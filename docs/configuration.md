# Configuration Reference

All environment variables can be passed with `-e` on `docker run` or under `environment:` in `docker-compose.yml`.

## Server ports

| Variable | Default | Description |
|----------|---------|-------------|
| `Port` | `25565` | Java Edition TCP port |
| `BedrockPort` | `19132` | Bedrock/Geyser UDP port (RakNet) |

## Java heap

| Variable | Default | Description |
|----------|---------|-------------|
| `MaxMemory` | *(unset)* | JVM max heap in MB (`-Xmx`). When unset, no upper limit is set — the JVM manages it. Example: `2048` for 2 GB. Keep below container memory limit. |

## Minecraft version

| Variable | Default | Description |
|----------|---------|-------------|
| `Version` | `1.21.11` | Minecraft version used to download the Paper JAR. Set this to pin a specific version and prevent auto-upgrades. |

## Plugin versions (optional pinning)

| Variable | Default | Description |
|----------|---------|-------------|
| `GeyserVersion` | *(unset = latest)* | Pin Geyser to a specific version, e.g. `2.4.0`. Empty or unset always pulls latest. |
| `FloodgateVersion` | *(unset = latest)* | Pin Floodgate to a specific version, e.g. `2.2.3`. |

## ViaVersion

| Variable | Default | Description |
|----------|---------|-------------|
| `NoViaVersion` | *(unset)* | Set to any non-empty value (e.g. `Y`) to disable ViaVersion entirely. |
| `ViaVersionSnapshot` | *(unset)* | Set to any non-empty value to install ViaVersion from Jenkins CI (snapshot build) instead of the latest stable GitHub release. |

## Backups

| Variable | Default | Description |
|----------|---------|-------------|
| `BackupCount` | `10` | Number of rolling `.tar.gz` backups to keep in `/minecraft/backups`. Must be a positive integer. |
| `NoBackup` | *(unset)* | Comma-separated list of subdirectories to exclude from backups. Example: `plugins,logs`. Path traversal characters are rejected. |

## Behaviour flags

| Variable | Default | Description |
|----------|---------|-------------|
| `QuietCurl` | *(unset)* | Set to any non-empty value to suppress curl download progress output. Useful in CI or when logs are noisy. |
| `NoPermCheck` | *(unset)* | Set to any non-empty value to skip the permissions check on startup. |

## Timezone

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/Denver` | Container timezone used for backup file timestamps and server logs. Any valid tz database name (e.g. `Europe/Paris`, `UTC`). |

## Example docker-compose.yml

```yaml
environment:
  Port: "25565"
  BedrockPort: "19132"
  TZ: "Europe/Paris"
  Version: "1.21.11"
  MaxMemory: "2048"
  BackupCount: "7"
  NoBackup: "logs"
  QuietCurl: "Y"
  # GeyserVersion: "2.4.0"
  # FloodgateVersion: "2.2.3"
  # NoViaVersion: "Y"
```
