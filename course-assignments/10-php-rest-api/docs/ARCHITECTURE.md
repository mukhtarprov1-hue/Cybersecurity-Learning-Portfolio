# Architecture Overview

The request path is separated from the persistence and audit paths.

    HTTP Client
        |
        v
    router.php
        |
        v
    public/index.php
        |
        +----> ApiApplication
        |          |
        |          +----> Validation / Bearer Auth / HTTP routing
        |          |
        |          +----> ItemRepository ----> storage/items.json
        |
        +----> AuditLogger
                    |
                    v
                AuditChain
                    |
                    v
           storage/audit-chain.jsonl
                    |
                    v
          tools/audit_verify.php

The only web document root is public/. Source classes, runtime storage, the HMAC key, and command-line verification tools remain outside the public document root.

Each audit event contains a monotonically increasing sequence and the HMAC of the previous event. The verifier recomputes every record using the separately supplied AUDIT_HMAC_KEY.

The audit chain detects content changes, insertion, reordering, and deletion of interior records. It cannot prove that a valid final suffix was not removed unless the latest sequence and HMAC are independently anchored outside the log's trust boundary.
