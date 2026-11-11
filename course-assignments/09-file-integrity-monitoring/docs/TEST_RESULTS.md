# Test Plan and Results — Assignment 09

## Environment

- Actual learner verification: Windows PowerShell.
- Python version: 3.10.0.
- Verification date: 12 November 2026.
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

## Learner execution record — Windows PowerShell

**Status: LOCALLY VERIFIED — 12 November 2026.**

Observed results supplied from the learner's Windows workstation:

- `python --version`: Python 3.10.0.
- CLI help displayed successfully.
- `py_compile`: completed with no syntax errors.
- Unit tests: 14 passed, 0 failed, 0 skipped.
- Test duration: 0.144 seconds.
- Continuous monitoring created the initial baseline and printed repeated `[OK]` integrity checks.
- After appending the simulated test change to the disposable TEMP copy, the tool displayed the critical file-integrity alert and showed different expected/current SHA-256 values.
- The alert remained active while the file differed from the original baseline.

The original sample file was not the modification target. Screenshots are maintained separately in `screenshots/`; their presence in the public repository must be verified after the learner pushes them.
