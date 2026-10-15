"""pathctl - inspect and repair the Windows global PATH (stdlib only).

Every subcommand returns a Report, which the renderer prints either as JSON (for agents) or
as a small table (for humans). No network access, no third-party packages, no prompts.
"""

import argparse
import fnmatch
import os
import sys
from collections.abc import Sequence

from . import __version__
from .checks import check_path, check_tools, effective_summary, summarize
from .fix import add_entry, apply, plan, remove_entry
from .model import Finding, Report, Scope, Severity, Tool, ToolProvenance
from .render import (
    configure_output,
    entry_dict,
    findings_block,
    render,
    style,
    table,
    tool_dict,
    tools_block,
)
from .schema import describe
from .tools import inventory, known_dirs
from .winenv import effective_entries, is_admin, stored_entries

ALL_SCOPES: tuple[Scope, ...] = (Scope.MACHINE, Scope.USER)
SCOPE_CHOICES: tuple[str, ...] = ("machine", "user", "effective", "all")
_WARN_ORDER: dict[Severity, int] = {Severity.INFO: 0, Severity.WARN: 1, Severity.ERROR: 2}


def parse_scope(text: str) -> str:
    """CLI scope value: machine / user / effective / all (validated by argparse choices)."""
    if text not in SCOPE_CHOICES:
        raise argparse.ArgumentTypeError(f"unknown scope: {text!r} (machine / user / effective / all)")
    return text


def _exceeds(findings: Sequence[Finding], threshold: Severity) -> bool:
    return any(_WARN_ORDER[item.severity] >= _WARN_ORDER[threshold] for item in findings)


def _scope_argument(
    parser: argparse.ArgumentParser,
    *,
    default: str,
    choices: tuple[str, ...] = SCOPE_CHOICES,
) -> None:
    parser.add_argument("--scope", choices=choices, default=default, help="対象スコープ（machine / user / effective / all）")


# --------------------------------------------------------------------------- path list


def cmd_path_list(args: argparse.Namespace) -> tuple[Report, str, int]:
    scopes: tuple[Scope, ...]
    match args.scope:
        case "all":
            scopes = (*ALL_SCOPES, Scope.EFFECTIVE)
        case "effective":
            scopes = (Scope.EFFECTIVE,)
        case other:
            scopes = (Scope(other),)

    data: dict[str, object] = {}
    blocks: list[str] = []
    for scope in scopes:
        entries = effective_entries() if scope is Scope.EFFECTIVE else stored_entries(scope)
        data[scope.value] = [entry_dict(entry) for entry in entries]
        rows = [
            [
                str(entry.index + 1),
                entry.raw if not entry.empty else "(空)",
                "yes" if entry.exists else "no",
                "user" if entry.user_specific else "",
            ]
            for entry in entries
        ]
        blocks.append(style(t"\n【{scope.value}】 {len(entries)} 件"))
        blocks.append(table(["#", "PATH エントリ", "exists", "固有"], rows))
    return Report(command="path.list", ok=True, data=data), "\n".join(blocks), 0


# -------------------------------------------------------------------------- path check


def cmd_path_check(args: argparse.Namespace) -> tuple[Report, str, int]:
    findings = tuple(check_path())
    data: dict[str, object] = {"findings": len(findings), "severity": summarize(findings), "effective": effective_summary()}
    body = "\n".join(
        [
            style(t"PATH の検査: {args_label(findings)}"),
            findings_block(findings),
        ]
    )
    report = Report(command="path.check", ok=not _exceeds(findings, Severity.WARN), data=data, findings=findings)
    return report, body, 1 if not report.ok else 0


def args_label(findings: Sequence[Finding]) -> str:
    counts = summarize(findings)
    return f"error {counts['error']} / warn {counts['warn']} / info {counts['info']}"


# ---------------------------------------------------------------------------- path fix


