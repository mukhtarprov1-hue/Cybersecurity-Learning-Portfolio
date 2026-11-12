# Threat Model — Assignment 10

## Assets

- API resource data in storage/items.json.
- Audit history in storage/audit-chain.jsonl.
- HMAC key supplied through AUDIT_HMAC_KEY.
- API write credential supplied through API_TOKEN.
- Request correlation identifiers and HTTP security configuration.

## Trust boundaries

1. HTTP client to local PHP server.
2. API application to JSON persistence.
3. API application to audit storage.
4. Audit verifier to the HMAC key provider.

## Threats and controls

| Threat | Relevant control | Residual risk |
|---|---|---|
| Anonymous state-changing request | Bearer token + hash_equals() | Shared token is not per-user identity |
| Malformed or oversized request | Strict JSON schema and 64 KiB limit | Availability still depends on host resources |
| Cross-origin browser access | Exact CORS allow-list | CORS is not authentication |
| Concurrent JSON writes | flock() and temporary-file replacement | JSON store is not a transactional database |
| Audit event modification | HMAC-SHA256 record authentication | Key compromise permits forgery |
| Interior event deletion/reordering | Sequence and previous-HMAC chain | Valid suffix truncation needs an external checkpoint |
| Audit key exposure | Environment variable, excluded from source control | Host administrator/process can still access process environment |
| Audit storage deletion | Verification and protected backups | Local-only storage cannot prove deletion after all copies are lost |

## Security assumptions

- The HMAC key is generated with a cryptographically secure random generator and is not stored beside the log.
- The local API is bound to 127.0.0.1 for the classroom demonstration.
- The operator controls the Windows account and protects the key file.
- Audit verification is performed with the same key used to create the chain.

## Non-goals

This assignment does not claim to implement a production identity provider, hardware-backed key storage, remote immutable log service, distributed consensus, or full non-repudiation.
