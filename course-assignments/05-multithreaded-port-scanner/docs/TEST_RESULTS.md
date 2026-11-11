# Test and execution record

This record separates project-preparation verification from the actual Windows results supplied by the learner.

## A. Project preparation environment

| Check | Observed result |
|---|---|
| Python version | 3.13.5 |
| \`python -m py_compile port_scanner.py tests/test_port_scanner.py\` | Passed |
| \`python -m unittest discover -s tests -v\` | 11 tests passed, 0 failures, 0 skipped |

These results describe the preparation environment only.

## B. Learner-supplied Windows execution (11 November 2026)

**Target:** \`127.0.0.1\` (localhost / loopback)  
**Shell:** Windows PowerShell

### B1. Service/listener validation

The learner ran:

\`\`\`powershell
Get-Service -Name simptcp
Get-NetTCPConnection -State Listen |
  Where-Object {$_.LocalPort -in 7,9,13,17,19}
\`\`\`

Observed:
- Windows service: \`simptcp\` / \`Simple TCP/IP Services\`
- State: \`Running\`
- Process: \`TCPSVCS\`, PID \`19356\`
- Listening TCP ports: \`7, 9, 13, 17, 19\`
- Listener addresses shown: \`0.0.0.0\` and \`::\`

### B2. Limited scan

Command:

\`\`\`powershell
python port_scanner.py 127.0.0.1 --start-port 7 --end-port 19 --workers 50 --timeout 1 --show-closed
\`\`\`

Observed summary:

| Metric | Result |
|---|---:|
| Ports checked | 13 / 13 |
| Open | 5 |
| Closed | 0 |
| Timed out | 8 |
| Unreachable | 0 |
| Blocked | 0 |
| Errors | 0 |
| Elapsed time | 2.014 seconds |

Open ports printed: \`7, 9, 13, 17, 19\`.

### B3. Full assignment scan

Command:

\`\`\`powershell
python port_scanner.py 127.0.0.1 --start-port 1 --end-port 1024 --workers 50 --timeout 0.5
\`\`\`

Observed summary:

| Metric | Result |
|---|---:|
| Ports checked | 1024 / 1024 |
| Open | 12 |
| Closed | 0 |
| Timed out | 1011 |
| Unreachable | 0 |
| Blocked | 1 |
| Errors | 0 |
| Elapsed time | 21.572 seconds |

Do not interpret timeout or blocked results as closed ports.

### B4. Windows compilation and unit tests

Commands:

\`\`\`powershell
python -m py_compile port_scanner.py tests/test_port_scanner.py
python -m unittest discover -s tests -v
\`\`\`

Observed:
- Compilation: passed (no output/error).
- Tests discovered: 11.
- Passed: 10.
- Skipped: 1.
- Failed: 0.
- Final result: \`OK (skipped=1)\`.

The skipped test was \`test_detects_closed_local_tcp_port\`. Windows returned \`TIMEOUT\` for the loopback probe, which cannot establish that the port is closed. The separate deterministic test \`test_connect_ex_refused_result_is_closed\` passed and verifies that an explicit Winsock connection-refused result (\`10061\`) maps to \`CLOSED\`.

## C. Interpretation

- \`OPEN\`: TCP connection was accepted at scan time.
- \`CLOSED\`: explicit connection refusal was received.
- \`TIMEOUT\`: no final response within the configured timeout; not proof of closure.
- \`BLOCKED\`: local OS/security policy denied the attempt; not proof of closure.
- \`UNREACHABLE\`: OS reported host/network reachability failure.
- \`ERROR\`: an otherwise unclassified error occurred.

## D. Evidence files

The learner reports that Windows screenshots have been captured in the local \`screenshots\` directory. They are not yet included in this GitHub revision because the image files have not been provided to the repository upload step. After adding them locally, commit and push the screenshot files so this record can link to the actual captures.
