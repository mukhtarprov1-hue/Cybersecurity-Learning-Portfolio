# Assignment 10 — Secure HTTP Request Handler & REST API (PHP)

A security-focused educational REST API that demonstrates real HTTP request handling, strict JSON parsing, method routing, bearer-token authorization, structured responses, and safe local persistence. The HMAC-chained audit trail is a later optional development and remains locally unverified; it is not part of the trainer's core acceptance requirements.

## Why this version stands out

- **Real CRUD API:** GET, POST, PUT, and DELETE operate on a resource collection rather than printing fixed examples.
- **Layered design:** separate HTTP application, repository, audit-chain, audit logger, response model, verifier, and router.
- **Defensive request parsing:** php://input, getallheaders(), JSON object validation, UTF-8 checks, allow-listed fields, and a 64 KiB body limit.
- **Authentication:** state-changing requests require an Authorization Bearer token. hash_equals() is used for constant-time comparison. If API_TOKEN is not configured, writes fail closed with HTTP 503.
- **HTTP correctness:** meaningful status codes, Allow, Location, WWW-Authenticate, and empty 204 responses.
- **Security headers:** nosniff, DENY, no-store, no-referrer, and same-origin resource policy.
- **Request observability:** unique X-Request-ID values link responses to audit events without storing credentials or request bodies. The later HMAC-chain writer is optional and best-effort; without AUDIT_HMAC_KEY its failure is written to the server log while the core API response remains available.
- **Later optional development — HMAC audit chain:** code and nine integrity tests are retained in this branch. CI passes, but the learner's local end-to-end validation is still pending. This enhancement is not counted as a completed trainer requirement.
- **Audit append protection:** the logger verifies the existing chain before appending and refuses to extend an invalid chain.
- **Safer persistence:** UUIDv4 IDs, flock() for concurrent access, JSON validation, and temporary-file replacement.
- **CORS allow-list:** browser origins are reflected only when they exactly match API_ALLOWED_ORIGIN.
- **Automated tests and CI:** 23 API/application tests plus a dedicated audit-integrity suite on Windows and Ubuntu with PHP 8.2 and 8.5.

## Requirements

- PHP 8.2 or newer.
- PHP JSON and Hash extensions.
- No Composer packages or third-party PHP libraries are required.
- Recommended classroom runtime: PHP 8.5.12.

Check the installation:

    php -v
    php -m

## Project structure

    10-php-rest-api/
    ├── public/
    │   ├── index.php
    │   └── .htaccess
    ├── src/
    │   ├── ApiApplication.php
    │   ├── ApiException.php
    │   ├── ApiResponse.php
    │   ├── ItemRepository.php
    │   ├── AuditChain.php
    │   ├── AuditLogger.php
    │   └── bootstrap.php
    ├── tools/
    │   └── audit_verify.php
    ├── tests/
    │   ├── run.php
    │   └── audit_integrity.php
    ├── scripts/
    │   ├── demo.ps1
    │   ├── register-index.ps1
    │   └── load-audit-key.ps1
    ├── storage/                  # Runtime data and audit chain; outside public/
    ├── docs/                     # API, architecture, threat model, audit format, reports
    └── router.php

## Optional later development — load the HMAC audit key (not required for the trainer's core task)

In Windows PowerShell, from this directory:

    .\scripts\load-audit-key.ps1

This step activates the optional HMAC audit-chain development only. It generates a 256-bit random key once, stores it outside the repository in the current Windows user's profile, and loads it into the current PowerShell process without printing the secret. The core REST API does not require this step to run its HTTP and CRUD functions.

Keep the same key for the lifetime of the audit chain. Back it up securely. If the key is lost or replaced, earlier records cannot be verified with the new key.

## 2. Start the local API

In server window 1:

    .\scripts\load-audit-key.ps1
    $env:API_TOKEN = 'Replace-This-With-A-Long-Unique-Local-Training-Token'
    $env:API_ALLOWED_ORIGIN = 'http://localhost:3000'
    php -S 127.0.0.1:8080 router.php

Keep the server bound to 127.0.0.1 for this classroom demonstration. Do not expose the PHP built-in server to a public or untrusted network.

## 3. Test the health endpoint and CRUD operations

In client window 2:

    $env:API_TOKEN = 'Replace-This-With-A-Long-Unique-Local-Training-Token'
    Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8080/api/health'

Run the complete CRUD example:

    .\scripts\demo.ps1

The script reads API_TOKEN from the client PowerShell environment. It exercises GET, POST, GET-by-ID, PUT, and DELETE. DELETE is expected to return HTTP 204 with no body.

## Optional HMAC development verification — still in progress locally

In client window 2, load the same HMAC key and verify the audit file:

    .\scripts\load-audit-key.ps1
    php tools/audit_verify.php

Expected result after API requests:

    AUDIT CHAIN: VALID
    Events verified: <number>

To verify another file:

    php tools/audit_verify.php storage/audit-chain.jsonl

The verification command exits with status 0 for a valid chain, 1 for an integrity failure, and 2 for a verifier/configuration error.

## 5. Run automated tests

Run the original API/application suite:

    php tests/run.php

Run the dedicated audit-integrity suite:

    php tests/audit_integrity.php

The optional audit suite contains nine cases for valid chaining, sequence and previous-HMAC links, event modification, interior deletion, reordering, append refusal after tampering, wrong-key rejection, minimum key length, and metadata-only logging. GitHub Actions has passed these tests, but the local Windows end-to-end run and screenshots for this optional enhancement are not yet complete.

## Optional HMAC audit-chain format and security properties (development in progress)

Audit events are written as JSON Lines to storage/audit-chain.jsonl. The HMAC key is supplied through AUDIT_HMAC_KEY and is not stored in the repository or in the event records.

The event chain uses a genesis value of 64 zeroes. Each subsequent event signs its canonical metadata plus the previous event's HMAC.

See:

- docs/AUDIT_CHAIN_FORMAT.md
- docs/THREAT_MODEL.md
- docs/SECURITY_CONTROLS.md
- docs/API_CONTRACT.md

## Important security limitations

- This is a classroom API, not a production deployment blueprint. PHP's built-in server is for local development only.
- A shared bearer token is not a user identity system or fine-grained authorization.
- The local JSON store is not a transactional database.
- HMAC chaining is tamper-evident, not tamper-proof. A party able to truncate the final records and control the only log copy can remove a valid suffix without breaking the remaining chain. Detecting this requires an independently protected checkpoint or remote append-only collector.
- Key compromise permits an attacker to forge new valid-looking records. Keep the key private and separate from the log.
- Changing the HMAC key makes old records unverifiable unless the old key is retained.
- CORS is a browser policy, not authentication.
- Production systems should use TLS, managed secrets, a dedicated identity provider, protected remote logging, backups, and a transactional database.

## Add the assignment to the portfolio index

Run:

    .\scripts\register-index.ps1

The script inserts the Assignment 10 row after Assignment 09 without duplicating it.
