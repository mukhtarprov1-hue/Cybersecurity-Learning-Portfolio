# Screenshot checklist — Assignment 13

The local automation at tools/verify-and-capture.ps1 generates these screenshots only after the local PHP and HTTP checks succeed. The source of each image is stated below. The browser images come from Microsoft Edge or Google Chrome headless mode.

| Filename | Evidence source | What it demonstrates |
|---|---|---|
| 01-document-cookie-comparison.png | Live local application page | JavaScript document.cookie shows DEMO_UNSAFE only; protected cookies remain unreadable |
| 02-session-cookie-flags.png | Actual local HTTP Set-Cookie response headers, with values redacted | HttpOnly, Secure, and SameSite=Strict on CYBERSESSID and DEMO_SAFE |
| 03-session-id-rotation.png | Actual HTTP login response; identifiers are replaced with short SHA-256 fingerprints | Session ID changes after the simulated login |
| 04-authenticated-dashboard.png | Sanitized HTML body returned by the actual authenticated dashboard request, with project CSS embedded | Authenticated navigation persists; raw session ID and CSRF token are not shown |
| 05-csrf-and-logout-tests.png | Actual PHP test output and local HTTP flow results | CSRF 403, session cookie expiry, and dashboard denial after logout |

Never expose raw session cookie values, CSRF tokens, or authenticated browser storage in screenshots. The script stores detailed local logs under evidence/local-verification/, which is git-ignored; only the report, summary, manifest, and five sanitized screenshots are pushed.