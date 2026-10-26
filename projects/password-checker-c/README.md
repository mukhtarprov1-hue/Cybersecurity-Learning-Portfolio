# Password Checker in C

A small C17 console exercise that validates five explicit password rules. It is a learning exercise, not a comprehensive password-strength estimator.

## Requirements

All five checks must pass:

1. Password length is greater than 8 characters (at least 9).
2. Contains an uppercase English letter (`A-Z`).
3. Contains a lowercase English letter (`a-z`).
4. Contains a digit (`0-9`).
5. Contains a punctuation character such as `!`, `@`, `#`, or `$`.

Whitespace is not treated as a symbol. The program accepts at most 255 input characters and explicitly rejects longer input.

## Build

With GCC installed:

```sh
gcc -Wall -Wextra -Wpedantic -Werror -std=c17 password_checker.c -o password_checker
```

Run it:

```sh
./password_checker
```

On Windows, the output may be named `password_checker.exe` and launched from the relevant terminal.

## Test

From the repository root:

```sh
python3 projects/password-checker-c/tests/run_tests.py --binary ./password_checker
```

To compile and test in one command:

```sh
python3 projects/password-checker-c/tests/run_tests.py --compile --binary ./password_checker
```

The test runner exercises a valid input, each failed condition, and input that exceeds the buffer limit. See [`tests/test_cases.csv`](tests/test_cases.csv) for the core cases.

## Implementation concepts

- `fgets()` for bounded input.
- `strlen()` and `strcspn()` for string length and newline handling.
- `isupper()`, `islower()`, `isdigit()`, and `ispunct()` from `<ctype.h>`.
- Conversion to `unsigned char` before calling `<ctype.h>` functions.
- Boolean flags and `&&` to require all rules.

## Limits and safety

The rules check character composition only. They do not evaluate how guessable a password is, consult breached-password lists, estimate entropy, or store/transmit the input. Use only the synthetic sample values in tests; never enter or publish a personal password in a demo or screenshot.

## Supporting material

- [Test cases CSV](tests/test_cases.csv)
- [Arabic test report](docs/test-report-ar.md)
- [Arabic instructor notes](docs/explain-to-instructor-ar.md)
