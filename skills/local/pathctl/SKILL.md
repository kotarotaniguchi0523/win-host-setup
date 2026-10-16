---
name: pathctl
description: Windows のグローバル PATH を点検・修復し、どのツールが mise / winget / npm / 直置きで使えるかを調べる CLI（pathctl）の使い方。PATH の点検、重複や個人パスの混入の修正、mise が無くても使えるコマンドの一覧、uvx / uv tool での導入、管理者権限が要る操作の依頼などで使う。
---

# pathctl

Windows のグローバル PATH（マシン / ユーザー）を点検・修復する CLI。`pathctl docs show agents` に
エージェント向けの契約（終了コード / JSON / 安全策）が入っている。

## 最初に読む順序

```console
pathctl docs list                          # 同梱ガイドの一覧
pathctl docs show agents                   # 契約（終了コード・JSON・安全策）
pathctl describe --format json             # 正確なフラグ一覧
pathctl doctor --format json               # 現状の点検
```

## 代表的な使い方

```console
pathctl tools --without-mise --format json   # mise が無くても起動できるコマンド
pathctl path check --format json             # 重複・個人パス・存在しないパス
pathctl path fix --scope user --apply        # ユーザー PATH の安全な整理
pathctl path add '%USERPROFILE%\.local\bin' --scope user --apply
```

## エージェントが守ること

1. **書き込みは `--apply` のときだけ**。付けなければ下見（`dry_run: true`）になる。
2. **exit 4（config）は管理者権限**。エージェントは自分で昇格できないので、ユーザーに
   管理者ターミナルでの実行を依頼する（回避策を探さない）。
3. 出力は `--format json`（`schema: "pathctl/1"`）を既定にする。TSV は `path list` と `tools` のみ。
4. 判断に迷ったら `pathctl docs show path-editing`（PATH の書き換え手順と戻し方）。

## 導入

```console
uvx pathctl --version
uv tool install --from tools/pathctl pathctl
uvx --from git+https://github.com/kotarotaniguchi0523/win-host-setup#subdirectory=tools/pathctl pathctl
```
