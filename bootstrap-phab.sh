#!/bin/bash

CONFIG_DIR=$(readlink -f $(dirname -- $0))

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
  cd phabricator
  sudo su phab -c "git remote add r4nt git://github.com/r4nt/phabricator.git"
  sudo su phab -c "git fetch r4nt"
  sudo su phab -c "git checkout r4nt-master"
fi

# Configure phabricator.
cd /srv/http/phabricator
sudo su phab -c "./bin/storage upgrade --force"

echo "******************************************************************"
echo "* Please create an administrator account. If you skip this step, *"
echo "* Phabricator will ask the first person visiting the website to  *"
echo "* create an administrator account.                               *"
echo "******************************************************************"
sudo su phab -c "/srv/http/phabricator/bin/accountadmin"

# Configure apache.
sudo a2dissite default

sudo cp $CONFIG_DIR/apache2-phabricator.conf \
  /etc/apache2/sites-available/phabricator
sudo a2ensite phabricator

sudo service apache2 reload

