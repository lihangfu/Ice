#!/usr/bin/env python3
"""Exercise release admission checks using fixture credentials, Python 3 and system Ruby."""
import base64
import json
from pathlib import Path
import plistlib
import shutil
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
            "RELEASE_TAG": "v1.2.3",
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REPOSITORY": "example/Ice",
            "GITHUB_SHA": "a" * 40,
            "GITHUB_RUN_ID": "1234",
            "GITHUB_RUN_ATTEMPT": "2",
            "GITHUB_RUN_NUMBER": "10",
            "GITHUB_STEP_SUMMARY": str(self.root / "summary"),
            "NOTARY_PROFILE": "fixture-profile",
            "NOTARY_SUBMISSION_ID": "11111111-2222-4333-8444-555555555555",
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
                              env=self.env, cwd=self.root, capture_output=True, text=True, timeout=10)

    def load_step_env(self):
        for line in (self.root / "github-env").read_text().splitlines():
            name, value = line.split("=", 1)
            self.env[name] = value

    def stub(self, name, script):
        directory = self.root / "bin"
        directory.mkdir(exist_ok=True)
        path = directory / name
        path.write_text("#!/bin/bash\nset -e\n" + script)
        path.chmod(0o755)
        self.env["PATH"] = str(directory) + ":/usr/bin:/bin:/usr/sbin:/sbin"

    def stub_notary(self):
        self.stub("xcrun", '''
echo "$*" >> "$RUNNER_TEMP/notary-calls"
case "$2" in
  submit) printf '{"id":"%s"}\\n' "$NOTARY_SUBMISSION_ID" ;;
  wait)
    [[ "$*" == *"--output-format normal --progress"* ]]
    echo "Current status: ${FIXTURE_STATUS:-Accepted}"
    exit "${FIXTURE_WAIT_EXIT:-0}" ;;
  info)
    if [[ "${FIXTURE_INFO_EXIT:-0}" != 0 ]]; then
      echo "status query failed" >&2
      exit "$FIXTURE_INFO_EXIT"
    fi
    printf '{"id":"%s","status":"%s"}\\n' "$NOTARY_SUBMISSION_ID" "${FIXTURE_STATUS:-Accepted}" ;;
  log)
    if [[ "${FIXTURE_LOG_EXIT:-0}" != 0 ]]; then exit "$FIXTURE_LOG_EXIT"; fi
    printf '{"issues":[]}\\n' > "${@: -1}" ;;
  *) exit 99 ;;
esac
''')

    def prepare_saved_state(self, submit=True):
        app = self.root / "build/export/Ice.app/Contents"
        (app / "MacOS").mkdir(parents=True)
        (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleVersion": "10", "CFBundleShortVersionString": "1.2.3"}))
        binary = app / "MacOS/Ice"
        binary.write_text("#!/bin/sh\necho fixture-app\n")
        binary.chmod(0o755)
        tools = self.root / "build/SourcePackages/artifacts/sparkle/Sparkle/bin"
        tools.mkdir(parents=True)
        (tools / "generate_appcast").write_text("#!/bin/sh\necho fixture-sparkle\n")
        (tools / "generate_appcast").chmod(0o755)
        (tools / "sign_update").symlink_to("generate_appcast")
        result = self.run_step("Prepare signed release state")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.load_step_env()
        self.stub_notary()
        if submit:
            result = self.run_step("Submit Ice for notarization")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.load_step_env()
        self.env.update(GITHUB_EVENT_NAME="workflow_dispatch", SOURCE_RUN_ID="1234", SOURCE_RUN_ATTEMPT="2",
                        RELEASE_COMMIT="a" * 40, GITHUB_RUN_NUMBER="99", GITHUB_REF_NAME="main")

    def pack_saved_state(self):
        result = self.run_step("Pack signed release state")
        self.assertEqual(result.returncode, 0, result.stderr)
        recovery = self.root / "build/recovery"
        recovery.mkdir(exist_ok=True)
        (self.root / "build/ice-signed.tgz").replace(recovery / "ice-signed.tgz")

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
            ("RELEASE_TAG", "v1.2.3;echo unsafe", "Release tags"),
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
        directory = self.root / "build/notarization"
        directory.mkdir(parents=True)
        for status in ["Accepted", "Invalid", "In Progress", None]:
            with self.subTest(status=status):
                (directory / "result.json").write_text(json.dumps({"id": self.env["NOTARY_SUBMISSION_ID"], "status": status}))
                result = self.run_step("Verify notarization result")
                self.assertEqual(result.returncode == 0, status == "Accepted", result.stdout + result.stderr)
                self.assertIn(self.env["NOTARY_SUBMISSION_ID"], result.stdout)
        (directory / "result.json").write_text(json.dumps({"id": "wrong-submission", "status": "Accepted"}))
        self.assertNotEqual(self.run_step("Verify notarization result").returncode, 0)

    def test_recovery_configuration_needs_no_signing_private_key(self):
        self.env.update(GITHUB_EVENT_NAME="workflow_dispatch", SOURCE_RUN_ID="1234", SOURCE_RUN_ATTEMPT="2")
        del self.env["APPLE_CERTIFICATE_P12_BASE64"]
        del self.env["APPLE_CERTIFICATE_PASSWORD"]
        result = self.run_step("Validate release configuration")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for name, value in [("SOURCE_RUN_ID", "1;echo unsafe"), ("SOURCE_RUN_ATTEMPT", "0"),
                            ("NOTARY_SUBMISSION_ID", "not-a-uuid")]:
            with self.subTest(variable=name):
                original = self.env[name]
                self.env[name] = value
                result = self.run_step("Validate release configuration")
                self.env[name] = original
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(name, result.stdout + result.stderr)

    def test_recovery_source_provenance(self):
        self.env.update(SOURCE_RUN_ID="1234", SOURCE_RUN_ATTEMPT="2")
        source = {"id": 1234, "event": "push", "path": ".github/workflows/release.yml",
                  "head_branch": "v1.2.3", "head_sha": "a" * 40, "repository": {"full_name": "example/Ice"}}
        fixture = self.root / "source-run.json"
        self.stub("gh", 'cat "$RUNNER_TEMP/source-run.json"\n')
        self.stub("git", 'if [[ "$1" == rev-parse ]]; then printf "%040d\\n" 0 | tr 0 a; fi\n')
        fixture.write_text(json.dumps(source))
        result = self.run_step("Validate recovery source")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for key, value in [("id", 9876), ("event", "pull_request"), ("path", ".github/workflows/lint.yml"),
                           ("head_branch", "v9.9.9"), ("head_sha", "b" * 40), ("repository", {"full_name": "other/Ice"})]:
            with self.subTest(field=key):
                fixture.write_text(json.dumps({**source, key: value}))
                result = self.run_step("Validate recovery source")
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_signed_state_round_trip_and_resume(self):
        self.prepare_saved_state()
        self.pack_saved_state()
        shutil.rmtree(self.root / "build/release-state")
        shutil.rmtree(self.root / "build/export")
        result = self.run_step("Restore original signed release state")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.load_step_env()
        self.assertEqual(self.env["RELEASE_BUILD_NUMBER"], "10")
        app = self.root / "build/export/Ice.app/Contents/MacOS/Ice"
        self.assertEqual(subprocess.check_output([str(app)], text=True).strip(), "fixture-app")
        tools = self.root / "build/release-state/sparkle-bin"
        self.assertTrue((tools / "sign_update").is_symlink())
        self.assertEqual(subprocess.check_output([str(tools / "sign_update")], text=True).strip(), "fixture-sparkle")
        result = self.run_step("Wait for notarization")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.run_step("Verify notarization result").returncode, 0)
        calls = (self.root / "notary-calls").read_text()
        self.assertEqual(calls.count("notarytool submit "), 1, calls)

    def test_recovery_rejects_mismatched_state(self):
        self.prepare_saved_state()
        path = self.root / "build/release-state/release.json"
        metadata = json.loads(path.read_text())
        for key, value in [("schema_version", 2), ("repository", "other/Ice"), ("tag", "v9.9.9"),
                           ("commit", "b" * 40), ("run_id", "9876"), ("run_attempt", "1"),
                           ("submission_id", "other-id"), ("archive_sha256", "0" * 64), ("build_number", "10\nINJECT=value")]:
            with self.subTest(field=key):
                path.write_text(json.dumps({**metadata, key: value}))
                self.pack_saved_state()
                result = self.run_step("Restore original signed release state")
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_wait_timeout_still_collects_diagnostics(self):
        self.stub_notary()
        self.env.update(FIXTURE_WAIT_EXIT="124", FIXTURE_STATUS="In Progress", FIXTURE_LOG_EXIT="1")
        result = self.run_step("Wait for notarization")
        self.assertEqual(result.returncode, 124, result.stdout + result.stderr)
        self.assertIn("Current status: In Progress", result.stdout)
        self.assertIn("Apple continues processing", result.stdout)
        calls = (self.root / "notary-calls").read_text()
        self.assertIn("notarytool info ", calls)
        self.assertIn("notarytool log ", calls)
        summary = (self.root / "summary").read_text()
        self.assertIn(self.env["NOTARY_SUBMISSION_ID"], summary)
        self.assertIn("In Progress", summary)
        self.assertNotEqual(self.run_step("Verify notarization result").returncode, 0)

    def test_wait_rejection_keeps_apple_log_and_blocks_release(self):
        self.stub_notary()
        self.env["FIXTURE_STATUS"] = "Invalid"
        result = self.run_step("Wait for notarization")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / "build/notarization/apple-log.json").exists())
        result = self.run_step("Verify notarization result")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid", result.stdout)

    def test_signed_archive_corruption_is_rejected(self):
        self.prepare_saved_state()
        archive = self.root / "build/release-state/Ice-notarization.zip"
        archive.write_bytes(archive.read_bytes() + b"corrupted")
        self.pack_saved_state()
        result = self.run_step("Restore original signed release state")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("archive checksum", result.stdout + result.stderr)

    def test_submission_failure_still_has_signed_state(self):
        self.prepare_saved_state(submit=False)
        self.stub("xcrun", 'echo "fixture submit failure" >&2\nexit 3\n')
        result = self.run_step("Submit Ice for notarization")
        self.assertEqual(result.returncode, 3)
        self.pack_saved_state()
        self.assertTrue((self.root / "build/recovery/ice-signed.tgz").is_file())
        metadata = json.loads((self.root / "build/release-state/release.json").read_text())
        self.assertIsNone(metadata["submission_id"])
        result = self.run_step("Record recovery instructions")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("cannot be resumed", (self.root / "summary").read_text())
        self.assertNotEqual(self.run_step("Restore original signed release state").returncode, 0)

    def test_wait_and_status_query_failures_do_not_publish(self):
        self.stub_notary()
        for wait_exit, info_exit in [(1, 0), (124, 3), (0, 3)]:
            with self.subTest(wait_exit=wait_exit, info_exit=info_exit):
                self.env.update(FIXTURE_WAIT_EXIT=str(wait_exit), FIXTURE_INFO_EXIT=str(info_exit))
                result = self.run_step("Wait for notarization")
                self.assertEqual(result.returncode, wait_exit or info_exit, result.stdout + result.stderr)

    def test_workflow_saves_before_wait_and_recovery_skips_build(self):
        steps = workflow["jobs"]["release"]["steps"]
        names = [step["name"] for step in steps]
        by_name = {step["name"]: step for step in steps}
        self.assertLess(names.index("Save signed release state"), names.index("Wait for notarization"))
        for name in ("Prepare signed release state", "Archive and export Ice", "Submit Ice for notarization",
                     "Import Apple signing identity", "Validate Apple signing identity"):
            self.assertEqual(by_name[name]["if"], "${{ github.event_name == 'push' }}")
        self.assertIn("always()", by_name["Save signed release state"]["if"])
        self.assertEqual(by_name["Save signed release state"]["with"]["path"], "build/ice-signed.tgz")
        self.assertEqual(by_name["Save notarization diagnostics"]["with"]["path"], "build/notarization/*.json")
        self.assertEqual(workflow["permissions"]["actions"], "read")

    def test_publishing_checks_tag_again_after_wait(self):
        self.stub("gh", 'echo "$*" >> "$RUNNER_TEMP/release-calls"\n')
        self.stub("git", 'if [[ "$1" == rev-parse ]]; then echo "$FIXTURE_TAG_COMMIT"; fi\n')
        self.env.update(FIXTURE_TAG_COMMIT="b" * 40, GITHUB_REF_NAME="main", RELEASE_COMMIT="a" * 40)
        result = self.run_step("Publish GitHub Release")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tag moved", result.stdout)
        self.assertFalse((self.root / "release-calls").exists())
        self.env["FIXTURE_TAG_COMMIT"] = "a" * 40
        result = self.run_step("Publish GitHub Release")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("release create v1.2.3 ", (self.root / "release-calls").read_text())

    def stub_ticket_network(self):
        (self.root / "main-pf-rules").write_text('anchor "com.apple/*" all\n')
        self.stub("sudo", '''
case "$*" in
  'pfctl -sr') cat "$RUNNER_TEMP/main-pf-rules" ;;
  'pfctl -a com.apple/ice-notarization -f -')
    if [[ "${FIXTURE_PF_LOAD_EXIT:-0}" != 0 ]]; then exit "$FIXTURE_PF_LOAD_EXIT"; fi
    cat > "$RUNNER_TEMP/ticket-pf-rules" ;;
  'pfctl -E') echo enabled > "$RUNNER_TEMP/ticket-pf-enabled" ;;
  'pfctl -a com.apple/ice-notarization -sr') cat "$RUNNER_TEMP/ticket-pf-rules" ;;
  *) echo "Unexpected privileged command: $*" >&2; exit 99 ;;
esac
''')

    def test_ticket_network_preserves_system_rules(self):
        self.stub_ticket_network()
        result = self.run_step("Use TCP for notarization tickets")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / "main-pf-rules").read_text(), 'anchor "com.apple/*" all\n')
        self.assertEqual((self.root / "ticket-pf-rules").read_text(),
                         "block return out quick proto udp from any to any port 443\n")
        self.assertEqual((self.root / "ticket-pf-enabled").read_text(), "enabled\n")

    def test_ticket_network_requires_active_system_anchor(self):
        self.stub_ticket_network()
        (self.root / "main-pf-rules").write_text('scrub-anchor "com.apple/*" all\n')
        result = self.run_step("Use TCP for notarization tickets")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "ticket-pf-rules").exists())
        self.assertFalse((self.root / "ticket-pf-enabled").exists())

    def test_ticket_network_load_failure_stops_setup(self):
        self.stub_ticket_network()
        self.env["FIXTURE_PF_LOAD_EXIT"] = "3"
        result = self.run_step("Use TCP for notarization tickets")
        self.assertEqual(result.returncode, 3, result.stdout + result.stderr)
        self.assertFalse((self.root / "ticket-pf-enabled").exists())

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
