"""Human readable and machine readable output."""

import io
import os
import sys
from collections.abc import Sequence
from functools import cache
from string.templatelib import Interpolation, Template

lazy import json
lazy import unicodedata

from .model import Exit, Finding, PathEntry, Report, Severity, Tool

RESET = "\x1b[0m"
_COLOR_CODES: dict[str, str] = {
    "bold": "\x1b[1m",
    "dim": "\x1b[2m",
    "ok": "\x1b[32m",
    "warn": "\x1b[33m",
    "error": "\x1b[31m",
    "info": "\x1b[36m",
    "via": "\x1b[35m",
}
# The tables keep plain text: ANSI codes would break the column widths.
_SEVERITY_ORDER: dict[Severity, int] = {Severity.INFO: 0, Severity.WARN: 1, Severity.ERROR: 2}


def colors_enabled() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("PATHCTL_COLOR") == "1":
        return True
    return sys.stdout.isatty()


def configure_output() -> None:
    """Piped output is UTF-8 so agents and `jq` can read it regardless of the console code page.

    A TTY keeps the console encoding: PowerShell 5.1 in a cp932 console cannot render UTF-8.
    """
    if sys.stdout.isatty():
        return
    for stream in (sys.stdout, sys.stderr):
        if isinstance(stream, io.TextIOWrapper):
            stream.reconfigure(encoding="utf-8", errors="replace")


def style(template: Template, *, enabled: bool | None = None) -> str:
    """Render a t-string, where the format spec names a colour (``t"{value:ok}"``)."""
    use_color = colors_enabled() if enabled is None else enabled
    parts: list[str] = []
    for part in template:
        match part:
            case str():
                parts.append(part)
            case Interpolation():
                text = str(part.value)
                code = _COLOR_CODES.get(str(part.format_spec))
                parts.append(f"{code}{text}{RESET}" if code and use_color else text)
    return "".join(parts)


@cache
def display_width(text: str) -> int:
    """Memoized: the table renderer asks for the same cells again for every row (item 27)."""
    width = 0
    for char in text:
        if unicodedata.combining(char):
            continue
        width += 2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1
    return width


def _pad(text: str, width: int) -> str:
    return text + " " * max(0, width - display_width(text))


def table(headers: Sequence[str], rows: Sequence[Sequence[str]]) -> str:
    if not rows:
        return ""
    widths = [display_width(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], display_width(cell))
    lines = ["  ".join(_pad(h, w) for h, w in zip(headers, widths, strict=True)).rstrip()]
    lines.append("  ".join("-" * w for w in widths))
    lines.extend("  ".join(_pad(c, w) for c, w in zip(row, widths, strict=True)).rstrip() for row in rows)
    return "\n".join(lines)


def finding_dict(finding: Finding) -> dict[str, object]:
    payload: dict[str, object] = {
        "code": finding.code.value,
        "severity": finding.severity.value,
        "scope": finding.scope.value,
        "detail": finding.detail,
    }
    if finding.entries:
        payload["entries"] = list(finding.entries)
    if finding.hint:
        payload["hint"] = finding.hint
    return payload


def tool_dict(tool: Tool) -> dict[str, object]:
    return {
        "name": tool.name,
        "provenance": tool.provenance.value,
        "path": tool.resolved,
        "found_in": list(tool.found_in),
        "via_mise": tool.via_mise,
        "without_mise": tool.without_mise,
        "available": tool.available,
        "shadowed_by": tool.shadowed_by,
    }


def entry_dict(entry: PathEntry) -> dict[str, object]:
    return {
        "scope": entry.scope.value,
        "index": entry.index,
        "raw": entry.raw,
        "expanded": entry.value,
        "exists": entry.exists,
        "user_specific": entry.user_specific,
        "empty": entry.empty,
    }


def to_json(report: Report) -> str:
    try:
        category = Exit(report.exit_code).category
    except ValueError:
        category = "general"
    payload: dict[str, object] = {
        "schema": "pathctl/1",
        "kind": report.kind or report.command,
        "command": report.command,
        "ok": report.ok,
        "exit_code": report.exit_code,
        "category": category,
        "data": report.data,
        "findings": [finding_dict(item) for item in report.findings],
        "hints": list(report.hints),
    }
    if report.error is not None:
        payload["error"] = report.error.as_dict()
    return json.dumps(payload, ensure_ascii=False, indent=2)


def _clean(cell: str) -> str:
    return cell.replace("\t", " ").replace("\r", " ").replace("\n", " ")


def to_tsv(rows: Sequence[Sequence[str]]) -> str:
    """Data rows only (no header) so `awk -F'\\t'` and `cut` work without skipping a line."""
    return "\n".join("\t".join(_clean(cell) for cell in row) for row in rows)


def tools_rows(tools: Sequence[Tool]) -> list[list[str]]:
    return [
        [tool.name, tool.provenance.value, "yes" if tool.without_mise else "no", tool.resolved or "-"]
        for tool in tools
    ]


def path_rows(entries: Sequence[PathEntry]) -> list[list[str]]:
    return [
        [
            entry.scope.value,
            str(entry.index + 1),
            entry.raw if not entry.empty else "(empty)",
            "yes" if entry.exists else "no",
            "yes" if entry.user_specific else "no",
        ]
        for entry in entries
    ]


TOOLS_HEADERS: tuple[str, ...] = ("TOOL", "VIA（入手元）", "MISEなし", "解決先")
PATH_HEADERS: tuple[str, ...] = ("SCOPE", "#", "PATH エントリ", "exists", "固有")


def render(report: Report, *, json_mode: bool, body: str = "") -> None:
    """Print the report as JSON (for agents) or as the prepared human body."""
    if json_mode:
        print(to_json(report))
    elif body:
        print(body)


def findings_block(findings: Sequence[Finding], *, color: bool | None = None) -> str:
    if not findings:
        return style(t"  問題は見つかりませんでした（findings 0 件）", enabled=color)
    # Resolve the colour decision once instead of once per finding (isatty + env lookups).
    use_color = colors_enabled() if color is None else color
    ordered = sorted(findings, key=lambda item: -_SEVERITY_ORDER[item.severity])
    lines: list[str] = []
    for finding in ordered:
        tag = {"info": "info ", "warn": "warn ", "error": "error"}[finding.severity.value]
        lines.append(style(t"{tag} [{finding.code}] {finding.detail}", enabled=use_color))
        if finding.hint:
            lines.append(style(t"        → {finding.hint}", enabled=use_color))
    return "\n".join(lines)


def tools_block(tools: Sequence[Tool]) -> str:
    return table(TOOLS_HEADERS, tools_rows(tools))
