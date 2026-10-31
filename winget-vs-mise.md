# winget vs mise 監査（mise 管理 全 28 ツール）

**目的**: mise 管理下の全ツールについて、**これまでの基準（① msstore 公式 → ② mise/aqua の実効検証 → ③ winget）** を適用し、
「**winget のほうが検証が強いか**」を 1 件ずつ判定して、切替の可否を明示する。

- **作成日**: 2026-10-15（データは同日取得: `mise tool` / `winget show` / `winget search`）
- **判定基準**: `AGENTS.md` Package Management Policy、`AUDIT.md §2`
- **生データ**: `winget-search-raw.txt`（winget 全候補）、`mise-security.json`（mise 側 backend・Security）

---

## 0. 比較の原理

| 軸 | mise | winget |
|---|---|---|
| ハッシュ検証 | backend 依存（`checksum (sha256)` / `attestations` / `cosign` / **`[none]`**） | マニフェストの **`Installer SHA256` 固定**（winget-pkgs の CI が実物と突合） |
| 発行元の裏付け | aqua なら **SLSA provenance / GitHub attestations / cosign 署名** | マニフェストの `Publisher` フィールド（**署名検証ではない**） |
| 版の固定 | `pin=true` ＋ `mise.lock`（checksum 付き・再現可能） | マニフェストの版（**古い版は削除される**） |
| 差し替え耐性 | vendor の checksums を取得（vendor CDN と同一経路） | **vendor とは独立した固定ハッシュ** |
| 追加統制 | なし（backend 次第で provenance） | なし |
| 追加スキャン（サプライチェーン） | **Takumi Guard 経由**（npm/pypi の全取得） | なし |

**結論（原理）**:
- **mise が `checksum` / `attestations` / `cosign` を持つ場合は mise が上位**（provenance はマニフェスト hash より強い）。
- **mise が `[none]` かつ winget に同一ツール（同一版）がある場合は winget が上位** → 切替。
- **`[none]` でも実効検証があるケースがある**（下記 §2 の注記: pypi の uv 依存グラフ / npm の registry integrity）。

---

## 1. 判定規則

| 記号 | 意味 |
|---|---|
| **mise 上位** | mise の検証が winget より強い（provenance / 署名 / 粒度） |
| **同等** | どちらも固定ハッシュ相当。mise は「版固定＋lock」で優位 → **mise 継続** |
| **winget 上位 → 切替** | mise が `[none]` で winget に同一版がある → **winget へ移す** |
| **例外** | winget に存在しない／不適（preview のみ・非公式・競合）→ **mise 継続＋記録** |

---

## 2. 全ツール判定表（29 件）

`mise の検証` は `mise tool` の `Security:` 行。`winget の検証` はマニフェストの `Installer SHA256`。

