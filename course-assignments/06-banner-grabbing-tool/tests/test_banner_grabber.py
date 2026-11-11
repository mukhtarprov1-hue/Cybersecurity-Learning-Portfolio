import errno
import socket
import threading
import unittest
from unittest.mock import patch

from banner_grabber import (
    decode_banner,
    grab_banner,
    parse_ports,
    validate_target,
)


def start_local_server(handler):
    """Start a one-connection TCP server; return (port, thread)."""
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    port = listener.getsockname()[1]

    def run():
        try:
            conn, _ = listener.accept()
            with conn:
                handler(conn)
        finally:
            listener.close()

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    return port, thread


class BannerGrabberTests(unittest.TestCase):
    def test_parses_comma_separated_ports_and_ranges(self):
        self.assertEqual(parse_ports("21,22,80,8000-8002"), [21, 22, 80, 8000, 8001, 8002])

    def test_rejects_invalid_port_range(self):
        with self.assertRaises(ValueError):
            parse_ports("80,70000")
        with self.assertRaises(ValueError):
            parse_ports("90-80")

    def test_validates_target_and_rejects_header_injection(self):
        self.assertEqual(validate_target("127.0.0.1"), "127.0.0.1")
        with self.assertRaises(ValueError):
            validate_target("127.0.0.1\r\nX-Evil: yes")

    def test_decodes_invalid_utf8_and_extracts_first_line(self):
        banner, first_line, server = decode_banner(
            b"HTTP/1.1 200 OK\r\nServer: LabHTTP/2.4\r\nX-Test: \xff\x00\r\n\r\n"
        )
        self.assertEqual(first_line, "HTTP/1.1 200 OK")
        self.assertEqual(server, "LabHTTP/2.4")
        self.assertIn("HTTP/1.1 200 OK", banner)
        self.assertNotIn("\x00", banner)

    def test_grabs_immediate_ssh_banner(self):
        def handler(conn):
            conn.sendall(b"SSH-2.0-OpenSSH_9.6 TestServer\r\n")

        port, thread = start_local_server(handler)
        result = grab_banner("127.0.0.1", port, timeout=1.0)
        thread.join(timeout=1.0)

        self.assertEqual(result.status, "BANNER_FOUND")
        self.assertEqual(result.service, "SSH")
        self.assertEqual(result.first_line, "SSH-2.0-OpenSSH_9.6 TestServer")

    def test_grabs_immediate_ftp_greeting(self):
        def handler(conn):
            conn.sendall(b"220 Example FTP Server 2.1\r\n")

        port, thread = start_local_server(handler)
        result = grab_banner("127.0.0.1", port, timeout=1.0)
        thread.join(timeout=1.0)

        self.assertEqual(result.status, "BANNER_FOUND")
        self.assertEqual(result.service, "FTP")
        self.assertEqual(result.first_line, "220 Example FTP Server 2.1")

    def test_sends_http_head_and_reads_server_header(self):
        received = []

        def handler(conn):
            request = conn.recv(1024)
            received.append(request)
            conn.sendall(
                b"HTTP/1.1 200 OK\r\n"
                b"Server: TestHTTP/1.2\r\n"
                b"Content-Length: 0\r\n"
                b"Connection: close\r\n\r\n"
            )

        port, thread = start_local_server(handler)
        result = grab_banner(
            "127.0.0.1", port, timeout=1.0, http_ports={port}, https_ports=set()
        )
        thread.join(timeout=1.0)

        self.assertEqual(result.status, "BANNER_FOUND")
        self.assertEqual(result.first_line, "HTTP/1.1 200 OK")
        self.assertEqual(result.server_header, "TestHTTP/1.2")
        self.assertIn(b"HEAD / HTTP/1.1\r\n", received[0])
        self.assertIn(b"Host: 127.0.0.1\r\n", received[0])

    def test_reports_no_banner_when_peer_closes_without_data(self):
        port, thread = start_local_server(lambda conn: None)
        result = grab_banner("127.0.0.1", port, timeout=1.0)
        thread.join(timeout=1.0)
        self.assertEqual(result.status, "NO_BANNER")
        self.assertFalse(result.banner)

    def test_reports_no_banner_when_read_times_out_after_connect(self):
        def handler(conn):
            threading.Event().wait(0.3)

        port, thread = start_local_server(handler)
        result = grab_banner("127.0.0.1", port, timeout=0.05)
        thread.join(timeout=1.0)
        self.assertEqual(result.status, "NO_BANNER")
        self.assertIn("read timeout", result.detail.lower())

    def test_classifies_refused_connection(self):
        with patch(
            "banner_grabber.socket.create_connection",
            side_effect=ConnectionRefusedError(errno.ECONNREFUSED, "refused"),
        ):
            result = grab_banner("127.0.0.1", 65000, timeout=0.1)
        self.assertEqual(result.status, "CLOSED")

    def test_classifies_connection_timeout(self):
        with patch(
            "banner_grabber.socket.create_connection",
            side_effect=socket.timeout("timed out"),
        ):
            result = grab_banner("192.0.2.10", 80, timeout=0.1)
        self.assertEqual(result.status, "TIMEOUT")


if __name__ == "__main__":
    unittest.main(verbosity=2)
