"""pathctl - inspect and repair the Windows global PATH (stdlib only).

The interface follows the agent-friendly CLI checklist:
  1. structured output   `--format table|json|tsv` (stdout carries data only)
  2. semantic exit codes `Exit` (0 ok / 1 general / 2 usage / 3 not-found / 4 config / 5 validation)
  3. non-interactive     never prompts, never uses the network
  4. noun-verb grammar   `path <verb>` / `tools` / `describe`
  5. self-describing     `pathctl describe [<command>] --format json`
  6. actionable errors   `error.category` / `next_step` / `candidates`
  7. idempotent          every write command has a preview and only changes what is missing
  8. composable          JSON for `jq`, TSV for `awk`
"""

import argparse
import os
import sys
from collections.abc import Sequence
from dataclasses import dataclass, field

lazy import fnmatch

from . import __version__, audit, docs
from .checks import check_path, check_tools, effective_summary, summarize
from .fix import add_entry, apply, plan, remove_entry
from .model import Error, Exit, Finding, Report, Scope, Severity, Tool, ToolProvenance
from .render import (
    PATH_HEADERS,
    TOOLS_HEADERS,
    configure_output,
    entry_dict,
    findings_block,
    path_rows,
    style,
    table,
    to_json,
    to_tsv,
    tool_dict,
    tools_block,
    tools_rows,
)
from .schema import describe_cli
from .tools import inventory, known_dirs
from .winenv import effective_entries, is_admin, stored_entries

ALL_SCOPES: tuple[Scope, ...] = (Scope.MACHINE, Scope.USER)
SCOPE_CHOICES: tuple[str, ...] = ("machine", "user", "effective", "all")
FORMATS: tuple[str, ...] = ("table", "json", "tsv")

EXAMPLES: dict[str, list[str]] = {
    "path list": [
        "pathctl path list --scope user",
        "pathctl path list --scope all --format tsv",
    ],
    "path check": ["pathctl path check --format json"],
    "path fix": [
        "pathctl path fix --move-user-entries --format json",
        "pathctl path fix --scope user --apply",
    ],
    "path add": ["pathctl path add '%USERPROFILE%\\.local\\bin' --scope user --apply"],
    "path remove": ["pathctl path remove '%USERPROFILE%\\.local\\bin' --apply"],
    "tools": ["pathctl tools --without-mise", "pathctl tools --format tsv"],
    "doctor": ["pathctl doctor --format json"],
    "describe": ["pathctl describe", "pathctl describe path fix --format json"],
    "docs list": ["pathctl docs list", "pathctl docs list --format tsv"],
    "docs show": ["pathctl docs show agents"],
    "audit": ["pathctl audit", "pathctl audit --format json"],
}

NOTES: dict[str, list[str]] = {
    "path fix": [
        "何も書き換えない限り --apply は不要（既定は下見）",
        "機械 PATH の書き換えには管理者権限が必要（無い場合は exit 4）",
        "個人パスの移動と存在しないパスの削除は明示フラグが要る",
    ],
    "tools": ["without_mise=yes は mise が無くても PATH から起動できるコマンド"],
    "doctor": ["--strict を付けると info/warn でも exit 5"],
    "describe": ["エージェントは最初にこれを読む（フラグ一覧を JSON で返す）"],
    "docs list": ["同梱ガイド。Web Fetch せずにここから読む"],
    "docs show": ["ガイド本文を stdout に出す（--format json なら data.text）"],
    "audit": [
        "宣言（mise のグローバル設定 / winget の DSC）に無いグローバル導入＝野良を一覧する",
        "WARN はパッケージマネージャ由来、PATH の項目は INFO（アプリのインストーラが足すため）",
        "方針: グローバルは mise か winget に集約し、それ以外は SBX（Docker Sandboxes）で実行する",
    ],
}

