# Test and execution record

This record separates results observed in the project preparation environment from results supplied by the learner's Windows machine. They are not interchangeable.

## A. Project preparation environment

| Check | Observed result |
|---|---|
| Python version | 3.13.5 |
| `python -m py_compile port_scanner.py tests/test_port_scanner.py` | Passed |
| `python -m unittest discover -s tests -v` | 11 tests passed, 0 failures, 0 skipped |

The local test run is reproducible from the project root. It does not certify the behavior of every Windows endpoint-security configuration.

## B. Learner-supplied Windows run (2026-11-11)

Command:

```powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 1024 --workers 50 --timeout 0.5
```

Observed output:

| Metric | Result |
|---|---:|
| Ports checked | 1024 / 1024 |
| Open | 12 |
| Closed | 0 |
| Timed out | 1011 |
| Unreachable | 0 |
| Blocked | 1 |
| Errors | 0 |
| Elapsed time | 21.552 seconds |

The learner's accompanying `Get-NetTCPConnection -State Listen` output showed that PID `19356` ran `TCPSVCS`, mapped to the Windows service `simptcp` (`Simple TCP/IP Services`, state `Running`, startup type `Automatic`). The same PID owned listeners on TCP ports `7`, `9`, `13`, `17`, and `19` on IPv4/IPv6 wildcard addresses. These are genuine local listeners reported by Windows; this does not imply that every other port in the scan was open.

## C. Windows test-suite status

The learner's last supplied test run contained 10 tests. Nine passed and `test_detects_closed_local_tcp_port` failed because the operating system returned `Connection timed out` rather than an explicit refusal. The archive that contained the updated test file had not been successfully extracted at that point.

The repository now contains the updated 11-test suite. It skips the environment-dependent closed-loopback test only when that probe returns `TIMEOUT` or `BLOCKED`, and separately verifies through a deterministic mocked result that Windows `WSAECONNREFUSED (10061)` is classified as `CLOSED`.

**Pending:** The learner has not yet run this committed test version on their Windows machine. Do not record Windows as fully verified until that command completes and its output is reviewed.

## D. Interpretation rules

- `OPEN` means a TCP handshake/connection was accepted at the time of testing.
- `CLOSED` requires an explicit connection-refused result.
- `TIMEOUT` and `BLOCKED` are not evidence that a port is closed.
- Counts can vary by host, listeners, firewall policy, endpoint security, and scan timeout.
