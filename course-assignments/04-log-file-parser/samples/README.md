# Synthetic SOC log fixture

This directory includes the committed, six-line `sample.log` fixture so a reviewer can inspect the input directly. It contains two synthetic `FAILED` events and one `404` response.

Regenerate the exact fixture at any time with:

```bash
python3 samples/create_sample.py
```

The sample uses the documentation-only IPv4 range `192.0.2.0/24`; it is not a capture from a real network or user system. The fixture contains no real account names, user data, or production telemetry.
