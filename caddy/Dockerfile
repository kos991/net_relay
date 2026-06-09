FROM caddy:2-builder AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2

RUN addgroup -S netbird-caddy -g 65532 \
    && adduser -S netbird-caddy -u 65532 -G netbird-caddy \
    && mkdir -p /data /config \
    && chown -R 65532:65532 /data /config

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

USER 65532:65532
