#!/bin/bash

# Usage: init_app <app_directory_name> [--domain custom.domain.com]

APP_NAME="$1"
APP_DIR="/var/www/laravel-apps/$APP_NAME"
NGINX_CONF_DIR="/etc/nginx/conf.d"
BASE_DOMAIN="jotaro.dev"
CUSTOM_DOMAIN=""

# Check if the application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "Error: Directory $APP_DIR does not exist."
    exit 1
fi

# Parse the optional --domain flag
while [[ $# -gt 0 ]]; do
    key="$2"
    case $key in
        --domain)
        CUSTOM_DOMAIN="$3"
        shift # past argument
        shift # past value
        ;;
        *)
        shift # past unrecognized argument
        ;;
    esac
done

# Determine the domain name and Nginx configuration file name to use
if [ -z "$CUSTOM_DOMAIN" ]; then
    DOMAIN="${APP_NAME}.${BASE_DOMAIN}"
    NGINX_CONF_FILE="${DOMAIN}.conf"
else
    DOMAIN="$CUSTOM_DOMAIN"
    NGINX_CONF_FILE="${CUSTOM_DOMAIN}.conf"
fi

echo "Setting up the application in $APP_DIR with domain $DOMAIN..."

# Set the rest of the files to be owned by the host user
chown -R hostuser:hostgroup "$APP_DIR"

# Run Composer install as hostuser
if [ -f "$APP_DIR/composer.json" ]; then
    echo "Running composer install..."
    cd "$APP_DIR"
    su-exec hostuser:hostgroup composer install --no-interaction --optimize-autoloader
fi

# Run npm install and npm run build as hostuser
if [ -f "$APP_DIR/package.json" ]; then
    echo "Running npm install..."
    su-exec hostuser:hostgroup npm install

    echo "Running npm run build..."
    su-exec hostuser:hostgroup npm run build
fi

# Generate Nginx configuration for the app
echo "Generating Nginx configuration..."
cat > $NGINX_CONF_DIR/$NGINX_CONF_FILE <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root $APP_DIR/public;
    index index.php index.html;

    client_max_body_size 100M;  # Increase the max upload file size
    proxy_read_timeout 300s;    # Increase the proxy read timeout

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
        proxy_set_header X-Forwarded-Proto https;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTPS on;
        fastcgi_connect_timeout 300s;  # Increase the fastcgi connect timeout
        fastcgi_send_timeout 300s;     # Increase the fastcgi send timeout
        fastcgi_read_timeout 300s;     # Increase the fastcgi read timeout
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Ensure necessary directories exist
mkdir -p "$APP_DIR/storage/framework/cache" "$APP_DIR/storage/framework/sessions" \
         "$APP_DIR/storage/framework/views" "$APP_DIR/storage/logs" \
         "$APP_DIR/storage/app/public" "$APP_DIR/bootstrap/cache"

# Set the necessary directories to be writable by www-data, excluding .gitignore files
echo "Fixing permissions for writable directories..."
find "$APP_DIR/storage/framework" "$APP_DIR/storage/logs" "$APP_DIR/storage/app/public" "$APP_DIR/bootstrap/cache" \
     -type d -exec chmod 775 {} \; -exec chown www-data:www-data {} \;
find "$APP_DIR/storage/framework" "$APP_DIR/storage/logs" "$APP_DIR/storage/app/public" "$APP_DIR/bootstrap/cache" \
     -type f ! -name ".gitignore" -exec chmod 664 {} \; -exec chown www-data:www-data {} \;

# Set the rest of the files to be owned by the host user, excluding .gitignore files
echo "Setting ownership for other files..."
find "$APP_DIR" -type f ! -name ".gitignore" -exec chown hostuser:hostgroup {} \;

# Reload Nginx to apply the new configuration
echo "Reloading Nginx..."
nginx -s reload

# Run php artisan storage:link as hostuser
echo "Creating storage symlink..."
cd "$APP_DIR"
su-exec hostuser:hostgroup php artisan storage:link

echo "Application setup completed for $APP_NAME with domain $DOMAIN. Nginx configuration saved as $NGINX_CONF_FILE."
