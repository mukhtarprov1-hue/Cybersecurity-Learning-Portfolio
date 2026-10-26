#!/usr/bin/env python3
"""Functional tests for the Password Checker demo; uses synthetic passwords only."""

from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CASES = Path(__file__).with_name("test_cases.csv")
ACCEPT_TEXT = "Result: The password meets all requirements."
REJECT_TEXT = "Result: The password does not meet all requirements."


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default=None, help="Path to a pre-built program")
    parser.add_argument("--compile", action="store_true", help="Compile before testing")
    args = parser.parse_args()

    binary = Path(args.binary).resolve() if args.binary else ROOT / "password_checker"
    if args.compile:
        source = Path(__file__).resolve().parents[1] / "password_checker.c"
        binary.parent.mkdir(parents=True, exist_ok=True)
        compile_result = subprocess.run(
            ["gcc", "-Wall", "-Wextra", "-Wpedantic", "-Werror", "-std=c17",
             str(source), "-o", str(binary)],
            capture_output=True, text=True, check=False,
        )
        if compile_result.returncode != 0:
            sys.stderr.write(compile_result.stdout + compile_result.stderr)
            print("FAIL: compilation", file=sys.stderr)
            return 1
        print("PASS: compilation with strict warnings")

    if not binary.is_file():
        print(f"Binary not found: {binary}. Build the program or pass --compile.",
              file=sys.stderr)
        return 2

    failures: list[str] = []
    with CASES.open(newline="", encoding="utf-8") as csvfile:
        cases = list(csv.DictReader(csvfile))

    for case in cases:
        process = subprocess.run(
            [str(binary)], input=case["sample_password"] + "\n",
            capture_output=True, text=True, check=False,
        )
        expected = ACCEPT_TEXT if case["expected_result"] == "ACCEPT" else REJECT_TEXT
        if process.returncode == 0 and expected in process.stdout:
            print(f"PASS: {case['case_id']} — {case['reason']}")
        else:
            failures.append(
                f"{case['case_id']}: expected {case['expected_result']}; "
                f"exit={process.returncode}; output={process.stdout!r} {process.stderr!r}"
            )
            print(f"FAIL: {case['case_id']}")

    # Boundary test: 256 characters must be rejected instead of silently truncated.
    long_input = "A" * 256 + "\n"
    process = subprocess.run(
        [str(binary)], input=long_input, capture_output=True, text=True, check=False
    )
    if process.returncode != 0 and "password is too long" in process.stderr:
        print("PASS: boundary — overlong input rejected")
    else:
        failures.append(
            f"boundary: expected overlong input rejection; "
            f"exit={process.returncode}; stderr={process.stderr!r}"
        )
        print("FAIL: boundary — overlong input")

    if failures:
        print(f"\n{len(failures)} test(s) failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"\nAll {len(cases) + 1} functional/boundary checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
