#!/bin/bash

# Sets up the BTCPayServer Wownero edition on a fresh Ubuntu VPS

set -e

if [[ -z $BTCPAY_HOST ]];
then
    echo Please provide a BTCPAY_HOST variable with the URL you will host your BTCPayServer at
    exit 1
fi

if [[ -z $EMAIL ]]
then
    echo Please provide a EMAIL variable to register for Lets Encrypt certificates
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Install packages
apt-get update
apt-get upgrade -y
apt-get install -y \
    software-properties-common \
    sudo \
    git \
    certbot \
    nginx \
    ufw \
    tor

# Setup basic firewall rules
ufw default deny incoming
ufw default allow outgoing
ufw allow 22
ufw allow 80
ufw allow 443
ufw -f enable

# Install docker engine + docker compose
curl -s https://get.docker.com | bash

# Install btcpayserver wownero
git clone https://github.com/lalanza808/btcpayserver-wownero /opt/btcpay
echo BTCPAY_HOST=$BTCPAY_HOST > /opt/btcpay/.env
cd /opt/btcpay
docker compose up -d

# Setup Tor
mkdir -p /run/tor
chown -R debian-tor:debian-tor /run/tor
chmod 700 -R /run/tor
mkdir -p /var/www/tor
cat << EOF > /etc/tor/torrc
ControlSocket /run/tor/control
ControlSocketsGroupWritable 1
CookieAuthentication 1
CookieAuthFileGroupReadable 1
CookieAuthFile /run/tor/control.authcookie
DataDirectory /var/lib/tor
ExitPolicy reject6 *:*, reject *:*
ExitRelay 0
IPv6Exit 0
Log notice stdout
ORPort 127.0.0.1:9001
PublishServerDescriptor 0
SOCKSPort 9050
HiddenServiceDir /var/lib/tor/btcpayserver
HiddenServicePort 80 127.0.0.1:80
EOF
systemctl enable tor
systemctl restart tor
sleep 10
mkdir -p /var/www/tor/
cp /var/lib/tor/btcpayserver/hostname /var/www/tor/index.html
chmod 644 /var/www/tor/index.html
chmod 755 /var/www/tor/
chown -R nobody:nogroup /var/www/tor


# Setup certs and Nginx
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/ssl/certs
rm -f /etc/nginx/sites-enabled/default
openssl dhparam -out /etc/ssl/certs/dhparam.pem -2 2048
cat << EOF > /etc/nginx/conf.d/ssl.conf
## SSL Certs are referenced in the actual Nginx config per-vhost
# Disable insecure SSL v2. Also disable SSLv3, as TLS 1.0 suffers a downgrade attack, allowing an attacker to force a connection to use SSLv3 and therefore disable forward secrecy.
# ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
# Strong ciphers for PFS
ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
# Use server's preferred cipher, not the client's
# ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
# Use ephemeral 4096 bit DH key for PFS
ssl_dhparam /etc/ssl/certs/dhparam.pem;
# Use OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 valid=300s;
resolver_timeout 5s;
EOF
cat << EOF > /etc/nginx/sites-enabled/${BTCPAY_HOST}.conf
# Redirect inbound http to https
server {
    listen 80 default_server;
    server_name ${BTCPAY_HOST};
    index index.php index.html;
    return 301 https://${BTCPAY_HOST}$request_uri;
}

# Load SSL configs and serve SSL site
server {
    listen 443 ssl;
    server_name ${BTCPAY_HOST};
    error_log /var/log/nginx/${BTCPAY_HOST}-error.log warn;
    access_log /var/log/nginx/${BTCPAY_HOST}-access.log;
    client_body_in_file_only clean;
    client_body_buffer_size 32K;
    # set max upload size
    client_max_body_size 8M;
    sendfile on;
    send_timeout 600s;

    location / {
        proxy_pass http://127.0.0.1:49392;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Frame-Options "SAMEORIGIN";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;

        # WebSocket-specific headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Optional timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Disable caching
        proxy_buffering off;
    }

    location /tor/ {
        alias /var/www/tor/;
    }

    include conf.d/ssl.conf;
    ssl_certificate /etc/letsencrypt/live/${BTCPAY_HOST}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${BTCPAY_HOST}/privkey.pem;
}
EOF
cat << EOF > /etc/nginx/sites-enabled/btcpay-tor.conf
server {
    listen 80;
    server_name $(cat /var/lib/tor/btcpayserver/hostname);

    error_log /var/log/nginx/btcpay-tor-error.log warn;
    access_log /var/log/nginx/btcpay-tor-access.log;
    client_body_in_file_only clean;
    client_body_buffer_size 32K;

    location / {
        proxy_pass http://127.0.0.1:49392;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Frame-Options "SAMEORIGIN";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
EOF
service nginx stop
certbot certonly --standalone -d ${BTCPAY_HOST} --agree-tos -m ${EMAIL} -n
sed -i 's/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/' /etc/nginx/nginx.conf
service nginx start

# Final output
echo -e "\nOnion site for BTCPayServer: $(cat /var/lib/tor/btcpayserver/hostname)"
echo -e "\nYou may now setup your BTCPayServer at ${BTCPAY_HOST}"