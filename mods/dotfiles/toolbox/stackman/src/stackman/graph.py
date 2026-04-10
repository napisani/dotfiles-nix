from __future__ import annotations

from collections import defaultdict, deque
from collections.abc import Iterable, Mapping, Sequence


def topological_order(branch_parents: Mapping[str, str | None]) -> list[str]:
    children: dict[str, list[str]] = defaultdict(list)
    indegree: dict[str, int] = {branch: 0 for branch in branch_parents}

    for branch, parent in branch_parents.items():
        if parent is None:
            continue
        children[parent].append(branch)
        indegree.setdefault(parent, 0)
        indegree[branch] = indegree.get(branch, 0) + 1

    for sibling_list in children.values():
        sibling_list.sort()

    queue: deque[str] = deque(sorted(branch for branch, degree in indegree.items() if degree == 0))
    ordered: list[str] = []

    while queue:
        branch = queue.popleft()
        if branch in branch_parents:
            ordered.append(branch)
        for child in children.get(branch, []):
            indegree[child] -= 1
            if indegree[child] == 0:
                queue.append(child)

    if len(ordered) != len(branch_parents):
        missing = [branch for branch in branch_parents if branch not in ordered]
        raise ValueError(f"Cycle detected or disconnected graph: {missing!r}")

    return ordered


def descendant_closure(
    seeds: Iterable[str],
    branch_parents: Mapping[str, str | None],
) -> list[str]:
    seed_set = list(dict.fromkeys(seeds))
    children = _children_map(branch_parents)
    seen: set[str] = set()
    ordered: list[str] = []
    queue: deque[str] = deque(seed_set)

    while queue:
        branch = queue.popleft()
        if branch in seen:
            continue
        seen.add(branch)
        if branch in branch_parents:
            ordered.append(branch)
        for child in children.get(branch, []):
            if child not in seen:
                queue.append(child)

    return [branch for branch in topological_order(branch_parents) if branch in seen]


def resolve_roots(
    branches: Iterable[str],
    branch_parents: Mapping[str, str | None],
    *,
    trunk_names: Sequence[str] = ("main", "master"),
) -> list[str]:
    trunk_set = set(trunk_names)
    roots: list[str] = []
    seen: set[str] = set()

    for branch in branches:
        root = branch
        path_seen: set[str] = set()
        while True:
            if root in path_seen:
                raise ValueError(f"Cycle detected while resolving roots for {branch!r}")
            path_seen.add(root)
            parent = branch_parents.get(root)
            if parent is None:
                break
            if parent in trunk_set:
                root = parent
                break
            if parent not in branch_parents:
                break
            root = parent
        if root not in seen:
            seen.add(root)
            roots.append(root)

    return roots


def _children_map(branch_parents: Mapping[str, str | None]) -> dict[str, list[str]]:
    children: dict[str, list[str]] = defaultdict(list)
    for branch, parent in branch_parents.items():
        if parent is not None:
            children[parent].append(branch)
    for sibling_list in children.values():
        sibling_list.sort()
    return children
