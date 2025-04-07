#!/bin/bash
set -e
me=$(whoami)
if [ "$me" != "root" ]; then
	echo "Please run as root"
	exit 1
fi

fsck.hfsplus -f /dev/sde2
mount -t hfsplus -o remount,force,rw /dev/sde2 /media/backup
mount -t hfsplus -o force,rw /dev/sde2 /media/backup
touch /media/backup/test

rsync -rlv --delete --progress --size-only /media/storage/ /media/backup/storage