def cmd_path_fix(args: argparse.Namespace) -> tuple[Report, str, int]:
    scopes = ALL_SCOPES if args.scope in {"all", "effective"} else (Scope(args.scope),)
    user_raw = [entry.raw for entry in stored_entries(Scope.USER)]
    plans = [
        plan(scope, user_entries=user_raw, move_user_entries=args.move_user_entries, prune_missing=args.prune_missing)
        for scope in scopes
    ]

    applied = False
    problems: list[str] = []
    if args.apply:
        for item in plans:
            if not item.changed and not item.moved:
                continue
            try:
                apply(item, current_user=user_raw)
                applied = True
            except PermissionError as error:
                problems.append(str(error))
                item.actions.append(f"適用できません: {error}")

    data: dict[str, object] = {"plans": {item.scope.value: item.as_dict() for item in plans}, "applied": applied}
    blocks: list[str] = []
    for item in plans:
        blocks.append(style(t"\n【{item.scope.value}】 {len(item.before)} -> {len(item.after)} 件"))
        blocks.append("\n".join(f"  - {action}" for action in item.actions) or "  変更なし")
    hints = (
        ("--apply を付けると書き換えます（今は下見のみ）",)
        if not args.apply
        else ("新しいシェルで反映を確認してください（既存のアプリは再起動が必要）",)
    )
    report = Report(
        command="path.fix",
        ok=not problems,
        data=data,
        hints=tuple(problems) + hints,
    )
    return report, "\n".join(blocks), 0 if not problems else 1


# ----------------------------------------------------------------------- path add/remove


def cmd_path_add(args: argparse.Namespace) -> tuple[Report, str, int]:
    directory = os.path.expandvars(args.directory)
    item = add_entry(Scope(args.scope), directory)
    return _mutate(item, args, command="path.add")


def cmd_path_remove(args: argparse.Namespace) -> tuple[Report, str, int]:
    directory = os.path.expandvars(args.directory)
    item = remove_entry(Scope(args.scope), directory)
    return _mutate(item, args, command="path.remove")


def _mutate(item, args: argparse.Namespace, *, command: str) -> tuple[Report, str, int]:
    problems: list[str] = []
    if args.apply and (item.changed or item.moved):
        try:
            apply(item)
        except PermissionError as error:
            problems.append(str(error))
    body = "\n".join(
        [
            style(t"{item.scope.value}: {len(item.before)} -> {len(item.after)} 件"),
            "\n".join(f"  - {action}" for action in item.actions) or "  変更なし",
        ]
    )
    data = item.as_dict() | {"applied": bool(args.apply and not problems)}
    report = Report(command=command, ok=not problems, data=data, hints=tuple(problems))
    return report, body, 0 if not problems else 1


# -------------------------------------------------------------------------------- tools


def cmd_tools(args: argparse.Namespace) -> tuple[Report, str, int]:
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
    header = style(
        t"グローバルに使えるツール {len(tools)} 件（mise shims: {dirs.mise_shims or 'なし'}）"
    )
    body = "\n".join([header, tools_block(tools)])
    return Report(command="tools", ok=True, data=data), body, 0


# ------------------------------------------------------------------------------- doctor


def cmd_doctor(args: argparse.Namespace) -> tuple[Report, str, int]:
    path_findings = tuple(check_path())
    tools = inventory()
    tool_findings = tuple(check_tools(tools))
    findings = path_findings + tool_findings
    threshold = Severity.INFO if args.strict else Severity.ERROR
    ok = not _exceeds(findings, threshold)
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
    body = "\n".join([style(t"doctor: {args_label(findings)}"), findings_block(findings)])
    hints: list[str] = []
    if not is_admin():
        hints.append("機械 PATH の修正には管理者権限が必要です（今はユーザー PATH のみ変更できます）")
    return Report(command="doctor", ok=ok, data=data, findings=findings, hints=tuple(hints)), body, 0 if ok else 1


# ------------------------------------------------------------------------------- schema


def cmd_schema(args: argparse.Namespace) -> tuple[Report, str, int]:
    data = describe()
    commands = data["commands"]
    names = ", ".join(commands) if isinstance(commands, dict) else ""
    body = "\n".join(
        [
            style(t"pathctl {__version__} / schema {data['schema']}"),
            f"コマンド: {names}",
            "詳細は --json で出力してください（エージェント向けの契約）",
        ]
    )
    return Report(command="schema", ok=True, data=data), body, 0


# ---------------------------------------------------------------------------------- main


