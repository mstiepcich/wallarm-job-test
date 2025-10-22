#!/bin/bash
set -e

# Actualizar paquetes
apt-get update -y
apt-get upgrade -y

# Instalar dependencias para Docker
apt-get install -y ca-certificates curl gnupg lsb-release

# Agregar clave GPG y repo de Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker y Docker Compose plugin
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Permitir usar Docker sin sudo
usermod -aG docker ubuntu

# Instalar Nginx
apt-get install -y nginx

# Configuración default personalizada de Nginx
cat <<EOC | tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;   # send traffic to the Wallarm container
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        add_header X-Proxy-Layer "ubuntu-nginx";
    }
}
EOC

# Habilitar y arrancar Nginx
systemctl enable nginx
systemctl restart nginx

# Crear directorio para docker-compose
mkdir -p /home/ubuntu/wallarm
cd /home/ubuntu/wallarm

# Crear docker-compose.yml
cat <<EOC > docker-compose.yml
version: '3.9'
services:
  wallarm:
    image: wallarm/node:6.6.2-wstore-health-check
    environment:
      - WALLARM_API_TOKEN=YFp07PdpBjLsq+GPWB7wQF/ax4WdwfQeNQET6s12AtbdmJHEL6BCNIEmWg4UQwl8
      - WALLARM_LABELS=group=mariano-test
      - WALLARM_API_HOST=audit.api.wallarm.com
      - NGINX_BACKEND=httpbin:80
      - WALLARM_MODE=monitoring
    ports:
      - "8080:80"
    depends_on:
      - httpbin

  httpbin:
    image: kennethreitz/httpbin
    expose:
      - "80"
EOC

# Levantar contenedores en background
docker compose up -d