# Shown in --help: agents should read the machine-readable contract instead of scraping help.
AGENT_HINT: str = (
    "If you are a coding agent: run 'pathctl describe --format json' for the command contract and "
    "'pathctl docs list' / 'pathctl docs show <name>' for the guides before answering questions "
    "or retrying an error."
)
ADMIN_HINT: str = (
    "機械 PATH の変更は管理者権限が要ります。エージェントは自分で昇格できないので、"
    "ユーザーに管理者ターミナルで同じコマンドを実行してもらってください。"
)


@dataclass(slots=True)
class Output:
    """What a command produced: the report plus the human/TSV renderings."""

    report: Report
    table_text: str = ""
    tsv_text: str = ""
    formats: tuple[str, ...] = field(default=("table", "json"))


def _report(
    command: str,
    *,
    kind: str,
    data: dict[str, object] | None = None,
    exit_code: Exit = Exit.OK,
    findings: Sequence[Finding] = (),
    hints: Sequence[str] = (),
    error: Error | None = None,
    ok: bool | None = None,
) -> Report:
    return Report(
        command=command,
        kind=kind,
        ok=(exit_code is Exit.OK) if ok is None else ok,
        exit_code=int(exit_code),
        data=data or {},
        findings=tuple(findings),
        hints=tuple(hints),
        error=error,
    )


def _failed(command: str, kind: str, error: Error, exit_code: Exit) -> Output:
    return Output(_report(command, kind=kind, exit_code=exit_code, error=error, hints=(error.next_step or "",)),
                  table_text=f"エラー: {error.message}" + (f"\n  → {error.next_step}" if error.next_step else ""))


def _severity_exit(findings: Sequence[Finding], threshold: Severity) -> Exit:
    order = {Severity.INFO: 0, Severity.WARN: 1, Severity.ERROR: 2}
    hit = any(order[item.severity] >= order[threshold] for item in findings)
    return Exit.VALIDATION if hit else Exit.OK


def _severity_label(findings: Sequence[Finding]) -> str:
    counts = summarize(findings)
    return f"error {counts['error']} / warn {counts['warn']} / info {counts['info']}"


# --------------------------------------------------------------------------- path list


def cmd_path_list(args: argparse.Namespace) -> Output:
    match args.scope:
        case "all":
            scopes = (*ALL_SCOPES, Scope.EFFECTIVE)
        case "effective":
            scopes = (Scope.EFFECTIVE,)
        case other:
            scopes = (Scope(other),)

    data: dict[str, object] = {}
    rows: list[list[str]] = []
    blocks: list[str] = []
    for scope in scopes:
        entries = effective_entries() if scope is Scope.EFFECTIVE else stored_entries(scope)
        data[scope.value] = [entry_dict(entry) for entry in entries]
        rows += path_rows(entries)
        blocks.append(style(t"\n【{scope.value}】 {len(entries)} 件"))
        blocks.append(table(PATH_HEADERS, path_rows(entries)))
    report = _report("path.list", kind="paths", data=data)
    return Output(report, table_text="\n".join(blocks), tsv_text=to_tsv(rows), formats=("table", "json", "tsv"))


# -------------------------------------------------------------------------- path check


def cmd_path_check(args: argparse.Namespace) -> Output:
    findings = tuple(check_path())
    data: dict[str, object] = {
        "findings": len(findings),
        "severity": summarize(findings),
        "effective": effective_summary(),
    }
    exit_code = _severity_exit(findings, Severity.WARN)
    hints = ["pathctl path fix --scope user --apply で安全な範囲を直せます"] if exit_code is not Exit.OK else []
    report = _report("path.check", kind="findings", data=data, exit_code=exit_code, findings=findings, hints=hints)
    body = "\n".join([style(t"PATH の検査: {_severity_label(findings)}"), findings_block(findings)])
    return Output(report, table_text=body)


# ---------------------------------------------------------------------------- path fix


