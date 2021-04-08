ARG PHP_VERSION=7.4
ARG PHP_EXT_DIR=/usr/local/lib/php/extensions/no-debug-non-zts-20190902
ARG TARGET_ENVIRONMENT=production
ARG BUILD_PLATFORM=alpine
ARG ALPINE_VERSION=3.12

# https://github.com/krakjoe/apcu/releases
ARG APCU_VERSION=5.1.20
# https://github.com/phpredis/phpredis/releases
ARG REDIS_VERSION=5.3.4
# https://github.com/xdebug/xdebug/releases
ARG XDEBUG_VERSION=3.0.4
# https://github.com/php/pecl-file_formats-yaml/releases
ARG YAML_VERSION=2.2.1

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} as builder-alpine
ARG APCU_VERSION
ARG REDIS_VERSION
ARG XDEBUG_VERSION
ARG YAML_VERSION

RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
 && architecture=$(case $(uname -m) in i386 | i686 | x86) echo "i386" ;; x86_64 | amd64) echo "amd64" ;; aarch64 | arm64 | armv8) echo "arm64" ;; *) echo "amd64" ;; esac) \
 && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/$architecture/$version \
 && mkdir -p /tmp/blackfire \
 && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
 && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
 && docker-php-ext-enable blackfire \
 && echo 'blackfire.agent_socket=tcp://${BLACKFIRE_HOST}:${BLACKFIRE_PORT}' >> $PHP_INI_DIR/conf.d/docker-php-ext-blackfire.ini \
 && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

RUN apk add --no-cache --virtual .build-deps \
        freetype-dev \
        openldap-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        icu-dev \
        yaml-dev \
        zlib-dev \
 && case $PHP_VERSION in 8.0.*|7.4.*) docker-php-ext-configure gd --with-freetype --with-jpeg;; *) docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr;; esac \
 && case $PHP_VERSION in 7.2.*) docker-php-ext-configure zip --with-libzip;; esac \
 && docker-php-source extract \
 && mkdir -p /usr/src/php/ext/apcu \
 && curl -fsSL https://github.com/krakjoe/apcu/archive/v$APCU_VERSION.tar.gz | tar xz -C /usr/src/php/ext/apcu --strip 1 \
 && mkdir -p /usr/src/php/ext/redis \
 && curl -fsSL https://github.com/phpredis/phpredis/archive/$REDIS_VERSION.tar.gz | tar xz -C /usr/src/php/ext/redis --strip 1 \
 && mkdir -p /usr/src/php/ext/xdebug \
 && curl -fsSL https://github.com/xdebug/xdebug/archive/$XDEBUG_VERSION.tar.gz | tar xz -C /usr/src/php/ext/xdebug --strip 1 \
 && mkdir -p /usr/src/php/ext/yaml \
 && curl -fsSL https://github.com/php/pecl-file_formats-yaml/archive/$YAML_VERSION.tar.gz | tar xz -C /usr/src/php/ext/yaml --strip 1 \
 && docker-php-ext-configure ldap \
 && docker-php-ext-install -j$(nproc) \
        apcu \
        gd \
        intl \
        ldap \
        mysqli \
        redis \
        soap \
        xdebug \
        yaml \
        zip

RUN { \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
        echo 'max_input_vars=${PHP_MAX_INPUT_VARS}'; \
        echo 'post_max_size=${PHP_POST_MAX_SIZE}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}'; \
    } > $PHP_INI_DIR/conf.d/custom.ini

RUN docker-php-ext-enable opcache
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCELERATED_FILES}'; \
        echo 'opcache.max_wasted_percentage=${PHP_OPCACHE_MAX_WASTED_PERCENTAGE}'; \
        echo 'opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}'; \
    } >> $PHP_INI_DIR/conf.d/docker-php-ext-opcache.ini

RUN { \
        echo 'apc.enabled=1'; \
        echo 'apc.enable_cli=1'; \
        echo 'apc.shm_size=${PHP_APC_SHM_SIZE}'; \
    } >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini
RUN echo 'xdebug.max_nesting_level=400' >> $PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} as runtime-alpine-base
ENV PHP_APC_SHM_SIZE="128M" \
    PHP_MAX_EXECUTION_TIME="240" \
    PHP_MAX_INPUT_VARS="1500" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="10000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10" \
    PHP_POST_MAX_SIZE="32M" \
    PHP_UPLOAD_MAX_FILESIZE="32M"

ARG PHP_EXT_DIR

RUN apk add --no-cache --virtual .typo3-deps \
        ghostscript \
        graphicsmagick \
        poppler-utils

COPY --from=builder-alpine \
    $PHP_EXT_DIR/apcu.so \
    $PHP_EXT_DIR/gd.so \
    $PHP_EXT_DIR/intl.so \
    $PHP_EXT_DIR/ldap.so \
    $PHP_EXT_DIR/mysqli.so \
    $PHP_EXT_DIR/redis.so \
    $PHP_EXT_DIR/soap.so \
    $PHP_EXT_DIR/yaml.so \
    $PHP_EXT_DIR/zip.so \
    $PHP_EXT_DIR/

COPY --from=builder-alpine \
    $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-gd.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-intl.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-ldap.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-mysqli.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-opcache.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-redis.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-soap.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-yaml.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-zip.ini \
    $PHP_INI_DIR/conf.d/custom.ini \
    $PHP_INI_DIR/conf.d/

FROM runtime-alpine-base as runtime-alpine-production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

FROM runtime-alpine-base as runtime-alpine-development
ARG PHP_EXT_DIR
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

ENV BLACKFIRE_HOST="blackfire" \
    BLACKFIRE_PORT="8707" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME="/tmp" \
    DBGP_IDEKEY="PHPSTORM" \
    PATH="/tmp/vendor/bin:$PATH" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS="1" \
    XDEBUG_MODE="debug" \
    XDEBUG_CONFIG="client_host=host.docker.internal"

COPY --from=builder-alpine \
    $PHP_EXT_DIR/blackfire.so \
    $PHP_EXT_DIR/xdebug.so \
    $PHP_EXT_DIR/

COPY --from=builder-alpine \
    $PHP_INI_DIR/conf.d/docker-php-ext-blackfire.ini \
    $PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini \
    $PHP_INI_DIR/conf.d/

RUN apk add --no-cache --virtual .composer-rundeps \
        bash \
        coreutils \
        git \
        make \
        mercurial \
        openssh-client \
        patch \
        subversion \
        tini \
        unzip \
        zip \
 && apk add --no-cache --virtual .dev-tools \
        mariadb-client \
        parallel

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

FROM runtime-${BUILD_PLATFORM}-${TARGET_ENVIRONMENT} AS runtime

LABEL org.opencontainers.image.source="https://github.com/t3easy/docker-php"

RUN runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
 && apk add --no-cache --virtual .phpext-rundeps $runDeps

RUN mkdir /app \
 && chown -R www-data:www-data /app \
 && php --version \
 && if [ -f /usr/bin/composer ]; then composer --version; fi
WORKDIR /app

ENV PATH="/app/vendor/bin:$PATH"
