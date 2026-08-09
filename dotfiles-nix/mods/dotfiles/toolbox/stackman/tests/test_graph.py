from __future__ import annotations

import sys
import types
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))

if "stackman" not in sys.modules:
    package = types.ModuleType("stackman")
    package.__path__ = [str(SRC_DIR / "stackman")]
    sys.modules["stackman"] = package

from stackman.graph import descendant_closure, resolve_roots, topological_order


def test_topological_order_is_parent_before_child() -> None:
    parents = {
        "main": None,
        "branch_a": "main",
        "branch_b": "branch_a",
        "branch_c": "main",
        "branch_d": "branch_c",
    }

    assert topological_order(parents) == [
        "main",
        "branch_a",
        "branch_c",
        "branch_b",
        "branch_d",
    ]


def test_descendant_closure_includes_all_descendants_in_order() -> None:
    parents = {
        "main": None,
        "branch_a": "main",
        "branch_b": "branch_a",
        "branch_c": "main",
        "branch_d": "branch_c",
    }

    assert descendant_closure(["branch_a"], parents) == ["branch_a", "branch_b"]


def test_resolve_roots_returns_minimal_span() -> None:
    parents = {
        "main": None,
        "branch_a": "main",
        "branch_b": "branch_a",
        "branch_c": "main",
        "branch_d": "branch_c",
    }

    assert resolve_roots(["branch_b", "branch_d"], parents) == ["main"]
