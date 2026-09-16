FROM fholzer/nginx-brotli:v1.31.3@sha256:4f94249d3e86b22aadfb52674b92fc0ddd8fb5bd20560341755e5a3c247e1c1a

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
