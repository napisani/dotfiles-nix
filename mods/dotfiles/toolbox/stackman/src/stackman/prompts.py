from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Sequence

from .git_ops import ParentCandidate


class PromptUnavailableError(RuntimeError):
    pass


def format_parent_candidate(candidate: ParentCandidate) -> str:
    parts = [
        candidate.branch_name,
        f"merge-base: {candidate.merge_base_sha[:7]}",
    ]
    if candidate.is_trunk:
        parts.append("trunk")
    if candidate.is_tracked:
        parts.append("tracked")
    parts.append(f"ahead: {candidate.ahead} / behind: {candidate.behind}")
    return "  ".join(parts)


def build_parent_prompt(current_branch: str, candidates: Sequence[ParentCandidate]) -> str:
    lines = [
        f"Ambiguous parent branch for current branch `{current_branch}`.",
        "Select the branch this work was based on:",
    ]
    for candidate in candidates:
        lines.append(f"- {format_parent_candidate(candidate)}")
    return "\n".join(lines)


def select_parent_branch(
    candidates: Sequence[ParentCandidate],
    *,
    current_branch: str,
    is_tty: bool,
    chooser: Callable[[str, Sequence[ParentCandidate]], ParentCandidate | str] | None = None,
) -> str:
    if chooser is not None:
        selected = chooser(build_parent_prompt(current_branch, candidates), candidates)
        return selected.branch_name if isinstance(selected, ParentCandidate) else str(selected)

    if not is_tty:
        raise PromptUnavailableError("Ambiguous parent selection requires --parent when no TTY is available.")

    try:
        from InquirerPy import inquirer
    except ModuleNotFoundError as exc:  # pragma: no cover - optional runtime dependency
        raise PromptUnavailableError("InquirerPy is required for interactive parent selection.") from exc

    choices = [
        {
            "name": format_parent_candidate(candidate),
            "value": candidate.branch_name,
        }
        for candidate in candidates
    ]
    answer = inquirer.select(
        message=build_parent_prompt(current_branch, candidates),
        choices=choices,
    ).execute()
    return str(answer)
