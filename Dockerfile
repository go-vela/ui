FROM fholzer/nginx-brotli

RUN apk update && \
    apk add --no-cache ca-certificates && \
    rm -rf /var/cache/apk/*

COPY dist /usr/share/nginx/html

COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80