# HMAC-Chained Audit Record Format

## Purpose

The API audit trail is stored as JSON Lines in storage/audit-chain.jsonl. Each line is one versioned event whose HMAC-SHA256 covers the event metadata and the HMAC of the previous event.

## Event structure

Each event contains:

- version: audit schema version (currently 1).
- sequence: strictly increasing event number, starting at 1.
- timestamp_utc: UTC timestamp.
- request_id: request correlation identifier.
- method: HTTP method.
- path: URL path only; query values are excluded.
- status: HTTP response status code.
- client_ip: peer address observed by the local server.
- previous_hmac: HMAC of the preceding record, or 64 zeroes for the first record.
- hmac: HMAC-SHA256 over the canonical JSON encoding of all preceding fields.

The canonical field order is fixed in src/AuditChain.php. JSON uses unescaped Unicode/slashes and exception-based encoding.

## Verification

Run:

    php tools/audit_verify.php

Or supply another path:

    php tools/audit_verify.php storage/audit-chain.jsonl

The verifier reads AUDIT_HMAC_KEY from the process environment. It checks schema, sequence continuity, previous-record linkage, and each HMAC using hash_equals().

## Key management

- AUDIT_HMAC_KEY must contain at least 32 bytes.
- Generate a high-entropy key using PHP random_bytes(32) and encode it as hexadecimal.
- Keep the key outside the repository and outside the audit log.
- Preserve the same key to verify historical records. Key rotation requires a deliberate, documented transition; changing the key makes old records unverifiable unless their original key is retained.
- Never print, commit, screenshot, or place the key in request headers or audit events.

## What this design detects

With the correct key, it detects changes to event fields, invalid HMAC values, reordering, insertion, and deletion of interior records. It refuses to append to a chain that fails verification.

## Important limitation

A party who can delete the final records and also control the only copy of the log may truncate a valid suffix without leaving a broken remaining chain. Detecting this requires a trusted external checkpoint, remote append-only collector, protected backup, or independently stored latest sequence/HMAC. Therefore this is tamper-evident, not tamper-proof or non-repudiation by itself.
