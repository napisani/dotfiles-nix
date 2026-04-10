from __future__ import annotations

import sys
from pathlib import Path

import pytest

TEST_DIR = Path(__file__).resolve().parent
SRC_DIR = TEST_DIR.parent / "src"
for path in (SRC_DIR, TEST_DIR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from stackman.git_ops import ParentCandidate
from stackman.prompts import (
    PromptUnavailableError,
    build_parent_prompt,
    format_parent_candidate,
    select_parent_branch,
)


def test_format_parent_candidate_shows_branch_name_and_metadata() -> None:
    candidate = ParentCandidate(
        branch_name="branch_a",
        merge_base_sha="abc1234567890",
        ahead=1,
        behind=2,
        is_trunk=True,
        is_tracked=True,
    )

    rendered = format_parent_candidate(candidate)

    assert "branch_a" in rendered
    assert "abc1234" in rendered
    assert "trunk" in rendered
    assert "tracked" in rendered
    assert "ahead: 1 / behind: 2" in rendered


def test_build_parent_prompt_includes_context() -> None:
    candidates = [
        ParentCandidate("main", "abc1234567890", 0, 1, is_trunk=True),
        ParentCandidate("branch_a", "def4567890123", 1, 0),
    ]

    prompt = build_parent_prompt("branch_c", candidates)

    assert "Ambiguous parent branch for current branch `branch_c`." in prompt
    assert "Select the branch this work was based on:" in prompt
    assert "- main" in prompt
    assert "- branch_a" in prompt


def test_select_parent_branch_uses_injected_chooser() -> None:
    candidates = [
        ParentCandidate("main", "abc1234567890", 0, 1, is_trunk=True),
        ParentCandidate("branch_a", "def4567890123", 1, 0),
    ]

    selected = select_parent_branch(
        candidates,
        current_branch="branch_c",
        is_tty=False,
        chooser=lambda prompt, items: items[1],
    )

    assert selected == "branch_a"


def test_select_parent_branch_requires_tty_or_parent() -> None:
    with pytest.raises(PromptUnavailableError):
        select_parent_branch(
            [ParentCandidate("main", "abc1234567890", 0, 1, is_trunk=True)],
            current_branch="branch_c",
            is_tty=False,
        )
