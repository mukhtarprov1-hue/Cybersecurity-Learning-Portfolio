#!/usr/bin/env python3
"""Create a harmless synthetic SOC-style text log for the C parser."""

from pathlib import Path

content = """2026-11-07T08:10:01Z INFO service=auth event=startup status=200
2026-11-07T08:11:12Z WARN service=auth event=login user=demo FAILED source=192.0.2.10
2026-11-07T08:11:16Z INFO service=web method=GET path=/health status=200
2026-11-07T08:12:02Z WARN service=web method=GET path=/admin status=404 source=192.0.2.15
2026-11-07T08:12:49Z ERROR service=auth event=login user=guest FAILED source=192.0.2.25
2026-11-07T08:13:10Z INFO service=web method=GET path=/ status=200
"""

output = Path(__file__).with_name("sample.log")
output.write_text(content, encoding="utf-8", newline="\n")
print(f"Created {output.name} ({len(content.encode('utf-8'))} bytes, {len(content.splitlines())} lines)")
