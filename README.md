# NetBird Relay Installer

This project provides a single interactive installer for a NetBird external Relay using:

- `Caddy` with Cloudflare DNS challenge for automatic certificate issuance
- a custom Relay TCP port
- a custom STUN UDP port
- a cert sync sidecar that copies renewed Caddy certs into the Relay mount
- fixed internal Caddy ports for certificate automation only

## Order

The installer runs in this order:

1. collect domain, Cloudflare token, ports, and shared secret
2. generate the stack files
3. start `caddy` and `sync-relay-certs`
4. wait until the first certificate is present in `data/relay-certs`
5. start `netbirdio/relay`
6. print the Management server `config.yaml` snippet

## Usage

Run this on the Linux Relay host:

```bash
chmod +x setup-relay.sh
./setup-relay.sh
```

Or run the one-line installer:

```bash
curl -fsSL https://raw.githubusercontent.com/kos991/net_relay/main/install.sh | bash
```

Custom install directory:

```bash
curl -fsSL https://raw.githubusercontent.com/kos991/net_relay/main/install.sh | INSTALL_DIR="$HOME/netbird-relay-installer" bash
```

## Notes

- No manual certificate file handling is needed.
- No `80/443` exposure is required for the Relay itself.
- Use a Cloudflare API token with `Zone.Zone:Read` and `Zone.DNS:Edit`.
- The installer generates `caddy/Caddyfile`, `.env`, `relay.env`, and `docker-compose.yml`.
