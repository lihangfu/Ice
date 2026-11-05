#!/usr/bin/env python3
"""Exercise release admission checks using fixture credentials, Python 3 and system Ruby."""
import base64
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github/workflows/release.yml"
workflow = json.loads(subprocess.check_output([
    "/usr/bin/ruby", "-ryaml", "-rjson", "-e",
    "print JSON.generate(YAML.load_file(ARGV.fetch(0)))", str(WORKFLOW),
], text=True))
STEPS = {step["name"]: step["run"] for step in workflow["jobs"]["release"]["steps"] if "run" in step}


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ice-release-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.env = {
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "RUNNER_TEMP": str(self.root),
            "SIGNING_KEYCHAIN_NAME": "fixture signing.keychain-db",
            "GITHUB_ENV": str(self.root / "github-env"),
            "GITHUB_REF_NAME": "v1.2.3",
            "SPARKLE_PUBLIC_ED_KEY": base64.b64encode(bytes(32)).decode(),
            "SPARKLE_PRIVATE_ED_KEY": base64.b64encode(bytes(64)).decode(),
            "APPLE_TEAM_ID": "AB12CD34EF",
            "APPLE_CERTIFICATE_P12_BASE64": base64.b64encode(b"fixture-p12-bytes").decode(),
            "APPLE_CERTIFICATE_PASSWORD": "fixture-export-password",
            "APPLE_ID": "developer@example.com",
            "APPLE_APP_SPECIFIC_PASSWORD": "fixture-notarization-password",
        }

    def run_step(self, name):
        return subprocess.run(["/bin/bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", STEPS[name]],
                              env=self.env, capture_output=True, text=True, timeout=10)

    def test_valid_configuration(self):
        result = self.run_step("Validate release configuration")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_apple_secret(self):
        for name in [key for key in self.env if key.startswith("APPLE_")]:
            with self.subTest(secret=name):
                original = self.env.pop(name)
                result = self.run_step("Validate release configuration")
                self.env[name] = original
                self.assertNotEqual(result.returncode, 0, f"Missing {name} was accepted")
                self.assertIn(name, result.stdout + result.stderr)
                self.assertNotIn(self.env["APPLE_CERTIFICATE_PASSWORD"], result.stdout + result.stderr)
                self.assertNotIn(self.env["APPLE_APP_SPECIFIC_PASSWORD"], result.stdout + result.stderr)

    def test_invalid_configuration(self):
        cases = [
            ("APPLE_TEAM_ID", "AB12CD34E", "APPLE_TEAM_ID"),
            ("APPLE_TEAM_ID", "AB12CD34EF\nINJECT=value", "APPLE_TEAM_ID"),
            ("APPLE_CERTIFICATE_P12_BASE64", "not-base64!", "APPLE_CERTIFICATE_P12_BASE64"),
            ("APPLE_CERTIFICATE_P12_BASE64", " \n", "APPLE_CERTIFICATE_P12_BASE64"),
            ("SPARKLE_PUBLIC_ED_KEY", base64.b64encode(bytes(31)).decode(), "SPARKLE_PUBLIC_ED_KEY"),
            ("SPARKLE_PRIVATE_ED_KEY", "", "SPARKLE_PRIVATE_ED_KEY"),
            ("GITHUB_REF_NAME", "v1.2.3;echo unsafe", "Release tags"),
        ]
        for name, value, diagnostic in cases:
            with self.subTest(variable=name, value=value):
                original = self.env[name]
                self.env[name] = value
                result = self.run_step("Validate release configuration")
                self.env[name] = original
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stdout + result.stderr)

    def test_signing_identity(self):
        fingerprint = "A" * 40
        valid = f'  1) {fingerprint} "Developer ID Application: Example (AB12CD34EF)"\n'
        cases = [
            (valid, True),
            ("     0 valid identities found\n", False),
            (valid.replace("AB12CD34EF", "ZZ12CD34EF"), False),
            (valid.replace("Developer ID Application", "Apple Development"), False),
            (valid.replace("Developer ID Application", "Developer ID Installer"), False),
            (valid + valid.replace(fingerprint, "B" * 40), False),
        ]
        for identities, accepted in cases:
            with self.subTest(identities=identities):
                (self.root / "ice-identities.txt").write_text(identities)
                output = self.root / "github-env"
                output.unlink(missing_ok=True)
                result = self.run_step("Validate Apple signing identity")
                self.assertEqual(result.returncode == 0, accepted, result.stdout + result.stderr)
                if accepted:
                    self.assertEqual(output.read_text(), f"APPLE_SIGNING_IDENTITY={fingerprint}\n")
                else:
                    self.assertFalse(output.exists(), "Rejected identity was exported to later steps")

    def test_notarization_requires_acceptance(self):
        for status in ["Accepted", "Invalid", "In Progress", None]:
            with self.subTest(status=status):
                (self.root / "ice-notarization.json").write_text(json.dumps({"id": "fixture-submission", "status": status}))
                result = self.run_step("Verify notarization result")
                self.assertEqual(result.returncode == 0, status == "Accepted", result.stdout + result.stderr)
                self.assertIn("fixture-submission", result.stdout)

    def test_shell_syntax(self):
        for name, script in STEPS.items():
            with self.subTest(step=name):
                result = subprocess.run(["/bin/bash", "-n"], input=script, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_cleanup_before_keychain_creation(self):
        artifacts = ["ice-signing.p12", "DeveloperIDG2CA.cer", "ice-identities.txt"]
        for name in artifacts:
            (self.root / name).write_text("fixture")
        sentinel = self.root / "unrelated.txt"
        sentinel.write_text("preserve")
        result = self.run_step("Remove signing credentials")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name in artifacts:
            self.assertFalse((self.root / name).exists(), f"Temporary signing artifact retained: {name}")
        self.assertEqual(sentinel.read_text(), "preserve")


if __name__ == "__main__":
    unittest.main(verbosity=2)
