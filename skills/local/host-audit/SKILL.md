---
name: host-audit
description: Use when you need to judge whether THIS Windows host still matches the pinned declarations in win-host-setup — drift from the pins, versions that moved without a PR, stray global installs (npm -g / uv tool), or CLIs that self-updated outside mise. Triggers include "host audit", "ドリフト確認", "pin どおりか", "野良チェック", "remote と何が違う", "更新してよいか", "毎日の点検", "daily check", or any scheduled host inspection.
---

# host-audit（ホストの点検・判定）

**役割は「判定だけ」**。宣言（`public/`）とこのホストの実体を比べ、差分と次の一手を返す。
**変更・削除・アンインストールはしない。** 適用は `tools/run-task.ps1 -Task update`（管理者シェル）に任せる。

## 前提

- 正は `public/`（GitHub のミラー）。CI が見ているものと、ホストが pull するものが同じ。
- ホストは版を決めない。`mise upgrade` / `winget upgrade --all` / `t3 update` / `opencode upgrade` などは**禁止**。
- 方針の全体像は `docs/automation.md`。

## 手順（この順で、すべて読み取りのみ）

### 1. 宣言との差分

```powershell
pwsh -File tools/run-task.ps1 -Task check
```

`tools/verify-host.ps1` が判定し、`.agent/update-report.json` に書く。見る項目は
`mise-missing` / `mise-pins` / `mise-config` / `declarations` / `skills-files` / `winget-dsc` / `git-remote`。

### 2. 野良グローバル

```powershell
uv run --project tools/pathctl pathctl audit --format json
```

- `stray-npm-global` / `stray-uv-tool` → **野良**。mise（`npm:` / `pypi:`）か SBX へ移す。
- `unmanaged-path-entry` → info。アプリ付属の PATH なので基本は放置。

### 3. mise 管理外の実体（自己更新の痕跡）

次のパスに**実行ファイルがあれば**「mise/winget の外で入ったもの」として報告する（削除はしない）。

```
~\.t3\versions         # t3 update
~\.opencode\bin        # opencode upgrade
~\.local\bin
~\.cargo\bin           # PATH に入れない（rustup は mise 経由）
%LOCALAPPDATA%\uv
%APPDATA%\npm
~\go\bin
```

### 4. msstore は対象外

`9MVS1J51GMK6` は Store が自動更新する。**差分として報告しない**（方針上信頼済み）。

## 判定と次の一手

| 検出 | 意味 | 次にやること |
|---|---|---|
| `mise-pins` / `mise-missing` ng | pin の版が無い・未導入 | `tools/run-task.ps1 -Task update` |
| `mise-config` ng | `~/.config/mise` が repo と違う | `-Task update` |
| `winget-dsc` ng | DSC と乖離 | **管理者**で `-Task update` |
| `git-remote` behind > 0 | public が古い | `-Task update` |
| `git-remote` ahead > 0 | public に未 push のコミット | `git -C public push`（**適用しない**） |
| `declarations` ng | source と public が不一致 | `tools/sync.ps1 -NoPush` で差分確認 |
| `stray-*` | 野良 | mise へ移す / SBX へ |
| 管理外の実体 | 自己更新 | self-update を止め、mise へ寄せる |

## 守ること

1. **書き込みはしない。** この skill は read-only（`-Task check` と `pathctl audit` だけ）。
2. **管理者が要る操作**（winget / Machine PATH / overrides）は、エージェントが昇格できないので**ユーザーに依頼**する。
3. レポートは **「結論 → 差分 → 次の一手（最大3つ）」** の順で短く。数値とコマンドを添える。
4. `git-remote` が ahead のときは、**その内容を適用してはいけない**（CI 未検証のため）。

## 定期実行

- トリガーは **T3 Code のスケジュール**から「host-audit を実行して」で呼ぶ（アプリ起動中のみ動く）。
- Git hook で「1日1回だけ」にしたい場合は、`.agent/last-host-audit.json` のタイムスタンプを見て
  24時間以内ならスキップする**ゲートを挟む**（hook は git 操作時にしか発火しないので、あくまで補助）。

## 参照

- `docs/automation.md` — 更新の全体像（remote-complete / local-apply）
- `AGENTS.md` — パッケージ管理ポリシー
- `skills/local/win-host-setup/SKILL.md` — mise / winget の判断基準と落とし穴
