# Git リポジトリ棚卸し/削除候補分析

- ソース: `win-host-setup\repos.md`（37 リポジトリ）
- 分析日: 2026-10-15
- 原則: **READ ONLY**（この分析は削除・変更を行わない）
- 「最近」のしきい値: 最終コミットが **2026-07-15 以降**（約3か月以内）を「最近」とみなす。

## 判定基準 (verdict)

| verdict | 意味 |
|---|---|
| **KEEP** | 最近の活動あり（最終コミットが約3か月以内）→ 触らない |
| **REVIEW** | 古いが remote あり（再取得/再clone 可能・要確認） |
| **CANDIDATE** | remote なし、かつ古い/コミットなし → 削除候補（下記の安全ゲート参照） |
| **EMPTY/TRIVIAL** | コミットなし・空/一時クローン → 削除リスク最小 |

> **安全ゲート**: `CANDIDATE` でも **dirty > 0** のものは「未コミットの作業を失う」ため、そのまま削除してはいけない。**先に backup / push が必要**（表では `CANDIDATE (blocked)` と表記）。ローカルにしか存在しないので remote 追加→push を推奨。

---

## 1. 削除候補（リスクの低い順）＋全リポジトリ評価

行は「削除してよさそうな順」に並べています。

### Tier A — 安全に削除できる（作業なし）

| Path | Remote | Last commit | dirty | size | verdict |
|---|---|---|---|---|---|
| `~\.codex\.tmp\plugins-clone-5oBPlb` | yes (openai/plugins) | (なし) | 0 | 0.7 MB | EMPTY/TRIVIAL |
| `~\.codex\.tmp\plugins-clone-UzoMAG` | yes (openai/plugins) | (なし) | 0 | 2.5 MB | EMPTY/TRIVIAL |
| `~\worktrees\refactor\architecture` | no | (なし) | 0 | 683.2 MB | CANDIDATE |

### Tier B — remote なし・dirty>0（先に backup / push 必須）

| Path | Remote | Last commit | dirty | size | verdict |
|---|---|---|---|---|---|
| `~\Desktop\家計設計` | **no** | (なし) | 3 | 41,634.9 MB | CANDIDATE (blocked) |
| `~\Desktop\個人的開発物\ask-use-question-mcp` | **no** | 2026-01-13 | **149** | 251.1 MB | CANDIDATE (blocked) |
| `~\liff-flexmessage-test` | **no** | 2025-07-28 | **15** | 535.2 MB | CANDIDATE (blocked) |

### Tier C — REVIEW（remote あり・古い。古い順）

