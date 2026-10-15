> このリポジトリは `tools/sanitize.ps1` の生成物です（ユーザー名・パス・ホスト名をプレースホルダ化）。
> 実環境の値は含みません。

# win-host-setup

**Windows ホストのグローバル導入を [mise](https://mise.jdx.dev/) に統一し、検証可能（サプライチェーン重視）にする**ための設計・実施記録・再現手順。

> 対象は **Windows 本体のグローバル導入のみ**。プロジェクトローカル、エディタ/ブラウザ拡張、WSL 内部は対象外。

## このリポジトリの読み方

| ファイル | 内容 |
|---|---|
| **`AGENTS.md`** | **Package Management Policy（判断基準の本体）** |
| **`PLAN.md`** | 計画＋実施ログ。**上=未完了 / 下=完了（同一見出しでアーカイブ）** |
| **`AUDIT.md`** | ポリシー準拠の監査（全ツールの入手方法と `Security:` 行） |
| **`winget-vs-mise.md`** | **全ツールの「mise vs winget」判定**（どちらの検証が強いか） |
| `inventory.md` / `TODO-inventory.md` | パッケージ棚卸し |
| `repos.md` / `repos-analysis.md` | リポジトリの分析 |
| `tools/` | 棚卸し・サニタイズ・復元・PATH 修正のスクリプト |
| `winget/host.dsc.yaml` | winget の宣言的構成（全バージョン固定） |
| `mise/mise.toml` / `mise/mise.lock` | mise のグローバル設定と lock（**コピー**。`tools/apply.ps1` で `~/.config/mise/` へ適用）<br>※ リポジトリ内で mise に「プロジェクト設定」として拾われないよう **`mise.toml` の名前**で保存 |

## 判断基準（要約）

**① msstore 公式 → ② mise/aqua の“実効検証” → ③ winget（Publisher + SHA256）**

- **「機能の存在」ではなく実効性**で判断する（`mise tool <名>` の `Security:` 行で確認）。
- ② の「実効検証」= `checksum (sha256)` / `attestations`（SLSA provenance）/ `cosign` / `gpg`。
- `Security: [none]` の表示でも、`pypi:` は **uv 依存グラフの wheel ハッシュ**、`npm:` は **registry integrity + provenance** で実効検証されている場合がある。
- mise が検証を持たない場合は **winget（マニフェストの `Installer SHA256`）** が上位。
- **正確にピン留め**し、`mise.lock` で再現可能にする（`latest` を使わない）。

## 主要な結論（2026-10-15 時点）

- 核は **mise**（winget `jdx.mise`）。Nix は不使用。
- セキュア設定: `paranoid = true` / `locked = true` / `locked_verify_provenance = true` / `minimum_release_age = "2d"` / `pin = true`。
- 既定バージョンは **最新**（`node` 26.x / `python` 3.15.x）。**1 つ前の系統も併設**（`24.x` / `3.14.x`）。mise の配列は**先頭が既定**。
- 依存レーンは **Takumi Guard**（npm/pypi を `npm.flatt.tech` / `pypi.flatt.tech` 経由に）。
- **winget へ移したもの**: `rust-analyzer`（mise/aqua が `[none]` のため）、`apm`（既定 Python 3.15 で依存 `pyyaml` の cp315 wheel が無く `pypi:` で導入不能のため）。
- **既知の逸脱**: `herdr`（winget に stable が無く aqua も `[none]`）。

## 自動更新（Renovate + GitHub Actions）

**「Renovate が PR を作り、CI が検証し、relock が lock を追随させる」**体制です。

| ワークフロー | 役割 |
|---|---|
| `.github/workflows/renovate.yml` | Renovate（セルフホスト）を週次＋手動で実行 → 依存更新 PR を作成。**`RENOVATE_TOKEN`（PAT）** が必要 |
| `.github/workflows/relock.yml` | `mise/config.toml` が変わった PR で **`mise lock` を実行し `mise.lock` を同じ PR に積む** |
| `.github/workflows/validate.yml` | push / PR で **`mise install --locked`（ロックのドリフト検出）** ＋ PSScriptAnalyzer ＋ JSON/YAML/TOML 構文 |
| `.github/workflows/winget-outdated.yml` | 週次（Windows ランナー）で **`winget` 自身を情報源に `host.dsc.yaml` のピンを更新**し PR を作成 |
| `.github/workflows/skills.yml` | `skills/**` の変更で **APM のマニフェスト検証・`apm.lock.yaml` ドリフト検出・`apm audit`（セキュリティ監査）** |
| `.github/workflows/healthcheck.yml` | 週次で **`mise` のドリフト／更新候補・winget の乖離・公開リポジトリの衛生（個人パス混入検査）** を点検 |

### Renovate が担当する範囲
- **`mise/config.toml`**（native な `mise` マネージャ）— 25 ツール前後を継続更新。
  - **配列の先頭（＝既定バージョン）のみ**更新される（`node` / `python` の fallback 側は手動）。
  - `pypi:git+…@v2.12.0`（SkillSpector）のような **git 固定は自動更新されない**。
- **GitHub Actions**（`pinDigests: true` でコミット SHA 固定）。
- **winget の DSC は Renovate 非対応**のため、上記 `winget-outdated.yml` が担当（`msstore` は対象外）。

### ポリシーとの整合
- `minimumReleaseAge: "2 days"` を Renovate 側にも設定し、mise の `minimum_release_age = "2d"` と揃えています。
- `mise.lock` の再生成は Renovate ではなく **CI（relock.yml）** に寄せ、`allowedUnsafeExecutions` を空にしています（実行権限を Renovate に渡さない）。

### グループごとの PR
Renovate / CI は **グループごとに 1 PR** を作ります。

| グループ | 担当 | 対象 |
|---|---|---|
| **mise tools** | Renovate（`mise` マネージャ） | `mise/mise.toml` の全ツール（配列の先頭＝既定のみ） |
| **GitHub Actions** | Renovate（`github-actions`） | 各ワークフローの `uses:`（コミット SHA 固定） |
| **Skills (APM)** | Renovate（`apm` マネージャ） | `skills/apm.yml` の `owner/repo#ref` |
| **winget (DSC)** | `winget-outdated.yml` | `winget/host.dsc.yaml`（`msstore` は除く） |

`mise.lock` の再生成は `relock.yml`、`apm.lock.yaml` の再生成は `tools/skills-apply.ps1 -Lock`（＋`skills.yml` がドリフト検出）が担当します。

## Skills の管理（APM）

**APM（Agent Package Manager）** でグローバル Skills を管理します。実体は `~/.apm/` に置かれ、このリポジトリが**唯一のソース**です。

| リポジトリ | 実環境 |
|---|---|
| `skills/apm.yml` | `~/.apm/apm.yml`（リモート Skill の宣言） |
| `skills/apm.lock.yaml` | `~/.apm/apm.lock.yaml`（**commit SHA + ファイルごとの sha256**） |
| `skills/local/<name>/SKILL.md` | `~/.agents/skills/<name>/`（**自作 Skill**） |

```powershell
# 実環境へ適用（+ lock 再生成）
pwsh -File tools/skills-apply.ps1 -Lock
```

- スキルの追加は `skills/apm.yml` の `dependencies.apm` に **`owner/repo#ref`** を書くだけ。**Renovate が自動で更新**します。
- **自作 Skill** は `skills/local/<name>/SKILL.md` に置きます（APM 管理外として扱われ、Renovate の対象になりません）。
- `apm audit`（`skills.yml`）が **hidden Unicode / drift / policy 違反**を検査し、**SARIF を Code Scanning へ**上げます。
- **Waza**（`waza check` / `coverage` / `gate`）でも Skill を評価します（CI に組み込み済み）。
- `apm audit --external skillspector` を使う場合は `apm experimental enable external-scanners` が必要です（skillspector は重量なため 1 回 240 秒超）。

### ローカルで更新 → Push

ホスト側で Skills や設定を変えたら、**1 コマンド**でリポジトリと公開版へ反映できます。

```powershell
pwsh -File tools/sync.ps1                  # capture → skills-capture → sanitize → commit → push
pwsh -File tools/sync.ps1 -NoPush          # push しない（確認用）
pwsh -File tools/sync.ps1 -Message "..."   # コミットメッセージ指定
```

1. `tools/capture.ps1` — `~/.config/mise` → `mise/`
2. `tools/skills-capture.ps1` — `~/.apm` と自作 Skill → `skills/`
3. `tools/sanitize.ps1` — `public/` を再生成（個人情報を伏せる）
4. source リポジトリをコミット → public リポジトリをコミットして push

### 必要な Secrets
| 名前 | 用途 |
|---|---|
| `RENOVATE_TOKEN` | Renovate が PR を作るための PAT（`repo` スコープ） |

## 再現手順

```powershell
# 1) 設定を適用（mise config + lock）
pwsh -File tools/apply.ps1

# 2) winget の宣言的構成を適用
winget configure winget/host.dsc.yaml

# 3) 検証
mise doctor
```

## サニタイズ（公開用コピーの生成）

```powershell
pwsh -File tools/depii.ps1 -Check   # ソース側の PII 検出（0 が目標）
pwsh -File tools/depii.ps1          # ソース側を in-place で浄化
pwsh -File tools/sanitize.ps1       # → public/ に個人情報を伏せたコピーを生成（最後の防波堤）
```

置換内容: `C:\Users\<user>` → `%USERPROFILE%`、ユーザー名・GitHub アカウント名・メール・ホスト名 → プレースホルダ。
ルールは **`tools/pii-rules.ps1`** に一元化。社内レジストリ（`flatt.tech`）は公開可（ユーザー判断）。

### データの置き場所

| 置き場所 | 内容 | 公開 |
|---|---|---|
| リポジトリ直下 | ドキュメント・設定・CI（**PII はプレースホルダで書く**） | ✅ public へ |
| **`.agent/`** | 生データ・退避データ・個人メモ（**.gitignore 済み**） | ❌ ローカルのみ |
| `public/` | `sanitize.ps1` の生成物（独立リポジトリ） | ✅ push 対象 |
