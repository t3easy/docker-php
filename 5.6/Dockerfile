FROM php:5.6-fpm-alpine

RUN apk add --no-cache \
        ghostscript \
        openssl \
        poppler-utils \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.5/community graphicsmagick

RUN apk add --no-cache --virtual .build-deps \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install \
            gd \
            mysqli \
            soap \
            zip \
    && apk del .build-deps

WORKDIR /app