| # | ツール | mise 版 | mise backend | **mise の検証** | winget ID | winget 版 | **判定** |
|---|---|---|---|---|---|---|---|
| 1 | betterleaks | 1.9.0 | aqua:betterleaks/betterleaks | **checksum + cosign** | `Betterleaks.Betterleaks` | 1.9.0 | **mise 上位**（cosign 署名） |
| 2 | node | 26.11.1 / 24.21.0 | core:node | **checksum + gpg** | `OpenJS.NodeJS` | **26.8.1**（古い） | **mise 上位**（GPG＋版が新しい） |
| 3 | python | 3.15.0 / 3.14.8 | core:python | **checksum + github_attestations** | `Python.Python.3.14` = 3.14.7 / **3.15 は winget に無い** | 3.14.7 | **mise 上位**（attestations＋版が新しい） |
| 4 | gh | 2.102.0 | aqua:cli/cli | **checksum + github_attestations** | `GitHub.cli` | 2.102.0 | **mise 上位**（attestations） |
| 5 | doppler | 3.76.0 | github:DopplerHQ/cli | checksum | `Doppler.doppler` | **3.77.0**（新しい） | **同等** → mise 継続（版上げは任意） |
| 6 | apm | 0.33.0 | pypi:apm-cli | 表示 `[none]`／**実効: `uv.lock` に sha256 1,504 行** ＋Takumi | `Microsoft.APM` | 0.33.0 | **同等**（粒度は mise が上・発行元明示は winget）→ **mise 継続**（**2026-10-15 に winget へ移行済み。現在 0.35.0 → §10.3**） |
| 7 | mo | 1.5.5 | aqua:k1LoW/mo | checksum | **なし** | — | **例外**（winget に無い） |
| 8 | waza | 0.33.0 | github:microsoft/waza | checksum | **なし** | — | **例外** |
| 9 | rtk | **0.40.0** | aqua:rtk-ai/rtk | checksum | `rtk-ai.rtk` | v0.50.0 | **同等** → mise 継続。**ただし現行 0.40.0 が古い（最新 0.51.0）→ 版上げ推奨** |
| 10 | pnpm | 12.12.1 | aqua:pnpm/pnpm | **github_attestations** | `pnpm.pnpm` | 12.11.2 | **mise 上位** |
| 11 | uv | 0.13.0 | aqua:astral-sh/uv | **checksum + github_attestations** | `astral-sh.uv` | 0.13.1 | **mise 上位** |
| 12 | go | 1.27.2 | core:go | checksum | `GoLang.Go` | 1.27.0 | **mise 上位** |
| 13 | jj | 0.46.0 | aqua:jj-vcs/jj | checksum | `jj-vcs.jj` | 0.45.1 | **mise 上位** |
| 14 | jq | 1.8.2 | aqua:jqlang/jq | **checksum + github_attestations** | `jqlang.jq` | 1.8.2 | **mise 上位** |
| 15 | tgrep | 1.2.0 | aqua:microsoft/tgrep | checksum | **なし** | — | **例外** |
| 16 | ax | 0.1.25 | ubi:yusukebe/ax | **`[none]`** | **なし**（`yusukebe` 該当なし） | — | **例外**（winget 無し） |
| 17 | dotenvx | 2.34.2 | aqua:dotenvx/dotenvx | checksum | `dotenvx.dotenvx` | **2.36.0**（新しい） | **同等** → mise 継続 |
| 18 | npm:secretlint | 13.0.7 | npm:secretlint | 表示 `[none]`／**実効: registry integrity + SLSA provenance** | **なし** | — | **例外** |
| 19 | npm:textlint | 15.8.0 | npm:textlint | 同上 | **なし** | — | **例外** |
| 20 | npm:ctx7 | 0.6.0 | npm:ctx7 | 同上 | **なし** | — | **例外** |
| 21 | nushell | 0.116.1 | aqua:nushell/nushell | checksum | `Nushell.Nushell` | 0.116.1 | **同等** → mise 継続 |
| 22 | npm:agent-browser | 0.39.0 | npm:agent-browser | 実効 registry integrity + provenance | **なし** | — | **例外** |
| 23 | npm:openclaw | 2026.10.3 | npm:openclaw | 実効 registry integrity + provenance | msstore `9NFPR3BGDRR5` は **GUI のみ**（CLI は無い） | — | **例外**（`360.NamiClaw` は類似名のため回避） |
| 24 | herdr | 0.9.3 | aqua:herdrdev/herdr | **`[none]`** | `Herdr.Herdr.Preview`（0.9.4-preview）／`hdosys.herdr-win`（**非公式** "Herdr Extended"） | preview | **例外**（stable が winget に無い。非公式は除外） |
| 25 | pi | 1.2.0 | aqua:earendil-works/pi | checksum | `EarendilWorks.pi` | 1.2.0 | **同等** → mise 継続 |
| 26 | rust | 1.99.0 | core:rust（rustup） | 表示 `[none]`（**rustup 自身が component を検証**） | `Rustlang.Rustup` 1.29.1 / `Rustlang.Rust.GNU` 1.99.0 | — | **例外**（winget 版は `~\.rustup` を消す恐れ・ツールチェーン前提が違う） |
| 27 | rust-analyzer | 2026-10-12 | aqua:rust-lang/rust-analyzer | **`[none]`** | **`Rustlang.rust-analyzer`**（Publisher: The Rust Project Developers, portable zip, SHA256） | **2026-10-12（同一）** | **winget 上位 → 切替** ✅ |
| 28 | npm | 12.2.0 | npm:npm | **`[none]`** | **なし**（単体 npm は存在せず `OpenJS.NodeJS` に同梱） | — | **例外** |
| 29 | diff-tour | 0.5.0 | github:init-co-jp/diff-tour | **checksum (sha256)**（release の `checksums.txt` を照合） | **なし** | — | **例外**（winget に無い。aqua/ubi/go backend は `[none]` のため `github:` を採用） |

