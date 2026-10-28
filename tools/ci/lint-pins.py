#!/usr/bin/env python3
"""lint-pins.py - enforce exact pins in the declarations (shared by CI and local use)

Policy: nothing may float. Renovate (mise / GitHub Actions / Skills) and
winget-outdated.yml (winget DSC) are the only update paths, so every declaration
must name an exact version, or a full commit SHA for git refs. A `latest`, a range,
or a branch name silently removes the item from those update paths and lets the
host drift on its own.

Checks:
  mise/mise.toml, mise.toml  [tools] values are exact versions
  winget/host.dsc.yaml       every WinGetPackage has `version` (msstore excluded)
  skills/apm.yml             every owner/repo#ref is a 40-hex SHA or a version tag

Usage: python3 tools/ci/lint-pins.py [<repo-root>]
Exit code: 0=OK / 1=violation / 2=missing dependency
"""
from __future__ import annotations

import os
import re
import sys
import tomllib

try:
    import yaml  # PyYAML (bundled with GitHub Actions ubuntu runners; pip install pyyaml if missing)
except ModuleNotFoundError:  # pragma: no cover
    print("PyYAML が必要です: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

MISE_CONFIGS = ("mise/mise.toml", "mise.toml")
DSC = "winget/host.dsc.yaml"
APM = "skills/apm.yml"

# msstore is trusted by policy (AGENTS.md) and its packages are not version-pinnable.
DSC_EXCLUDED_SOURCES = {"msstore"}

SHA_RE = re.compile(r"^[0-9a-f]{40}$")
TAG_RE = re.compile(r"^v?\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z.\-+]+)?$")
FLOAT_RE = re.compile(r"[\^~*<>=]|\s|\|\||,\s")
WILDCARD_RE = re.compile(r"(?:^|\.)(?:x|X|\*)(?:\.|$)")

# Branch refs are normally forbidden (they float and Renovate cannot follow them).
# These upstreams publish no tags, so the only way to keep them APM-managed is a branch
# ref that `apm update` / the scheduled relock re-resolves into the lock. The map is
# explicit so a new floating ref cannot slip in: {repo: branch}.
APM_BRANCH_REF_ALLOW = {
    "nushell/nu_scripts": "main",
    "mizchi/explainer": "main",
}


def is_exact_version(value: str) -> bool:
    """True when the value names one exact version (no latest / range / wildcard)."""
    v = value.strip()
    if not v or v.lower() == "latest":
        return False
    if v.startswith("prefix:"):  # mise prefix: syntax resolves to the newest match
        return False
    if FLOAT_RE.search(v):
        return False
    if WILDCARD_RE.search(v):
        return False
    return True


def check_mise(root: str, errors: list[str]) -> None:
    for rel in MISE_CONFIGS:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            print(f"[i] skip（無い）: {rel}")
            continue
        with open(path, "rb") as fh:
            try:
                data = tomllib.load(fh)
            except tomllib.TOMLDecodeError as exc:
                errors.append(f"{rel}: TOML を解析できません: {exc}")
                continue
        tools = data.get("tools", {})
        bad = 0
        for name, spec in tools.items():
            values: list[object] = []
            if isinstance(spec, str):
                values = [spec]
            elif isinstance(spec, list):
                values = list(spec)
            elif isinstance(spec, dict):
                if "version" not in spec:
                    errors.append(f"{rel}: {name} に version がありません")
                    bad += 1
                    continue
                version = spec["version"]
                values = list(version) if isinstance(version, list) else [version]
            else:
                errors.append(f"{rel}: {name} の形式が不明です: {spec!r}")
                bad += 1
                continue

            for value in values:
                if not isinstance(value, str) or not is_exact_version(value):
                    errors.append(f"{rel}: {name} = {value!r} が厳密 pin ではありません")
                    bad += 1
        if bad == 0:
            print(f"[ok] {rel}（{len(tools)} ツールが厳密 pin）")


def check_dsc(root: str, errors: list[str]) -> None:
    path = os.path.join(root, DSC)
    if not os.path.exists(path):
        print(f"[i] skip（無い）: {DSC}")
        return
    with open(path, encoding="utf-8") as fh:
        try:
            data = yaml.safe_load(fh)
        except yaml.YAMLError as exc:
            errors.append(f"{DSC}: YAML を解析できません: {exc}")
            return
    resources = ((data or {}).get("properties") or {}).get("resources") or (data or {}).get("resources") or []
    checked = 0
    skipped = 0
    bad = 0
    for item in resources:
        if not isinstance(item, dict):
            continue
        if item.get("resource") != "Microsoft.WinGet.DSC/WinGetPackage":
            continue
        settings = item.get("settings") or {}
        package_id = settings.get("id", "<unknown>")
        if settings.get("source") in DSC_EXCLUDED_SOURCES:
            skipped += 1
            continue
        checked += 1
        version = settings.get("version")
        if version is None:
            errors.append(f"{DSC}: {package_id} に version がありません")
            bad += 1
        elif not isinstance(version, str) or not is_exact_version(version):
            errors.append(f"{DSC}: {package_id} の version {version!r} が厳密 pin ではありません")
            bad += 1
    if bad == 0:
        print(f"[ok] {DSC}（{checked} 件が厳密 pin / {skipped} 件は msstore として除外）")


def check_apm(root: str, errors: list[str]) -> None:
    path = os.path.join(root, APM)
    if not os.path.exists(path):
        print(f"[i] skip（無い）: {APM}")
        return
    with open(path, encoding="utf-8") as fh:
        try:
            data = yaml.safe_load(fh) or {}
        except yaml.YAMLError as exc:
            errors.append(f"{APM}: YAML を解析できません: {exc}")
            return
    entries: list[object] = []
    for section in ("dependencies", "devDependencies"):
        block = data.get(section) or {}
        if isinstance(block, dict):
            entries.extend(block.get("apm") or [])
    checked = 0
    pinned = 0
    on_branch = 0
    bad = 0
    for entry in entries:
        if isinstance(entry, dict):
            ref = entry.get("ref")
            name = entry.get("repo") or entry.get("url") or "<unknown>"
            if ref is None:
                errors.append(f"{APM}: {name} に ref がありません（ブランチ追従は不可）")
                bad += 1
                continue
        elif isinstance(entry, str):
            if "#" not in entry:
                errors.append(f"{APM}: {entry} に #ref がありません（ブランチ追従は不可）")
                bad += 1
                continue
            name, ref = entry.rsplit("#", 1)
        else:
            errors.append(f"{APM}: 解釈できない項目: {entry!r}")
            bad += 1
            continue

        checked += 1
        ref = str(ref).strip()
        name = str(name).strip()
        repo_key = "/".join(name.split("/")[:2])

        if SHA_RE.match(ref) or TAG_RE.match(ref):
            pinned += 1
            continue
        if APM_BRANCH_REF_ALLOW.get(repo_key) == ref:
            on_branch += 1
            continue

        allowed = APM_BRANCH_REF_ALLOW.get(repo_key)
        hint = (
            f"（このリポジトリで許すのは {allowed} のみ）"
            if allowed
            else "（40桁のコミット SHA かバージョンタグに固定してください）"
        )
        errors.append(f"{APM}: {name}#{ref} はブランチ名です{hint}")
        bad += 1
    if bad == 0:
        print(f"[ok] {APM}（{checked} 件: SHA/タグ {pinned} + APM 管理ブランチ {on_branch}）")


def main() -> int:
    root = (
        os.path.abspath(sys.argv[1])
        if len(sys.argv) > 1
        else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    )
    errors: list[str] = []

    check_mise(root, errors)
    check_dsc(root, errors)
    check_apm(root, errors)

    if errors:
        print("\n厳密 pin 違反:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        print("\n方針: 更新は Renovate / winget-outdated の PR 経由のみ。宣言は版を固定すること。", file=sys.stderr)
        return 1

    print("\n[ok] すべて厳密 pin（latest / 範囲 / ブランチ ref なし）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
