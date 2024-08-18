# Use Node.js 20.16.0 with Alpine as the base image
FROM node:20.16.0-alpine AS node

# Use PHP 8.3 FPM with Alpine as the base image
FROM php:8.3-fpm-alpine

# Set build arguments for host UID and GID
ARG HOST_UID=1000
ARG HOST_GID=1000

# Create a new user and group with the same UID and GID as the host user
RUN addgroup -g $HOST_GID hostgroup && \
    adduser -D -u $HOST_UID -G hostgroup hostuser

# Copy Node.js from the Node.js image
COPY --from=node /usr/local /usr/local

# Install necessary packages: Nginx, Composer, curl, bash, and other dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    git \
    bash \
    inotify-tools \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    libxml2-dev \
    oniguruma-dev \
    su-exec \
    && rm -rf /var/cache/apk/*

# Install necessary PHP extensions 
RUN docker-php-ext-install pdo pdo_mysql mysqli

# Create the Nginx configuration directory
RUN mkdir -p /etc/nginx/conf.d

# Create directories for supervisord logs and pid files
RUN mkdir -p /var/log/supervisord /var/run/supervisord

# Install Composer globally
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set up the PHP-FPM configuration
RUN sed -i "s|;daemonize = yes|daemonize = no|" /usr/local/etc/php-fpm.d/zz-docker.conf && \
    sed -i "s|listen = /var/run/php/php-fpm.sock|listen = 9000|" /usr/local/etc/php-fpm.d/zz-docker.conf && \
    sed -i "s|;listen.owner = nobody|listen.owner = www-data|" /usr/local/etc/php-fpm.d/zz-docker.conf && \
    sed -i "s|;listen.group = nobody|listen.group = www-data|" /usr/local/etc/php-fpm.d/zz-docker.conf && \
    sed -i "s|user = nobody|user = www-data|" /usr/local/etc/php-fpm.d/zz-docker.conf && \
    sed -i "s|group = nobody|group = www-data|" /usr/local/etc/php-fpm.d/zz-docker.conf

# Set up Nginx configuration
COPY ./nginx.conf /etc/nginx/nginx.conf

# Supervisor configuration to manage Nginx and PHP-FPM
COPY ./supervisord.conf /etc/supervisord.conf

# Dynamic Nginx configuration and setup script
COPY ./init_app.sh /usr/local/bin/init_app

# Set up the directory for Laravel apps and set the correct ownership
RUN mkdir -p /var/www/laravel-apps && \
    chown -R hostuser:hostgroup /var/www/laravel-apps

# Set the working directory
WORKDIR /var/www/laravel-apps

# Expose port 80
EXPOSE 80

# Make the init_app script executable and available in PATH
RUN chmod +x /usr/local/bin/init_app

# Suppress NPM update notifier warnings
ENV NPM_CONFIG_UPDATE_NOTIFIER=false

# Start Nginx, PHP-FPM, and the dynamic config script
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
