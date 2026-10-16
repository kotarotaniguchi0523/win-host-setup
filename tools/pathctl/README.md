# pathctl — グローバル PATH の点検・修復とツールの入手元一覧

Windows のグローバル PATH（マシン / ユーザー）を**点検・修復**し、**どのツールがどの入手元でグローバルに使えるか**（mise / winget / npm / 直置き）を一覧する CLI です。

- **実行時の依存なし**（Python 3.15 の標準ライブラリのみ）
- ネットワークを使わない。プロンプトを出さない。`--json` で機械可読
- 書き換えは `--apply` を付けたときだけ。マシン PATH の書き換えは管理者権限が必要

## 使い方

```powershell
# リポジトリ内から（uv が .venv を作ります）
uv run --project tools/pathctl pathctl doctor --json

# どのツールが mise 無しでも使えるか
uv run --project tools/pathctl pathctl tools --without-mise

# グローバルにコマンドとして入れる（uv のツール置き場に入ります）
uv tool install --from tools/pathctl pathctl
pathctl doctor
```

`uv tool install` の bin（`%USERPROFILE%\.local\bin`）が PATH に無い場合は、この CLI 自身で足せます。

```powershell
pathctl path add '%USERPROFILE%\.local\bin' --scope user --apply
```

## コマンド

| コマンド | 内容 |
|---|---|
| `pathctl path list [--scope machine\|user\|effective\|all]` | PATH の内容を一覧（`exists` / ユーザー固有かどうか付き） |
| `pathctl path check` | 重複・個人パスの混入・存在しないパス・空エントリを検出 |
| `pathctl path fix [--scope ...] [--apply] [--move-user-entries] [--prune-missing]` | 安全な修復。既定は**下見のみ** |
| `pathctl path add <dir> [--scope user\|machine] [--apply]` | エントリを追加（`%USERPROFILE%` などの変数可） |
| `pathctl path remove <dir> [--scope ...] [--apply]` | エントリを削除 |
| `pathctl tools [--without-mise] [--via <入手元>] [--name <glob>]` | ツールと入手元の一覧 |
| `pathctl doctor [--strict]` | PATH とツールをまとめて点検 |
| `pathctl schema` | エージェント向けの入出力契約（コマンド・JSON・終了コード） |

### 検出コード（`findings[].code`）

`empty-entry` / `duplicate-in-scope` / `duplicate-across-scopes` / `user-path-in-machine` / `missing-directory` / `trailing-separator` / `mise-shims-not-first` / `tool-shadowed` / `tool-not-on-path`

### 入手元（`provenance`）

`mise-shim` / `mise-install` / `winget` / `npm-global` / `direct` / `unavailable`

`without_mise: true` は「**mise が無くても PATH から起動できる**」コマンドです（mise の shim 以外のディレクトリから解決できる場合）。

## エージェント向けの契約

`--json` の出力は常に同じ形です。

```json
{
  "schema": "pathctl/1",
  "command": "doctor",
  "ok": false,
  "data": { "...": "コマンド固有のデータ" },
  "findings": [
    { "code": "user-path-in-machine", "severity": "error", "scope": "machine", "detail": "...", "hint": "..." }
  ],
  "hints": ["..."]
}
```

- 終了コード: `0` 成功 / `1` findings あり・適用失敗 / `2` 引数の誤り
- `pathctl schema --json` に全コマンドと例が入っています。**まずこれを読む**のが最短です
- TTY 以外では色を自動で無効化します（`--no-color` / `NO_COLOR` も有効）

## 設計上の約束

- **`%VAR%` を展開して保存し直さない**。エントリは生の文字列のまま編集します（`C:\Users\%USERNAME%\...` の意味を壊さないため）
- レジストリの値の型（`REG_SZ` / `REG_EXPAND_SZ`）を保ったまま書き戻します
- `pathctl path fix` は、空エントリの削除・同一スコープ内の重複統合・末尾区切りの整理だけを既定にし、**個人パスの移動**と**存在しないパスの削除**は明示フラグが要ります
- 書き換え後は `WM_SETTINGCHANGE` をブロードキャストします（既存のアプリは再起動が必要）

## 効率性と不変性（Effective Python 第2版）

| 方針 | 適用箇所 |
|---|---|
| **値オブジェクトは `frozen=True`** | `PathEntry` / `Finding` / `Tool` / `Report`（不変・比較可能・ハッシュ可能）|
| **構築中に変わるものは可変** | `FixPlan`（`slots=True` のみ。`actions` / `moved` を追記する builder）|
| **`NamedTuple`（frozen な値）** | `docs.Guide`（名前＋要約の組。unpack もできる）|
| **`frozenset` を定数に** | `model.MISE_PROVENANCES`（プロパティ内の set リテラルはアクセスごとに作り直されるため）|
| **`functools.cache`** | `tools.known_dirs()`、`render.display_width()`（同じセルを毎行数え直さない）|
| **ループの不変条件を巻き上げ** | `inventory()` の shims パス正規化、`findings_block()` の色判定 |
| **計算量の見直し** | `FixPlan.as_dict()` は key 集合を先に作る（O(n²) を回避）|
| **例外は絞る** | `OSError` / `RuntimeError` のみ（`except Exception` を使わない）|
| **テストは `unittest`** | 44 件（エージェント向け 8 原則の検証を含む）。追加依存なし |

