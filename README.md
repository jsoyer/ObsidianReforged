# 🪨 ObsidianReforged — Minecraft Java + Geyser + Floodgate + Paper on Docker

A Docker container for a fully-featured Minecraft Java dedicated server with Geyser and Floodgate, allowing **Bedrock clients to join your Java server**.

Runs the [Paper](https://papermc.io/) server with plugin support (Paper / Spigot / Bukkit), multi-arch builds, and automatic updates.

---

## 🙏 Credits

This project is a fork of [Legendary Java Minecraft + Geyser + Floodgate + Paper Dedicated Server for Docker](https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate) by **James A. Chambers** ([@TheRemote](https://github.com/TheRemote)).

A huge thank you to James for the original work, which this project builds upon.
The original Docker image is available at [05jchambers/legendary-minecraft-geyser-floodgate](https://hub.docker.com/r/05jchambers/legendary-minecraft-geyser-floodgate).

---

## ✨ Features

- 🎮 Java and Bedrock clients can connect to the same server (via Geyser + Floodgate)
- ⚡ Runs the highly efficient Paper Minecraft server
- 🔑 Bedrock players authenticate with their Bedrock credentials (Floodgate)
- 💾 Named Docker volume for safe, accessible server data storage
- 🧩 Plugin support: Paper, Spigot, Bukkit
- 🔄 Automatic backups on each restart (rolling, configurable)
- 🚀 Auto-updates to the latest Minecraft version on start
- 🍓 Runs on all Docker platforms including Raspberry Pi (multi-arch)
- ☸️ Kubernetes support

---

## 🐳 Docker Usage

**1. Create a named volume:**

```bash
docker volume create yourvolumename
```

**2. Start the server:**

Default ports:
```bash
docker run -it \
  -v yourvolumename:/minecraft \
  -p 25565:25565 \
  -p 19132:19132/udp \
  -p 19132:19132 \
  --restart unless-stopped \
  jsoyer/obsidian-reforged:latest
```

Custom ports:
```bash
docker run -it \
  -v yourvolumename:/minecraft \
  -p 12345:12345 -e Port=12345 \
  -p 54321:54321/udp -p 54321:54321 -e BedrockPort=54321 \
  --restart unless-stopped \
  jsoyer/obsidian-reforged:latest
```

Specific Minecraft version:
```bash
docker run -it \
  -v yourvolumename:/minecraft \
  -p 25565:25565 -p 19132:19132/udp -p 19132:19132 \
  -e Version=1.21.4 \
  --restart unless-stopped \
  jsoyer/obsidian-reforged:latest
```

Memory limit (in MB):
```bash
docker run -it \
  -v yourvolumename:/minecraft \
  -p 25565:25565 -p 19132:19132/udp -p 19132:19132 \
  -e MaxMemory=2048 \
  --restart unless-stopped \
  jsoyer/obsidian-reforged:latest
```

---

## 📦 Docker Compose

```yaml
version: "3.5"
services:
  minecraft:
    image: jsoyer/obsidian-reforged:latest
    restart: "unless-stopped"
    ports:
      - 25565:25565
      - 19132:19132
      - 19132:19132/udp
    volumes:
      - minecraft:/minecraft
    stdin_open: true
    tty: true
    entrypoint: ["/bin/bash", "/scripts/start.sh"]
    environment:
      Port: "25565"
      BedrockPort: "19132"
      TZ: "America/Denver"
      #BackupCount: 10
      #MaxMemory: 2048
      #Version: 1.21.11
      #NoBackup: "plugins"
      #NoPermCheck: "Y"
      #NoViaVersion: "Y"
      #QuietCurl: "Y"
volumes:
  minecraft:
    driver: local
```

---

## ☸️ Kubernetes Usage

Create a suitable PVC using your preferred StorageClass, then pass `k8s="True"` as an environment variable:

```yaml
env:
  - name: MaxMemory
    value: '1024'
  - name: TZ
    value: Europe/London
  - name: k8s
    value: "True"
```

> ⚠️ Terminal features are not available in Kubernetes mode.

Example manifests are available in the `/kubernetes` folder (based on Longhorn storage + LoadBalancer — adjust to fit your environment).

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `Port` | `25565` | Java server port |
| `BedrockPort` | `19132` | Geyser/Bedrock port |
| `Version` | latest | Minecraft version (e.g. `1.21.4`) |
| `MaxMemory` | unlimited | Max JVM memory in MB |
| `TZ` | `America/Denver` | Timezone ([list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)) |
| `BackupCount` | `10` | Number of rolling backups to keep |
| `NoBackup` | — | Comma-separated folders to exclude from backups |
| `NoPermCheck` | — | Set to `Y` to skip permissions check on startup |
| `NoViaVersion` | — | Set to `Y` to disable the ViaVersion plugin |
| `QuietCurl` | — | Set to `Y` to suppress curl download output |

---

## 📁 Accessing Server Files

Find the volume path on the host:

```bash
docker volume inspect yourvolumename
```

Typical paths:
- 🐧 **Linux:** `/var/lib/docker/volumes/yourvolumename/_data`
- 🪟 **Windows:** `C:\ProgramData\DockerDesktop` or `\wsl$\docker-desktop-data\...`
- 🍎 **Mac:** `~/Library/Containers/com.docker.docker/Data/vms/0/`

Key files:
- 🔧 Server config: `server.properties`
- 💾 Backups: `backups/`
- 🌉 Geyser config: `plugins/Geyser-Spigot/config.yml`
- 🔓 Floodgate config: `plugins/floodgate/config.yml`

---

## 🧩 Plugins

Drop any `.jar` plugin file into the `plugins/` folder on your volume and restart the container.

Compatible with Paper / Spigot / Bukkit plugins.
Browse plugins at [dev.bukkit.org](https://dev.bukkit.org/bukkit-plugins).

---

## 🛠️ Troubleshooting

### ☁️ Oracle Cloud VMs

If nobody can connect, you need to open ports in **two places**:
1. The Virtual Cloud Network (VCN) security list (TCP/UDP ingress)
2. A Network Security Group assigned to your instance

Both are required.

### 🪟 Hyper-V (UDP bug)

Use a **Generation 1 VM** with the **Legacy LAN** network driver.

Alternatively, disable TX offloading:

```bash
sudo apt install ethtool
sudo ethtool -K eth0 tx off
```

To make it persistent, add `offload-tx off` to your network interface config in `/etc/network/interfaces`.

---

## 📜 Update History

- 🪨 **March 2026** — Fork to ObsidianReforged, project relaunched
- **January 2026** — Update to 1.21.11, migrate to Paper API v3
- **July 2025** — Multi-arch builds via `buildx`
- **July 2025** — Default version updated to 1.21.8
- **February 2025** — Default version updated to 1.21.4, fix Paper API URLs
- **December 2024** — Fix ViaVersion, server no longer runs as root (runs as `minecraft` user)
- **June 2024** — Default version updated to 1.21
- **May 2024** — OpenJDK updated to 21, default version 1.20.6
- **April 2023** — Add `NoViaVersion` environment variable
- **March 2023** — Migrate `paper.yml` to `paper-global.yml`
- **March 2023** — Add ViaVersion plugin for cross-version client support
- **November 2022** — Add `QuietCurl` environment variable
- **October 2022** — Add `BackupCount`, `NoBackup`, `NoPermCheck` environment variables; RISC arch support; switch to `ubuntu:rolling`
- **August 2022** — Initial release (upstream)
