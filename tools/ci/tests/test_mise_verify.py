"""Exercise PowerShell isolation and error propagation without installing tools."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(shutil.which("pwsh"), "PowerShell is required")
class MiseVerificationTests(unittest.TestCase):
    def run_verifier(self, *, relock=False, fail=False):
        with tempfile.TemporaryDirectory(prefix="ci-verifier-test-") as temporary:
            fixture = Path(temporary)
            for rel in ("tools/ci/mise-verify.ps1", "tools/lib/common.ps1"):
                target = fixture / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / rel, target)
            (fixture / "mise").mkdir()
            (fixture / "mise/mise.toml").write_text('[tools]\nnode = "1.0.0"\n', encoding="utf-8")
            (fixture / "mise/mise.lock").write_text('lockfile_version = 3\n# preserved\n', encoding="utf-8")
            trace = fixture / "trace.jsonl"
            wrapper = fixture / "run.ps1"
            wrapper.write_text(r'''
$ErrorActionPreference = 'Stop'
function global:mise {
    $entry = @{ args = @($args); cwd = (Get-Location).Path; config = $env:MISE_GLOBAL_CONFIG_FILE }
    $entry | ConvertTo-Json -Compress | Add-Content $env:TEST_TRACE
    if ($env:TEST_FAIL -eq '1' -and ($args -join ' ') -eq 'install --locked') {
        $global:LASTEXITCODE = 42
    } else { $global:LASTEXITCODE = 0 }
}
$before = $env:MISE_CONFIG_DIR
$originalLocation = (Get-Location).Path
try {
    if ($env:TEST_RELOCK -eq '1') { & ./tools/ci/mise-verify.ps1 -Lock }
    else { & ./tools/ci/mise-verify.ps1 }
} finally {
    if ($env:MISE_CONFIG_DIR -ne $before) { throw 'Config isolation was not restored' }
    if ((Get-Location).Path -ne $originalLocation) { throw 'Working directory was not restored' }
}
''', encoding="utf-8")
            env = dict(os.environ, TEST_TRACE=str(trace), TEST_FAIL=str(int(fail)), TEST_RELOCK=str(int(relock)))
            completed = subprocess.run(["pwsh", "-NoProfile", "-File", str(wrapper)], cwd=fixture,
                                       env=env, capture_output=True, text=True, encoding="utf-8")
            entries = [json.loads(line) for line in trace.read_text(encoding="utf-8-sig").splitlines()]
            self.assertEqual((fixture / "mise/mise.lock").read_text(encoding="utf-8"),
                             'lockfile_version = 3\n# preserved\n')
            # All operations after the version probe must run away from the checkout.
            for entry in entries[1:]:
                self.assertFalse(Path(entry["cwd"]).is_relative_to(fixture))
                self.assertNotEqual(entry["config"], os.environ.get("MISE_GLOBAL_CONFIG_FILE"))
            return completed, entries

    def test_verification_never_regenerates_lock(self):
        completed, entries = self.run_verifier()
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertFalse(any(entry["args"][0] == "lock" for entry in entries))
        installs = [entry["args"] for entry in entries if entry["args"][0] == "install"]
        self.assertTrue(all("--locked" in args for args in installs))

    def test_relock_preserves_existing_lock_and_isolates_all_installs(self):
        completed, entries = self.run_verifier(relock=True)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(sum(entry["args"] == ["lock", "--global"] for entry in entries), 2)
        self.assertIn(["install", "--locked"], [entry["args"] for entry in entries])

    def test_failed_locked_install_stops_the_job_and_restores_environment(self):
        completed, entries = self.run_verifier(relock=True, fail=True)
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("42", completed.stderr)
        self.assertEqual(entries[-1]["args"], ["install", "--locked"])


if __name__ == "__main__":
    unittest.main()
