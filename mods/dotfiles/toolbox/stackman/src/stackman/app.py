from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence, TextIO

from .commands import init_command, merged, runner, stacks, status, sync
from .context import AppContext, ParentChooser


@dataclass(slots=True)
class StackmanApp:
    """Thin façade over command modules (keeps CLI and tests on a single injectable object)."""

    db_path: Path
    cwd: Path
    stdin: TextIO
    stdout: TextIO
    stderr: TextIO
    parent_chooser: ParentChooser | None = None
    stack_id_factory: Callable[[], str] | None = None

    def _ctx(self) -> AppContext:
        return AppContext(
            db_path=self.db_path,
            cwd=self.cwd,
            stdin=self.stdin,
            stdout=self.stdout,
            stderr=self.stderr,
            parent_chooser=self.parent_chooser,
            stack_id_factory=self.stack_id_factory,
        )

    def status(self) -> int:
        return runner.run_safely(self._ctx(), status.run)

    def init(self, *, parent: str | None = None, stacks: Sequence[str] = ()) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: init_command.run(c, parent=parent, stacks=stacks))

    def sync(
        self,
        *,
        stack_id: str | None = None,
        dry_run: bool = False,
        verbose: bool = False,
        squash: bool = False,
    ) -> int:
        ctx = self._ctx()
        return runner.run_safely(
            ctx,
            lambda c: sync.run(c, stack_id=stack_id, dry_run=dry_run, verbose=verbose, squash=squash),
        )

    def list_stacks(self) -> int:
        return runner.run_safely(self._ctx(), stacks.run_list_stacks)

    def stack_branches(self, stack_id: str) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: stacks.run_stack_branches(c, stack_id))

    def stack_unlabel(self, stack_id: str, *, branch: str | None) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: stacks.run_stack_unlabel(c, stack_id, branch=branch))

    def stack_delete(self, stack_id: str) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: stacks.run_stack_delete(c, stack_id))

    def merged(self, *, branch: str | None = None, dry_run: bool = False) -> int:
        ctx = self._ctx()
        return runner.run_safely(ctx, lambda c: merged.run(c, branch=branch, dry_run=dry_run))
