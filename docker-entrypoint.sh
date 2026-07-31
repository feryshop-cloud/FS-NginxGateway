#!/bin/sh
set -e

envsubst '${PORT} ${WEB_HOST} ${WEB_PORT} ${ADMIN_HOST} ${ADMIN_PORT} ${API_HOST} ${API_PORT}' \
  < /templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

nginx -t

exec nginx -g 'daemon off;'
