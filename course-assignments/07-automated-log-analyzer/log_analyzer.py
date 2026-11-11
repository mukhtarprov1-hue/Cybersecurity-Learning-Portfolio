#!/usr/bin/env python3
"""Automated web-server log analyzer for authorized defensive review."""

from __future__ import annotations

import argparse
import ipaddress
import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable
from urllib.parse import unquote_plus


@dataclass(frozen=True)
class AttackRule:
    """A named attack category and its compiled detection expressions."""

    name: str
    expressions: tuple[re.Pattern[str], ...]


@dataclass(frozen=True)
class SecurityAlert:
    """One finding for an attack category on a single log line."""

    attack_type: str
    line_number: int
    source_ip: str
    matched_text: str
    log_excerpt: str


@dataclass
class ScanReport:
    """Summary of a streaming log-file analysis."""

    file_path: str
    lines_scanned: int
    alerts: list[SecurityAlert]

    @property
    def total_alerts(self) -> int:
        return len(self.alerts)

    @property
    def counts_by_type(self) -> dict[str, int]:
        counts = Counter(alert.attack_type for alert in self.alerts)
        return dict(sorted(counts.items()))

    @property
    def suspicious_lines(self) -> int:
        return len({alert.line_number for alert in self.alerts})


FLAGS = re.IGNORECASE

ATTACK_RULES: tuple[AttackRule, ...] = (
    AttackRule(
        name="SQL Injection",
        expressions=(
            re.compile(r"\bunion\s+(?:all\s+)?select\b", FLAGS),
            re.compile(
                r"(?:['\"]\s*)?(?:or|and)\s+['\"]?\d+['\"]?\s*=\s*['\"]?\d+",
                FLAGS,
            ),
            re.compile(
                r"\b(?:sleep|benchmark)\s*\(|\bload_file\s*\(|"
                r"\binto\s+outfile\b",
                FLAGS,
            ),
        ),
    ),
    AttackRule(
        name="Path Traversal",
        expressions=(
            re.compile(
                r"(?:\.\.(?:[/\\]|%2f|%5c|%252f|%255c)|"
                r"%2e%2e(?:%2f|%5c)|%252e%252e(?:%252f|%255c))+",
                FLAGS,
            ),
        ),
    ),
)


def extract_source_ip(log_line: str) -> str:
    """Read the leading IP field used by common/combined web access logs."""

    parts = log_line.strip().split(maxsplit=1)
    if not parts:
        return "UNKNOWN"

    candidate = parts[0].strip("[]")
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return "UNKNOWN"


def _clean_excerpt(value: str, limit: int = 240) -> str:
    """Collapse control characters and cap the displayed log excerpt."""

    cleaned = " ".join(value.strip().split())
    return cleaned if len(cleaned) <= limit else cleaned[: limit - 3] + "..."


def _find_rule_match(line: str, rule: AttackRule) -> re.Match[str] | None:
    """Match raw log text and a URL-decoded view of that text."""

    for candidate in (line, unquote_plus(line)):
        for expression in rule.expressions:
            match = expression.search(candidate)
            if match:
                return match
    return None


def analyze_stream(
    stream: Iterable[str],
    *,
    file_path: str = "<stream>",
    rules: tuple[AttackRule, ...] = ATTACK_RULES,
) -> ScanReport:
    """Analyze input one line at a time; normal lines generate no alert."""

    alerts: list[SecurityAlert] = []
    lines_scanned = 0

    for line_number, line in enumerate(stream, start=1):
        lines_scanned += 1
        source_ip = extract_source_ip(line)

        for rule in rules:
            match = _find_rule_match(line, rule)
            if match is None:
                continue

            alerts.append(
                SecurityAlert(
                    attack_type=rule.name,
                    line_number=line_number,
                    source_ip=source_ip,
                    matched_text=_clean_excerpt(match.group(0), limit=120),
                    log_excerpt=_clean_excerpt(line),
                )
            )

    return ScanReport(
        file_path=file_path,
        lines_scanned=lines_scanned,
        alerts=alerts,
    )


def analyze_log_file(
    file_path: str | Path,
    *,
    encoding: str = "utf-8",
    rules: tuple[AttackRule, ...] = ATTACK_RULES,
) -> ScanReport:
    """Open and scan a text log file in streaming mode."""

    path = Path(file_path)
    with path.open("r", encoding=encoding, errors="replace") as log_file:
        return analyze_stream(log_file, file_path=str(path), rules=rules)


def render_text_report(report: ScanReport) -> str:
    """Format line-level alerts followed by a concise summary."""

    output = [
        "=" * 72,
        "AUTOMATED WEB LOG SECURITY ANALYZER",
        f"Log file      : {report.file_path}",
        f"Lines scanned : {report.lines_scanned}",
        "=" * 72,
    ]

    if not report.alerts:
        output.append("[INFO] No configured attack patterns were detected.")
    else:
        for alert in report.alerts:
            output.extend(
                [
                    f"[SECURITY ALERT] {alert.attack_type}",
                    f"  Line number : {alert.line_number}",
                    f"  Source IP   : {alert.source_ip}",
                    f"  Evidence    : {alert.matched_text}",
                    f"  Log entry   : {alert.log_excerpt}",
                ]
            )

    output.extend(
        [
            "=" * 72,
            "SCAN SUMMARY",
            f"Lines scanned     : {report.lines_scanned}",
            f"Suspicious lines  : {report.suspicious_lines}",
            f"Total alerts      : {report.total_alerts}",
        ]
    )

    if report.counts_by_type:
        for attack_type, count in report.counts_by_type.items():
            output.append(f"{attack_type:<20}: {count}")
    else:
        output.append("Attack categories : None detected")

    output.append("=" * 72)
    return "\n".join(output)


def render_json_report(report: ScanReport) -> str:
    """Serialize the report for automation or further analysis."""

    payload = {
        "file_path": report.file_path,
        "lines_scanned": report.lines_scanned,
        "suspicious_lines": report.suspicious_lines,
        "total_alerts": report.total_alerts,
        "counts_by_type": report.counts_by_type,
        "alerts": [asdict(alert) for alert in report.alerts],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Detect selected web-log attack patterns (authorized defensive use)."
    )
    parser.add_argument("log_file", help="Path to a text web-server access log")
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Report output format (default: text)",
    )
    parser.add_argument(
        "--output",
        help="Optional path to save the report; stdout is used when omitted",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        report = analyze_log_file(args.log_file)
    except (OSError, UnicodeError) as exc:
        print(
            f"[ERROR] Cannot read log file '{args.log_file}': {exc}",
            file=sys.stderr,
        )
        return 2

    rendered = (
        render_json_report(report)
        if args.format == "json"
        else render_text_report(report)
    )

    if args.output:
        try:
            Path(args.output).write_text(rendered + "\n", encoding="utf-8")
        except OSError as exc:
            print(
                f"[ERROR] Cannot write report '{args.output}': {exc}",
                file=sys.stderr,
            )
            return 2
        print(f"Report saved to: {args.output}")
    else:
        print(rendered)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
