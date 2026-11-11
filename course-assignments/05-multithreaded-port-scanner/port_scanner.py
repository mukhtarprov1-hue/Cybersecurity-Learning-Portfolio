#!/usr/bin/env python3
"""A bounded, multithreaded TCP connect scanner for authorized IPv4 targets."""

from __future__ import annotations

import argparse
import errno
import ipaddress
import select
import socket
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Iterator, Sequence


@dataclass(frozen=True)
class ScanResult:
    """Result of checking one TCP port."""

    port: int
    status: str
    detail: str = ""


def validate_ipv4(value: str) -> str:
    """Return a normalized IPv4 address or raise ValueError."""
    try:
        address = ipaddress.ip_address(value)
    except ValueError as exc:
        raise ValueError(f"Invalid IP address: {value}") from exc

    if address.version != 4:
        raise ValueError("This assignment implementation accepts IPv4 addresses only.")

    return str(address)


def _pending_connect_codes() -> set[int]:
    """Return platform codes meaning that a nonblocking connect is in progress."""
    codes = {
        getattr(errno, name)
        for name in ("EINPROGRESS", "EWOULDBLOCK", "EALREADY")
        if hasattr(errno, name)
    }
    # Windows Winsock equivalents: WSAEWOULDBLOCK, WSAEINPROGRESS,
    # and WSAEALREADY. Python timeout-mode sockets are internally nonblocking.
    codes.update({10035, 10036, 10037})
    return codes


def classify_connect_error(error_code: int) -> str:
    """Classify POSIX errno and Windows Winsock connect_ex() error codes."""
    closed_codes = {getattr(errno, "ECONNREFUSED", -1), 10061}  # WSAECONNREFUSED
    timeout_codes = {getattr(errno, "ETIMEDOUT", -1), 10060}  # WSAETIMEDOUT
    unreachable_codes = {
        getattr(errno, name, -1)
        for name in ("EHOSTUNREACH", "ENETUNREACH", "EHOSTDOWN", "ENETDOWN")
    }
    unreachable_codes.update({10065, 10051, 10064, 10050})
    blocked_codes = {getattr(errno, "EACCES", -1), 10013}  # WSAEACCES
    unreachable_codes.discard(-1)
    blocked_codes.discard(-1)

    if error_code in closed_codes:
        return "closed"
    if error_code in timeout_codes:
        return "timeout"
    if error_code in unreachable_codes:
        return "unreachable"
    if error_code in blocked_codes:
        return "blocked"
    return "error"


def _resolve_pending_connect(sock: socket.socket, timeout: float) -> tuple[int | None, bool]:
    """Wait for a nonblocking connect to finish.

    Returns (SO_ERROR, timed_out). A None SO_ERROR with timed_out=True means
    select() did not report completion within the requested timeout.
    """
    try:
        _readable, writable, exceptional = select.select([], [sock], [sock], timeout)
    except OSError:
        raise

    if not writable and not exceptional:
        return None, True

    # SO_ERROR is zero on success; otherwise it contains the final connect error.
    return sock.getsockopt(socket.SOL_SOCKET, socket.SO_ERROR), False


