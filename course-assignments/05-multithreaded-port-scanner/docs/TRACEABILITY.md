# Requirements traceability

| Handout requirement | Implementation location | Verification/evidence |
|---|---|---|
| Receive a target IP and port | `scan_port(target_ip, port, timeout)` | `test_validates_ipv4`, local open/closed tests |
| Validate the target IP | `validate_ipv4()` | Valid IPv4, invalid text, and IPv6 assertions |
| Set a timeout | `sock.settimeout(timeout)` and `_resolve_pending_connect()` | `test_pending_connect_times_out` |
| Use `concurrent.futures` threads | `scan_ports()` with `ThreadPoolExecutor(max_workers=workers)` | CLI default shows 50 workers; full scan command documented in README |
| Scan a range such as 1–1024 | `build_parser()` defaults and `range(start, end + 1)` | README default invocation and learner-supplied 1024/1024 scan |
| Print open ports as discovered | `as_completed()` and `print(..., flush=True)` in `main()` | CLI execution; capture screenshot when available |
| Measure elapsed time | `time.perf_counter()` | Scan summary output |
| Distinguish open and closed | `connect_ex()` and `classify_connect_error()` | Mocked Winsock refusal test and local listener tests |
| Avoid crashes and close sockets | Socket context manager and worker exception boundary | Socket-creation error test and context-manager assertions |

## Scope note

The handout mentions discovering active services. This implementation identifies TCP port connectivity only; service banner/version identification is not implemented and is not claimed by this package.
