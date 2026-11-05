# Assignment 01 — Password Checker in C17

> **Course:** Cybersecurity Camp 2026  
> **Learner:** Mukhtar Alawady  
> **Task:** 01 · **Language:** C17  
> **Public status:** Source, tests, Arabic report, and instructor notes are publicly accessible.  
> **Local reference validation:** Strict GCC build succeeded; 8/8 functional and boundary checks passed in Debian 13.  
**Hosted GitHub Actions:** SUCCESS — [run 42074038390](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/42074038390).

## Instructor quick access

| Open this | What it contains |
|---|---|
| [Task requirements (Arabic)](TASK_SPEC_AR.md) | The five recorded password rules and input boundary |
| [C source](../../projects/password-checker-c/password_checker.c) | Complete implementation |
| [Project README](../../projects/password-checker-c/README.md) | Build and run instructions, concepts, and limitations |
| [Test case table](../../projects/password-checker-c/tests/test_cases.csv) | Seven synthetic functional examples |
| [Automated test runner](../../projects/password-checker-c/tests/run_tests.py) | Functional and 256-character boundary checks |
| [Arabic test report](../../projects/password-checker-c/docs/test-report-ar.md) | Test design and limitations |
| [Instructor explanation notes](../../projects/password-checker-c/docs/explain-to-instructor-ar.md) | Short walkthrough and key C functions |
| [Requirements traceability](../../projects/password-checker-c/docs/TRACEABILITY.md) | Five rules mapped to code, tests, and CI evidence |
| [Reference build/test log](evidence/build-and-test.log) | Observed local build and test output |
| [Hosted CI evidence](evidence/hosted-ci-run.md) | Successful GitHub Actions build and test run |
| [GitHub Actions workflow](../../.github/workflows/ci.yml) | CI definition |
| [Successful hosted CI run](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/42074038390) | GCC build and 8/8 checks passed |

## Objective

Create a C17 console program that checks the five password composition rules recorded in [TASK_SPEC_AR.md](TASK_SPEC_AR.md). The program reports each rule separately and accepts only when all required rules pass.

## Reproduce

From the repository root:

    gcc -Wall -Wextra -Wpedantic -Werror -std=c17 projects/password-checker-c/password_checker.c -o password_checker
    python3 projects/password-checker-c/tests/run_tests.py --binary ./password_checker

## Recorded local validation

| Test group | Cases | Result |
|---|---:|---|
| Functional examples | 7 | PASS |
| Overlong input boundary | 1 | PASS |
| **Total** | **8** | **8/8 PASS** |

The reference build/test log names the toolchain versions used. The GitHub Actions workflow completed successfully for the recorded commit. This is CI evidence, not a trainer grade or acceptance.

## Important limitations

This is a rule-based learning exercise, not a comprehensive password-strength estimator. It does not measure guessability or entropy, check breached-password databases, or store/transmit entered passwords. Only synthetic example values should be used in demonstrations.
