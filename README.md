# PHP FPM Docker image
This image can be used as base image for PHP applications or to run tests.

You should map or copy the desired application to the folder `/app`.

## Environment variables
You can configure PHP with some environment variables.

### For production and development flavor:
```
PHP_APC_SHM_SIZE="128M"
PHP_MAX_EXECUTION_TIME="240"
PHP_MAX_INPUT_VARS="1500"
PHP_MEMORY_LIMIT="128M"
PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"
PHP_OPCACHE_MAX_ACCELERATED_FILES="10000"
PHP_OPCACHE_MEMORY_CONSUMPTION="192"
PHP_OPCACHE_MAX_WASTED_PERCENTAGE="10"
PHP_POST_MAX_SIZE="32M"
PHP_UPLOAD_MAX_FILESIZE="32M"
```
The folder `/app/vendor/bin` is already in PATHs.

### For development flavor:
```
BLACKFIRE_HOST="blackfire"
BLACKFIRE_PORT="8707"
COMPOSER_ALLOW_SUPERUSER=1
COMPOSER_HOME="/tmp"
DBGP_IDEKEY="PHPSTORM"
PHP_OPCACHE_VALIDATE_TIMESTAMPS="1"
XDEBUG_MODE="off"
XDEBUG_CONFIG="client_host=host.docker.internal"
```
The folders `/app/vendor/bin` and `/tmp/vendor/bin` are already in PATHs.

## Examples

Run PHPunit tests in folder `tests`
```shell
docker run --rm -v $PWD:/app t3easy/php:7.4-development phpunit tests
```

Run PHPStan
```shell
docker run --rm -v $PWD:/app -e PHP_MEMORY_LIMIT=256M t3easy/php:7.4-development phpstan analyse --ansi
```

Run composer
```shell
docker run --rm -v $PWD:/app t3easy/php:7.4-development composer update --dry-run
```
