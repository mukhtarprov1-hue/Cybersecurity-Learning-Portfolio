# Test Plan and Results — Assignment 10

## Automated suite

Run:

    php tests/run.php

The dependency-free suite contains 23 tests:

1. Health route returns JSON 200.
2. Empty collection returns 200.
3. Missing write token returns 401.
4. POST creates resource with 201 and Location.
5. GET by ID returns created resource.
6. PUT replaces resource fields.
7. Search and limit filtering work.
8. DELETE removes resource with 204 empty body.
9. Deleted resource returns 404.
10. Malformed JSON returns 400.
11. Wrong media type returns 415.
12. Missing title returns 422.
13. Unknown fields return 422.
14. Unknown route returns 404.
15. Unsupported method returns 405 and Allow.
16. OPTIONS preflight returns 204 with methods.
17. Allowed origin receives CORS header.
18. Untrusted origin is not reflected.
19. Request ID header is returned.
20. Security headers are present.
21. Oversized body returns 413.
22. Invalid bearer token returns 401.
23. PUT on collection returns 405.

## Development environment result

- Runtime: PHP 8.4.24 (Linux build container).
- PHP syntax lint: all project PHP files passed.
- Automated suite: 23 passed, 0 failed.
- HTTP integration smoke test against the PHP built-in server: GET health (200), POST create (201), GET item (200), PUT update (200), DELETE (204), unsupported PATCH (405), missing token (401), and malformed JSON (400) all returned the expected status.
- Audit JSONL file was created outside the public document root.

This is build-container validation, not a claim that the learner's Windows machine has been tested. Re-run the commands locally before recording Windows results.

## Learner execution record

**Status: PENDING WINDOWS VERIFICATION.**

After running on the learner's Windows machine, update this section with:

- `php -v` output.
- `php tests/run.php` summary.
- Actual HTTP response screenshots for GET, POST, PUT and DELETE.
- Invalid JSON / 401 / 405 evidence where available.
- GitHub Actions run URL and final matrix status.

## Windows Local Verification — 2026-11-12

- Runtime: PHP 8.5.12 (NTS, Visual C++ 2022 x64).
- PHP syntax validation: 9 PHP files passed with no syntax errors.
- Automated test suite: 23 passed, 0 failed.
- HTTP health endpoint: GET /api/health returned HTTP 200.
- CRUD smoke test completed successfully against 127.0.0.1:8080:
  - GET collection: HTTP 200
  - POST create: HTTP 201
  - GET resource: HTTP 200
  - PUT update: HTTP 200
  - DELETE resource: HTTP 204
- Server binding: 127.0.0.1 only (local loopback).
- Overall result: PASS.


## Windows Local Verification — 2026-11-12

- Runtime: PHP 8.5.12 (NTS, Visual C++ 2022 x64).
- PHP syntax validation: all assignment PHP files passed with no syntax errors.
- Automated test suite: 23 passed, 0 failed.
- Health endpoint: GET /api/health returned HTTP 200.
- CRUD demonstration: GET collection, POST create, GET resource, PUT update, and DELETE resource completed successfully; DELETE returned HTTP 204.
- Server binding: 127.0.0.1 (local loopback only).
- Evidence: screenshots are stored in the screenshots/ directory.
- Overall result: PASS.

## Windows Local Verification — 2026-11-12

- Runtime: PHP 8.5.12 (NTS, Visual C++ 2022 x64).
- PHP syntax validation: all assignment PHP files passed with no syntax errors.
- Automated test suite: 23 passed, 0 failed.
- Health endpoint: GET /api/health returned HTTP 200.
- CRUD demonstration: GET collection, POST create, GET resource, PUT update, and DELETE resource completed successfully; DELETE returned HTTP 204.
- Server binding: 127.0.0.1 (local loopback only).
- Evidence: screenshots are stored in the screenshots/ directory.
- Overall result: PASS.
