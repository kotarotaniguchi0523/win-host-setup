"""Typed data model shared by the pathctl commands."""

from dataclasses import dataclass, field
from enum import StrEnum

type EntryList = list[PathEntry]
type ScopeMap = dict[Scope, EntryList]


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


class Severity(StrEnum):
    INFO = "info"
    WARN = "warn"
    ERROR = "error"


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
        return self.provenance in {ToolProvenance.MISE_SHIM, ToolProvenance.MISE_INSTALL}

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
