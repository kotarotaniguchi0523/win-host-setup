"""Find global installations that no declaration owns ("stray" globals).

The host keeps every global tool in one of two declarations:

* ``~/.config/mise/config.toml`` (mise) - the default for CLI/runtimes
* ``winget/host.dsc.yaml`` in this repository (winget) - for the exceptions

Anything else is a *stray* global: it exists on the machine, nobody reported it, and it will rot.
``pathctl audit`` lists those so they can be moved to mise, declared in winget, or pushed into a
sandbox (Docker Sandboxes / ``sbx``) instead of the host.
"""

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .model import Finding, FindingCode, PathEntry, Scope, Severity

# PATH roots that are managed on purpose (mise shims, winget, uv tools, OS locations).
# Kept as documentation of the policy; the matching logic lives in _is_allowed().
_ALLOWED_SUFFIXES: tuple[str, ...] = (
    "\\mise\\shims",
    "\\microsoft\\winget\\links",
    "\\microsoft\\windowsapps",
    "\\.local\\bin",  # uv tool install
)


@dataclass(frozen=True, slots=True)
class Stray:
    """One global installation that no declaration owns."""

    kind: str  # mise / npm / uv / path
    name: str
    location: str
    hint: str


def _home() -> Path:
    return Path(os.environ.get("USERPROFILE") or Path.home())


def mise_config() -> Path:
    return _home() / ".config" / "mise" / "config.toml"


def _norm(path: str) -> str:
    return path.replace("\\", "/").casefold()


def mise_global_json() -> dict[str, object] | None:
    """`mise ls -g --json` (None when mise is unavailable, e.g. inside a sandbox)."""
    try:
        proc = subprocess.run(
            ["mise", "ls", "-g", "--json"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def mise_strays(data: dict[str, object] | None) -> list[Stray]:
    """Tools installed globally by mise but coming from a config other than the global one."""
    if not data:
        return []
    config = _norm(str(mise_config()))
    strays: list[Stray] = []
    for tool, versions in data.items():
        if not isinstance(versions, list):
            continue
        for entry in versions:
            if not isinstance(entry, dict):
                continue
            source = entry.get("source")
            path = _norm(str(source.get("path", ""))) if isinstance(source, dict) else ""
            if path and path != config:
                strays.append(
                    Stray(
                        kind="mise",
                        name=str(tool),
                        location=path,
                        hint="~/.config/mise/config.toml に宣言する（mise use -g）か、SBX へ移してください",
                    )
                )
    return strays


def _package_dirs(root: Path | None) -> list[str]:
    if root is None or not root.is_dir():
        return []
    return sorted(item.name for item in root.iterdir() if item.is_dir() and not item.name.startswith("."))


def npm_strays() -> list[Stray]:
    root = Path(os.environ.get("APPDATA") or _home()) / "npm" / "node_modules"
    return [
        Stray("npm", name, str(root / name), "npm -g ではなく mise の npm: バックエンドで宣言するか、SBX で実行してください")
        for name in _package_dirs(root)
    ]


def uv_strays() -> list[Stray]:
    root = Path(os.environ.get("LOCALAPPDATA") or _home()) / "uv" / "tools"
    return [
        Stray("uv", name, str(root / name), "uv tool は mise で宣言できないため、常用しないなら削除して SBX で実行してください")
        for name in _package_dirs(root)
    ]


def _is_allowed(entry: PathEntry) -> bool:
    text = entry.raw.casefold().rstrip("\\")
    # Anything below Program Files / Windows is an OS or application install.
    if text.startswith(("c:\\program files\\", "c:\\program files (x86)\\", "c:\\windows\\")):
        return True
    # Specific managed directories (winget package payloads can have a subdirectory).
    if "\\microsoft\\winget\\packages\\" in text:
        return True
    return any(
        text.endswith(suffix)
        for suffix in ("\\mise\\shims", "\\microsoft\\winget\\links", "\\microsoft\\windowsapps", "\\.local\\bin")
    )


def path_strays(entries: list[PathEntry]) -> list[Stray]:
    """User PATH entries outside the managed roots (informational: app installers add these)."""
    return [
        Stray("path", entry.raw, entry.value, "アプリ付属の PATH です。不要なら path remove で外せます")
        for entry in entries
        if entry.scope is Scope.USER and not entry.empty and not _is_allowed(entry)
    ]


def collect(user_entries: list[PathEntry]) -> list[Stray]:
    return [*mise_strays(mise_global_json()), *npm_strays(), *uv_strays(), *path_strays(user_entries)]


def _finding(stray: Stray, *, severity: Severity) -> Finding:
    code = {
        "mise": FindingCode.STRAY_MISE_TOOL,
        "npm": FindingCode.STRAY_NPM_GLOBAL,
        "uv": FindingCode.STRAY_UV_TOOL,
        "path": FindingCode.UNMANAGED_PATH_ENTRY,
    }[stray.kind]
    return Finding(
        code=code,
        severity=severity,
        scope=Scope.USER,
        detail=f"{stray.kind}: {stray.name}（{stray.location}）",
        entries=(stray.location,),
        hint=stray.hint,
    )


def findings(strays: list[Stray]) -> list[Finding]:
    """Warnings for package-manager strays, info for PATH entries added by app installers."""
    return [_finding(stray, severity=Severity.INFO if stray.kind == "path" else Severity.WARN) for stray in strays]
