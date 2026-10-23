# syntax=docker/dockerfile:1.7
# SPDX-License-Identifier: Apache-2.0

# renovate: datasource=github-tags depName=nginx/nginx
ARG NGINX_VERSION=1.30.6
# renovate: datasource=git-refs depName=google/ngx_brotli
ARG NGX_BROTLI_COMMIT=53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1

FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS base

RUN apk add --no-cache ca-certificates

FROM base AS builder

ARG NGINX_VERSION
ARG NGX_BROTLI_COMMIT

RUN apk add --no-cache --virtual .build-deps \
      autoconf \
      automake \
      bash \
      build-base \
      cmake \
      curl \
      gettext \
      git \
      gnupg \
      libtool \
      linux-headers \
      openssl-dev \
      pax-utils \
      pcre-dev \
      tar \
      zlib-dev

RUN set -eux; \
    mkdir -p /usr/src/ngx_brotli; \
    cd /usr/src/ngx_brotli; \
    git init; \
    git remote add origin https://github.com/google/ngx_brotli.git; \
    git fetch --depth 1 origin "${NGX_BROTLI_COMMIT}"; \
    git checkout --recurse-submodules -q FETCH_HEAD; \
    git submodule update --init --depth 1; \
    cd /usr/src; \
    curl -fsSLO "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    curl -fsSLO "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc"; \
    curl -fsSL https://nginx.org/keys/pluknet.key -o /tmp/nginx-signing.key; \
    gpg --batch --import /tmp/nginx-signing.key; \
    gpg --batch --verify "nginx-${NGINX_VERSION}.tar.gz.asc" "nginx-${NGINX_VERSION}.tar.gz"; \
    tar -xzf "nginx-${NGINX_VERSION}.tar.gz"

RUN set -eux; \
    cmake -S /usr/src/ngx_brotli/deps/brotli \
      -B /usr/src/ngx_brotli/deps/brotli/out \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF; \
    cmake --build /usr/src/ngx_brotli/deps/brotli/out \
      --config Release \
      --target brotlienc; \
    cd "/usr/src/nginx-${NGINX_VERSION}"; \
    ./configure \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --user=nginx \
      --group=nginx \
      --with-http_ssl_module \
      --with-http_realip_module \
      --with-http_sub_module \
      --with-http_gzip_static_module \
      --with-http_auth_request_module \
      --with-http_stub_status_module \
      --with-threads \
      --with-file-aio \
      --with-http_v2_module \
      --with-compat \
      --add-module=/usr/src/ngx_brotli; \
    make -j"$(getconf _NPROCESSORS_ONLN)"; \
    make install; \
    nginx -V 2>&1 | grep -F -- '--add-module=/usr/src/ngx_brotli'; \
    apk add --no-cache --virtual .gettext gettext; \
    scanelf --needed --nobanner /usr/sbin/nginx /usr/bin/envsubst \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u > /tmp/runDeps.txt

FROM base

ARG NGINX_VERSION
ARG NGINX_CONFIG=nginx/default.conf

LABEL org.opencontainers.image.title="Vela UI NGINX" \
      org.opencontainers.image.version="${NGINX_VERSION}"

COPY --from=builder /tmp/runDeps.txt /tmp/runDeps.txt
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/bin/envsubst /usr/local/bin/envsubst

RUN set -eux; \
    apk add --no-cache tzdata $(cat /tmp/runDeps.txt); \
    rm /tmp/runDeps.txt; \
    addgroup -S nginx; \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
    mkdir -p /var/cache/nginx /var/log/nginx /usr/share/nginx/html; \
    touch /var/log/nginx/access.log /var/log/nginx/error.log; \
    ln -sf /dev/stdout /var/log/nginx/access.log; \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY dist /usr/share/nginx/html
COPY ${NGINX_CONFIG} /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ln -s /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh

STOPSIGNAL SIGQUIT

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
