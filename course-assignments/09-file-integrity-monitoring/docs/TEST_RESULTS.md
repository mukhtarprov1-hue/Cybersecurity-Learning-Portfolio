# Test Plan and Results — Assignment 09

## Environment

- Required Python: 3.10 or newer.
- Operating system: record the learner's actual OS and Python version after local execution.
- Dependencies: Python standard library only.

## Automated unit tests

Run:

    python -m py_compile fim_tool.py tests\test_fim_tool.py
    python -m unittest discover -s tests -v

The current test suite contains 14 test methods covering:

1. SHA-256 result against Python's hashlib.
2. Chunked reading using a small chunk size.
3. Rejection of invalid chunk sizes.
4. Creating and loading a JSON baseline.
5. 64-character hexadecimal digest length.
6. Unchanged file status.
7. Detection of a one-character edit.
8. Detection of appended content.
9. Detection of a deleted file.
10. Preservation of the original baseline after a modification.
11. Rejection of a different monitored file.
12. Prevention of using the monitored file itself as the baseline.
13. Rejection of an invalid SHA-256 digest in a baseline.
14. Rejection of an unsupported baseline schema.

## Expected outcomes

- Compilation: no syntax errors.
- Unit tests: 14 passed, 0 failed.
- Initial run: [BASELINE CREATED].
- Subsequent unchanged scan: [OK] Integrity verified.
- Changed file: [ALERT] [CRITICAL] FILE INTEGRITY VIOLATION DETECTED!.
- Missing file: [ALERT] [CRITICAL] Monitored file is missing.
- Continuous run: remains active until Ctrl+C; the original baseline is preserved.

## Learner execution record

**Status: PENDING LOCAL VERIFICATION.**

Do not mark the expected results above as observed until the commands have actually been executed on the learner's workstation. Add the actual Python version, test count, elapsed time, and screenshots after local verification.