| Path | Remote | Last commit | dirty | size | verdict |
|---|---|---|---|---|---|
| `~\Documents\search-novel` | yes (Yuorei/search-novel) | 2022-11-26 | 0 | 0.4 MB | REVIEW |
| `~\tutorial` | yes (kotarotaniguchi0523/Refine_Practice) | 2023-08-06 | 0 | 696.4 MB | REVIEW |
| `~\Desktop\LAF-DEV\Laf-develop-dev\%PROJECT_NAME%` | yes (comen-ryotaro/%PROJECT_NAME%) | 2024-06-23 | 1 | 2.4 MB | REVIEW |
| `~\dify` | yes (langgenius/dify) | 2025-01-21 | 0 | 174.6 MB | REVIEW |
| `~\refine\administorator-machine` | yes | 2025-04-03 | 12 | 1,328.6 MB | REVIEW |
| `~\Desktop\mother-day` | yes | 2025-05-11 | 1 | 47.1 MB | REVIEW |
| `~\mem0` | yes (mem0ai/mem0) | 2025-05-16 | 0 | 59.6 MB | REVIEW |
| `~\Desktop\授業まとめフォルダー\パターン認識と機械学習2025` | yes | 2025-05-20 | 7 | 4.9 MB | REVIEW |
| `~\Desktop\授業まとめフォルダー\音響音声処理` | yes | 2025-05-27 | 14 | 18.3 MB | REVIEW |
| `~\claudia` | yes (getAsterisk/claudia) | 2025-06-19 | 0 | 2.8 MB | REVIEW |
| `~\liff-gas-react` | yes | 2025-06-24 | 34 | 371.1 MB | REVIEW |
| `~\Desktop\line-mcp` | yes | 2025-06-30 | 66 | 76.8 MB | REVIEW |
| `~\line-narrowcast-flexmessage-` | yes | 2025-07-17 | 31 | 79.9 MB | REVIEW |
| `~\laf-line-mini-app` | yes | 2025-08-16 | 9 | 1,277.3 MB | REVIEW |
| `~\Desktop\processing-coding-agent\my-processing-app` | yes | 2025-09-23 | 1 | 339.0 MB | REVIEW |
| `~\Awesome-GAS-project` | yes | 2025-10-06 | 8 | 556.2 MB | REVIEW |
| `~\laf-line-route-info\liff-route-info` | yes | 2025-10-13 | 1 | 311.0 MB | REVIEW |
| `~\liff-hearing` | yes | 2025-11-10 | 0 | 1,240.1 MB | REVIEW |
| `~\Desktop\個人的開発物\taskmaster-kanban` | yes | 2025-12-04 | 3 | 204.6 MB | REVIEW |
| `~\laf-liff-app` | yes | 2026-02-27 | 0 | 1,505.5 MB | REVIEW |
| `~\blog` | yes (git@github.com:...blog) | 2026-04-07 | 0 | 395.2 MB | REVIEW |
| `~\.codex\vendor_imports\skills` | yes (openai/skills) | 2026-06-23 | 0 | 6.2 MB | REVIEW |
| `~\.codex\.tmp\plugins` | yes (openai/plugins) | 2026-06-02 | 0 | 54.6 MB | REVIEW |
| `~\.codex\.tmp\plugins-clone-p2cNN8` | yes (openai/plugins) | 2026-06-25 | **5257** | 21.0 MB | REVIEW |
| `~\playwright-mcp` | yes (microsoft/playwright-mcp) | 2025-03-31 | 0 | 69.8 MB | REVIEW |
| `~\Desktop\個人的開発物\kadai-sec\research-sources\react` | yes (facebook/react) | 2026-05-14 | 0 | 57.1 MB | REVIEW |
| `~\Desktop\個人的開発物\kadai-sec\research-sources\hono` | yes (honojs/hono) | 2026-05-16 | 0 | 7.1 MB | REVIEW |
| `~\claude-code-windows-setup` | yes | 2026-05-23 | 6 | 6.5 MB | REVIEW |

### Tier D — KEEP（最近の活動あり）

| Path | Remote | Last commit | dirty | size | verdict |
|---|---|---|---|---|---|
| `~\projects\fit-redesign-new` | yes | 2026-10-15 | 0 | 2,162.1 MB | KEEP |
| `~\Desktop\家計設計\sbx-setup` | yes (kotarotaniguchi0523/sbx-setup) | 2026-10-13 | 0 | 41,631.9 MB | KEEP |
| `~\projects\fit-redesign` | yes | 2026-09-28 | 1 | 26.1 MB | KEEP |

---

## 2. notes（要注意点）

### 2.1 remote が無い ＝ 消すと失われるリポジトリ（最重要）

