# Requirement Traceability — Assignment 12

| Trainer requirement | Implementation | Verification | Evidence location |
|---|---|---|---|
| Receive `$_FILES['file_uploaded']` | public/index.php | Genuine multipart HTTP upload accepted | screenshots/local-verification/02-valid-image-upload.png |
| Check maximum size | SecureUploadService::inspectTemporaryFile() | Oversize fixture rejected | tests/run.php — 14/14 |
| Strict extension whitelist | ALLOWED_TYPES + pathinfo() | .php extension rejected | tests/run.php |
| Check actual MIME with Fileinfo | finfo(FILEINFO_MIME_TYPE) | PHP payload renamed .jpg rejected | HTTP case + screenshot 04 |
| Verify content signature/structure | getimagesize(), PDF header and EOF | Valid PNG/JPEG/PDF and malformed content cases | tests/run.php |
| Generate a random storage name | bin2hex(random_bytes(16)) | 32 hex chars + allowed extension; repeat differs | tests/run.php |
| Move uploaded file | is_uploaded_file() then move_uploaded_file() | Actual synthetic PNG transfer succeeded over local HTTP | screenshot 02 |
| Secure file permissions | POSIX 0700 / 0600; Windows NTFS ACL | NTFS ACL applied and recorded | screenshot 03 and private-storage-and-acl.txt |
| Prevent Path Traversal | Original client name is never used as destination path | Traversal text does not enter generated storage name | tests/run.php |

## Verified Windows workstation result

- PHP 8.5.12, with Fileinfo temporarily loaded from the matching PHP extension DLL; php.ini was not modified.
- PHP syntax checks: 3/3 passed.
- Policy tests: 14/14 passed.
- HTTP integration cases: 2/2 passed (valid synthetic PNG accepted; PHP-as-JPG rejected with HTTP 400).
- Screenshots: 5/5 captured.
- NTFS ACL: applied to private storage and recorded.
- Local verification report: `docs/LOCAL_VERIFICATION_REPORT.md`.

## Hosted CI result

GitHub Actions run [43142698351](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43142698351) passed 4/4 jobs on Windows/Ubuntu with PHP 8.2/8.5. Each job passed the three syntax checks and all 14 policy tests.

The local screenshots are browser-rendered captures of the actual local application responses and verification output. No personal files were used; only synthetic fixtures were uploaded.
