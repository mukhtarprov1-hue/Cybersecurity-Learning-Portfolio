# Assignment 05 — Multithreaded Port Scanner

**Track:** Python for Cybersecurity  
**Language:** Python 3  
**Implementation:** TCP sockets + `concurrent.futures.ThreadPoolExecutor`

[![Assignment 05 CI](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/workflows/assignment-05-port-scanner.yml/badge.svg)](https://github.com/mukhtarprov1-hue/Cybersecurity-Learning-Portfolio/actions/workflows/assignment-05-port-scanner.yml)

## Submission overview

This assignment implements a bounded TCP connect scanner for one IPv4 target. It checks a configurable port range concurrently, prints discovered open ports as tasks finish, and reports a result summary and elapsed time.

**Authorization:** Use this scanner only against systems you own, your isolated lab, or targets for which you have explicit written permission. The default example scans `127.0.0.1` only.

## Review this package

| Item | Location | Purpose |
|---|---|---|
| Original task transcription | [TASK_SPEC_AR.md](TASK_SPEC_AR.md) | Arabic brief transcribed from the one-page assignment handout |
| Main source | [port_scanner.py](port_scanner.py) | TCP connect scanner implementation |
| Unit tests | [tests/test_port_scanner.py](tests/test_port_scanner.py) | Local and deterministic tests, including Windows Winsock handling |
| Arabic report | [docs/REPORT_AR.md](docs/REPORT_AR.md) | Design, implementation, interpretation, tests, and limitations |
| Test record | [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md) | Separates build-environment verification from the student's observed Windows run |
| Requirements traceability | [docs/TRACEABILITY.md](docs/TRACEABILITY.md) | Maps each handout requirement to source and test evidence |
| Execution screenshots | [screenshots/](screenshots/README.md) | Instructions for adding genuine Windows screenshots |

## Requirements

- Python 3.10 or newer recommended.
- No third-party dependencies; only the Python standard library is used.
- Network access to the authorized target.

## Run it

Open PowerShell or a terminal in this directory.

Default assignment scan (TCP ports 1–1024, 50 workers, 0.5-second timeout):

```powershell
python port_scanner.py 127.0.0.1
```

Scan a smaller authorized lab range:

```powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 100
```

Choose the timeout and worker count:

```powershell
python port_scanner.py 127.0.0.1 --timeout 1.0 --workers 50
```

Show connection-refused ports too:

```powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 100 --show-closed
```

Show all options:

```powershell
python port_scanner.py --help
```

## Run the verification suite

From this directory:

```powershell
python -m py_compile port_scanner.py tests/test_port_scanner.py
python -m unittest discover -s tests -v
```

The environment-dependent closed-loopback test is skipped—not marked as passed—when the operating system or endpoint protection silently filters the local connection and returns `TIMEOUT` or `BLOCKED`. A separate deterministic test verifies that an explicit Windows `WSAECONNREFUSED` (`10061`) is classified as `CLOSED`.

## Result states

| State | Meaning |
|---|---|
| `OPEN` | TCP connection was accepted at scan time. |
| `CLOSED` | The target explicitly refused the connection. |
| `TIMEOUT` | No final connection response arrived before the timeout. This does not prove the port is closed. |
| `UNREACHABLE` | The OS reported a host or network reachability error. |
| `BLOCKED` | The local OS or security policy denied the attempt. This does not prove the target port is closed. |
| `ERROR` | An otherwise unclassified socket/OS error occurred. |

## Scope and limitations

- TCP connect scanning only; UDP scanning is not implemented.
- The tool does not identify service banners, service versions, or operating-system versions. An open port only indicates that a TCP connection was accepted.
- Results depend on target state, routing, firewalls, endpoint protection, packet loss, and the chosen timeout.
- On Windows, a local security product may filter loopback attempts. Do not relabel `TIMEOUT` or `BLOCKED` as `CLOSED`.
- A listening socket shown by `Get-NetTCPConnection` may be bound to a specific interface. A listener on `0.0.0.0`, `127.0.0.1`, or an IPv6 address does not imply identical reachability on every interface.

## Evidence status

The 11-test suite passes in the project preparation environment (Python 3.13.5). The latest Windows run supplied by the learner is preserved in [docs/TEST_RESULTS.md](docs/TEST_RESULTS.md); that Windows run used the earlier 10-test file and its closed-loopback test failed because Windows returned a timeout. The updated 11-test file is now in this repository, but it has **not yet been re-run on the learner's Windows machine**. The workflow badge will show hosted CI status after GitHub Actions runs.

The screenshots directory contains instructions only until authentic screenshots are added. No terminal screenshot has been fabricated.
