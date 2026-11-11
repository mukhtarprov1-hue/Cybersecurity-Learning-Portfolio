# Assignment 05 — Multithreaded Port Scanner

**Track:** Python for Cybersecurity  
**Language:** Python 3  
**Implementation:** TCP sockets + \`concurrent.futures.ThreadPoolExecutor\`

[![Assignment 05 CI](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/workflows/assignment-05-port-scanner.yml/badge.svg)](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/workflows/assignment-05-port-scanner.yml)

## Submission overview

This assignment implements a bounded TCP connect scanner for one IPv4 target. It checks a configurable port range concurrently, prints discovered open ports as tasks finish, and reports a result summary and elapsed time.

**Authorization:** Use this scanner only against systems you own, your isolated lab, or targets for which you have explicit written permission. The default example scans \`127.0.0.1\` only.

## Review this package

| Item | Location | Purpose |
|---|---|---|
| Original task transcription | [TASK_SPEC_AR.md](TASK_SPEC_AR.md) | Arabic brief transcribed from the one-page assignment handout |
| Main source | [port_scanner.py](port_scanner.py) | TCP connect scanner implementation |
| Unit tests | [tests/test_port_scanner.py](tests/test_port_scanner.py) | Local and deterministic tests, including Windows Winsock handling |
| Arabic report | [docs/REPORT_AR.md](docs/REPORT_AR.md) | Design, implementation, interpretation, tests, and actual Windows results |
| Test record | [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md) | Project preparation and learner-supplied Windows results |
| Requirements traceability | [docs/TRACEABILITY.md](docs/TRACEABILITY.md) | Maps each handout requirement to source and test evidence |
| Execution screenshots | [screenshots/](screenshots/README.md) | Location and naming guide for genuine Windows screenshots |

## Requirements

- Python 3.10 or newer recommended.
- No third-party dependencies; only the Python standard library is used.
- Network access to the authorized target.

## Run it

Open PowerShell or a terminal in this directory.

Default assignment scan (TCP ports 1–1024, 50 workers, 0.5-second timeout):

\`\`\`powershell
python port_scanner.py 127.0.0.1
\`\`\`

Scan a smaller authorized lab range:

\`\`\`powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 100
\`\`\`

Choose the timeout and worker count:

\`\`\`powershell
python port_scanner.py 127.0.0.1 --timeout 1.0 --workers 50
\`\`\`

Show connection-refused ports too:

\`\`\`powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 100 --show-closed
\`\`\`

Show all options:

\`\`\`powershell
python port_scanner.py --help
\`\`\`

## Run the verification suite

From this directory:

\`\`\`powershell
python -m py_compile port_scanner.py tests/test_port_scanner.py
python -m unittest discover -s tests -v
\`\`\`

The environment-dependent closed-loopback test is skipped—not marked as passed—when the operating system or endpoint protection silently filters the local connection and returns \`TIMEOUT\` or \`BLOCKED\`. A separate deterministic test verifies that an explicit Windows \`WSAECONNREFUSED\` (\`10061\`) is classified as \`CLOSED\`.

## Result states

| State | Meaning |
|---|---|
| \`OPEN\` | TCP connection was accepted at scan time. |
| \`CLOSED\` | The target explicitly refused the connection. |
| \`TIMEOUT\` | No final connection response arrived before the timeout. This does not prove the port is closed. |
| \`UNREACHABLE\` | The OS reported a host or network reachability error. |
| \`BLOCKED\` | The local OS or security policy denied the attempt. This does not prove the target port is closed. |
| \`ERROR\` | An otherwise unclassified socket/OS error occurred. |

## Scope and limitations

- TCP connect scanning only; UDP scanning is not implemented.
- The tool does not identify service banners, service versions, or operating-system versions. An open port only indicates that a TCP connection was accepted.
- Results depend on target state, routing, firewalls, endpoint protection, packet loss, and the chosen timeout.
- On Windows, a local security product may filter loopback attempts. Do not relabel \`TIMEOUT\` or \`BLOCKED\` as \`CLOSED\`.
- A listening socket shown by \`Get-NetTCPConnection\` may be bound to a specific interface. A listener on \`0.0.0.0\`, \`127.0.0.1\`, or an IPv6 address does not imply identical reachability on every interface.

## Observed Windows verification (11 November 2026)

The learner ran the program and tests on Windows PowerShell.

- Limited scan, ports 7–19: 13/13 checked; 5 open (7, 9, 13, 17, 19), 8 timed out, 0 errors; 2.014 seconds.
- Full scan, ports 1–1024: 1024/1024 checked; 12 open, 0 closed, 1011 timed out, 0 unreachable, 1 blocked, 0 errors; 21.572 seconds.
- Compilation: passed.
- Unit tests: 11 discovered, 10 passed, 1 skipped, 0 failed (\`OK (skipped=1)\`).

The five ports found open in the limited scan matched the Windows \`Simple TCP/IP Services\` service (\`simptcp\`) listeners confirmed by \`Get-NetTCPConnection\`. The skipped closed-loopback test was filtered by Windows and returned \`TIMEOUT\`; it is not evidence that the port is closed.

The actual Windows output is recorded in [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md), and the technical report is in [docs/REPORT_AR.md](docs/REPORT_AR.md).

## Screenshots

The screenshot guide is in [screenshots/README.md](screenshots/README.md). Captures have been made locally by the learner; upload the actual image files in a follow-up commit before claiming that screenshots are publicly available in this repository.
