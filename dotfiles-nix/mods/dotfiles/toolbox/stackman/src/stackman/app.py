from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence, TextIO

from .commands import discover, done, forget, listing, runner, status, sync, track
from .context import AppContext


@dataclass(slots=True)
class StackmanApp:
    """Thin façade over command modules (keeps CLI and tests on a single injectable object)."""

    db_path: Path
    cwd: Path
    stdin: TextIO
    stdout: TextIO
    stderr: TextIO
    stack_id_factory: Callable[[], str] | None = None

    def _ctx(self) -> AppContext:
        return AppContext(
            db_path=self.db_path,
            cwd=self.cwd,
            stdin=self.stdin,
            stdout=self.stdout,
            stderr=self.stderr,
            stack_id_factory=self.stack_id_factory,
        )

    def status(self, *, branch: str | None = None) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: status.run(c, branch=branch))

    def track(self, *, branch: str | None = None, parent: str) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: track.run_track(c, branch=branch, parent=parent))

    def chain(self, *, anchor: str, branches: Sequence[str]) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: track.run_chain(c, anchor=anchor, branches=branches))

    def sync(
        self,
        *,
        branch: str | None = None,
        dry_run: bool = False,
        verbose: bool = False,
        squash: bool = False,
        allow_dirty: bool = False,
    ) -> int:
        ctx = self._ctx()
        return runner.run_safely(
            ctx,
            lambda c: sync.run(
                c,
                branch=branch,
                dry_run=dry_run,
                verbose=verbose,
                squash=squash,
                allow_dirty=allow_dirty,
            ),
        )

    def list(self) -> int:
        return runner.run_safely(self._ctx(), listing.run_repo_list)

    def discover(self, *, pr_number: int, apply: bool = False) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: discover.run(c, pr_number=pr_number, apply=apply))

    def done(self, *, branch: str | None = None, dry_run: bool = False) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: done.run(c, branch=branch, dry_run=dry_run))

    def forget(self, *, branch: str | None = None) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: forget.run(c, branch=branch))
