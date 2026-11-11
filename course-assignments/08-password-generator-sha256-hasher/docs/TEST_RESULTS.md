# Test Results — Password Generator & SHA-256 Hasher

## Verified learner environment

- OS / Shell: Windows PowerShell
- Date: 12 November 2026
- Dependencies: Python standard library only

## 1. Compilation

Command:

    python -m py_compile password_tool.py tests\test_password_tool.py

Observed result: returned to the PowerShell prompt without a compilation error.

## 2. Unit tests

Command:

    python -m unittest discover -s tests -v

Observed Windows result:

    Ran 16 tests in 0.005s

    OK

| Metric | Result |
|---|---:|
| Tests run | 16 |
| Passed | 16 |
| Failed | 0 |
| Skipped | 0 |
| Runtime | 0.005 s |

Coverage includes requested password length, uppercase, lowercase, digits, punctuation, allowed character set, minimum length, invalid length bounds and types, password count, invalid count, the SHA-256 abc vector, Unicode input, empty-string SHA-256, and invalid hash input type.

## 3. Password generation — Windows execution

Commands executed:

    python password_tool.py generate
    python password_tool.py generate --length 20 --count 3

Observed:
- Default generation: 1 password with length 16.
- Custom generation: 3 passwords, each with length 20.
- The generated values were not copied into this report because passwords should not be published or reused after appearing in terminal logs/screenshots.

## 4. SHA-256 verification — Windows execution

Command:

    python password_tool.py hash "abc"

Observed digest:

    ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

This matches the known SHA-256 test vector for abc.

Command:

    python password_tool.py hash "الأمن السيبراني"

Observed digest:

    a433fb4c622953583421726d62fd046612be73116e5584f98da7f4853bca307b

The Unicode text was encoded as UTF-8 before hashing.

## 5. CLI help

Command:

    python password_tool.py --help

Observed result: usage displayed the generate and hash subcommands successfully.

## 6. Summary

- Compilation: PASS.
- Windows unit tests: 16/16 PASS.
- Default password generation: PASS (length 16).
- Custom generation: PASS (3 passwords, length 20 each).
- SHA-256 known vector for abc: PASS.
- SHA-256 Unicode input: PASS.

Never put real account passwords in screenshots, reports, source control, or shell command history. SHA-256 is a one-way hash and is not a password-storage KDF; production password storage should use Argon2id, scrypt, or bcrypt with unique salts and appropriate parameters.
