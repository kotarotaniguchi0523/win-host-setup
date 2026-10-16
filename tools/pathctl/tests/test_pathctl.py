"""Unit tests for pathctl (stdlib `unittest` only, as Effective Python item 65 suggests).

They cover the platform-independent logic, so the same suite runs on Windows and on the
Linux runner. Anything that touches the registry is exercised through its pure helpers.
"""

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

from pathctl import __version__, docs
from pathctl.checks import summarize
from pathctl.cli import build_parser, collect_commands, main
from pathctl.fix import _canonical, merged_user_entries
from pathctl.model import Error, Exit, Finding, FindingCode, PathEntry, Report, Scope, Severity, Tool, ToolProvenance
from pathctl.render import display_width, finding_dict, table, to_json, to_tsv, tool_dict, tools_rows
from pathctl.tools import _strip_backend, find_all


def make_entry(raw: str, *, index: int = 0, scope: Scope = Scope.USER, exists: bool = True) -> PathEntry:
    return PathEntry(scope=scope, index=index, raw=raw, value=raw, exists=exists, user_specific=False, empty=False)


class DisplayWidthTest(unittest.TestCase):
    def test_ascii_is_one_column_per_char(self) -> None:
        self.assertEqual(display_width("abc"), 3)

    def test_wide_characters_count_two_columns(self) -> None:
        self.assertEqual(display_width("パス"), 4)

    def test_combining_marks_do_not_add_width(self) -> None:
        self.assertEqual(display_width("e\u0301"), 1)


class TableTest(unittest.TestCase):
    def test_empty_rows_returns_empty_string(self) -> None:
        self.assertEqual(table(["a"], []), "")

    def test_columns_are_aligned_by_display_width(self) -> None:
        rendered = table(["名前", "v"], [["a", "1"], ["あ", "22"]])
        lines = rendered.splitlines()
        self.assertEqual(len(lines), 4)  # header + separator + 2 rows
        self.assertTrue(lines[2].startswith("a"))


class TsvTest(unittest.TestCase):
    def test_tsv_has_no_header_and_tabs_only(self) -> None:
        rendered = to_tsv([["a", "b"], ["c", "d"]])
        self.assertEqual(rendered, "a\tb\nc\td")

    def test_cells_are_sanitized(self) -> None:
        self.assertEqual(to_tsv([["a\tb", "c\nd"]]), "a b\tc d")


class ModelTest(unittest.TestCase):
    def test_exit_categories(self) -> None:
        self.assertEqual({item.value: item.category for item in Exit}[5], "validation")
        self.assertEqual(Exit.NOT_FOUND.category, "not_found")

    def test_error_payload_only_lists_what_is_set(self) -> None:
        minimal = Error(category="config", message="boom")
        self.assertEqual(minimal.as_dict(), {"category": "config", "message": "boom"})
        rich = Error(category="not_found", message="boom", next_step="retry", candidates=("a",), required_args=("--x",))
        self.assertEqual(rich.as_dict()["candidates"], ["a"])
        self.assertEqual(rich.as_dict()["required_args"], ["--x"])

    def test_tool_properties(self) -> None:
        shimmed = Tool(name="node", provenance=ToolProvenance.MISE_SHIM, resolved="C:/mise/shims/node.exe", found_in=("C:/mise/shims",))
        self.assertTrue(shimmed.via_mise)
        self.assertFalse(shimmed.without_mise)
        mixed = Tool(name="fd", provenance=ToolProvenance.WINGET, resolved="C:/winget/fd.exe", found_in=("C:/mise/shims", "C:/winget"))
        self.assertTrue(mixed.without_mise)
        missing = Tool(name="ghost", provenance=ToolProvenance.MISE_INSTALL, resolved=None)
        self.assertFalse(missing.available)


class RenderTest(unittest.TestCase):
    def test_envelope_has_the_documented_keys(self) -> None:
        report = Report(
            command="doctor",
            kind="doctor",
            ok=False,
            exit_code=int(Exit.VALIDATION),
            data={"x": 1},
            findings=(Finding(code=FindingCode.USER_PATH_IN_MACHINE, severity=Severity.ERROR, scope=Scope.MACHINE, detail="d"),),
            hints=("h",),
            error=Error(category="validation", message="m"),
        )
        payload = json.loads(to_json(report))
        self.assertEqual(payload["schema"], "pathctl/1")
        self.assertEqual(payload["category"], "validation")
        self.assertEqual(payload["exit_code"], 5)
        self.assertEqual(payload["findings"][0]["code"], "user-path-in-machine")
        self.assertEqual(payload["error"]["message"], "m")

    def test_finding_and_tool_dicts_are_serializable(self) -> None:
        finding = Finding(code=FindingCode.EMPTY_ENTRY, severity=Severity.WARN, scope=Scope.USER, detail="d", entries=("",))
        self.assertEqual(finding_dict(finding)["entries"], [""])
        rows = tools_rows([Tool(name="n", provenance=ToolProvenance.DIRECT, resolved="C:/x/n.exe", found_in=("C:/x",))])
        self.assertEqual(rows[0][2], "yes")
        self.assertEqual(tool_dict(Tool(name="n", provenance=ToolProvenance.DIRECT, resolved=None))["path"], None)


