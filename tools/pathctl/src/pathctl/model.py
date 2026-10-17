"""Typed data model shared by the pathctl commands."""

from dataclasses import dataclass, field
from enum import IntEnum, StrEnum
from typing import Final


class Scope(StrEnum):
    """Where a PATH value lives (or the combined view a process actually sees)."""

    MACHINE = "machine"
    USER = "user"
    EFFECTIVE = "effective"


class ToolProvenance(StrEnum):
    """Which mechanism makes a command available on the global PATH."""

    MISE_SHIM = "mise-shim"
    MISE_INSTALL = "mise-install"
    WINGET = "winget"
    NPM_GLOBAL = "npm-global"
    DIRECT = "direct"
    UNAVAILABLE = "unavailable"


# Frozen on purpose: a set literal inside a property would rebuild the set on every access
# (this is read once per tool per render), and frozenset is hashable so it stays a constant.
MISE_PROVENANCES: Final[frozenset[ToolProvenance]] = frozenset(
    {ToolProvenance.MISE_SHIM, ToolProvenance.MISE_INSTALL}
)


class Severity(StrEnum):
    INFO = "info"
    WARN = "warn"
    ERROR = "error"


class Exit(IntEnum):
    """Semantic exit codes (design principle 2: let the caller decide what to do next).

    HTTP-like categories so an agent can branch without parsing the message:
    ``0`` success, ``1`` unexpected failure, ``2`` usage, ``3`` not found,
    ``4`` configuration / permission, ``5`` validation (including findings to act on).
    """

    OK = 0
    FAILURE = 1
    USAGE = 2
    NOT_FOUND = 3
    CONFIG = 4
    VALIDATION = 5

    @property
    def category(self) -> str:
        return {
            Exit.OK: "ok",
            Exit.FAILURE: "general",
            Exit.USAGE: "usage",
            Exit.NOT_FOUND: "not_found",
            Exit.CONFIG: "config",
            Exit.VALIDATION: "validation",
        }[self]


@dataclass(frozen=True, slots=True)
class Error:
    """Actionable error payload (design principle 6: say what to run next)."""

    category: str
    message: str
    next_step: str | None = None
    candidates: tuple[str, ...] = ()
    required_args: tuple[str, ...] = ()

    def as_dict(self) -> dict[str, object]:
        payload: dict[str, object] = {"category": self.category, "message": self.message}
        if self.next_step:
            payload["next_step"] = self.next_step
        if self.candidates:
            payload["candidates"] = list(self.candidates)
        if self.required_args:
            payload["required_args"] = list(self.required_args)
        return payload


class FindingCode(StrEnum):
    """Stable identifiers for the checks, so agents can switch on them."""

    EMPTY_ENTRY = "empty-entry"
    DUPLICATE_IN_SCOPE = "duplicate-in-scope"
    DUPLICATE_ACROSS_SCOPES = "duplicate-across-scopes"
    USER_PATH_IN_MACHINE = "user-path-in-machine"
    MISSING_DIRECTORY = "missing-directory"
    TRAILING_SEPARATOR = "trailing-separator"
    MISE_SHIMS_NOT_FIRST = "mise-shims-not-first"
    TOOL_SHADOWED = "tool-shadowed"
    TOOL_NOT_ON_PATH = "tool-not-on-path"
    # audit: global installations that no declaration owns
    STRAY_MISE_TOOL = "stray-mise-tool"
    STRAY_NPM_GLOBAL = "stray-npm-global"
    STRAY_UV_TOOL = "stray-uv-tool"
    STRAY_PIPX_VENV = "stray-pipx-venv"
    STRAY_PIP_USER = "stray-pip-user"
    STRAY_CARGO_INSTALL = "stray-cargo-install"
    STRAY_GO_INSTALL = "stray-go-install"
    MANUAL_INSTALL_PATH = "manual-install-path"
    UNMANAGED_PATH_ENTRY = "unmanaged-path-entry"


@dataclass(frozen=True, slots=True)
class PathEntry:
    """One element of a PATH value, before and after expansion."""

    scope: Scope
    index: int
    raw: str
    value: str
    exists: bool
    user_specific: bool
    empty: bool

    @property
    def has_variable(self) -> bool:
        return "%" in self.raw


@dataclass(frozen=True, slots=True)
class Finding:
    """A single problem (or note) about the PATH."""

    code: FindingCode
    severity: Severity
    scope: Scope
    detail: str
    entries: tuple[str, ...] = ()
    hint: str | None = None


@dataclass(frozen=True, slots=True)
class Tool:
    """A command that could be used globally, and how it is reachable."""

    name: str
    provenance: ToolProvenance
    resolved: str | None
    found_in: tuple[str, ...] = ()
    shadowed_by: str | None = None

    @property
    def via_mise(self) -> bool:
        return self.provenance in MISE_PROVENANCES

    @property
    def without_mise(self) -> bool:
        """True when the command is reachable without any mise-managed directory."""
        return any("mise" not in part.lower() for part in self.found_in)

    @property
    def available(self) -> bool:
        return self.resolved is not None


@dataclass(frozen=True, slots=True)
class Report:
    """The envelope every command prints (human-readable or as JSON)."""

    command: str
    ok: bool
    data: dict[str, object] = field(default_factory=dict)
    findings: tuple[Finding, ...] = ()
    hints: tuple[str, ...] = ()
    kind: str = ""
    exit_code: int = 0
    error: Error | None = None
