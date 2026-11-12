# Local evidence — completed

The Windows workstation verification has been executed and the resulting evidence has been committed to this branch.

Included under `evidence/local-verification/`:

- `php-version.txt`, `php-ini.txt`, and `php-modules.txt`
- `php-lint.txt` — 3/3 syntax checks
- `automated-tests.txt` — 14/14 policy tests
- `http-valid-upload-response.html` — genuine synthetic PNG accepted
- `http-spoofed-upload-response.html` — PHP source renamed to JPG rejected
- `private-storage-and-acl.txt` — private storage and NTFS ACL review
- `verification-summary.json`
- `SHA256SUMS.txt`

The five browser evidence images are stored under `screenshots/local-verification/`. The Arabic local report is `docs/LOCAL_VERIFICATION_REPORT.md`.

No private user documents or real uploads were committed. Runtime uploads remain outside Git under the private storage directory.
