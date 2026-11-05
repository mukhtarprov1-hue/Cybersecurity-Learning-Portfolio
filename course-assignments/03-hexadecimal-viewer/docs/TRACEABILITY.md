# Requirements Traceability — Assignment 03

This matrix maps the trainer-provided requirements to the implementation, a repeatable test, and the associated evidence. It is a traceability checklist, not an invented scoring rubric.

| ID | Requirement / acceptance point | Implementation location | Verification | Evidence |
|---|---|---|---|---|
| R-01 | Accept a file path through argc/argv | hex_viewer.c — main() argument check | Run without arguments; expect Usage and non-zero exit | evidence/argument-validation.log; screenshots/03-argument-validation.svg |
| R-02 | Open the target in binary read mode rb | hex_viewer.c — fopen(argv[1], "rb") | Run on synthetic binary fixture | evidence/sample-run.log; screenshots/01-sample-output.svg |
| R-03 | Read up to 16 bytes per iteration with fread() in while | hex_viewer.c — fread(buffer, 1, sizeof buffer, file) | 22-byte sample checks offsets 0x00 and 0x10; exact 16-byte case checks no spurious row | tests/run_tests.py; evidence/build-and-test.log |
| R-04 | Print each byte as two-digit uppercase hex using %02X | hex_viewer.c — hexadecimal output loop | Verify PNG signature bytes in output | evidence/sample-run.log; screenshots/01-sample-output.svg |
| R-05 | Print ASCII for values 32–126; replace other bytes with a dot | hex_viewer.c — ASCII output loop | NUL and 0xFF are displayed as dots; readable ASCII remains readable | tests/run_tests.py; evidence/sample-run.log |
| A-01 | Hex and ASCII columns align | fixed 16-column display and padding for missing bytes | 22-byte partial final row | screenshots/01-sample-output.svg |
| A-02 | Missing file is handled | fopen() NULL check and perror() | Run with non-existent path; expect non-zero exit | evidence/missing-file.log; screenshots/02-missing-file.svg |
| A-03 | Close file after reading | fclose() and error check | Code review; success and failure paths after a successful open reach fclose() | hex_viewer.c |
| A-04 | Detect read/close errors | ferror() and fclose() return value | Code review; ordinary I/O error injection is not covered by the five integration tests | hex_viewer.c |

## Verification result

- Reference environment: Debian GNU/Linux 13, GCC 14.2.0, Python 3.13.5.
- Strict build command: gcc -std=c17 -Wall -Wextra -Wpedantic -Werror -O2 hex_viewer.c -o hex_viewer
- Local reference verification: build passed; 5/5 integration tests passed.
- Hosted GitHub Actions workflow: configured at .github/workflows/hex-viewer-c.yml; inspect the live workflow page before claiming CI success.

## Test inventory

| Test ID | Scenario | Expected behavior | Current recorded outcome |
|---|---|---|---|
| T-01 | 22-byte synthetic binary fixture | Hex/ASCII correct, 16-byte rows, partial row, total 22 | PASS |
| T-02 | Non-existent path | Error message and non-zero exit | PASS |
| T-03 | No file argument | Usage message and non-zero exit | PASS |
| T-04 | Empty file | Successful exit and total 0 | PASS |
| T-05 | Exactly 16 bytes | One row, total 16, no second row | PASS |

The five tests do not constitute exhaustive filesystem fault injection or validation of every binary file format.
