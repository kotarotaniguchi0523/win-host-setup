# AUDIT — Windows Package Policy 準拠レビュー

実施: 2026-10-15 / 対象: Windows ホストのグローバル導入 / 根拠: `AGENTS.md`

## 1. Rule 1 — 公式 Microsoft Store 版を優先

| 対象 | 現状 | 判定 |
|---|---|---|
| **ngrok** | **msstore** `9MVS1J51GMK6`（3.39.9-msix） | ✅ 移行済み |
| PowerShell | winget `Microsoft.PowerShell` 7.6.6（msstore に `9MZ1SNWT0N5D` あり） | ⚠️ **候補** |
| Ubuntu | winget `Canonical.Ubuntu`（msstore に `9PDXGNCFSCZV` あり） | ⚠️ **候補** |
| Docker Desktop | winget `Docker.DockerDesktop`（msstore に `XP8CBJ40XLBWKX` あり） | ⚠️ 候補だが **sbx データ依存のため非推奨** |
| Python | mise `3.14.8`（msstore は 3.13 のみ） | ✅ mise が正当（Attestation＋固定） |
| mise / git / openssl / cloudflared / fd | msstore に無し | — |

> 「MSIX/EXE/MSI の形式だけで安全性を判断しない」→ 発行元（Publisher）を `winget show` で確認した（下表 Rule 3）。

## 2. Rule 2 — mise/aqua（検証が**実効**か `mise tool` で確認）

| tool | backend | `Security:` 行（実測） |
|---|---|---|
| betterleaks | aqua:betterleaks/betterleaks | checksum (sha256) + **cosign** |
| node | core:node | checksum (sha256) + **gpg** |
| pnpm | aqua:pnpm/pnpm | **github_attestations** |
| python | core:python | checksum + github_attestations |
| gh | aqua:cli/cli | checksum + github_attestations |
| uv | aqua:astral-sh/uv | checksum + github_attestations |
| jq | aqua:jqlang/jq | checksum + github_attestations |
| ripgrep | aqua:BurntSushi/ripgrep | checksum (sha256) |
| jj | aqua:jj-vcs/jj | checksum (sha256) |
| go | core:go | checksum (sha256) |
| doppler | github:DopplerHQ/cli | checksum (sha256) |
| apm | github:microsoft/apm | checksum (sha256) |
| mo | aqua:k1LoW/mo | checksum (sha256) |
| waza | github:microsoft/waza | checksum (sha256) |
| rtk | aqua:rtk-ai/rtk | checksum (sha256) |
| hk | packslip:github.com/jdx/hk | packslip |
| **npm** | npm:npm | **[none]** ⚠️ **例外**（下記） |

> **`packslip` の注記（誤解しやすい点）**: `Security: packslip` は「検証なし」ではなく **署名ベースの最強クラス**。mise は展開前に ①バンドルの Sigstore 署名＋証明書＋transparency log ②manifest の構造・要求した project/version ③**artifact の digest と size** ④**signer 継続性**と **lockfile のコミットメント** ⑤release-age を検証する。
>
> 実測 `mise.lock` の hk エントリ:
> ```
> checksum = "sha256:bcccd6..."
> signer = "sigstore-oidc:https://github.com/jdx/hk/.github/workflows/release.yml"
> repository_ids = { repository = "922514152", owner = "216188" }
> ```
> → 発行元の **CI workflow 署名**に加えて **リポジトリID まで固定**（repo 改名・同名なりすまし対策）。検証済み manifest は `.mise-packslip.json` に保存され、次回以降も継続性を照合する。
>
> ただし署名が保証するのは **「誰が発行したか」と「バイトがその署名どおりか」**であり、**ソフトの安全性や SLSA build provenance の検証ではない**（provenance の有無は記録するが取得・検証はしない）。なお **すべての取得は mise 経由**（`locked=true` で URL は `mise.lock` に限定）。毎回再検証したい場合は `locked_verify_provenance` を有効化する。

## 3. Rule 3 — 通常の WinGet（検証が不十分なもの）

