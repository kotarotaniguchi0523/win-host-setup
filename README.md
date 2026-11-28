# win-host-setup

Windows ホストの**グローバル導入**を宣言ファイルで管理し、**更新は PR・適用はホスト**で再現可能にするリポジトリ。
対象は Windows 本体のグローバル導入のみ（プロジェクトローカル、エディタ/ブラウザ拡張、WSL 内部は対象外）。

## 基本方針

判断基準の本体は **[`AGENTS.md`](AGENTS.md)**。要点だけ:

- 選定は **① 公式 Microsoft Store（`msstore`）→ ② mise の実効検証（checksum / attestations / cosign / gpg）→ ③ winget の厳密 pin**。
- 「機能がある」ではなく **実効性**で判断する（`mise tool <name>` の `Security:` 行）。
- 版は厳密に固定し、**`mise.lock` と `mise/locks/`（aube の依存グラフ）**で再現する。
- 自己更新できるものは**自己更新を止め**、宣言だけを更新経路にする。止められないものだけ `exceptions.tsv` に例外登録（署名検証）。

## 現在の構成（2026-11-28）

| 層 | 対象 | 実体 |
|---|---|---|
| **mise** | CLI・ランタイム・npm ツール・APM・obscura など | `mise/mise.toml` + `mise.lock` + `mise/locks/` |
| **msstore** | PowerShell / WSL / Ubuntu | `winget/host.dsc.yaml`（`source: msstore`） |
| **winget** | mise / Git / Docker Desktop / Docker sbx | `winget/host.dsc.yaml`（厳密 pin・自己更新 OFF） |
| **例外** | T3 Code desktop | `exceptions.tsv`（`verify-host` が Authenticode 署名を確認） |

備考: `curl` は **OS 標準（System32 / Microsoft 署名）** を使う。`Docker Desktop` は Store 掲載（`XP8CBJ40XLBWKX`）もあるが、配布物は Win32 インストーラー（MSIX ではない）ため winget pin 側で宣言している。

## ファイル

| ファイル | 内容 |
|---|---|
| `AGENTS.md` | **Package Management Policy（判断基準の本体）** |
| `PLAN.md` | 計画と実施ログ（上=未完了 / 下=完了） |
| `AUDIT.md` | ポリシー準拠の監査（入手方法と実効検証） |
| `docs/automation.md` | **更新の仕組み（Renovate / CI / ホスト適用）** |
| `winget-vs-mise.md` | 全ツールの「mise vs winget」判定の記録 |
| `winget/host.dsc.yaml` | winget / msstore の宣言（WinGet Configuration） |
| `mise/mise.toml` / `mise/mise.lock` / `mise/locks/` | mise の宣言と lock（`tools/apply.ps1` で `~/.config/mise/` へ適用） |
| `skills/` | APM のマニフェスト・lock・自作 Skill |
| `tools/` | 適用・検証・同期・サニタイズ・PATH 点検（`pathctl`） |
| `exceptions.tsv` | 自己更新を止められないアプリの例外（署名者つき） |

## 日常の操作

```powershell
pwsh -File tools/run-task.ps1 -Task check    # 差分・ドリフトの表示（読み取りのみ）
pwsh -File tools/run-task.ps1 -Task update   # public 取り込み → mise → skills → winget（管理者）→ verify
pwsh -File tools/run-task.ps1 -Task verify   # 検証のみ（.agent/update-report.json）
pwsh -File tools/sync.ps1                    # ホスト → リポジトリ → public へ反映
```

- `tools/verify-host.ps1` の結果が **`ng=0`** を保つのが運用の基準。
- `winget configure` は管理者権限が必要（非管理者では警告してスキップ）。
- `mise install` は `shims\mise.exe` を作るが、そのままだと全シムが再帰で壊れる。**`tools/apply.ps1` が直後に削除**する。

## 更新の流れ（要点）

Renovate が PR → CI（lint / validate / skills）→ relock（mise / APM の lock）→ automerge → ホストは `pull` で追随。
詳細と運用ルールは **[`docs/automation.md`](docs/automation.md)**。

- 必須: `relock` Environment の **`RELOCK_APP_CLIENT_ID`**（Variable）と **`RELOCK_APP_PRIVATE_KEY`**（Secret）。
- ローカルで lock を作り直すときは GitHub API のレート制限を避けるため **`GITHUB_TOKEN`** を渡す。
- 検証結果は `.agent/update-report.json`（ローカルのみ・コミットしない）。

## 再現手順

```powershell
pwsh -File tools/apply.ps1                      # 1) mise config + lock を適用
winget configure winget/host.dsc.yaml           # 2) winget / msstore を適用（管理者）
pwsh -File tools/skills-apply.ps1 -Lock         # 3) Skills（APM）を適用
pwsh -File tools/verify-host.ps1                # 4) 検証
```

- PATH の大掃除: `tools/fix-machine-path.ps1`（管理者）。日常の点検・微修正: `pathctl`（`tools/pathctl/README.md`）。

## 公開用コピー

```powershell
pwsh -File tools/depii.ps1 -Check   # 個人情報の検出（0 が目標）
pwsh -File tools/sanitize.ps1       # public/ を生成（最後の防波堤）
```

個人情報はプレースホルダで書き、置換ルールは `tools/pii-rules.ps1` に一元化。`.agent/` はローカルのみ（`.gitignore`）。

## さらに読む

`AGENTS.md`（方針） / `docs/automation.md`（更新） / `AUDIT.md`（監査） / `winget-vs-mise.md`（判定の記録） / `tools/pathctl/README.md`（PATH CLI）