### 重要な注記
- **`pypi:` の `[none]` は「無検証」ではない**。`mise lock` が **依存グラフ（`locks/pypi-*/**/uv.lock`）に wheel ハッシュを記録**し、`--frozen` で再現する（`apm-cli` は **sha256 1,504 行**）。表示だけが `[none]`。
- 同様に **`npm:` の `[none]` も「無検証」ではない**。npm パッケージは `dist.integrity`（sha512）と **SLSA provenance** を持ち、mise の pnpm が registry integrity を**実効検証**する。加えて **Takumi Guard 経由**。
- **winget の `Installer SHA256` は vendor 非依存**で強いが、**マニフェストはコミュニティ管理**であり、provenance（SLSA）ほど強くはない。

---

## 3. 切替を実施（winget が明確に上位）

| ツール | 変更 | 理由 | 結果 |
|---|---|---|---|
| **rust-analyzer** | `aqua:rust-lang/rust-analyzer 2026-10-12`（`[none]`）→ **winget `Rustlang.rust-analyzer` 2026-10-12** | **同一版**で、winget 側は **`Installer SHA256` 固定＋発行元 "The Rust Project Developers"**。aqua 側は検証なし | ✅ `rust-analyzer 0.3.3081-standalone (2ad81e72b7 2026-10-11)` / `…\WinGet\Packages\Rustlang.rust-analyzer_…\rust-analyzer.exe` |
| **apm**（追加） | `pypi:apm-cli 0.33.0` → **winget `Microsoft.APM` 0.33.0** | **既定 Python を 3.15.0 にした結果、依存 `pyyaml` の cp315 wheel が無く `pypi:` では導入不可**（`mise` が自動導入を試みて全コマンドが停止する障害になった）。winget 版は **Publisher: Microsoft Corporation** / portable(zip) / `Installer SHA256` | ✅ `Agent Package Manager (APM) CLI version 0.33.0`（**現在 0.35.0** → §10.3） |

実行済みコマンド:
```powershell
winget install --id Rustlang.rust-analyzer --exact --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.APM          --exact --accept-package-agreements --accept-source-agreements
mise uninstall rust-analyzer --all          # + config から削除 / installs と シムを撤去
mise prune --yes                            # pypi:apm-cli を撤去
```

> **注**: `rust-analyzer` は mise のシムが残ると winget 版を隠すため、**`mise\shims\rust-analyzer.exe` の削除**と `mise\installs\rust-analyzer` の削除まで行って完了。

---

## 4. 例外（winget に無い／不適 → mise 継続・記録）

| ツール | 理由 |
|---|---|
| mo / waza / tgrep | winget にパッケージが無い |
| ax / secretlint / textlint / ctx7 / agent-browser | winget に無い（npm は registry integrity＋provenance で実効検証あり） |
| openclaw(CLI) | winget に無い（msstore は GUI のみ）。`360.NamiClaw` は類似名のため回避 |
| herdr | winget は **preview のみ**＋非公式派生のみ。stable 0.9.3 の `[none]` は**逸脱として記録** |
| rust | winget 経路は `~\.rustup` を消す恐れ。rustup が component を検証 |
| npm | 単体 npm は winget に無い（Node 同梱） |
| mo / waza / tgrep | GitHub/aqua の checksum 付きで継続 |

---

## 5. 参考: winget 側の版が「新しい」もの（版上げ候補）

| ツール | 現行 | 最新 | 備考 |
|---|---|---|---|
| rtk | 0.40.0 | **0.51.0**（mise）／0.50.0（winget） | **mise で 0.51.0 へ上げるのが妥当**（11 版遅れ） |
| doppler | 3.76.0 | 3.77.0 | 任意 |
| dotenvx | 2.34.2 | 2.36.0 | 任意 |

