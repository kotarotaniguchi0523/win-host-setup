"""Machine readable description of the CLI contract.

Agents should read this first (``pathctl schema``) instead of scraping the human output:
it lists the commands, the JSON envelope, the finding codes and the exit codes.
"""

from .model import FindingCode, Severity, ToolProvenance

SCHEMA_ID = "pathctl/1"


def describe() -> dict[str, object]:
    return {
        "schema": SCHEMA_ID,
        "about": "Inspect and repair the Windows global PATH, and list globally usable tools",
        "exit_codes": {
            "0": "成功（findings なし、または doctor が許容範囲）",
            "1": "findings あり / 適用に失敗（例: 管理者権限が無い）",
            "2": "引数の誤り",
        },
        "global_flags": {
            "--json": "結果を JSON で出力する（エージェント向け。これが既定の推奨）",
            "--no-color": "色を無効化（TTY 以外では自動で無効）",
            "--version": "バージョンを表示して終了",
        },
        "json_envelope": {
            "schema": f"{SCHEMA_ID} 固定",
            "command": "実行したコマンド（例: path.check）",
            "ok": "成功したか",
            "data": "コマンド固有のデータ",
            "findings": "検出項目の配列（code / severity / scope / detail / entries / hint）",
            "hints": "次に実行するとよいコマンドなどの補足",
        },
        "commands": {
            "path.list": {
                "usage": "pathctl path list [--scope machine|user|effective|all] [--json]",
                "data": "scope ごとの entries（raw / expanded / exists / user_specific）",
            },
            "path.check": {
                "usage": "pathctl path check [--json]",
                "data": "findings の件数と severity の内訳",
            },
            "path.fix": {
                "usage": (
                    "pathctl path fix [--scope machine|user|all] [--apply] "
                    "[--move-user-entries] [--prune-missing] [--json]"
                ),
                "data": "scope ごとの before_count / after_count / actions / moved_to_user",
                "note": "--apply を付けない限り何も書き換えない。機械 PATH の書き換えには管理者権限が必要",
            },
            "path.add": {
                "usage": "pathctl path add <dir> [--scope user|machine] [--apply] [--json]",
                "data": "追加後の entry 数",
            },
            "path.remove": {
                "usage": "pathctl path remove <dir> [--scope user|machine] [--apply] [--json]",
                "data": "削除後の entry 数",
            },
            "tools": {
                "usage": "pathctl tools [--json] [--without-mise] [--via <provenance>] [--name <glob>]",
                "data": "tools（name / provenance / path / via_mise / without_mise / shadowed_by）と provenance の内訳",
                "note": "without_mise=true は「mise が無くても PATH から起動できる」コマンド",
            },
            "doctor": {
                "usage": "pathctl doctor [--json] [--strict]",
                "data": "path の findings と tools の要約",
                "note": "--strict を付けると info/warn でも終了コード 1",
            },
            "schema": {"usage": "pathctl schema [--json]", "data": "この説明そのもの"},
        },
        "provenance": [item.value for item in ToolProvenance],
        "finding_codes": [item.value for item in FindingCode],
        "severity": [item.value for item in Severity],
        "examples": [
            {"why": "壊れていないかをまとめて確認する", "run": "pathctl doctor --json"},
            {"why": "mise が無くても使えるコマンドだけを見る", "run": "pathctl tools --without-mise --json"},
            {"why": "マシン PATH の個人パスを下見する（書き換えない）", "run": "pathctl path fix --scope machine --move-user-entries --json"},
            {"why": "uv tool の bin（~/.local/bin）をユーザー PATH に足す", "run": "pathctl path add %USERPROFILE%\\.local\\bin --scope user --apply --json"},
        ],
    }