def cmd_path_fix(args: argparse.Namespace) -> Output:
    scopes = ALL_SCOPES if args.scope in {"all", "effective"} else (Scope(args.scope),)
    user_raw = [entry.raw for entry in stored_entries(Scope.USER)]
    plans = [
        plan(scope, user_entries=user_raw, move_user_entries=args.move_user_entries, prune_missing=args.prune_missing)
        for scope in scopes
    ]

    errors: list[Error] = []
    applied = False
    if args.apply:
        for item in plans:
            if not item.changed and not item.moved:
                continue
            try:
                apply(item, current_user=user_raw)
                applied = True
            except PermissionError as error:
                errors.append(
                    Error(
                        category="config",
                        message=str(error),
                        next_step=ADMIN_HINT,
                        required_args=("--apply",),
                    )
                )
                item.actions.append(f"適用できません: {error}")

    data: dict[str, object] = {
        "dry_run": not args.apply,
        "plans": {item.scope.value: item.as_dict() for item in plans},
        "applied": applied,
    }
    blocks: list[str] = []
    for item in plans:
        blocks.append(style(t"\n【{item.scope.value}】 {len(item.before)} -> {len(item.after)} 件"))
        blocks.append("\n".join(f"  - {action}" for action in item.actions) or "  変更なし")
    hints = (
        ("--apply を付けると書き換えます（今は下見のみ）",)
        if not args.apply
        else ("新しいシェルで反映を確認してください（既存のアプリは再起動が必要）",)
    )
    if errors:
        return Output(
            _report("path.fix", kind="fix", data=data, exit_code=Exit.CONFIG, error=errors[0], hints=hints),
            table_text="\n".join(blocks),
        )
    return Output(
        _report("path.fix", kind="fix", data=data, hints=hints),
        table_text="\n".join(blocks),
    )


# ----------------------------------------------------------------------- path add/remove


def cmd_path_add(args: argparse.Namespace) -> Output:
    directory = os.path.expandvars(args.directory)
    if not os.path.isdir(directory):
        return _failed(
            "path.add",
            "add",
            Error(
                category="not_found",
                message=f"ディレクトリが存在しません: {directory}",
                next_step="先にディレクトリを作るか、既存のパスを指定してください",
                required_args=("<dir>",),
            ),
            Exit.NOT_FOUND,
        )
    return _mutate(add_entry(Scope(args.scope), directory), args, command="path.add", kind="add")


def cmd_path_remove(args: argparse.Namespace) -> Output:
    directory = os.path.expandvars(args.directory)
    item = remove_entry(Scope(args.scope), directory)
    if not item.changed:
        # Removing something that is already absent is a success (idempotent), but say so explicitly.
        return Output(
            _report(
                "path.remove",
                kind="remove",
                data=item.as_dict() | {"changed": False},
                hints=("指定のディレクトリは元から入っていません（変更なし）",),
            ),
            table_text=f"  変更なし: {directory} は {item.scope.value} PATH にありません",
        )
    return _mutate(item, args, command="path.remove", kind="remove")


def _mutate(item, args: argparse.Namespace, *, command: str, kind: str) -> Output:
    errors: list[Error] = []
    if args.apply and (item.changed or item.moved):
        try:
            apply(item)
        except PermissionError as error:
            errors.append(
                Error(
                    category="config",
                    message=str(error),
                    next_step=ADMIN_HINT,
                    required_args=("--apply",),
                )
            )
    data = item.as_dict() | {"dry_run": not args.apply, "applied": bool(args.apply and not errors)}
    body = "\n".join(
        [
            style(t"{item.scope.value}: {len(item.before)} -> {len(item.after)} 件"),
            "\n".join(f"  - {action}" for action in item.actions) or "  変更なし",
        ]
    )
    if errors:
        return Output(_report(command, kind=kind, data=data, exit_code=Exit.CONFIG, error=errors[0]), table_text=body)
    hints = ("--apply を付けると書き換えます",) if not args.apply else ()
    return Output(_report(command, kind=kind, data=data, hints=hints), table_text=body)


# -------------------------------------------------------------------------------- tools


