#!/usr/bin/env python3
"""TCP banner grabbing for explicitly authorized lab reconnaissance."""
from __future__ import annotations

import argparse
import errno
import ipaddress
import socket
import ssl
import time
from dataclasses import dataclass
from typing import Iterable, Sequence

DEFAULT_PORTS = "7,9,13,17,19,21,22,25,80,110,143,443,587,8080,8443"
DEFAULT_HTTP_PORTS = "80,8080"
DEFAULT_HTTPS_PORTS = "443,8443"
MAX_PORTS_PER_RUN = 256
SERVICE_NAMES = {
    7: "Echo", 9: "Discard", 13: "Daytime", 17: "Quote",
    19: "Character Generator", 21: "FTP", 22: "SSH", 23: "Telnet",
    25: "SMTP", 80: "HTTP", 110: "POP3", 143: "IMAP", 443: "HTTPS",
    587: "SMTP Submission", 8080: "HTTP alternate", 8443: "HTTPS alternate",
}


@dataclass(frozen=True)
class BannerResult:
    port: int
    status: str
    service: str
    first_line: str = ""
    server_header: str = ""
    banner: str = ""
    detail: str = ""


def validate_target(value: str) -> str:
    target = value.strip()
    if not target:
        raise ValueError("Target host/IP cannot be empty.")
    if any(ch in target for ch in ("\r", "\n", "\x00")) or any(ch.isspace() for ch in target):
        raise ValueError("Target contains whitespace or invalid control characters.")
    return target


def parse_ports(value: str, *, max_ports: int = MAX_PORTS_PER_RUN) -> list[int]:
    """Parse comma-separated TCP ports and ranges with a per-run cap."""
    if not value.strip():
        raise ValueError("At least one port is required.")
    ports: set[int] = set()
    for item in value.split(","):
        item = item.strip()
        if not item:
            raise ValueError("Empty item in port list.")
        if "-" in item:
            parts = item.split("-")
            if len(parts) != 2:
                raise ValueError(f"Invalid port range: {item}")
            try:
                start, end = (int(part.strip()) for part in parts)
            except ValueError as exc:
                raise ValueError(f"Invalid port range: {item}") from exc
            if start > end:
                raise ValueError(f"Port range starts after it ends: {item}")
            if start < 1 or end > 65535:
                raise ValueError(f"Port range outside 1-65535: {item}")
            if end - start + 1 > max_ports:
                raise ValueError(f"Port range exceeds the {max_ports}-port limit: {item}")
            ports.update(range(start, end + 1))
        else:
            try:
                port = int(item)
            except ValueError as exc:
                raise ValueError(f"Invalid port: {item}") from exc
            if not 1 <= port <= 65535:
                raise ValueError(f"Port outside 1-65535: {port}")
            ports.add(port)
        if len(ports) > max_ports:
            raise ValueError(f"Too many ports. The limit per run is {max_ports}.")
    return sorted(ports)


def parse_port_set(value: str, *, option_name: str) -> set[int]:
    try:
        return set(parse_ports(value)) if value.strip() else set()
    except ValueError as exc:
        raise ValueError(f"Invalid {option_name}: {exc}") from exc


def decode_banner(raw_data: bytes) -> tuple[str, str, str]:
    """Decode with UTF-8 ignore, filter controls, and return banner/first line/Server."""
    decoded = raw_data.decode("utf-8", errors="ignore")
    filtered = "".join(ch for ch in decoded if ch.isprintable() or ch in "\r\n\t").strip("\x00")
    lines = filtered.splitlines()
    first_line = lines[0].strip() if lines else ""
    server_header = ""
    for line in lines[1:]:
        if line.lower().startswith("server:"):
            server_header = line.split(":", 1)[1].strip()
            break
    return filtered.strip(), first_line, server_header


def _http_request(target: str, path: str) -> bytes:
    if not path.startswith("/") or any(ch in path for ch in ("\r", "\n", "\x00")):
        raise ValueError("HTTP path must start with '/' and contain no control characters.")
    host_header = target
    try:
        if ipaddress.ip_address(target).version == 6:
            host_header = f"[{target}]"
    except ValueError:
        pass  # A hostname will be resolved by socket.create_connection().
    request = (
        f"HEAD {path} HTTP/1.1\r\n"
        f"Host: {host_header}\r\n"
        "User-Agent: Authorized-Banner-Grabber/1.0\r\n"
        "Accept: */*\r\n"
        "Connection: close\r\n\r\n"
    )
    return request.encode("ascii", errors="strict")


def _service_name(port: int, first_line: str) -> str:
    line = first_line.upper()
    if line.startswith("SSH-"):
        return "SSH"
    if line.startswith("HTTP/"):
        return "HTTPS" if port in {443, 8443} else "HTTP"
    if "FTP" in line or (port == 21 and first_line[:3].isdigit()):
        return "FTP"
    return SERVICE_NAMES.get(port, "Unknown TCP service")


def _connection_error_status(exc: OSError) -> str:
    code = getattr(exc, "winerror", None)
    if code is None:
        code = getattr(exc, "errno", None)
    if code in {errno.ECONNREFUSED, 10061}:
        return "CLOSED"
    if isinstance(exc, (socket.timeout, TimeoutError)) or code in {getattr(errno, "ETIMEDOUT", -1), 10060}:
        return "TIMEOUT"
    if code in {getattr(errno, "EACCES", -1), 10013}:
        return "BLOCKED"
    return "ERROR"


