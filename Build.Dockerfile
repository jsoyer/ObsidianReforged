# ObsidianReforged — Minecraft Java + Geyser + Floodgate + Paper on Docker
# GitHub: https://github.com/jsoyer/ObsidianReforged

# Pin to Ubuntu 24.04 LTS — security patches flow in automatically on each rebuild.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="ObsidianReforged" \
      org.opencontainers.image.description="Minecraft Java + Geyser + Floodgate + Paper on Docker" \
      org.opencontainers.image.source="https://github.com/jsoyer/ObsidianReforged" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies and create /scripts in a single layer
# - gosu: safe privilege drop (replaces sudo)
# - iproute2: provides `ip route` for network detection (replaces legacy net-tools)
# - libcurl4: runtime curl library (not the -dev headers)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless tzdata curl unzip gawk openssl findutils pigz \
    libcurl4t64 ca-certificates nano jq gosu iproute2 \
    && apt-get clean && rm -rf /var/cache/apt/* /var/lib/apt/lists/* \
    && mkdir /scripts

# Environment variables — all overridable at runtime via -e or docker-compose
ENV Port=25565
ENV BedrockPort=19132
ENV MaxMemory=""
ENV Version="1.21.11"
ENV TZ="America/Denver"
ENV NoBackup=""
ENV BackupCount=10
ENV NoPermCheck=""
ENV QuietCurl=""
ENV NoViaVersion=""
ENV ViaVersionSnapshot=""
ENV GeyserVersion=""
ENV FloodgateVersion=""

# Java port (TCP) and Bedrock/Geyser port (UDP only — RakNet does not use TCP)
EXPOSE 25565/tcp
EXPOSE 19132/udp

# Explicit COPY — avoids glob surprises from new files added to the repo
COPY --chmod=755 start.sh /scripts/
COPY bukkit.yml spigot.yml paper-global.yml server.properties config.yml /scripts/

# Health check — Minecraft server is reachable on the Java port
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD bash -c 'echo > /dev/tcp/localhost/25565' || exit 1

ENTRYPOINT ["/bin/bash", "/scripts/start.sh"]
