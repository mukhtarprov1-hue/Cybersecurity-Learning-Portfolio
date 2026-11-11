# Test Results — Automated Log Analyzer

## Project-preparation verification

**Validation date:** 12 November 2026.

Commands:

    python -m py_compile log_analyzer.py tests/test_log_analyzer.py
    python -m unittest discover -s tests -v
    python log_analyzer.py samples/sample_access.log

### Results

- Python compilation: passed.
- Unit tests: 15 passed, 0 failed.
- Synthetic sample: 6 lines scanned, 4 suspicious lines, 4 alerts.
- SQL Injection: 2 alerts.
- Path Traversal: 2 alerts.
- Normal log entries: 2 ignored.

The 15 unit tests cover case-insensitive SQL UNION SELECT, Boolean SQL Injection, SLEEP(), plain and URL-encoded Path Traversal, normal access records, IPv4 and IPv6 extraction, invalid/unknown IP handling, line numbers and category counts, multiple categories on one line, context-managed file reading, missing-file handling, text report contents, and JSON report validity.

**Important:** These results were produced in the project-preparation environment. They are not evidence that the learner's Windows PC has run the project yet. Repeat the commands locally and capture fresh screenshots after pulling the repository.

## Expected synthetic-sample totals

    Lines scanned     : 6
    Suspicious lines  : 4
    Total alerts      : 4
    Path Traversal    : 2
    SQL Injection     : 2

The sample uses synthetic access entries and documentation IP ranges only.
