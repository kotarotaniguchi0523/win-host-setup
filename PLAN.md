# PLAN: Windows ホストのグローバル導入を mise に統一（セキュア）

> 対象: **Windows 本体のグローバル導入のみ**（リポジトリ/プロジェクトローカル、エディタ/ブラウザ拡張、**WSL 内部**は対象外）。
> 方針: **`AGENTS.md`**（Package Management Policy: msstore 優先 → mise/aqua の実効検証 → winget）。
> 監査: **`AUDIT.md`**。一覧: **`inventory.md`** / **`TODO-inventory.md`** / **`winget/host.dsc.yaml`**。
>
> 読み方: **上から「未完了（TODO）」→ 下に「アーカイブ（完了）」**。完了分は下部に同一見出しで移動。

---

# 未完了（TODO）

## 3. グローバル ツール（正確ピン＋lock）

**mise 管理 27 件**（内訳は下部 §3 アーカイブ参照）

- **既定 = 最新**（2026-10-15 変更）: `node = ["26.11.1", "24.21.0"]`（既定 **26.11.1**）/ `python = ["3.15.0", "3.14.8"]`（既定 **3.15.0**）。**配列は先頭が既定**（`mise which` で実測）
- **winget へ移行（2 件）**: `apm`（`pypi:apm-cli` は既定 3.15 で `pyyaml` の cp315 wheel が無く導入不可）/ `rust-analyzer`（aqua は `Security: [none]`）
- **追加**: `pypi:git+…/skillspector@v2.12.0`（Python 3.13.16 固定で導入成功）
- 全 27 ツールの「mise vs winget」判定は **`winget-vs-mise.md`**

- [ ] Go 固有: `gopls` の再導入（`go install golang.org/x/tools/gopls@latest`）

### 3.1 Git フック: `lefthook` → **`hk`**

- [ ] 各リポジトリで `lefthook.yml` → `hk.pkl`（`hk init` → `hk validate`）※**プロジェクトローカル作業** → **今回は保留**（対象 repo 未指定。`家計設計\sbx-setup` は `lefthook.yml` のまま）

## 9. ロールバック

- [ ] 失敗時の復旧手順を実地確認（`mise uninstall <tool>` → 旧導入で復旧）

## 10. 運用

- [ ] project config は `paranoid` の内容バインド承認（`mise trust`）
- [ ] 自動化は `MISE_SAFE=1`

---

# アーカイブ（完了）

## 1. mise 基盤

**内容**: Windows で mise を核に据え、グローバル PATH を通す。

- [x] `winget install jdx.mise`
- [x] **`%LOCALAPPDATA%\mise\shims` と mise bin を User PATH に追加** → `shims_on_path: yes`
- [x] `.cargo\bin` を PATH に追加（Rust）
- [x] `mise activate pwsh` 動作確認（`OneDrive\Documents\PowerShell\profile.ps1`）

## 2. セキュア設定（`~/.config/mise/config.toml`）

**内容**: `paranoid` / `locked` / `minimum_release_age` / `pin` を核に、検証を既定で有効化。

- [x] `paranoid = true`
- [x] `locked = true`（lockfile の URL のみ使用）
- [x] `locked_verify_provenance = true`（新規/再インストール時に再検証）
- [x] `minimum_release_age = "2d"`
- [x] `pin = true`
- [x] `[settings.npm] package_manager = "pnpm"`
- [x] `[env]` = Takumi Guard（`PIP_INDEX_URL` / `UV_INDEX_URL` / `NPM_CONFIG_REGISTRY`）
- [x] config バックアップ（`config.toml.bak-2026-10-15`）

## 3. グローバル ツール（正確ピン＋lock）

**内容**: 未固定（`"24"`/`"3.13"`）を正確版に置換し、lockfile で再現可能にする。
**mise 管理 27 件**: `betterleaks 1.9.0`（cosign）/ `node 26.11.1 / 24.21.0`（gpg）/ `npm 12.2.0`（**[none]**）/ `pnpm 12.12.1`（attestations）/ `python 3.15.0 / 3.14.8`（attestations）/ `gh 2.102.0`（attestations）/ `uv 0.13.0`（attestations）/ `go 1.27.2`（checksum）/ `jj 0.46.0` / `jq 1.8.2`（attestations）/ **`tgrep 1.2.0`**（aqua）/ **`ax 0.1.25`**（ubi, **[none]**）/ **`dotenvx 2.34.2`**（aqua）/ **`npm:secretlint 13.0.7`** / **`npm:textlint 15.8.0`** / **`npm:ctx7 0.6.0`**（Context7 CLI）/ **`rust 1.99.0`**（core:rust）/ `doppler 3.76.0` / `mo 1.5.5` / `waza 0.33.0` / `rtk 0.40.0` / **`nushell 0.116.1`**（aqua, checksum）/ **`npm:agent-browser 0.39.0`**（npm, integrity+provenance）/ **`herdr 0.9.3`**（aqua, **[none]**）/ **`pi 1.2.0`**（aqua, checksum）/ **`npm:openclaw 2026.10.3`**（npm, integrity+provenance）/ **`pypi:git+…/skillspector v2.12.0`**（git ソース, Python 3.13.16 固定）

