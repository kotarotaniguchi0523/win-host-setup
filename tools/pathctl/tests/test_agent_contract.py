"""Mechanical checks for the eight agent-friendly CLI principles (Zenn: 設計原則8選).

Each test names the principle it enforces, so a regression shows up as a failing principle
instead of a claim in a document. Everything runs in-process with `unittest` (no extra deps).
"""

import contextlib
import io
import json
import sys
import unittest
from pathlib import Path

import pathctl
from pathctl.cli import main
from pathctl.model import Exit, Report
from pathctl.render import to_json


def run(args: list[str]) -> tuple[int, str, str]:
    """Run the CLI in-process and capture (exit_code, stdout, stderr).

    argparse exits through SystemExit for --help / usage errors, so that is folded into the code.
    """
    out, err = io.StringIO(), io.StringIO()
    code: int = 0
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(args)
    except SystemExit as exc:
        code = exc.code if isinstance(exc.code, int) else int(Exit.FAILURE)
    return code, out.getvalue(), err.getvalue()


class Principle1StructuredOutput(unittest.TestCase):
    """必須: parseable data on stdout, messages elsewhere."""

    def test_json_goes_to_stdout_only(self) -> None:
        code, out, err = run(["docs", "list", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        json.loads(out)
        self.assertNotIn("{", err)

    def test_envelope_has_the_documented_keys(self) -> None:
        _code, out, _err = run(["describe", "--format", "json"])
        payload = json.loads(out)
        for key in ("schema", "kind", "command", "ok", "exit_code", "category", "data", "findings", "hints"):
            self.assertIn(key, payload)

    def test_tsv_is_tab_separated_without_a_header(self) -> None:
        code, out, _err = run(["docs", "list", "--format", "tsv"])
        self.assertEqual(code, Exit.OK)
        lines = out.strip().splitlines()
        self.assertTrue(lines)
        self.assertTrue(all("\t" in line for line in lines))


class Principle2SemanticExitCodes(unittest.TestCase):
    """必須: the caller can branch on the code without reading the message."""

    def test_categories_are_stable(self) -> None:
        self.assertEqual(
            {item.value: item.category for item in Exit},
            {0: "ok", 1: "general", 2: "usage", 3: "not_found", 4: "config", 5: "validation"},
        )

    def test_success_is_zero_and_not_found_is_three(self) -> None:
        self.assertEqual(run(["describe", "--format", "json"])[0], Exit.OK)
        self.assertEqual(run(["docs", "show", "nope", "--format", "json"])[0], Exit.NOT_FOUND)

    def test_usage_error_is_two(self) -> None:
        code, _out, err = run(["path", "list", "--scope", "bogus"])
        self.assertEqual(code, Exit.USAGE)
        self.assertIn("invalid choice", err)

    def test_validation_category_reaches_the_json(self) -> None:
        payload = json.loads(to_json(Report(command="x", kind="x", ok=False, exit_code=int(Exit.VALIDATION))))
        self.assertEqual(payload["category"], "validation")
        self.assertEqual(payload["exit_code"], 5)


class Principle3NonInteractive(unittest.TestCase):
    """必須: never prompt, never need the network."""

    def test_shipped_code_has_no_prompts_or_network_calls(self) -> None:
        package = Path(pathctl.__file__).parent
        sources = "\n".join(path.read_text(encoding="utf-8") for path in sorted(package.rglob("*.py")))
        for forbidden in ("input(", "getpass", "urllib", "requests", "socket."):
            self.assertNotIn(forbidden, sources)


class Principle4NounVerb(unittest.TestCase):
    """必須: predictable `noun verb` shape, with aliases kept for compatibility."""

    def test_help_lists_the_nouns(self) -> None:
        code, out, _err = run(["--help"])
        self.assertEqual(code, Exit.OK)
        for noun in ("path", "tools", "docs", "doctor", "describe"):
            self.assertIn(noun, out)

    def test_aliases_resolve_to_the_canonical_command(self) -> None:
        code, out, _err = run(["list-tools", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        self.assertEqual(json.loads(out)["kind"], "tools")
        code, out, _err = run(["schema", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        self.assertEqual(json.loads(out)["kind"], "describe.cli")


class Principle5SelfDescribing(unittest.TestCase):
    """強く推奨: `describe` answers "what flags can I pass?" as data."""

    def test_every_command_has_usage_flags_examples_and_formats(self) -> None:
        _code, out, _err = run(["describe", "--format", "json"])
        specs = json.loads(out)["data"]["command_specs"]
        for expected in ("path list", "path fix", "path add", "tools", "docs show", "doctor", "describe"):
            self.assertIn(expected, specs)
            spec = specs[expected]
            self.assertTrue(spec["usage"], expected)
            self.assertTrue(spec["examples"], expected)
            self.assertIn("json", spec["output_formats"])

    def test_flags_are_described_with_defaults(self) -> None:
        _code, out, _err = run(["describe", "path", "fix", "--format", "json"])
        spec = json.loads(out)["data"]
        flags = {flag["name"]: flag for flag in spec["flags"]}
        self.assertEqual(flags["--apply"]["type"], "boolean")
        self.assertEqual(flags["--scope"]["default"], "all")
        self.assertIn("machine", flags["--scope"]["choices"])


class Principle6ActionableErrors(unittest.TestCase):
    """強く推奨: an error says what to try next."""

    def test_error_carries_category_message_and_next_step(self) -> None:
        _code, out, _err = run(["docs", "show", "nope", "--format", "json"])
        error = json.loads(out)["error"]
        self.assertEqual(error["category"], "not_found")
        self.assertTrue(error["message"])
        self.assertTrue(error["next_step"])
        self.assertIn("agents", error["candidates"])


class Principle7Idempotent(unittest.TestCase):
    """推奨: preview by default, safe to re-run."""

    @unittest.skipUnless(sys.platform == "win32", "the registry is Windows-only")
    def test_fix_defaults_to_dry_run(self) -> None:
        code, out, _err = run(["path", "fix", "--scope", "user", "--format", "json"])
        payload = json.loads(out)
        self.assertEqual(code, Exit.OK)
        self.assertIs(payload["data"]["dry_run"], True)
        self.assertIs(payload["data"]["applied"], False)

    @unittest.skipUnless(sys.platform == "win32", "the registry is Windows-only")
    def test_remove_of_an_absent_entry_is_a_success(self) -> None:
        code, out, _err = run(["path", "remove", r"C:\definitely-not-in-path", "--format", "json"])
        self.assertEqual(code, Exit.OK)
        payload = json.loads(out)
        self.assertIs(payload["data"]["changed"], False)
        self.assertTrue(any("変更なし" in hint for hint in payload["hints"]))


class Principle8Composable(unittest.TestCase):
    """推奨: JSON for jq, TSV for awk/cut."""

    def test_tools_tsv_has_four_stable_columns(self) -> None:
        _code, out, _err = run(["tools", "--format", "tsv"])
        for line in out.strip().splitlines():
            self.assertEqual(len(line.split("\t")), 4)

    def test_unsupported_tsv_reports_usage_error(self) -> None:
        code, _out, err = run(["doctor", "--format", "tsv"])
        self.assertEqual(code, Exit.USAGE)
        self.assertIn("tsv", err)


if __name__ == "__main__":
    unittest.main()
