from __future__ import annotations

import subprocess
from typing import Callable

from ..context import AppContext


def run_safely(ctx: AppContext, fn: Callable[[AppContext], int]) -> int:
    try:
        return fn(ctx)
    except SystemExit as exc:
        message = exc.code if isinstance(exc.code, str) else ""
        if message:
            ctx.stderr.write(f"{message}\n")
        return exc.code if isinstance(exc.code, int) else 1
    except subprocess.CalledProcessError as exc:
        error_output = exc.stderr.strip() if exc.stderr else str(exc)
        ctx.stderr.write(f"{error_output}\n")
        return 1