`freeze` の使い分けの基準は「**値か、途中状態か**」です。値（エントリ・検出結果・ツール・レポート）は
frozen にして取り違えを防ぎ、組み立て中の `FixPlan` だけを可変にしています。集合は定数として
`frozenset` に、辞書は `Final` にして、うっかり書き換えないようにしています。

## 開発

```powershell
uv sync                 # 開発環境（dev 依存は ty のみ）
uv run ty check --python-platform win32 tools/pathctl   # 型チェック（Windows 専用ツールのため win32 を明示）
uv run python -m unittest discover -s tests   # テスト（追加依存なし）
uv run pathctl doctor   # 動作確認
```

`pyproject.toml` の `[tool.ty.environment]` でも `python-platform = "win32"` を指定していますが、
リポジトリ直下から実行すると設定が読まれないことがあるため、CI と開発コマンドではフラグで明示します
（Linux ランナーで `winreg` が未解決になるのを防ぐため）。

## リリースと検証（SLSA Build Level 3）

タグ `pathctl-v<version>` を push すると `.github/workflows/release.yml` が走ります。

1. `pyproject.toml` の `version` を上げてコミット（タグと一致しないと失敗します）
2. `git tag pathctl-v0.1.2 && git push origin pathctl-v0.1.2`
3. GitHub Release に wheel / sdist / `SHA256SUMS` が添付され、provenance が発行されます

### SLSA v1.0（build track）への対応

| SLSA の要件 | この実装 |
|---|---|
| ビルドはコードで完全に定義される | `release.yml` のみ。手作業なし |
| ビルドは隔離された使い捨て環境で走る | GitHub ホストの `ubuntu-latest`。**キャッシュを復元しない**（`cache: false`）ので前回の実行が成果物に影響しない |
| 依存は固定される | ツールは `mise.toml` / `mise.lock`（`--locked`）、Python は `uv.lock`（`uv sync --frozen`） |
| provenance はビルド基盤が発行し、改ざんできない | `actions/attest-build-provenance`（GitHub が OIDC で署名。リポジトリ内のスクリプトは関与しない）|
| 公開される成果物はビルドしたものと同一 | 1 回ビルド → `upload-artifact` → Release / PyPI はそのファイルのみ（再ビルドしない）|
| 成果物の完全性が検証できる | `SHA256SUMS` を添付し、公開前に `sha256sum -c` で再検証 |
| 公開は短期トークンを使わない | **PyPI Trusted Publishing（OIDC）**。`uv publish --trusted-publishing always` |
| 公開物に attestation が付く | `uv publish` が **PEP 740** の publish attestation を添付（PyPI の Attestations に表示）|

### 利用者側の検証

```console
# GitHub の provenance（SLSA Build L3）
gh attestation verify pathctl-0.1.2-py3-none-any.whl --repo kotarotaniguchi0523/win-host-setup

# ダイジェスト（成果物と同じディレクトリで実行）
sha256sum -c SHA256SUMS

# PyPI の attestation はプロジェクトのファイル一覧から確認できる（PEP 740）
```

検証結果として、provenance は次の内容を主張します（`--format json` で確認できます）。

| 項目 | 値の例 |
|---|---|
| `predicateType` | `https://slsa.dev/provenance/v1` |
| issuer | `https://token.actions.githubusercontent.com`（GitHub の OIDC）|
| workflow | `.github/workflows/release.yml` @ `refs/tags/pathctl-v0.1.2` |
| subject | 公開した wheel / sdist の sha256（`SHA256SUMS` と一致）|

### PyPI へ公開する場合（任意・1 回だけの設定）

PyPI 側で **Trusted Publisher** を登録します（トークンは不要です）。

- Publisher: GitHub / Owner: `kotarotaniguchi0523` / Repository: `win-host-setup`
- Workflow name: `release.yml` / Environment name: `pypi`

登録後、リポジトリの変数 `PYPI_PUBLISH` を `true` にすると、以後のタグ push で
`uv publish --trusted-publishing always` が実行されます（未設定なら GitHub Release だけが作られます）。
環境 `pypi` には必要なら Required reviewers を設定して、公開を人手で承認する運用にもできます。

なお **2026-10-16 時点では PyPI への公開は未有効**です（Trusted Publisher 未登録のため、
`PYPI_PUBLISH` は未設定のままにしています）。

Python 3.15 を前提に、新しい文法を使っています（下限は 3.14。理由は下の「注意」）。

- `type` 文（PEP 695）と型パラメータ記法
- `StrEnum` / `dataclass(slots=True, frozen=True)` / `match`
- t-strings（PEP 750）: `render.style()` が `t"{値:ok}"` の書式指定を色として解釈します
- `pathlib.Path` / `winreg` / `ctypes`（標準ライブラリのみ）

注意: `pyproject.toml` の `requires-python` は **`>=3.14`** です。実行環境（このホストと CI）は **3.15.0** 固定ですが、
下限を 3.15 にすると GitHub の依存グラフ更新（Dependabot）が `tool_version_not_supported`（対応は 3.14 まで）で
失敗するため、コードが実際に必要とする下限（t-strings = 3.14）を宣言しています。
