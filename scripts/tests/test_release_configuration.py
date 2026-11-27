import base64
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "validate-release-configuration.py"
spec = importlib.util.spec_from_file_location("release_configuration", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def valid():
    return {"SUPABASE_URL": "https://release-qa.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_synthetic_qa_only",
            "SUPABASE_AUTH_CALLBACK_URL": "matlogg://auth/callback"}


class ReleaseConfigurationTests(unittest.TestCase):
    def test_valid_public_settings(self):
        self.assertEqual(module.validation_errors(valid()), [])

    def test_missing_empty_and_unexpanded_each_required_value(self):
        for key in valid():
            for value in (None, "", " ", "$(MISSING_SETTING)", "${MISSING_SETTING}"):
                values = valid(); values[key] = value
                with self.subTest(key=key, value=value):
                    self.assertTrue(module.validation_errors(values))

    def test_invalid_url_callback_and_secret_key_are_rejected(self):
        for key, value in (("SUPABASE_URL", "http://release-qa.supabase.co"),
                           ("SUPABASE_URL", "https://user:password@release-qa.supabase.co"),
                           ("SUPABASE_URL", "https://[invalid"),
                           ("SUPABASE_URL", "https://account-qa.invalid"),
                           ("SUPABASE_AUTH_CALLBACK_URL", "other-app://auth/callback"),
                           ("SUPABASE_PUBLISHABLE_KEY", "sb_secret_synthetic_qa_only")):
            values = valid(); values[key] = value
            with self.subTest(key=key):
                self.assertTrue(module.validation_errors(values))

    def test_legacy_anon_key_allowed_service_role_denied(self):
        for role in ("anon", "service_role"):
            payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
            values = valid(); values["SUPABASE_PUBLISHABLE_KEY"] = "synthetic." + payload + ".signature"
            self.assertEqual(bool(module.validation_errors(values)), role != "anon")

    def test_release_process_fails_without_settings_but_debug_is_unchanged(self):
        for configuration, expected in (("Release", 1), ("Debug", 0)):
            result = subprocess.run([sys.executable, str(SCRIPT)],
                                    env={"CONFIGURATION": configuration}, capture_output=True, text=True)
            self.assertEqual(result.returncode, expected)

    def test_finished_plist_is_checked_and_values_never_printed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            for values, expected in ((valid(), 0), ({**valid(), "SUPABASE_URL": ""}, 1),
                                     ({**valid(), "SUPABASE_PUBLISHABLE_KEY": "sb_secret_DO_NOT_PRINT"}, 1)):
                path.write_bytes(plistlib.dumps(values))
                result = subprocess.run([sys.executable, str(SCRIPT), "--plist", str(path)], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected)
                self.assertNotIn(values["SUPABASE_PUBLISHABLE_KEY"], result.stdout + result.stderr)
            path.write_bytes(b"invalid plist")
            result = subprocess.run([sys.executable, str(SCRIPT), "--plist", str(path)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