> **winget へ移行（2026-10-15）**: `apm` → winget **`Microsoft.APM 0.33.0`**（Publisher: Microsoft Corporation）/ `rust-analyzer` → winget **`Rustlang.rust-analyzer 2026-10-12`**（aqua は `Security: [none]` のため）。判定は **`winget-vs-mise.md`**
> **既定バージョン**: `node` = `["26.11.1", "24.21.0"]` / `python` = `["3.15.0", "3.14.8"]`（**先頭が既定**。`mise which` で実測確認）

> **変更履歴**: `ripgrep`→**`tgrep`**、`hk` **バイナリごと削除**、`cloudflared`/`fd`→**winget**、**`rust` を rustup から mise へ**（旧 toolchain `stable` 削除・`~\.cargo\bin` を PATH から除去。**`~\.rustup` は mise が使用するため保持**）。
> **バイナリ系（mise 外の例外）**: `gopls`（`go install`／mise・winget・ubi いずれも不可）。
> **npm backend の検証（実測）**: mise の `Security:` は `[none]` 表示だが、**`~/.npmrc` の `registry=https://npm.flatt.tech/` 経由で pnpm が `dist.integrity`（sha512）を実効検証**（＝Takumi Guard 込み。`pnpm view agent-browser dist.tarball` = `npm.flatt.tech/...` で確認済）。`npm.package_manager = "pnpm"`。
> **逸脱**: `herdr` は aqua の `Security: [none]`（winget は preview のみ、npm は予約プレースホルダ `herdr@0.0.0`）→ **§14 に記録**。
> 一覧は `tools/tool-inventory.ps1` で生成（**ツール×実体バイナリ×backend×検証**）。

- [x] `[tools]` を正確ピン（`"24"`/`"3.13"` を排除）
- [x] **`mise lock --global`** → `mise.lock`
- [x] `mise install --locked` 成功
- [x] `mise prune --yes`（旧 `node 24.16.0` / `python 3.13.13` / `gh 2.92.0` 削除）
- [x] `mise tool <名>` の `Security:` 行を全件確認（`AUDIT.md §2`）

### 3.1 Git フック: `lefthook` → **`hk`**

**内容**: lefthook（winget）を hk（jdx 製・Rust）へ移行。`--mise` でフック実行に mise 環境を使う。

- [x] `[tools]` に `hk = "2.6.0"`
- [x] `hk install --global --mise` で動作確認（no-op 確認）→ **グローバル配線は撤去**（`~/.gitconfig` の `hook.hk-*` 4 件を削除）。以後は **repo ごとに `hk install`**（`hk.pkl` を置いた repo のみ）
- [x] winget 版 `lefthook` 撤去

### 3.2 Python（pip 由来）

**内容**: pip 134 は「134 ツール」ではなく **whisperx(93) + poetry(41) の 2 ツリー**。全削除して mise/uv へ。

- [x] **pip 134 件を全削除**
- [x] **Python 3.13 を winget/MSI で撤去** ＋ `%APPDATA%\Python`・PATH 除去
- [x] **pyenv-win 撤去**（`backup-pyenv-2026-10-15/` に退避）
- [x] グローバル Python は **mise `3.15.0`（既定）＋ `3.14.8`（併設）**（2026-10-15 変更。`3.15.0` は 2026-10-09 リリースでパッチ実績 0、`win_amd64` wheel は主要 24 パッケージ中 17/24）
- 参考: `whisperx` は `<3.14` 要求 → ASR プロジェクトは **3.13 を mise で併用**。`networkx` は `!=3.14.1` に注意。

## 4. 依存レーン（Takumi Guard）

**内容**: npm/pip を Takumi Guard 経由に。**トークン無しでも利用可**のため、既存のグローバル設定（mise `[env]`）で完了とする。

