ARG PHP_VERSION=7.3
ARG TARGET_ENVIRONMENT=production
ARG BUILD_PLATFORM=alpine
ARG ALPINE_VERSION=3.10

ARG APCU_VERSION=5.1.17
ARG REDIS_VERSION=5.0.2
ARG XDEBUG_VERSION=2.7.2


FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} as runtime-alpine-base

RUN apk add --no-cache --virtual .typo3-deps \
        ghostscript \
        graphicsmagick \
        poppler-utils

ARG APCU_VERSION
ARG REDIS_VERSION
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        openldap-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        icu-dev \
        zlib-dev \
 && docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr \
 && docker-php-ext-configure zip --with-libzip \
 && docker-php-ext-configure ldap \
 && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
        gd \
        intl \
        ldap \
        opcache \
        mysqli \
        soap \
        zip \
 && pecl install apcu-${APCU_VERSION} \
 && pecl install redis-${REDIS_VERSION} \
 && docker-php-ext-enable \
        apcu \
        redis \
 && runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
 && apk add --virtual .phpext-rundeps $runDeps \
 && apk del .build-deps \
 && rm -rf /tmp/pear

RUN { \
        echo 'max_execution_time=240'; \
        echo 'max_input_vars=1500'; \
        echo 'post_max_size=32M'; \
        echo 'upload_max_filesize=32M'; \
    } > $PHP_INI_DIR/conf.d/typo3.ini

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0" \
    PHP_OPCACHE_MAX_ACCELERATED_FILES="10000" \
    PHP_OPCACHE_MEMORY_CONSUMPTION="192" \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"
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

ENV PHP_APC_SHM_SEGMENTS="1" \
    PHP_APC_SHM_SIZE="128M"
RUN { \
        echo 'apc.enabled=1'; \
        echo 'apc.enable_cli=1'; \
        echo 'apc.shm_segments=${PHP_APC_SHM_SEGMENTS}'; \
        echo 'apc.shm_size=${PHP_APC_SHM_SIZE}'; \
    } >> $PHP_INI_DIR/conf.d/docker-php-ext-apcu.ini

WORKDIR /app

FROM runtime-alpine-base as runtime-alpine-production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

FROM runtime-alpine-base as runtime-alpine-development
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="1"

ARG XDEBUG_VERSION
RUN apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS \
 && pecl install xdebug-${XDEBUG_VERSION} \
 && docker-php-ext-enable xdebug \
 && apk del .phpize-deps \
 && rm -rf /tmp/pear
RUN { \
        echo 'xdebug.max_nesting_level=400'; \
        echo 'xdebug.remote_enable=1'; \
    } >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
ENV XDEBUG_CONFIG="idekey=PHPSTORM remote_host=host.docker.internal"

ENV BLACKFIRE_HOST=blackfire
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
 && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/alpine/amd64/$version \
 && mkdir -p /tmp/blackfire \
 && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
 && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
 && docker-php-ext-enable blackfire \
 && echo 'blackfire.agent_socket=tcp://${BLACKFIRE_HOST}:8707' >> $PHP_INI_DIR/conf.d/docker-php-ext-blackfire.ini \
 && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

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
        zip
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV PATH "/tmp/vendor/bin:$PATH"
COPY --from=composer:1 /usr/bin/composer /usr/bin/composer

RUN apk add --no-cache --virtual .dev-tools mariadb-client parallel

FROM runtime-${BUILD_PLATFORM}-${TARGET_ENVIRONMENT} AS runtime