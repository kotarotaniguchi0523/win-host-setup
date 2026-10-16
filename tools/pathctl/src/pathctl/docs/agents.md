# エージェント向けの契約

この CLI は **Coding Agent** に使わせる前提で作っている。Web Fetch は不要で、次の順に読めば
自己完結する。

```console
pathctl docs list                            # ガイドの一覧
pathctl docs show agents                     # この文書
pathctl describe --format json               # コマンドとフラグ（正確な引数）
pathctl doctor --format json                 # 現状の点検
```

## 出力

- `--format json` は常に同じ封筒（`schema: "pathctl/1"`）を返す。
  `schema` / `kind` / `command` / `ok` / `exit_code` / `category` / `data` / `findings` / `hints` / `error`。
- stdout は**データのみ**、人間向けのメッセージは stderr。パイプ時は UTF-8。
- `--format tsv` は `path list` と `tools` のみ。ヘッダ無しなので `awk -F'\t'` にそのまま渡せる。
- `pathctl describe <command> --format json` に、そのコマンドのフラグ・既定値・例・注意が入る。

## 終了コード（分岐に使う）

| コード | category | 意味 |
|---|---|---|
| 0 | ok | 成功（findings なし、または許容範囲）|
| 1 | general | 予期しない失敗 |
| 2 | usage | 引数の誤り |
| 3 | not_found | 対象が存在しない（存在しないディレクトリを `path add` した等）|
| 4 | config | 管理者権限が無い / レジストリが使えない |
| 5 | validation | findings への対応が必要（`doctor` / `path check`）|

## エラーは「次の一手」まで返す

```json
{
  "error": {
    "category": "config",
    "message": "writing the machine PATH needs an elevated shell (Run as administrator)",
    "next_step": "管理者として実行したシェルで --apply を付け直してください",
    "required_args": ["--apply"]
  }
}
```

## 安全策（必ず守る）

1. **書き込みは `--apply` のときだけ**。付けなければ下見（`dry_run: true`）で、出力を読めば
   何が消えて何が残るかが分かる。
2. **マシン PATH の変更は管理者権限**が要る。エージェントは自分で昇格できないので、
   exit 4 が返ったら**ユーザーに管理者ターミナルでの実行を依頼する**（回避策を探さない）。
3. **`--move-user-entries` と `--prune-missing` は明示**。既定の `path fix` は空エントリの削除・
   重複統合・末尾区切りの整理だけ。
4. **`%VAR%` はそのまま保持**される（`C:\Users\%USERNAME%\...` を展開して保存し直さない）。
5. 反映には**新しいシェル**が必要（書き換え後に `WM_SETTINGCHANGE` は投げるが、起動済みの
   アプリは再起動が要る）。
