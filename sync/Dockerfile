FROM alpine:3.20

RUN apk add --no-cache bash curl coreutils findutils

COPY sync-relay-certs.sh /usr/local/bin/sync-relay-certs.sh
RUN chmod +x /usr/local/bin/sync-relay-certs.sh

ENTRYPOINT ["/usr/local/bin/sync-relay-certs.sh"]

