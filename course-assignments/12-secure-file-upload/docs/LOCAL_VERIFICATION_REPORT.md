# Local Verification Report — Assignment 12

- **Result:** PASS
- **Timestamp:** 2026-11-12T13:15:29+03:00
- **Operating system:** Microsoft Windows NT 10.0.22631.0
- **PHP:** PHP 8.5.12 (cli) (built: Oct 26 2026 09:51:07) (NTS Visual C++ 2022 x64)
- **Fileinfo:** enabled (Temporarily loaded from 'F:\Tools\PHP\8.5.12\ext\php_fileinfo.dll'; php.ini unchanged)
- **Syntax checks:** 3/3 passed
- **Policy tests:** 14/14 passed
- **HTTP genuine PNG upload:** accepted and stored under storage/private with a random name
- **HTTP PHP-as-JPG test:** rejected with HTTP 400
- **NTFS ACL:** Inheritance removed; Full Control granted to the current account, local Administrators, and SYSTEM.
- **Browser screenshots:** 5/5 captured
- **Git branch:** feat/assignment-12-secure-file-upload

## Evidence

Raw evidence: evidence/local-verification/

Screenshots:
- screenshots/local-verification/01-php-runtime-fileinfo.png
- screenshots/local-verification/02-valid-image-upload.png
- screenshots/local-verification/03-private-storage-result.png
- screenshots/local-verification/04-spoofed-php-as-jpg-rejected.png
- screenshots/local-verification/05-automated-tests.png

Only synthetic samples were uploaded. The session CSRF token is redacted from saved HTML. The test upload stays in private storage and is not added to Git.