| tool | id | Publisher（`winget show`） | 検証 |
|---|---|---|---|
| mise | jdx.mise | jdx | SHA256 |
| git | Git.Git | The Git Development Community | SHA256 + Authenticode(OS) |
| openssl | ShiningLight.OpenSSL.Light | Shining Light Productions | SHA256 |
| cloudflared | Cloudflare.cloudflared | cloudflare | SHA256 |
| fd | sharkdp.fd | sharkdp | SHA256 |
| docker | Docker.DockerDesktop | Docker Inc. | SHA256 |
| sbx | Docker.sbx | Docker Inc. | SHA256 |

## 4. 検出した違反と修正

| 違反（ポリシー不整合） | 修正 |
|---|---|
| **cloudflared** を mise 管理 → `Security: [none]`（Rule 2 不成立） | **winget へ**（`Cloudflare.cloudflared`, publisher=cloudflare） |
| **fd** を mise 管理 → `Security: [none]`（Rule 2 不成立） | **winget へ**（`sharkdp.fd`） |
| **betterleaks が二重**（winget 1.9.0 / mise 1.2.0） | mise を **1.9.0 に更新**し **winget 版を削除**（mise は cosign 検証あり） |
| **lefthook**(winget) が残存（`hk` に置換済み） | **削除** |
| **Python.Launcher** 孤立（Python 実体なし） | **削除** |
| User PATH に stale な WinGet ポータブル項目（Betterleaks/lefthook/Ngrok.Ngrok） | **削除** |

## 5. 共通セキュリティ要件の確認

- 第三者の再配布物を避ける: **Chocolatey / Scoop 不使用**（choco は全撤去・PATH も除去）✅
- バージョン固定・検証可能な取得: `mise.lock`（checksum/provenance）＋ `locked=true` ✅
- 管理者権限・任意スクリプト・PATH 変更の最小化: 昇格が必要な操作は**昇格スクリプトに分離**し実行ログを保存 ✅
- 既存パッケージ管理との重複排除: nvm / Python 3.13 / choco / pnpm-global / lefthook / betterleaks ✅
- **混同しない**: 「署名（Authenticode）≠ provenance（attestation）≠ ハッシュ（SHA256）≠ マルウェア検査」を本表で区別して記録 ✅
- 不明は推測しない: `npm` は検証可能な入手経路が見つからないため**例外として報告**（下記）

## 6. 未解決 / 要判断

| 項目 | 内容 |
|---|---|
| **npm の検証** | mise `npm:npm` は `Security: [none]`。単体 npm を検証つきで配る経路が無い（winget に npm 単体なし／node 同梱の npm は mise の node に含まれない）→ **記録的例外**として扱う |
| **PowerShell が二重** → **解消済（B）** | ⚠️ **MSIX**（`Microsoft.PowerShell 7.6.6.0`, `WindowsApps`）と **MSI**（`C:\Program Files\PowerShell\7`）が併存していた。PATH は WindowsApps(idx13) が先 → **実効は MSIX**。→ **2026-10-15: MSI を削除**（`msiexec /X{B1A9B37E-…}`）。**検証済**: `C:\Program Files\PowerShell` 消滅 ／ MSIX の `WindowsApps\pwsh.exe` 残存。`host.dsc.yaml` の `Microsoft.PowerShell`（winget=MSIX）と整合 |
| **MSIX の制約**（既に実効） | 単一ユーザーのみ／**WinRM リモート不可**／`$PSHOME` 書込不可（`Set-ExecutionPolicy -Scope LocalMachine`・`Register-PSSessionConfiguration`・`Update-Help -Scope AllUsers` 不可）／全ユーザープロファイル不可／`.ps1` 関連付け不可／DISM cmdlet（`Get-WindowsOptionalFeature` 等）不可／**SYSTEM 文脈で不可**（スケジュールタスク・サービス）。※ MSI は **7.7 で廃止**（MSIX 一本化） |
| **msstore 候補** | Ubuntu（`9PDXGNCFSCZV`）は**既に Canonical の MSIX**（変更不要）。Docker は sbx データ依存のため非推奨 |
| **MSI 削除の副作用** | ⚠️ **opencode は既定で `C:\Program Files\PowerShell\7\pwsh.exe` をシェルとして掴む**ため、MSI 削除後に **spawn 失敗**（`指定されたパスが見つかりません`）。→ `~/.config/opencode/opencode.jsonc` の **`shell`** に MSIX の pwsh（`%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe`）を明示して解決。**他ツールでも「MSI パスを固定参照しているもの」は要確認** |
| ~~**gh auth**~~ | ✅ **解決 (2026-10-15)**: `gh auth login` 完了（account `%GITHUB_USER%`）＋ `GH_TOKEN`/`GITHUB_TOKEN` を **User 環境変数**に登録 → API **5,000/h**（実測 4,999/5000）＝ `github_attestations` 検証が安定 |
| **Rust** | rustup は winget `Rustlang.Rustup` 経由（ツールチェーンは `~/.cargo`）。発行元 = Rust Project |

