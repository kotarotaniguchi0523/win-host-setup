# migration-npm.md — npm / pnpm グローバルの mise 移行計画

> 対象: `inventory-npm-global.txt`（npm -g, 22 行）＋ `inventory-pnpm-global.txt` / `inventory.md §2`（pnpm global）。
> エンジン: **mise**（`2026.9.18 windows-x64`）＋ **Takumi Guard**（`NPM_CONFIG_REGISTRY=https://npm.flatt.tech/`）。
> 調査日: 2026-10-15 / **読み取り専用**（install/uninstall/変更なし）。
> 参照: `inventory.md §2,§7` / `PLAN.md §3,§6`。

## 0. 方法と前提（重要な発見）

- **mise の generic `npm:` backend は任意の npm パッケージに対応**する。レジストリ登録が無いパッケージでも **`mise use -g npm:<pkg>@<ver>`** で導入可能（実測: `npm:@google/clasp`, `npm:netlify-cli`, `npm:osgrep` 等で `ls-remote` 成功）。→ 「npm だから移行不可」というケースは **無い**。
- ただし **backend の質**には差がある。優先順位:
  1. **`aqua:` / `github:`**（ネイティブバイナリ ＝ Node ランタイム不要・provenance/attestation 検証可）… 最良
  2. **`npm:`（レジストリ略称あり）** … mise 管理だが Node 依存
  3. **`npm:`（generic）** … 実質「npm グローバルを mise 管理下に置く」だけ
  4. レジストリに無く dev/preview のみ → **npm グローバルを Takumi Guard のまま維持**
- mise の `ls-remote` 実測で確認した registry 略称:
  `codex aqua:openai/codex npm:@openai/codex` / `copilot aqua:github/copilot-cli github:github/copilot-cli npm:@github/copilot` /
  `gemini-cli npm:@google/gemini-cli` / `jules npm:@google/jules` / `devcontainer-cli npm:@devcontainers/cli` /
  `opencode aqua:anomalyco/opencode` / `pnpm aqua:pnpm/pnpm npm:pnpm` / `npm npm:npm` / `vercel npm:vercel` / `playwright npm:playwright`
- **pnpm global 一覧は収集失敗**（`inventory-pnpm-global.txt` = `ERROR: The configured global bin directory "C:\Users\%USERNAME%\AppData\Local\pnpm" is not in PATH`）。
  `inventory.md §2` と実体 `%LOCALAPPDATA%\pnpm\bin` から **直接導入は `osgrep` と `pnpm`** の 2 つのみ（`arrow2csv` などの実体は依存ツリーの残骸）。
- 前提: mise の `npm:` backend 実行には **mise 管理の node**（`config.toml` の `node`）が必要。Takumi Guard の `[env]` は維持。

## 1. npm -g（22 エントリ）

