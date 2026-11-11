# Test Results — Automated Log Analyzer

## Verified learner environment

- **OS / Shell:** Windows PowerShell
- **Validation date:** 12 November 2026
- **Input:** included synthetic file samples\sample_access.log
- **Dependencies:** Python standard library only

## 1. Compilation

Command:

    python -m py_compile log_analyzer.py tests\test_log_analyzer.py

Observed result: returned to the PowerShell prompt without a compilation error.

## 2. Unit tests

Command:

    python -m unittest discover -s tests -v

Observed result from the learner's Windows console:

    Ran 15 tests in 0.034s

    OK

| Metric | Result |
|---|---:|
| Tests run | 15 |
| Passed | 15 |
| Failed | 0 |
| Skipped | 0 |
| Runtime | 0.034 s |

Covered cases include case-insensitive SQL UNION SELECT, Boolean SQL Injection, SLEEP(), plain and URL-encoded Path Traversal, normal access records, IPv4 and IPv6 extraction, invalid/unknown IP handling, line numbers and category counts, multiple categories on one line, context-managed file reading, missing-file handling, text report output, and JSON report validity.

## 3. Text report — actual Windows run

Command:

    python log_analyzer.py samples\sample_access.log

Observed summary:

    Lines scanned     : 6
    Suspicious lines  : 4
    Total alerts      : 4
    Path Traversal    : 2
    SQL Injection     : 2

Alert details:

| Line | Source IP | Category | Matched evidence |
|---:|---|---|---|
| 2 | 198.51.100.23 | SQL Injection | UNION SELECT |
| 3 | 203.0.113.7 | Path Traversal | ../../ |
| 4 | 198.51.100.81 | SQL Injection | ' OR '1'='1 |
| 6 | 192.0.2.45 | Path Traversal | %2e%2e%2f |

Two normal lines generated no alert.

## 4. JSON output — actual Windows run

Commands:

    python log_analyzer.py samples\sample_access.log --format json
    python log_analyzer.py samples\sample_access.log --format json --output docs\sample_report.json

Observed result: valid structured JSON was printed to the terminal. The output-file command returned:

    Report saved to: docs\sample_report.json

The generated file should be included in the final Git commit.

## 5. CLI help

Command:

    python log_analyzer.py --help

Observed result: usage and both supported options were displayed successfully: --format {text,json} and --output OUTPUT.

## 6. Summary

- Python compilation: PASS.
- Unit tests on learner Windows: 15/15 PASS.
- Synthetic sample: 6 lines, 4 suspicious lines, 4 alerts.
- Category distribution: 2 SQL Injection, 2 Path Traversal.
- Normal entries ignored: 2.
- JSON output: generated and saved to docs\sample_report.json.

The sample is synthetic and uses documentation IP ranges only. Findings are attack indicators for analyst review, not proof of successful exploitation.