---

## 6. 結論

- **winget へ移したものは 2 件: `rust-analyzer`（検証が winget 上位）と `apm`（pypi が既定 Python 3.15 と両立不能）**。それ以外は mise が同等以上。
- `pypi:` / `npm:` の `Security: [none]` は**表示上のもの**で、実際は wheel ハッシュ／registry integrity＋provenance で検証されている（＋Takumi）。
- **winget は「mise が検証を持たない／mise で導入できない場合の受け皿」**として機能する。
- `herdr` のみ「どこにも stable が無い」ため、**唯一の継続的な逸脱**として記録する。
- **重要な実測知見**: 既定 Python を **3.15.0** にすると、**cp315 wheel が無い依存（`pyyaml` 等）を持つ Python ツールは `pypi:` で導入できない**。しかも mise は「不足ツールの自動導入」を全コマンドで試みるため、**1 ツールの導入失敗が全 mise コマンドの停止（ハング）に波及**する。→ Python ツールは **winget へ逃がす**か、**wheel のある 3.14 を明示**するのが安全。

---

## 7. 追加分の判定（2026-10-15 追記）

### 7.1 `waza`（Agent Skills の評価 CLI / Microsoft）

| 経路 | 実測 |
|---|---|
| ① msstore | **なし**（`winget search waza --source msstore`） |
| ② mise | ✅ **`github:microsoft/waza`** — `Security: checksum (sha256)` |
| ③ winget | **なし**（`winget search waza --source winget`） |

**判定: ② mise が唯一の経路かつ検証あり → 準拠** ✅
**実施**: `0.33.0` → **`0.38.10`** へ更新（`github:microsoft/waza`、`waza version 0.38.10`）。winget/msstore に無いため代替は存在しない。

> Waza は `adversarial` / `check` / `coverage` / `gate` / `quality` / `replay` など **Skill の評価・回帰ゲート**を持つため、Skills の CI 監査に併用できる。

### 7.2 `skillspector`（Skill のセキュリティスキャナ / NVIDIA）

| 経路 | 実測 |
|---|---|
| ① msstore | **なし** |
| ② mise | **`pypi:git+https://github.com/nvidia/skillspector.git@v2.12.0`** — `Security: [none]` ⚠️ |
| ③ winget | **なし** |

**判定: mise が唯一の経路。`[none]` のため正確には ② を満たさない → 逸脱として記録**（PyPI 未公開のため git 固定のみ。タグ `v2.12.0` で不変性を保証し、依存は Takumi 経由）。

### 7.3 Skills（`agent-browser` / `ax`）: APM 経由

| 対象 | 入手方法 | 検証 |
|---|---|---|
| `vercel-labs/agent-browser` | **APM**（`skills/apm.yml` に `#v0.39.1`） | ✅ `apm.lock.yaml` に **resolved_commit（SHA）+ 展開ファイルごとの sha256** |
| `yusukebe/ax` | **APM**（`#v0.1.25`） | ✅ 同上（`resolved_commit` + `deployed_file_hashes`） |

**判定: パッケージマネージャ経路（msstore/winget）は存在しないため APM が唯一。タグ + commit SHA + ファイルハッシュで検証できる点で準拠** ✅
（Renovate の `apm` マネージャが `owner/repo#ref` を自動更新する）

---

## 8. 追加分の判定（2026-10-18 追記）

### 8.1 `t3`（T3 Code CLI / pingdotgg/t3code）

| 経路 | 実測 |
|---|---|
| ① msstore | **なし**（`winget search --source msstore t3` は無関係の `T3` のみ） |
| ② mise | ✅ **`npm:t3` 0.1.0** — 表示は `[none]` だが **registry integrity（sha512）＋ SLSA provenance**（`@t3code/t3-win32-x64` 側にも attestation）。実体は optionalDependencies で postinstall 不要 |
| ③ winget | **CLI は無し**（winget にあるのはデスクトップアプリ `T3Tools.T3Code` のみ） |

