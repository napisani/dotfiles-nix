#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def pr_number(value: str) -> str:
    if not value.isascii() or not value.isdecimal() or int(value) < 1:
        raise argparse.ArgumentTypeError("expected a positive PR number")
    return str(int(value))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Open PRs with native Workmux behavior."
    )
    parser.add_argument("--purpose", required=True, choices=("development", "review"))
    parser.add_argument("prs", nargs="+", type=pr_number, metavar="PR")
    options = parser.parse_args(argv)
    failed = False
    for number in options.prs:
        command = ["workmux", "add", "--pr", number, "--open-if-exists"]
        if options.purpose == "review":
            command += [
                f"review/{number}",
                "--config",
                str(Path(__file__).with_name("workmux-review.json")),
                "--no-hooks",
                "--no-file-ops",
            ]
        try:
            if subprocess.run(command, check=False).returncode != 0:
                failed = True
        except OSError as error:
            print(
                f"workmux-pr: cannot start Workmux: {error.strerror}", file=sys.stderr
            )
            return 1
        except KeyboardInterrupt:
            return 130
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
