import hashlib
import unittest

from password_tool import (
    ALL_CHARACTERS,
    DIGITS,
    LOWERCASE,
    SYMBOLS,
    UPPERCASE,
    generate_password,
    generate_passwords,
    sha256_hex,
)


class PasswordToolTests(unittest.TestCase):
    def test_generates_password_with_requested_length(self):
        self.assertEqual(len(generate_password(24)), 24)

    def test_generated_password_contains_uppercase(self):
        self.assertTrue(any(char in UPPERCASE for char in generate_password(16)))

    def test_generated_password_contains_lowercase(self):
        self.assertTrue(any(char in LOWERCASE for char in generate_password(16)))

    def test_generated_password_contains_digit(self):
        self.assertTrue(any(char in DIGITS for char in generate_password(16)))

    def test_generated_password_contains_symbol(self):
        self.assertTrue(any(char in SYMBOLS for char in generate_password(16)))

    def test_generated_password_uses_only_allowed_characters(self):
        password = generate_password(64)
        self.assertTrue(all(char in ALL_CHARACTERS for char in password))

    def test_minimum_valid_length_is_four(self):
        self.assertEqual(len(generate_password(4)), 4)

    def test_rejects_length_below_minimum(self):
        with self.assertRaises(ValueError):
            generate_password(3)

    def test_rejects_length_above_maximum(self):
        with self.assertRaises(ValueError):
            generate_password(4097)

    def test_rejects_non_integer_length(self):
        with self.assertRaises(TypeError):
            generate_password("16")

    def test_generates_requested_number_of_passwords(self):
        passwords = generate_passwords(length=20, count=3)
        self.assertEqual(len(passwords), 3)
        self.assertTrue(all(len(password) == 20 for password in passwords))

    def test_rejects_invalid_password_count(self):
        with self.assertRaises(ValueError):
            generate_passwords(length=16, count=0)

    def test_sha256_matches_known_abc_vector(self):
        self.assertEqual(
            sha256_hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        )

    def test_sha256_matches_hashlib_for_unicode(self):
        text = "الأمن السيبراني"
        expected = hashlib.sha256(text.encode("utf-8")).hexdigest()
        self.assertEqual(sha256_hex(text), expected)

    def test_sha256_empty_text_known_vector(self):
        self.assertEqual(
            sha256_hex(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        )

    def test_sha256_rejects_non_string_input(self):
        with self.assertRaises(TypeError):
            sha256_hex(b"abc")


if __name__ == "__main__":
    unittest.main()
