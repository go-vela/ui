# Copyright (c) 2019 Target Brands, Inc. All rights reserved.
#
# Use of this source code is governed by the LICENSE file in this repository.

FROM fholzer/nginx-brotli

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
