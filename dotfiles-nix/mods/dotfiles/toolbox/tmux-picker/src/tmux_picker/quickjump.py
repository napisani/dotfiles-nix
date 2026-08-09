"""Bracketed quickjump tags for the picker's session list.

Tags are drawn from a home-row-reach-ordered alphabet and assigned fresh on
every render (no persistence) -- they're a fast, typeable convenience to
narrow the fzf list, not a stable per-session identity.
"""

import itertools

KEYS = "fjdkslgheirutycnvmowa;qp"


def assign_tags(sessions: list[str]) -> list[tuple[str, str]]:
    """(session, tag) pairs in the given order. Tag length starts at 2 and
    scales up only if there are more sessions than KEYS**n allows."""
    n = 2
    while len(KEYS) ** n < len(sessions):
        n += 1
    tags = itertools.islice(
        ("".join(combo) for combo in itertools.product(KEYS, repeat=n)),
        len(sessions),
    )
    return list(zip(sessions, tags))