def cmd_tools(args: argparse.Namespace) -> Output:
    tools: list[Tool] = inventory()
    if args.name:
        tools = [item for item in tools if fnmatch.fnmatch(item.name.casefold(), args.name.casefold())]
    if args.via:
        wanted = {ToolProvenance(value) for value in args.via}
        tools = [item for item in tools if item.provenance in wanted]
    if args.without_mise:
        tools = [item for item in tools if item.without_mise]

    counts: dict[str, int] = {}
    for item in tools:
        counts[item.provenance.value] = counts.get(item.provenance.value, 0) + 1
    data: dict[str, object] = {
        "tools": [tool_dict(item) for item in tools],
        "provenance_counts": counts,
        "with_mise": sum(1 for item in tools if item.via_mise),
        "without_mise": sum(1 for item in tools if item.without_mise),
    }
    dirs = known_dirs()
    header = style(t"グローバルに使えるツール {len(tools)} 件（mise shims: {dirs.mise_shims or 'なし'}）")
    report = _report("tools", kind="tools", data=data)
    return Output(
        report,
        table_text="\n".join([header, tools_block(tools)]),
        tsv_text=to_tsv(tools_rows(tools)),
        formats=("table", "json", "tsv"),
    )


# ------------------------------------------------------------------------------- doctor


def cmd_doctor(args: argparse.Namespace) -> Output:
    path_findings = tuple(check_path())
    tools = inventory()
    tool_findings = tuple(check_tools(tools))
    findings = path_findings + tool_findings
    threshold = Severity.INFO if args.strict else Severity.ERROR
    exit_code = _severity_exit(findings, threshold)
    data: dict[str, object] = {
        "path": {"findings": len(path_findings), "severity": summarize(path_findings)},
        "tools": {
            "total": len(tools),
            "without_mise": sum(1 for item in tools if item.without_mise),
            "via_mise": sum(1 for item in tools if item.via_mise),
            "unavailable": sum(1 for item in tools if not item.available),
        },
        "effective": effective_summary(),
        "admin": is_admin(),
    }
    hints: list[str] = []
    if not is_admin():
        hints.append("機械 PATH の修正には管理者権限が必要です（今はユーザー PATH のみ変更できます）")
    if exit_code is not Exit.OK:
        hints.append("pathctl path fix --move-user-entries --format json で下見できます")
    report = _report("doctor", kind="doctor", data=data, exit_code=exit_code, findings=findings, hints=hints)
    body = "\n".join([style(t"doctor: {_severity_label(findings)}"), findings_block(findings)])
    return Output(report, table_text=body)


# -------------------------------------------------------------------------------- docs
# Bundled guides so an agent never needs a web fetch (see the agent-friendly CLI checklist).


def cmd_docs_list(args: argparse.Namespace) -> Output:
    items = docs.available()
    data: dict[str, object] = {"docs": [{"name": name, "summary": summary} for name, summary in items]}
    rows = [[name, summary] for name, summary in items]
    body = "\n".join(
        [
            style(t"同梱ガイド {len(items)} 件（本文: pathctl docs show <name>）"),
            table(["NAME", "内容"], rows),
        ]
    )
    return Output(_report("docs.list", kind="docs", data=data), table_text=body, tsv_text=to_tsv(rows),
                  formats=("table", "json", "tsv"))


def cmd_docs_show(args: argparse.Namespace) -> Output:
    try:
        text = docs.read(args.name)
    except docs.DocError:
        return _failed(
            "docs.show",
            "docs",
            Error(
                category="not_found",
                message=f"ガイドがありません: {args.name}",
                next_step="pathctl docs list で使える名前を確認してください",
                candidates=tuple(name for name, _summary in docs.available()),
            ),
            Exit.NOT_FOUND,
        )
    data: dict[str, object] = {"name": args.name, "text": text}
    return Output(_report("docs.show", kind="docs.doc", data=data), table_text=text)


# ------------------------------------------------------------------------------- audit


