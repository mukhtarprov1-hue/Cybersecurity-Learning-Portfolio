# Assignment 11 — SQL Injection Defense (SQLi Defense)

**Track:** Cybersecurity Programming — Web & PHP  
**Implementation:** PHP 8.2+ · PDO · SQLite in-memory database  
**Status:** CI verified (4/4 matrix jobs); learner-side Windows execution and screenshots are pending.

## Objective

A small, self-contained PHP web demonstration reading the search term from `$_GET['username']` and comparing two ways to search a demo users table:

- **Unsafe mode:** concatenates the supplied username into SQL so the instructor can observe how SQL injection changes the query logic.
- **Safe mode:** uses PDO `prepare()`, a named parameter, and `execute()` so the supplied value remains data rather than SQL code.

The application uses `sqlite::memory:`. Every request creates and seeds a fresh temporary database; no MySQL server, persistent database file, real accounts, or external service is required.

> **Safety boundary:** The vulnerable query exists solely as a local training demonstration against synthetic in-memory records. Do not deploy it, connect it to a real database, or use it with real user data. The safe prepared-statement example is the implementation to retain.

## Requirements

- PHP 8.2 or newer.
- PDO and the `pdo_sqlite` extension enabled.
- No Composer install or MySQL service is required.

Check the extensions in PowerShell:

```powershell
& $php -m | Select-String -Pattern 'PDO|pdo_sqlite|sqlite3'
```

## Project structure

```text
11-sqli-defense/
├── index.php
├── composer.json
├── src/
│   ├── Database.php
│   └── UserSearch.php
├── tests/
│   └── run.php
├── docs/
│   ├── REPORT_AR.md
│   └── SECURITY_ANALYSIS_AR.md
└── screenshots/
    └── README.md
```

## Run on Windows PowerShell

From the repository root:

```powershell
cd F:\Cybersecurity-Learning-Portfolio\course-assignments\11-sqli-defense
$php = "F:\Tools\PHP\8.5.12\php.exe"
Test-Path $php
& $php -v
& $php -m | Select-String -Pattern 'PDO|pdo_sqlite|sqlite3'
```

Run syntax validation and automated tests:

```powershell
& $php -l .\index.php
& $php -l .\src\Database.php
& $php -l .\src\UserSearch.php
& $php -l .\tests\run.php
& $php .\tests\run.php
```

Start the local web application:

```powershell
& $php -S 127.0.0.1:8081 -t .
```

Open [http://127.0.0.1:8081](http://127.0.0.1:8081). Stop the local server with **Ctrl+C**.

## Reproduce the comparison

1. Keep **Safe — PDO Prepared Statement** selected and search for `alice`. One matching demo record should appear.
2. Paste this exact value into the username field:

   ```text
   ' OR '1'='1' -- 
   ```

3. Submit in **Unsafe — String Concatenation** mode. The intentionally vulnerable query should return all seeded demo records.
4. Submit the same input in **Safe — PDO Prepared Statement** mode. It should return zero records because the complete payload is treated as a literal username.
5. Run the automated test suite to validate both outcomes independently of the browser.

The application HTML-escapes every displayed field. Database exception details are written only to the PHP server error log; they are not returned to the browser.

## Acceptance-criteria mapping

| Requirement | Implementation | Verification |
|---|---|---|
| PDO database connection | `src/Database.php` creates `sqlite::memory:` | PHP runtime check and test runner |
| Create users table and seed examples | `Database::create()` | Normal lookup test |
| Demonstrate unsafe interpolation | `UserSearch::unsafeSearch()` | Injection test expects all seeded rows |
| Implement prepared statement | `UserSearch::safeSearch()` | Normal lookup and injection-blocking tests |
| Use `prepare()` and `execute()` | Named parameter `:username` | Source review and automated tests |
| Prevent error/schema disclosure | Generic browser error; details go to server log | Manual error-path review |
| Show result data safely | `htmlspecialchars()` via `e()` | Source review and browser test |

## Continuous integration evidence

[GitHub Actions run 43133416122](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43133416122) completed successfully across all four matrix environments: Windows and Ubuntu with PHP 8.2 and 8.5. Each environment passed PHP syntax validation and all six automated tests. This hosted CI result does not replace the learner's local browser demonstration and original screenshots.

## Evidence and report

- [Arabic technical report](docs/REPORT_AR.md)
- [Security comparison and threat analysis](docs/SECURITY_ANALYSIS_AR.md)
- [Screenshot capture checklist](screenshots/README.md)

The screenshot directory is intentionally not populated with simulated or fabricated evidence. Add genuine captures after running the application on the Windows workstation.

## Limitations

This is a teaching demonstration, not a production authentication system. It uses synthetic records, an in-memory SQLite database, and an intentionally vulnerable query path to make the difference observable. It does not implement password authentication, authorization, account management, persistent storage, CSRF protection, rate limiting, or production deployment controls.
