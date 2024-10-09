#!/bin/bash

APP_DIR="/var/www/laravel-apps"
NGINX_CONF_DIR="/etc/nginx/conf.d"

# Initialize each app
APPS=$(ls $APP_DIR)

for APP in $APPS; do
    echo "Initializing app: $APP"
    /usr/local/bin/init_app "$APP"
done

# Clean up unused Nginx configurations
echo "Cleaning up unused Nginx configurations..."
# Get all registered domains from .domain files
REGISTERED_DOMAINS=()
for app in $APPS; do
    DOMAIN_FILE="$APP_DIR/$app/.domain"
    if [ -f "$DOMAIN_FILE" ]; then
        registered_domain=$(cat "$DOMAIN_FILE")
        REGISTERED_DOMAINS+=("$registered_domain")
    fi
done

# Now check against the registered domains before removing any Nginx config
for conf in $NGINX_CONF_DIR/*.conf; do
    if [ -f "$conf" ]; then  # Check if the configuration file exists
        domain=$(basename "$conf" .conf)

        # Check if this domain is registered in any .domain file
        if [[ ! " ${REGISTERED_DOMAINS[@]} " =~ " ${domain} " ]]; then
            echo "Removing unused Nginx config: $conf"
            rm "$conf"
        fi
    fi
done

echo "Cleanup of unused Nginx configurations completed."
