# AGENTS.md: Windows Package Management Policy

Windows ホスト OS へのソフトウェア導入・更新では、**サプライチェーンセキュリティ・配布元の真正性・最小権限・再現性**を優先する。

## 選択ルール

1. **公式 Microsoft Store 版を優先する。**
   - 開発元自身が公開した正規パッケージであることを確認する。
   - WinGet の `msstore` ソースを明示的に使用する。
   - MSIX・EXE・MSI の形式だけで安全性を判断しない。

2. **開発用 CLI では mise/aqua の検証能力を比較する。**
   - Cosign、SLSA provenance、GitHub Artifact Attestations などによる真正性検証が**実際に利用できる場合**、mise/aqua を優先候補とする。
   - 「対応機能がある」だけでなく、**対象パッケージで検証が有効**であることを確認する。
   - プロジェクト単位のバージョン固定・再現性が必要な場合は mise を優先する。

3. **上記が適さない場合は通常の WinGet を使用する。**
   - 公式の `winget` ソースと信頼できる開発元の配布物を選択する。
   - SHA-256・署名・配布元 URL を可能な範囲で検証する。

## 共通セキュリティ要件

- 信頼できない第三者の再配布物・パッケージソースを避ける。
- 可能な限りバージョンを固定し、検証可能な成果物を取得する。
- インストール時の管理者権限・任意スクリプト実行・不要な PATH 変更を最小限にする。
- 既存のパッケージ管理との重複や競合を避ける。
- 署名・provenance・ハッシュ検証・マルウェア検査を**混同しない**。
- 安全性を確認できない場合は推測で判断せず、**問題点を報告する**。

## 実行原則

インストール前に**公式配布元・利用可能な配布方式・実際のセキュリティ検証方法**を調査する。
優先順位は絶対的な安全性の序列ではなく、**対象パッケージごとの検証結果**に基づいて決定する。

---

## このホストへの適用方針（本リポジトリ）

- **mise**: `~/.config/mise/config.toml` + `mise.lock`（`paranoid`/`locked`/`minimum_release_age="2d"`/`pin`）。検証は `mise tool <name>` の `Security:` 行で**実効性を確認**する。
- **winget**: 宣言は WinGet Configuration（DSC）。Store 版があるものは `--source msstore` を明示。
- **Chocolatey / Scoop は使わない**。
- **グローバル導入は「宣言」にだけ置く**。CLI・ランタイムは mise（`~/.config/mise/config.toml`、このリポジトリでは `mise/mise.toml`）、
  mise で扱えない例外だけ winget（`winget/host.dsc.yaml`）。それ以外の場所に入れると「野良グローバル」として扱う。
- **野良は `pathctl audit` で検出する**（`npm -g` / `uv tool` / インストーラが足した PATH など）。
  見つけたら、mise に宣言するか、winget の DSC に入れるか、**SBX（Docker Sandboxes）で実行する**ように移す。
- **mise にツールを足したら `mise lock --global`** を実行する（`locked = true` のため、ロックに無いツールは shim が解決できず失敗する）。
- **postinstall で実体を取得する npm パッケージ**は、そのツールだけ `npm_args` で script を許可する
  （mise の既定 `--ignore-scripts=true` と npm 11.16+ の `--allow-scripts`。pnpm では lifecycle script が動かない）。

---

## このリポジトリのデータ方針（PII・ローカル専用）

- **リポジトリには個人情報を書かない。** プレースホルダを使う。

  | 対象 | 表記 |
  |---|---|
  | ホームディレクトリ | `%USERPROFILE%` |
  | ユーザー名 | `%USERNAME%` |
  | ホスト名 | `%COMPUTERNAME%` |
  | Git アカウント | `%GITHUB_USER%` / `%GITHUB_USER_2%` |
  | メール | `%EMAIL%` |
  | 案件・個人プロジェクト名 | `%PROJECT_NAME%` |

  - 置換ルールは **`tools/pii-rules.ps1`** に一元化する。
  - **`tools/depii.ps1`** が公開対象ファイルを in-place で浄化し、**`tools/sanitize.ps1`** が `public/` 生成時に最終防波堤として適用する。
  - コミット前に `pwsh -File tools/depii.ps1 -Check` を実行し、検出 **0** を確認する。

- **公開しないデータは `.agent/` に置く（`.gitignore` 済み・コミットされない）。**
  - ホスト固有の生データ（`inventory-*.txt` / `winget-search-raw.txt` / `path-backup-*.txt` / `mise-security.json`）
  - 削除前の退避データ（`backup-removals-*` / `backup-pyenv-*`）
  - 個人的なメモ・一時ファイル

- **秘密はどこにも保存しない。** トークンは環境変数、CI では GitHub Secrets（`RENOVATE_TOKEN`）に置く。`env/variables.md` は秘密を自動で伏せる。
