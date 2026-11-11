# Security Controls and Design Rationale

| Control | Implementation | Purpose |
|---|---|---|
| Bearer authentication for writes | Authorization header + `hash_equals()` | Prevent anonymous state changes |
| Fail-closed configuration | 503 when API_TOKEN is unset | Avoid accidental open write access |
| Strict JSON parsing | JSON_THROW_ON_ERROR + object-only payload | Reject malformed or unexpected body types |
| Input allow-list | title, description, priority only | Reduce mass-assignment risk |
| Bounded request size | 64 KiB maximum | Limit memory abuse |
| HTTP method allow-list | Endpoint-specific method lists | Enforce API contract and 405/Allow |
| Security response headers | nosniff, DENY, no-store, no-referrer | Reduce browser-side exposure |
| CORS allow-list | exact configured Origin match | Avoid wildcard cross-origin exposure |
| UUID resource identifiers | random UUIDv4 | Avoid predictable sequential IDs |
| File locking | flock() around JSON store operations | Prevent concurrent writes from clobbering each other |
| Temp-file replacement | write temp then rename | Reduce partial JSON writes |
| Audit trail | JSONL metadata only | Preserve request trace without recording secrets/body |
| Request correlation | X-Request-ID | Link client response to server-side log entry |

## Residual limitations

- A single shared bearer token is not user identity or fine-grained authorization.
- The local JSON store is not a substitute for a transactional database.
- A local audit file can be modified by an administrator or process with filesystem write privileges.
- The PHP built-in web server is not a production deployment server.
- HTTPS and production secrets management are outside this classroom scope.
