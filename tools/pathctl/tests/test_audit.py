"""Audit tests: which global installations count as stray (no declaration owns them)."""

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from pathctl import audit
from pathctl.model import FindingCode, PathEntry, Scope, Severity


def make_entry(raw: str, *, scope: Scope = Scope.USER, index: int = 0) -> PathEntry:
    return PathEntry(scope=scope, index=index, raw=raw, value=raw, exists=True, user_specific=False, empty=False)


class MiseAuditTest(unittest.TestCase):
    def test_tool_from_the_global_config_is_fine(self) -> None:
        config = str(audit.mise_config())
        data: dict[str, object] = {"node": [{"version": "26.11.1", "source": {"type": "mise.toml", "path": config}}]}
        self.assertEqual(audit.mise_strays(data), [])

    def test_tool_from_another_config_is_stray(self) -> None:
        data: dict[str, object] = {
            "node": [{"version": "26.11.1", "source": {"type": "mise.toml", "path": "C:/project/mise.toml"}}]
        }
        strays = audit.mise_strays(data)
        self.assertEqual(len(strays), 1)
        self.assertEqual(strays[0].kind, "mise")
        self.assertEqual(strays[0].name, "node")

    def test_missing_data_is_not_an_error(self) -> None:
        self.assertEqual(audit.mise_strays(None), [])


class PackageDirAuditTest(unittest.TestCase):
    def test_npm_globals_are_listed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "npm" / "node_modules"
            (root / "typescript").mkdir(parents=True)
            (root / "left-pad").mkdir()
            with mock.patch.dict(os.environ, {"APPDATA": tmp}):
                names = sorted(item.name for item in audit.npm_strays())
        self.assertEqual(names, ["left-pad", "typescript"])

    def test_uv_tools_are_listed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "uv" / "tools"
            (root / "black").mkdir(parents=True)
            with mock.patch.dict(os.environ, {"LOCALAPPDATA": tmp}):
                names = [item.name for item in audit.uv_strays()]
        self.assertEqual(names, ["black"])

    def test_missing_directories_are_quiet(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.dict(os.environ, {"APPDATA": tmp, "LOCALAPPDATA": tmp}):
                self.assertEqual(audit.npm_strays(), [])
                self.assertEqual(audit.uv_strays(), [])


class PathAuditTest(unittest.TestCase):
    def test_managed_roots_are_allowed(self) -> None:
        allowed = [
            make_entry(r"C:\Users\x\AppData\Local\mise\shims"),
            make_entry(r"C:\Users\x\AppData\Local\Microsoft\WinGet\Packages\Vendor.Tool_abc\bin"),
            make_entry(r"C:\Users\x\.local\bin"),
            make_entry(r"C:\Program Files\Git\cmd"),
        ]
        self.assertEqual(audit.path_strays(allowed), [])

    def test_inventory_leftovers_are_reported(self) -> None:
        entries = [
            make_entry(r"C:\Users\x\AppData\Roaming\npm"),
            make_entry(r"C:\Users\x\go\bin"),
        ]
        names = sorted(item.name for item in audit.path_strays(entries))
        self.assertEqual(len(names), 2)

    def test_machine_scope_is_ignored(self) -> None:
        entry = make_entry(r"C:\Something", scope=Scope.MACHINE)
        self.assertEqual(audit.path_strays([entry]), [])


class SeverityTest(unittest.TestCase):
    def test_package_strays_warn_and_path_entries_inform(self) -> None:
        strays = [
            audit.Stray("npm", "typescript", "x", "h"),
            audit.Stray("path", "C:/x", "C:/x", "h"),
        ]
        found = audit.findings(strays)
        self.assertEqual(found[0].severity, Severity.WARN)
        self.assertEqual(found[0].code, FindingCode.STRAY_NPM_GLOBAL)
        self.assertEqual(found[1].severity, Severity.INFO)
        self.assertEqual(found[1].code, FindingCode.UNMANAGED_PATH_ENTRY)


if __name__ == "__main__":
    unittest.main()
