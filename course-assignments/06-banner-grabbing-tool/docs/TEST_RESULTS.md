# Test and verification results

**Verification date:** 11 November 2026  
**Runtime environment:** Windows PowerShell  
**Scan target:** 127.0.0.1 (localhost only)

## 1. Python compilation

Command:

    python -m py_compile banner_grabber.py tests\test_banner_grabber.py

Result: passed. The command returned to the PowerShell prompt without a syntax or compilation error.

## 2. Automated unit tests

Command:

    python -m unittest discover -s tests -v

The learner ran the suite three times. The latest captured run reported:

    Ran 11 tests in 0.374s

    OK

| Metric | Result |
|---|---:|
| Tests run | 11 |
| Passed | 11 |
| Failed | 0 |
| Skipped | 0 |
| Latest runtime | 0.374 s |

The 11 tests cover port parsing and ranges, invalid ports, target/header-injection validation, UTF-8 decoding, immediate SSH and FTP banners, HTTP HEAD and Server-header parsing, no-banner behavior, read timeout, connection refusal, and connection timeout.

## 3. Actual localhost banner-grabbing results

### Targeted tests

| Target port(s) | Observed result | Notes |
|---|---|---|
| 13 | BANNER_FOUND | Daytime service returned a time/date line. |
| 17 | BANNER_FOUND | Quote service returned a text quotation. |
| 19 | BANNER_FOUND | Character Generator returned printable characters. |
| 80, first attempt | NO_BANNER | TCP connected, but no banner arrived before the 2-second read timeout. |
| 80, later attempt | BANNER_FOUND | HTTP/1.1 200 OK; Server: Microsoft-IIS/10.0; X-Powered-By: ASP.NET; Content-Length: 696; Content-Type: text/html. |
| 21, 22, 25, 110, 143, 587 | TIMEOUT | All six ports timed out in the recorded 2-second test. |
| 8080 | TIMEOUT | No HTTP response arrived within the 2-second timeout. |
| 443, targeted test | CLOSED | Connection actively refused (WinError 10061). |
| 8443 | NO_BANNER | TCP connected, but TLS handshake failed because certificate verification rejected a weak EE certificate key. |

The port 80 result is intentionally recorded as two separate attempts: the first attempt returned NO_BANNER, while a later attempt returned an HTTP response. The evidence should not be represented as though every attempt produced the same outcome.

The port 443 result also differed between runs: a targeted run reported CLOSED, while the later default scan reported TIMEOUT. Both observations are retained as captured.

### Default 15-port scan

Command:

    python banner_grabber.py 127.0.0.1 --timeout 2

| Result state | Count | Ports |
|---|---:|---|
| BANNER_FOUND | 4 | 13, 17, 19, 80 |
| NO_BANNER | 3 | 7, 9, 8443 |
| TIMEOUT | 8 | 21, 22, 25, 110, 143, 443, 587, 8080 |
| CLOSED | 0 | — |
| BLOCKED | 0 | — |
| ERROR | 0 | — |
| **Total** | **15** | — |

Recorded elapsed time: **20.344 seconds**.

Ports 7 and 9 accepted TCP connections but did not send an unsolicited banner before the read timeout. Port 8443 reached the TLS stage but did not complete the handshake because certificate verification rejected the weak key.

## 4. CLI verification

Command:

    python banner_grabber.py --help

Result: passed. Help output displayed the target argument and the supported options: --ports, --timeout, --http-ports, --https-ports, --path, and --no-verify-tls.

Passing an empty quoted value to --http-ports or --https-ports produced an argparse “expected one argument” message. The learner then ran the tool without those optional flags; the documented defaults were used successfully. This command-line input issue is not a failed unit test.

## 5. Screenshot evidence

The following original PowerShell screenshots were committed under screenshots/:

- 01-daytime-quote-chargen.png
- 01-help.png
- 02-http-no-banner.png
- 03-ftp-ssh-mail-services.png
- 04-http-alternative-port.png
- 05-https-tls-test.png
- 06-default-ports-scan.png
- 07-cli-help.png
- 08-unit-tests.png

## 6. Test safety and scope

All live banner-grabbing commands shown here targeted 127.0.0.1 only. Automated unit tests use temporary local TCP listeners. No external targets were scanned.

The observations describe the specific test runs on 11 November 2026; network/service states may differ between separate executions. The reported service name is based on the port mapping unless a banner or HTTP header provides additional identification. A banner is not conclusive proof of the remote operating system or software version.
