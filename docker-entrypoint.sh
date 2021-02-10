#!/bin/sh
set -eu

for f in /usr/share/nginx/html/*.js
do
    # shellcheck disable=SC2016
    envsubst '${VELA_API},${VELA_FEEDBACK_URL},{$VELA_DOCS_URL}' < "$f" > "$f".tmp && mv "$f".tmp "$f"
done

NGINX_CONF=/etc/nginx/conf.d/default.conf
# shellcheck disable=SC2016
envsubst '${VELA_API}' < "$NGINX_CONF" > "$NGINX_CONF".tmp && mv "$NGINX_CONF".tmp "$NGINX_CONF"

exec "$@"