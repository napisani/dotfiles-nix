#!/bin/bash
set -e

me=$(whoami)
if [ "$me" != "root" ]; then
	echo "Please run as root"
	exit 1
fi

k3s kubectl exec -n home $(k3s kubectl get pods -n home | grep mongo | awk '{ print $1 }') -- /usr/bin/mongodump --uri 'mongodb://localhost:27017' --archive >/media/storage/computer_backups/supermicro/mongo_backup.dump
