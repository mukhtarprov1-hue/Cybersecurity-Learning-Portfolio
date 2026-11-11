# Assignment 07 — Automated Log Analyzer

Python tool for defensive, line-by-line analysis of web-server access logs using compiled regular expressions to flag selected SQL Injection and Path Traversal indicators.

## Features

- Reads text logs incrementally with a context manager; it does not load the entire file at once.
- Compiles detection expressions with re.IGNORECASE and uses Pattern.search().
- Detects selected SQL injection indicators: UNION SELECT, Boolean OR/AND comparisons, SLEEP(), BENCHMARK(), LOAD_FILE(), and INTO OUTFILE.
- Detects plain and URL-encoded path traversal sequences.
- Checks both raw log text and a URL-decoded view to catch common percent-encoded payloads.
- Extracts IPv4/IPv6 from the first field of common access logs; otherwise reports UNKNOWN.
- Prints attack type, line number, source IP, matched evidence, and a shortened log excerpt.
- Summarizes scanned lines, suspicious lines, total alerts, and counts by category.
- Supports text and JSON reports. No third-party dependencies are required.

## Project structure

    07-automated-log-analyzer/
    ├── log_analyzer.py
    ├── README.md
    ├── TASK_SPEC_AR.md
    ├── requirements.txt
    ├── samples/sample_access.log
    ├── tests/test_log_analyzer.py
    ├── docs/REPORT_AR.md
    ├── docs/TEST_RESULTS.md
    ├── docs/TRACEABILITY.md
    ├── docs/sample_report.json
    └── screenshots/

## Requirements

- Python 3.10 or newer.
- Python standard library only. No pip install step is required.

## Run the included synthetic sample

    python log_analyzer.py samples/sample_access.log

Expected and learner-verified totals:
- 6 lines scanned.
- 4 suspicious lines.
- 4 alerts: 2 SQL Injection and 2 Path Traversal.
- 2 normal lines ignored.

The sample uses documentation-only IP ranges. It contains no real incident data.

## Save JSON output

    python log_analyzer.py samples/sample_access.log --format json
    python log_analyzer.py samples/sample_access.log --format json --output docs/sample_report.json

The second command creates a structured report in the docs directory.

## Analyze an authorized log

    python log_analyzer.py "C:\Logs\access.log"

## Compile and test

    python -m py_compile log_analyzer.py tests/test_log_analyzer.py
    python -m unittest discover -s tests -v

Learner's Windows verification: 15 tests passed, 0 failed, 0 skipped. See docs/TEST_RESULTS.md for the observed output.

## Detection scope and limitations

This is a teaching tool based on selected indicators, not a full web application firewall or a definitive vulnerability detector. Attackers may obfuscate payloads, and legitimate requests may contain suspicious-looking strings. Findings require analyst review. A log entry identifies the source address recorded by the server; it does not independently prove the identity of a person or system. The first whitespace-delimited field is assumed to be the client IP, as in common Apache/Nginx access logs.

The URL-decoding pass improves detection of common percent-encoded payloads. The original log excerpt is retained for review. The tool does not modify logs or make network connections.

Use only on systems and log files you are authorized to analyze.
