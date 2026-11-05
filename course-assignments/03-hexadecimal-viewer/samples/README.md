# Sample binary fixture

create_sample.py generates signature_sample.bin, a 22-byte synthetic binary fixture. Its first eight bytes are the standard PNG signature (89 50 4E 47 0D 0A 1A 0A), followed by readable ASCII, a NUL byte, and a non-ASCII byte. It is deliberately synthetic and contains no personal or sensitive data.

Generate it with:

```bash
python samples/create_sample.py
```

The generated .bin file is a local test artifact and is not required to compile the program.
