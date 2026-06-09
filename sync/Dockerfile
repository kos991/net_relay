FROM alpine:3.23

RUN apk add --no-cache bash coreutils curl findutils

COPY sync-relay-certs.sh /usr/local/bin/sync-relay-certs.sh
RUN chmod +x /usr/local/bin/sync-relay-certs.sh

ENTRYPOINT ["/usr/local/bin/sync-relay-certs.sh"]
