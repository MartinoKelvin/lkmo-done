# Gunakan image PHP-FPM
FROM php:8.3-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libzip-dev libpng-dev libonig-dev libxml2-dev nginx \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && docker-php-ext-install pdo_mysql zip gd

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php \
    -- --install-dir=/usr/local/bin --filename=composer

# Set working directory
WORKDIR /app

# Copy the entire application first
COPY . .

# Copy environment file
COPY .env .env

# Copy certificate
COPY storage/certs/isrgrootx.pem storage/certs/isrgrootx.pem

# Install composer dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Install npm dependencies & build assets
RUN npm install
RUN chmod +x node_modules/.bin/vite
RUN npm run build

# Remove default nginx welcome page
RUN rm -rf /var/www/html/* && \
    rm -f /etc/nginx/sites-enabled/default

# Set permission
RUN chown -R www-data:www-data /app && \
    chmod -R 775 storage bootstrap/cache

# Laravel config
RUN php artisan config:clear && \
    php artisan config:cache && \
    php artisan storage:link || true

# Nginx config
RUN echo "server { \
    listen 80 default_server; \
    server_name _; \
    root /app/public; \
    index index.php index.html; \
    charset utf-8; \
    location / { \
    try_files \$uri \$uri/ /index.php?\$query_string; \
    } \
    location ~ \.php$ { \
    fastcgi_pass 127.0.0.1:9000; \
    fastcgi_index index.php; \
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; \
    include fastcgi_params; \
    } \
    }" > /etc/nginx/sites-available/default && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

EXPOSE 80

# Jalankan PHP-FPM dan Nginx
CMD sh -c "php-fpm -D && nginx -g 'daemon off;'"
