from __future__ import annotations

from dataclasses import dataclass
import subprocess
from collections.abc import Sequence
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


def _run_git(
    cwd: Path,
    *args: str,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=check,
        capture_output=True,
        text=True,
    )


def git_output(cwd: Path, *args: str) -> str:
    return _run_git(cwd, *args, check=True).stdout.strip()


def working_tree_clean(cwd: Path) -> bool:
    return _run_git(cwd, "status", "--porcelain", check=True).stdout == ""


def rebase_in_progress(cwd: Path) -> bool:
    """Detect rebase state in this checkout (main or linked worktree)."""
    try:
        rel_m = git_output(cwd, "rev-parse", "--git-path", "rebase-merge")
        rel_a = git_output(cwd, "rev-parse", "--git-path", "rebase-apply")
    except subprocess.CalledProcessError:
        return False
    mpath = Path(rel_m)
    apath = Path(rel_a)
    if not mpath.is_absolute():
        mpath = (cwd / mpath).resolve()
    if not apath.is_absolute():
        apath = (cwd / apath).resolve()
    return mpath.is_dir() or apath.is_dir()


def iter_worktree_entries(cwd: Path) -> list[tuple[Path, str | None]]:
    """Each linked worktree: ``(path, branch_name)`` or ``(path, None)`` if detached."""
    text = git_output(cwd, "worktree", "list", "--porcelain")
    entries: list[tuple[Path, str | None]] = []
    cur: Path | None = None
    branch: str | None = None
    for raw in text.splitlines():
        if raw.startswith("worktree "):
            if cur is not None:
                entries.append((cur, branch))
            cur = Path(raw[len("worktree ") :].strip()).resolve()
            branch = None
        elif raw.startswith("branch "):
            ref = raw[len("branch ") :].strip()
            if ref.startswith("refs/heads/"):
                branch = ref.removeprefix("refs/heads/")
    if cur is not None:
        entries.append((cur, branch))
    return entries


def worktree_path_for_branch(cwd: Path, branch: str) -> Path | None:
    """Directory of the worktree that has ``branch`` checked out, if any."""
    for path, br in iter_worktree_entries(cwd):
        if br == branch:
            return path
    return None


def rebase_in_progress_any_linked(cwd: Path) -> bool:
    """True if a rebase is in progress in any worktree of this repository."""
    for path, _ in iter_worktree_entries(cwd):
        if rebase_in_progress(path):
            return True
    return False


def all_linked_worktrees_clean(cwd: Path) -> bool:
    """True if every linked worktree has a clean working tree."""
    for path, _ in iter_worktree_entries(cwd):
        if not working_tree_clean(path):
            return False
    return True


def sync_relevant_worktrees(start_worktree: Path, branch_names: Sequence[str]) -> list[Path]:
    """Worktrees ``stackman sync`` may touch: the starting tree plus each branch's checkout location."""
    root = repo_root(start_worktree)
    by_key: dict[str, Path] = {str(root.resolve()): root}
    for name in branch_names:
        holder = worktree_path_for_branch(root, name) or root
        by_key[str(holder.resolve())] = holder
    return list(by_key.values())


def worktree_dirty_preview(cwd: Path, *, max_lines: int = 20) -> str | None:
    """If the tree is dirty, return a short ``git status --porcelain`` excerpt; otherwise ``None``."""
    text = _run_git(cwd, "status", "--porcelain", check=True).stdout.strip()
    if not text:
        return None
    lines = text.splitlines()
    shown = lines[:max_lines]
    body = "\n".join(f"      {line}" for line in shown)
    extra = len(lines) - len(shown)
    if extra:
        body += f"\n      … ({extra} more porcelain lines)"
    return body


def rev_parse(cwd: Path, ref: str) -> str:
    return git_output(cwd, "rev-parse", ref)


def checkout(cwd: Path, branch: str) -> None:
    _run_git(cwd, "checkout", branch, check=True)


def rebase_onto(
    cwd: Path,
    *,
    onto: str,
    upstream: str,
) -> subprocess.CompletedProcess[str]:
    """Run `git rebase --onto onto upstream` on the current branch (non-interactive)."""
    return _run_git(
        cwd,
        "rebase",
        "--onto",
        onto,
        upstream,
        check=False,
    )


def upstream_branch(cwd: Path, branch: str) -> str | None:
    result = _run_git(
        cwd,
        "rev-parse",
        "--abbrev-ref",
        f"{branch}@{{upstream}}",
        check=False,
    )
    if result.returncode != 0:
        return None
    ref = result.stdout.strip()
    return ref or None


def push_force_with_lease_current_branch(cwd: Path) -> subprocess.CompletedProcess[str]:
    """Push current HEAD using its configured @{upstream} (if any)."""
    return _run_git(cwd, "push", "--force-with-lease", check=False)


def repo_root(cwd: Path) -> Path:
    """Top-level directory of the current worktree (where checkout/rebase run)."""
    return Path(git_output(cwd, "rev-parse", "--show-toplevel"))


def repo_db_key(cwd: Path) -> str:
    """Stable key for one Git repository across linked worktrees (shared object database)."""
    raw = git_output(cwd, "rev-parse", "--git-common-dir")
    path = Path(raw)
    resolved = path.resolve() if path.is_absolute() else (cwd / path).resolve()
    return str(resolved)


def format_repo_key_for_display(repo_key: str) -> str:
    """Prefer showing the main checkout path instead of the bare ``…/.git`` directory when possible."""
    path = Path(repo_key)
    if path.name == ".git":
        return str(path.parent)
    return repo_key


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
