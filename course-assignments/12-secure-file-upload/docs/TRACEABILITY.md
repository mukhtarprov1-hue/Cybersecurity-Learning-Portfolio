# Requirement Traceability — Assignment 12

| Trainer requirement | Implementation | Verification | Evidence location |
|---|---|---|---|
| Receive $_FILES['file_uploaded'] | public/index.php | Real HTTP multipart upload on learner machine | screenshots/ (to be captured locally) |
| Check maximum size | SecureUploadService::inspectTemporaryFile() | Oversize fixture is rejected | tests/run.php |
| Strict extension whitelist | ALLOWED_TYPES + pathinfo() | .php extension is rejected | tests/run.php |
| Check actual MIME with Fileinfo | finfo(FILEINFO_MIME_TYPE) | PHP payload renamed .jpg is rejected | tests/run.php |
| Verify content signature/structure | getimagesize(), PDF header and EOF | Valid image/PDF and malformed content cases | tests/run.php |
| Generate a random storage name | bin2hex(random_bytes(16)) | 32 hex chars + allowed extension; repeat differs | tests/run.php |
| Move uploaded file | is_uploaded_file() then move_uploaded_file() | Local path masquerading as upload is rejected; actual transfer is manual HTTP test | tests/run.php + local browser proof |
| Secure file permissions | POSIX 0700 / 0600; Windows NTFS ACL guidance | Code path and host ACL review | docs/SECURITY_NOTES_AR.md |
| Prevent Path Traversal | Original client name is never used as a destination path | ../../avatar.png does not enter generated storage name | tests/run.php |

## Status vocabulary

- Source implementation and automated policy tests are present.
- PHP lint and 14 tests passed in the assistant's PHP 8.4.24 build environment.
- Learner's Windows execution, genuine browser upload, screenshots, and hosted GitHub Actions results remain pending until their actual outputs are observed.
