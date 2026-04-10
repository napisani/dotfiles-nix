from __future__ import annotations

from dataclasses import dataclass
import subprocess
from pathlib import Path


@dataclass(frozen=True, slots=True)
class ParentCandidate:
    branch_name: str
    merge_base_sha: str
    ahead: int
    behind: int
    is_trunk: bool = False
    is_tracked: bool = False

    @property
    def likelihood_score(self) -> int:
        return (self.behind * 5) + self.ahead


def _run_git(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )


def git_output(cwd: Path, *args: str) -> str:
    return _run_git(cwd, *args).stdout.strip()


def repo_root(cwd: Path) -> Path:
    return Path(git_output(cwd, "rev-parse", "--show-toplevel"))


def current_branch(cwd: Path) -> str:
    return git_output(cwd, "branch", "--show-current")


def local_branches(cwd: Path) -> list[str]:
    output = git_output(cwd, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    return [line for line in output.splitlines() if line]


def branch_exists(cwd: Path, branch: str) -> bool:
    result = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def merge_base(cwd: Path, left: str, right: str) -> str:
    return git_output(cwd, "merge-base", left, right)


def is_ancestor(cwd: Path, older: str, newer: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", older, newer],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def ahead_behind(cwd: Path, left: str, right: str) -> tuple[int, int]:
    output = git_output(cwd, "rev-list", "--left-right", "--count", f"{left}...{right}")
    ahead_s, behind_s = output.split()
    return int(ahead_s), int(behind_s)


def candidate_parent_branches(
    cwd: Path,
    *,
    current: str | None = None,
    trunk_branches: tuple[str, ...] = ("main", "master"),
    limit: int = 25,
) -> list[ParentCandidate]:
    if current is None:
        current = current_branch(cwd)

    candidates: list[ParentCandidate] = []
    for branch in local_branches(cwd):
        if branch == current:
            continue

        try:
            base = merge_base(cwd, current, branch)
        except subprocess.CalledProcessError:
            continue

        ahead, behind = ahead_behind(cwd, branch, current)
        candidates.append(
            ParentCandidate(
                branch_name=branch,
                merge_base_sha=base,
                ahead=ahead,
                behind=behind,
                is_trunk=branch in trunk_branches,
            )
        )

    candidates.sort(
        key=lambda candidate: (
            candidate.likelihood_score,
            candidate.behind,
            candidate.ahead,
            not candidate.is_trunk,
            candidate.branch_name,
        )
    )
    return candidates[:limit]