- [x] `[env]` に `npm.flatt.tech` / `pypi.flatt.tech` を設定済み（**トークンは任意**）
- [x] **User 環境変数にも配置**: `NPM_CONFIG_REGISTRY` / `UV_INDEX_URL` / `PIP_INDEX_URL` = flatt.tech（mise 非依存の全プロセスに適用）
- [x] **実測確認（2026-10-15）**: `~\.npmrc` = `registry=https://npm.flatt.tech/` ／ `pnpm view <pkg> dist.tarball` = `https://npm.flatt.tech/...` ／ mise `npm.package_manager = "pnpm"` → **mise の `npm:` backend も Takumi 経由で `dist.integrity`(sha512) を実効検証**（純粋 npm への切替は不要）。postinstall は未実行（`Ignored build scripts`）
- 参考: 代替として **Aikido safe-chain**（mise `npm:@aikidosec/safe-chain` で管理可、24h minimum age 内蔵）

## 5. APM / SkillSpector

**内容**: スキル／スキル資産のスキャナを導入。**APM は winget へ移行**（下記）。

- [x] 前提: `python` / `uv` を正確ピンで導入済み
- [x] **APM = winget `Microsoft.APM` 0.33.0**（Publisher: **Microsoft Corporation** / portable(zip) / `Installer SHA256`）→ 動作確認 `Agent Package Manager (APM) CLI version 0.33.0`
      - 当初 `pypi:apm-cli@0.33.0`（= `github.com/microsoft/apm` の**公式 PyPI 配布**。同一プロジェクトと確認済み）で導入したが、
        **既定 Python を 3.15.0 にした結果、依存 `pyyaml` の cp315 wheel が無く導入不可**となった
      - さらに mise は「不足ツールの自動導入」を全コマンドで試みるため、**1 ツールの導入失敗が `mise exec`／シム全体の停止（ハング）に波及**した（`git` の大量ハングは二次的）
      - → **winget へ移行して解消**（判定は `winget-vs-mise.md §3`）
- [x] **SkillSpector = mise `pypi:git+https://github.com/nvidia/skillspector.git@v2.12.0`**（PyPI 未公開のため git ソース）
      - 依存 `yara-python 4.5.4` は **cp314/cp315 の wheel が無い**ため、**このツールのみ Python 3.13.16**（`uvx_args = "--python 3.13.16"`）
      - 導入成功: 65 パッケージ / `skillspector==2.12.0 (git+…@c7958a3)` / `skillspector --help` 動作確認
- [x] `[settings.pypi] registry_url = "https://pypi.flatt.tech/simple/{}/"`（**pip も Takumi 経由**。Takumi の index は `upload-time` と `sha256` を返すため `minimum_release_age` も機能）
- [ ] **APM で管理予定のスキル（メモ）**: `agent-browser` / `ax` / `grill-with-docs`（旧 `~\.agents\skills` から削除済）
- [ ] グローバル Skill リポジトリ（別リポジトリ）で `apm.yml` + `apm.lock.yaml` ← **次段（リポジトリ管理の判断後）**

## 6. 撤去（野良/重複）

**内容**: 「移行 → 検証 → 撤去」の順で、野良・重複・残骸を除去。

- [x] **nvm-windows** 撤去（`C:\nvm4w`・`NVM_*` も除去）→ Node は mise
- [x] **npm -g**: 24 → **2**（`codex`/`opencode`）
- [x] **pnpm global `osgrep`** 削除
- [x] **Chocolatey**: `cloudflared`→**winget** / `ngrok`→**msstore** / `OpenSSL.Light`→**winget**、`make`・`maven`・`mkcert` 削除、**choco 本体も撤去**
- [x] **PATH 整理**: `node_mod` / `node_modules\npm` / nvm / 旧 OpenSSL を除去。`OpenSSL-Win64\bin` 追加
- [x] **手置き**: `~/.local\bin`（`claude.exe` 等）削除
- [x] **winget 重複**: `Betterleaks.Betterleaks`・`evilmartians.lefthook`・`Python.Launcher` 削除
- [x] **PowerShell**: MSI 削除 → MSIX 一本化

## 7. winget DSC ＋ Git 一元管理

**内容**: winget も宣言化（DSC）し、mise と合わせて Git 管理する。

