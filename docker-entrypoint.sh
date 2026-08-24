#!/bin/sh
set -e

: "${PORT:=8080}"
: "${WEB_HOST:=fs-webtopup}"
: "${WEB_PORT:=8080}"
: "${ADMIN_HOST:=fs-webdashboard}"
: "${ADMIN_PORT:=8080}"
: "${API_HOST:=fs-webtopup}"
: "${API_PORT:=8080}"
: "${NGINX_RESOLVER:=$(awk '/^nameserver / { print $2; exit }' /etc/resolv.conf)}"
: "${NGINX_RESOLVER:=127.0.0.11}"

normalize_host() {
  if [ -n "$RAILWAY_ENVIRONMENT" ] || [ -n "$RAILWAY_PROJECT_ID" ] || [ "$USE_RAILWAY_INTERNAL" = "true" ]; then
    case "$1" in
      *.*|"" ) printf '%s' "$1" ;;
      * ) printf '%s.railway.internal' "$1" ;;
    esac
  else
    printf '%s' "$1"
  fi
}

WEB_HOST="$(normalize_host "$WEB_HOST")"
ADMIN_HOST="$(normalize_host "$ADMIN_HOST")"
API_HOST="$(normalize_host "$API_HOST")"

case "$NGINX_RESOLVER" in
  *:* )
    case "$NGINX_RESOLVER" in
      \[*\] ) ;;
      * ) NGINX_RESOLVER="[$NGINX_RESOLVER]" ;;
    esac
    ;;
esac

export PORT WEB_HOST WEB_PORT ADMIN_HOST ADMIN_PORT API_HOST API_PORT NGINX_RESOLVER

mkdir -p /tmp/nginx-cache/games /tmp/nginx-cache/proxy

envsubst '${PORT} ${WEB_HOST} ${WEB_PORT} ${ADMIN_HOST} ${ADMIN_PORT} ${API_HOST} ${API_PORT} ${NGINX_RESOLVER}' \
  < /templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

nginx -t

exec nginx -g 'daemon off;'
