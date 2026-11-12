# Test Plan and Results — Assignment 10

## Original API/application suite

Run:

    php tests/run.php

The dependency-free suite contains 23 tests covering:

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

## Tamper-evident audit-chain suite

Run:

    php tests/audit_integrity.php

The dedicated suite contains 9 tests for:

1. Empty chain validation.
2. Valid multi-event chain and previous-HMAC links.
3. Modified event detection.
4. Interior event deletion detection.
5. Event reordering detection.
6. Refusal to append to a tampered chain.
7. Wrong-key verification failure.
8. Rejection of keys shorter than 32 bytes.
9. Metadata-only audit logging.

## Development environment result

- Runtime: PHP 8.4.24 (Linux build container).
- Original API/application suite: 23 passed, 0 failed.
- HTTP integration smoke test: GET health (200), POST create (201), GET item (200), PUT update (200), DELETE (204), unsupported PATCH (405), missing token (401), and malformed JSON (400) returned expected statuses.
- The HMAC audit-chain implementation is introduced in the feature branch; its dedicated Windows and CI execution must be confirmed before merging.

## Learner Windows execution record — original API version

- Runtime: PHP 8.5.12 (NTS, Visual C++ 2022 x64).
- PHP syntax validation: 9 PHP files passed with no syntax errors.
- Original API/application suite: 23 passed, 0 failed.
- Health endpoint: GET /api/health returned HTTP 200.
- CRUD demonstration against 127.0.0.1:8080 completed successfully:
  - GET collection: HTTP 200
  - POST create: HTTP 201
  - GET resource: HTTP 200
  - PUT update: HTTP 200
  - DELETE resource: HTTP 204
- Server binding: 127.0.0.1 only.
- Evidence: six Windows screenshots were captured for the original API version.

## Later optional HMAC enhancement — CI passed, local completion pending

The HMAC audit-chain enhancement is later optional development and is not part of the trainer's original core acceptance scope.

- The dedicated suite contains nine integrity tests.
- GitHub Actions passed the nine-test suite in the Windows/Ubuntu × PHP 8.2/8.5 matrix.
- The learner's Windows end-to-end verification of key loading, real API events, independent chain verification, and evidence capture remains pending.
- Do not claim the optional HMAC enhancement is locally complete until all of those steps are run and recorded.

The original API requirement remains locally verified as recorded above: nine PHP syntax checks, 23/23 core tests, and successful Health/CRUD HTTP calls.

