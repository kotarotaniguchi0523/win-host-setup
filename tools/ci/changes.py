"""Select CI jobs from the complete Git diff, without GitHub's path-list limits."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess


def classify(paths: list[str], *, all_jobs: bool = False) -> dict[str, bool]:
    shared = {
        "mise.toml", "mise.lock", "tools/lib/common.ps1", "tools/ci/changes.py",
        "tools/ci/tests/test_changes.py",
    }
    result = dict.fromkeys(("mise", "config", "python", "actions"), all_jobs)
    for path in paths:
        if path in shared:
            result = dict.fromkeys(result, True)
        if path.startswith("mise/") or path in {
            "tools/ci/mise-verify.ps1", ".github/workflows/validate.yml",
            ".github/workflows/relock.yml", ".github/workflows/healthcheck.yml",
        }:
            result["mise"] = True
        if path.endswith((".json", ".yaml", ".yml", ".toml")) or path in {
            "tools/ci/lint-config.py", "tools/ci/lint-pins.py",
            ".github/workflows/validate.yml",
        }:
            result["config"] = True
        if path.startswith(("tools/pathctl/", "tools/ci/tests/")) or path in {
            ".github/workflows/validate.yml", ".github/workflows/release.yml",
        }:
            result["python"] = True
        if path.startswith((".github/", "tools/lint/")):
            result["actions"] = True
    return result


def changed_paths(event: dict, event_name: str) -> list[str] | None:
    if event_name == "workflow_dispatch":
        return None
    if event_name == "pull_request":
        base, head = (event["pull_request"][part]["sha"] for part in ("base", "head"))
        separator = "..."
    elif event_name == "push":
        base, head = event["before"], event["after"]
        separator = ".."
        if base == "0" * 40:
            return None
    else:
        raise ValueError(f"Unsupported CI event: {event_name}")
    if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head)):
        raise ValueError("Expected immutable commit SHAs")
    diff = subprocess.check_output([
        "git", "diff", "--name-only", "--no-renames", "-z", f"{base}{separator}{head}", "--",
    ])
    return [p.decode("utf-8") for p in diff.split(b"\0") if p]


def main() -> None:
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    paths = changed_paths(event, os.environ["GITHUB_EVENT_NAME"])
    jobs = classify(paths or [], all_jobs=paths is None)
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for name, enabled in jobs.items():
            output.write(f"{name}={str(enabled).lower()}\n")
    print(json.dumps(jobs))


if __name__ == "__main__":
    main()
