#!/bin/bash
set -e
me=$(whoami)
if [ "$me" != "root" ]; then
	echo "Please run as root"
	exit 1
fi
DIR="/media/storage/media"
echo "Fixing permissions on $DIR"

echo "Setting ownership to user 'nick' and group 'users' for $DIR"
chown -R nick:users $DIR
echo "Setting permissions for directories and files in $DIR"
find $DIR -type d -exec chmod 755 {} \;
echo "Setting permissions for files in $DIR"
find $DIR -type f -exec chmod 644 {} \;
echo "Done"
