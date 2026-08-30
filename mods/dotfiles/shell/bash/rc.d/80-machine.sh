# Machine-specific aliases and functions.
#
# Previously these lived in the per-host nix modules' shellAliases
# (homes/home-supermicro.nix). Keyed off MACHINE_NAME, which ~/.profile
# guarantees is set — from home-manager's session variables on a nix host, from
# `hostname -s` otherwise.
#
# Add a new branch here rather than in a nix module, so a host's shell behavior
# stays visible in the dotfiles rather than being generated somewhere else.

case "${MACHINE_NAME:-}" in
supermicro)
# pet: Back up homelab data
	alias backup-homelab='sudo --preserve-env=HOMELAB_BACKUP_RESTIC_PASSWORD /home/nick/toolbox/homelab_backup.py backup'
# pet: Follow the homelab GitOps sync service logs
	alias tail-gitops-sync='journalctl -fu gitops-sync.service'
# pet: Start Tailscale with the homelab route
	alias tailscaleup='sudo tailscale up --advertise-routes=192.168.1.0/24 --accept-routes'
	;;
esac
