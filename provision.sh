#!/usr/bin/env bash

# print commands and their expanded arguments
set -x

# Fail if anything goes wrong
set -e 

DOMAIN=${domain}
ADMIN_EMAIL=${admin_email}

apt-get update

apt install -y --no-install-recommends \
  build-essential \
  software-properties-common \
  dirmngr \
  git \
  nginx \
  libcairo2-dev \
  python3-dev \
  python3-pip \
  pkg-config \
  libjpeg-turbo8-dev \
  libblas-dev \
  liblapack-dev \
  gfortran \
  libxml2-dev \
  libcurl4-openssl-dev \
  cmake

################# Install jupyterlab + hub ###################################

# clone this repo so we have any helper scripts (e.g. add_users.sh) available if we SSH onto the VM
# for creation of users and other management.
cd /opt
git clone https://github.com/xyonetx/jupyterhub

# move into the cloned repo dir:
cd /opt/jupyterhub
pip3 install -U pip
pip3 install --no-cache-dir -r ./requirements.txt

# The following allows dynamic 3-d plotting
curl -sL https://deb.nodesource.com/setup_18.x | /usr/bin/bash -
apt-get install -y nodejs

npm install -g configurable-http-proxy

cd /opt
mkdir -p /opt/jupyterhub_config/etc/jupyterhub
cd /opt/jupyterhub_config/etc/jupyterhub
/usr/local/bin/jupyterhub --generate-config

# Edit the jupyterhub config file:
sed -i "s?^# c.JupyterHub.bind_url = 'http://:8000'?c.JupyterHub.bind_url = 'http://:8000/jupyter'?g" /opt/jupyterhub_config/etc/jupyterhub/jupyterhub_config.py
sed -i "s?^# c.Spawner.default_url = ''?c.Spawner.default_url = '/lab'?g" /opt/jupyterhub_config/etc/jupyterhub/jupyterhub_config.py

# Setup jupyterhub as a service
mkdir -p /opt/jupyterhub_config/etc/systemd
cat > /opt/jupyterhub_config/etc/systemd/jupyterhub.service<<"EOF"
[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/usr/local/bin/jupyterhub -f /opt/jupyterhub_config/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOF

# Load and start the service
ln -s /opt/jupyterhub_config/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
systemctl daemon-reload
systemctl enable jupyterhub.service
systemctl start jupyterhub.service

################ nginx server configuration #####################################

# install certbot so we can roll a SSL cert:
snap install core
snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# stop nginx, otherwise it's using port 80 and certbot will fail
service nginx stop

# now run certbot
certbot certonly -n --agree-tos --email $ADMIN_EMAIL --standalone --domains $DOMAIN

# The location of the files created by certbot:
SSL_CERT=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_CERT_KEY=/etc/letsencrypt/live/$DOMAIN/privkey.pem

# Removing the existing default conf and create an nginx conf file
rm /etc/nginx/sites-enabled/default

# Create an nginx config. 
cat > /etc/nginx/sites-enabled/jupyterstudio.conf <<EOF

map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''        close;
}

server {
  listen 80 default_server;
  listen [::]:80 default_server;
  server_name _;
  return 301 https://\$host\$request_uri;
}

server {

  listen                    443 ssl;
  server_name               $DOMAIN;
  ssl_certificate         $SSL_CERT;
  ssl_certificate_key $SSL_CERT_KEY;

  location /jupyter/ {    
    # NOTE important to also set base url of jupyterhub to /jupyter in its config
    proxy_pass http://localhost:8000;
    proxy_redirect http://localhost:8000/ \$scheme://\$host/jupyter/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF

service nginx restart