| # | package@version | これは何か | mise ネイティブ/レジストリ backend | 推奨移行 | 備考/リスク |
|---|---|---|---|---|---|
| 1 | `@aikidosec/safe-chain@1.1.10` | Aikido Safe Chain。npm/pip のインストール時に悪性パッケージを検知・ブロックするサプライチェーン防衛 CLI | **unclear**（レジストリ無し）。generic **`npm:`** は可 | **(a)** `mise use -g npm:@aikidosec/safe-chain@1.1.10` | **Takumi Guard と機能が重複**（Guard=レジストリ代理 / safe-chain=パッケージ検査）。両立は可だが運用重複を整理。セキュリティツールなので「動いている方」を正とする |
| 2 | `@devcontainers/cli@0.76.0` | Dev Containers CLI（`devcontainer`）。devcontainer.json の build/exec | **yes** — registry `devcontainer-cli` = **`npm:@devcontainers/cli`** | **(a)** `mise use -g devcontainer-cli@0.76.0` | 導入版 0.76.0 は古い（mise ls-remote 最新 0.89.0）。`minimum_release_age` 以内なら 1 つ前へピン |
| 3 | `@executeautomation/playwright-mcp-server@1.0.3` | Playwright をブラウザ自動化する **MCP サーバ** | **no**（レジストリ無し）。generic **`npm:`** 可 | **(b)** npm グローバル維持（Takumi Guard） | MCP は通常クライアント設定から **`npx -y` で都度起動**するため、そもそもグローバル導入が不要な可能性。絶対パス参照が無ければ **(d) 削除** も可 |
| 4 | `@github/copilot@0.0.372` | GitHub Copilot **CLI**（ターミナル用） | **yes** — registry `copilot` = **`aqua:github/copilot-cli` / `github:github/copilot-cli` / `npm:@github/copilot`** | **(a)** `mise use -g copilot@<pin>`（aqua ネイティブ） | ⚠️ aqua 版は別系列（実測 1.0.97 ＝新ネイティブ Copilot CLI）。npm パッケージ同一性を厳密に保つなら `npm:@github/copilot@0.0.372`。aqua 採用で **Node 不要** |
| 5 | `@google/clasp@2.4.2` | Google Apps Script CLI（`clasp`） | **no**（略称無し）。generic **`npm:`** 可 | **(a)** `mise use -g npm:@google/clasp@2.4.2` | レジストリ略称が無いだけで実質 npm グローバル。mise 一本化したい場合のみ。CSS/Google API の認証情報はユーザー領域に残る |
| 6 | `@google/gemini-cli@0.15.1` | Google Gemini CLI（`gemini`） | **yes** — registry `gemini-cli` = **`npm:@google/gemini-cli`** | **(a)** `mise use -g gemini-cli@0.15.1` | 導入版 0.15.1 はかなり古い（実測最新 0.64.0）。ピン更新を検討 |
| 7 | `@google/jules@`（**版なし＝破損**） | Google Jules CLI（非同期コーディングエージェント） | **yes** — registry `jules` = **`npm:@google/jules`** | **(a)** `mise use -g jules@<pin>`（入れ直し） | ⚠️ 現在の npm エントリは**バージョン欠落＝途中失敗の残骸**。移行時に旧残骸を **(d) 削除** |
| 8 | `@inkdropapp/ipm-cli@1.3.1` | Inkdrop プラグインマネージャ CLI（`ipm`） | **no**。generic **`npm:`** 可 | **(a)** `mise use -g npm:@inkdropapp/ipm-cli@1.3.1` | `PLAN.md` 記載の「最 demanding な Node 下限 = >=24」の対象。Node 26 で問題なし |
| 9 | `@inkdropapp/mcp-server@1.1.1` | Inkdrop の **MCP サーバ** | **no**。generic **`npm:`** 可 | **(b)** npm グローバル維持 | #3 と同様、MCP は `npx` 起動なら不要 → 参照確認の上 **(d) 削除** も可 |
| 10 | `@line/liff-cli@0.4.1` | LINE LIFF CLI（LIFF アプリの scaffold/deploy） | **no**。generic **`npm:`** 可 | **(a)** `mise use -g npm:@line/liff-cli@0.4.1` | 実測最新 0.1.x 系の `ls-remote`（0.1.0…）と導入版 0.4.1 の整合を要確認 |
| 11 | `@openai/codex@0.162.1` | OpenAI Codex CLI（Rust 製コーディングエージェント） | **yes** — registry `codex` = **`aqua:openai/codex` / `npm:@openai/codex`** | **(a)** `mise use -g codex@0.162.1`（aqua ネイティブ） | aqua 採用で **Node 不要・checksum/attestation 検証可**。導入版 = 実測最新 0.162.1 と一致 |
| 12 | `@opencode/cli@2.0.27` | OpenCode CLI（本エージェント基盤） | **yes** — registry `opencode` = **`aqua:anomalyco/opencode`** | **(a)** `mise use -g opencode@2.0.27` | ⚠️ **実行中のハーネス自身**。移行は自己更新を伴うため「移行→検証→旧削除」の順を厳守。実測最新 2.0.28 |
| 13 | `@typescript/native-preview@7.0.0-dev.20250816.1` | TypeScript ネイティブ（Go 移植）プレビュー `tsgo` | **no**（レジストリ無し）。generic `npm:` の **`ls-remote` は空**（prerelease を列挙不可） | **(b)** npm グローバル維持（Takumi Guard） | dev スナップショット（`7.0.0-dev.*`）で **mise ピン不可**。安定版が出るまで npm 維持が妥当 |
| 14 | `codex@`（**版なし＝破損**） | `@openai/codex` の重複/失敗残骸 | n/a | **(d) 削除** | #11 と重複。`npm rm -g codex` |
| 15 | `dev3000@0.0.59` | dev3000。Next.js 等の開発時にブラウザ/サーバログ・スクショをエージェントへ渡す dev ツール | **no**。generic **`npm:`** 可 | **(a)** `mise use -g npm:dev3000@0.0.59` | 開発補助。使わなくなれば **(d) 削除** |
| 16 | `netlify-cli@22.1.3` | Netlify CLI（`netlify`） | **no**（`netlify-cli` はレジストリ未登録）。generic **`npm:`** 可 | **(a)** `mise use -g npm:netlify-cli@22.1.3` | 導入版 22.1.3 は最新系より大幅に古い。更新可否を別途判断 |
| 17 | `notion@0.1.0` → **symlink `..\Windows\system32\mcp-notion-server\notion`** | 古い `notion` npm パッケージ＋**手動ジャンクション** | **no**（`notion` はレジストリ未登録）。generic `npm:` は同パッケージ名だが**無関係の旧パッケージ** | **(d) 削除/要調査** | ⚠️ **要注意**: `C:\Windows\System32\mcp-notion-server\` へのリンク。実体（MCP Notion サーバ）の出所不明。実体を確認してから削除。放置は PATH/セキュリティ上のリスク |
| 18 | `npm@11.13.0` | npm 本体 | **yes** — registry `npm` = **`npm:npm`** | **(d) 削除** | **mise の node が npm を同梱**（shim に `npm`/`npx` あり）。グローバル npm は二重管理。mise node の npm に一本化 |
| 19 | `pnpm@10.17.1` | pnpm（高速パッケージマネージャ） | **yes** — registry `pnpm` = **`aqua:pnpm/pnpm` / `npm:pnpm`** | **(a)** `mise use -g pnpm@<pin>`（aqua ネイティブ） | `config.toml` の `[settings.npm] package_manager="pnpm"` と整合。導入版 10.17.1 は実測最新 12.x より古い。`corepack` shim との役割整理 |
| 20 | `task-master-ai@0.31.1` | Task Master AI。AI コーディング用のタスク管理 CLI/サーバ | **no**。generic **`npm:`** 可 | **(a)** `mise use -g npm:task-master-ai@0.31.1` | 実測 `ls-remote` は 0.9.5… のみ表示（0.31.1 との整合は要確認） |
| 21 | `typescript@5.7.3` | TypeScript コンパイラ（`tsc`, `tsserver`） | **no**（略称無し）。generic **`npm:typescript`** は可 | **(d) 削除**（原則プロジェクトローカル） | グローバル `tsc` はプロジェクト版と衝突しやすい。各リポジトリの devDependency へ。どうしてもグローバルが必要なら `mise use -g npm:typescript@5.7.3` |
| 22 | `vercel@45.0.9` | Vercel CLI（`vercel`） | **yes** — registry `vercel` = **`npm:vercel`** | **(a)** `mise use -g vercel@45.0.9` | 最新は実測 64.x。更新方針を別途判断 |

## 2. pnpm global（収集失敗のため `inventory.md §2` ＋ 実体から復元）

`inventory-pnpm-global.txt` は PATH 未通過エラーで失敗。実体 `%LOCALAPPDATA%\pnpm\bin` と `inventory.md §2` より、**直接導入は 2 件**（他は依存ツリー）。

| # | package@version | これは何か | mise ネイティブ/レジストリ backend | 推奨移行 | 備考/リスク |
|---|---|---|---|---|---|
| P1 | `osgrep`（版不明） | ローカル埋め込み（LanceDB）による**セマンティックコード検索** CLI | **no**（レジストリ未登録）。generic **`npm:osgrep`** は可 | **(a)** `mise use -g npm:osgrep@<pin>`（採用時） | 依存ツリーが巨大（`@huggingface/transformers, @lancedb, @swc, sharp, @protobufjs` …）。**未使用なら `pnpm rm -g osgrep`（= (d)）** が最も効果的 |
| P2 | `pnpm`（版不明） | pnpm 本体（npm -g 版 #19 と重複の可能性） | **yes** — registry `pnpm` = **`aqua:pnpm/pnpm` / `npm:pnpm`** | **(a)** `mise use -g pnpm@<pin>` | #19 と同一ツール。**二重導入（npm -g と pnpm global）を一本化**。`%LOCALAPPDATA%\pnpm\bin` の `arrow2csv` 等は依存残骸 |

> 注: `%LOCALAPPDATA%\pnpm` 配下に `global\5` と `global\v11` が併存（旧 pnpm の残骸）。撤去時に整理。

## 3. 集計（推奨バケット）

| バケット | 件数 | 内容 |
|---|---|---|
| **(a) mise へ移行** | **16** | #1,2,4,5,6,7,8,10,11,12,15,16,19,20,22 ＋ `osgrep`（pnpm）。うち **aqua/github ネイティブ = 4**（copilot, codex, opencode, pnpm）＋ **npm レジストリ略称 = 4**（devcontainer-cli, gemini-cli, jules, vercel）、残りは generic `npm:` |
| **(b) npm グローバル維持（Takumi Guard）** | **3** | `@typescript/native-preview`（dev スナップショット）, `@executeautomation/playwright-mcp-server`, `@inkdropapp/mcp-server`（MCP は `npx` 起動なら削除可） |
| **(c) winget へ** | **0** | npm/pnpm 由来で winget が適切なものは無し（Windows 専用ソフトは `inventory.md §2` の winget 群が担当） |
| **(d) 削除** | **4** | `codex`（重複残骸）, `notion`（system32 への不可解な symlink）, `npm`（mise node 同梱へ一本化）, `typescript`（プロジェクトローカルへ） |
| 合計（重複統合後のユニーク） | **23** | npm -g 22 ＋ pnpm `osgrep`（`pnpm` は #19 と同一） |

## 4. 実施順序（推奨）

1. `config.toml` をバックアップ（`PLAN.md §9`）。
2. **aqua/github ネイティブ優先**で (a) を導入:
   `mise use -g codex@0.162.1 pnpm@<pin> opencode@2.0.27 copilot@<pin>`（Node 不要・attestation 検証）。
3. 続けて npm レジストリ略称: `devcontainer-cli`, `gemini-cli`, `jules`, `vercel`。
4. **Takumi Guard 検証後に generic `npm:`** を導入（`clasp, ipm-cli, liff-cli, dev3000, netlify-cli, task-master-ai, safe-chain, osgrep`）。
5. `mise lock` → `mise install --locked`（`PLAN.md §3`）。
6. 動作確認後、**(d) を撤去**: `npm rm -g codex notion npm typescript`（`notion` は実体確認を先に）。
7. (b) の 3 件は npm グローバル維持。MCP 2 件は参照設定を確認し、`npx` 起動なら追加で削除。

## 5. リスク・注意（横断）

- **Takumi Guard との競合/重複**: `@aikidosec/safe-chain` は Guard と役割が重複。二重でインストール妨害（false positive）を起こさないか検証。
- **`notion` symlink は最優先で調査**: `C:\Windows\System32\mcp-notion-server\` は通常の npm 配置ではない。マルウェア/手動設定の可能性を含め実体を確認。
- **破損エントリ**（`@google/jules@`, `codex@`）は「移行（再導入）→ 旧残骸削除」を厳守。
- **openode/opencode 等の自己参照ツール**はアップデートで現行プロセスが落ちうる。新シェルで検証。
- **version 整合**: 導入版が mise の `minimum_release_age` より新しい場合、mise が 1 つ前のパッチへピンする（実測で copilot/opencode/vercel に警告）。`PLAN.md §3` の注意書きどおり。
- **generic `npm:` は Node 依存**: mise の node が落ちると全 (a) generic が停止。aqua ネイティブ（Node 不要）を優先する理由。
- **pnpm 収集失敗**の根本原因（`C:\Users\%USERNAME%\AppData\Local\pnpm` が PATH 未通過）は `PLAN.md §1` の shims PATH 整理と併せて解消。
