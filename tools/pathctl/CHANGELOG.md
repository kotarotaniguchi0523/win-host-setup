# Changelog

pathctl の変更点。形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠。

## [0.1.1] - 2026-10-16

### Changed

- 効率性の見直し（Effective Python 第2版を踏襲）
  - `FixPlan.as_dict()` は key 集合を先に作る（内包表記の中での再構築をやめて O(n²) を回避）
  - `render.display_width()` を `functools.cache` でメモ化、`findings_block()` は色判定を 1 回だけ
  - `inventory()` は shims パスをループ外で正規化
- 不変性（freeze）の方針を明確化
  - 値オブジェクトは `frozen=True`（`PathEntry` / `Finding` / `Tool` / `Report`）、構築中の `FixPlan` は可変
  - `docs.Guide` は `NamedTuple`、`model.MISE_PROVENANCES` は `frozenset`（プロパティ内の set リテラルをやめた）
- 未使用コードを削除（`checks.SCOPES` / `checks.worst_severity` / 未使用の型エイリアス）

### Added

- `tests/test_agent_contract.py`: エージェント向け 8 原則を機械的に検証（構造化出力 / 終了コード /
  非対話・ネットワーク無し / noun-verb / `describe` / アクション可能なエラー / 冪等・下見 / TSV）
- テストは合計 44 件（追加依存なし）

## [0.1.0] - 2026-10-16

### Added

- `path list` / `path check` / `path fix` / `path add` / `path remove` — グローバル PATH の一覧・検査・修復
- `tools` — グローバルに使えるコマンドと入手元（`mise-shim` / `mise-install` / `winget` / `npm-global` / `direct`）の一覧。
  `without_mise` で「mise が無くても起動できる」ものを判別
- `doctor` — PATH の findings とツールの要約をまとめて点検
- `describe` — コマンドごとのフラグ一覧を JSON で返す自己記述（別名 `schema`）
- `docs list` / `docs show <name>` — 同梱ガイドを Web Fetch 無しで読む
- `--format table|json|tsv`（`--json` は別名）。stdout はデータのみ、パイプ時は UTF-8
- セマンティック終了コード（0 成功 / 1 一般 / 2 引数 / 3 対象なし / 4 設定・権限 / 5 検証）
- アクション可能なエラー（`error.category` / `message` / `next_step` / `candidates` / `required_args`）
- `--dry-run`（既定）と `--apply`、`--move-user-entries`、`--prune-missing`
- `unittest` によるテスト 27 件（追加依存なし）と ty による型チェック

### Notes

- Python 3.15 の `lazy import`（PEP 810）を使うため `requires-python = ">=3.15"`
  （`ctypes` / `winreg` / `json` / `unicodedata` は使うときだけ解決する）
- レジストリの値の型（`REG_SZ` / `REG_EXPAND_SZ`）と `%VAR%` 表記を保持したまま書き戻す
- マシン PATH の書き換えは管理者権限が必要（無い場合は exit 4 と、次の一手を返す）
