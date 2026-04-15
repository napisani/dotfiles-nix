"""SQLite persistence for stackman (schema, repos, branches, stack labels)."""

from .branches import (
    delete_branch,
    get_branch,
    list_branches,
    list_branches_with_parent,
    update_branch_fork_point,
    upsert_branch,
)
from .repos import get_repo, upsert_repo
from .schema import initialize
from .stacks import (
    create_stack,
    delete_stack,
    label_branch,
    list_branch_labels,
    list_branch_names_with_stack_label,
    list_global_tracked_branches,
    list_labeled_branches_for_stack,
    list_stack_summaries,
    remove_branch_stack_label,
)

__all__ = [
    "initialize",
    "upsert_repo",
    "get_repo",
    "upsert_branch",
    "update_branch_fork_point",
    "get_branch",
    "list_branches",
    "list_branches_with_parent",
    "delete_branch",
    "create_stack",
    "label_branch",
    "list_branch_labels",
    "list_branch_names_with_stack_label",
    "list_stack_summaries",
    "list_global_tracked_branches",
    "list_labeled_branches_for_stack",
    "remove_branch_stack_label",
    "delete_stack",
]
