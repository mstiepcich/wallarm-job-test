#!/bin/bash
set -e

# Update packets
apt-get update -y
apt-get upgrade -y

# Installing Docker dependencies
apt-get install -y ca-certificates curl gnupg lsb-release

# Adding GPG key and Docker repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker and docker-compose plugin
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Allow using docker without sudo
usermod -aG docker ubuntu

# Install Nginx
apt-get install -y nginx

# Custom default config for Nginx
cat <<EOC | tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;   # send traffic to the Wallarm container
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        #Add a custom header to identify the traffic passes through here
        add_header X-Proxy-Layer "ubuntu-nginx";
    }
}
EOC

# Enable and Start Nginx
systemctl enable nginx
systemctl restart nginx

# Create directory for docker-compose
mkdir -p /home/ubuntu/wallarm
cd /home/ubuntu/wallarm

# Create the default config file for wallarm nginx
cat <<EOC > default
#
# by default, proxy all to 127.0.0.1:8080
#

server {
        listen 80 default_server;
        listen [::]:80 default_server ipv6only=on;
        #listen 443 ssl;

        server_name localhost;

        #ssl_certificate cert.pem;
        #ssl_certificate_key cert.key;

        root /usr/share/nginx/html;

        index index.html index.htm;

        wallarm_mode monitoring;

        location / {
                proxy_pass http://httpbin:80;
                include proxy_params;

                #Add custom header in all responses to identify it passes through here
                add_header Wallarm-Container "true" always;
        }
}
EOC

# Create docker-compose.yml
cat <<EOC > docker-compose.yml
version: '3.9'
services:
  wallarm:
    image: wallarm/node:6.6.2-wstore-health-check
    environment:
      - WALLARM_API_TOKEN=${wallarm_api_token}
      - WALLARM_LABELS=group=mariano-test
      - WALLARM_API_HOST=${wallarm_api_host}
      - NGINX_BACKEND=httpbin:80
      - WALLARM_MODE=${wallarm_mode}
    volumes:
      - ./default:/etc/nginx/http.d/default.conf
    ports:
      - "8080:80"
    depends_on:
      - httpbin

  httpbin:
    image: kennethreitz/httpbin
    expose:
      - "80"
EOC

# Start container in the background
docker compose up -d
