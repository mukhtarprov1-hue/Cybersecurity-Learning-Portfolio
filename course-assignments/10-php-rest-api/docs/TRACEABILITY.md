# Requirement Traceability — Assignment 10

| Trainer requirement | Implementation | Evidence/test |
|---|---|---|
| JSON response content type | public/index.php response emitter | HTTP response headers |
| Read request method | `$_SERVER['REQUEST_METHOD']` | GET/POST/PUT/DELETE integration demo |
| Read incoming headers | `getallheaders()` with Authorization fallback | Bearer token tests |
| Read body from php://input | public/index.php bounded stream read | JSON integration requests |
| Parse JSON | `json_decode(..., JSON_THROW_ON_ERROR)` | malformed JSON test |
| Distinguish HTTP methods | ApiApplication route/method allow-lists | 405 + Allow tests |
| Correct HTTP status | response model and exception mapping | CRUD/status tests |
| Pretty JSON output | JSON_PRETTY_PRINT and JSON_UNESCAPED_UNICODE | CLI/API response inspection |
| Authorization header handling | Bearer authentication for writes | missing/invalid token tests |

## Advanced additions

- CRUD resource persistence with UUIDv4 IDs.
- Strict request schema, content-type check, UTF-8 validation and body limit.
- Request IDs and JSONL audit metadata.
- Security headers and exact-origin CORS allow-list.
- Locked and temp-file-replaced JSON storage.
- CI matrix for Windows/Ubuntu and PHP 8.2/8.5.
