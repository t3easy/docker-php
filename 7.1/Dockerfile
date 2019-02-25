FROM php:7.1-fpm-alpine3.9

RUN apk add --no-cache --virtual .typo3-deps \
        ghostscript \
        graphicsmagick \
        poppler-utils

RUN apk add --no-cache --virtual .build-deps \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        icu-dev \
        zlib-dev \
 && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
 && docker-php-ext-configure zip --with-libzip \
 && docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) \
        gd \
        intl \
        mysqli \
        soap \
        zip \
 && runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
 && apk add --virtual .phpext-rundeps $runDeps \
 && apk del .build-deps

RUN echo "max_execution_time = 240;" > /usr/local/etc/php/conf.d/typo3.ini \
 && echo "max_input_vars = 1500;" >> /usr/local/etc/php/conf.d/typo3.ini \
 && echo "post_max_size = 32M;" >> /usr/local/etc/php/conf.d/typo3.ini \
 && echo "upload_max_filesize = 32M;" >> /usr/local/etc/php/conf.d/typo3.ini

WORKDIR /app
