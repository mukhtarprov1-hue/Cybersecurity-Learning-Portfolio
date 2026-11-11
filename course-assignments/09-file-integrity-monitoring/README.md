# Assignment 09 — File Integrity Monitoring (FIM)

A defensive Python command-line tool that creates a SHA-256 baseline for one file and checks it repeatedly for unexpected changes.

## Features

- Reads monitored files in binary mode (rb) and hashes them incrementally in configurable chunks.
- Creates a JSON SHA-256 baseline on first run.
- Checks the file every three seconds by default using time.sleep().
- Prints a critical alert when the digest changes or the monitored file disappears.
- Preserves the original baseline after a change; it never silently trusts modified content.
- Supports a one-shot comparison for repeatable tests and an explicit baseline reset option.
- Uses only the Python standard library.

## Requirements

- Python 3.10 or newer.
- No third-party packages are required.

## Project structure

    09-file-integrity-monitoring/
    ├── fim_tool.py
    ├── README.md
    ├── TASK_SPEC_AR.md
    ├── requirements.txt
    ├── .gitignore
    ├── samples/critical_config_sample.txt
    ├── tests/test_fim_tool.py
    ├── docs/REPORT_AR.md
    ├── docs/TEST_RESULTS.md
    ├── docs/TRACEABILITY.md
    ├── screenshots/
    (CI workflow: repository-root .github/workflows/assignment-09-fim.yml)

## Run the monitor

From this directory:

    python fim_tool.py samples/critical_config_sample.txt

The first run creates fim_baseline.json in the current directory and then starts continuous monitoring. The default check interval is three seconds. Stop it with Ctrl+C.

Specify a different interval, baseline path, or chunk size:

    python fim_tool.py samples/critical_config_sample.txt --interval 5
    python fim_tool.py samples/critical_config_sample.txt --baseline docs/local_baseline.json --chunk-size 32768

## Reproducible change demonstration (Windows PowerShell)

Open two PowerShell windows in this assignment directory.

Window 1 — start monitoring a disposable copy:

    $demoFile = Join-Path $env:TEMP "fim-demo-target.txt"
    Copy-Item .\samples\critical_config_sample.txt $demoFile -Force
    python .\fim_tool.py $demoFile --baseline .\fim_baseline.json --interval 3

Window 2 — change one line in the disposable copy:

    Add-Content -LiteralPath (Join-Path $env:TEMP "fim-demo-target.txt") -Value "SIMULATED TEST CHANGE"

Within the next scan interval, Window 1 should display [ALERT] [CRITICAL] FILE INTEGRITY VIOLATION DETECTED!. Stop monitoring with Ctrl+C. The original sample is not modified.

## One-shot mode

    python fim_tool.py samples/critical_config_sample.txt --once

The first invocation creates a baseline and reports the initial file as unchanged. Run it again after changing the file to receive a critical alert and a non-zero exit code.

## Explicitly reset the baseline

    python fim_tool.py samples/critical_config_sample.txt --reset-baseline

This intentionally replaces the stored reference with the file's current content. Do this only after verifying the change is legitimate. Do not use this option to dismiss an unexplained alert.

## Compile and test

    python -m py_compile fim_tool.py tests\test_fim_tool.py
    python -m unittest discover -s tests -v

**Learner's Windows verification (Python 3.10.0):** compilation passed, all 14 unit tests passed (0 failed, 0 skipped), and the continuous demonstration created a baseline, reported unchanged scans, then emitted a critical alert after a simulated file modification. See docs/TEST_RESULTS.md and docs/REPORT_AR.md for the observed results.

## Execution evidence

The five learner-captured Windows PowerShell screenshots are committed in [screenshots/](screenshots/):

| Evidence | Screenshot |
|---|---|
| Python version and CLI help | [01-help-and-python-version.png](screenshots/01-help-and-python-version.png) |
| Compilation and all unit tests | [02-compilation-and-unit-tests.png](screenshots/02-compilation-and-unit-tests.png) |
| Initial SHA-256 baseline | [03-baseline-created.png](screenshots/03-baseline-created.png) |
| Critical alert after content modification | [04-critical-change-alert.png](screenshots/04-critical-change-alert.png) |
| Safe stop of continuous monitoring | [05-stop-monitoring.png](screenshots/05-stop-monitoring.png) |

Hosted verification: [GitHub Actions run 43112755840 — all four Windows/Ubuntu and Python 3.10/3.13 jobs passed](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43112755840).

## Security notes and limitations

- SHA-256 detects content changes; it does not identify who changed the file or whether the change was authorized.
- A baseline stored beside the tool can itself be modified by an attacker with sufficient permissions. For production use, protect the baseline with restrictive access controls and consider storing or signing it in a separate trusted location.
- This teaching version monitors one file per process. It is not a full endpoint detection platform, does not watch file-system events, and can detect a change only at the next polling interval.
- A change is reported repeatedly while the current digest differs from the trusted baseline. The tool deliberately does not update the baseline automatically.
- File replacement, deletion, access denial, or concurrent writes can affect a scan. Review errors and alerts rather than assuming a clean result.
- Use only on files and systems you own or are authorized to monitor.
