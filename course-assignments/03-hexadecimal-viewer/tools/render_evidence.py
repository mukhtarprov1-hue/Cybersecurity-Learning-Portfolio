#!/usr/bin/env python3
"""Render captured terminal logs as lightweight, embeddable SVG evidence."""

from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
SCREENSHOTS = ROOT / "screenshots"
SCREENSHOTS.mkdir(exist_ok=True)

items = [
    ("sample-run.log", "01-sample-output.svg", "HEX VIEWER / ACTUAL PROGRAM OUTPUT"),
    ("missing-file.log", "02-missing-file.svg", "ERROR HANDLING / ACTUAL PROGRAM OUTPUT"),
    ("argument-validation.log", "03-argument-validation.svg", "CLI VALIDATION / ACTUAL PROGRAM OUTPUT"),
    ("build-and-test.log", "04-automated-tests.svg", "BUILD & INTEGRATION TESTS / ACTUAL OUTPUT"),
]

for source, target, title in items:
    lines = (ROOT / "evidence" / source).read_text(encoding="utf-8", errors="replace").splitlines()
    line_height = 27
    height = max(190, 112 + len(lines) * line_height + 30)
    width = 1450
    body = []
    for index, line in enumerate(lines):
        y = 112 + index * line_height
        body.append(f'<text x="42" y="{y}" class="line" xml:space="preserve">{escape(line)}</text>')
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#101827"/><stop offset="1" stop-color="#0b1220"/></linearGradient></defs>
  <rect width="100%" height="100%" rx="22" fill="url(#bg)"/>
  <rect x="1" y="1" width="{width-2}" height="{height-2}" rx="21" fill="none" stroke="#334155"/>
  <rect x="0" y="0" width="{width}" height="72" rx="22" fill="#1e293b"/>
  <rect x="0" y="50" width="{width}" height="22" fill="#1e293b"/>
  <circle cx="34" cy="36" r="7" fill="#fb7185"/><circle cx="58" cy="36" r="7" fill="#fbbf24"/><circle cx="82" cy="36" r="7" fill="#34d399"/>
  <text x="118" y="43" class="title">{escape(title)}</text>
  <text x="{width-36}" y="43" text-anchor="end" class="tag">VERBATIM TERMINAL TRANSCRIPT</text>
  {''.join(body)}
  <style>.title{{font:600 19px 'DejaVu Sans',Arial,sans-serif;fill:#e2e8f0;letter-spacing:1px}}.tag{{font:12px 'DejaVu Sans',Arial,sans-serif;fill:#94a3b8;letter-spacing:1px}}.line{{font:17px 'DejaVu Sans Mono',Consolas,monospace;fill:#d1fae5;white-space:pre}}</style>
</svg>"""
    (SCREENSHOTS / target).write_text(svg, encoding="utf-8")
    print(f"Rendered {target}")