def scan_port(target_ip: str, port: int, timeout: float = 0.5) -> ScanResult:
    """Perform one TCP connection attempt and always close its socket."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            result = sock.connect_ex((target_ip, port))

            if result in _pending_connect_codes():
                result, did_timeout = _resolve_pending_connect(sock, timeout)
                if did_timeout:
                    return ScanResult(port=port, status="timeout", detail="Connection timed out")

            if result == 0:
                return ScanResult(port=port, status="open", detail="TCP connection accepted")

            # A completed connect has a concrete OS error code at this point.
            assert result is not None
            status = classify_connect_error(result)
            known_windows_errors = {
                10013: "WSAEACCES: permission denied by the OS or a local security policy",
                10035: "WSAEWOULDBLOCK: connection is pending (unexpected after completion wait)",
                10036: "WSAEINPROGRESS: connection is in progress",
                10037: "WSAEALREADY: connection is already in progress",
                10051: "WSAENETUNREACH: network is unreachable",
                10060: "WSAETIMEDOUT: connection timed out",
                10061: "WSAECONNREFUSED: connection refused",
                10064: "WSAEHOSTDOWN: host is down",
                10065: "WSAEHOSTUNREACH: host is unreachable",
            }
            detail = known_windows_errors.get(
                result, errno.errorcode.get(result, f"OS error {result}")
            )
            return ScanResult(port=port, status=status, detail=detail)

    except socket.timeout:
        return ScanResult(port=port, status="timeout", detail="Connection timed out")
    except OSError as exc:
        error_code = getattr(exc, "winerror", None)
        if error_code is None:
            error_code = getattr(exc, "errno", None)
        if error_code is not None:
            status = classify_connect_error(error_code)
            if status != "error":
                return ScanResult(port=port, status=status, detail=str(exc))
        return ScanResult(port=port, status="error", detail=str(exc))


def scan_ports(
    target_ip: str,
    ports: Sequence[int],
    timeout: float = 0.5,
    workers: int = 50,
) -> Iterator[ScanResult]:
    """Scan ports concurrently and yield results as each task completes."""
    if workers < 1:
        raise ValueError("workers must be at least 1")
    if timeout <= 0:
        raise ValueError("timeout must be greater than 0")
    if not ports:
        return

    worker_count = min(workers, len(ports))
    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {
            executor.submit(scan_port, target_ip, port, timeout): port
            for port in ports
        }

        for future in as_completed(futures):
            try:
                yield future.result()
            except Exception as exc:  # defensive boundary around worker tasks
                yield ScanResult(
                    port=futures[future],
                    status="error",
                    detail=f"Unexpected worker error: {exc}",
                )


def positive_float(value: str) -> float:
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return number


def positive_int(value: str) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def port_number(value: str) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if not 1 <= number <= 65535:
        raise argparse.ArgumentTypeError("must be between 1 and 65535")
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Multithreaded TCP port scanner for authorized IPv4 targets."
    )
    parser.add_argument("target", help="Target IPv4 address, e.g. 127.0.0.1")
    parser.add_argument("--start-port", type=port_number, default=1,
                        help="First TCP port to scan (default: 1)")
    parser.add_argument("--end-port", type=port_number, default=1024,
                        help="Last TCP port to scan (default: 1024)")
    parser.add_argument("--timeout", type=positive_float, default=0.5,
                        help="Socket timeout in seconds (default: 0.5)")
    parser.add_argument("--workers", type=positive_int, default=50,
                        help="Maximum concurrent worker threads (default: 50)")
    parser.add_argument("--show-closed", action="store_true",
                        help="Print closed ports as well as open ports")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.start_port > args.end_port:
        parser.error("--start-port must be less than or equal to --end-port")

    try:
        target_ip = validate_ipv4(args.target)
    except ValueError as exc:
        parser.error(str(exc))

    ports = range(args.start_port, args.end_port + 1)
    total_ports = len(ports)
    counts = {"open": 0, "closed": 0, "timeout": 0,
              "unreachable": 0, "blocked": 0, "error": 0}

    print("=" * 60)
    print("Multithreaded TCP Port Scanner")
    print(f"Target        : {target_ip}")
    print(f"Port range    : {args.start_port}-{args.end_port}")
    print(f"Workers       : {min(args.workers, total_ports)}")
    print(f"Socket timeout: {args.timeout:.2f}s")
    print("=" * 60)
    print("Starting scan...\n")

    start_time = time.perf_counter()

    try:
        for result in scan_ports(
            target_ip, list(ports), timeout=args.timeout, workers=args.workers
        ):
            counts[result.status] = counts.get(result.status, 0) + 1
            if result.status == "open":
                print(f"[OPEN]  {target_ip}:{result.port}", flush=True)
            elif args.show_closed and result.status == "closed":
                print(f"[CLOSED] {target_ip}:{result.port}", flush=True)
            elif result.status in ("timeout", "unreachable", "blocked", "error"):
                print(f"[{result.status.upper()}] {target_ip}:{result.port} - {result.detail}", flush=True)
    except KeyboardInterrupt:
        print("\nScan interrupted by user.", file=sys.stderr)
        return 130

    elapsed = time.perf_counter() - start_time
    print("\n" + "=" * 60)
    print("Scan summary")
    print(f"Ports checked : {sum(counts.values())}/{total_ports}")
    print(f"Open          : {counts['open']}")
    print(f"Closed        : {counts['closed']}")
    print(f"Timed out     : {counts['timeout']}")
    print(f"Unreachable   : {counts['unreachable']}")
    print(f"Blocked       : {counts['blocked']}")
    print(f"Errors        : {counts['error']}")
    print(f"Elapsed time  : {elapsed:.3f} seconds")
    print("=" * 60)
    print("Note: a timeout, unreachable, or blocked result does not prove that a port is closed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
