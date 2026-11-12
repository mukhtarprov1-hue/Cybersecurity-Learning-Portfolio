# Requirements Traceability — Assignment 10

## A. Trainer's requested core requirements — complete

| Trainer requirement | Implementation | Evidence/test |
|---|---|---|
| JSON response content type | public/index.php response emitter | HTTP response headers |
| Read request method | $_SERVER['REQUEST_METHOD'] | GET/POST/PUT/DELETE integration demo |
| Read incoming headers | getallheaders() with Authorization fallback | Bearer token tests |
| Read body from php://input | public/index.php bounded stream read | JSON integration requests |
| Parse JSON | json_decode(..., JSON_THROW_ON_ERROR) | malformed JSON test |
| Distinguish HTTP methods | ApiApplication route/method allow-lists | 405 + Allow tests |
| Correct HTTP status | response model and exception mapping | CRUD/status tests |
| Pretty JSON output | JSON_PRETTY_PRINT and JSON_UNESCAPED_UNICODE | CLI/API response inspection |
| Authorization header handling | Bearer authentication for writes | missing/invalid token tests |

### Latest recorded local verification for the core task

- PHP 8.5.12 on Windows.
- PHP syntax: 12/12 passed across assignment PHP files (excluding vendor).
- Core API suite: 23/23 passed.
- Health and CRUD HTTP statuses: 200, 201, 200, 200, and 204 as expected in the recorded local demonstration.
- Worktree was clean after the latest test run.

See docs/TEST_RESULTS.md and docs/REPORT_AR.md.

## B. Later optional development — HMAC audit chain (incomplete end-to-end locally)

| Enhancement | Implementation | Current status |
|---|---|---|
| HMAC-SHA256 chained metadata events | AuditChain.php / AuditLogger.php | Retained in branch; optional development in progress |
| Independent chain verification | tools/audit_verify.php | Code present; verification against a real API-generated local log remains pending |
| Tamper/interior deletion/reorder tests | tests/audit_integrity.php | 9/9 isolated tests pass locally and in CI |
| External key handling | scripts/load-audit-key.ps1 | Code present; full local key-loading and runtime workflow still pending |

The HMAC audit-chain work was added after the original trainer requirements. It is not required to mark the REST API task complete. Do not delete these files. The nine isolated tests passing does not mean the complete local end-to-end enhancement is finished: key loading, live API event generation, independent verification of the real log, and local evidence capture remain to be completed.

See docs/DEVELOPMENT_STATUS_AR.md for the detailed status and safe handling of runtime audit files.
