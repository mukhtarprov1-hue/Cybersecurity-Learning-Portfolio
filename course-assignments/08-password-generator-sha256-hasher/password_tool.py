#!/usr/bin/env python3
"""Secure password generation and SHA-256 hashing educational utility."""

from __future__ import annotations

import argparse
import hashlib
import secrets
import string
import sys


UPPERCASE = string.ascii_uppercase
LOWERCASE = string.ascii_lowercase
DIGITS = string.digits
SYMBOLS = string.punctuation
ALL_CHARACTERS = UPPERCASE + LOWERCASE + DIGITS + SYMBOLS
MIN_PASSWORD_LENGTH = 4
MAX_PASSWORD_LENGTH = 4096
MAX_PASSWORD_COUNT = 50


def generate_password(length: int = 16) -> str:
    """Generate a password with all four character classes using OS-backed randomness."""

    if not isinstance(length, int) or isinstance(length, bool):
        raise TypeError("Password length must be an integer.")
    if not MIN_PASSWORD_LENGTH <= length <= MAX_PASSWORD_LENGTH:
        raise ValueError(
            f"Password length must be between {MIN_PASSWORD_LENGTH} "
            f"and {MAX_PASSWORD_LENGTH}."
        )

    characters = [
        secrets.choice(UPPERCASE),
        secrets.choice(LOWERCASE),
        secrets.choice(DIGITS),
        secrets.choice(SYMBOLS),
    ]
    characters.extend(
        secrets.choice(ALL_CHARACTERS)
        for _ in range(length - len(characters))
    )
    secrets.SystemRandom().shuffle(characters)
    return "".join(characters)


def generate_passwords(length: int = 16, count: int = 1) -> list[str]:
    """Generate one or more passwords after validating the requested count."""

    if not isinstance(count, int) or isinstance(count, bool):
        raise TypeError("Password count must be an integer.")
    if not 1 <= count <= MAX_PASSWORD_COUNT:
        raise ValueError(f"Password count must be between 1 and {MAX_PASSWORD_COUNT}.")
    return [generate_password(length) for _ in range(count)]


def sha256_hex(text: str) -> str:
    """Return the lowercase hexadecimal SHA-256 digest of a UTF-8 string."""

    if not isinstance(text, str):
        raise TypeError("Input to SHA-256 must be text (str).")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate cryptographically secure passwords and calculate SHA-256 hashes."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_parser = subparsers.add_parser(
        "generate",
        help="Generate secure random password(s).",
        description="Generate passwords using Python's secrets module.",
    )
    generate_parser.add_argument(
        "--length",
        type=int,
        default=16,
        help=f"Password length ({MIN_PASSWORD_LENGTH}-{MAX_PASSWORD_LENGTH}; default: 16).",
    )
    generate_parser.add_argument(
        "--count",
        type=int,
        default=1,
        help=f"Number of passwords to generate (1-{MAX_PASSWORD_COUNT}; default: 1).",
    )

    hash_parser = subparsers.add_parser(
        "hash",
        help="Calculate the SHA-256 digest of text.",
        description="Calculate a SHA-256 hexadecimal digest of UTF-8 text.",
    )
    hash_parser.add_argument("text", help="Text to hash. Do not pass real account passwords.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "generate":
            passwords = generate_passwords(args.length, args.count)
            print("Secure Password Generator")
            print(f"Length : {args.length}")
            print(f"Count  : {args.count}")
            for index, password in enumerate(passwords, start=1):
                print(f"Password {index}: {password}")
            return 0

        if args.command == "hash":
            digest = sha256_hex(args.text)
            print("SHA-256 Hasher")
            print(f"Input (UTF-8): {args.text}")
            print(f"SHA-256      : {digest}")
            return 0

        parser.error("Unknown command.")
    except (TypeError, ValueError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
