#!/bin/bash -eu

set -o pipefail

if [[ "$(whoami)" != "phab" ]]; then
  sudo service phd stop
  sudo service apache2 stop
  sudo su phab -c "$0 everything_down"
  sudo service apache2 start
  sudo service phd start
  exit 1
fi

if [[ "${1:-unset}" != "everything_down" ]]; then
  echo "Please run either:"
  echo "1) as a user with sudo rights;"
  echo "2) after making sure neither apache nor phd is running, retry with '$0 everything_down'."
fi

cd /srv/http

for project in libphutil arcanist phabricator; do
  cd $project
  git pull && git submodule update --init
  cd ..
done

/srv/http/phabricator/bin/storage upgrade