def cmd_audit(args: argparse.Namespace) -> Output:
    try:
        user_entries = stored_entries(Scope.USER)
    except RuntimeError:  # non-Windows: still able to audit mise / npm / uv
        user_entries = []
    strays = audit.collect(user_entries)
    found = tuple(audit.findings(strays))
    exit_code = _severity_exit(found, Severity.WARN)
    counts = {kind: sum(1 for item in strays if item.kind == kind) for kind in ("mise", "npm", "uv", "path")}
    data: dict[str, object] = {
        "strays": [
            {"kind": item.kind, "name": item.name, "location": item.location, "hint": item.hint} for item in strays
        ],
        "counts": counts,
        "mise_config": str(audit.mise_config()),
    }
    rows = [[item.kind, item.name, item.location] for item in strays]
    body = "\n".join(
        [
            style(t"野良グローバル: {len(strays)} 件（mise {counts['mise']} / npm {counts['npm']} / uv {counts['uv']} / PATH {counts['path']}）"),
            table(["KIND", "NAME", "LOCATION"], rows) if rows else "  宣言に無いグローバル導入はありません",
            findings_block(found),
        ]
    )
    hints = (
        "方針: グローバルは mise（~/.config/mise/config.toml）と winget（winget/host.dsc.yaml）に集約し、"
        "それ以外は SBX（Docker Sandboxes）で実行してください",
    )
    report = _report("audit", kind="audit", data=data, exit_code=exit_code, findings=found, hints=hints)
    return Output(report, table_text=body)


# ----------------------------------------------------------------------------- describe


def _subparsers(parser: argparse.ArgumentParser) -> dict[str, argparse.ArgumentParser]:
    found: dict[str, argparse.ArgumentParser] = {}
    for action in parser._actions:  # noqa: SLF001 - argparse exposes subcommands only here
        choices = getattr(action, "choices", None)
        if isinstance(choices, dict):
            for name, sub in choices.items():
                if isinstance(sub, argparse.ArgumentParser):
                    found[str(name)] = sub
    return found


def _plain(value: object) -> object:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def command_spec(name: str, parser: argparse.ArgumentParser) -> dict[str, object]:
    """One command as data: what it takes, what it prints, how to call it."""
    flags: list[dict[str, object]] = []
    positionals: list[dict[str, object]] = []
    for action in parser._actions:  # noqa: SLF001
        if isinstance(getattr(action, "choices", None), dict):
            continue
        if not action.option_strings:
            positionals.append(
                {
                    "name": action.dest,
                    "required": action.nargs in (None, "+", 1),
                    "description": action.help or "",
                }
            )
            continue
        if action.option_strings == ["-h", "--help"]:
            continue
        choices = action.choices
        flags.append(
            {
                "name": " / ".join(action.option_strings),
                "dest": action.dest,
                "type": "boolean" if action.nargs == 0 else "string",
                "choices": list(choices) if isinstance(choices, (list, tuple)) else None,
                "default": None if action.default is argparse.SUPPRESS else _plain(action.default),
                "description": action.help or "",
            }
        )
    formats = ["table", "json"]
    if name in {"path list", "tools"}:
        formats = ["table", "json", "tsv"]
    return {
        "name": name,
        "usage": parser.format_usage().strip().removeprefix("usage:").strip(),
        "positionals": positionals,
        "flags": flags,
        "output_formats": formats,
        "examples": EXAMPLES.get(name, []),
        "notes": NOTES.get(name, []),
    }


def collect_commands() -> dict[str, dict[str, object]]:
    specs: dict[str, dict[str, object]] = {}
    root = build_parser()

    def visit(parser: argparse.ArgumentParser, prefix: str) -> None:
        for name, sub in _subparsers(parser).items():
            full = f"{prefix} {name}".strip()
            specs[full] = command_spec(full, sub)
            visit(sub, full)

    visit(root, "")
    return specs


def _spec_table(spec: dict[str, object]) -> str:
    flags = spec.get("flags")
    rows: list[list[str]] = []
    if isinstance(flags, list):
        for flag in flags:
            if isinstance(flag, dict):
                rows.append(
                    [
                        str(flag.get("name", "")),
                        str(flag.get("type", "")),
                        str(flag.get("default", "") or ""),
                        str(flag.get("description", "")),
                    ]
                )
    lines = [str(spec.get("usage", "")), table(["フラグ", "型", "既定", "説明"], rows)]
    examples = spec.get("examples")
    if isinstance(examples, list):
        for example in examples:
            lines.append(f"  例: {example}")
    return "\n".join(lines)


