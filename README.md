> このリポジトリは 	ools/sanitize.ps1 の生成物です（ユーザー名・パス・ホスト名をプレースホルダ化）。
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

### Renovate が担当する範囲
- **`mise/config.toml`**（native な `mise` マネージャ）— 25 ツール前後を継続更新。
  - **配列の先頭（＝既定バージョン）のみ**更新される（`node` / `python` の fallback 側は手動）。
  - `pypi:git+…@v2.12.0`（SkillSpector）のような **git 固定は自動更新されない**。
- **GitHub Actions**（`pinDigests: true` でコミット SHA 固定）。
- **winget の DSC は Renovate 非対応**のため、上記 `winget-outdated.yml` が担当（`msstore` は対象外）。

### ポリシーとの整合
- `minimumReleaseAge: "2 days"` を Renovate 側にも設定し、mise の `minimum_release_age = "2d"` と揃えています。
- `mise.lock` の再生成は Renovate ではなく **CI（relock.yml）** に寄せ、`allowedUnsafeExecutions` を空にしています（実行権限を Renovate に渡さない）。

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
pwsh -File tools/sanitize.ps1     # → public/ に個人情報を伏せたコピーを生成
```

置換内容: `C:\Users\<user>` → `%USERPROFILE%`、ユーザー名・GitHub アカウント名・ホスト名 → プレースホルダ。
社内レジストリ（`flatt.tech`）は公開可（ユーザー判断）。
