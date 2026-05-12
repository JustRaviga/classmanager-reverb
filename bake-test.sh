#!/usr/bin/env bash
#
# Local AMI-bake dry-run for the Classmanager Reverb host.
#
# Mirrors the package install + composer install + smoke-test steps the EC2
# Image Builder pipeline in JustRaviga/classmanager runs inside the AMI. Lets
# you catch package-availability / PECL-build / composer-resolution issues in
# ~30 seconds locally instead of after a 15-minute AMI bake.
#
# Usage (from a Mac with Docker Desktop on Apple Silicon):
#
#   docker run --rm -v $(pwd)/bake-test.sh:/bake-test.sh \
#     --platform linux/arm64 ubuntu:26.04 bash /bake-test.sh
#
# What it covers:
#   - apt package availability (the kind of failure that breaks the AMI bake)
#   - PECL ev extension build (compiler / headers)
#   - composer install resolving the skeleton's lockfile
#   - php artisan reverb:start command registering
#
# What it does NOT cover (needs a real EC2/VM):
#   - systemd daemon-reload / service enable
#   - IAM / SSM / network behaviour
#   - ASG / NLB / health-check flow
#
# If you change the apt list / PHP version / extensions in the Image Builder
# component (backend/infrastructure/serverless/resources/reverb.yml in the
# classmanager repo), mirror the changes here so this script stays a faithful
# fast-feedback loop.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> apt update + base packages"
apt-get update -y
apt-get install -y ca-certificates curl git unzip jq awscli

echo "==> PHP 8.5 + extensions from Ubuntu native packages"
apt-get install -y \
  php8.5-cli php8.5-dev php8.5-mbstring php8.5-xml php8.5-curl php8.5-redis \
  php-pear libev-dev

echo "==> Build the ev extension via PECL and enable it"
pecl install ev
echo "extension=ev.so" > /etc/php/8.5/cli/conf.d/20-ev.ini

echo "==> Install composer"
curl -sS https://getcomposer.org/installer | \
  php -- --install-dir=/usr/local/bin --filename=composer

echo "==> Clone the skeleton repo + composer install"
mkdir -p /var/www/reverb
cd /var/www/reverb
git clone --depth 1 --branch main https://github.com/JustRaviga/classmanager-reverb.git .
/usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction

echo "==> Smoke tests (same assertions as the Image Builder test component)"
php --version | grep -q 'PHP 8.5' || { echo 'FAIL: PHP 8.5 not found'; exit 1; }
test -f /var/www/reverb/artisan || { echo 'FAIL: artisan not found'; exit 1; }
php -m | grep -q '^ev$' || { echo 'FAIL: ev extension not loaded'; exit 1; }
php /var/www/reverb/artisan reverb:start --help > /dev/null \
  || { echo 'FAIL: reverb:start command not registered'; exit 1; }

echo "==> All checks passed"
