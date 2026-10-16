"""Bundled guides, readable without a web fetch (`pathctl docs list` / `pathctl docs show <name>`).

The text lives next to the code (``pathctl/docs/*.md``) so it ships inside the wheel and always
matches the version that is running. Keep each file short: agents pay for every token.
"""

from importlib.resources import files
from typing import Final, NamedTuple

DOC_EXTENSION: Final = ".md"
PACKAGE: Final = "pathctl"
DOCS_DIR: Final = "docs"


class DocError(LookupError):
    """Raised when a guide does not exist."""


class Guide(NamedTuple):
    """A bundled guide: name and one-line summary.

    A frozen record on purpose: it is a value (hashable, comparable, unpackable) and never mutated.
    """

    name: str
    summary: str


_SUMMARIES: Final[dict[str, str]] = {
    "overview": "何をする CLI か、インストール方法、代表的な使い方",
    "agents": "エージェント向けの契約（終了コード / JSON / 探索順序 / 安全策）",
    "path-editing": "グローバル PATH を安全に書き換える手順（管理者権限・変数・反映）",
}


def available() -> tuple[Guide, ...]:
    """(name, one-line summary) for every bundled guide, sorted by name."""
    return tuple(Guide(name, _SUMMARIES.get(name, "")) for name in sorted(_SUMMARIES))


def _path(name: str):
    return files(PACKAGE).joinpath(DOCS_DIR, f"{name}{DOC_EXTENSION}")


def is_known(name: str) -> bool:
    return name in _SUMMARIES


def read(name: str) -> str:
    """Return the guide text. Raises DocError for an unknown name."""
    if not is_known(name):
        raise DocError(name)
    return _path(name).read_text(encoding="utf-8")
