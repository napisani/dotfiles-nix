
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
