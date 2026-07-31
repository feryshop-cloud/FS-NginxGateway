#!/bin/sh
set -e

: "${PORT:=8080}"
: "${WEB_HOST:=fs-webtopup}"
: "${WEB_PORT:=8080}"
: "${ADMIN_HOST:=fs-webdashboard}"
: "${ADMIN_PORT:=8080}"
: "${API_HOST:=fs-webtopup}"
: "${API_PORT:=8080}"

normalize_railway_host() {
  case "$1" in
    *.*|"" ) printf '%s' "$1" ;;
    * ) printf '%s.railway.internal' "$1" ;;
  esac
}

WEB_HOST="$(normalize_railway_host "$WEB_HOST")"
ADMIN_HOST="$(normalize_railway_host "$ADMIN_HOST")"
API_HOST="$(normalize_railway_host "$API_HOST")"
export PORT WEB_HOST WEB_PORT ADMIN_HOST ADMIN_PORT API_HOST API_PORT

envsubst '${PORT} ${WEB_HOST} ${WEB_PORT} ${ADMIN_HOST} ${ADMIN_PORT} ${API_HOST} ${API_PORT}' \
  < /templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

nginx -t

exec nginx -g 'daemon off;'
