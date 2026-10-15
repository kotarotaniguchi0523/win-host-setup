# ARCHITECTURE — 構成と更新フロー

このリポジトリは「**Windows ホストの実環境**」を「**リポジトリ**」に写し、
「**サニタイズした写し**」を GitHub で公開・自動更新する。図はすべて ASCII。

---

## 1. 3 つの層

```
+----------------------------+      +----------------------------+      +----------------------------+
|  実環境 (host)             |      |  source repo               |      |  public repo               |
|                            |      |  (PII を含む / remote 無)  |      |  (PII なし / GitHub)       |
|  ~/.config/mise/config.toml|      |                            |      |                            |
|  ~/.config/mise/mise.lock  | ---> |  mise/mise.toml            | ---> |  mise/mise.toml            |
|  ~/.apm/apm.yml            | copy |  mise/mise.lock            | san  |  mise/mise.lock            |
|  ~/.agents/skills/         |      |  skills/                   |      |  skills/                   |
|  PATH / 環境変数            | <--- |  winget/host.dsc.yaml      |      |  .github/workflows/        |
|  winget (DSC)              | apply|  tools/ .github/ hk.pkl    |      |  ...                       |
+----------------------------+      +----------------------------+      +----------------------------+
                                                 ^
                                                 |  gitignore
                                      +----------------------------+
                                      |  .agent/  (local only)     |
                                      |   docs/  退避データ 実値表  |
                                      +----------------------------+
```

| 層 | 管理するもの | パッケージマネージャ | 実体 |
|---|---|---|---|
| ホスト全体 | グローバルな CLI/ランタイム | **mise** | `~/.config/mise/config.toml` |
| リポジトリ限定 | Lint/フック用ツール | **mise** | `./mise.toml` |
| Skills | エージェントのスキル | **APM** | `~/.apm/apm.yml` |
| フック | commit/push 時の検証 | **hk** | `./hk.pkl` |

---

## 2. フォルダ構造

```
win-host-setup/
|
+-- AGENTS.md                 ポリシー本文 (msstore > mise/aqua > winget)
+-- README.md                 入口・手順
+-- ARCHITECTURE.md           この文書 (構成とフロー)
+-- PLAN.md                   計画 + 実施ログ (上=未完了 / 下=完了)
+-- AUDIT.md                  ポリシー準拠の監査
+-- winget-vs-mise.md         全ツールの「mise か winget か」判定表
|
+-- mise.toml                 [repo-local] ツール定義 (jactionlint/sisakulint/hk/...)
+-- mise.lock                 [repo-local] チェックサム + provenance の固定
+-- hk.pkl                    pre-commit / pre-push のフック定義
+-- renovate.json             mise / Skills の自動更新 (グループ別 PR)
+-- .secretlintrc.json        secretlint のルール
|
+-- mise/                     [グローバル設定の写し]
|   +-- mise.toml             -> ~/.config/mise/config.toml
|   +-- mise.lock             -> ~/.config/mise/mise.lock
|
+-- winget/
|   +-- host.dsc.yaml         winget の宣言 (バージョン固定)
|
+-- skills/                   [Skills の実体]
|   +-- apm.yml               リモート Skill の宣言 (owner/repo#ref)
|   +-- apm.lock.yaml         commit SHA + ファイル毎 sha256
|   +-- local/<name>/        自作 Skill (APM 管理外)
|
+-- env/
|   +-- variables.md          ユーザー環境変数 (秘密は自動で伏せる)
|
+-- tools/                    [同期・検証のスクリプト]
|   +-- lib/common.ps1        共有 (Invoke-Native / Get-HomeDir / Resolve-Apm)
|   +-- capture.ps1           実環境 -> repo     (mise)
|   +-- skills-capture.ps1    実環境 -> repo     (Skills)
|   +-- apply.ps1             repo -> 実環境     (mise)
|   +-- skills-apply.ps1      repo -> 実環境     (Skills)
|   +-- depii.ps1             PII を in-place 除去
|   +-- sanitize.ps1          repo -> public (最後の防波堤)
|   +-- sync.ps1              一括: capture -> depii -> sanitize -> commit -> push
|   +-- pii-rules.ps1         置換ルール (汎用) + 公開対象リスト
|   +-- update-winget-dsc.ps1 winget の最新版と突き合わせ
|   +-- fix-machine-path.ps1  Machine PATH の整理 (管理者)
|   +-- lint/actions.ps1      jactionlint + sisakulint (+ pinact 任意)
|   +-- lint/secrets.ps1      betterleaks + secretlint
|   +-- lint/all.ps1          上記 + PII + waza
|   +-- ci/mise-verify.ps1    ロック整合性の検証 (relock でも使用)
|   +-- ci/skills-verify.ps1  APM lock ドリフト + 監査 (SARIF)
|   +-- ci/hygiene.ps1        個人パス混入の検査
|   +-- ci/lint-config.py     JSON / YAML / TOML の構文
|   +-- ci/install-apm.ps1    APM CLI の導入
|   +-- ci/waza-check.ps1     Skill の評価
|
+-- .github/
|   +-- workflows/            CI (下記 4 章)
|   |   +-- renovate.yml
|   |   +-- relock.yml
|   |   +-- validate.yml
|   |   +-- lint.yml
|   |   +-- skills.yml
|   |   +-- winget-outdated.yml
|   |   +-- healthcheck.yml
|   |   +-- actions.lock      gh actions-lock が生成 (タグ -> コミット)
|   +-- dependabot.yml        github-actions の更新
|   +-- jactionlint.yaml      profile + baseline
|   +-- jactionlint-baseline.json  既知の指摘 (新規のみ失敗させる)
|
+-- .agent/                   [local only / gitignore]
|   +-- docs/                 分析系ドキュメントの退避先
|   +-- pii-rules.local.ps1   PII の実値リスト
|
+-- public/                   [公開用の生成物 / 独立 git repo]
```

