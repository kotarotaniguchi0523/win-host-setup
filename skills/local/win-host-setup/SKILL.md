---
name: win-host-setup
description: Use when working on THIS Windows host's global tooling — installing or updating global CLIs, deciding between mise and winget, managing global Skills (APM), changing PATH, or syncing/committing the host configuration to the win-host-setup repository. Triggers include "install <tool> globally", "mise or winget?", "add a skill", "update the pinned version", "why is this tool here", "sync the host setup", "sanitize and push", or any request touching the host's global environment rather than a project.
---

# win-host-setup（このホストのグローバル環境）

このホストのグローバル導入は **mise に統一**されている。このリポジトリが**唯一のソース**で、
`~/.config/mise/config.toml` と `~/.apm/apm.yml` はこのリポジトリから配布される。

## 判断基準（これを必ず適用する）

**① msstore 公式 → ② mise/aqua の「実効検証」 → ③ winget（Publisher + SHA256）**

- **「機能の存在」ではなく実効性**で判断する。`mise tool <名>` の **`Security:` 行**で確認する。
- ② の実効検証 = `checksum (sha256)` / `attestations`（SLSA provenance）/ `cosign` / `gpg`。
- `Security: [none]` の**表示でも実効検証がある場合がある**:
  - `pypi:` → `mise.lock` の **uv 依存グラフに wheel ハッシュ**
  - `npm:` → **registry integrity (sha512) + provenance**（mise の pnpm が検証）
- mise に実効検証が無く、winget に**同一版**がある場合は **winget が上位**。
- **`latest` を使わず正確にピン留め**し、`mise.lock` で再現する。
- 既知の逸脱: `herdr`（winget は preview のみ / aqua は `[none]`）、`skillspector`（`pypi:` で `[none]`）。

## 主要なコマンド

```powershell
pwsh -File tools/apply.ps1          # リポジトリ → 実環境（mise config/lock を ~/.config/mise へ）
pwsh -File tools/skills-apply.ps1 -Lock   # Skills（APM）を ~/.apm へ配置 + lock 再生成 + 自作 Skill 展開
pwsh -File tools/capture.ps1        # 実環境 → リポジトリ
pwsh -File tools/skills-capture.ps1 # Skills（~/.apm・自作）→ リポジトリ
pwsh -File tools/sanitize.ps1       # public/ を再生成（個人情報を伏せる）
pwsh -File tools/sync.ps1           # capture → skills-capture → sanitize → commit → push（全部）
pwsh -File tools/update-winget-dsc.ps1 [-Apply]  # winget 最新版と突き合わせ
pwsh -File tools/fix-machine-path.ps1 [-Apply]   # Machine PATH 整理（管理者）
```

## 落とし穴（必ず守る）

1. **`~/.config/mise/config.toml` をリポジトリに `config.toml` の名前で置かない**。そのディレクトリで mise が
   「プロジェクト設定」として読み、`paranoid` が無視されて未信頼エラーになる。**`mise/mise.toml`** に置く。
2. **既定 Python は 3.15.0**。`cp315` wheel が無い依存（`pyyaml` 等）を持つ Python ツールは `pypi:` で**導入不能**。
   さらに mise は「不足ツールの自動導入」を全コマンドで試みるため、**1 ツールの失敗が全 mise コマンドの停止（ハング）に波及**する。
   → その場合は **winget へ逃がす**（例: APM は `Microsoft.APM`）か、**wheel のある 3.14 を明示**する。
3. **配列は先頭が既定**: `node = ["26.11.1", "24.21.0"]` / `python = ["3.15.0", "3.14.8"]`。fallback 側は手動更新。
4. **PATH は mise shims が先頭**。`~\.cargo\bin` は PATH に入れない（rustup は mise 経由）。`~\.rustup` は**削除禁止**。
5. winget は **`Installer SHA256`（マニフェスト固定）**、msstore は**発行者**で判断する。
6. Skill を足したら **`skills/apm.yml` に `owner/repo#ref`**（Renovate が更新）。自作は **`skills/local/<name>/SKILL.md`**。

## 参照

- `AGENTS.md` — ポリシー本文 / `AUDIT.md` — ポリシー監査
- `winget-vs-mise.md` — **全ツールの判定表**（mise か winget か）
- `PLAN.md` — 計画と実施ログ（上=未完了 / 下=完了）
- `.github/workflows/` — renovate / relock / validate / skills / winget-outdated / healthcheck
