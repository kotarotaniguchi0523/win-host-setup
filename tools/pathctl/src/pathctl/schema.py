"""Machine readable description of the CLI contract.

Agents should read this first (``pathctl describe --format json``) instead of scraping the
human output: it lists the commands, the JSON envelope, the exit codes and the finding codes.
"""

from .model import Exit, FindingCode, Severity, ToolProvenance

SCHEMA_ID = "pathctl/1"


def describe_cli() -> dict[str, object]:
    return {
        "schema": SCHEMA_ID,
        "about": "Windows のグローバル PATH を点検・修復し、グローバルに使えるツールと入手元を一覧する",
        "discovery": [
            "1. pathctl describe --format json         # コマンドとフラグの一覧",
            "2. pathctl doctor --format json           # 現状の点検（findings を読む）",
            "3. pathctl path fix --move-user-entries --format json   # 直す内容の下見",
            "4. pathctl path fix --move-user-entries --apply        # 適用（機械 PATH は管理者権限）",
            "5. pathctl tools --format json            # どのツールが mise 無しでも使えるか",
        ],
        "principles": {
            "structured_output": "--format table|json|tsv。stdout はデータのみ、メッセージは stderr",
            "semantic_exit_codes": "0 成功 / 1 予期しない失敗 / 2 引数の誤り / 3 対象なし / 4 設定・権限 / 5 検証（findings）",
            "non_interactive": "プロンプトを出さず、ネットワークも使わない",
            "noun_verb": "path <verb> / tools / doctor / describe（tools の別名は list-tools）",
            "self_describing": "describe [<command>] がコマンドごとのフラグ一覧を JSON で返す",
            "actionable_errors": "error.category / message / next_step / candidates / required_args",
            "idempotent": "書き込みは --apply のときだけ（既定は下見）。--dry-run は明示的な別名",
            "composable": "JSON は jq、TSV は awk / cut にそのまま渡せる",
        },
        "exit_codes": {str(item.value): f"{item.category}: {_MEANING[item]}" for item in Exit},
        "formats": ["table", "json", "tsv"],
        "json_envelope": {
            "schema": f"{SCHEMA_ID} 固定",
            "kind": "データ種別（paths / findings / fix / tools / doctor / describe.*）",
            "command": "実行したコマンド（例: path.check）",
            "ok": "成功したか",
            "exit_code": "このプロセスの終了コードと同じ値",
            "category": "exit_code の分類名（ok / general / usage / not_found / config / validation）",
            "data": "コマンド固有のデータ",
            "findings": "検出項目（code / severity / scope / detail / entries / hint）",
            "hints": "次に実行するとよいコマンド",
            "error": "失敗時のみ。category / message / next_step / candidates / required_args",
        },
        "provenance": [item.value for item in ToolProvenance],
        "finding_codes": [item.value for item in FindingCode],
        "severity": [item.value for item in Severity],
        "examples": [
            {"why": "壊れていないかをまとめて確認する", "run": "pathctl doctor --format json"},
            {"why": "mise が無くても使えるコマンドだけを見る", "run": "pathctl tools --without-mise --format json"},
            {"why": "ツール名と入手元だけを抜く", "run": "pathctl tools --format tsv | awk -F'\\t' '{print $1, $2}'"},
            {
                "why": "マシン PATH の個人パスを下見する（書き換えない）",
                "run": "pathctl path fix --scope machine --move-user-entries --format json",
            },
            {
                "why": "uv tool の bin（%USERPROFILE%\\.local\\bin）をユーザー PATH に足す",
                "run": "pathctl path add '%USERPROFILE%\\.local\\bin' --scope user --apply --format json",
            },
        ],
    }


_MEANING: dict[Exit, str] = {
    Exit.OK: "成功（findings なし、または許容範囲）",
    Exit.FAILURE: "予期しない失敗",
    Exit.USAGE: "引数の誤り",
    Exit.NOT_FOUND: "対象が存在しない",
    Exit.CONFIG: "設定・権限の問題（管理者権限が必要など）",
    Exit.VALIDATION: "検証エラー（findings への対応が必要）",
}
