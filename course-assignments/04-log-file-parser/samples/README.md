# Synthetic SOC log fixture

Run `python3 samples/create_sample.py` from the assignment directory to generate `sample.log`. The fixture contains six synthetic text-log records, including two `FAILED` events and one `404` response.

The sample uses the documentation-only IPv4 range `192.0.2.0/24`; it is not a capture from a real network or user system. The generated file is ignored by Git because the generator is the canonical, reproducible source for this fixture.
