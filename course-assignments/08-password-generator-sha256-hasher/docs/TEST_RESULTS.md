# Test Results — Password Generator & SHA-256 Hasher

## Project-preparation verification

**Date:** 12 November 2026  
**Environment:** Project-preparation Python runtime; learner Windows verification is pending.

Commands:

    python -m py_compile password_tool.py tests\test_password_tool.py
    python -m unittest discover -s tests -v

### Results

- Compilation: passed.
- Unit tests: 16 passed, 0 failed.
- Password generation smoke test: generated two 20-character examples, each containing all required character classes.
- SHA-256 smoke test: input abc matched the known digest:

    ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

The 16 tests cover requested length, uppercase, lowercase, digits, punctuation, allowed character set, minimum length, invalid length bounds and types, password count, invalid count, the abc SHA-256 vector, Unicode input, empty-string SHA-256, and invalid hash input type.

**Important:** These results were produced in the project-preparation environment. Repeat the commands on the learner's Windows machine after syncing the repository, then update this file with the Windows output and capture screenshots.

## SHA-256 reference values

| Input text | SHA-256 (hexadecimal) |
|---|---|
| abc | ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad |
| empty string | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
