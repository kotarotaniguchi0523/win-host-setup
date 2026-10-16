# グローバル PATH を安全に書き換える

## どこに保存されているか

| スコープ | 保存先 | 書き換えに必要な権限 |
|---|---|---|
| マシン | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment` の `Path` | **管理者** |
| ユーザー | `HKCU\Environment` の `Path` | 通常ユーザー |

値の型（`REG_SZ` / `REG_EXPAND_SZ`）は保ったまま書き戻す。`pathctl` は `%USERPROFILE%` のような
変数を**展開せずに**扱うので、他のアカウントでログインしても意味が変わらない。

## 手順（推奨）

```console
pathctl path check --format json                      # 1. 何が問題か
pathctl path fix --scope user --apply                 # 2. ユーザー側の安全な整理
pathctl path fix --scope machine --move-user-entries --format json   # 3. 下見
# 4. 内容を確認してから、管理者ターミナルで:
pathctl path fix --scope machine --move-user-entries --apply
```

反映の確認は**新しいシェル**で（`pathctl path list --scope user` と `where.exe <command>`）。

## 何をするか / しないか

| 操作 | 既定 | フラグ |
|---|---|---|
| 空エントリの削除 | する | — |
| 同一スコープ内の重複統合（先頭を残す）| する | — |
| 末尾の区切り文字の整理 | する | — |
| **マシン PATH の個人パスをユーザー PATH へ移動** | しない | `--move-user-entries` |
| **存在しないディレクトリのエントリ削除** | しない | `--prune-missing` |

## 元に戻したいとき

- 変更前に控える: `pathctl path list --scope machine --format json > machine.before.json`
- その控えから復元する（エントリの配列を書き戻す）:

```console
pathctl path list --scope machine --format json
# 出力の data.machine[].raw を確認し、必要なエントリを path add で戻す
```

`--move-user-entries` でマシン PATH から消したものは、**ユーザー PATH に追加されている**ので、
戻すときはユーザー側から `pathctl path remove <dir> --apply` で外す。

## 注意

- **`PATH` を空にしない**。`pathctl path add/remove` は 1 件ずつしか触らない。
- 破壊的な一括置換は用意していない（`--prune-missing` も「存在しないディレクトリ」だけ）。
- マシン PATH は全ユーザーに影響する。`C:\Users\<name>\...` のような個人パスを置かない
  （`pathctl path check` が `user-path-in-machine` として検出する）。