---

## 3. 同期フロー（向きが重要）

```
  (A) 実環境 -> repo            (B) repo -> 実環境
  +---------------------+       +---------------------+
  | tools/capture.ps1   |       | tools/apply.ps1     |
  | tools/skills-capture|       | tools/skills-apply  |
  +----------+----------+       +----------+----------+
             |                             ^
             v                             |
  +---------------------+       +---------------------+
  |  source repo        |       |  source repo        |
  +----------+----------+       +---------------------+
             |
             |  tools/depii.ps1     (PII を in-place 除去)
             v
  +---------------------+
  |  tools/sanitize.ps1  |  (プレースホルダ化して public/ を生成)
  +----------+----------+
             v
  +---------------------+       +---------------------+
  |  public repo        | ----> |  GitHub (main)      |
  +---------------------+ push  +---------------------+

  ワンショット:  pwsh -File tools/sync.ps1
    capture -> skills-capture -> depii -> sanitize -> commit -> push
```

---

## 4. 更新フロー（依存を古くしない）

```
   +----------------+        +----------------+        +----------------+
   |  Renovate      |        |  Dependabot    |        | winget-outdated|
   |  (mise/Skills) |        | (github-actions|        | (winget 自身)  |
   +-------+--------+        +-------+--------+        +-------+--------+
           |                         |                         |
           | PR                      | PR                      | PR
           v                         v                         v
   +-------------------------------------------------------------------+
   |  PR 検証 (CI):  validate  /  lint  /  skills                       |
   |    relock: mise/mise.toml が変わったら mise.lock を再生成して追随   |
   +--------------------------------+----------------------------------+
                                    | merge
                                    v
                            +----------------+
                            | GitHub main    |
                            +----------------+

  注意: 現状は source -> public の一方通行。
        GitHub 側の更新を実環境へ反映するには public から pull して apply する。
```

---

## 5. CI フロー（ワークフロー別）

```
  push / PR                      schedule (週次)               skills/** 変更
  +--------------------+         +--------------------+       +--------------------+
  | validate.yml       |         | renovate.yml       |       | skills.yml         |
  |  - mise lock 整合  |         |  - グループ別 PR   |       |  - APM lock ドリフト|
  |  - 設定の構文      |         +--------------------+       |  - apm audit(SARIF)|
  |  - PSScriptAnalyzer|         | winget-outdated.yml|       |  - waza check      |
  +--------------------+         |  - DSC のピン更新  |       +--------------------+
  | lint.yml           |         +--------------------+
  |  - actions (並列)  |         | healthcheck.yml    |
  |  - secrets (並列)  |         |  - mise/winget 乖離|
  |  - pii     (並列)  |         |  - 公開物の衛生    |
  +--------------------+         +--------------------+

  relock.yml : PR で mise/mise.toml が変わったときのみ (mise.lock を再生成)
```

---

## 6. ローカルフック（hk）

```
  git commit                     git push
      |                              |
      v                              v
  +----------------+          +--------------------------------------+
  | pre-commit     |          | pre-push                             |
  |  - pii         |          |  - pii / secrets                     |
  |  - secrets     |          |  - jactionlint / betterleaks         |
  +----------------+          |  - sisakulint / powershell           |
                              +--------------------------------------+
      (hk install で git config に配線 / `git commit --no-verify` で回避可)
```

---

## 7. 検証の多層構造

```
  1. 入手時    msstore 公式  ->  mise/aqua (checksum/attestations/cosign/gpg)
                              ->  winget (Installer SHA256)
  2. 再現性    mise.lock / (pypi は uv 依存グラフ) / actions.lock / apm.lock.yaml
  3. PII       pii-rules (汎用 + .agent の実値) -> depii -> sanitize
  4. 秘密      betterleaks + secretlint + GitHub secret scanning / push protection
  5. CI        validate / lint / skills (SARIF を Code Scanning へ)
  6. フック    hk pre-commit / pre-push
```

---

## 8. 典型シナリオ

