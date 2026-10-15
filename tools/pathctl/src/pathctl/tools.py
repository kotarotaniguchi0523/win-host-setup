"""Discover the commands that are usable globally, and how they are reachable."""

import os
from dataclasses import dataclass
from pathlib import Path

from .model import PathEntry, Scope, Tool, ToolProvenance
from .winenv import effective_entries, stored_entries

EXECUTABLE_SUFFIXES: tuple[str, ...] = (".exe", ".cmd", ".bat", ".ps1", ".com", ".py")

# mise installs prefixes its own directories with the backend name
_BACKEND_PREFIXES: tuple[str, ...] = (
    "npm-",
    "pypi-",
    "cargo-",
    "go-",
    "github-",
    "gitlab-",
    "aqua-",
    "ubi-",
    "dotnet-",
    "core-",
    "http-",
    "vfox-",
)


@dataclass(frozen=True, slots=True)
class KnownDirs:
    """Directories whose contents identify how a tool was installed."""

    mise_shims: Path | None
    mise_installs: Path | None
    winget_packages: Path | None
    winget_links: Path | None
    npm_global: Path | None

    def classify(self, path: Path | None) -> ToolProvenance:
        if path is None:
            return ToolProvenance.UNAVAILABLE
        text = str(path).casefold()
        checks = (
            (self.mise_shims, ToolProvenance.MISE_SHIM),
            (self.mise_installs, ToolProvenance.MISE_INSTALL),
            (self.winget_links, ToolProvenance.WINGET),
            (self.winget_packages, ToolProvenance.WINGET),
            (self.npm_global, ToolProvenance.NPM_GLOBAL),
        )
        for root, provenance in checks:
            if root is not None and text.startswith(str(root).casefold()):
                return provenance
        return ToolProvenance.DIRECT


def _env_path(name: str) -> Path | None:
    value = os.environ.get(name)
    return Path(value) if value else None


def _child(root: Path | None, *parts: str) -> Path | None:
    if root is None:
        return None
    candidate = root.joinpath(*parts)
    return candidate if candidate.is_dir() else None


def known_dirs() -> KnownDirs:
    """Resolve the installation roots from the environment (None when the tool is absent)."""
    home = _env_path("USERPROFILE") or Path.home()
    local = _env_path("LOCALAPPDATA")
    roaming = _env_path("APPDATA")
    return KnownDirs(
        mise_shims=_child(local, "mise", "shims"),
        mise_installs=_child(local, "mise", "installs"),
        winget_packages=_child(local, "Microsoft", "WinGet", "Packages"),
        winget_links=_child(local, "Microsoft", "WinGet", "Links"),
        npm_global=_child(roaming, "npm"),
    )


def _names_from_files(root: Path | None, *, recursive_depth: int = 0) -> set[str]:
    if root is None:
        return set()
    names: set[str] = set()
    for path in root.iterdir():
        if path.is_dir() and recursive_depth > 0:
            names |= _names_from_files(path, recursive_depth=recursive_depth - 1)
        elif path.is_file() and path.suffix.casefold() in EXECUTABLE_SUFFIXES:
            names.add(path.stem)
    return names


def _strip_backend(name: str) -> str:
    for prefix in _BACKEND_PREFIXES:
        if name.startswith(prefix):
            return name[len(prefix) :]
    return name


def shim_names(dirs: KnownDirs) -> set[str]:
    return _names_from_files(dirs.mise_shims)


def mise_install_names(dirs: KnownDirs) -> set[str]:
    if dirs.mise_installs is None:
        return set()
    return {_strip_backend(item.name) for item in dirs.mise_installs.iterdir() if item.is_dir()}


def winget_names(dirs: KnownDirs) -> set[str]:
    # WinGet\Packages\<Id>_<Source>_<hash>\<payload...>\tool.exe
    return _names_from_files(dirs.winget_links) | _names_from_files(dirs.winget_packages, recursive_depth=3)


def npm_global_names(dirs: KnownDirs) -> set[str]:
    return _names_from_files(dirs.npm_global) - {"npm", "npx", "corepack"}


def find_all(name: str, entries: list[PathEntry]) -> list[Path]:
    """Every PATH entry that provides `name`, in PATH order (first match wins for the shell)."""
    found: list[Path] = []
    for entry in entries:
        if entry.empty:
            continue
        base = Path(entry.value)
        for suffix in ("", *EXECUTABLE_SUFFIXES):
            candidate = base / f"{name}{suffix}"
            if candidate.is_file():
                found.append(candidate)
                break
    return found


def search_entries() -> list[PathEntry]:
    """The PATH a new process receives: machine first, then user.

    The registry is the source of truth for "globally usable"; the PATH of the running process
    may be stale (an IDE or an installer can inject extra directories), so it is only a fallback.
    """
    try:
        return [*stored_entries(Scope.MACHINE), *stored_entries(Scope.USER)]
    except Exception:
        return effective_entries()


def inventory(*, names: set[str] | None = None) -> list[Tool]:
    """The global tool inventory: what is reachable, how, and whether mise is required."""
    dirs = known_dirs()
    entries = search_entries()
    shims = shim_names(dirs)
    installed = mise_install_names(dirs)
    candidates = names or (shims | installed | winget_names(dirs) | npm_global_names(dirs))

    tools: list[Tool] = []
    for name in sorted(candidates, key=str.casefold):
        found = find_all(name, entries)
        primary = found[0] if found else None
        provenance = dirs.classify(primary)
        if primary is None and name in installed:
            provenance = ToolProvenance.MISE_INSTALL
        shadowed = None
        if primary is not None and name in shims and not str(primary.parent).casefold().startswith(
            str(dirs.mise_shims).casefold() if dirs.mise_shims else "\0"
        ):
            shadowed = str(primary.parent)
        tools.append(
            Tool(
                name=name,
                provenance=provenance,
                resolved=str(primary) if primary else None,
                found_in=tuple(str(path.parent) for path in found),
                shadowed_by=shadowed,
            )
        )
    return tools
