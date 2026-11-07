# Assignment 04 — Log File Parser (C17)

> **Course:** Cybersecurity Camp 2026  
> **Learner:** Mukhtar Alawady  
> **Task:** 04 · **Language:** C17 · **Interface:** CLI  
> **Implementation:** Complete source code and repeatable integration tests are included.  
> **Local verification:** Strict GCC build passed; 10/10 integration tests passed.  
> **Hosted CI:** Pending first hosted verification; do not infer success from the workflow file alone.  
> **Submission:** The assignment-specific Discord thread is listed in Section 9. GitHub publication alone is not proof of course submission.

> **Submission state:** Public package prepared; the learner must still post the assignment link in the Discord thread. **Trainer review/acceptance:** Not recorded. **Due date/rubric:** Not supplied in the task brief received.

## Instructor quick access

| Open this | What it contains |
|---|---|
| [Task specification (Arabic)](TASK_SPEC_AR.md) | Description, required C functions, and acceptance points |
| [C source](log_parser.c) | Full implementation using `fopen`, `fgets`, and `strstr` |
| [Arabic technical report](docs/REPORT_AR.md) | Design, memory behavior, implementation, tests, and limitations |
| [Requirements traceability](docs/TRACEABILITY.md) | Requirement → source → test → evidence |
| [Reviewer guide (Arabic)](docs/REVIEWER_GUIDE_AR.md) | Rebuild and verify the program |
| [Integration tests](tests/run_tests.py) | Ten repeatable functional, negative, boundary, and scale tests |
| [Synthetic log generator](samples/create_sample.py) | Creates a harmless six-line SOC-style log |
| [Execution evidence](evidence/) | Captured terminal output and build/test logs |
| [GitHub Actions workflow](../../.github/workflows/log-parser-c.yml) | Automated strict C17 build and integration tests |

## 1. Objective and result

The program scans a text log file for one user-selected keyword. It reads the file in text mode, identifies each complete logical line containing that keyword, prints the original line with its one-based line number, and reports the total number of matching lines as `Total alerts`.

The keyword is supplied as a command-line argument so the same executable can search for `FAILED`, `404`, or another literal string without changing or recompiling the source.

## 2. Build and run

### Linux / Kali Linux

```bash
gcc -std=c17 -Wall -Wextra -Wpedantic -Werror -O2 log_parser.c -o log_parser
python3 samples/create_sample.py
./log_parser samples/sample.log FAILED
./log_parser samples/sample.log 404
python3 tests/run_tests.py ./log_parser
```

### Windows / MSYS2 UCRT64

```bash
gcc -std=c17 -Wall -Wextra -Wpedantic -Werror -O2 log_parser.c -o log_parser.exe
python samples/create_sample.py
./log_parser.exe samples/sample.log FAILED
./log_parser.exe samples/sample.log 404
python tests/run_tests.py ./log_parser.exe
```

Quote the keyword when it contains spaces, for example `"authentication failed"`. Matching is literal and case-sensitive because the implementation uses `strstr()` as requested.

## 3. Expected output behavior

For the included synthetic fixture and keyword `FAILED`, the tool reports the two matching records and their original line numbers, followed by `Total alerts: 2`. Searching for `404` reports the single matching web record and `Total alerts: 1`. Captured outputs are stored in `evidence/`.

## 4. Verification coverage

The test suite checks keyword extraction and line numbering, `404` searching, case sensitivity, counting once per matching line, zero matches, empty files, missing files, invalid arguments, long lines whose keyword crosses an internal `fgets()` chunk boundary, and a 6,000-line input.

The long-line test verifies that one logical log line is not mistakenly counted as multiple lines merely because it exceeds the 512-byte input chunk. The large-file test checks line-number accuracy without loading the entire log file into memory.

## 5. Memory and processing model

Input is fetched with `fgets()` into a 512-byte chunk. Chunks are assembled into one dynamically sized logical-line buffer so long lines can still be searched and printed as a single line. After each logical line is processed, the same buffer is reused. The program does **not** keep the complete log file or a list of alerts in memory.

For a file of size **N** and longest logical line of length **L**, scanning is linear in the file size; additional memory is proportional to the longest single line, not the total file size. This preserves correct matching across chunk boundaries and exact line numbers. A pathological single line can still require a correspondingly large allocation.

## 6. Project structure

```text
04-log-file-parser/
├── README.md
├── TASK_SPEC_AR.md
├── log_parser.c
├── samples/
│   ├── README.md
│   └── create_sample.py
├── tests/
│   └── run_tests.py
├── docs/
│   ├── REPORT_AR.md
│   ├── REVIEWER_GUIDE_AR.md
│   └── TRACEABILITY.md
├── evidence/
└── .gitignore
```

## 7. Safety and limitations

- The parser opens logs read-only in text mode and does not modify the source file.
- `strstr()` performs a literal, case-sensitive substring match; this is not regular-expression or semantic detection.
- The input is expected to be a text log. Embedded NUL bytes are outside the intended text-log format and are not supported by C string functions such as `strstr()`.
- This is a keyword triage utility, not a SIEM, correlation engine, intrusion detector, or proof that an event is malicious.
- The sample log is synthetic and uses documentation-only IP address ranges. Do not publish private logs or sensitive identifiers.

## 8. Evidence integrity

Text files under `evidence/` are captured program/build/test outputs. A live GitHub Actions result will be linked once the hosted run is inspected. A workflow definition alone is not evidence of a successful CI run.

## 9. Submission channel

[Open the Assignment 04 Discord thread](https://discord.com/channels/838962253855588402/1567926845662306394)

Post this assignment page link in that thread:

```text
https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/tree/main/course-assignments/04-log-file-parser
```

**Submission status:** The public package has been prepared. The learner still needs to post the link. No trainer submission, grade, review, or acceptance is claimed here.
