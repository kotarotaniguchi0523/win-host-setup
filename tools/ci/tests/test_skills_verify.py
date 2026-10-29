"""The lock resolver and frozen verifier must use different APM operations."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]


@unittest.skipUnless(shutil.which("pwsh"), "PowerShell is required")
class SkillsVerificationTests(unittest.TestCase):
    def invoke(self, relock=False):
        with tempfile.TemporaryDirectory(prefix="skills-ci-test-") as temporary:
            fixture = Path(temporary)
            for rel in ("tools/ci/skills-verify.ps1", "tools/lib/common.ps1"):
                target = fixture / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / rel, target)
            with (fixture / "tools/lib/common.ps1").open("a", encoding="utf-8") as common:
                common.write("\nfunction Resolve-Apm { return 'apm' }\nfunction Get-HomeDir { return $env:TEST_HOME }\n")
            (fixture / "skills").mkdir()
            (fixture / "skills/apm.yml").write_text("name: fixture\n", encoding="utf-8")
            (fixture / "skills/apm.lock.yaml").write_text(
                "dependencies:\n- repo_url: example/package\n  resolved_commit: " + "a" * 40 + "\n", encoding="utf-8")
            trace = fixture / "trace.jsonl"
            wrapper = fixture / "run.ps1"
            wrapper.write_text('''
$ErrorActionPreference = 'Stop'
function global:apm {
    ConvertTo-Json -InputObject @($args) -Compress | Add-Content $env:TEST_TRACE
    $global:LASTEXITCODE = 0
}
if ($env:TEST_RELOCK -eq '1') { & ./tools/ci/skills-verify.ps1 -SkipAudit -Relock }
else { & ./tools/ci/skills-verify.ps1 -SkipAudit }
''', encoding="utf-8")
            env = dict(os.environ, TEST_TRACE=str(trace), TEST_HOME=str(fixture / "home"), TEST_RELOCK=str(int(relock)))
            process = subprocess.run(["pwsh", "-NoProfile", "-File", str(wrapper)], cwd=fixture,
                                     env=env, capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(process.returncode, 0, process.stderr)
            return [json.loads(line) for line in trace.read_text(encoding="utf-8-sig").splitlines()]

    def test_verification_replays_lock_without_resolving_refs(self):
        self.assertEqual(self.invoke(), [["install", "--global", "--frozen"]])

    def test_relock_refreshes_refs_and_records_deployment_inventory(self):
        self.assertEqual(self.invoke(relock=True), [
            ["lock", "--global", "--update"], ["install", "--global"],
        ])


if __name__ == "__main__":
    unittest.main()
