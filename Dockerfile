FROM caddy:2.3.0-alpine

RUN apk update && \
    apk add --no-cache gettext ca-certificates && \
    rm -rf /var/cache/apk/*

COPY dist /srv

COPY caddy/Caddyfile /etc/caddy/Caddyfile

COPY docker-entrypoint.sh /usr/local/bin
RUN ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
