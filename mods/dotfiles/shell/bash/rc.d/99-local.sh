# Local, untracked overrides — always last.
#
# This is the escape hatch that replaces the old .bashrc.d/excludes.txt: rather
# than listing fragments to skip, override or unset whatever you want here.
# ~/.bashrc.local is deliberately not tracked, so machine-specific
# experiments never end up in a public mirror.

sh_source_if "$HOME/.bashrc.local"
