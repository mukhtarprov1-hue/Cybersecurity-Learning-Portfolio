# Requirements Traceability — Assignment 10

| Requirement / enhancement | Implementation | Evidence |
|---|---|---|
| JSON response content type | ApiResponse and public entry point | tests/run.php |
| Read request method and URI | public/index.php | HTTP CRUD demo |
| Read request headers | getallheaders() and server fallback | authentication/CORS tests |
| Parse JSON request body | ApiApplication | malformed JSON and validation tests |
| GET, POST, PUT, DELETE | ApiApplication resource routes | CRUD tests and demo.ps1 |
| Correct HTTP status codes | ApiException and ApiResponse | API contract and tests |
| Bearer authentication | authorizeMutation() with hash_equals() | missing/invalid token tests |
| Request size and field validation | body limit and allow-list schema | 413 and 422 tests |
| CORS and security headers | baseHeaders(), corsHeaders() | CORS/security tests |
| Safe JSON persistence | ItemRepository with flock() and temp replacement | repository tests |
| Request correlation and audit | X-Request-ID and AuditLogger | request ID test |
| HMAC-chained audit events | AuditChain with HMAC-SHA256 | tests/audit_integrity.php |
| Detect modified audit records | independent full-chain verification | tamper test |
| Detect interior deletion/reordering | sequence + previous-HMAC linkage | deletion/reorder tests |
| Refuse append after tampering | append verifies chain under exclusive lock | append-refusal test |
| Keep HMAC key outside source repository | load-audit-key.ps1 and environment variable | key-management documentation |
| Threats and residual risks documented | THREAT_MODEL.md and AUDIT_CHAIN_FORMAT.md | architecture/security review |
