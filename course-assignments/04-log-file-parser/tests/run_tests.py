#!/usr/bin/env python3
"""Integration tests for the C Log File Parser."""

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
        print(f"Usage: {Path(sys.argv[0]).name} <path-to-log-parser>", file=sys.stderr)
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

    with tempfile.TemporaryDirectory(prefix="log-parser-tests-") as temp_dir:
        temp = Path(temp_dir)
        sample = temp / "sample.log"
        sample.write_text(
            "INFO startup status=200\n"
            "WARN login FAILED user=demo\n"
            "INFO health status=200\n"
            "WARN request status=404 path=/admin\n"
            "ERROR login FAILED user=guest\n",
            encoding="utf-8",
        )

        def test_keyword_and_line_numbers() -> None:
            result = run([executable, str(sample), "FAILED"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Line 2: WARN login FAILED user=demo" in result.stdout,
                        "first matching line number/content is incorrect")
            assert_true("Line 5: ERROR login FAILED user=guest" in result.stdout,
                        "second matching line number/content is incorrect")
            assert_true("Total alerts: 2" in result.stdout, "alert count should be 2")

        def test_different_keyword() -> None:
            result = run([executable, str(sample), "404"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Line 4: WARN request status=404 path=/admin" in result.stdout,
                        "404 record was not extracted with the correct line number")
            assert_true("Total alerts: 1" in result.stdout, "alert count should be 1")

        def test_case_sensitive_search() -> None:
            case_file = temp / "case.log"
            case_file.write_text("login failed\nlogin FAILED\n", encoding="utf-8")
            result = run([executable, str(case_file), "FAILED"])
            assert_true("Line 2: login FAILED" in result.stdout, "case-sensitive match is incorrect")
            assert_true("Total alerts: 1" in result.stdout, "lowercase text should not match FAILED")

        def test_count_once_per_matching_line() -> None:
            repeated = temp / "repeated-keyword.log"
            repeated.write_text("FAILED FAILED FAILED\nFAILED once\n", encoding="utf-8")
            result = run([executable, str(repeated), "FAILED"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Line 1: FAILED FAILED FAILED" in result.stdout,
                        "first matching line was not printed")
            assert_true("Total alerts: 2" in result.stdout,
                        "alert count must count matching lines, not keyword occurrences")

        def test_no_matches() -> None:
            result = run([executable, str(sample), "NOT_PRESENT"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("No matching records found." in result.stdout, "no-match message is absent")
            assert_true("Total alerts: 0" in result.stdout, "zero-alert summary is incorrect")

        def test_empty_file() -> None:
            empty = temp / "empty.log"
            empty.write_text("", encoding="utf-8")
            result = run([executable, str(empty), "FAILED"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Total alerts: 0" in result.stdout, "empty-file summary is incorrect")

        def test_missing_file() -> None:
            result = run([executable, str(temp / "missing.log"), "FAILED"])
            assert_true(result.returncode != 0, "missing file unexpectedly returned success")
            assert_true("Error opening log file" in result.stderr, "missing-file error is absent")

        def test_invalid_arguments() -> None:
            no_args = run([executable])
            empty_keyword = run([executable, str(sample), ""])
            assert_true(no_args.returncode != 0 and "Usage:" in no_args.stderr,
                        "missing arguments were not rejected")
            assert_true(empty_keyword.returncode != 0 and "Usage:" in empty_keyword.stderr,
                        "empty keyword was not rejected")

        def test_long_line_and_match_across_chunks() -> None:
            long_file = temp / "long-line.log"
            long_file.write_text("X" * 509 + "FAILED" + " tail\nsecond line FAILED",
                                 encoding="utf-8")
            result = run([executable, str(long_file), "FAILED"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Line 1: " in result.stdout, "long first line was not counted once")
            assert_true("Line 2: second line FAILED" in result.stdout,
                        "final non-newline-terminated line has the wrong number/content")
            assert_true("Total alerts: 2" in result.stdout, "long-line alert count is incorrect")

        def test_large_log_streaming_and_line_count() -> None:
            large = temp / "large.log"
            total_lines = 6000
            with large.open("w", encoding="utf-8", newline="\n") as handle:
                for index in range(1, total_lines + 1):
                    marker = " FAILED" if index == 4321 else ""
                    handle.write(f"2026-11-07T00:00:{index % 60:02d}Z INFO event={index}{marker}\n")
            result = run([executable, str(large), "FAILED"])
            assert_true(result.returncode == 0, f"exit={result.returncode}; stderr={result.stderr}")
            assert_true("Line 4321: " in result.stdout, "large-file line number is incorrect")
            assert_true("Total alerts: 1" in result.stdout, "large-file alert count is incorrect")

        test("Keyword extraction and exact line numbers", test_keyword_and_line_numbers)
        test("404 keyword extraction", test_different_keyword)
        test("Case-sensitive strstr behavior", test_case_sensitive_search)
        test("Count once per matching line", test_count_once_per_matching_line)
        test("No matching records", test_no_matches)
        test("Empty log file", test_empty_file)
        test("Missing log file error", test_missing_file)
        test("Missing and empty arguments", test_invalid_arguments)
        test("Long line and keyword across fgets chunks", test_long_line_and_match_across_chunks)
        test("Large log file and line-number accuracy", test_large_log_streaming_and_line_count)

    print(f"\nTest summary: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
