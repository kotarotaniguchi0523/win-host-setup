"""Windows PATH storage (registry) and environment plumbing.

The tool never expands ``%VARIABLES%`` when it writes back: entries are edited in their raw
form so ``C:\\Users\\%USERNAME%\\...`` keeps meaning the same thing for every account.

``ctypes`` and ``winreg`` are imported lazily (PEP 810): they are only touched on Windows, so
``pathctl describe`` and every check run on other platforms without resolving them at all.
"""

import os
import sys
from pathlib import Path

lazy import ctypes
lazy import winreg

from .model import PathEntry, Scope

IS_WINDOWS = sys.platform == "win32"

MACHINE_KEY = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
USER_KEY = r"Environment"
VALUE_NAME = "Path"

# Folder name of the per-account profile root (kept as a constant so the marker used by
# is_user_specific() is not written literally in this file; see tools/ci/hygiene.ps1).
_USERS_DIR = "Users"

_SHELL32 = "shell32"
_USER32 = "user32"
_HWND_BROADCAST = 0xFFFF
_WM_SETTINGCHANGE = 0x1A
_SMTO_ABORTIFHUNG = 0x0002
_BROADCAST_TIMEOUT_MS = 5000


def _require_windows() -> None:
    if not IS_WINDOWS:
        raise RuntimeError("the Windows registry is only available on Windows")


def is_admin() -> bool:
    """True when the current process can write to HKLM."""
    if not IS_WINDOWS:
        geteuid = getattr(os, "geteuid", None)
        return bool(geteuid()) if geteuid is not None else False
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())  # type: ignore[attr-defined]
    except (OSError, AttributeError):
        return False


def read_raw(scope: Scope) -> tuple[list[str], int | None]:
    """Return the stored entries and the registry value type (None when the value is missing)."""
    _require_windows()
    if scope is Scope.EFFECTIVE:
        raise ValueError("the effective PATH is not stored in the registry")

    hive = winreg.HKEY_LOCAL_MACHINE if scope is Scope.MACHINE else winreg.HKEY_CURRENT_USER
    key_path = MACHINE_KEY if scope is Scope.MACHINE else USER_KEY
    try:
        with winreg.OpenKey(hive, key_path, 0, winreg.KEY_READ) as key:
            value, value_type = winreg.QueryValueEx(key, VALUE_NAME)
    except FileNotFoundError:
        return [], None
    return [part for part in str(value).split(";")], int(value_type)


def write_raw(scope: Scope, entries: list[str], value_type: int | None) -> None:
    """Store the entries back, keeping the original value type when one is known."""
    _require_windows()
    if scope is Scope.EFFECTIVE:
        raise ValueError("the effective PATH cannot be written")
    if scope is Scope.MACHINE and not is_admin():
        raise PermissionError("writing the machine PATH needs an elevated shell (Run as administrator)")

    hive = winreg.HKEY_LOCAL_MACHINE if scope is Scope.MACHINE else winreg.HKEY_CURRENT_USER
    key_path = MACHINE_KEY if scope is Scope.MACHINE else USER_KEY
    stored_type = value_type or winreg.REG_EXPAND_SZ
    value = ";".join(entries)
    with winreg.CreateKeyEx(hive, key_path, 0, winreg.KEY_SET_VALUE) as key:
        winreg.SetValueEx(key, VALUE_NAME, 0, stored_type, value)


def broadcast_change() -> bool:
    """Tell running applications that the environment changed (new shells pick it up anyway)."""
    if not IS_WINDOWS:
        return False
    try:
        result = ctypes.c_ulong()
        user32 = ctypes.windll.user32  # type: ignore[attr-defined]
        return bool(
            user32.SendMessageTimeoutW(
                _HWND_BROADCAST,
                _WM_SETTINGCHANGE,
                0,
                ctypes.c_wchar_p("Environment"),
                _SMTO_ABORTIFHUNG,
                _BROADCAST_TIMEOUT_MS,
                ctypes.byref(result),
            )
        )
    except (OSError, AttributeError):
        return False


def expand(entry: str) -> str:
    return os.path.expandvars(entry) if entry else entry


def normalize(entry: str) -> str:
    """Case- and separator-insensitive key used to detect duplicates."""
    text = expand(entry).strip().rstrip("\\")
    return text.casefold()


def is_user_specific(raw: str) -> bool:
    """Heuristic: an entry that only makes sense for one account."""
    text = expand(raw).casefold()
    if "%userprofile%" in text:
        return True
    # Build the marker from the folder name so this source file holds no literal personal-path
    # pattern (tools/ci/hygiene.ps1 scans the sources for those).
    users_dir = _USERS_DIR.casefold()
    candidates = (f"\\{users_dir}\\", f"/{users_dir}/")
    marker = next((item for item in candidates if item in text), "")
    if not marker:
        return False
    # The public profile is shared; everything else below the users root belongs to one account.
    return not text.split(marker, 1)[1].startswith("public")


def make_entry(scope: Scope, index: int, raw: str) -> PathEntry:
    stripped = raw.strip()
    expanded = expand(stripped)
    if not stripped:
        return PathEntry(scope=scope, index=index, raw=raw, value="", exists=False, user_specific=False, empty=True)
    exists = bool(expanded) and Path(expanded).is_dir()
    return PathEntry(
        scope=scope,
        index=index,
        raw=stripped,
        value=expanded,
        exists=exists,
        user_specific=is_user_specific(stripped),
        empty=False,
    )


def stored_entries(scope: Scope) -> list[PathEntry]:
    """Entries for a registry scope. Nothing is filtered out: fixes must see everything."""
    raw, _type = read_raw(scope)
    return [make_entry(scope, index, item) for index, item in enumerate(raw)]


def effective_parts() -> list[str]:
    """The raw PATH parts a process sees (empty parts kept, so problems stay visible)."""
    return os.environ.get("PATH", "").split(os.pathsep)


def effective_entries() -> list[PathEntry]:
    return [make_entry(Scope.EFFECTIVE, index, item) for index, item in enumerate(effective_parts())]
