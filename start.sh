#!/bin/bash
# Legendary Paper Minecraft Java Server Docker + Geyser/Floodgate server startup script
# Author: James A. Chambers - https://jamesachambers.com/minecraft-java-bedrock-server-together-geyser-floodgate/
# GitHub Repository: https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate

# If running as root, create 'minecraft' user and restart script as 'minecraft' user
if [ "$(id -u)" = '0' ]; then
    echo "Script is running as root, switching to 'minecraft' user..."

    if ! id minecraft >/dev/null 2>&1; then
        echo "Creating 'minecraft' user..."
        useradd -m -r -s /bin/bash minecraft
    fi

    chown -R minecraft:minecraft /minecraft

    exec gosu minecraft "$0" "$@"
fi

echo "Paper Minecraft Java Server Docker + Geyser/Floodgate script by James A. Chambers"
echo "Latest version always at https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate"
echo "Don't forget to set up port forwarding on your router!  The default port is 25565 and the Bedrock port is 19132"

if [ ! -d '/minecraft' ]; then
    echo "ERROR:  A named volume was not specified for the minecraft server data.  Please create one with: docker volume create yourvolumename"
    echo "Please pass the new volume to docker like this:  docker run -it -v yourvolumename:/minecraft"
    exit 1
fi

if [ -z "$Port" ]; then
    Port="25565"
fi
echo "Port used: $Port"

if [ -z "$BedrockPort" ]; then
    BedrockPort="19132"
fi
echo "Bedrock port used: $BedrockPort"

# Change directory to server directory
cd /minecraft

# Create backups/downloads folder if it doesn't exist
if [ ! -d "/minecraft/downloads" ]; then
    mkdir -p /minecraft/downloads
fi
if [ ! -d "/minecraft/config" ]; then
    mkdir -p /minecraft/config
fi
if [ ! -d "/minecraft/backups" ]; then
    mkdir -p /minecraft/backups
fi
if [ ! -d "/minecraft/plugins/Geyser-Spigot" ]; then
    mkdir -p /minecraft/plugins/Geyser-Spigot
fi

# Check if network interfaces are up
NetworkChecks=0
if [ -e '/sbin/route' ]; then
    DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
else
    DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
fi
while [ -z "$DefaultRoute" ]; do
    echo "Network interface not up, will try again in 1 second"
    sleep 1
    if [ -e '/sbin/route' ]; then
        DefaultRoute=$(/sbin/route -n | awk '$4 == "UG" {print $2}')
    else
        DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
    fi
    NetworkChecks=$((NetworkChecks + 1))
    if [ "$NetworkChecks" -gt 20 ]; then
        echo "Waiting for network interface to come up timed out - starting server without network connection ..."
        break
    fi
done

# Ownership is already set to minecraft by the root startup block above.
# This step is a no-op when NoPermCheck is unset but kept for logging clarity.
if [ -z "$NoPermCheck" ]; then
    echo "Permissions set by startup block."
else
    echo "Skipping permissions check due to NoPermCheck flag"
fi

# Back up server
if [ -d "world" ]; then
    # Build extra --exclude args from NoBackup (comma-separated), sanitised to safe path chars only
    extraExcludes=()
    if [ -n "$NoBackup" ]; then
        IFS=',' read -ra ADDR <<< "$NoBackup"
        for i in "${ADDR[@]}"; do
            if [[ "$i" =~ ^[a-zA-Z0-9_./-]+$ ]]; then
                extraExcludes+=(--exclude="./$i")
            else
                echo "WARNING: Skipping unsafe NoBackup entry: $i"
            fi
        done
    fi
    BackupFile="backups/$(date +%Y.%m.%d.%H.%M.%S).tar.gz"
    if [ -n "$(which pigz)" ]; then
        echo "Backing up server (all cores) to minecraft/backups folder"
        tar -I pigz --exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./paperclip.jar' \
            "${extraExcludes[@]}" -pvcf "$BackupFile" ./*
    else
        echo "Backing up server (single core, pigz not found) to minecraft/backups folder"
        tar --exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./paperclip.jar' \
            "${extraExcludes[@]}" -pvcf "$BackupFile" ./*
    fi
