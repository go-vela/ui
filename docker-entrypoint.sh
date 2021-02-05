#!/bin/sh
set -eu

for f in /srv/*.js
do
    # shellcheck disable=SC2016
    envsubst '${VELA_API},${VELA_FEEDBACK_URL},{$VELA_DOCS_URL}' < "$f" > "$f".tmp && mv "$f".tmp "$f"
done

exec "$@"
