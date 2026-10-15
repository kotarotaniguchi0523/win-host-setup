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

## 開発

```powershell
uv sync                 # 開発環境（dev 依存は ty のみ）
uv run ty check         # 型チェック
uv run pathctl doctor   # 動作確認
```

Python 3.15 を前提に、新しい文法を使っています（下限は 3.14。理由は下の「注意」）。

- `type` 文（PEP 695）と型パラメータ記法
- `StrEnum` / `dataclass(slots=True, frozen=True)` / `match`
- t-strings（PEP 750）: `render.style()` が `t"{値:ok}"` の書式指定を色として解釈します
- `pathlib.Path` / `winreg` / `ctypes`（標準ライブラリのみ）

注意: `pyproject.toml` の `requires-python` は **`>=3.14`** です。実行環境（このホストと CI）は **3.15.0** 固定ですが、
下限を 3.15 にすると GitHub の依存グラフ更新（Dependabot）が `tool_version_not_supported`（対応は 3.14 まで）で
失敗するため、コードが実際に必要とする下限（t-strings = 3.14）を宣言しています。
