# Use a PHP image with Apache as the base
FROM php:8.1-apache

# Install required packages and PHP extensions
RUN apt-get update && apt-get install -y \
    unzip \
    zip \
    nano \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mysqli zip mbstring pdo_mysql opcache exif \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable EXIF for PHP
RUN docker-php-ext-enable exif

# Enable Apache modules and configure OSSN rewrites permanently
RUN a2enmod rewrite headers expires \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && cat > /etc/apache2/conf-available/ossn-overrides.conf <<'EOF'
<Directory /var/www/html>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

RUN a2enconf ossn-overrides

# Force Apache to route OSSN dynamic paths correctly
RUN cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    RewriteEngine On

    # OSSN action handler: required for login, register, comments, likes, messages, etc.
    RewriteRule ^/action/([A-Za-z0-9_\-/]+)$ /system/handlers/actions.php?action=$1 [QSA,L]

    # OSSN rewrite test
    RewriteRule ^/rewrite.php$ /installation/tests/apache_rewrite.php [L]

    # OSSN dynamic page handlers: js, css, profile, u, group, cache, etc.
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-d
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-f
    RewriteRule ^/([A-Za-z0-9_\-\.]+)/(.*)$ /index.php?h=$1&p=$2 [QSA,L]

    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-d
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} !-f
    RewriteRule ^/([A-Za-z0-9_\-\.]+)$ /index.php?h=$1 [QSA,L]

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Download and extract OSSN
ADD https://www.opensource-socialnetwork.org/download_ossn/latest/build.zip /tmp/ossn.zip

RUN unzip /tmp/ossn.zip -d /var/www/html/ \
    && mv /var/www/html/ossn/* /var/www/html/ \
    && rm -rf /var/www/html/ossn /tmp/ossn.zip

# Replace settings.php with the latest from GitHub
RUN curl -L -o /var/www/html/installation/pages/settings.php https://raw.githubusercontent.com/opensource-socialnetwork/docker/refs/heads/main/settings.php

# Create a data directory for OSSN used for file storage
RUN mkdir -p /var/www/ossn_data \
    && chown -R www-data:www-data /var/www/ossn_data \
    && chgrp www-data /var/www/ossn_data \
    && chmod g+w /var/www/ossn_data

# Create configurations directory for persistent OSSN config
RUN mkdir -p /var/www/html/configurations

# Set permissions for OSSN directories
RUN chown -R www-data:www-data /var/www/html/ \
    && chmod -R 755 /var/www/html/ \
    && chown -R www-data:www-data /var/www/ossn_data \
    && chmod -R 755 /var/www/ossn_data

# Expose port 80
EXPOSE 80

# Default command
CMD ["apache2-foreground"]
