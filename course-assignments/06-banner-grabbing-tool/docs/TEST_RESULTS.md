# Test and verification results

## Preparation environment

- Python version: 3.13.5.
- \`python -m py_compile banner_grabber.py tests/test_banner_grabber.py\`: passed.
- \`python -m unittest discover -s tests -v\`: **11 tests passed, 0 failures, 0 skipped**.

## Coverage

| Test | Purpose |
|---|---|
| Port-list parsing | Handles comma-separated ports and ranges. |
| Invalid port values | Rejects out-of-range and reversed ranges. |
| Target validation | Rejects CR/LF header-injection input. |
| Banner decoding | UTF-8 with \`errors='ignore'\`, filters control bytes, extracts the first line and \`Server\` header. |
| Immediate SSH banner | Reads a service greeting without sending a protocol request. |
| Immediate FTP greeting | Reads the FTP welcome line and records its disclosed version string. |
| HTTP HEAD exchange | Confirms the request method and parses the HTTP status and \`Server\` header. |
| Empty response | Reports \`NO_BANNER\` when the peer closes without data. |
| Read timeout | Reports \`NO_BANNER\` when TCP connected but no banner arrived before the read timeout. |
| Connection refusal | Reports \`CLOSED\` only after explicit refusal. |
| Connection timeout | Reports \`TIMEOUT\` when TCP connection establishment times out. |

## Local test safety

All network tests use temporary listeners bound to \`127.0.0.1\`. No external addresses are contacted.

## Learner Windows verification

Pending. After syncing the repository, run:

\`\`\`powershell
python -m py_compile banner_grabber.py tests/test_banner_grabber.py
python -m unittest discover -s tests -v
python banner_grabber.py --help
python banner_grabber.py 127.0.0.1 --ports 21,22,80,443,8080,8443
\`\`\`

Add actual Windows outputs/screenshots only after these commands have been run. Do not substitute preparation-environment results for Windows evidence.
