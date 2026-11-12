# Assignment 12 — Secure File Upload & Multi-Layer Validation

**Course:** Cybersecurity Programming — Web & PHP  
**Implementation:** PHP 8.2+ · Fileinfo · move_uploaded_file() · HTML forms  
**Delivery branch:** feat/assignment-12-secure-file-upload  
**Hosted CI:** verified — 4/4 jobs passed (Windows/Ubuntu × PHP 8.2/8.5), run [43142698351](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43142698351).  
**Learner workstation verification/screenshots:** completed on Windows with PHP 8.5.12 — syntax 3/3, policy tests 14/14, HTTP cases 2/2, screenshots 5/5, and NTFS ACL applied.

## Objective

Build a PHP upload endpoint that accepts only a narrow allow-list of PDF, PNG, and JPEG files, validates the actual uploaded bytes, generates a random storage name, and moves accepted files into a private directory outside the web document root.

The app is intentionally small and dependency-free. It demonstrates defence in depth rather than relying on the browser's accept attribute, the filename, or the client-supplied Content-Type header.

## Security layers

1. **HTTP upload state:** accepts POST only, handles PHP's $_FILES['file_uploaded'] error codes, and requires is_uploaded_file() before processing.
2. **Size limits:** 2 MiB application limit, non-empty file requirement, and exact comparison between the reported upload size and the actual temporary-file size. PHP's upload_max_filesize and post_max_size must also be configured appropriately.
3. **Extension allow-list:** pathinfo($originalName, PATHINFO_EXTENSION) is lower-cased and restricted to pdf, png, jpg, and jpeg.
4. **Actual MIME inspection:** PHP Fileinfo (finfo) determines the temporary file's MIME type. The browser-provided MIME header is ignored.
5. **Content structure:** image uploads are checked using getimagesize() and the PNG/JPEG image type; image dimensions are capped. PDFs must contain a %PDF- header and a trailing %%EOF marker.
6. **Random destination name:** bin2hex(random_bytes(16)) creates a 128-bit random identifier. The original filename never becomes a filesystem path.
7. **Private storage:** move_uploaded_file() moves the accepted file to storage/private/, outside public/. POSIX directory/file permissions are 0700/0600. On Windows, restrict the NTFS ACL for the account running PHP.
8. **Request protection:** a session-backed CSRF token, secure cookie flags, generic error responses, output escaping, and security response headers are used.

## Project structure

    12-secure-file-upload/
    ├── public/
    │   ├── index.php               # upload form and HTTP controller
    │   └── .htaccess               # Apache directory/header hardening
    ├── src/
    │   └── SecureUploadService.php # extension/MIME/signature/size/storage policy
    ├── storage/
    │   └── private/                # created at runtime; outside public/
    ├── tests/
    │   └── run.php                 # 14 dependency-free policy tests
    ├── tools/
    │   ├── verify.ps1              # basic local PHP lint/test checks
    │   └── verify-and-capture.ps1   # HTTP upload tests, screenshots, report, hashes, and Git push
    ├── docs/
    │   ├── REPORT_AR.md
    │   ├── TRACEABILITY.md
    │   ├── SECURITY_NOTES_AR.md
    │   └── REVIEWER_GUIDE_AR.md
    ├── screenshots/
    │   └── README.md
    ├── .gitignore
    ├── composer.json
    └── TASK_SPEC_AR.md

## Requirements

- PHP 8.2 or newer.
- PHP Fileinfo extension enabled (finfo class).
- Standard PHP file upload support.
- No Composer packages or external services are required.

Check from PowerShell:

    $php = "F:\Tools\PHP\8.5.12\php.exe"
    & $php -v
    & $php -m | Select-String -Pattern 'fileinfo|session'

If Fileinfo is not listed, enable it in the loaded php.ini or temporarily try:

    & $php -d extension=php_fileinfo.dll -m | Select-String fileinfo

Also confirm upload_max_filesize is at least 2M and post_max_size is larger than 2M:

    & $php -i | Select-String -Pattern '^upload_max_filesize|^post_max_size'

## Run on Windows PowerShell

First, update the local branch from GitHub, then run the unified verification script from the assignment directory:

    cd F:\Cybersecurity-Learning-Portfolio
    git switch feat/assignment-12-secure-file-upload
    git pull --ff-only origin feat/assignment-12-secure-file-upload
    cd .\course-assignments\12-secure-file-upload
    $php = "F:\Tools\PHP\8.5.12\php.exe"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\verify-and-capture.ps1 -PhpPath $php -ApplyPrivateNtfsAcl

