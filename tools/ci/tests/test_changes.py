"""Regression cases for skipped required jobs and full push/PR diffs."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("changes", Path(__file__).parents[1] / "changes.py")
changes = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(changes)


class ChangesTests(unittest.TestCase):
    def test_docs_do_not_provision_toolchains(self):
        self.assertFalse(any(changes.classify(["README.md", "docs/automation.md"]).values()))

    def test_pathctl_does_not_install_host_or_actions_tools(self):
        self.assertEqual(changes.classify(["tools/pathctl/src/pathctl/cli.py"]),
                         dict(mise=False, config=False, python=True, actions=False))

    def test_host_update_does_not_block_unrelated_jobs(self):
        self.assertEqual(changes.classify(["mise/mise.toml", "mise/mise.lock"]),
                         dict(mise=True, config=True, python=False, actions=False))

    def test_ci_toolchain_and_selector_change_run_every_job(self):
        for path in ("mise.toml", "mise.lock", "tools/ci/changes.py", "tools/lib/common.ps1"):
            self.assertTrue(all(changes.classify([path]).values()), path)

    def test_new_branch_and_manual_run_check_everything(self):
        self.assertIsNone(changes.changed_paths({}, "workflow_dispatch"))
        self.assertIsNone(changes.changed_paths({"before": "0" * 40, "after": "a" * 40}, "push"))
        self.assertTrue(all(changes.classify([], all_jobs=True).values()))

    def test_pr_uses_merge_base_and_push_uses_full_range(self):
        base, head = "a" * 40, "b" * 40
        for event, payload, separator in (
            ("pull_request", {"pull_request": {"base": {"sha": base}, "head": {"sha": head}}}, "..."),
            ("push", {"before": base, "after": head}, ".."),
        ):
            with patch.object(subprocess, "check_output", return_value=b"old/file.py\0new/file.py\0") as diff:
                self.assertEqual(changes.changed_paths(payload, event), ["old/file.py", "new/file.py"])
                self.assertIn(f"{base}{separator}{head}", diff.call_args.args[0])
                self.assertIn("--no-renames", diff.call_args.args[0])

    def test_bad_event_or_sha_fails_instead_of_skipping_checks(self):
        with self.assertRaises(ValueError):
            changes.changed_paths({}, "unknown")
        with self.assertRaises(ValueError):
            changes.changed_paths({"before": "--bad", "after": "b" * 40}, "push")


if __name__ == "__main__":
    unittest.main()
