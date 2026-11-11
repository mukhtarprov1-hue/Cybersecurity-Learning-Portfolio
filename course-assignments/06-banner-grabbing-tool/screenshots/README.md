# Windows execution screenshots

These are original screenshots captured from the learner's PowerShell session. They document the actual localhost runs and unit-test execution; terminal output has not been fabricated.

| File | Evidence |
|---|---|
| 01-daytime-quote-chargen.png | Banner responses from Daytime (13), Quote (17), and Character Generator (19). |
| 01-help.png | Additional CLI help capture. |
| 02-http-no-banner.png | Initial HTTP port 80 attempt: TCP connected, but no banner arrived within the read timeout. |
| 03-ftp-ssh-mail-services.png | Recorded TIMEOUT results for ports 21, 22, 25, 110, 143, and 587. |
| 04-http-alternative-port.png | HTTP test on port 8080; TIMEOUT in the captured run. |
| 05-https-tls-test.png | HTTPS test: port 443 refused the connection; port 8443 failed TLS certificate verification because its key was too weak. |
| 06-default-ports-scan.png | Default scan of 15 localhost ports: 4 BANNER_FOUND, 3 NO_BANNER, and 8 TIMEOUT. |
| 07-cli-help.png | CLI usage and supported arguments/options. |
| 08-unit-tests.png | Windows unittest output: 11 tests, 0 failures, 0 skipped, OK. |

The later port 80 run returned HTTP/1.1 200 OK and identified Server: Microsoft-IIS/10.0. That successful response is recorded in docs/REPORT_AR.md and docs/TEST_RESULTS.md. The initial NO_BANNER screenshot is retained because it is a genuine earlier observation, not a contradiction to be removed.

All live scans shown in the report targeted 127.0.0.1. Use the tool only on systems you own or are explicitly authorized to assess.
