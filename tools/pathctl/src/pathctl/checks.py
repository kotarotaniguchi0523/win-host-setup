"""Checks that turn the PATH state into structured findings."""

from pathlib import Path
from typing import Iterable

lazy import itertools
lazy from collections import Counter, defaultdict

from .model import Finding, FindingCode, PathEntry, Scope, Severity, Tool
from .tools import known_dirs
from .winenv import effective_entries, normalize, stored_entries

SCOPES: tuple[Scope, ...] = (Scope.MACHINE, Scope.USER)


def _duplicates(entries: Iterable[PathEntry]) -> dict[str, list[PathEntry]]:
    grouped: dict[str, list[PathEntry]] = defaultdict(list)
    for entry in entries:
        if entry.empty:
            continue
        grouped[normalize(entry.raw)].append(entry)
    return {key: group for key, group in grouped.items() if len(group) > 1}


def check_scope(scope: Scope, entries: list[PathEntry], *, shims: Path | None) -> list[Finding]:
    """Rules that only need one scope."""
    findings: list[Finding] = []

    for entry in entries:
        if entry.empty:
            findings.append(
                Finding(
                    code=FindingCode.EMPTY_ENTRY,
                    severity=Severity.WARN,
                    scope=scope,
                    detail=f"位置 {entry.index + 1} が空です（余分な区切り文字）",
                    entries=(entry.raw,),
                    hint="pathctl path fix --apply で取り除けます",
                )
            )

    for key, group in _duplicates(entries).items():
        positions = ", ".join(str(item.index + 1) for item in group)
        findings.append(
            Finding(
                code=FindingCode.DUPLICATE_IN_SCOPE,
                severity=Severity.WARN,
                scope=scope,
                detail=f"同じディレクトリが {len(group)} 回あります（位置 {positions}）",
                entries=tuple(item.raw for item in group),
                hint=f"pathctl path fix --scope {scope.value} --apply で 1 つに統合できます",
            )
        )

    for entry in entries:
        if scope is Scope.MACHINE and entry.user_specific:
            findings.append(
                Finding(
                    code=FindingCode.USER_PATH_IN_MACHINE,
                    severity=Severity.ERROR,
                    scope=scope,
                    detail=f"ユーザー固有のパスがマシン PATH にあります: {entry.raw}",
                    entries=(entry.raw,),
                    hint="pathctl path fix --move-user-entries --apply（管理者）でユーザー PATH へ移せます",
                )
            )
        elif not entry.empty and not entry.exists:
            findings.append(
                Finding(
                    code=FindingCode.MISSING_DIRECTORY,
                    severity=Severity.WARN,
                    scope=scope,
                    detail=f"存在しないディレクトリ: {entry.raw}",
                    entries=(entry.raw,),
                    hint="アンインストールの残骸なら pathctl path fix --prune-missing --apply で除去できます",
                )
            )
        elif entry.raw.endswith("\\") and len(entry.raw) > 3:
            findings.append(
                Finding(
                    code=FindingCode.TRAILING_SEPARATOR,
                    severity=Severity.INFO,
                    scope=scope,
                    detail=f"末尾の区切りが余分です: {entry.raw}",
                    entries=(entry.raw,),
                )
            )

    if scope is Scope.USER and shims is not None:
        shim_key = normalize(str(shims))
        keys = [normalize(entry.raw) for entry in entries if not entry.empty]
        if shim_key in keys and keys.index(shim_key) != 0:
            findings.append(
                Finding(
                    code=FindingCode.MISE_SHIMS_NOT_FIRST,
                    severity=Severity.WARN,
                    scope=scope,
                    detail="mise shims がユーザー PATH の先頭にありません",
                    entries=(str(shims),),
                    hint="後ろにある別のディレクトリが同名コマンドを隠す可能性があります",
                )
            )
    return findings


def check_cross_scope(machine: list[PathEntry], user: list[PathEntry]) -> list[Finding]:
    """Entries that appear in both scopes (usually duplicated by an installer)."""
    machine_keys = {normalize(entry.raw) for entry in machine if not entry.empty}
    findings: list[Finding] = []
    for entry in user:
        if entry.empty:
            continue
        if normalize(entry.raw) in machine_keys:
            findings.append(
                Finding(
                    code=FindingCode.DUPLICATE_ACROSS_SCOPES,
                    severity=Severity.INFO,
                    scope=Scope.USER,
                    detail=f"マシン PATH とユーザー PATH の両方にあります: {entry.raw}",
                    entries=(entry.raw,),
                    hint="マシン側を残してユーザー側から消すと、新しいシェルで順序が安定します",
                )
            )
    return findings


def check_path() -> list[Finding]:
    """All PATH findings for the stored scopes."""
    dirs = known_dirs()
    machine = stored_entries(Scope.MACHINE)
    user = stored_entries(Scope.USER)
    findings = check_scope(Scope.MACHINE, machine, shims=dirs.mise_shims)
    findings += check_scope(Scope.USER, user, shims=dirs.mise_shims)
    findings += check_cross_scope(machine, user)
    return findings


def check_tools(tools: list[Tool]) -> list[Finding]:
    """Findings that need the tool inventory."""
    findings: list[Finding] = []
    for tool in tools:
        if tool.shadowed_by:
            findings.append(
                Finding(
                    code=FindingCode.TOOL_SHADOWED,
                    severity=Severity.INFO,
                    scope=Scope.EFFECTIVE,
                    detail=f"{tool.name} は mise shim ではなく {tool.shadowed_by} から解決されます",
                    entries=(tool.resolved or "",),
                    hint="mise でバージョンを切り替えても効かないコマンドです",
                )
            )
        elif not tool.available:
            findings.append(
                Finding(
                    code=FindingCode.TOOL_NOT_ON_PATH,
                    severity=Severity.INFO,
                    scope=Scope.EFFECTIVE,
                    detail=f"{tool.name} はインストール済みですが PATH から解決できません",
                    hint=f"必要なら pathctl path add <dir> --scope user で追加してください（入手元: {tool.provenance.value}）",
                )
            )
    return findings


def summarize(findings: Iterable[Finding]) -> dict[str, int]:
    counts = Counter(finding.severity for finding in findings)
    return {severity.value: counts.get(severity, 0) for severity in Severity}


def worst_severity(findings: Iterable[Finding]) -> Severity | None:
    order = {Severity.INFO: 0, Severity.WARN: 1, Severity.ERROR: 2}
    worst: Severity | None = None
    for finding in findings:
        if worst is None or order[finding.severity] > order[worst]:
            worst = finding.severity
    return worst


def effective_summary() -> dict[str, int]:
    entries = effective_entries()
    stored = list(itertools.chain(stored_entries(Scope.MACHINE), stored_entries(Scope.USER)))
    return {
        "entries": len(entries),
        "existing": sum(1 for entry in entries if entry.exists),
        "missing": sum(1 for entry in entries if not entry.empty and not entry.exists),
        "empty": sum(1 for entry in entries if entry.empty),
        "stored": len([entry for entry in stored if not entry.empty]),
    }
