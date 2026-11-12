# Assignment 13 — Session & Cookie Security

**Course:** Cybersecurity Programming — Web & PHP  
**Language:** PHP 8.2+  
**Branch:** feat/assignment-13-session-cookie-security  
**Status:** Source and tests are implemented; hosted GitHub Actions and learner-workstation evidence are pending until the branch workflow completes and the learner later performs the local stage.

## Objective

Demonstrate secure PHP session management and cookie flags, compare a protected cookie against an intentionally unprotected demonstration cookie, and prove that the session identifier changes after a successful login event.

This is a focused educational lab. The login button simulates a successful authentication event; it is not a real username/password authentication system and must not be used as one.

## What is implemented

### Session hardening

- Configure cookie parameters before session_start() using the PHP options-array API.
- Session cookie name: CYBERSESSID.
- HttpOnly=true, Secure=true by default, SameSite=Strict, and Path=/.
- Enable session.use_strict_mode=1 and session.use_only_cookies=1.
- Disable URL-based session IDs using session.use_trans_sid=0.
- Rotate the session ID with session_regenerate_id(true) after the simulated login event.
- Keep only a short SHA-256 fingerprint for display; never render the raw session ID.

### Cookie comparison

- DEMO_SAFE: HttpOnly; Secure; SameSite=Strict.
- DEMO_UNSAFE: deliberately lacks HttpOnly and Secure and uses SameSite=Lax; its value is a public, non-secret lab marker only.
- public/assets/cookie-probe.js reads document.cookie and displays the visible cookie names. The browser should show DEMO_UNSAFE but not DEMO_SAFE or CYBERSESSID.

### CSRF and navigation

- Session-backed 256-bit CSRF token on state-changing POST forms.
- Constant-time token comparison using hash_equals().
- Token rotation after the login event.
- Protected dashboard requires an authenticated session.
- Logout validates CSRF, expires the session cookie, and destroys the server-side session.

### Security headers

The app sends X-Content-Type-Options: nosniff, X-Frame-Options: DENY, Referrer-Policy: no-referrer, Cache-Control: no-store, and a restrictive Content Security Policy.

## Project structure

    13-session-cookie-security/
    ├── public/
    │   ├── index.php
    │   ├── login.php
    │   ├── dashboard.php
    │   ├── logout.php
    │   ├── .htaccess
    │   └── assets/
    │       ├── cookie-probe.js
    │       └── style.css
    ├── src/
    │   ├── SessionSecurity.php
    │   └── bootstrap.php
    ├── tests/
    │   ├── run.php
    │   └── http_integration.php
    ├── docs/
    │   ├── REPORT_AR.md
    │   ├── SECURITY_ANALYSIS_AR.md
    │   ├── TRACEABILITY.md
    │   └── REVIEWER_GUIDE_AR.md
    └── screenshots/
        └── README.md

## Requirements

PHP 8.2+ with the session extension. No Composer packages are required.

## Automated tests

    $php = "F:\Tools\PHP\8.5.12\php.exe"
    & $php .\tests\run.php
    & $php .\tests\http_integration.php

The policy suite has 15 tests. The HTTP integration suite starts a loopback-only PHP server and has 11 tests, including exact Set-Cookie attributes, CSRF rejection, session ID rotation, cross-page persistence, logout, and dashboard access denial after logout.

## Local browser review (deferred until the GitHub-first submission phase is complete)

Start the local server with the public directory as the document root:

    & $php -S 127.0.0.1:8083 -t .\public

Open http://localhost:8083 (or use a local HTTPS endpoint). Secure is enabled by default; a browser may refuse to persist Secure cookies on a plain HTTP IP origin. Do not turn off Secure for real deployments. For a strictly isolated non-production HTTP-only lab experiment, APP_SESSION_SECURE=0 can be set before starting PHP, but the Set-Cookie header will then not satisfy the Secure-cookie acceptance criterion.

## Acceptance mapping

| Trainer requirement | Implementation | Verification |
|---|---|---|
| Set cookie parameters before session start | SessionSecurity::configureAndStart() | Unit tests + Set-Cookie HTTP test |
| HttpOnly prevents JS cookie read | CYBERSESSID and DEMO_SAFE use HttpOnly | Browser document.cookie probe + HTTP attributes |
| SameSite Strict | Protected cookies use Strict | Set-Cookie header assertions |
| Secure flag | Protected cookies use Secure by default | Set-Cookie header assertions |
| Regenerate ID after login | session_regenerate_id(true) | HTTP test compares old and new session cookie values |
| Session persists across navigation | Dashboard reads authenticated session state | HTTP navigation integration test |
| Logout ends session | CSRF-protected POST expires cookie and destroys session | HTTP test attempts dashboard access after logout |
| CSRF control | 256-bit session token and hash_equals() | Missing token returns HTTP 403 |
| Compare protected/unprotected cookies | DEMO_SAFE vs DEMO_UNSAFE plus document.cookie probe | Unit and HTTP header assertions; manual browser evidence pending |

## Important limitations

- The login action is explicitly a simulation, not real authentication. A production service must authenticate credentials against a proper identity store and apply password hashing, account controls, and authorization.
- SameSite=Strict is defence in depth, not a substitute for CSRF tokens, origin validation, or authorization.
- HttpOnly blocks JavaScript reads of the cookie; it does not stop XSS from making authenticated requests in the user's browser.
- Secure requires HTTPS in production. The PHP built-in server is not an HTTPS production server.
- Session timeouts, MFA, central revocation, monitoring, and concurrent-session policies are future hardening work.

## CI

The workflow .github/workflows/assignment-13-session-cookie-security.yml checks PHP syntax, 15 unit tests, and 11 HTTP integration tests on Windows and Ubuntu with PHP 8.2 and 8.5.

## Submission

The Discord thread for Assignment 13 is in the Cybersecurity Camp server. Use the instructor's specific Assignment 13 thread when submitting.