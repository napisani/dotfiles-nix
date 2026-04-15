from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Sequence, TextIO

from .git_ops import ParentCandidate

ParentChooser = Callable[[str, Sequence[ParentCandidate]], ParentCandidate | str]


@dataclass(slots=True)
class AppContext:
    db_path: Path
    cwd: Path
    stdin: TextIO
    stdout: TextIO
    stderr: TextIO
    parent_chooser: ParentChooser | None = None
    stack_id_factory: Callable[[], str] | None = None
