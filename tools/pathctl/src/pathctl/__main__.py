"""Allow `python -m pathctl` in addition to the `pathctl` console script."""

import sys

from .cli import main

if __name__ == "__main__":
    sys.exit(main())