def cmd_describe(args: argparse.Namespace) -> Output:
    specs = collect_commands()
    if args.command:
        name = " ".join(args.command)
        spec = specs.get(name)
        if spec is None:
            return _failed(
                "describe",
                "describe",
                Error(
                    category="not_found",
                    message=f"未知のコマンドです: {name}",
                    next_step="pathctl describe --format json でコマンド一覧を確認してください",
                    candidates=tuple(sorted(specs)),
                ),
                Exit.NOT_FOUND,
            )
        return Output(_report("describe", kind="describe.command", data=spec), table_text=_spec_table(spec))
    data = describe_cli() | {"command_specs": specs}
    body = "\n".join(
        [
            style(t"pathctl {__version__} / schema {data['schema']}"),
            "コマンド: " + ", ".join(specs),
            "契約の詳細は --format json（エージェント向け）で出力してください",
        ]
    )
    return Output(_report("describe", kind="describe.cli", data=data), table_text=body)


# ---------------------------------------------------------------------------------- main


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--format", choices=FORMATS, default=None, help="出力形式（table / json / tsv）")
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS, help="--format json の別名")
    common.add_argument("--no-color", action="store_true", default=argparse.SUPPRESS, help="色を使わない")

    parser = argparse.ArgumentParser(
        prog="pathctl",
        description="Windows のグローバル PATH を点検・修復し、mise / winget / npm / 直置きのどれで使えるツールかを一覧します",
        epilog=(
            "例: pathctl doctor --format json / pathctl tools --without-mise / pathctl describe\n"
            f"{AGENT_HINT}"
        ),
    )
    parser.add_argument("--version", action="version", version=f"pathctl {__version__}")
    parser.add_argument("--format", choices=FORMATS, default="table", help="出力形式（table / json / tsv）")
    parser.add_argument("--json", action="store_true", help="--format json の別名")
    parser.add_argument("--no-color", action="store_true", help="色を使わない")

    subparsers = parser.add_subparsers(dest="group", required=True)

    path = subparsers.add_parser("path", help="PATH の点検・修復", parents=[common])
    path_sub = path.add_subparsers(dest="action", required=True)

    list_parser = path_sub.add_parser("list", help="PATH の内容を一覧", parents=[common])
    _scope_argument(list_parser, default="all")

    check_parser = path_sub.add_parser("check", help="PATH の問題点を検出", parents=[common])
    check_parser.set_defaults(scope="all")

    fix_parser = path_sub.add_parser("fix", help="重複除去・個人パスの移動・存在しないパス除去", parents=[common])
    _scope_argument(fix_parser, default="all")
    _write_flags(fix_parser)
    fix_parser.add_argument("--move-user-entries", action="store_true", help="機械 PATH の個人パスをユーザー PATH へ移す")
    fix_parser.add_argument("--prune-missing", action="store_true", help="存在しないディレクトリのエントリを削除")

    add_parser = path_sub.add_parser("add", help="PATH にディレクトリを追加", parents=[common])
    add_parser.add_argument("directory", help="追加するディレクトリ（%%USERPROFILE%% などの変数可）")
    _scope_argument(add_parser, default="user", choices=("user", "machine"))
    _write_flags(add_parser)

    remove_parser = path_sub.add_parser("remove", help="PATH からディレクトリを削除", parents=[common])
    remove_parser.add_argument("directory", help="削除するディレクトリ（%%USERPROFILE%% などの変数可）")
    _scope_argument(remove_parser, default="user", choices=("user", "machine"))
    _write_flags(remove_parser)

    tools_parser = subparsers.add_parser(
        "tools", help="グローバルに使えるツールと入手元の一覧", parents=[common], aliases=["list-tools"]
    )
    tools_parser.add_argument("--without-mise", action="store_true", help="mise が無くても使えるものだけ表示")
    tools_parser.add_argument("--via", nargs="*", choices=[item.value for item in ToolProvenance], help="入手元で絞る")
    tools_parser.add_argument("--name", help="コマンド名のパターン（例: 'py*'）")

    doctor_parser = subparsers.add_parser("doctor", help="PATH とツールをまとめて点検", parents=[common])
    doctor_parser.add_argument("--strict", action="store_true", help="info/warn でも終了コード 5 にする")

    audit_parser = subparsers.add_parser(
        "audit", help="宣言に無いグローバル導入（野良グローバル）を一覧", parents=[common]
    )
    audit_parser.add_argument(
        "--strict", action="store_true", help="info だけでも終了コード 5 にする"
    )

    docs_parser = subparsers.add_parser("docs", help="同梱ガイド（Web Fetch 不要）", parents=[common])
    docs_sub = docs_parser.add_subparsers(dest="action", required=True)
    docs_sub.add_parser("list", help="ガイドの一覧", parents=[common])
    docs_show = docs_sub.add_parser("show", help="ガイドの本文を表示", parents=[common])
    docs_show.add_argument("name", help="ガイド名（pathctl docs list で確認）")

    describe_parser = subparsers.add_parser(
        "describe", help="エージェント向けの入出力契約（コマンドごとのフラグ一覧）", parents=[common], aliases=["schema"]
    )
    describe_parser.add_argument(
        "command", nargs="*", help="調べるコマンド（例: 'path fix'）。省略すると全体を返す"
    )
    return parser


