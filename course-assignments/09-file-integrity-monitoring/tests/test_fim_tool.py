import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from fim_tool import calculate_sha256, check_integrity, create_baseline, load_baseline


class FileIntegrityMonitoringTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.target = self.root / "important_config.txt"
        self.baseline_path = self.root / "baseline.json"
        self.target.write_text("original configuration\n", encoding="utf-8")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_sha256_matches_known_content(self):
        self.assertEqual(
            calculate_sha256(self.target),
            hashlib.sha256(b"original configuration\n").hexdigest(),
        )

    def test_hash_reads_small_chunks(self):
        self.assertEqual(
            calculate_sha256(self.target, chunk_size=3),
            hashlib.sha256(self.target.read_bytes()).hexdigest(),
        )

    def test_hash_rejects_invalid_chunk_size(self):
        for value in (0, -1, True, 1.5):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    calculate_sha256(self.target, chunk_size=value)

    def test_create_and_load_baseline(self):
        created = create_baseline(self.target, self.baseline_path)
        loaded = load_baseline(self.baseline_path)
        self.assertEqual(created["sha256"], loaded["sha256"])
        self.assertEqual(loaded["algorithm"], "SHA-256")
        self.assertEqual(loaded["file_path"], str(self.target.resolve()))

    def test_baseline_has_64_character_digest(self):
        record = create_baseline(self.target, self.baseline_path)
        self.assertEqual(len(record["sha256"]), 64)

    def test_unchanged_file_is_accepted(self):
        baseline = create_baseline(self.target, self.baseline_path)
        self.assertEqual(check_integrity(self.target, baseline)["status"], "UNCHANGED")

    def test_single_character_change_is_detected(self):
        baseline = create_baseline(self.target, self.baseline_path)
        self.target.write_text("Original configuration\n", encoding="utf-8")
        result = check_integrity(self.target, baseline)
        self.assertEqual(result["status"], "MODIFIED")
        self.assertNotEqual(result["expected_sha256"], result["current_sha256"])

    def test_appended_data_is_detected(self):
        baseline = create_baseline(self.target, self.baseline_path)
        with self.target.open("a", encoding="utf-8") as target_file:
            target_file.write("new line\n")
        self.assertEqual(check_integrity(self.target, baseline)["status"], "MODIFIED")

    def test_deleted_file_is_reported_missing(self):
        baseline = create_baseline(self.target, self.baseline_path)
        self.target.unlink()
        result = check_integrity(self.target, baseline)
        self.assertEqual(result["status"], "MISSING")
        self.assertIsNone(result["current_sha256"])

    def test_baseline_is_not_replaced_after_modification(self):
        baseline = create_baseline(self.target, self.baseline_path)
        original_digest = baseline["sha256"]
        self.target.write_text("tampered\n", encoding="utf-8")
        check_integrity(self.target, baseline)
        self.assertEqual(load_baseline(self.baseline_path)["sha256"], original_digest)

    def test_rejects_different_target_file(self):
        baseline = create_baseline(self.target, self.baseline_path)
        other = self.root / "other.txt"
        other.write_text("other", encoding="utf-8")
        with self.assertRaises(ValueError):
            check_integrity(other, baseline)

    def test_rejects_baseline_path_equal_to_target(self):
        with self.assertRaises(ValueError):
            create_baseline(self.target, self.target)

    def test_rejects_invalid_baseline_digest(self):
        self.baseline_path.write_text(json.dumps({
            "schema_version": 1, "algorithm": "SHA-256",
            "file_path": str(self.target.resolve()), "sha256": "not-a-digest",
            "created_at_utc": "2026-11-12T00:00:00+00:00",
        }), encoding="utf-8")
        with self.assertRaises(ValueError):
            load_baseline(self.baseline_path)

    def test_rejects_unsupported_baseline_schema(self):
        self.baseline_path.write_text(json.dumps({"schema_version": 99}), encoding="utf-8")
        with self.assertRaises(ValueError):
            load_baseline(self.baseline_path)


if __name__ == "__main__":
    unittest.main()
