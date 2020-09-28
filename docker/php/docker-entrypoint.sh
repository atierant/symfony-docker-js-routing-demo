#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- php-fpm "$@"
fi

if [ "$1" = 'php-fpm' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ]; then
	PHP_INI_RECOMMENDED="$PHP_INI_DIR/php.ini-production"
	if [ "$APP_ENV" != 'prod' ]; then
		PHP_INI_RECOMMENDED="$PHP_INI_DIR/php.ini-development"
	fi
	ln -sf "$PHP_INI_RECOMMENDED" "$PHP_INI_DIR/php.ini"

  mkdir -p var/cache var/log

	setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX var
	setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX var
fi

# Installation base de données + fixtures, oui, je sais, faudrait des migrations......
echo "Doctrine schema update & fixtures..."
php bin/console doctrine:schema:update --force
php bin/console doctrine:fixtures:load --no-interaction | true

setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX .
setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX .

exec docker-php-entrypoint "$@"