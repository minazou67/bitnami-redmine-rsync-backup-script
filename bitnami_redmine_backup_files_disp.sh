#!/bin/bash

readonly BACKUP_DIR=~/backup/redmine

echo "[Date]"
echo `date`
echo "[Host]"
echo `hostname`
echo "[Path]"
echo $BACKUP_DIR
echo "[Files]"
find $BACKUP_DIR -type f -printf "%f : %s\n" | sort
echo "[Total size]"
find $BACKUP_DIR -type f -printf "%s\n" | awk '{ sum += $1; }; END { print sum }'
