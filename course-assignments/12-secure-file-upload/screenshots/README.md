# Evidence checklist — Assignment 12

The local script tools/verify-and-capture.ps1 creates this evidence set after the local PHP checks and real HTTP upload cases succeed. It uses the installed Microsoft Edge or Google Chrome in headless mode to capture rendered evidence pages; no mock images are generated.

| File name | What it shows | Capture source |
|---|---|---|
| 01-php-runtime-fileinfo.png | PHP version, Fileinfo module, and upload settings | Browser rendering of captured local runtime output |
| 02-valid-image-upload.png | Actual application success response for a genuine synthetic PNG, including its generated storage name and MIME type | Saved HTTP response from the local PHP app |
| 03-private-storage-result.png | Verified private storage path, file size, SHA-256, and NTFS ACL result | Captured local filesystem and icacls output |
| 04-spoofed-php-as-jpg-rejected.png | Actual application rejection response for PHP source uploaded under a JPG name | Saved HTTP response from the local PHP app |
| 05-automated-tests.png | Three PHP syntax checks and all 14 automated policy tests | Captured local command output |

The script writes the raw outputs and a SHA-256 manifest under evidence/local-verification/, updates docs/LOCAL_VERIFICATION_REPORT.md, and pushes the report, raw evidence, and five PNG files to the Assignment 12 branch. It does not stage or publish files from storage/private/. Only synthetic test fixtures are used.