class FixHelperTest(unittest.TestCase):
    def test_canonical_strips_trailing_separator_but_not_the_root(self) -> None:
        self.assertEqual(_canonical("C:\\tools\\"), "C:\\tools")
        self.assertEqual(_canonical("C:\\"), "C:\\")

    def test_merged_user_entries_appends_once_case_insensitively(self) -> None:
        merged = merged_user_entries(["C:\\a"], ["c:\\A", "C:\\b"])
        self.assertEqual(merged, ["C:\\a", "C:\\b"])


class ToolsHelperTest(unittest.TestCase):
    def test_backend_prefix_is_stripped(self) -> None:
        self.assertEqual(_strip_backend("npm-secretlint"), "secretlint")
        self.assertEqual(_strip_backend("github-jdx-jactionlint"), "jdx-jactionlint")
        self.assertEqual(_strip_backend("betterleaks"), "betterleaks")

    def test_find_all_keeps_path_order(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            for directory in (first, second):
                Path(directory, "tool.exe").write_text("", encoding="utf-8")
            entries = [make_entry(first, index=0), make_entry(second, index=1)]
            self.assertEqual(find_all("tool", entries), [Path(first, "tool.exe"), Path(second, "tool.exe")])
            self.assertEqual(find_all("missing", entries), [])


class CliDescriptionTest(unittest.TestCase):
    def test_canonical_commands_and_aliases(self) -> None:
        specs = collect_commands()
        for name in ("path list", "path check", "path fix", "path add", "path remove", "tools", "doctor", "describe"):
            self.assertIn(name, specs)
        parser = build_parser()
        self.assertIn("list-tools", str(parser.format_help()))

    def test_command_spec_describes_flags_and_formats(self) -> None:
        spec = collect_commands()["path fix"]
        flags = spec["flags"]
        notes = spec["notes"]
        if not isinstance(flags, list) or not isinstance(notes, list):
            self.fail("flags and notes must be lists")
        names = [flag["name"] for flag in flags if isinstance(flag, dict)]
        self.assertIn("--apply", names)
        self.assertIn("--dry-run", names)
        self.assertIn("何も書き換えない限り --apply は不要（既定は下見）", notes)

    def test_describe_json_envelope(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = main(["describe", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(payload["kind"], "describe.cli")
        self.assertIn("command_specs", payload["data"])

    def test_unknown_describe_target_exits_not_found(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = main(["describe", "no", "such", "command", "--format", "json"])
        self.assertEqual(code, Exit.NOT_FOUND)
        payload = json.loads(buffer.getvalue())
        self.assertIn("candidates", payload["error"])

    def test_tsv_is_rejected_where_it_is_not_supported(self) -> None:
        stderr = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
            code = main(["doctor", "--format", "tsv"])
        self.assertEqual(code, Exit.USAGE)
        self.assertIn("tsv", stderr.getvalue())

    def test_version_is_exposed(self) -> None:
        self.assertRegex(__version__, r"^\d+\.\d+\.\d+$")


class DocsTest(unittest.TestCase):
    def test_available_lists_the_bundled_guides(self) -> None:
        names = [name for name, _summary in docs.available()]
        self.assertEqual(names, sorted(names))
        self.assertIn("agents", names)
        self.assertTrue(all(summary for _name, summary in docs.available()))

    def test_read_returns_markdown_and_rejects_unknown_names(self) -> None:
        self.assertIn("pathctl", docs.read("overview"))
        with self.assertRaises(docs.DocError):
            docs.read("nope")

    def test_docs_list_json_lists_names(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = main(["docs", "list", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        payload = json.loads(buffer.getvalue())
        self.assertEqual(payload["kind"], "docs")
        self.assertTrue(any(item["name"] == "agents" for item in payload["data"]["docs"]))

    def test_docs_show_unknown_name_exits_not_found(self) -> None:
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            code = main(["docs", "show", "nope", "--format", "json"])
        self.assertEqual(code, Exit.NOT_FOUND)
        payload = json.loads(buffer.getvalue())
        self.assertIn("agents", payload["error"]["candidates"])


class SummaryTest(unittest.TestCase):
    def test_summarize_counts_every_severity(self) -> None:
        counts = summarize(
            [
                Finding(code=FindingCode.EMPTY_ENTRY, severity=Severity.ERROR, scope=Scope.USER, detail="d"),
                Finding(code=FindingCode.EMPTY_ENTRY, severity=Severity.INFO, scope=Scope.USER, detail="d"),
            ]
        )
        self.assertEqual(counts, {"info": 1, "warn": 0, "error": 1})


if __name__ == "__main__":
    unittest.main()
