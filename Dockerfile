FROM fholzer/nginx-brotli:v1.30.0@sha256:3e7306e5edd4ccd24fdac3b90439c839324db96174fb004c2c68cc50415493df

RUN apk update && \
    apk add --no-cache ca-certificates && \
    rm -rf /var/cache/apk/*

COPY dist /usr/share/nginx/html

COPY nginx/default.conf /etc/nginx/conf.d/default.conf

COPY docker-entrypoint.sh /usr/local/bin
RUN ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
