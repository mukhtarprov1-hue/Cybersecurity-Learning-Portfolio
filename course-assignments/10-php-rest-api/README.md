# Assignment 10 — Secure HTTP Request Handler & REST API (PHP)

A security-focused educational REST API that demonstrates real HTTP request handling, strict JSON parsing, method routing, bearer-token authorization, structured responses, safe local persistence, and audit events.

## Why this version stands out

- **Real CRUD API:** `GET`, `POST`, `PUT`, and `DELETE` operate on a resource collection rather than printing fixed examples.
- **Layered design:** separate HTTP application, repository, audit logger, response model, and router.
- **Defensive request parsing:** `php://input`, `getallheaders()`, JSON object validation, UTF-8 checks, allow-listed fields, and a 64 KiB body limit.
- **Authentication:** state-changing requests require an `Authorization: Bearer ...` token. `hash_equals()` is used for constant-time comparison. If `API_TOKEN` is not configured, writes fail closed with HTTP 503.
- **HTTP correctness:** meaningful status codes, `Allow`, `Location`, `WWW-Authenticate`, and empty 204 responses.
- **Security headers:** `nosniff`, `DENY`, `no-store`, `no-referrer`, and same-origin resource policy.
- **Request observability:** a unique `X-Request-ID` is returned and a JSON Lines audit record is written without storing credentials or request bodies.
- **Safer persistence:** UUIDv4 IDs, `flock()` for concurrent access, JSON validation, and temp-file replacement.
- **CORS allow-list:** browser origins are reflected only when they exactly match `API_ALLOWED_ORIGIN`.
- **Automated tests and CI:** 23 API/application tests and a Windows/Ubuntu × PHP 8.2/8.5 workflow.

## Requirements

- PHP **8.2 or newer**.
- PHP JSON extension (included in standard PHP distributions).
- No Composer packages or third-party PHP libraries are required.
- Recommended current stable line for this assignment: PHP 8.5.12. Do not use PHP 8.6 release candidates for the submission environment.

Check your installation:

    php -v
    php -m

If PowerShell says `php` is not recognized and XAMPP is installed, check `C:\xampp\php\php.exe -v`; you can run the commands with that full executable path or add `C:\xampp\php` to your Windows PATH. Prefer a current supported PHP build over an old bundled version.

## Project structure

    10-php-rest-api/
    ├── public/index.php             # HTTP entry point and response emitter
    ├── public/.htaccess             # Apache hardening hints
    ├── router.php                   # PHP built-in server router
    ├── src/
    │   ├── ApiApplication.php       # Routing, validation, auth, HTTP semantics
    │   ├── ApiException.php
    │   ├── ApiResponse.php
    │   ├── ItemRepository.php       # Locked JSON persistence
    │   ├── AuditLogger.php          # JSONL audit trail
    │   └── bootstrap.php
    ├── storage/                     # Runtime data and audit logs; outside public/
    ├── tests/run.php                # Dependency-free automated test suite
    ├── scripts/demo.ps1             # PowerShell CRUD demonstration
    ├── docs/                        # Arabic report, API contract, security, test plan
    └── .github/workflows/           # PHP 8.2/8.5 on Windows and Ubuntu

## 1. Start the local API on Windows PowerShell

Open PowerShell in the assignment directory. In **server window 1**, set a local training token and start PHP's built-in server bound to loopback only:

    $env:API_TOKEN = 'Replace-This-With-A-Long-Unique-Local-Training-Token'
    $env:API_ALLOWED_ORIGIN = 'http://localhost:3000'
    php -S 127.0.0.1:8080 router.php

Keep this terminal open. The API listens only on your own computer, not on the LAN.

## 2. Test the health endpoint

In **client window 2**:

    Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8080/api/health'

## 3. Exercise all four required methods

Set the same token in client window 2:

    $token = 'Replace-This-With-A-Long-Unique-Local-Training-Token'
    $headers = @{ Authorization = "Bearer $token" }

**GET — list items**

    Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:8080/api/items'

**POST — create an item**

    $body = @{ title = 'FIM Review'; description = 'Review a protected file baseline'; priority = 'high' } | ConvertTo-Json
    $created = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8080/api/items' -Headers $headers -ContentType 'application/json' -Body $body
    $id = $created.data.id
    $id

**GET — retrieve the created item**

    Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:8080/api/items/$id"

**PUT — replace/update the item**

    $update = @{ title = 'FIM Review Updated'; description = 'Reviewed and documented'; priority = 'normal' } | ConvertTo-Json
    Invoke-RestMethod -Method Put -Uri "http://127.0.0.1:8080/api/items/$id" -Headers $headers -ContentType 'application/json' -Body $update

**DELETE — remove the item**

    Invoke-WebRequest -Method Delete -Uri "http://127.0.0.1:8080/api/items/$id" -Headers $headers

DELETE returns HTTP 204 with no response body, as expected by HTTP semantics.

You can also run the prepared PowerShell demonstration script after starting the server:

    .\scripts\demo.ps1

The script reads the API token from the `API_TOKEN` environment variable. Set it in the client terminal before running the script.

## 4. Run automated tests

    php -l public/index.php
    php -l router.php
    php tests/run.php

The test runner is dependency-free and exercises CRUD, JSON parsing, validation, authentication, CORS, request IDs, security headers, body limits, and HTTP status behavior.

## 5. Useful HTTP behavior to demonstrate

| Scenario | Expected status |
|---|---:|
| Health / successful GET | 200 |
| Successful POST | 201 + `Location` |
| Successful PUT | 200 |
| Successful DELETE | 204, empty body |
| Malformed JSON | 400 |
| Missing/invalid bearer token | 401 |
| Missing API token configuration | 503 |
| Unsupported HTTP method | 405 + `Allow` |
| Unknown route/resource | 404 |
| Wrong content type | 415 |
| Invalid resource fields | 422 |
| Body above limit | 413 |

## 6. Runtime files

Runtime state is created under `storage/`:

- `items.json` — current resource data.
- `items.lock` — inter-process lock file.
- `audit.jsonl` — request metadata (timestamp, request ID, method, path, status, client IP).

Do not commit runtime data, audit logs, or real API tokens. They are ignored by `.gitignore`.

## Add the assignment to the portfolio index

After extracting this package into the repository root, run from this directory:

    .\scripts\register-index.ps1

The script inserts the Assignment 10 row after Assignment 09 in `course-assignments/README.md`; it does not duplicate the row if already present.

## Security and scope notes

- This is a classroom API, not a production deployment blueprint. The PHP built-in server is for local development only.
- Keep `API_TOKEN` secret; never put it in Git, screenshots, or request logs.
- The example uses a single shared bearer token. A real system should use a proper identity provider, token rotation, per-user authorization, HTTPS, and secret management.
- CORS is a browser policy, not authentication. The bearer token remains required for write operations.
- JSON file storage is useful for learning; a production service should use a database with transactions and backups.
- Audit records intentionally exclude Authorization headers and request bodies.
