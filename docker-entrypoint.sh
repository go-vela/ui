#!/bin/sh
set -eu

for f in /usr/share/nginx/html/*.js
do  
    # shellcheck disable=SC2016
    envsubst '${VELA_API},${VELA_SOURCE_URL},${VELA_SOURCE_CLIENT},${VELA_FEEDBACK_URL},{$VELA_DOCS_URL}' < "$f" > "$f".tmp && mv "$f".tmp "$f"
done

exec "$@"