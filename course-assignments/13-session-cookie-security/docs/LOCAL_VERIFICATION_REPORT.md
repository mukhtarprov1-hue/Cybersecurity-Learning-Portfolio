# Local Verification Report — Assignment 13

- **Result:** PASS
- **Local timestamp:** 2026-11-12T13:25:48+03:00
- **PHP runtime:** PHP 8.5.12 (cli) (built: Oct 26 2026 09:51:07) (NTS Visual C++ 2022 x64)
- **Syntax validation:** 8/8 PHP files passed
- **Policy/unit tests:** 15/15 passed
- **Real HTTP integration tests:** 11/11 passed
- **Session cookie:** HttpOnly, Secure, SameSite=Strict verified from actual Set-Cookie response header
- **Protected demo cookie:** DEMO_SAFE has HttpOnly, Secure, SameSite=Strict
- **Unprotected demo cookie:** DEMO_UNSAFE deliberately lacks HttpOnly and Secure and uses SameSite=Lax
- **Browser document.cookie:** DEMO_UNSAFE visible; DEMO_SAFE and CYBERSESSID absent from JavaScript-readable cookies
- **CSRF:** missing token rejected with HTTP 403
- **Session fixation mitigation:** login returned a different session identifier; only short SHA-256 fingerprints were retained
- **Authenticated navigation:** dashboard returned HTTP 200 and displayed the authenticated demo state
- **Logout:** session cookie expired and subsequent dashboard request redirected with HTTP 303
- **Temporary session storage:** separate session directory with restricted NTFS ACL; removed after the run
- **Screenshots:** 5/5 captured by local Edge/Chrome headless browser
- **Git branch:** feat/assignment-13-session-cookie-security

## Screenshot evidence

- screenshots/local-verification/01-document-cookie-comparison.png — actual application page and JavaScript cookie probe
- screenshots/local-verification/02-session-cookie-flags.png — sanitized actual Set-Cookie response headers
- screenshots/local-verification/03-session-id-rotation.png — actual login response and redacted session fingerprints
- screenshots/local-verification/04-authenticated-dashboard.png — sanitized actual authenticated dashboard response with project CSS
- screenshots/local-verification/05-csrf-and-logout-tests.png — policy, HTTP integration, CSRF, and logout results

## Scope and limitations

The login is a training simulation, not real credential authentication. Secure cookies were verified from actual HTTP response headers; the browser probe was loaded from localhost. Session IDs and CSRF values were not written into evidence or screenshots. The temporary session directory was deleted after the run. The PHP built-in server is for local testing only, not production hosting.