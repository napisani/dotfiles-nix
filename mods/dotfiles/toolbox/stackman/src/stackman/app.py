from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence, TextIO

from .db import StackmanDb
from .git_ops import ParentCandidate, candidate_parent_branches, current_branch, merge_base, repo_root
from .prompts import PromptUnavailableError, select_parent_branch


ParentChooser = Callable[[str, Sequence[ParentCandidate]], ParentCandidate | str]


@dataclass(slots=True)
class StackmanApp:
    db_path: Path
    cwd: Path
    stdin: TextIO
    stdout: TextIO
    stderr: TextIO
    parent_chooser: ParentChooser | None = None

    def status(self) -> int:
        try:
            return self._run_status()
        except SystemExit as exc:
            message = exc.code if isinstance(exc.code, str) else ""
            if message:
                self.stderr.write(f"{message}\n")
            return exc.code if isinstance(exc.code, int) else 1
        except subprocess.CalledProcessError as exc:
            error_output = exc.stderr.strip() if exc.stderr else str(exc)
            self.stderr.write(f"{error_output}\n")
            return 1

    def init(self, *, parent: str | None = None, stacks: Sequence[str] = ()) -> int:
        try:
            return self._run_init(parent=parent, stacks=stacks)
        except SystemExit as exc:
            message = exc.code if isinstance(exc.code, str) else ""
            if message:
                self.stderr.write(f"{message}\n")
            return exc.code if isinstance(exc.code, int) else 1
        except subprocess.CalledProcessError as exc:
            error_output = exc.stderr.strip() if exc.stderr else str(exc)
            self.stderr.write(f"{error_output}\n")
            return 1

    def _run_status(self) -> int:
        database = StackmanDb(self.db_path)
        database.initialize()
        repository_root = repo_root(self.cwd)
        branch_name = current_branch(repository_root)
        tracked = database.get_branch(repository_root, branch_name)
        if tracked is None:
            self.stdout.write(
                f"Branch {branch_name!r} is not tracked in repo {repository_root}.\n"
            )
            return 1

        labels = database.list_branch_labels(repository_root, branch_name)
        parent_display = tracked.parent_branch_name or "<none>"
        labels_display = ", ".join(labels) if labels else "<none>"
        self.stdout.write(f"branch: {tracked.branch_name}\n")
        self.stdout.write(f"parent: {parent_display}\n")
        self.stdout.write(f"fork-point: {tracked.fork_point_sha}\n")
        self.stdout.write(f"labels: {labels_display}\n")
        return 0

    def _run_init(self, *, parent: str | None, stacks: Sequence[str]) -> int:
        database = StackmanDb(self.db_path)
        database.initialize()

        repository_root = repo_root(self.cwd)
        branch_name = current_branch(repository_root)
        parent_branch = parent or self._confirm_parent_branch(
            repository_root=repository_root,
            branch_name=branch_name,
            database=database,
        )
        fork_point_sha = merge_base(repository_root, branch_name, parent_branch)

        database.upsert_branch(
            repo_root=repository_root,
            branch_name=branch_name,
            parent_branch_name=parent_branch,
            fork_point_sha=fork_point_sha,
        )
        for stack_id in stacks:
            database.label_branch(repository_root, branch_name, stack_id)

        self.stdout.write(
            f"Tracked branch {branch_name!r} with parent {parent_branch!r} at {fork_point_sha[:7]}.\n"
        )
        return 0

    def _confirm_parent_branch(
        self,
        *,
        repository_root: Path,
        branch_name: str,
        database: StackmanDb,
    ) -> str:
        candidates = candidate_parent_branches(repository_root, current=branch_name)
        if not candidates:
            raise SystemExit("No plausible parent branches found. Re-run with --parent.")

        tracked_names = {
            branch.branch_name
            for branch in database.list_branches(repository_root)
        }
        decorated_candidates = [
            ParentCandidate(
                branch_name=candidate.branch_name,
                merge_base_sha=candidate.merge_base_sha,
                ahead=candidate.ahead,
                behind=candidate.behind,
                is_trunk=candidate.is_trunk,
                is_tracked=candidate.branch_name in tracked_names,
            )
            for candidate in candidates
        ]

        try:
            return select_parent_branch(
                decorated_candidates,
                current_branch=branch_name,
                is_tty=self.stdin.isatty(),
                chooser=self.parent_chooser,
            )
        except PromptUnavailableError as exc:
            raise SystemExit(str(exc)) from exc
