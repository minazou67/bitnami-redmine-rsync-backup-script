#!/bin/bash

readonly BITNAMI_ROOT=/opt/redmine-3.1.0-0
readonly REDMINE_ROOT=$BITNAMI_ROOT/apps/redmine/htdocs
readonly BACKUP_DIR=~/backup/redmine

readonly MOUNT_DEVICE=//192.168.100.100/backup
readonly MOUNT_DIR=/mnt/cifs
readonly MOUNT_SYNC_DIR=$MOUNT_DIR/redmine
readonly MOUNT_USR="user"
readonly MOUNT_PWD="password"

readonly DB_USR="bitnami"
readonly DB_PWD="password"
readonly DB_NAME="bitnami_redmine"

readonly MAIL_FROM="backup@example.com"
readonly MAIL_TO="backup@example.com"

result=""
error_msg=""
error_dtl=""

# E-mail transmission function
function send_mail() {
  if [ $? -ne 0 ]; then
    /usr/sbin/sendmail -i -t << EOF
From: $MAIL_FROM
To: $MAIL_TO
Subject: Failed to backup of bitnami redmine!
Content-Type: text/plain;charset="UTF-8"

Failed to backup of bitnami redmine!

Please contact the server administrator.

Date:        `date`
Host:        $HOSTNAME
Description: $error_msg
Details:     $error_dtl
EOF
  fi
  return 0
}

# Trap the end of the script
trap send_mail EXIT

# Check whether the root user
if [ $UID -ne 0 ]; then
  error_msg="This script requires root privileges"
  exit 1
fi

# Stop bitnami redmine service
result=$($BITNAMI_ROOT/ctlscript.sh stop apache 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to stop the bitnami redmine service"
  error_dtl=$result
  exit 1
fi

# Backup database
result=$($BITNAMI_ROOT/mysql/bin/mysqldump -u $DB_USR -p$DB_PWD $DB_NAME 2>&1 > $BACKUP_DIR/redmine_db_`date +%Y%m%d`.dump)
if [ $? -ne 0 ]; then
  error_msg="Failed to back up the database"
  error_dtl=$result
  exit 1
fi

# Compress of the backup file
result=$(gzip -f $BACKUP_DIR/redmine_db_`date +%Y%m%d`.dump 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to compression of the backup file"
  error_dtl=$result
  exit 1
fi

# Backup data files
result=$(tar -czf $BACKUP_DIR/redmine_files_`date +%Y%m%d`.tgz $REDMINE_ROOT/files 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to backup data files"
  error_dtl=$result
  exit 1
fi

# Remove old archive
find $BACKUP_DIR -name "redmine_db_*" -mtime +5 -exec rm {} \;
find $BACKUP_DIR -name "redmine_files_*" -mtime +5 -exec rm {} \;

# Start bitnami redmine service
result=$($BITNAMI_ROOT/ctlscript.sh start apache 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to stop the bitnami redmine service"
  error_dtl=$result
  exit 1
fi

# Mount the CIFS if the folder hasn't mounted already
if [ $(mount -v | grep -c $MOUNT_DIR) -eq 0 ]; then
  result=$(mount -t cifs -o username="$MOUNT_USR",password="$MOUNT_PWD" $MOUNT_DEVICE $MOUNT_DIR 2>&1)
  if [ $? -ne 0 ]; then
    error_msg="Failed to mount the file system"
    error_dtl=$result
    exit 1
  fi
fi

# Synchronize backup files
result=$(rsync -au --delete $BACKUP_DIR/ $MOUNT_SYNC_DIR/ 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to synchronize backup files"
  error_dtl=$result
  umount $MOUNT_DIR
  exit 1
fi

# Unmount the CIFS
result=$(umount $MOUNT_DIR 2>&1)
if [ $? -ne 0 ]; then
  error_msg="Failed to unmount the file system"
  error_dtl=$result
  exit 1
fi
