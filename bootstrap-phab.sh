#!/bin/bash -eu
# export MODE=production to set up a production system.

: ${HOST:="llvm-reviews.no-ip.org"}
: ${MODE:="test"}

CONFIG_DIR=$(readlink -f $(dirname -- $0))
DISK_DEV=/dev/disk/by-id/google-mysql
MYSQLDIR=/var/lib/mysql
MOUNT=/mnt/database
DIR=phabricator-mysql

if [[ "${MODE}" == "production" ]]; then
  if [[ ! -e "${DISK_DEV}" ]]; then
    echo "Disk ${DISK_DEV} not available. Please attach before"
    echo "trying to set up a production system."
    exit 1
  fi
  if [[ ! -e "${MOUNT}" ]]; then
    sudo mkdir -p "${MOUNT}"
  fi
  if ! grep "${DISK_DEV}" /etc/fstab; then
    sudo bash -c "echo \"${DISK_DEV} ${MOUNT} ext4 defaults 0 0\" >> /etc/fstab"
    sudo mount -a
  fi
  if [[ ! -e "${MOUNT}/${DIR}" ]]; then
    echo "The production data at ${MOUNT}/${DIR} does not exist!"
    exit 1
  fi
  if [[ -e "${MYSQLDIR}" ]]; then
    LINK=$(readlink -f "${MYSQLDIR}")
    if [[ "${LINK}" != "${MOUNT}/${DIR}" ]]; then
      echo "The mysql directory at ${LINK} is different from the"
      echo "production data at ${MOUNT}/${DIR}. Please fix!"
      exit 1
    fi
  else
    ln -s "${MOUNT}/${DIR}" "${MYSQLDIR}"
  fi 
else
  if [[ -e "${DISK_DEV}" ]]; then
    echo "Disk ${DISK_DEV} is attached - perhaps you want to set"
    echo "up a production system?"
    exit 1
  fi
fi

exit 1

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
  cd libphutil
  sudo su phab -c "git remote add r4nt git://github.com/r4nt/libphutil.git"
  sudo su phab -c "git fetch r4nt"
  sudo su phab -c "git checkout r4nt-master"
  cd ..
fi
if [[ ! -e arcanist ]]; then
  sudo su phab -c "git clone git://github.com/facebook/arcanist.git"
  cd arcanist
  sudo su phab -c "git remote add r4nt git://github.com/r4nt/arcanist.git"
  sudo su phab -c "git fetch r4nt"
  sudo su phab -c "git checkout r4nt-master"
  cd ..
fi
if [[ ! -e phabricator ]]; then
  sudo su phab -c "git clone git://github.com/facebook/phabricator.git"
  cd phabricator
  sudo su phab -c "git remote add r4nt git://github.com/r4nt/phabricator.git"
  sudo su phab -c "git fetch r4nt"
  sudo su phab -c "git checkout r4nt-master"
  cd ..
fi

# Configure phabricator.
cd /srv/http/phabricator
sudo su phab -c "./bin/storage upgrade --force"

sudo mkdir /var/repo
sudo chown phab:phab /var/repo

echo "******************************************************************"
echo "* Please create an administrator account. If you skip this step, *"
echo "* Phabricator will ask the first person visiting the website to  *"
echo "* create an administrator account.                               *"
echo "******************************************************************"
sudo su phab -c "/srv/http/phabricator/bin/accountadmin"

function set_config() {
  sudo su phab -c "./bin/config set $1 $2"
}
set_config phabricator.base-uri "http://$HOST/"
set_config storage.upload-size-limit 15M
set_config metamta.mail-adapter PhabricatorMailImplementationSendGridAdapter
set_config account.minimum-password-length 6
set_config auth.require-approval false
set_config differential.allow-self-accept true
set_config differential.always-allow-close true
set_config differential.require-test-plan-field false
set_config metamta.can-send-as-user true
set_config metamta.default-address phabricator@$HOST
set_config metamta.differential.attach-patches true
set_config metamta.differential.inline-patches 100
set_config metamta.differential.reply-handler-domain $HOST
set_config metamta.differential.subject-prefix "[PATCH]"
set_config metamta.domain $HOST
set_config metamta.insecure-auth-with-reply-to true
set_config metamta.one-mail-per-recipient false
set_config metamta.public-replies true
set_config metamta.re-prefix true
set_config metamta.reply-handler-domain $HOST
set_config metamta.user-address-format real
set_config minimal-email true
set_config metamta.differential.unified-comment-context true
set_config metamta.vary-subjects false
set_config phabricator.uninstalled-applications \''{ "PhabricatorApplicationConpherence" : true, "PhabricatorApplicationDiviner" : true, "PhabricatorApplicationFlags" : true, "PhabricatorApplicationPhriction" : true }'\'

# Configure php.
sudo bash -c "sed -i'' -e 's,;date.timezone =,date.timezone = America/Los_Angeles,' /etc/php5/apache2/php.ini"
if ! grep apc.stat /etc/php5/apache2/php.ini; then
  sudo bash -c "echo 'apc.stat = 0' >> /etc/php5/apache2/php.ini"
fi

# Configure apache.
sudo a2dissite default

sudo cp $CONFIG_DIR/apache2-phabricator.conf \
  /etc/apache2/sites-available/phabricator
sudo bash -c "sed -i'' -e s,__HOST__,$HOST, /etc/apache2/sites-available/phabricator"
sudo a2ensite phabricator

sudo service apache2 reload

echo ""
echo ""
echo "Next steps:"
echo "- add authentication providers via the web UI"
echo "- configure a SendGrid account vai the web UI"

