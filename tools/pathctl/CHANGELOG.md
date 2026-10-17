# Changelog

pathctl の変更点。形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠。

## [0.2.4] - 2026-10-17

### Fixed

- PyPI に **PEP 740 の publish attestation が添付されていなかった**問題を修正。公開を
  **`pypa/gh-action-pypi-publish`**（公式アクション）に切り替え、attestation をそのコンテナ内で
  生成・添付させる。0.2.2 までは wheel / sdist だけが公開され、`.../provenance` は 404 だった。
  ランナー側に Python の依存ツリー（twine → sigstore → pydantic など）を持ち込まない。
- ダイジェストファイル（`SHA256SUMS`）を `dist/` の外へ移動。公開アクションは `dist/*` を
  `twine check` するため、配布物以外のファイルが混ざっていると失敗する。
- `pypi` ジョブから checkout と mise-action を削除（公開はアクションのコンテナ内で完結する）。

### Note

- 0.2.3 は GitHub Release を作成したあとにタグを作り直せなくなり（`protect release tags`
  ルールセットによるタグ名の再利用不可）、**PyPI へは未公開**。同じ内容を 0.2.4 として公開した。

## [0.2.2] - 2026-10-17

### Added

- `path add --prepend`: PATH の**末尾ではなく先頭**に追加する。Windows 同梱の `curl.exe`
  （`C:\Windows\System32`）より新しい版を優先させたいときなど、システム側のコマンドを
  上書きする用途。マシン PATH への書き込みは管理者権限が要る。

## [0.2.1] - 2026-10-17

### Added

- `audit` の対象を拡張: **pipx** / **pip --user** / **cargo install** / **go install** /
  **バージョン付きの手動配置**（`curl-8.7.1_7-win64-mingw` のような展開済みアーカイブ）。機械 PATH も見る。
- winget の突き合わせは誤検知が多い（バージョン文字列・Windows 標準アプリ）ため audit から外した。
  winget のピン管理は `tools/update-winget-dsc.ps1` が担当する。

## [0.2.0] - 2026-10-17

### Added

- **`pathctl audit`**: 宣言（mise のグローバル設定 / winget の DSC）に無いグローバル導入＝
  **野良グローバル**を一覧する。mise の `source.path`、npm の `node_modules`、uv tool、
  ユーザー PATH の項目を突き合わせ、パッケージマネージャ由来は WARN、PATH は INFO で返す。
  `--format json` でそのまま記録・自動化できる。

## [0.1.4] - 2026-10-16

### Fixed

- リリースの PyPI 公開ジョブが `uv: command not found` で失敗していた
  （`actions/checkout` が無く `mise.toml` を読めなかったため。checkout を追加）

### Added

- 公開前に**ビルドした wheel を実際に動かす**検証（`uvx --from dist/*.whl pathctl --version` /
  `docs show` / `describe`）をリリースに追加（パッケージング回帰の検出）

## [0.1.3] - 2026-10-16

### Changed

- **PyPI への公開を有効化**（Trusted Publishing / PEP 740）。`uvx pathctl` が最短形で使えます。
  コードの変更はありません（リリース運用の切り替えのみ）。

## [0.1.2] - 2026-10-16

### Added

- **SLSA Build Level 3 相当のリリース**: GitHub ホストの使い捨てランナーで 1 回だけビルドし、
  `actions/attest-build-provenance` で GitHub 自身が署名する provenance を発行
  （`gh attestation verify` で検証可能）
- `SHA256SUMS` を成果物に添付し、公開前に再検証（`sha256sum -c`）
- **PyPI の Trusted Publishing（OIDC）** で公開（トークン不要）。`uv publish` が PEP 740 の
  publish attestation も既定で添付する
- リリースタグの保護（ruleset）と immutable releases を有効化

### Changed

- リリースは「ビルド → アップロード → Release / PyPI」の 3 ジョブに分離し、**公開するのは
  ビルドした同一ファイル**（再ビルドしない）
- リリース時の `mise-action` は `cache: false`（キャッシュ経由のビルド汚染を避ける）

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
