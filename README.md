# ObsidianReforged — Minecraft Java + Geyser + Floodgate on Docker

[![Build & Push](https://github.com/jsoyer/ObsidianReforged/actions/workflows/build.yml/badge.svg)](https://github.com/jsoyer/ObsidianReforged/actions/workflows/build.yml)
[![CI](https://github.com/jsoyer/ObsidianReforged/actions/workflows/ci.yml/badge.svg)](https://github.com/jsoyer/ObsidianReforged/actions/workflows/ci.yml)
[![Security Scan](https://github.com/jsoyer/ObsidianReforged/actions/workflows/security-scan.yml/badge.svg)](https://github.com/jsoyer/ObsidianReforged/actions/workflows/security-scan.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/jsoyer/obsidian-reforged)](https://hub.docker.com/r/jsoyer/obsidian-reforged)

A Docker image for a Minecraft Java server with [Geyser](https://geysermc.org/) and [Floodgate](https://wiki.geysermc.org/floodgate/), letting **Bedrock clients join your Java server** — no extra proxy required.

Runs [Paper](https://papermc.io/) with full plugin support, multi-arch builds (amd64, arm64, arm/v7, riscv64…), and automatic plugin updates on startup.

---

## Credits

Fork of [Legendary Java Minecraft + Geyser + Floodgate](https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate) by **James A. Chambers** ([@TheRemote](https://github.com/TheRemote)). Thank you for the original work.

---

## Features

- Java and Bedrock clients connect to the same server (Geyser + Floodgate)
- Bedrock players authenticate with their own credentials (no Java account needed)
- Paper server — high performance, full plugin ecosystem (Paper / Spigot / Bukkit)
- Automatic backups on each restart (rolling, configurable count)
- Auto-updates Paper, Geyser, Floodgate, and ViaVersion on startup
- Multi-arch: amd64, arm64, arm/v7, riscv64, s390x, ppc64le
- Signed images — verifiable with cosign (see [Verify the image](#verify-the-image))
- Kubernetes manifests included

---

## Quick start

```bash
docker volume create mc-data

docker run -it \
  -v mc-data:/minecraft \
  -p 25565:25565 \
  -p 19132:19132/udp \
  --restart unless-stopped \
  jsoyer/obsidian-reforged:latest
```

Java players connect to `your-host:25565`.
Bedrock players connect to `your-host:19132`.

First startup takes 2–3 minutes (Paper bootstrap + plugin downloads).

---

## Docker Compose

Use the provided `docker-compose.yml` at the root of this repo:

```bash
docker compose up -d
docker compose logs -f minecraft
```

To customise, uncomment and adjust the environment variables in `docker-compose.yml`:

```yaml
environment:
  Port: "25565"
  BedrockPort: "19132"
  TZ: "America/Denver"
  #MaxMemory: 2048       # Max JVM heap in MB
  #Version: "1.21.11"   # Pin a specific Minecraft version
  #BackupCount: 10
```

See [Environment variables](#environment-variables) for the full reference.

### Production overlay

Pin the image tag and tighten resource limits:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Development overlay

Bind-mount `start.sh` for live iteration:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `Port` | `25565` | Java server port (TCP) |
| `BedrockPort` | `19132` | Geyser/Bedrock port (UDP) |
| `Version` | `1.21.11` | Minecraft version to run (e.g. `1.21.4`) |
| `MaxMemory` | — | Max JVM heap in MB. Unset = unlimited (not recommended) |
| `TZ` | `America/Denver` | Timezone — [full list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) |
| `BackupCount` | `10` | Number of rolling backups to keep on startup |
| `NoBackup` | — | Comma-separated folders to exclude from backups (e.g. `plugins,cache`) |
| `NoPermCheck` | — | Set to `Y` to skip the permissions check on startup |
| `NoViaVersion` | — | Set to `Y` to disable the ViaVersion plugin |
| `ViaVersionSnapshot` | — | Set to `Y` to install the latest ViaVersion snapshot instead of stable |
| `GeyserVersion` | `latest` | Pin Geyser to a specific version (e.g. `2.4.0`) |
| `FloodgateVersion` | `latest` | Pin Floodgate to a specific version |
| `QuietCurl` | — | Set to `Y` to suppress curl download progress output |

---

## Kubernetes

Ready-to-apply manifests in `kubernetes/`:

```bash
kubectl apply -f kubernetes/
```

| File | Resource |
|------|----------|
| `01-namespace.yaml` | Namespace `minecraft` |
| `02-pvc.yaml` | PersistentVolumeClaim (3 Gi) |
| `03-deployment.yaml` | Deployment with liveness + readiness probes |
| `04-service.yaml` | LoadBalancer service (Java TCP + Bedrock UDP) |
| `05-serviceaccount.yaml` | Dedicated ServiceAccount |
| `06-configmap.yaml` | Environment variables |
| `07-networkpolicy.yaml` | Default-deny + player ports + outbound HTTPS/DNS |

See [docs/kubernetes.md](docs/kubernetes.md) for storage class configuration, resource tuning, and rollback procedures.

---

## Monitoring

A Prometheus + Grafana + cAdvisor stack is available as a compose overlay:

```bash
# Required — set in a .env file at the project root
RCON_PASSWORD=your-rcon-password
GRAFANA_PASSWORD=your-grafana-password
```

```bash
docker compose -f docker-compose.yml \
               -f docker-compose.monitoring.yml up -d
```

- Grafana: `http://localhost:3000` — SRE dashboard included (availability SLO, player count, container resources)
- Prometheus: `http://localhost:9090` — loopback only

For alert definitions and SLO targets, see `monitoring/alert_rules.yml`.
For alert response procedures, see [docs/runbooks.md](docs/runbooks.md).

> Monitoring requires `enable-rcon=true` in `server.properties` and the `RCON_PASSWORD` env var.

---

## Accessing server files

```bash
# Find the volume path
docker volume inspect mc-data
```

Typical paths:
- **Linux:** `/var/lib/docker/volumes/mc-data/_data`
- **Windows:** `\\wsl$\docker-desktop-data\...`
- **macOS:** `~/Library/Containers/com.docker.docker/Data/vms/0/`

Key locations inside the volume:

| Path | Contents |
|------|----------|
| `server.properties` | Server configuration |
| `backups/` | Rolling tar.gz backups |
| `plugins/` | Plugin JARs |
| `plugins/Geyser-Spigot/config.yml` | Geyser configuration |
| `plugins/floodgate/config.yml` | Floodgate configuration |

---

## Plugins

Drop any `.jar` into `plugins/` on your volume and restart the container.

Compatible with Paper, Spigot, and Bukkit plugins.
Browse at [dev.bukkit.org](https://dev.bukkit.org/bukkit-plugins) or [modrinth.com](https://modrinth.com/plugins).

---

## Verify the image

Images are signed with [cosign](https://docs.sigstore.dev/cosign/overview/) via Sigstore keyless OIDC. Verify before running:

```bash
cosign verify \
  --certificate-identity-regexp "github.com/jsoyer" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/jsoyer/obsidianreforged:latest
```

---

## Troubleshooting

### Nobody can connect (Oracle Cloud)

Open ports in **two places**:
1. Virtual Cloud Network security list (TCP + UDP ingress rules)
2. Network Security Group attached to your instance

Both are required — either alone is not sufficient.

### Bedrock UDP not working (Hyper-V)

Use a **Generation 1 VM** with the **Legacy LAN** network adapter.

Alternatively, disable TX offloading:

```bash
sudo apt install ethtool
sudo ethtool -K eth0 tx off
```

To persist across reboots, add `offload-tx off` to your interface config in `/etc/network/interfaces`.

### Server takes too long to start

The first startup downloads Paper, Geyser, Floodgate, and ViaVersion — allow 3–5 minutes. Subsequent starts are faster (only downloads updates).

Set `QuietCurl=Y` to suppress download progress if logs are too noisy.

---

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/configuration.md](docs/configuration.md) | Full environment variable reference |
| [docs/deployment.md](docs/deployment.md) | Multi-env deployment, Docker Secrets, rollback |
| [docs/kubernetes.md](docs/kubernetes.md) | Kubernetes walkthrough |
| [docs/runbooks.md](docs/runbooks.md) | Alert response runbooks |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Local build, lint, release process |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Credits

This project is a fork of [Legendary Java Minecraft + Geyser + Floodgate](https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate) by **James A. Chambers** ([@TheRemote](https://github.com/TheRemote)).
Original image: [05jchambers/legendary-minecraft-geyser-floodgate](https://hub.docker.com/r/05jchambers/legendary-minecraft-geyser-floodgate).