def grab_banner(
    target: str,
    port: int,
    *,
    timeout: float = 2.0,
    http_ports: Iterable[int] = (80, 8080),
    https_ports: Iterable[int] = (443, 8443),
    request_path: str = "/",
    verify_tls: bool = True,
) -> BannerResult:
    """Connect to one TCP port and obtain an immediate or requested banner."""
    target = validate_target(target)
    if not 1 <= port <= 65535:
        raise ValueError("Port must be between 1 and 65535.")
    if timeout <= 0:
        raise ValueError("Timeout must be greater than zero.")

    http_set, https_set = set(http_ports), set(https_ports)
    is_https = port in https_set
    is_http = port in http_set or is_https
    initial_service = "HTTPS" if is_https else ("HTTP" if port in http_set else SERVICE_NAMES.get(port, "Unknown TCP service"))
    try:
        connection = socket.create_connection((target, port), timeout=timeout)
    except OSError as exc:
        return BannerResult(port, _connection_error_status(exc), initial_service, detail=str(exc))

    stream = connection
    try:
        if is_https:
            context = ssl.create_default_context()
            if not verify_tls:
                context.check_hostname = False
                context.verify_mode = ssl.CERT_NONE
            try:
                stream = context.wrap_socket(connection, server_hostname=target)
            except (ssl.SSLError, OSError) as exc:
                return BannerResult(port, "NO_BANNER", "HTTPS", detail=f"TCP connected, TLS handshake failed: {exc}")

        stream.settimeout(timeout)
        try:
            if is_http:
                stream.sendall(_http_request(target, request_path))
            raw_data = stream.recv(1024)
        except socket.timeout:
            return BannerResult(port, "NO_BANNER", initial_service, detail="TCP connected, but no banner arrived before read timeout.")
        except (OSError, ValueError) as exc:
            return BannerResult(port, "NO_BANNER", initial_service, detail=f"TCP connected, banner exchange failed: {exc}")

        if not raw_data:
            return BannerResult(port, "NO_BANNER", initial_service, detail="TCP connected; peer closed without banner data.")
        banner, first_line, server_header = decode_banner(raw_data)
        service = _service_name(port, first_line)
        return BannerResult(
            port, "BANNER_FOUND" if banner else "NO_BANNER", service,
            first_line=first_line, server_header=server_header, banner=banner,
            detail="Banner received." if banner else "No printable banner data received."
        )
    finally:
        try:
            stream.close()
        except OSError:
            pass


def positive_float(value: str) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Retrieve TCP service banners from authorized targets.")
    parser.add_argument("target", help="Target IPv4/IPv6 address or hostname")
    parser.add_argument("--ports", default=DEFAULT_PORTS,
                        help=f"Comma-separated ports/ranges (default: {DEFAULT_PORTS})")
    parser.add_argument("--timeout", type=positive_float, default=2.0,
                        help="Connection/read timeout in seconds (default: 2.0)")
    parser.add_argument("--http-ports", default=DEFAULT_HTTP_PORTS,
                        help="Ports that receive an HTTP HEAD request (default: 80,8080)")
    parser.add_argument("--https-ports", default=DEFAULT_HTTPS_PORTS,
                        help="Ports that use TLS then HTTP HEAD (default: 443,8443)")
    parser.add_argument("--path", default="/", help="HTTP HEAD request path (default: /)")
    parser.add_argument("--no-verify-tls", action="store_true",
                        help="Disable TLS certificate verification for authorized lab targets only")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        target = validate_target(args.target)
        ports = parse_ports(args.ports)
        http_ports = parse_port_set(args.http_ports, option_name="--http-ports")
        https_ports = parse_port_set(args.https_ports, option_name="--https-ports")
        if not args.path.startswith("/") or any(ch in args.path for ch in ("\r", "\n", "\x00")):
            raise ValueError("--path must start with '/' and contain no control characters.")
    except ValueError as exc:
        parser.error(str(exc))

    print("=" * 68)
    print("TCP Banner Grabbing Tool")
    print(f"Target        : {target}")
    print(f"Ports         : {', '.join(str(p) for p in ports)}")
    print(f"Timeout       : {args.timeout:.2f}s")
    print(f"HTTP ports    : {', '.join(str(p) for p in sorted(http_ports)) or 'none'}")
    print(f"HTTPS ports   : {', '.join(str(p) for p in sorted(https_ports)) or 'none'}")
    print("=" * 68)

    started = time.perf_counter()
    counts = {"BANNER_FOUND": 0, "NO_BANNER": 0, "CLOSED": 0, "TIMEOUT": 0, "BLOCKED": 0, "ERROR": 0}
    for port in ports:
        result = grab_banner(
            target, port, timeout=args.timeout, http_ports=http_ports,
            https_ports=https_ports, request_path=args.path,
            verify_tls=not args.no_verify_tls,
        )
        counts[result.status] += 1
        print(f"\n[{result.status}] {target}:{port} ({result.service})")
        if result.first_line:
            print(f"  First line : {result.first_line}")
        if result.server_header:
            print(f"  Server     : {result.server_header}")
        if result.banner:
            for line in result.banner.splitlines()[:8]:
                print(f"  {line}")
        if result.detail:
            print(f"  Detail     : {result.detail}")

    elapsed = time.perf_counter() - started
    print("\n" + "=" * 68)
    print("Banner grabbing summary")
    print(f"Ports checked : {len(ports)}/{len(ports)}")
    for status, count in counts.items():
        print(f"{status.replace('_', ' ').title():<15}: {count}")
    print(f"Elapsed time  : {elapsed:.3f} seconds")
    print("=" * 68)
    print("Use only on systems you own or are explicitly authorized to assess.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
