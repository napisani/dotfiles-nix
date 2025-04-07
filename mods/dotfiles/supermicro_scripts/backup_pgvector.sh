#!/bin/bash
set -e

me=$(whoami)
if [ "$me" != "root" ]; then
	echo "Please run as root"
	exit 1
fi

k3s kubectl exec -n home $(k3s kubectl get pods -n home | grep pgvector | awk '{ print $1 }') -- bash -c 'pg_dumpall -U homelab' >/media/storage/computer_backups/supermicro/pgvector_backup.sql
