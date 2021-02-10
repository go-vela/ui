#!/bin/sh
set -eu

for f in /usr/share/nginx/html/*.js
do
    # shellcheck disable=SC2016
    envsubst '${VELA_API},${VELA_FEEDBACK_URL},{$VELA_DOCS_URL}' < "$f" > "$f".tmp && mv "$f".tmp "$f"
done
    envsubst '${VELA_API},${VELA_FEEDBACK_URL},{$VELA_DOCS_URL}' < "$f" > "$f".tmp && mv "$f".tmp "$f"

# substitute config values
NGINX_CONFIG=/etc/nginx/conf.d/default.conf

envsubst '${VELA_API}' < "$NGINX_CONFIG" > "$NGINX_CONFIG".tmp && mv "$NGINX_CONFIG".tmp "$NGINX_CONFIG"

exec "$@"
