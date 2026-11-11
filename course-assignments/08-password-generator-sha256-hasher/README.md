# Assignment 08 — Password Generator & SHA-256 Hasher

A Python command-line utility with two educational security functions:

1. Generate passwords using the operating system's cryptographically secure random source through the secrets module.
2. Calculate SHA-256 hexadecimal digests for UTF-8 text using hashlib.

## Features

- Guarantees at least one uppercase letter, lowercase letter, digit, and punctuation symbol in each generated password.
- Uses secrets.choice() for character selection and secrets.SystemRandom().shuffle() for secure ordering.
- Supports password lengths from 4 through 4096 characters and 1–50 passwords per run.
- Calculates lowercase hexadecimal SHA-256 digests and supports Unicode input through UTF-8.
- Uses only the Python standard library. No external packages are required.

## Project structure

    08-password-generator-sha256-hasher/
    ├── password_tool.py
    ├── README.md
    ├── TASK_SPEC_AR.md
    ├── requirements.txt
    ├── .gitignore
    ├── tests/test_password_tool.py
    ├── docs/REPORT_AR.md
    ├── docs/TEST_RESULTS.md
    ├── docs/TRACEABILITY.md
    └── screenshots/README.md

## Generate passwords

    python password_tool.py generate
    python password_tool.py generate --length 24
    python password_tool.py generate --length 20 --count 3

Each password includes at least one character from all four required classes.

## Calculate SHA-256

    python password_tool.py hash "abc"

Expected digest:

    ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

## Compile and test

    python -m py_compile password_tool.py tests\test_password_tool.py
    python -m unittest discover -s tests -v

## Security notes

- secrets is designed for security-sensitive random values. Do not replace it with random for password generation.
- Generated passwords are printed to the terminal. Do not capture or publish a password intended for a real account.
- SHA-256 is a one-way hash, not encryption. It cannot be decrypted.
- Plain SHA-256 is not suitable for production password storage. Use a password-hashing scheme such as Argon2id, scrypt, or bcrypt with unique salts and suitable work factors.
- Passing a real password as a command-line argument can expose it in shell history or process listings. Use demonstration text only with the hash command.

Use this utility for educational work and authorized administration.
