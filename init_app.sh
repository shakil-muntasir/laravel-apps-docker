#!/bin/bash

# Usage: init_app <app_directory_name> [--domain custom.domain.com]

APP_NAME="$1"
APP_DIR="/var/www/laravel-apps/$APP_NAME"
NGINX_CONF_DIR="/etc/nginx/conf.d"
CUSTOM_DOMAIN=""
DOMAIN_FILE="$APP_DIR/.domain"

# Check if the application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "Error: Directory $APP_DIR does not exist."
    exit 1
fi

# Check for existing .domain file
if [ -f "$DOMAIN_FILE" ]; then
    CUSTOM_DOMAIN=$(cat "$DOMAIN_FILE")
    echo "Using domain from .domain file: $CUSTOM_DOMAIN"
else
    # Parse the mandatory --domain flag if .domain file does not exist
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

    if [ -z "$CUSTOM_DOMAIN" ]; then
        echo "Error: .domain file does not exist and --domain flag is mandatory."
        exit 1
    fi

    # Save the domain to the .domain file
    echo "$CUSTOM_DOMAIN" > "$DOMAIN_FILE"
    echo "Domain saved to $DOMAIN_FILE: $CUSTOM_DOMAIN"
fi

# Determine the Nginx configuration file name
DOMAIN="$CUSTOM_DOMAIN"
NGINX_CONF_FILE="${DOMAIN}.conf"

# Check if Nginx config already exists
if [ -f "$NGINX_CONF_DIR/$NGINX_CONF_FILE" ]; then
    echo "Nginx configuration already exists for $DOMAIN."
else

echo "Setting up the application in $APP_DIR with domain $DOMAIN..."

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

fi

# Ensure necessary directories exist
mkdir -p "$APP_DIR/bootstrap/cache"  # Ensure bootstrap/cache exists
mkdir -p "$APP_DIR/storage/framework/cache" "$APP_DIR/storage/framework/sessions" \
         "$APP_DIR/storage/framework/views" "$APP_DIR/storage/logs" \
         "$APP_DIR/storage/app/public"

# Set writable permissions for necessary directories while excluding .gitignore files
echo "Setting writable permissions for necessary directories..."
# Use find to change permissions for directories
find "$APP_DIR/bootstrap/cache" -type d -exec chmod 775 {} \;
find "$APP_DIR/storage/logs" -type d -exec chmod 775 {} \;
find "$APP_DIR/storage/framework/views" -type d -exec chmod 775 {} \;
find "$APP_DIR/storage/framework/sessions" -type d -exec chmod 775 {} \;
find "$APP_DIR/storage/framework/cache" -type d -exec chmod 775 {} \;

# Use find to change permissions for files, excluding .gitignore
find "$APP_DIR/bootstrap/cache" -type f ! -name ".gitignore" -exec chmod 664 {} \;
find "$APP_DIR/storage/logs" -type f ! -name ".gitignore" -exec chmod 664 {} \;
find "$APP_DIR/storage/framework/views" -type f ! -name ".gitignore" -exec chmod 664 {} \;
find "$APP_DIR/storage/framework/sessions" -type f ! -name ".gitignore" -exec chmod 664 {} \;
find "$APP_DIR/storage/framework/cache" -type f ! -name ".gitignore" -exec chmod 664 {} \;


# Ensure ownership is set for hostuser
chown -R hostuser:hostgroup "$APP_DIR"

# Ensure laravel.log is created and writable by host user
touch "$APP_DIR/storage/logs/laravel.log"
chmod 664 "$APP_DIR/storage/logs/laravel.log"
chown hostuser:hostgroup "$APP_DIR/storage/logs/laravel.log"

# Run Composer install as hostuser
if [ -f "$APP_DIR/composer.json" ]; then
    echo "Running composer install..."
    cd "$APP_DIR"
    su-exec hostuser:hostgroup composer install --no-interaction --optimize-autoloader
fi

# Set the necessary directories to be writable by www-data after setup
echo "Fixing permissions for writable directories for www-data..."
find "$APP_DIR/storage/framework" "$APP_DIR/storage/logs" "$APP_DIR/storage/app/public" "$APP_DIR/bootstrap/cache" \
     -type d -exec chmod 775 {} \; -exec chown www-data:www-data {} \;

# Exclude .gitignore files from permission changes
find "$APP_DIR/storage/framework" "$APP_DIR/storage/logs" "$APP_DIR/storage/app/public" "$APP_DIR/bootstrap/cache" \
     -type f ! -name ".gitignore" -exec chmod 664 {} \; -exec chown www-data:www-data {} \;

# Run npm install and npm run build as hostuser
if [ -f "$APP_DIR/package.json" ]; then
    echo "Running npm install..."
    su-exec hostuser:hostgroup npm install

    echo "Running npm run build..."
    su-exec hostuser:hostgroup npm run build
fi

# Reload Nginx to apply the new configuration
echo "Reloading Nginx..."
nginx -s reload

# Run php artisan storage:link as hostuser
echo "(Re)creating storage symlink..."
cd "$APP_DIR"
su-exec hostuser:hostgroup unlink "$APP_DIR/public/storage" 2>/dev/null
su-exec hostuser:hostgroup php artisan storage:link

echo "Application setup completed for $APP_NAME with domain $DOMAIN. Nginx configuration saved as $NGINX_CONF_FILE."
