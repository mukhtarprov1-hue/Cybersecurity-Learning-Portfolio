# Requirements Traceability — Assignment 04

This matrix maps the received task brief to the C implementation, repeatable verification, and supporting evidence. It is a review checklist, not an invented grading rubric.

| ID | Trainer requirement / acceptance point | Implementation | Verification | Evidence |
|---|---|---|---|---|
| R-01 | Open a text log in read mode `r` | `log_parser.c` — `fopen(argv[1], "r")` | Run with a readable synthetic text log | `evidence/sample-failed.log`; `evidence/sample-404.log` |
| R-02 | Read the log line by line with `fgets()` | `log_parser.c` — `fgets(chunk, sizeof chunk, log_file)` | Sample, long-line, and large-file integration tests | `tests/run_tests.py`; `evidence/build-and-test.log` |
| R-03 | Search each line with `strstr()` | `log_parser.c` — `inspect_line()` | Search for `FAILED`, `404`, and a case variant | `tests/run_tests.py`; sample run logs |
| R-04 | Increment alert count and print line number/content | `inspect_line()` — `line_number`, `alert_count`, `printf`, `fputs` | Assert matching line numbers and complete text | `evidence/sample-failed.log`; `evidence/sample-404.log` |
| R-05 | Print final alert total | `main()` — `Total alerts` summary | Test positive and zero-match inputs | `evidence/no-match.log`; `evidence/build-and-test.log` |
| A-01 | Handle large logs without retaining the whole file in memory | Fixed 512-byte input chunk; one reusable dynamic logical-line buffer | Process 6,000-line fixture and inspect line 4321 | T-10 in `tests/run_tests.py` |
| A-02 | Accurate physical/logical line numbers | Count only after a complete logical line is assembled | Long line crosses the 511-byte input boundary; final line lacks newline | T-09 in `tests/run_tests.py` |
| A-03 | Report the number of extracted records | One increment per matching logical line | Assert totals 2, 1, and 0 | `evidence/sample-failed.log`; `evidence/sample-404.log`; `evidence/no-match.log` |

## Verification scope and limitations

- The program uses `strstr()` exactly as requested; the match is literal and case-sensitive.
- The input is a text log. Embedded NUL bytes are outside the supported input model.
- Memory consumption is proportional to the longest single logical line, not the complete file size. A single extremely long line can require a large allocation.
- The ten automated tests cover the scenarios listed in the Arabic report. They are not exhaustive fault-injection or SIEM detection validation.
- Do not record CI as successful until the live workflow run has been inspected and its tested commit recorded here.