```
  (1) グローバルにツールを足す
      mise use -g <tool>@<ver>  ->  mise lock  ->  tools/sync.ps1

  (2) Skill を足す
      skills/apm.yml に owner/repo#ref      (リモート)
      skills/local/<name>/SKILL.md          (自作)
      ->  tools/skills-apply.ps1 -Lock  ->  tools/sync.ps1

  (3) winget のピンを更新
      tools/update-winget-dsc.ps1 -Apply  ->  tools/sync.ps1

  (4) 更新 PR を取り込む (現状は手作業)
      public を pull  ->  mise/mise.lock 等を source へ  ->  tools/apply.ps1
```

---

## 9. ローカル設定の共有（どうやって repo と共有するか）

**方式は「コピー」**（symlink ではない）。理由は Developer Mode が OFF で symlink 作成に管理者権限が要るため、
また mise が設定を書き換える（`mise use`）ため、**実体を 1 箇所に固定すると書き込み競合が起きる**ため。

### パス対応（どこが正か）

```
  実環境 (host)                              リポジトリ (source)              正 (source of truth)
  ------------------------------------       ----------------------------     --------------------
  ~/.config/mise/config.toml          <-->   mise/mise.toml                  ホスト (capture で写す)
  ~/.config/mise/mise.lock            <-->   mise/mise.lock                  ホスト (lock は生成物)
  ~/.config/mise/locks/               <-->   mise/locks/                     pypi の依存グラフ (生成物)
  ~/.apm/apm.yml                      <-->   skills/apm.yml                 リポジトリ (宣言を書く)
  ~/.apm/apm.lock.yaml                <-->   skills/apm.lock.yaml            生成物 (apm lock -g)
  ~/.agents/skills/<name>/            <-->   skills/local/<name>/           ホスト (自作 Skill は実環境が正)
  (存在しない)                               winget/host.dsc.yaml           リポジトリ (winget configure で適用)
  (環境変数)                                 env/variables.md                生成物 (秘密は自動で伏せる)

  補足: リポジトリ側は config.toml ではなく **mise/mise.toml** という名前で置く。
        リポジトリ直下に config.toml を置くと mise が「プロジェクト設定」として読み、
        paranoid が無視されて未信頼エラーになるため。
```

### コマンド（向きごと）

```
  ホスト -> リポジトリ                リポジトリ -> ホスト
  +---------------------------+       +---------------------------+
  | tools/capture.ps1         |       | tools/apply.ps1           |
  |   mise/ を更新            |       |   ~/.config/mise/ へ配置   |
  | tools/skills-capture.ps1  |       |   mise install を実行      |
  |   skills/ を更新          |       | tools/skills-apply.ps1    |
  +---------------------------+       |   ~/.apm へ配置 + 自作Skill|
                                      |   apm lock/install (-Lock) |
                                      +---------------------------+
  一括 (推奨):
      pwsh -File tools/sync.ps1                 # capture -> depii -> sanitize -> commit -> push
      pwsh -File tools/sync.ps1 -Check          # 変更を書き換えず差分だけ確認
      pwsh -File tools/sync.ps1 -NoPush         # push しない

  新しいホストへ復元:
      git clone <public>  ->  pwsh -File tools/apply.ps1
                          ->  winget configure winget/host.dsc.yaml
                          ->  pwsh -File tools/skills-apply.ps1 -Lock
                          ->  hk install
```

### 共有しないもの（ローカル専用）

```
  .agent/                  .gitignore 済み
    +-- docs/              分析系ドキュメント (inventory.md / repos.md / migration-*)
    +-- pii-rules.local.ps1   PII の実値 (Git アカウント名 / 案件名 / メール)
    +-- (環境変数の秘密は保存しない: CONTEXT7_API_KEY / GH_TOKEN 等は env/variables.md で伏せる)
```

### 共有時のルール

1. **実パスを書かない**。`%USERPROFILE%` / `%USERNAME%` / `%GITHUB_USER%` などのプレースホルダを使う
   （`tools/depii.ps1 -Check` が検出。コード内の検出は「要手直し」として失敗にする）。
2. **秘密をコミットしない**。`env/variables.md` は秘密を自動で伏せ、CI の betterleaks / secretlint と
   GitHub の secret scanning / push protection が二重に守る。
3. **`mise/mise.lock` と `skills/apm.lock.yaml` は生成物**。手で編集せず `mise lock` / `apm lock -g` で更新する。
4. **向きを間違えない**。自作 Skill はホストが正なので、リポジトリ側を直接編集した場合は
   先に `tools/skills-apply.ps1` でホストへ反映してから `sync` する（逆順だと編集が失われる）。

---

## 10. 既知のギャップ

- **同期は一方通行** (source -> public)。GitHub で merge された更新を実環境へ戻す経路がない (案: `tools/pull.ps1`)。
- CI の `lint` は runner 側で赤 (ローカルは緑)。原因は runner での `mise install` (Go ビルドの sisakulint / npm の secretlint)。
- jactionlint の指摘 45 件は **baseline 記録** (CI 緑は「新規なし」の意味)。`missing-timeout` 等は返済対象。
- 分析系ドキュメント (inventory/repos/migration) は公開しない (`.agent/docs/`)。