fi

# Rotate backups — guard against empty/invalid BackupCount
BackupCount="${BackupCount:-10}"
if ! [[ "$BackupCount" =~ ^[0-9]+$ ]] || [ "$BackupCount" -lt 1 ]; then
    echo "WARNING: BackupCount is invalid ('$BackupCount'), defaulting to 10"
    BackupCount=10
fi
if [ -d /minecraft/backups ]; then
    pushd /minecraft/backups
    ls -1tr | head -n -"$BackupCount" | xargs -d '\n' rm -f --
    popd
fi

# Copy config files if this is a brand new server
if [ ! -e "/minecraft/bukkit.yml" ]; then
    cp /scripts/bukkit.yml /minecraft/bukkit.yml
fi
if [ ! -e "/minecraft/config/paper-global.yml" ]; then
    cp /scripts/paper-global.yml /minecraft/config/paper-global.yml
fi
if [ ! -e "/minecraft/spigot.yml" ]; then
    cp /scripts/spigot.yml /minecraft/spigot.yml
fi
if [ ! -e "/minecraft/server.properties" ]; then
    cp /scripts/server.properties /minecraft/server.properties
fi
if [ ! -e "/minecraft/plugins/Geyser-Spigot/config.yml" ]; then
    cp /scripts/config.yml /minecraft/plugins/Geyser-Spigot/config.yml
fi

# Test internet connectivity first
# Update paperclip.jar
echo "Updating to most recent paperclip version ..."

# Test internet connectivity first
if [ -z "$QuietCurl" ]; then
    curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -s https://papermc.io -o /dev/null
else
    curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -s https://papermc.io -o /dev/null
fi

if [ "$?" != 0 ]; then
    echo "Unable to connect to update website (internet connection may be down).  Skipping update ..."
