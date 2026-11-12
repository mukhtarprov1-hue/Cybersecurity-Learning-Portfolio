# Screenshot checklist — Assignment 13

Original screenshots from the learner's Windows browser and PowerShell are intentionally pending until the local phase. GitHub CI is not represented as a substitute for browser screenshots.

| Filename | What to capture |
|---|---|
| 01-session-cookie-flags.png | Browser DevTools Network/Application view showing CYBERSESSID with HttpOnly, Secure, SameSite=Strict; redact cookie values |
| 02-document-cookie-comparison.png | Lab page showing DEMO_UNSAFE visible to document.cookie while DEMO_SAFE and CYBERSESSID are not present |
| 03-session-id-rotation.png | Login action and response Set-Cookie showing session ID replacement; redact both values |
| 04-authenticated-dashboard.png | Dashboard after navigation, showing authenticated state and only a short fingerprint |
| 05-csrf-and-logout-tests.png | HTTP integration tests showing CSRF 403 and logout/session destruction, or PowerShell output |

Never expose live session cookie values, CSRF tokens, or authenticated browser storage in screenshots.