- [x] **`winget/host.dsc.yaml`**（全バージョン固定 / ngrok は `source: msstore`）
- [x] **`winget configure -f winget/host.dsc.yaml`** → Configuration successfully applied（冪等）
- [x] **`winget/winget-export-baseline.json`** 保存
- 再現: `mise install --locked` ＋ `winget configure -f winget/host.dsc.yaml`

## 8. 検証

**内容**: 導入後に「どこから来たか（検証）」と「再現性」を確認する。

- [x] `mise doctor` → `shims_on_path: yes`
- [x] `where <tool>` が mise/winget を正しく指す（全ツール確認）
- [x] `mise tool <名>` の `Security:` 行（checksum/attestation/cosign/gpg/packslip）
- [x] `winget configure` の冪等再適用
- [x] **`apm audit --external skillspector`（2026-10-15）**: **動作確認**。事前に `apm experimental enable external-scanners` が必要
      - `[>] Scanning installed packages and deployed files...` → `[i] Running external scanner: skillspector` まで確認
      - **注意**: skillspector は LLM/重量依存（langchain/boto3 等 65 パッケージ）で**1 回 240 秒超**。完了させるには十分な時間が必要
- [x] **mise vs winget の全件判定**（`winget-vs-mise.md`。`rust-analyzer` と `apm` を winget へ移行）

## 9. ロールバック

**内容**: 失敗時に戻せるよう、変更前の状態を退避する。

- [x] `config.toml` バックアップ（`.bak-2026-10-15`）／`backup-pyenv-2026-10-15/`・`backup-removals-2026-10-15/`
- [x] 旧導入方法の控え（`inventory.md` / `AUDIT.md §7`）

## 10. 運用

**内容**: 今後の追加・更新・trust の手順。

- [x] 新ツール追加は `mise use -g <tool>@<正確版>` → `mise lock` → コミット
- [x] 更新は `minimum_release_age="2d"` を尊重

## 11. リポジトリ整理

**内容**: ユーザー配下 37 件を精査（`repos.md` / `repos-analysis.md`）。判定 KEEP 3 / REVIEW 28 / CANDIDATE 4 / EMPTY 2。

### Tier A: 安全に削除（完了）

- [x] `~\worktrees\refacotr`（空の誤字ディレクトリ）→ 削除
- [x] `~\worktrees\refactor\architecture`（683 MB / branch `refactor/architecture` は **remote に存在** / dirty は `.claude/settings.local.json` のみ）→ **`git worktree remove --force`**（設定は `backup-removals-2026-10-15/worktree-architecture/` に退避）→ **`~\worktrees` 自体を除去**
- （`.codex\.tmp\plugins-clone-*` の壊れた空クローンは **Codex 本体のキャッシュ**のため対象外）

### Tier B: remote なし＋未コミット（完了）

- [x] `~\Desktop\個人的開発物\ask-use-question-mcp`（dirty 149）→ **フルバックアップ**（`backup-removals-2026-10-15/ask-use-question-mcp`, 251 MB）→ 🗑 削除
- [x] `~\liff-flexmessage-test`（dirty 15）→ **バックアップ**（`backup-removals-2026-10-15/liff-flexmessage-test`, 0.8 MB：node_modules/.next 除外）→ 🗑 削除
- [x] `~\Desktop\家計設計` → **保持**（現在の作業ディレクトリ）

### Tier C: REVIEW（完了）

- [x] **25 件を削除（8.6 GB 解放）**: `search-novel` / `tutorial`(696 MB) / `%PROJECT_NAME%` / `dify` / `administorator-machine`(1.33 GB) / `mother-day` / `mem0` / `パターン認識と機械学習2025` / `音響音声処理` / `claudia` / `liff-gas-react` / `line-mcp` / `line-narrowcast-flexmessage-` / `laf-line-mini-app`(1.28 GB) / `my-processing-app` / `Awesome-GAS-project` / `liff-route-info` / `liff-hearing`(1.24 GB) / `taskmaster-kanban` / `laf-liff-app`(1.51 GB) / `blog` / `playwright-mcp` / `react` / `hono` / `claude-code-windows-setup`
- [x] 未コミット分は **patch 退避**（`backup-removals-2026-10-15/repos-tierC/*/{tracked.diff,untracked.txt,status.txt,head.txt}`）
- [x] **保持（除外）**: `~\.codex\vendor_imports\skills`（**Skills**）/ `~\.codex\.tmp\plugins*`（**plugins**）

### Tier D: KEEP（保持・操作不要）

