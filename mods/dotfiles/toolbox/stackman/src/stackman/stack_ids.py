"""Opaque stack identifiers (auto-assigned when the user omits ``--stack``)."""

from __future__ import annotations

import secrets

# Docker-style short id: 12 hex chars, prefixed so user-chosen ids rarely collide.
_AUTO_PREFIX = "sm_"


def new_auto_stack_id() -> str:
    return _AUTO_PREFIX + secrets.token_hex(6)
