# The different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/develop/develop-images/multistage-build/#stop-at-a-specific-build-stage
# https://docs.docker.com/compose/compose-file/#target

# ---------------------------------------------- Build Time Arguments --------------------------------------------------
# Actually :
# - composer:latest = composer:1.10.13
# - node:lts = node:12.18.4

ARG COMPOSER_VERSION=1.10
ARG NODE_VERSION=12.18
ARG PHP_VERSION=7.4
ARG NGINX_VERSION=1.19

# -------------------------------------------------- Composer Image ----------------------------------------------------

# ======================================================================================================================
# PHP Dependencies, in production we don't need composer inside container
# ======================================================================================================================

FROM composer:${COMPOSER_VERSION} as vendor
# default WORKDIR : /app

COPY composer.json composer.json
COPY composer.lock composer.lock
COPY symfony.lock symfony.lock
RUN composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --no-progress \
    --no-suggest \
    --prefer-dist

# -------------------------------------------------- Node/Yarn Image ---------------------------------------------------

# ======================================================================================================================
# Frontend dependencies, in production we don't need yarn inside container, sources are already supposed to be built
# ======================================================================================================================

# we are using an official image, the LTS (12.18.4 actually) version of Node, which comes with yarn as well.
FROM node:${NODE_VERSION} as demo_frontend
# default WORKDIR : /

WORKDIR /app
RUN mkdir -p public

# Yarn install to install dependencies in node_modules
COPY package.json yarn.lock ./
RUN yarn install

# Webpack encore
COPY webpack.config.js ./
COPY assets/ ./assets/
# We need this, because of FOSJsRoutingBundle
COPY --from=vendor \
    /app/vendor/friendsofsymfony/jsrouting-bundle/Resources/public/js/router.min.js ./vendor/friendsofsymfony/jsrouting-bundle/Resources/public/js/router.min.js
COPY public/js/fos_js_routes.json ./public/js/fos_js_routes.json

# Yarn build makes Webpack encore assets for production (command : yarn encore production)
#HACK |true, A CORRIGER
RUN yarn build | true

# https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact
# ======================================================================================================================
#                                                   --- Base ---
# ---------------  This stage install needed extenstions, plugins and add all needed configurations  -------------------
# ======================================================================================================================

FROM php:${PHP_VERSION}-fpm AS demo_php

# ------------------------------------- Install Packages Needed Inside Base Image --------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    acl \
    apt-utils \
    git \
    libxslt1-dev \
    libxtst6 \
    netcat-traditional \
    pax-utils \
    unzip \
    zip \
    zlib1g-dev \
    libzip-dev \
    ;
    # Ou sous Alpine apk add --no-cache zip libzip-dev

# Set timezone, The system time zone is configured by symlinking the /etc/localtime file
# to a binary time zone’s identifier in the /usr/share/zoneinfo directory.
RUN rm /etc/localtime && ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime

# ---------------------------------------- Install / Enable PHP Extensions ---------------------------------------------

ARG APCU_VERSION=5.1.18
RUN  set -eux; \
	docker-php-ext-configure zip; \
    docker-php-ext-install -j$(nproc) \
	    intl \
	    zip \
	    pdo \
	    pdo_mysql \
	; \
    pecl install \
    	    apcu-${APCU_VERSION} \
    	; \
    	pecl clear-cache; \
    	docker-php-ext-enable \
    	    apcu \
    	    opcache \
    	;

# ------------------------------------------------------ PHP -----------------------------------------------------------

RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY docker/php/conf.d/symfony.ini $PHP_INI_DIR/conf.d/symfony.ini

# ---------------------------------------------------- Composer --------------------------------------------------------

# TODO virer composer du build de prod
COPY --from=vendor /usr/bin/composer /usr/bin/composer
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
# install Symfony Flex globally to speed up download of Composer packages (parallelized prefetching)
RUN set -eux; \
	composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
	composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

# ----------------------------------------------------- MISC -----------------------------------------------------------

# Explicitly declare default workdir
WORKDIR /var/www/html
ARG APP_ENV=prod
ENV APP_DEBUG 0

# Get sources
COPY . .

# On monte le répertoire des variables
VOLUME /var/www/html/var

# -------------------------------------------------- ENTRYPOINT --------------------------------------------------------

COPY docker/php/docker-entrypoint.sh  /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint
ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

# ======================================================================================================================
# "demo_php_dev" stage, uniquement pour une image de dev
# ======================================================================================================================

FROM demo_php as demo_php_dev

COPY --from=demo_frontend /app/public ./public
RUN sed -i -e "s#;access.log = log/\$pool.access.log#access.log = log/\$pool.access.log#g" /usr/local/etc/php-fpm.d/www.conf.default

###> XDebug ###
RUN pecl install xdebug && docker-php-ext-enable xdebug && docker-php-source delete
###< XDebug ###

#RUN usermod -u 1000 www-data

# Ou si image Alpine :
#ARG XDEBUG_VERSION=2.8.0
#RUN set -eux; \
#	apk add --no-cache --virtual .build-deps $PHPIZE_DEPS; \
#	pecl install xdebug-$XDEBUG_VERSION; \
#	docker-php-ext-enable xdebug; \
#	apk del .build-deps

# ======================================================================================================================
#                                                  --- NGINX ---
# ---------------  This stage will install composer runtime dependencies and install app dependencies.  ----------------
# ======================================================================================================================
FROM nginx:${NGINX_VERSION}-alpine AS demo_sa

ARG SERVER_NAME="demo"
ENV SERVER_NAME=$SERVER_NAME

COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /var/www/html/public

COPY --from=demo_php /var/www/html/public .
COPY --from=demo_frontend /app/public .
# We might remove index.php, as this, every php request will not find it and proxy_pass it to php container
#RUN rm index.php
