# Changelog

All notable changes to ObsidianReforged are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

---

## 1.0.0 - 2026-03-22

### Features
- Multi-arch Docker image (amd64, arm64, arm/v7, riscv64, s390x, ppc64le) via `buildx`
- Paper, Geyser, Floodgate, and ViaVersion auto-updated on every container start
- SHA256 integrity verification for all downloaded JARs
- `safe_download()` helper: atomic downloads with fallback to existing file on failure
- `run_curl()` helper with `QuietCurl` support and shared headers
- Automatic rolling backups with `pigz` multi-core compression when available
- Configurable backup exclusions via `NoBackup` env var
- `ViaVersionSnapshot` env var for Jenkins CI snapshot builds
- Privilege drop via `gosu` (replaces `sudo`)
- GitHub Actions CI: ShellCheck, Hadolint, yamllint
- GitHub Actions build: multi-arch push to Docker Hub + GHCR with SBOM and provenance
- GitHub Actions security scan: weekly Trivy container + filesystem scan
- Kubernetes manifests: namespace, PVC, ServiceAccount, ConfigMap, NetworkPolicy, Deployment, Service
- Monitoring stack: `docker-compose.monitoring.yml` with Prometheus + Grafana overlay

### Fixes
- `BedrockPort` variable collision — was incorrectly overwriting `Port`
- `MaxMemory` arithmetic comparison on empty string — guarded by regex check
- ViaVersion curl `-k` flag (TLS disabled) — removed
- Paper SHA256 fetched but never verified — now checked with `sha256sum`
- `EXPOSE 19132/tcp` removed — Bedrock/RakNet is UDP only
- `FROM ubuntu:rolling` pinned to `ubuntu:24.04`

### Security
- `set -Eeuo pipefail` enforced throughout `start.sh`
- `server.properties`: `rate-limit=50`, `enforce-secure-profile=true`, `spawn-protection=16`
- Geyser `config.yml`: password auth disabled, IP logging disabled, metrics disabled
- Paper `paper-global.yml`: IP logging disabled, timings disabled
- Kubernetes: `runAsNonRoot`, `allowPrivilegeEscalation: false`, `drop: ALL`, NetworkPolicy

### Refactor
- Forked from [TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate](https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate) — relaunched as ObsidianReforged
- `net-tools` replaced with `iproute2` (`ip route`)
- `which` replaced with `command -v`
- `pushd`/`popd` replaced with subshell `(cd ...; ...)`
- Duplicated curl headers extracted to `readonly UA` constant and `run_curl()` function
- Single ViaVersion API call (was two)
- Explicit `COPY` filenames in Dockerfile (no globs)
- `libcurl4-openssl-dev` (headers) replaced with `libcurl4` (runtime only)
