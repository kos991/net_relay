FROM alpine:3.23

RUN apk add --no-cache bash coreutils curl findutils
RUN addgroup -S cert-sync -g 65532 \
    && adduser -S cert-sync -u 65532 -G cert-sync

COPY sync-relay-certs.sh /usr/local/bin/sync-relay-certs.sh
RUN chmod +x /usr/local/bin/sync-relay-certs.sh

USER 65532:65532

ENTRYPOINT ["/usr/local/bin/sync-relay-certs.sh"]
