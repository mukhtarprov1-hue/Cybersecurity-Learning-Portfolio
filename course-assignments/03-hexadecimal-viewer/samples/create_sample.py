#!/usr/bin/env python3
"""Generate a harmless binary sample containing a PNG file signature."""

from pathlib import Path

sample = bytes.fromhex(
    "89 50 4E 47 0D 0A 1A 0A 48 45 41 44 45 52 00 41 53 43 49 49 FF 21"
)
out = Path(__file__).with_name("signature_sample.bin")
out.write_bytes(sample)
print(f"Created {out.name} ({len(sample)} bytes)")