The script checks PHP and Fileinfo, runs the three syntax checks and 14 policy tests, starts a temporary local PHP server, sends a genuine synthetic PNG upload and a PHP-as-JPG spoofing attempt over HTTP, verifies private storage and the NTFS ACL, captures five PNG screenshots through installed Edge/Chrome headless mode, writes a local verification report and SHA-256 manifest, then commits and pushes only the generated Assignment 12 evidence to this branch. It uses synthetic samples only and does not upload any personal files. It refuses to run from a different branch or when unrelated changes are already staged.

The script automatically chooses a free localhost port if 8082 is occupied and does not modify php.ini. To run without pushing the evidence to GitHub, append the -NoPush switch.

Manual alternative: start the local server using public/ as the only document root:

    & $php -S 127.0.0.1:8082 -t .\public

Then open http://127.0.0.1:8082 and stop the server with Ctrl+C.

Try these cases:

- Upload a genuine small PNG/JPEG/PDF: the app should accept it and show a random stored name.
- Rename PHP source content to .jpg: the MIME check should reject it.
- Rename PNG content to .jpg: the MIME check should reject it.
- Upload a .php extension: the extension allow-list should reject it.
- Try a file larger than 2 MiB: the size layer should reject it.

Accepted files remain private in storage/private/; the app deliberately provides no public download URL.

## Automated tests

Run:

    & $php .\tests\run.php

The test runner creates temporary synthetic fixtures and removes them after execution. It covers accepted PNG/JPEG/PDF content, web-shell extension/MIME mismatch, fake extension, oversize and empty files, size tampering, path-traversal names, random-name format, storage-root separation, is_uploaded_file() enforcement, and malformed PDFs.

## Acceptance criteria mapping

| Requirement from the task | Implementation | Test / evidence |
|---|---|---|
| Read $_FILES['file_uploaded'] | public/index.php | Local HTTP upload demonstration |
| Enforce maximum size | SecureUploadService::inspectTemporaryFile() | Oversize test |
| Strict extension whitelist | ALLOWED_TYPES + pathinfo() | Unsupported extension test |
| Inspect real MIME with Fileinfo | finfo(FILEINFO_MIME_TYPE) | PHP renamed .jpg test |
| Validate actual content | getimagesize(), image type, PDF header/EOF | PNG/JPEG/PDF and malformed-file tests |
| Generate random filename | bin2hex(random_bytes(16)) | 128-bit name tests |
| Move only genuine uploaded files | is_uploaded_file() then move_uploaded_file() | Fake local path rejection + browser upload |
| Prevent path traversal | Original name is never a destination path | Traversal-name test |
| Restrict storage access | storage/private/ outside public/; POSIX 0700/0600 | Storage separation test and manual ACL review |

## Continuous integration

The workflow is defined in .github/workflows/assignment-12-secure-upload.yml. [Run 43142698351](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/runs/43142698351) completed successfully: all four Windows/Ubuntu × PHP 8.2/8.5 jobs passed Fileinfo setup, three PHP syntax checks, and all 14 automated tests.

The learner's Windows run also completed the two HTTP integration cases: a genuine synthetic PNG was accepted and stored outside public/, while PHP source renamed to JPG was rejected with HTTP 400. Five screenshots, raw outputs, verification summary, SHA-256 manifest, and local report were committed to this branch. The local report records the NTFS ACL change.

## Important limitations

- Fileinfo and signature checks reject common extension spoofing and simple web-shell renaming; they do not prove that every accepted file is harmless.
- The PDF checks validate basic file markers, not full PDF sanitization. Embedded JavaScript, malicious links, parser exploits, and sophisticated polyglots require a dedicated malware scanner, content-disarm/reconstruction, or sandbox pipeline for a production service.
- The app does not publish a file-serving endpoint. If downloads are added later, they must use authorization, Content-Disposition: attachment, safe response MIME, nosniff, and a separately reviewed download controller.
- The PHP built-in server is for local coursework only. A production deployment needs web-server limits, HTTPS, malware scanning, monitoring, quotas, rate limits, and carefully managed operating-system ACLs.
- POSIX permission bits are applied on Linux/macOS. On Windows, use NTFS ACLs to grant access only to the PHP service account and authorized administrators.

## Submission route

- [Discord thread for Assignment 12](https://discord.com/channels/838962253855588402/1570091983563661484)
- [Pull Request #3](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/pull/3)

## Reports and evidence

- [Arabic task transcription](TASK_SPEC_AR.md)
- [Arabic technical report](docs/REPORT_AR.md)
- [Security notes](docs/SECURITY_NOTES_AR.md)
- [Requirement traceability](docs/TRACEABILITY.md)
- [Five-minute reviewer guide](docs/REVIEWER_GUIDE_AR.md)
- [Screenshot checklist](screenshots/README.md)
