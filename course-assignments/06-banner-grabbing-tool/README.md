# Assignment 06 — Banner Grabbing Tool

**Track:** Python for Cybersecurity  
**Language:** Python 3  
**Purpose:** Authorized TCP service fingerprint collection

## 1. Objective

The tool connects to selected TCP service ports and retrieves a service banner when available. SSH/FTP may send greetings immediately. HTTP services are interactive, so the tool sends a basic \`HEAD\` request and reads the response. HTTPS ports perform a TLS handshake before sending \`HEAD\`.

**Authorization:** Use only against systems you own, isolated labs, or targets you have explicit permission to assess. The default examples use \`127.0.0.1\`.

## 2. Contents

| File | Purpose |
|---|---|
| \`banner_grabber.py\` | Main command-line application |
| \`tests/test_banner_grabber.py\` | 11 local/deterministic tests |
| \`TASK_SPEC_AR.md\` | Arabic transcription of the one-page handout |
| \`docs/REPORT_AR.md\` | Arabic implementation report |
| \`docs/TEST_RESULTS.md\` | Test outcomes and limitations |
| \`docs/TRACEABILITY.md\` | Requirement-to-code/test mapping |
| \`screenshots/README.md\` | Genuine screenshot instructions |
| \`requirements.txt\` | Standard-library-only dependency declaration |

## 3. Requirements

- Python 3.10 or newer recommended.
- No third-party packages.
- Network access to the authorized target.

## 4. Run the tool

Run commands from this directory.

\`\`\`powershell
python banner_grabber.py --help
python banner_grabber.py 127.0.0.1
python banner_grabber.py 127.0.0.1 --ports 21,22,80,443,8080,8443
python banner_grabber.py 127.0.0.1 --ports 21-25,80,443
python banner_grabber.py 127.0.0.1 --ports 21,22,80 --timeout 3
\`\`\`

Change HTTP/HTTPS port sets explicitly:

\`\`\`powershell
python banner_grabber.py 127.0.0.1 --ports 80,8080,443,8443 --http-ports 80,8080 --https-ports 443,8443
\`\`\`

For a self-signed certificate in an authorized lab only, certificate verification can be disabled:

\`\`\`powershell
python banner_grabber.py 127.0.0.1 --ports 8443 --https-ports 8443 --no-verify-tls
\`\`\`

Do not disable TLS verification in normal production checks.

## 5. How it works

1. Validates the target and parses selected ports (maximum 256 distinct ports per run).
2. Creates TCP connections using \`socket.create_connection()\`.
3. Waits for immediate greetings from services such as SSH/FTP.
4. Sends \`HEAD / HTTP/1.1\` with a Host header to configured HTTP ports.
5. For configured HTTPS ports, completes TLS before sending HEAD.
6. Receives at most \`recv(1024)\` bytes.
7. Decodes using \`decode('utf-8', errors='ignore')\`, filters control characters, and extracts the first line using \`splitlines()[0]\` when present.
8. Displays the detected banner, HTTP Server header, no-banner status, or connection error.
9. Closes the socket and prints a summary.

## 6. Result states

| State | Meaning |
|---|---|
| \`BANNER_FOUND\` | Readable banner/response bytes were received. |
| \`NO_BANNER\` | TCP connected, but the peer was silent, closed without data, or TLS/protocol exchange yielded no banner. |
| \`CLOSED\` | The connection was explicitly refused. |
| \`TIMEOUT\` | TCP connection establishment timed out. |
| \`BLOCKED\` | The local OS/security policy denied the attempt. |
| \`ERROR\` | Another connection-stage error occurred. |

A connected but silent service is not labeled closed. The tool reports only what a service actually discloses; it does not infer an operating system from an absent banner.

## 7. Tests

\`\`\`powershell
python -m py_compile banner_grabber.py tests/test_banner_grabber.py
python -m unittest discover -s tests -v
\`\`\`

The 11 tests use temporary TCP listeners bound to \`127.0.0.1\` to simulate SSH, FTP, and HTTP. No external host is contacted.

## 8. Scope and safety

- TCP only; UDP banner grabbing is not implemented.
- Only the first 1024 response bytes are read, per the handout.
- No brute force, exploit attempts, authentication attempts, or vulnerability tests are performed.
- HTTP HEAD is a minimal read-oriented request.
- TLS certificate validation is enabled by default.
- Assess only systems you own or have explicit permission to test.

## 9. Evidence status

The source and test suite have passed in the preparation environment (Python 3.13.5). Windows execution evidence is pending until the learner runs the commands locally. Genuine screenshots should be added to \`screenshots/\`; no terminal images are fabricated.
