# Canonical machine name for this host, matching a homes/<machine> directory.
# POSIX sh: bootstrap.sh sources this before any bash is guaranteed.
sh_machine_name() {
	_machine_host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)
	# macOS display hostnames differ from the canonical names.
	case "$_machine_host" in
	Nicks-Loancrate-MacBook-Pro | nicks-loancrate-mbp) echo nicks-loancrate-mbp ;;
	nicks-mbp | Nicks-MacBook-Pro) echo nicks-mbp ;;
	*) echo "$_machine_host" ;;
	esac
	unset _machine_host
}
