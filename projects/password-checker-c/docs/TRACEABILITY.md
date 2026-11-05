# Requirements Traceability — Assignment 01: Password Checker

This table maps the known task requirements to the public implementation, functional tests, and evidence. It does not invent trainer grading weights.

| ID | Requirement recorded | Implementation | Test/evidence |
|---|---|---|---|
| R-01 | Password length must be greater than 8 | password_checker.c — length > 8 | TC-01 and TC-02 reject length 8; TC-04 accepts a length-9 value |
| R-02 | At least one uppercase English letter | isupper() and has_uppercase | TC-03 rejects lower-only input; TC-04 includes uppercase |
| R-03 | At least one lowercase English letter | islower() and has_lowercase | TC-05 rejects upper-only input; TC-04 includes lowercase |
| R-04 | At least one digit | isdigit() and has_number | TC-06 rejects input without a digit; TC-04 includes digits |
| R-05 | At least one punctuation/symbol character | ispunct() and has_symbol | TC-07 rejects input without a symbol; TC-04 includes ! |
| A-01 | Require all rules together | combined logical AND in final acceptance condition | TC-01 through TC-07 |
| A-02 | Bound input and reject overlong input | fgets() with 255-character maximum and explicit overlong detection | 256-character boundary test |
| A-03 | Do not treat whitespace as a symbol | ispunct() classification | Documented in README; add a dedicated whitespace test if the trainer asks for it |

## Verified evidence

- Public Actions run: [42074144672 — SUCCESS](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/42074144672)
- Hosted runner: Ubuntu 24.04.5
- Observed test output: seven functional cases plus the 256-character boundary check, all passed.
- Local reference validation log: [assignment landing-page evidence log](../../../course-assignments/01-password-checker/evidence/build-and-test.log)

The official trainer rubric, if supplied separately, takes precedence over this traceability checklist.
