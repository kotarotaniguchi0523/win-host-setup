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
import re
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


_PIP_BASELINE: frozenset[str] = frozenset({"pip", "setuptools", "wheel", "pkg_resources"})


def pipx_strays() -> list[Stray]:
    """pipx venvs (the analysis docs list pipx as a legacy install path)."""
    root = _home() / ".local" / "pipx" / "venvs"
    return [
        Stray("pipx", name, str(root / name), "pipx ではなく mise の pypi: で宣言するか、SBX で実行してください")
        for name in _package_dirs(root)
    ]


def pip_user_strays() -> list[Stray]:
    """`pip install --user` leftovers under %APPDATA%\\Python."""
    root = Path(os.environ.get("APPDATA") or _home()) / "Python"
    if not root.is_dir():
        return []
    strays: list[Stray] = []
    for version in sorted(item for item in root.iterdir() if item.is_dir()):
        site = version / "site-packages"
        for name in _package_dirs(site):
            key = name.casefold()
            if key in _PIP_BASELINE or key.endswith((".dist-info", ".data", ".egg-info")):
                continue
            strays.append(
                Stray("pip", name, str(site / name), "pip --user ではなく venv / uv / SBX を使ってください")
            )
    return strays


# Binaries that rustup itself manages in ~/.cargo/bin (they are not `cargo install` leftovers).
_RUSTUP_BINARIES: frozenset[str] = frozenset(
    {
        "cargo", "rustc", "rustdoc", "rustup", "rustfmt", "cargo-clippy", "clippy-driver",
        "cargo-fmt", "cargo-miri", "rls", "rust-analyzer", "rust-gdb", "rust-gdbgui", "rust-lldb",
    }
)


def cargo_strays() -> list[Stray]:
    root = _home() / ".cargo" / "bin"
    if not root.is_dir():
        return []
    return [
        Stray("cargo", item.stem, str(item), "cargo install ではなく mise（cargo:）か SBX で実行してください")
        for item in sorted(root.glob("*.exe"))
        if item.stem.casefold() not in _RUSTUP_BINARIES
    ]


def go_strays() -> list[Stray]:
    root = _home() / "go" / "bin"
    if not root.is_dir():
        return []
    return [
        Stray("go", item.stem, str(item), "go install ではなく mise（go:）か SBX で実行してください")
        for item in sorted(root.glob("*.exe"))
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


# A directory that carries its version in the name, e.g. curl-8.7.1_7-win64-mingw or node-v26.11.1-win-x64.
_VERSIONED_DIR = re.compile(r"^[\w.+-]+-\d+(?:\.\d+)+", re.IGNORECASE)


def manual_install_paths(entries: list[PathEntry]) -> list[Stray]:
    """PATH entries pointing at an unpacked archive (a manual install nobody updates)."""
    strays: list[Stray] = []
    for entry in entries:
        if entry.empty:
            continue
        text = entry.raw.replace("/", "\\")
        lowered = text.casefold()
        if "\\winget\\" in lowered or "\\mise\\" in lowered:
            continue
        if any(_VERSIONED_DIR.match(part) for part in text.split("\\")):
            strays.append(
                Stray(
                    "manual",
                    text,
                    entry.value,
                    "バージョン付きの手動配置です。winget（DSC）か mise に移し、古い PATH を外してください",
                )
            )
    return strays


def collect(user_entries: list[PathEntry]) -> list[Stray]:
    return [
        *mise_strays(mise_global_json()),
        *npm_strays(),
        *uv_strays(),
        *pipx_strays(),
        *pip_user_strays(),
        *cargo_strays(),
        *go_strays(),
        *path_strays(user_entries),
        *manual_install_paths(user_entries),
    ]


def _finding(stray: Stray, *, severity: Severity) -> Finding:
    code = {
        "mise": FindingCode.STRAY_MISE_TOOL,
        "npm": FindingCode.STRAY_NPM_GLOBAL,
        "uv": FindingCode.STRAY_UV_TOOL,
        "pipx": FindingCode.STRAY_PIPX_VENV,
        "pip": FindingCode.STRAY_PIP_USER,
        "cargo": FindingCode.STRAY_CARGO_INSTALL,
        "go": FindingCode.STRAY_GO_INSTALL,
        "manual": FindingCode.MANUAL_INSTALL_PATH,
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