## 7. 現在のダウンロード方法（全ツール）

### 7.1 mise 経由（`mise.lock` に URL/checksum を固定・`locked=true`・`locked_verify_provenance=true`）

| tool | version | backend | `Security:` |
|---|---|---|---|
| betterleaks | 1.9.0 | aqua:betterleaks/betterleaks | checksum + cosign |
| node | 26.11.1 | core:node | checksum + gpg |
| npm | 12.2.0 | npm:npm | **[none]**（例外） |
| pnpm | 12.12.1 | aqua:pnpm/pnpm | github_attestations |
| python | 3.14.8 | core:python | checksum + github_attestations |
| gh | 2.102.0 | aqua:cli/cli | checksum + github_attestations |
| uv | 0.13.0 | aqua:astral-sh/uv | checksum + github_attestations |
| go | 1.27.2 | core:go | checksum |
| jj | 0.46.0 | aqua:jj-vcs/jj | checksum |
| hk | 2.6.0 | packslip:github.com/jdx/hk | packslip（署名＋repo ID 固定） |
| jq | 1.8.2 | aqua:jqlang/jq | checksum + github_attestations |
| ripgrep | 15.2.0 | aqua:BurntSushi/ripgrep | checksum |
| doppler | 3.76.0 | github:DopplerHQ/cli | checksum |
| apm | 0.14.0 | github:microsoft/apm | checksum |
| mo | 1.5.5 | aqua:k1LoW/mo | checksum |
| waza | 0.33.0 | github:microsoft/waza | checksum |
| rtk | 0.40.0 | aqua:rtk-ai/rtk | checksum |

### 7.2 winget（community ソース・Publisher 明示＋SHA256）

| tool | id | Publisher（`winget show`） |
|---|---|---|
| mise | jdx.mise | jdx |
| git | Git.Git | The Git Development Community |
| openssl | ShiningLight.OpenSSL.Light | Shining Light Productions |
| cloudflared | Cloudflare.cloudflared | cloudflare |
| fd | sharkdp.fd | sharkdp |
| rustup | Rustlang.Rustup | Rust Project |
| docker | Docker.DockerDesktop | Docker Inc. |
| sbx | Docker.sbx | Docker Inc. |
| WSL | Microsoft.WSL | Microsoft |
| Ubuntu | Canonical.Ubuntu | Canonical |
| PowerShell | Microsoft.PowerShell | Microsoft Corporation |

### 7.3 winget（`msstore` ソース）

| tool | id | Publisher |
|---|---|---|
| ngrok | 9MVS1J51GMK6 | ngrok |

### 7.4 その他
- **cargo / rustup toolchain**: `~/.cargo`（winget `Rustlang.Rustup` がブートストラップ）。
- **sbx データ**: `%LOCALAPPDATA%\DockerSandboxes\sandboxes`（アンインストールでは消えない想定だが `bin` と同居のため退避推奨）。
- **削除済み**: Chocolatey / Scoop / nvm / pyenv / Python 3.13 / `~/.local\bin`（claude 他）/ 旧 npm グローバル（claude-code 等）。

## 8. 宣言的再現（Git 一元管理）

- **mise**: `mise/config.toml` + `mise/mise.lock` → `mise install --locked`
- **winget**: `winget/host.dsc.yaml` → `winget configure -f winget/host.dsc.yaml --accept-configuration-agreements`
  - 実測: **12 リソース全て適用成功**（`Configuration successfully applied.`）。全バージョン固定で冪等。
  - ⚠️ `assertions`（OsVersion 等）は DSC モジュールが無いと**全リソースがスキップ**されるため外した。
