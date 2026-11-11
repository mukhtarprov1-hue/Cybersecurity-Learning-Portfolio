# Requirements traceability

| Requirement in the handout | Implementation | Verification |
|---|---|---|
| Create a TCP connection function for a selected service port | \`grab_banner(target, port, ...)\` uses \`socket.create_connection()\` | SSH, HTTP, no-banner, refusal, and timeout tests |
| Handle services that send a banner immediately (e.g. SSH) | Reads from the connected stream without sending a request for non-HTTP ports | \`test_grabs_immediate_ssh_banner\`, \`test_grabs_immediate_ftp_greeting\` |
| Handle interactive services such as web servers | HTTP/HTTPS port sets select the interactive request path | \`test_sends_http_head_and_reads_server_header\` |
| Send a basic HTTP HEAD request on web ports | \`_http_request()\` and \`stream.sendall()\` | HTTP test checks \`HEAD / HTTP/1.1\` and Host header |
| Receive up to 1024 bytes | \`stream.recv(1024)\` | HTTP and SSH fixture-server tests |
| Convert received data to formatted text | \`decode_banner()\` uses UTF-8 with \`errors='ignore'\` and filters non-printable control characters | \`test_decodes_invalid_utf8_and_extracts_first_line\` |
| Extract the first main banner line | \`filtered.splitlines()\` then first element | SSH and decode tests |
| Display detected result or indicate no banner | CLI prints \`BANNER_FOUND\`, \`NO_BANNER\`, \`CLOSED\`, \`TIMEOUT\`, \`BLOCKED\`, or \`ERROR\` per port | Empty-response and timeout tests |
| Extract service version where a service discloses it | Preserves first banner line and HTTP \`Server\` header without inventing a version | SSH and HTTP tests verify sample version strings |
| Handle timeouts smoothly | Separates connection timeout from post-connect no-banner read timeout | \`test_classifies_connection_timeout\` and \`test_reports_no_banner_when_read_times_out_after_connect\` |

## Scope note

The source brief asks the analyst to identify service type, operating system, and version from disclosed banners. This implementation displays only details actually present in the returned banner/HTTP headers; it does not infer an operating system when the service does not disclose one.