**判定: ② mise 採用（基準②準拠）** ✅
**実施**: `mise/mise.toml` に `"npm:t3" = "0.1.0"`、`mise lock --global` で lock 更新、`mise install npm:t3` → **`t3 v0.1.0`**（shim `%LOCALAPPDATA%\mise\shims\t3.exe`）。
**更新**: mise（`mise.toml` の版上げ → `mise lock --global`）で行う。**`t3 update` は使わない**（mise のピン外へ独自ランタイムを入れて drift する）。
**Windows 制約（実測）**: `t3 service`（常駐）は **Linux/macOS のみ** → `unavailable on this machine`。

## 9. GUI アプリ（mise 対象外）: T3 Code デスクトップ

| 対象 | 実測 |
|---|---|
| インストール実体 | **T3 Code (Beta) 0.1.0**（Publisher: T3 Tools / `%LOCALAPPDATA%\Programs\t3code` / 非管理者・ユーザー単位） |
| winget マニフェスト | **`T3Tools.T3Code` 0.0.45**（Release Date 2026-10-02）— **本体 0.1.0 より遅れ** |
| 更新方式 | デスクトップアプリが**自己更新**（公式サイト / GitHub Releases のビルドと同じ） |

**判定: `winget/host.dsc.yaml` にはピンしない（例外として記録）**。
- winget の版（0.0.45）で固定すると、自己更新済みの 0.1.0 から **ダウングレード**しかねない。
- アプリが自己更新するため、`Installer SHA256` による固定は意味を持たない。
- → CLI は §8.1 の mise 管理、**GUI は例外**として本節に実体版（0.1.0）と入手経路（公式サイト / GitHub Releases）を記録する。

### 9.1 sbx（Docker Sandboxes）連携

- T3 Code に sbx 専用統合は無く、**sbx を SSH ホストとして扱う**（Docker 公式 "Connect T3 Code to a sandbox"）。
- ホスト側: **`sbx setup ssh`** を1回実行（`~/.ssh/config` に managed Include、`Host *.sbx` の ProxyCommand は `sbx.exe ssh proxy %n`。**`sh` 不要**）。
- サンドボックス側: **追加導入は不要**（実測: `common-opencode:dev` に python3 3.14.4 / g++ 15.2 / make / Node 24.21.0 / curl / tar / sha256sum / shasum / git / libatomic1 / libstdc++ / libgcc_s が既存）。
- SSH 環境の追加は **デスクトップアプリの Settings → Connections → Add environment → SSH**（**Web UI には SSH 追加 UI が無い**）。プロバイダは**環境ごと**に設定する。
- Docker Hub の `hambn/t3code`（`t3 serve` が entrypoint の非公式イメージ）は **sbx テンプレートには不向き**（sbx は `tini --` ＋ エージェント起動の独自テンプレート前提）。

---

## 10. 追加分の判定（2026-10-31 追記）: ctx7 / agent-desktop / APM

### 10.1 `ctx7`（Context7 CLI / Upstash）

| 経路 | 実測 |
|---|---|
| ① msstore | **なし** |
| ② mise | ✅ **`npm:ctx7` 0.8.2**（導入済み・`ctx7 --version` = 0.8.2）。`Security:` は `[none]` 表示だが **registry integrity（sha512）を pnpm が実効検証**（`dist.integrity` あり）。**`dist.attestations` は未公開**（provenance 無し） |
| ③ winget | **なし**（`winget search ctx7` 該当なし） |

**判定: ② mise 採用（基準②準拠。ただし検証は integrity のみで provenance は無し）** ✅
**実施**: **宣言済みのため変更なし**（`mise/mise.toml` の `"npm:ctx7" = "0.8.2"`）。
**注意**: 公式手順の **`npx ctx7 setup` / `npm install -g ctx7` は使わない**（mise のピン外に実体ができる＝野良グローバル）。更新は `mise.toml` の版上げ → relock。
**要件**: Node.js **≥ 22.13**（ホストは `node 26.12.1` が既定）。postinstall は無いため `allow_builds` 不要。

### 10.2 `agent-desktop`（vercel-labs / Apache-2.0）

