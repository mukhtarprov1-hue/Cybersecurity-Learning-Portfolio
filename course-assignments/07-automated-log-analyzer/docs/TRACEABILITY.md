# Requirements Traceability — Assignment 07

| Task requirement | Implementation | Verification |
|---|---|---|
| Read text log files | analyze_log_file() opens the file with Path.open() and passes its iterator to the scanner. | test_reads_log_file_with_context_manager |
| Process records line by line | analyze_stream() enumerates the stream without calling read() or loading the entire file. | test_tracks_line_numbers_and_counts_by_category |
| Compile Regex patterns | ATTACK_RULES defines compiled re.Pattern values using re.IGNORECASE. | SQL and traversal detection tests |
| Search each record | _find_rule_match() uses Pattern.search() against raw and URL-decoded text. | Encoded and unencoded payload tests |
| Detect SQL Injection | UNION SELECT, Boolean comparison, SLEEP/BENCHMARK, LOAD_FILE and INTO OUTFILE indicators. | SQL detection tests |
| Detect Path Traversal | Slash/backslash traversal and common percent-encoded sequences. | Plain and encoded traversal tests |
| Report attack type | SecurityAlert.attack_type. | test_text_report_contains_ip_line_and_summary |
| Report line number | SecurityAlert.line_number. | test_tracks_line_numbers_and_counts_by_category |
| Report source IP | extract_source_ip() validates IPv4/IPv6 with ipaddress. | IPv4, IPv6, and invalid-field tests |
| Ignore normal entries | Only lines matching configured indicators generate alerts. | test_ignores_normal_access_log_line |
| Print detailed summary | ScanReport counts lines, suspicious lines, total alerts, and categories. | Text and JSON report tests |
| Handle file errors | CLI catches OSError and UnicodeError and returns exit code 2. | test_missing_file_raises_os_error |
