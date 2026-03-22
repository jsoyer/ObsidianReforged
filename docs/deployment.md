# Deployment Guide

## Environments

ObsidianReforged ships three Compose files designed to be layered:

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Base configuration — works standalone |
| `docker-compose.prod.yml` | Production overrides (pinned tag, tighter limits, quiet logs) |
| `docker-compose.dev.yml` | Development overrides (bind-mounted script, no backups, isolated volume) |

### Production deployment

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Before going to production, edit `docker-compose.prod.yml` and set:
- The image tag to the version you want to run (e.g. `1.0.0`)
- `MaxMemory` to ~80% of your container memory limit
- `TZ` in `docker-compose.yml` to your timezone

### Development loop

```bash
# Start with dev overrides (start.sh bind-mounted, isolated volume)
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Edit start.sh, then restart — no rebuild needed
docker compose -f docker-compose.yml -f docker-compose.dev.yml restart minecraft
```

---

## Rollback

### Docker Compose

```bash
# Pull and start a specific previous version
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  --env-file /dev/null \
  up -d --no-build \
  -e IMAGE=jsoyer/obsidian-reforged:0.9.0
```

Or simply edit the tag in `docker-compose.prod.yml` and re-run `up -d`.

```bash
# List available tags
docker images jsoyer/obsidian-reforged
```

### Kubernetes

```bash
# View rollout history
kubectl rollout history deployment/minecraft -n minecraft

# Roll back to the previous revision
kubectl rollout undo deployment/minecraft -n minecraft

# Roll back to a specific revision
kubectl rollout undo deployment/minecraft -n minecraft --to-revision=2

# Pin to a specific image tag directly
kubectl set image deployment/minecraft \
  minecraft=jsoyer/obsidian-reforged:1.0.0 \
  -n minecraft

# Watch the rollback progress
kubectl rollout status deployment/minecraft -n minecraft
```

---

## Image signature verification (cosign)

Every image pushed by the CI pipeline is signed with Sigstore keyless signing.
Verify before pulling in security-sensitive environments:

```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/jsoyer/ObsidianReforged" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  jsoyer/obsidian-reforged:latest
```

A successful verification prints the signing certificate and confirms the image
was built by the official GitHub Actions workflow.

---

## Docker Secrets (production secret management)

The server does not currently require secrets for basic operation. If you enable
RCON or add plugins that require API keys, use Docker Secrets instead of
environment variables.

### Swarm / docker-compose secrets example

```yaml
# docker-compose.prod.yml addition
services:
  minecraft:
    secrets:
      - rcon_password
    environment:
      # Read the secret inside start.sh or a plugin config
      RCON_PASSWORD_FILE: /run/secrets/rcon_password

secrets:
  rcon_password:
    external: true   # created with: docker secret create rcon_password -
```

Create the secret:

```bash
echo "your-strong-password" | docker secret create rcon_password -
```

### Kubernetes secrets example

```bash
kubectl create secret generic minecraft-secrets \
  --from-literal=rcon-password="your-strong-password" \
  -n minecraft
```

Reference in the deployment:

```yaml
env:
  - name: RCON_PASSWORD
    valueFrom:
      secretKeyRef:
        name: minecraft-secrets
        key: rcon-password
```

---

## Multi-server setup

To run two independent servers on the same host:

```bash
# Server 1 — survival (default ports, default volume)
docker compose -f docker-compose.yml up -d

# Server 2 — creative (different ports, different volume)
docker compose \
  -f docker-compose.yml \
  -p mc-creative \
  up -d \
  --env-file /dev/null \
  -e Port=25566 \
  -e BedrockPort=19133
```

Or duplicate `docker-compose.yml`, rename the volume, and map different host ports.
