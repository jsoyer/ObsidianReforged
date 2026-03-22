# Minecraft Java Paper Server + Geyser + Floodgate Docker Container
# Author: James A. Chambers - https://jamesachambers.com/minecraft-java-bedrock-server-together-geyser-floodgate/
# GitHub Repository: https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate

# Pin to a specific Ubuntu LTS release for reproducible builds
FROM ubuntu:24.04

# Fetch dependencies — no sudo (privilege drop handled by gosu), no binfmt-support (build-host only)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless tzdata curl unzip net-tools gawk openssl findutils pigz \
    libc6 libcrypt1 libcurl4-openssl-dev ca-certificates nano jq gosu \
    && apt-get clean && rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Set port environment variable
ENV Port=25565

# Set Bedrock port environment variable
ENV BedrockPort=19132

# Optional maximum memory Minecraft is allowed to use
ENV MaxMemory=

# Optional Paper Minecraft Version override
ENV Version="1.21.11"

# Optional Timezone
ENV TZ="America/Denver"

# Optional folder to ignore during backup operations
ENV NoBackup=""

# Number of rolling backups to keep
ENV BackupCount=10

# Optional switch to skip permissions check
ENV NoPermCheck=""

# Optional switch to tell curl to suppress the progress meter which generates much less noise in the logs
ENV QuietCurl=""

# Optional switch to disable ViaVersion
ENV NoViaVersion=""

# Optional switch to use ViaVersion snapshot from Jenkins CI instead of stable GitHub releases
ENV ViaVersionSnapshot=""

# IPV4 Ports
EXPOSE 25565/tcp
EXPOSE 19132/tcp
EXPOSE 19132/udp

# Copy scripts to minecraftbe folder and make them executable
RUN mkdir /scripts
COPY *.sh /scripts/
COPY *.yml /scripts/
COPY server.properties /scripts/
RUN chmod -R +x /scripts/*.sh

# Set entrypoint to start.sh script
ENTRYPOINT ["/bin/bash", "/scripts/start.sh"]
