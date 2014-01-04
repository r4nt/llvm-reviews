#!/bin/bash

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y vim less

# Add the user we're going to maintain phab as.
sudo adduser --disabled-password --gecos "" phab

# Install phabricator dependencies.
cat <<END |debconf-set-selections
mysql-server-5.1 mysql-server/root_password password ""
mysql-server-5.1 mysql-server/root_password_again password ""
mysql-server-5.1 mysql-server/start_on_boot boolean true
END
sudo DEBIAN_FRONTEND=non-interactive apt-get install -y mysql-server

sudo apt-get install -y \
  git apache2 dpkg-dev \
  php5 php5-mysql php5-gd php5-dev php5-curl php-apc php5-cli php5-json

sudo a2enmod rewrite

# Create basic serving directory structure.
sudo mkdir -p /srv/http
sudo chown phab:phab /srv/http
cd /srv/http

if [[ ! -e libphutil ]]; then
  sudo su phab -c "git clone git://github.com/facebook/libphutil.git"
fi
if [[ ! -e arcanist ]]; then
  sudo su phab -c "git clone git://github.com/facebook/arcanist.git"
fi
if [[ ! -e phabricator ]]; then
  sudo su phab -c "git clone git://github.com/facebook/phabricator.git"
fi
