# Assignment 11 - Local Verification Report

- Status: **PASS**
- Date: 2026-11-12 01:49:46 +03:00
- PHP: 8.5.12
- PDO drivers: sqlite
- Syntax checks: 4/4 passed
- Automated tests: 6 passed, 0 failed
- Local test server: http://127.0.0.1:8081 (stopped automatically after capture)

## HTTP validation

| Case | HTTP | Expected records | Actual records | Result |
|---|---:|---:|---:|---|
| Safe normal search | 200 | 1 | 1 | PASS |
| Unsafe SQLi demonstration | 200 | 5 | 5 | PASS |
| Safe SQLi blocked | 200 | 0 | 0 | PASS |

## Screenshots

| File | Description | Bytes | SHA-256 |
|---|---|---:|---|
| 01-php-runtime-and-sqlite-extension.png | PHP Runtime and SQLite Extension Check | 53283 | B4061B9B342AB47D720491D40A1D194C1F54024342E637A69DC91B79F3890EB6 |
| 05-automated-tests.png | Assignment 11 Automated Tests | 42135 | 5EEA51C76B2891BF458A6AA384E5FED4C02DBFD0B92E3E33F814B0FE02A39594 |
| 02-safe-normal-search.png | Safe normal lookup | 91124 | F550D1D735A6C56DCFAC5E06D9C0F0355EA89C0E821C4D61ED7D641113CBC583 |
| 03-unsafe-sqli-demonstration.png | Unsafe SQLi demonstration | 100543 | 0FC19055629F712D1DFAC3E073CB646817A3A786A2D47E828BF97E2D337AB2CE |
| 04-safe-sqli-blocked.png | Prepared statement blocks SQLi | 90335 | 418A32FF03C549C47DAAB1965AF3C86EEF3F67CFBDF3FBD26325C4746CBD97A6 |

## Raw evidence

Raw runtime, PHP INI, modules, PDO driver, syntax, test, HTTP, and server logs are in evidence/local-verification/. SHA256SUMS.txt records hashes of the report, images, and raw evidence. SQL injection was tested only against the synthetic SQLite in-memory lab. The intentionally unsafe query must not be deployed.