# Multi-Node Relay Deployment Design

## Goal

Add first-class multi-node deployment support to the NetBird Relay installer and OVA first-boot flow.

Each relay node remains an independent NetBird relay instance. Nodes do not form an internal relay cluster. Multi-node behavior is achieved by using the same relay auth secret across all nodes and adding every node address to the NetBird Management `config.yaml`.

## User Experience

`setup-relay.sh` will ask for a deployment mode:

1. Create a new relay node group
2. Join an existing relay node group

In create mode, the user can enter a secret or leave it empty to generate one. The installer prints the generated or supplied secret at the end and tells the user to reuse it on additional nodes.

In join mode, the user must enter the existing node group secret. Empty input is rejected so a second node cannot accidentally create a separate relay group.

Both modes continue to collect the current per-node settings:

- Relay domain
- ACME email
- Cloudflare API token
- Relay TCP port
- STUN UDP port
- Relay image
- Certificate sync interval

## OVA First Boot

The OVA first-boot script continues to call `setup-relay.sh`. Multi-node support lives in the installer, so OVA users get the same create or join flow without duplicating installer logic.

The first-boot banner will mention that the OVA supports creating a new relay node group or joining an existing group.

## Generated Files

The existing `.env` remains the main runtime configuration file.

The installer will add:

```env
RELAY_GROUP_MODE=create
RELAY_NODE_NAME=relay-a.example.com
```

For joined nodes, `RELAY_GROUP_MODE=join`.

`RELAY_NODE_NAME` defaults to the relay domain. It is stored so management commands can display which node is configured.

## Management Configuration Output

After installation, the summary will continue to show the current node addresses:

```yaml
server:
  relays:
    addresses:
      - "rels://relay-a.example.com:8443"
    secret: "shared-secret"
  stuns:
    - uri: "stun:relay-a.example.com:3478"
      proto: udp
```

For join mode, the summary will also clearly show the snippets to append to an existing Management config:

```yaml
- "rels://relay-b.example.com:8443"
```

```yaml
- uri: "stun:relay-b.example.com:3478"
  proto: udp
```

The installer will emphasize that all relay nodes and the Management server must use the same secret.

## Error Handling

Join mode rejects an empty relay auth secret.

Create mode preserves the existing behavior: an empty secret generates a strong random secret with `openssl` or `python3`.

Port validation remains unchanged.

If Docker, Docker Compose, image pulls, Caddy, certificate sync, or relay startup fail, the existing failure behavior remains unchanged.

## Testing

Update `tests/ova-scripts-check.sh` to verify:

- `setup-relay.sh` contains the create node group prompt.
- `setup-relay.sh` contains the join existing node group prompt.
- `setup-relay.sh` rejects an empty secret in join mode.
- `ova/files/net-relay-firstboot` mentions multi-node support.
- The installer still prints Management `relays` and `stuns` configuration.

## Out of Scope

This design does not add SSH-based batch deployment.

This design does not modify the NetBird relay binary or protocol.

This design does not add relay load balancing behind a single shared DNS name. Each node should use its own reachable domain and port.