| 経路 | 実測 |
|---|---|
| ① msstore | **なし** |
| ② mise | ✅ **`npm:agent-desktop` 1.0.2** — **registry integrity（sha512）+ SLSA provenance**（`dist.attestations.provenance = slsa.dev/provenance/v1`）。パッケージは**全プラットフォームの実バイナリ同梱**（unpacked 29.5 MB）で、`postinstall: node scripts/postinstall.js` が `bin/agent-desktop-win32-x64.exe` を link する |
| ③ winget | **なし**（v1.0.0 は 2026-10-28 公開の新規プロジェクト） |
| （参考）GitHub Releases | zip/tar のアーカイブはあるが**管理下に置けない**（更新検知・ハッシュ固定が手作業になる）ため不採用 |

**判定: ② mise 採用（基準②準拠）** ✅
**実施**: `mise/mise.toml` に **`"npm:agent-desktop" = { version = "1.0.2", allow_builds = ["agent-desktop"] }`** → `tools/ci/mise-verify.ps1 -Lock` で relock（`mise.lock` の `[[tools.*]]` ヘッダは 1 件追加のみ・欠落なし）→ `tools/apply.ps1`（**39/39 installed**）。
**実測**: `mise which agent-desktop` → `%LOCALAPPDATA%\mise\installs\npm-agent-desktop\1.0.2\node_modules\.bin\agent-desktop`、`agent-desktop version` → `{"version":"2.5","ok":true,"command":"version","data":{"os":"windows","target":"x86_64","version":"1.0.2"}}`。
**`allow_builds` が必要な理由**: mise は既定で dependency の build script を実行しない。`agent-desktop` は postinstall で**実バイナリを link するだけ**（ダウンロードはしない＝パッケージ同梱）だが、link しないと Node ランチャー経由になる。installer 非依存の `allow_builds` で許可する（pnpm → `--allow-build=agent-desktop`）。
**`minimum_release_age = "2d"` との関係（実測）**: 1.0.2 の publish は 2026-10-30T21:17Z で 2 日に満たないが、**mise はこの npm 導入をブロックしなかった**（`mise install` 成功）。Renovate 側は `minimumReleaseAge: "2 days"` が効くため、PR は公開 2 日後に出る。
**Windows の権限**: アクセシビリティ権限の付与は**不要**（macOS のみ必要）。CLI のため GUI インストーラや自動更新は無く、**更新は mise のみ**。

### 10.3 APM の管理主体（`Microsoft.APM` — **mise ではない**）

| 項目 | 実測（2026-10-31） |
|---|---|
| 導入経路 | **winget `Microsoft.APM`**（Publisher: **Microsoft Corporation**、portable(zip)、`Installer SHA256`） |
| 実体版 | **0.35.0**（`apm --version` = `Agent Package Manager (APM) CLI version 0.35.0` / `winget list --id Microsoft.APM` = 0.35.0） |
| mise で入らない理由 | 旧 `pypi:apm-cli` は既定 **Python 3.15** で依存 `pyyaml` の cp315 wheel が無く導入不可（§6 の実測知見）。`github:microsoft/apm` も当時は配布形態が合わず不採用 |
| 宣言 | ✅ **`winget/host.dsc.yaml` に 0.35.0 を追加**（2026-10-31）。従来は文書とコメントにしか無く **DSC 未宣言**だった（＝`winget configure` では入らない状態） |
| Renovate | ❌ **対象外**。Renovate に winget の manager / datasource が無い（`/modules/manager/winget/` は 404、manager・datasource 一覧にも `winget` 無し） |
| 自動追随 | ✅ **`.github/workflows/winget-outdated.yml`**（毎週土曜 03:00 JST）が `tools/update-winget-dsc.ps1 -Apply` で DSC の `version:` を winget の最新へ書き換え、PR 作成 → auto-merge。**実測**: APM 行も走査対象として認識（`Microsoft.APM 0.35.0 → 0.35.0 update False`） |

**回答（要約）**: **APM は mise 管理ではない。winget `Microsoft.APM` の管轄**で、`host.dsc.yaml` に 0.35.0 として宣言済み。更新は Renovate ではなく **`winget-outdated` ワークフロー（週次）** が winget の最新版に追随する。DSC 未宣言のままだと、この自動追随からも漏れていた（今回の修正で解消）。
