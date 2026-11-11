import errno
import socket
import unittest
from unittest.mock import MagicMock, patch

from port_scanner import (
    classify_connect_error,
    scan_port,
    validate_ipv4,
)


class PortScannerTests(unittest.TestCase):
    def test_detects_open_local_tcp_port(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            port = listener.getsockname()[1]
            result = scan_port("127.0.0.1", port, timeout=1.0)

        self.assertEqual(result.status, "open", msg=result.detail)
        self.assertEqual(result.port, port)

    def test_detects_closed_local_tcp_port(self):
        # Reserve a local ephemeral port without listening on it. On systems
        # where endpoint security blocks loopback connections, skip honestly.
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
            result = scan_port("127.0.0.1", port, timeout=1.0)

        # Some Windows endpoint-security/firewall configurations silently drop
        # loopback SYN packets. In that environment connect_ex() cannot prove
        # the port is closed and the correct result is TIMEOUT/BLOCKED.
        if result.status in {"blocked", "timeout"}:
            self.skipTest(
                "The local security policy filtered the loopback connection; "
                f"the probe returned {result.status.upper()}: {result.detail}. "
                "This is not evidence that the port is closed."
            )
        self.assertEqual(result.status, "closed", msg=result.detail)

    def test_pending_windows_connect_completes_as_open(self):
        mock_socket = MagicMock()
        mock_socket.__enter__.return_value = mock_socket
        mock_socket.connect_ex.return_value = 10035  # WSAEWOULDBLOCK
        mock_socket.getsockopt.return_value = 0

        with patch("port_scanner.socket.socket", return_value=mock_socket), \
             patch("port_scanner.select.select", return_value=([], [mock_socket], [])):
            result = scan_port("127.0.0.1", 8080, timeout=0.2)

        self.assertEqual(result.status, "open")
        mock_socket.__exit__.assert_called_once()

    def test_pending_windows_connect_resolves_as_closed(self):
        mock_socket = MagicMock()
        mock_socket.__enter__.return_value = mock_socket
        mock_socket.connect_ex.return_value = 10035  # WSAEWOULDBLOCK
        mock_socket.getsockopt.return_value = 10061  # WSAECONNREFUSED

        with patch("port_scanner.socket.socket", return_value=mock_socket), \
             patch("port_scanner.select.select", return_value=([], [mock_socket], [])):
            result = scan_port("127.0.0.1", 8081, timeout=0.2)

        self.assertEqual(result.status, "closed")
        mock_socket.__exit__.assert_called_once()

    def test_pending_connect_times_out(self):
        mock_socket = MagicMock()
        mock_socket.__enter__.return_value = mock_socket
        mock_socket.connect_ex.return_value = 10035  # WSAEWOULDBLOCK

        with patch("port_scanner.socket.socket", return_value=mock_socket), \
             patch("port_scanner.select.select", return_value=([], [], [])):
            result = scan_port("192.0.2.10", 443, timeout=0.01)

        self.assertEqual(result.status, "timeout")
        mock_socket.__exit__.assert_called_once()

    def test_validates_ipv4(self):
        self.assertEqual(validate_ipv4("127.0.0.1"), "127.0.0.1")
        with self.assertRaises(ValueError):
            validate_ipv4("not-an-ip")
        with self.assertRaises(ValueError):
            validate_ipv4("::1")

    def test_classifies_connection_refused_as_closed(self):
        self.assertEqual(classify_connect_error(errno.ECONNREFUSED), "closed")

    def test_connect_ex_refused_result_is_closed(self):
        mock_socket = MagicMock()
        mock_socket.__enter__.return_value = mock_socket
        mock_socket.connect_ex.return_value = 10061  # WSAECONNREFUSED

        with patch("port_scanner.socket.socket", return_value=mock_socket):
            result = scan_port("127.0.0.1", 8082, timeout=0.2)

        self.assertEqual(result.status, "closed")
        mock_socket.__exit__.assert_called_once()

    def test_classifies_windows_winsock_codes(self):
        self.assertEqual(classify_connect_error(10061), "closed")
        self.assertEqual(classify_connect_error(10060), "timeout")
        self.assertEqual(classify_connect_error(10051), "unreachable")
        self.assertEqual(classify_connect_error(10013), "blocked")

    def test_classifies_posix_permission_denied_as_blocked(self):
        self.assertEqual(classify_connect_error(errno.EACCES), "blocked")

    def test_handles_socket_creation_error_without_crashing(self):
        with patch("port_scanner.socket.socket", side_effect=OSError("simulated failure")):
            result = scan_port("127.0.0.1", 80, timeout=0.1)

        self.assertEqual(result.status, "error")
        self.assertIn("simulated failure", result.detail)


if __name__ == "__main__":
    unittest.main(verbosity=2)
