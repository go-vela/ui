FROM fholzer/nginx-brotli:v1.31.3@sha256:b156d21079ff1de833c0bec13ddee2aa61fd84b360c5fe72a085fe72e095a1e8

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