def _write_flags(parser: argparse.ArgumentParser) -> None:
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true", help="実際に書き換える")
    group.add_argument("--dry-run", action="store_true", help="書き換えずに結果だけ表示（既定と同じ）")


def _scope_argument(
    parser: argparse.ArgumentParser,
    *,
    default: str,
    choices: tuple[str, ...] = SCOPE_CHOICES,
) -> None:
    parser.add_argument("--scope", choices=choices, default=default, help="対象スコープ（machine / user / effective / all）")


def _resolve_format(args: argparse.Namespace) -> str:
    if getattr(args, "json", False):
        return "json"
    return getattr(args, "format", None) or "table"


def main(argv: Sequence[str] | None = None) -> int:
    configure_output()
    parser = build_parser()
    args = parser.parse_args(argv)
    format_ = _resolve_format(args)
    if getattr(args, "no_color", False):
        os.environ["NO_COLOR"] = "1"
    if not hasattr(args, "action"):
        args.action = None

    output: Output
    try:
        match (args.group, args.action):
            case ("path", "list"):
                output = cmd_path_list(args)
            case ("path", "check"):
                output = cmd_path_check(args)
            case ("path", "fix"):
                output = cmd_path_fix(args)
            case ("path", "add"):
                output = cmd_path_add(args)
            case ("path", "remove"):
                output = cmd_path_remove(args)
            case ("tools" | "list-tools", _):
                output = cmd_tools(args)
            case ("doctor", _):
                output = cmd_doctor(args)
            case ("audit", _):
                output = cmd_audit(args)
            case ("docs", "list"):
                output = cmd_docs_list(args)
            case ("docs", "show"):
                output = cmd_docs_show(args)
            case ("describe" | "schema", _):
                output = cmd_describe(args)
            case _:
                parser.error(f"unknown command: {args.group} {args.action}")
    except RuntimeError as error:
        # e.g. the Windows registry is unavailable (pathctl is a Windows tool)
        config_error = Error(
            category="config",
            message=str(error),
            next_step="Windows 上で実行してください（pathctl schema はどの OS でも動きます）",
        )
        output = _failed(args.group, args.group, config_error, Exit.CONFIG)

    report = output.report
    if format_ == "json":
        print(to_json(report))
    elif format_ == "tsv":
        if not output.tsv_text:
            print(
                f"エラー: {report.command} は --format tsv に対応していません"
                f"（対応: {' / '.join(output.formats)}）",
                file=sys.stderr,
            )
            return int(Exit.USAGE)
        print(output.tsv_text)
    else:
        if output.table_text:
            print(output.table_text)
        for hint in report.hints:
            if hint:
                print(f"  hint: {hint}", file=sys.stderr)
    return int(report.exit_code)


if __name__ == "__main__":
    sys.exit(main())
