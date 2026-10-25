---
description: public の更新を取り込み、失敗したら診断・修復して再検証する
agent: host-fixer
subagent: false
---

ホスト更新を実行し、失敗した場合だけ原因を診断して修復してください。

手順:

1. `pwsh -NoProfile -File tools/run-task.ps1 -Task update` を実行する
   （`MISE_SAFE` はラッパーが自プロセスだけ解除する）。
2. 成功したら、レポート `.agent/update-report.json` の要点（ok / warn / ng、更新されたバージョン）だけを日本語で報告して終了する。
3. 失敗したら `.agent/update-report.json` と `%LOCALAPPDATA%\win-host-setup\logs\last-run.json`（およびその log）を読む。
4. **最初に失敗したチェック**を特定し、既知の問題か確認する
   （`tools/skills-apply.ps1` のコメント、`PLAN.md`、`tools/verify-host.ps1`）。
5. リポジトリ内のファイルだけを最小限修正する。winget の直接操作、major のマージ、force push、Secrets の参照は禁止。
6. `pwsh -NoProfile -File tools/run-task.ps1 -Task verify` で再検証する。
7. 「原因 / 修正 / 再検証 / 残課題」を日本語で報告する。コミットはしない。

引数（任意）: $ARGUMENTS
