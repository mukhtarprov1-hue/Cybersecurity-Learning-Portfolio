import json
import tempfile
import unittest
from pathlib import Path

from log_analyzer import (
    analyze_log_file,
    analyze_stream,
    extract_source_ip,
    render_json_report,
    render_text_report,
)


class AutomatedLogAnalyzerTests(unittest.TestCase):
    def test_detects_sql_union_select_case_insensitively(self):
        report = analyze_stream([
            '198.51.100.10 - - [date] "GET /?q=UNION%20SELECT%20name%20FROM%20users HTTP/1.1" 200 10'
        ])
        self.assertEqual(report.total_alerts, 1)
        self.assertEqual(report.alerts[0].attack_type, "SQL Injection")

    def test_detects_boolean_sql_injection(self):
        report = analyze_stream([
            "203.0.113.8 - - [date] \"GET /login?u=admin%27%20OR%20%271%27=%271 HTTP/1.1\" 403 12"
        ])
        self.assertEqual(report.total_alerts, 1)
        self.assertEqual(report.alerts[0].attack_type, "SQL Injection")

    def test_detects_sleep_sql_injection(self):
        report = analyze_stream([
            '192.0.2.5 - - [date] "GET /?id=1%20AND%20SLEEP(5) HTTP/1.1" 500 1'
        ])
        self.assertEqual(report.counts_by_type, {"SQL Injection": 1})

    def test_detects_plain_path_traversal(self):
        report = analyze_stream([
            '198.51.100.23 - - [date] "GET /download?file=../../etc/passwd HTTP/1.1" 403 10'
        ])
        self.assertEqual(report.counts_by_type, {"Path Traversal": 1})

    def test_detects_encoded_path_traversal(self):
        report = analyze_stream([
            '198.51.100.23 - - [date] "GET /download?file=%2e%2e%2fetc%2fpasswd HTTP/1.1" 403 10'
        ])
        self.assertEqual(report.counts_by_type, {"Path Traversal": 1})

    def test_ignores_normal_access_log_line(self):
        report = analyze_stream([
            '127.0.0.1 - - [date] "GET /assets/site.css HTTP/1.1" 200 2048',
            '127.0.0.1 - - [date] "GET /products?id=42 HTTP/1.1" 200 512',
        ])
        self.assertEqual(report.total_alerts, 0)
        self.assertEqual(report.lines_scanned, 2)

    def test_extracts_ipv4_source_address(self):
        self.assertEqual(
            extract_source_ip('203.0.113.44 - - [date] "GET / HTTP/1.1" 200 10'),
            "203.0.113.44",
        )

    def test_extracts_ipv6_source_address(self):
        self.assertEqual(
            extract_source_ip('2001:db8::10 - - [date] "GET / HTTP/1.1" 200 10'),
            "2001:db8::10",
        )

    def test_uses_unknown_when_first_field_is_not_ip(self):
        self.assertEqual(
            extract_source_ip('localhost - - [date] "GET / HTTP/1.1" 200 10'),
            "UNKNOWN",
        )

    def test_tracks_line_numbers_and_counts_by_category(self):
        report = analyze_stream([
            '127.0.0.1 - - [date] "GET / HTTP/1.1" 200 10',
            '198.51.100.2 - - [date] "GET /?x=UNION%20SELECT%20a%20FROM%20b HTTP/1.1" 200 10',
            '203.0.113.3 - - [date] "GET /?f=../../etc/passwd HTTP/1.1" 403 10',
        ])
        self.assertEqual(report.lines_scanned, 3)
        self.assertEqual(report.alerts[0].line_number, 2)
        self.assertEqual(report.alerts[1].line_number, 3)
        self.assertEqual(
            report.counts_by_type,
            {"Path Traversal": 1, "SQL Injection": 1},
        )

    def test_reports_multiple_categories_on_same_line(self):
        report = analyze_stream([
            '198.51.100.9 - - [date] "GET /?q=UNION%20SELECT%20x%20FROM%20t&f=../../etc/passwd HTTP/1.1" 403 10'
        ])
        self.assertEqual(report.total_alerts, 2)
        self.assertEqual(report.suspicious_lines, 1)

    def test_reads_log_file_with_context_manager(self):
        content = '198.51.100.3 - - [date] "GET /?q=UNION%20SELECT%20a%20FROM%20b HTTP/1.1" 200 10\n'
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "access.log"
            path.write_text(content, encoding="utf-8")
            report = analyze_log_file(path)
        self.assertEqual(report.total_alerts, 1)
        self.assertTrue(report.file_path.endswith("access.log"))

    def test_missing_file_raises_os_error(self):
        with self.assertRaises(OSError):
            analyze_log_file("this-file-does-not-exist-07.log")

    def test_text_report_contains_ip_line_and_summary(self):
        report = analyze_stream([
            '198.51.100.12 - - [date] "GET /?file=../../etc/passwd HTTP/1.1" 403 10'
        ])
        output = render_text_report(report)
        self.assertIn("Path Traversal", output)
        self.assertIn("Line number : 1", output)
        self.assertIn("198.51.100.12", output)
        self.assertIn("Total alerts      : 1", output)

    def test_json_report_is_valid_and_includes_summary(self):
        report = analyze_stream([
            '198.51.100.99 - - [date] "GET /?q=UNION%20SELECT%20a%20FROM%20b HTTP/1.1" 200 10'
        ])
        payload = json.loads(render_json_report(report))
        self.assertEqual(payload["total_alerts"], 1)
        self.assertEqual(payload["counts_by_type"]["SQL Injection"], 1)


if __name__ == "__main__":
    unittest.main()