| Path | Last commit | dirty | コメント |
|---|---|---|---|
| `~\Desktop\家計設計` | (なし) | 3 | コミットが1つも無いのに dirty=3。**現在の作業ディレクトリ**そのもの。さらに `sbx-setup`(#19) を入れ子で含む。**削除禁止**。 |
| `~\Desktop\個人的開発物\ask-use-question-mcp` | 2026-01-13 | **149** | ローカル専用。未コミット149件＝実作業が眠っている可能性大。**backup/push 必須**。 |
| `~\liff-flexmessage-test` | 2025-07-28 | **15** | ローカル専用。未コミット15件。**backup/push 必須**。 |
| `~\worktrees\refactor\architecture` | (なし) | 0 | コミットも dirty も無い worktree。**孤児 worktree** の可能性。ただし削除前に親リポジトリとの関係を確認。 |

### 2.2 dirty > 0 のリポジトリ一覧（削除すると未コミット作業を失う）

`家計設計`(3) / `ask-use-question-mcp`(149) / `liff-flexmessage-test`(15) /
`plugins-clone-p2cNN8`(5257) / `line-mcp`(66) / `liff-gas-react`(34) /
`line-narrowcast-flexmessage-`(31) / `音響音声処理`(14) / `administorator-machine`(12) /
`laf-line-mini-app`(9) / `Awesome-GAS-project`(8) / `パターン認識と機械学習2025`(7) /
`claude-code-windows-setup`(6) / `taskmaster-kanban`(3) / `mother-day`(1) /
`%PROJECT_NAME%`(1) / `my-processing-app`(1) / `liff-route-info`(1) / `fit-redesign`(1)

> 注意: `plugins-clone-p2cNN8` の dirty=5257 は異常値。ほぼ確実に `node_modules`/build 生成物。
> 削除前に `git status` で中身を確認（実作業が混じっているか）。

### 2.3 重複・同一 remote

- `openai/plugins.git` のクローンが **4つ**: `~\.codex\.tmp\plugins`(#1)、`plugins-clone-5oBPlb`(#2)、`plugins-clone-p2cNN8`(#3)、`plugins-clone-UzoMAG`(#4)。
  → `.codex\.tmp` 配下は一時ファイル。`#2/#4` はコミット無し（未完）。**#1〜#4 は整理対象**（#3 は dirty に注意）。
- `~\.codex\vendor_imports\skills`(#5) も openai 系。`.codex` のキャッシュ的性格。

### 2.4 入れ子（nested）とサイズ異常

- `~\.Desktop\家計設計`(#18, 41,634.9 MB) の**中に** `~\.Desktop\家計設計\sbx-setup`(#19, 41,631.9 MB) がある。
  → **サイズがほぼ同じ**＝スキャナが親のサイズに子を含めて二重計上している可能性。親(#18)を削除すると子(#19, remoteあり)も消える点に注意。
- `~\.Desktop\家計設計` は本セッションの作業ディレクトリでもある。

### 2.5 サードパーティのクローン（＝再clone可能、自作コミットが無ければ安全に削除）

`claudia`(getAsterisk) / `dify`(langgenius) / `mem0`(mem0ai) / `playwright-mcp`(microsoft) /
`react`(facebook) / `hono`(honojs) / `search-novel`(Yuorei) / `.codex\vendor_imports\skills`(openai) /
`.codex\.tmp\plugins*`(openai)
→ 上流のコピーなので再取得可能。バッキング対象は原則自前ブランチ/実装のみ。

### 2.6 ディスク使用量が大きいもの（整理効果が高い）

`家計設計`(41.6GB) / `sbx-setup`(41.6GB) / `fit-redesign-new`(2.16GB, KEEP) /
`laf-liff-app`(1.51GB) / `administorator-machine`(1.33GB) / `laf-line-mini-app`(1.28GB) /
`liff-hearing`(1.24GB) / `tutorial`(0.70GB) / `worktrees\refactor\architecture`(0.68GB) /
`Awesome-GAS-project`(0.56GB) / `liff-flexmessage-test`(0.54GB)

### 2.7 その他

- `~\.codex\.tmp\*` は名前からして一時ディレクトリ。恒久的に必要でない限り削除優先。
- `search-novel`(2022) は最古。古いが remote あり。
- `~\.codex\.tmp\plugins-clone-5oBPlb` / `plugins-clone-UzoMAG` はブランチ `HEAD`・コミット日無し＝実質空。

---

## 3. 集計

| verdict | 件数 |
|---|---|
| KEEP | 3 |
| REVIEW | 28 |
| CANDIDATE | 4 |
| EMPTY/TRIVIAL | 2 |
| **合計** | **37** |

- remote なし: **4** 件（`家計設計`, `ask-use-question-mcp`, `liff-flexmessage-test`, `worktrees\refactor\architecture`）
- dirty > 0: **19** 件（2.2 節参照）
