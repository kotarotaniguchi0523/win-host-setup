"""pathctl - Windows のグローバル PATH を点検・修復し、ツールの入手元を一覧する CLI。

標準ライブラリのみで動きます（実行時の依存なし）。型チェックは ty、実行環境は uv。
"""

from importlib.metadata import PackageNotFoundError, version

try:
    # Single source of truth: the version in pyproject.toml (installed distribution metadata).
    __version__ = version("pathctl")
except PackageNotFoundError:  # running straight from a source tree without an install
    __version__ = "0.0.0+unknown"

__all__ = ["__version__"]
