#!/bin/bash -eu
: ${HOST:=}
: ${REMOTE:=}
: ${BACKUP:=/tmp/mysql.dump}

if [[ ! "${REMOTE}" ]]; then
  scp $0 ${HOST}:/tmp/backup-script.sh
  ssh ${HOST} "REMOTE=1 /tmp/backup-script.sh" > "${BACKUP}"
else
  MYSQL=~/mysql.sh
  MYSQLDUMP=~/mysqldump.sh
  DATABASES=$( ${MYSQL} -N -e 'show databases like "phabricator_%";' )
  ${MYSQLDUMP} --databases ${DATABASES}
fi