- [x] `~\projects\fit-redesign-new`（2026-10-15）
- [x] `~\Desktop\家計設計\sbx-setup`（2026-10-13・remote あり）
- [x] `~\projects\fit-redesign`（2026-09-28）

## 12. ローカル整理（Temp / AI 設定 / キャッシュ / クラッシュダンプ）

**内容**: 「AI が作りがちな一時・設定ディレクトリ」と OS の一時ファイルを整理（**opencode / codex / Zed / ChatGPT(OpenAI) は除外**）。

- [x] **AI エージェント設定**: `.claude`(＋`.claude.json*`) / `.gemini`(282 MB) / `.serena`(1.28 GB) / `.copilot`(179 MB) / `.cursor-tutor` / `.mcp-auth` / `.mcp.json` / `claude-cli-nodejs`(109 MB) / `github-copilot`(73 MB) / `Goose`×2 / `com.example`
- [x] **Cursor 全削除**: `~\.cursor`(1.47 GB) / `%APPDATA%\Cursor`(6.43 GB) / `cursor-updater`(536 MB) ＋ **アプリ本体**（winget `Anysphere.Cursor`）をアンインストール
- [x] **Temp**: `sbx-both.tar`(10.1 GB) / `sbx-templates`(9.3 GB) / `DockerDesktopUpdates` / `wsl-crashes`(111 MB) / `mise`(105 MB) / `DockerDesktop`(538 MB)
- [x] **クラッシュダンプ/WER**: `%LOCALAPPDATA%\CrashDumps`(93 MB) ／ `C:\ProgramData\Microsoft\Windows\WER\{ReportArchive,ReportQueue,Temp}`(108 MB) ／ `C:\Windows\Minidump` ／ Desktop の `*.dmp`
- [x] 野良ディレクトリ `~\sample-liff-app`(72 MB) 削除
- [x] **Trae（AI IDE）全削除**: `~\.trae`(2,087 MB) / `~\.trae-aicc` / `%APPDATA%\Trae`(371 MB) ＝ **計 2,462 MB**
- [x] **curl\|sh 系の落下点**: `~\.local\bin`（空・障害なし）/ `~\.local\share\claude`(128 MB) / `~\.local\state\{claude,hk}` を削除
- [x] **`.bashrc` 整理**: 重複 `PATH`（3→1）と削除済 `task-master` エイリアスを除去（`.bashrc.bak-2026-10-15`）
- [x] **pnpm グローバルツールを mise へ**: `dotenvx`(aqua) / `secretlint`・`textlint`(mise `npm:`) ※誤って残骸と判定→復旧
- [x] **MAMP 撤去**（未使用）/ **Rust を mise 管理へ**（`rust 1.99.0` + `rust-analyzer`）
- [ ] `%TEMP%\FF26DB13-…`(356 MB)。**`swap.vhdx`（稼働中VMのスワップ）のため削除禁止**
- [x] `~\.local\share\containers`(4,982 MB)。**保持**（ユーザー判断により削除しない）
- [x] **Codex 一時/キャッシュ**: `~\.codex\.tmp`(125.6 MB, 中断クローン含む) / `~\.cache\codex-runtimes`(1,329.3 MB) を削除 ＝ **計 1,455 MB**（C: 空き 177.85 → **179.05 GB**）。**`~\.codex\plugins`(506 MB, `codex.exe` 318.6 MB 等の本体) と自作プラグイン `gakuchika-review`(2 か所) は保全**
- [x] **`~\.plugins` は存在しない**（実在は無ドットの `~\plugins` ＝自作 Codex プラグイン `gakuchika-review`。marketplace 本体は `~\.agents\plugins\marketplace.json` の "personal"）
- **除外（保持）**: `~\.codex`（Skills/plugins）／ `~\.agents\plugins`・`~\plugins`（自作プラグイン 2 か所）／ `%LOCALAPPDATA%\OpenAI`（ChatGPT）／ `%LOCALAPPDATA%\Zed` ／ `%TEMP%\opencode` ／ `~\.local\share\opencode`

## 13. バイナリ系（mise/winget 管理外）の一覧

**内容**: 「単体 .exe で配布されるもの」は mise/winget の外に落ちやすい（例: `ax`）。`tools/tool-inventory.ps1` で **ツール × 実体バイナリ × backend × 検証** を列挙する。

