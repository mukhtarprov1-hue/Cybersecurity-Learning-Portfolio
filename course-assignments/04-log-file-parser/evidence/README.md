# Assignment 04 — Execution evidence

The files in this directory are captured outputs from the local reference build and test runs.

- `build-and-test.log`: strict GCC build and all ten integration tests.
- `sample-failed.log`: two matching records, lines 2 and 5.
- `sample-404.log`: one matching record, line 4.
- `no-match.log`: zero-match behavior and summary.
- `missing-file.log`: missing-file error and non-zero exit.
- `argument-validation.log`: usage message for invalid arguments.

The five SVG files in `../screenshots/` are rendered from these output logs (where applicable) for convenient viewing in GitHub. They are not raw desktop screenshots. The synthetic source log is generated reproducibly by `../samples/create_sample.py` and is intentionally not committed as a generated binary/text fixture.
