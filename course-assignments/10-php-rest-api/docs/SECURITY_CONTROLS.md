# Security Controls and Design Rationale

| Control | Implementation | Purpose |
|---|---|---|
| Bearer authentication for writes | Authorization header + hash_equals() | Prevent anonymous state changes |
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
| Request correlation | X-Request-ID | Link client response to server-side audit event |
| HMAC-chained audit | HMAC-SHA256 over canonical metadata + previous HMAC | Detect event modification and chain discontinuity |
| Sequence validation | monotonic sequence starting at 1 | Detect insertion, reordering, and interior deletion |
| Append refusal | verify existing chain before appending | Avoid extending a corrupted chain |
| Separate key management | AUDIT_HMAC_KEY from process environment; local loader stores key outside repository | Keep signing key separate from audit data |
| Metadata-only logging | method, path, status, request ID, client IP | Avoid recording bearer credentials or request bodies |

## HMAC audit-chain design

The runtime audit file is storage/audit-chain.jsonl. The original legacy audit.jsonl file is not reused or overwritten. Each event has a schema version, sequence, UTC timestamp, request ID, method, path, status, client IP, previous_hmac, and hmac.

The independent verifier is tools/audit_verify.php. It checks every record using the original key. The audit-integrity test suite deliberately changes, deletes, and reorders records to prove that validation fails.

## Residual limitations

- A single shared bearer token is not user identity or fine-grained authorization.
- The local JSON store is not a substitute for a transactional database.
- HMAC chaining is tamper-evident, not tamper-proof. Deletion of a valid trailing suffix cannot be detected without an independently protected latest checkpoint or remote append-only collector.
- Key compromise permits valid-looking record forgery. Keep the key separate from the log and repository.
- A local audit file can still be deleted by an administrator or process with filesystem write privileges.
- Verification reads the chain from the beginning; this classroom implementation favors clarity and complete verification over very large-log performance.
- The PHP built-in web server is not a production deployment server.
- HTTPS, remote log shipping, hardware-backed key storage, and production secrets management are outside this classroom scope.
