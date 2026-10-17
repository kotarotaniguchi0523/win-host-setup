"""Plan and apply safe repairs to a stored PATH scope.

Nothing is written unless the caller asks for it: ``plan`` is pure, ``apply`` is the only
function that touches the registry, and it refuses machine-scope writes without elevation.
"""

from dataclasses import dataclass, field

lazy from pathlib import Path

from .model import Scope
from .winenv import broadcast_change, expand, is_admin, normalize, read_raw, write_raw


@dataclass(slots=True)
class FixPlan:
    """The intended change for one scope (``before`` -> ``after``)."""

    scope: Scope
    before: list[str]
    after: list[str]
    actions: list[str] = field(default_factory=list)
    moved: list[str] = field(default_factory=list)
    value_type: int | None = None

    @property
    def changed(self) -> bool:
        return self.before != self.after

    @property
    def needs_admin(self) -> bool:
        return self.scope is Scope.MACHINE

    def as_dict(self) -> dict[str, object]:
        # Precompute the key sets once: rebuilding them inside the comprehensions would be O(n^2).
        before_keys = {normalize(item) for item in self.before}
        after_keys = {normalize(item) for item in self.after}
        return {
            "scope": self.scope.value,
            "changed": self.changed,
            "actions": list(self.actions),
            "removed": [item for item in self.before if normalize(item) not in after_keys],
            "added": [item for item in self.after if normalize(item) not in before_keys],
            "moved_to_user": list(self.moved),
            "before_count": len(self.before),
            "after_count": len(self.after),
        }


def _canonical(raw: str) -> str:
    text = raw.strip()
    if len(text) > 3 and text.endswith("\\"):
        return text.rstrip("\\")
    return text


def plan(
    scope: Scope,
    *,
    user_entries: list[str] | None = None,
    move_user_entries: bool = False,
    prune_missing: bool = False,
) -> FixPlan:
    """Compute the fixed entry list for `scope` without writing anything."""
    raw, value_type = read_raw(scope)
    plan_ = FixPlan(scope=scope, before=list(raw), after=[], value_type=value_type)
    seen: set[str] = set()
    user_keys = {normalize(item) for item in (user_entries or [])}

    for item in raw:
        text = item.strip()
        if not text:
            plan_.actions.append("空のエントリを削除")
            continue
        canonical = _canonical(text)
        if canonical != text:
            plan_.actions.append(f"末尾の区切りを整理: {text} -> {canonical}")
        key = normalize(canonical)
        if key in seen:
            plan_.actions.append(f"重複を削除: {canonical}")
            continue
        if move_user_entries and scope is Scope.MACHINE:
            from .winenv import is_user_specific

            if is_user_specific(canonical):
                if key in user_keys:
                    plan_.actions.append(f"ユーザー PATH に既にあるため削除: {canonical}")
                else:
                    plan_.actions.append(f"ユーザー PATH へ移動: {canonical}")
                    plan_.moved.append(canonical)
                    user_keys.add(key)
                continue
        if prune_missing and not Path(expand(canonical)).is_dir():
            plan_.actions.append(f"存在しないため削除: {canonical}")
            continue
        seen.add(key)
        plan_.after.append(canonical)
    return plan_


def merged_user_entries(current_user: list[str], moved: list[str]) -> list[str]:
    """Append moved entries to the user PATH, keeping the mise shims on top of the added ones."""
    keys = {normalize(item) for item in current_user}
    result = [item for item in current_user if normalize(item)]
    for item in moved:
        if normalize(item) not in keys:
            result.append(item)
            keys.add(normalize(item))
    return result


def apply(plan_: FixPlan, *, current_user: list[str] | None = None, announce: bool = True) -> bool:
    """Write the plan (and the moved entries). Returns True when the registry changed."""
    if not plan_.changed and not plan_.moved:
        return False
    if plan_.needs_admin and not is_admin():
        raise PermissionError("機械 PATH の変更には管理者権限が必要です（管理者として実行してください）")
    if plan_.changed:
        write_raw(plan_.scope, plan_.after, plan_.value_type)
    if plan_.moved:
        user_raw, user_type = read_raw(Scope.USER)
        merged = merged_user_entries(current_user or user_raw, plan_.moved)
        write_raw(Scope.USER, merged, user_type)
    if announce:
        broadcast_change()
    return True


def add_entry(scope: Scope, directory: str, *, prepend: bool = False) -> FixPlan:
    raw, value_type = read_raw(scope)
    plan_ = FixPlan(scope=scope, before=list(raw), after=list(raw), value_type=value_type)
    key = normalize(directory)
    if key not in {normalize(item) for item in raw}:
        if prepend:
            plan_.after.insert(0, _canonical(directory))
            plan_.actions.append(f"先頭に追加: {directory}")
        else:
            plan_.after.append(_canonical(directory))
            plan_.actions.append(f"追加: {directory}")
    return plan_


def remove_entry(scope: Scope, directory: str) -> FixPlan:
    raw, value_type = read_raw(scope)
    key = normalize(directory)
    plan_ = FixPlan(scope=scope, before=list(raw), after=[], value_type=value_type)
    for item in raw:
        if normalize(item) == key:
            plan_.actions.append(f"削除: {item}")
            continue
        plan_.after.append(item)
    return plan_