- [x] **mise で吸収**: `ax`（`ubi:`）/ `tgrep`（aqua）/ `dotenvx`（aqua）/ `gopls` は ubi 不可
- [x] **winget で吸収**: Git / Docker / sbx / cloudflared / openssl / fd / mise / Copilot CLI / Zed / VS Code(+Insiders) / Vrew / Delta / Meltype / ngrok(msstore)
- [x] **例外（確定）**: **`gopls`**（`go install` が唯一＝mise/ubi/winget 不可）→ 例外として記録（`~\go\bin\gopls.exe`, v0.23.0）
- [ ] **例外（移行可）**: **`Canva`**（手動導入・180 MB）→ winget `Canva.Canva` / msstore `XP8K17RNMM8MTN` に在る
- [x] **Rust を mise へ移行**: `rust 1.99.0` + `rust-analyzer`。旧 toolchain `stable` 削除（**1,153 MB 解放**）、`~\.cargo\bin` を PATH から除去。**`~\.rustup` は mise が使用（削除禁止）**。winget `Rustlang.Rustup` の uninstall は **`~\.rustup` を消す恐れ**があるため保留
- [x] **MAMP 撤去**: `C:\MAMP`（**1,959 MB**）削除 ＋ Machine PATH 2 件除去 ＋ ARP/スタートメニューのゴースト掃除

## 14. AI ツール / シェルの採用判断（2026-10-15）

**内容**: AI 時代のツールを **`AGENTS.md` の基準（① msstore → ② mise/aqua の実効検証 → ③ winget）**で選定。

- [x] **Nushell 0.116.1**（aqua）… `Security: checksum (sha256)` ＝ **基準②準拠**（winget は SHA256 のみで弱い）
- [x] **Pi 1.2.0**（aqua）… `checksum (sha256)` ＝ **準拠**
- [x] **OpenClaw**（**msstore** `9NFPR3BGDRR5`, 発行元 **OpenClaw Foundation**）… **基準①準拠**（実体は**トレイ GUI** `OpenClaw.Tray.WinUI.exe`。CLI は npm `openclaw@2026.10.3`）
- [x] **OpenClaw CLI 2026.10.3**（mise `npm:`）… 公式（`github.com/openclaw/openclaw`, author **OpenClaw Foundation**）・**Takumi 経由**（`npm.flatt.tech/openclaw/-/openclaw-2026.10.3.tgz`）・integrity 検証つき。msstore が GUI のみだったため CLI を追加（`OpenClaw 2026.10.3 (59cb447)`）
- [x] **herdr 0.9.3**（aqua）… ⚠️ **`Security: [none]` ＝ 基準②を満たさない**。winget は **preview のみ**、npm は**予約プレースホルダ**（`herdr@0.0.0`, 実体なし）→ やむを得ず aqua（**逸脱として記録**）
- [x] **agent-browser**（**aqua → `npm:` backend へ切替**）… npm 版は公式（`vercel-labs/agent-browser`）で **sha512 integrity + SLSA provenance** あり。mise 表示は `[none]` だが **pnpm が registry integrity を実効検証**
- [x] **ctx7 / secretlint / textlint**（npm backend）… 同上（integrity + provenance あり）
- [x] **Takumi Guard をグローバル化**: `UV_INDEX_URL` / `PIP_INDEX_URL` / `NPM_CONFIG_REGISTRY` を **User 環境変数**に設定（mise 非依存の全プロセスで Takumi 経由）
- [x] **`uv` を mise の Python へ寄せる**: `UV_PYTHON_PREFERENCE=system`
- [x] **不採用**: `crush` / `xonsh` / `murex` / `elvish` / PowerShell **AI Shell（2026-01 にアーカイブ）**
- [ ] **HerdrUI（`penso/herdr-gpui`）**: msstore/winget/mise **いずれも無し**。Herdr 本体とは**無関係の第三者**クライアント（署名+sha256 あり）→ **入れない**方針（TUI＋SSH で足りる）

---

## 未確定（要判断）

- ~~`github:microsoft/apm`（mise 直）と `pypi:apm-cli` の**どちらに一本化**するか~~ → **解決（2026-10-15）**: どちらも採らず **winget `Microsoft.APM 0.33.0`** に一本化（`pypi:apm-cli` は既定 Python 3.15 で `pyyaml` の cp315 wheel が無く導入不可のため）
- この **win-host-setup のドキュメント／設定をリポジトリ管理**するか（＝`~/.config/mise/config.toml` と `mise.lock` の扱い）
- **グローバル PATH の通し方**（mise shims → winget Links → Machine/User PATH の順序設計）
- **`paranoid` 最強のままか**（中間 `trusted_config_paths` を使うか）
