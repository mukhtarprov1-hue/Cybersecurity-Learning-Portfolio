#!/usr/bin/env python3
"""Educational File Integrity Monitoring (FIM) tool using SHA-256."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_CHUNK_SIZE = 64 * 1024
DEFAULT_INTERVAL = 3.0
SCHEMA_VERSION = 1
ALGORITHM = "SHA-256"


def calculate_sha256(file_path: str | Path, chunk_size: int = DEFAULT_CHUNK_SIZE) -> str:
    """Return a file's SHA-256 digest, reading incrementally in binary chunks."""
    if isinstance(chunk_size, bool) or not isinstance(chunk_size, int) or chunk_size <= 0:
        raise ValueError("chunk_size must be a positive integer")

    digest = hashlib.sha256()
    with Path(file_path).open("rb") as file_handle:
        while True:
            chunk = file_handle.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _validated_paths(file_path: str | Path, baseline_path: str | Path) -> tuple[Path, Path]:
    target = Path(file_path).expanduser().resolve(strict=False)
    baseline = Path(baseline_path).expanduser().resolve(strict=False)
    if target == baseline:
        raise ValueError("The baseline file must be different from the monitored file")
    return target, baseline


def create_baseline(
    file_path: str | Path,
    baseline_path: str | Path,
    chunk_size: int = DEFAULT_CHUNK_SIZE,
) -> dict[str, Any]:
    """Calculate and atomically save the initial trusted reference record."""
    target, baseline = _validated_paths(file_path, baseline_path)
    if not target.exists() or not target.is_file():
        raise FileNotFoundError(f"Monitored file does not exist or is not a regular file: {target}")

    record: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "algorithm": ALGORITHM,
        "file_path": str(target),
        "sha256": calculate_sha256(target, chunk_size),
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
    }

    baseline.parent.mkdir(parents=True, exist_ok=True)
    temp_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", newline="\n",
            dir=baseline.parent, prefix=f".{baseline.name}.", suffix=".tmp",
            delete=False,
        ) as temp_file:
            temp_name = temp_file.name
            json.dump(record, temp_file, ensure_ascii=False, indent=2)
            temp_file.write("\n")
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.replace(temp_name, baseline)
    finally:
        if temp_name and os.path.exists(temp_name):
            os.unlink(temp_name)

    return record


def load_baseline(baseline_path: str | Path) -> dict[str, Any]:
    """Load and validate a previously saved JSON baseline."""
    with Path(baseline_path).expanduser().open("r", encoding="utf-8") as file_handle:
        record = json.load(file_handle)

    if not isinstance(record, dict):
        raise ValueError("Invalid baseline: JSON root must be an object")
    if record.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("Invalid baseline: unsupported or missing schema_version")
    if record.get("algorithm") != ALGORITHM:
        raise ValueError("Invalid baseline: expected algorithm SHA-256")
    stored_path = record.get("file_path")
    if not isinstance(stored_path, str) or not stored_path.strip():
        raise ValueError("Invalid baseline: file_path is missing")
    digest = record.get("sha256")
    if not isinstance(digest, str) or re.fullmatch(r"[0-9a-f]{64}", digest) is None:
        raise ValueError("Invalid baseline: sha256 must contain 64 lowercase hexadecimal characters")
    if not isinstance(record.get("created_at_utc"), str):
        raise ValueError("Invalid baseline: created_at_utc is missing")
    return record


def check_integrity(
    file_path: str | Path,
    baseline: dict[str, Any],
    chunk_size: int = DEFAULT_CHUNK_SIZE,
) -> dict[str, str | None]:
    """Compare the current file digest with the stored reference."""
    target = Path(file_path).expanduser().resolve(strict=False)
    expected_path = Path(str(baseline["file_path"])).expanduser().resolve(strict=False)
    if target != expected_path:
        raise ValueError("The monitored file does not match the file recorded in the baseline")

    expected_hash = str(baseline["sha256"])
    if not target.exists() or not target.is_file():
        return {"status": "MISSING", "expected_sha256": expected_hash, "current_sha256": None}

    current_hash = calculate_sha256(target, chunk_size)
    return {
        "status": "UNCHANGED" if current_hash == expected_hash else "MODIFIED",
        "expected_sha256": expected_hash,
        "current_sha256": current_hash,
    }


def positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def positive_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive number") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def run_monitor(args: argparse.Namespace) -> int:
    target, baseline_path = _validated_paths(args.file, args.baseline)

    if args.reset_baseline:
        record = create_baseline(target, baseline_path, args.chunk_size)
        print(f"[BASELINE RESET] New SHA-256 reference saved: {baseline_path}")
    elif baseline_path.exists():
        record = load_baseline(baseline_path)
        if Path(record["file_path"]).resolve(strict=False) != target:
            raise ValueError(
                "The selected baseline belongs to a different file. "
                "Choose the correct baseline or use --reset-baseline deliberately."
            )
        print(f"[BASELINE LOADED] {baseline_path}")
    else:
        record = create_baseline(target, baseline_path, args.chunk_size)
        print(f"[BASELINE CREATED] Initial SHA-256 reference saved: {baseline_path}")

    print(f"[MONITORING] File: {target}")
    print(f"[MONITORING] Interval: {args.interval:g} seconds | Chunk size: {args.chunk_size} bytes")
    print("[MONITORING] Press Ctrl+C to stop safely.")

    def scan_once() -> int:
        try:
            result = check_integrity(target, record, args.chunk_size)
        except (OSError, ValueError) as exc:
            print(f"[ERROR] Could not complete integrity check: {exc}", flush=True)
            return 2

        if result["status"] == "UNCHANGED":
            print(f"[OK] Integrity verified — SHA-256: {result['current_sha256']}", flush=True)
            return 0
        if result["status"] == "MISSING":
            print(
                f"[ALERT] [CRITICAL] Monitored file is missing: {target}. "
                "The original baseline has been preserved.",
                flush=True,
            )
            return 1

        print(
            "[ALERT] [CRITICAL] FILE INTEGRITY VIOLATION DETECTED!\n"
            f"  File:     {target}\n"
            f"  Expected: {result['expected_sha256']}\n"
            f"  Current:  {result['current_sha256']}\n"
            "  Action:   Baseline preserved; investigate before any reset.",
            flush=True,
        )
        return 1

    if args.once:
        return scan_once()

    try:
        while True:
            scan_once()
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[STOPPED] Monitoring stopped by user. Baseline was not changed.")
        return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Monitor a file for unauthorized changes using a SHA-256 baseline."
    )
    parser.add_argument("file", help="path to the file to monitor")
    parser.add_argument("--baseline", default="fim_baseline.json",
                        help="path for the JSON baseline (default: fim_baseline.json)")
    parser.add_argument("--interval", type=positive_float, default=DEFAULT_INTERVAL,
                        help="seconds between scans in continuous mode (default: 3)")
    parser.add_argument("--chunk-size", type=positive_int, default=DEFAULT_CHUNK_SIZE,
                        help="bytes read per hashing chunk (default: 65536)")
    parser.add_argument("--once", action="store_true",
                        help="perform one comparison and exit instead of monitoring continuously")
    parser.add_argument("--reset-baseline", action="store_true",
                        help="replace the saved reference with the current file's digest")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return run_monitor(args)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
