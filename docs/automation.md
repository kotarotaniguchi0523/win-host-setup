# ホスト更新の仕組み（remote-complete / local-apply）

このホストのグローバル導入は **「判断は GitHub、適用はホスト」** で動かします。
ホストは版を決めません。**宣言（`public`）を pull して、そのとおりに適用するだけ**です。

## 原則

1. **更新の判断は GitHub 側で完結させる。** Renovate と `winget-outdated.yml` だけが版を上げる。
2. **ホストは宣言に従うだけ。** `mise upgrade` / `winget upgrade --all` / 各 CLI の self-update は使わない。
3. **宣言は厳密 pin。** `latest`・範囲指定・ブランチ ref は CI が拒否する（例外は APM 管理の2件のみ）。

## 全体の流れ

```
[source: ローカル専用・remote なし]
    │  tools/sync.ps1（capture → sanitize → commit → push）
    ▼
[public: GitHub のミラー]  ── CI（validate / lint / skills） ──┐
    │                                                          │
    │  Renovate / winget-outdated が PR を作り、CI 通過でマージ ┘
    │
    ▼  git -C public pull --ff-only（tools/run-task.ps1 -Task update）
[host: 適用]  mise install → skills-apply → winget configure（管理者）→ verify-host
```

`public/` が**ホストが pull する当のもの**であり、CI が見ているものと同じです（検証対象＝適用対象）。

## 更新の担当

| 対象 | 誰が上げるか | トリガー | 反映先 |
|---|---|---|---|
| mise ツール | Renovate（`mise` マネージャ） | 平日 6:00 前 / 2日ルール / minor・patch は automerge | `mise/mise.toml`、`relock.yml` が `mise.lock`（push は App トークン） |
| GitHub Actions | Renovate（`pinDigests`） | 同上 | 各ワークフローの `uses:`（SHA 固定） |
| Skills（タグ / SHA 固定） | Renovate（`apm` マネージャ） | 同上 | `skills/apm.yml`、`skills-relock.yml` が lock（push は App トークン） |
| Skills（**タグ無しの2件**） | **APM**（`apm update` / `skills-apply.ps1 -Lock`） | 手動、または relock | `apm.lock.yaml` の `resolved_commit` |
| winget DSC | `winget-outdated.yml` | 週次（windows ランナー） | `winget/host.dsc.yaml` |
| **msstore**（1件） | Store が自動更新 | — | **対象外**（信頼済みとして不問） |

Renovate の設定は `renovate.json`（`rangeStrategy: pin` / `pinDigests: true` / `minimumReleaseAge: 2 days`）。
脆弱性アラートだけは schedule・2日ルール・Dashboard 承認を迂回して即 PR・即マージです。
mise / APM の lock は Mend hosted の Renovate では更新できないため **`skipArtifactsUpdate: true`** にし、`relock.yml` / `skills-relock.yml` に任せています。

## ホスト側（ローカル）の操作

```powershell
pwsh -File tools/run-task.ps1 -Task check    # 読み取りのみ（差分・ドリフト表示）
pwsh -File tools/run-task.ps1 -Task update   # public pull → mise → skills → winget → verify
pwsh -File tools/run-task.ps1 -Task verify   # 検証のみ（.agent/update-report.json）
```

- `winget` の適用は**管理者権限が必要**。非管理者では警告してスキップします（その場合 `verify` は winget 乖離で失敗します）。
- 失敗時の AI フォールバック: `-AiFallback`（エージェント定義は `.opencode/agents/host-fixer.md`、許可リスト方式）。

## CI が守っているもの

| 守る対象 | 場所 |
|---|---|
| 厳密 pin（`latest` / 範囲 / ブランチ ref の拒否） | `validate.yml` → `tools/ci/lint-pins.py` |
| `uses:` の SHA 固定 | `lint.yml` → `tools/lint/actions.ps1`（pinact） |
| lock のドリフト | `validate.yml`（mise）/ `skills.yml`（APM） |
| lock の再生成 | `relock.yml`（mise）/ `skills-relock.yml`（APM）。PR ブランチへの push は relock 用 GitHub App のトークンで行い、`github-actions[bot]` の push による `action_required`（承認待ち）を避ける |
| PII・秘密情報 | `lint.yml`（depii / betterleaks / secretlint / hygiene） |
| winget DSC の乖離 | `healthcheck.yml`（週次・windows ランナー） |

## 例外と既知の穴

| 項目 | 状態 |
|---|---|
| **msstore 1件**（`9MVS1J51GMK6`、版指定なし） | Store が自動更新する。ポリシー上信頼済みなので**比較対象外**。 |
| **`#main` の2件**（`nushell/nu_scripts` / `mizchi/explainer`） | 上流にタグが無い。Renovate は追えないので **APM 管理**（`apm update` で lock を再解決）。許可リストは `lint-pins.py` の `APM_BRANCH_REF_ALLOW`。 |
| **自己更新 CLI**（`t3 update` / `opencode upgrade` / `uv self update` など） | mise の外に実体を作る。`pathctl audit` で検出できるが `verify` には未組み込み。 |
| **source → public の同期** | `tools/sync.ps1` が唯一の経路。source は remote を持たないため、CI からは同期ズレを検出できない。 |

## 運用ルール（1行）

> 更新は必ず PR → マージ → `pull` の順。ホストで版を上げるコマンドは使わない。
