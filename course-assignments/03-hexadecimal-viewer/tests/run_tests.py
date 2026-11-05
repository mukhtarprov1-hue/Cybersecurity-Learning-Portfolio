#!/usr/bin/env python3
"""Integration tests for the Hexadecimal Viewer CLI."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, check=False)


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <path-to-hex-viewer>", file=sys.stderr)
        return 2

    executable = str(Path(sys.argv[1]).resolve())
    passed = 0
    failed = 0

    def test(name: str, check) -> None:
        nonlocal passed, failed
        try:
            check()
            print(f"[PASS] {name}")
            passed += 1
        except Exception as exc:
            print(f"[FAIL] {name}: {exc}")
            failed += 1

    with tempfile.TemporaryDirectory(prefix="hex-viewer-tests-") as temp_dir:
        temp = Path(temp_dir)
        sample = temp / "signature_sample.bin"
        sample_bytes = bytes.fromhex(
            "89 50 4E 47 0D 0A 1A 0A 48 45 41 44 45 52 00 41 53 43 49 49 FF 21"
        )
        sample.write_bytes(sample_bytes)

        def test_binary_hex_ascii_and_partial_row() -> None:
            result = run([executable, str(sample)])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("00000000" in result.stdout, "first offset is missing")
            assert_true("00000010" in result.stdout, "second offset is missing for the final 6 bytes")
            assert_true("89 50 4E 47 0D 0A 1A 0A" in result.stdout, "PNG signature bytes are not shown")
            assert_true(".PNG....HEADER.A" in result.stdout, "ASCII rendering is incorrect")
            assert_true("SCII.!" in result.stdout, "final partial ASCII row is incorrect")
            assert_true("Total bytes read: 22" in result.stdout, "byte count is incorrect")

        def test_missing_file() -> None:
            result = run([executable, str(temp / "does-not-exist.bin")])
            assert_true(result.returncode != 0, "missing file unexpectedly returned success")
            assert_true("Error opening file" in result.stderr, "missing-file error message is absent")

        def test_no_arguments() -> None:
            result = run([executable])
            assert_true(result.returncode != 0, "no-argument call unexpectedly returned success")
            assert_true("Usage:" in result.stderr, "usage message is absent")

        def test_empty_file() -> None:
            empty = temp / "empty.bin"
            empty.write_bytes(b"")
            result = run([executable, str(empty)])
            assert_true(result.returncode == 0, f"empty file failed: {result.stderr}")
            assert_true("Total bytes read: 0" in result.stdout, "empty-file count is incorrect")

        def test_exact_16_byte_row() -> None:
            exact = temp / "exact-16.bin"
            exact.write_bytes(bytes(range(16)))
            result = run([executable, str(exact)])
            assert_true(result.returncode == 0, f"16-byte file failed: {result.stderr}")
            assert_true("Total bytes read: 16" in result.stdout, "exact-row byte count is incorrect")
            assert_true("00000010" not in result.stdout, "unexpected extra row at offset 0x10")

        test("Binary Hex + ASCII output and 16-byte offsets", test_binary_hex_ascii_and_partial_row)
        test("Missing file is handled", test_missing_file)
        test("Missing command-line argument is handled", test_no_arguments)
        test("Empty file is handled", test_empty_file)
        test("Exact 16-byte boundary is handled", test_exact_16_byte_row)

    print(f"\nTest summary: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
