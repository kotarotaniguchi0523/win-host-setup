# pathctl — 概要

Windows の**グローバル PATH**（マシン / ユーザー）を点検・修復し、**どのツールがどの入手元で
使えるか**（mise / winget / npm / 直置き）を一覧する CLI。

## インストール

```console
uvx pathctl --version                     # PyPI（公開後）
uv tool install --from tools/pathctl pathctl   # このリポジトリから
uvx --from git+https://github.com/kotarotaniguchi0523/win-host-setup#subdirectory=tools/pathctl pathctl
```

`uv tool install` の bin（`%USERPROFILE%\.local\bin`）が PATH に無い場合は、この CLI 自身で足せる。

```console
pathctl path add '%USERPROFILE%\.local\bin' --scope user --apply
```

## よく使う形

```console
pathctl doctor --format json                 # 点検（機械可読）
pathctl tools --without-mise                 # mise が無くても起動できるコマンド
pathctl path check                           # 重複・個人パス・存在しないパス
pathctl path fix --move-user-entries         # 直す内容の下見（まだ書き換えない）
pathctl describe --format json               # コマンドとフラグの一覧
pathctl docs list                            # 同梱ガイドの一覧（この文書もここから読める）
```

## コマンド体系（noun-verb）

| 名詞 | 動詞 | 内容 |
|---|---|---|
| `path` | `list` / `check` / `fix` / `add` / `remove` | PATH の一覧・検査・修復・追加・削除 |
| `tools` | （一覧） | ツールと入手元（別名 `list-tools`）|
| `docs` | `list` / `show` | 同梱ガイド |
| `doctor` | — | PATH とツールをまとめて点検 |
| `describe` | — | 入出力契約（別名 `schema`）|

## 何を見ているか

- **レジストリが正**（マシン PATH とユーザー PATH）。現在のプロセスの PATH は、IDE やインストーラが
  注入した差分を含むため「参考」としてのみ扱う（`pathctl path list --scope all` で両方見える）。
- ツールの入手元は、解決先のディレクトリから判定する: `mise-shim` / `mise-install` / `winget` /
  `npm-global` / `direct` / `unavailable`。
- `without_mise: true` は「mise のディレクトリ以外からも解決できる」= **mise が無くても起動できる**。