else
    # Get latest build using PaperMC API v3
    Build=$(curl -s -L "https://fill.papermc.io/v3/projects/paper/versions/$Version" | jq -r '.builds[0]' 2>/dev/null)
    if [[ -n "$Build" && "$Build" != "null" ]]; then
        echo "Latest paperclip build found: $Build"
        # Get the SHA256 hash and filename for the download URL (pipe directly to avoid newline issues in commit messages)
        SHA256=$(curl -s -L "https://fill.papermc.io/v3/projects/paper/versions/$Version/builds/$Build" | jq -r '.downloads["server:default"].checksums.sha256' 2>/dev/null)
        FileName="paper-$Version-$Build.jar"
        if [[ -n "$SHA256" && "$SHA256" != "null" ]]; then
            echo "Downloading Paper $Version build $Build..."
            if [ -z "$QuietCurl" ]; then
                curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/paperclip.jar "https://fill-data.papermc.io/v1/objects/$SHA256/$FileName"
            else
                curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/paperclip.jar "https://fill-data.papermc.io/v1/objects/$SHA256/$FileName"
            fi
            echo "Verifying Paper download..."
            if ! echo "$SHA256  /minecraft/paperclip.jar" | sha256sum -c --quiet; then
                echo "ERROR: SHA256 verification failed for Paper! The download may be corrupt or tampered with. Aborting."
                rm -f /minecraft/paperclip.jar
                exit 1
            fi
            echo "Paper SHA256 verified."
        else
            echo "Unable to retrieve download info for Paper build $Build"
        fi
    else
        echo "Unable to retrieve latest Paper build (got result of $Build)"
    fi

    # Update Floodgate
    echo "Updating Floodgate..."
    FloodgateBuildInfo=$(curl -s -L "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest")
    FloodgateSHA256=$(echo "$FloodgateBuildInfo" | jq -r '.downloads.spigot.sha256' 2>/dev/null)
    if [ -z "$QuietCurl" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/Floodgate-Spigot.jar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/Floodgate-Spigot.jar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
    fi
    if [[ -n "$FloodgateSHA256" && "$FloodgateSHA256" != "null" ]]; then
        if ! echo "$FloodgateSHA256  /minecraft/plugins/Floodgate-Spigot.jar" | sha256sum -c --quiet; then
            echo "ERROR: SHA256 verification failed for Floodgate! Aborting."
            rm -f /minecraft/plugins/Floodgate-Spigot.jar
            exit 1
        fi
        echo "Floodgate SHA256 verified."
    else
        echo "WARNING: Could not fetch Floodgate SHA256 checksum, skipping verification."
    fi

    # Update Geyser
    echo "Updating Geyser..."
    GeyserBuildInfo=$(curl -s -L "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest")
    GeyserSHA256=$(echo "$GeyserBuildInfo" | jq -r '.downloads.spigot.sha256' 2>/dev/null)
    if [ -z "$QuietCurl" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/Geyser-Spigot.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/Geyser-Spigot.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
    fi
    if [[ -n "$GeyserSHA256" && "$GeyserSHA256" != "null" ]]; then
        if ! echo "$GeyserSHA256  /minecraft/plugins/Geyser-Spigot.jar" | sha256sum -c --quiet; then
            echo "ERROR: SHA256 verification failed for Geyser! Aborting."
            rm -f /minecraft/plugins/Geyser-Spigot.jar
            exit 1
        fi
        echo "Geyser SHA256 verified."
    else
        echo "WARNING: Could not fetch Geyser SHA256 checksum, skipping verification."
    fi

    if [ -z "$NoViaVersion" ]; then
        if [ -n "$ViaVersionSnapshot" ]; then
            # Update ViaVersion from Jenkins CI (snapshot/dev versions)
            echo "Updating ViaVersion from Jenkins CI (snapshot)..."
            ViaVersionVersion=$(curl -s -L "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/" | grep -oE 'href="ViaVersion[^"]+' | head -1 | sed 's/href="//')
            if [ -n "$ViaVersionVersion" ]; then
                echo "Found ViaVersion: $ViaVersionVersion"
                if [ -z "$QuietCurl" ]; then
                    curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion"
                else
                    curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion"
                fi
            else
                echo "Unable to check for updates to ViaVersion!"
            fi
        else
            # Update ViaVersion from GitHub Releases (stable versions) - default
            ViaVersionURL=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | jq -r '.assets[0].browser_download_url' 2>/dev/null)
            if [[ -n "$ViaVersionURL" && "$ViaVersionURL" != "null" ]]; then
                ViaVersionTag=$(curl -s "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest" | jq -r '.tag_name' 2>/dev/null)
                echo "Updating ViaVersion to $ViaVersionTag..."
                if [ -z "$QuietCurl" ]; then
                    curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "$ViaVersionURL"
                else
                    curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36" -o /minecraft/plugins/ViaVersion.jar "$ViaVersionURL"
                fi
            else
                echo "Unable to check for updates to ViaVersion!"
            fi
        fi
    else
        echo "ViaVersion is disabled -- skipping"
    fi
fi

# Accept EULA
echo eula=true > eula.txt

# Validate ports are numeric-only before injecting into config files via sed
if ! [[ "$Port" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Port must be a positive integer, got: $Port"
    exit 1
fi
if ! [[ "$BedrockPort" =~ ^[0-9]+$ ]]; then
    echo "ERROR: BedrockPort must be a positive integer, got: $BedrockPort"
    exit 1
fi

# Change ports in server.properties
sed -i "/server-port=/c\server-port=$Port" /minecraft/server.properties
sed -i "/query\.port=/c\query\.port=$Port" /minecraft/server.properties
# Change Bedrock port in Geyser config
if [ -e /minecraft/plugins/Geyser-Spigot/config.yml ]; then
    sed -i -z "s/  port: [0-9]*/  port: $BedrockPort/" /minecraft/plugins/Geyser-Spigot/config.yml
fi

# Start server
echo "Starting Minecraft server..."

if [[ -z "$MaxMemory" ]] || [[ "$MaxMemory" -le 0 ]]; then
    exec java -Xms400M -jar /minecraft/paperclip.jar
else
    exec java -Xms400M -Xmx"${MaxMemory}M" -jar /minecraft/paperclip.jar
fi

# Exit container
exit 0
