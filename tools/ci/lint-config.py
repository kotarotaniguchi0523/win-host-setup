#!/usr/bin/env python3
"""lint-config.py — リポジトリの設定ファイルの構文を検証する（CI・ローカル共用）

使い方: python3 tools/ci/lint-config.py [<repo-root>]
終了コード: 0=OK / 1=構文エラー
"""
from __future__ import annotations

import glob
import json
import os
import sys
import tomllib

try:
    import yaml  # PyYAML（GitHub Actions の ubuntu ランナーには同梱。無ければ pip install pyyaml）
except ModuleNotFoundError:  # pragma: no cover
    print("PyYAML が必要です: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..")
    )
    errors: list[str] = []

    def check(rel: str, loader, binary: bool = False) -> None:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            print(f"[i] skip（無い）: {rel}")
            return
        try:
            if binary:
                with open(path, "rb") as fh:
                    loader(fh)
            else:
                with open(path, encoding="utf-8") as fh:
                    loader(fh)
            print(f"[ok] {rel}")
        except Exception as exc:  # noqa: BLE001 - 構文エラーをまとめて報告する
            errors.append(f"{rel}: {exc}")
            print(f"[x] {rel}: {exc}")

    check("renovate.json", json.load)
    check("mise/mise.toml", tomllib.load, binary=True)
    check("winget/host.dsc.yaml", yaml.safe_load)
    check("skills/apm.yml", yaml.safe_load)
    check("skills/apm.lock.yaml", yaml.safe_load)

    for pattern in (".github/workflows/*.yml", ".github/workflows/*.yaml"):
        for path in sorted(glob.glob(os.path.join(root, pattern))):
            check(os.path.relpath(path, root), yaml.safe_load)

    for pattern in (".github/**/*.json",):
        for path in sorted(glob.glob(os.path.join(root, pattern), recursive=True)):
            check(os.path.relpath(path, root), json.load)

    if errors:
        print("\n構文エラー:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print("\n[ok] JSON / YAML / TOML すべて有効")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