def build_parser() -> argparse.ArgumentParser:
    # `--json` / `--no-color` are accepted both before and after the subcommand
    # (default=SUPPRESS keeps an earlier --json from being reset by the subparser default).
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS, help="JSON で出力（エージェント向け）")
    common.add_argument("--no-color", action="store_true", default=argparse.SUPPRESS, help="色を使わない")

    parser = argparse.ArgumentParser(
        prog="pathctl",
        description="Windows のグローバル PATH を点検・修復し、mise / winget / npm / 直置きのどれで使えるツールかを一覧します",
        epilog="例: pathctl doctor --json / pathctl tools --without-mise / pathctl schema --json",
    )
    parser.add_argument("--version", action="version", version=f"pathctl {__version__}")
    parser.add_argument("--json", action="store_true", help="JSON で出力（エージェント向け）")
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
    fix_parser.add_argument("--apply", action="store_true", help="実際に書き換える（既定は下見のみ）")
    fix_parser.add_argument("--move-user-entries", action="store_true", help="機械 PATH の個人パスをユーザー PATH へ移す")
    fix_parser.add_argument("--prune-missing", action="store_true", help="存在しないディレクトリのエントリを削除")

    add_parser = path_sub.add_parser("add", help="PATH にディレクトリを追加", parents=[common])
    add_parser.add_argument("directory", help="追加するディレクトリ（%%USERPROFILE%% などの変数可）")
    _scope_argument(add_parser, default="user", choices=("user", "machine"))
    add_parser.add_argument("--apply", action="store_true", help="実際に書き換える")

    remove_parser = path_sub.add_parser("remove", help="PATH からディレクトリを削除", parents=[common])
    remove_parser.add_argument("directory", help="削除するディレクトリ（%%USERPROFILE%% などの変数可）")
    _scope_argument(remove_parser, default="user", choices=("user", "machine"))
    remove_parser.add_argument("--apply", action="store_true", help="実際に書き換える")

    tools_parser = subparsers.add_parser("tools", help="グローバルに使えるツールと入手元の一覧", parents=[common])
    tools_parser.add_argument("--without-mise", action="store_true", help="mise が無くても使えるものだけ表示")
    tools_parser.add_argument("--via", nargs="*", choices=[item.value for item in ToolProvenance], help="入手元で絞る")
    tools_parser.add_argument("--name", help="コマンド名のパターン（例: 'py*'）")

    doctor_parser = subparsers.add_parser("doctor", help="PATH とツールをまとめて点検", parents=[common])
    doctor_parser.add_argument("--strict", action="store_true", help="info/warn でも終了コード 1 にする")

    subparsers.add_parser("schema", help="エージェント向けの入出力契約を表示", parents=[common])
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    configure_output()
    parser = build_parser()
    args = parser.parse_args(argv)
    json_mode = bool(getattr(args, "json", False))
    if getattr(args, "no_color", False):
        os.environ["NO_COLOR"] = "1"
    if not hasattr(args, "action"):
        args.action = None

    try:
        match (args.group, args.action):
            case ("path", "list"):
                report, body, code = cmd_path_list(args)
            case ("path", "check"):
                report, body, code = cmd_path_check(args)
            case ("path", "fix"):
                report, body, code = cmd_path_fix(args)
            case ("path", "add"):
                report, body, code = cmd_path_add(args)
            case ("path", "remove"):
                report, body, code = cmd_path_remove(args)
            case ("tools", _):
                report, body, code = cmd_tools(args)
            case ("doctor", _):
                report, body, code = cmd_doctor(args)
            case ("schema", _):
                report, body, code = cmd_schema(args)
            case _:
                parser.error(f"unknown command: {args.group} {args.action}")
    except RuntimeError as error:
        # e.g. the Windows registry is unavailable (pathctl is a Windows tool)
        report = Report(command=args.group, ok=False, hints=(str(error),))
        render(report, json_mode=json_mode, body=f"エラー: {error}")
        return 1

    if report.hints and not json_mode:
        body += "\n" + "\n".join(f"  hint: {hint}" for hint in report.hints)
    render(report, json_mode=json_mode, body=body)
    return code


if __name__ == "__main__":
    sys.exit(main())
