# Local, untracked overrides — always last.
#
# Override or unset whatever any earlier fragment set.
# ~/.bashrc.local is deliberately not tracked, so machine-specific
# experiments never end up in a public mirror.

sh_source_if "$HOME/.bashrc.local"
