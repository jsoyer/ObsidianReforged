#!/bin/bash
# ObsidianReforged — Minecraft Paper Java Server + Geyser/Floodgate startup script
# Based on work by James A. Chambers — https://github.com/TheRemote/Legendary-Java-Minecraft-Geyser-Floodgate
set -Eeuo pipefail

# ─── Constants ───────────────────────────────────────────────────────────────
readonly UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4.212 Safari/537.36"

# ─── Privilege drop ──────────────────────────────────────────────────────────
if [ "$(id -u)" = '0' ]; then
    echo "Script is running as root, switching to 'minecraft' user..."
    if ! id minecraft >/dev/null 2>&1; then
        echo "Creating 'minecraft' user..."
        useradd -m -r -s /bin/bash minecraft
    fi
    chown -R minecraft:minecraft /minecraft
    exec gosu minecraft "$0" "$@"
fi

echo "ObsidianReforged — Minecraft Paper Java Server + Geyser/Floodgate"
echo "GitHub: https://github.com/jsoyer/ObsidianReforged"
echo "Default Java port: 25565 | Default Bedrock port: 19132"

# ─── Volume check ────────────────────────────────────────────────────────────
if [ ! -d '/minecraft' ]; then
    echo "ERROR: Named volume not found."
    echo "Create one with: docker volume create yourvolumename"
    echo "Then pass it:    docker run -it -v yourvolumename:/minecraft ..."
    exit 1
fi

# ─── Port validation ─────────────────────────────────────────────────────────
Port="${Port:-25565}"
BedrockPort="${BedrockPort:-19132}"

if ! [[ "$Port" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Port must be a positive integer, got: $Port"
    exit 1
fi
if ! [[ "$BedrockPort" =~ ^[0-9]+$ ]]; then
    echo "ERROR: BedrockPort must be a positive integer, got: $BedrockPort"
    exit 1
fi
echo "Port: $Port | Bedrock port: $BedrockPort"

# ─── BackupCount validation ──────────────────────────────────────────────────
BackupCount="${BackupCount:-10}"
if ! [[ "$BackupCount" =~ ^[0-9]+$ ]] || [ "$BackupCount" -lt 1 ]; then
    echo "WARNING: BackupCount is invalid ('$BackupCount'), defaulting to 10"
    BackupCount=10
fi

# ─── Curl helper — handles QuietCurl flag and shared headers ─────────────────
run_curl() {
    if [ -z "${QuietCurl:-}" ]; then
        curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "$UA" "$@"
    else
        curl --no-progress-meter -H "Accept-Encoding: identity" -H "Accept-Language: en" -L -A "$UA" "$@"
    fi
}

# ─── Safe download helper ────────────────────────────────────────────────────
# Usage: safe_download TARGET URL [SHA256]
# - Downloads to a temp file alongside TARGET, verifies checksum if provided.
# - On success: atomically replaces TARGET.
# - On failure (download error or checksum mismatch):
#     - If TARGET already exists: warns and keeps the existing version (returns 0).
#     - If TARGET does not exist: prints an error and returns 1
#       (with set -e the caller will abort unless it uses || or if).
safe_download() {
    local target="$1"
    local url="$2"
    local expected_sha256="${3:-}"
    local tmpfile
    tmpfile=$(mktemp "${target}.XXXXXX")

    if run_curl --fail -o "$tmpfile" "$url"; then
        if [[ -n "$expected_sha256" ]]; then
            if echo "$expected_sha256  $tmpfile" | sha256sum -c --quiet; then
                mv "$tmpfile" "$target"
                echo "SHA256 verified — $(basename "$target") updated."
                return 0
            else
                rm -f "$tmpfile"
                echo "ERROR: SHA256 mismatch for $(basename "$target")!"
                if [ -e "$target" ]; then
                    echo "Keeping existing version."
                    return 0
                fi
                return 1
            fi
        else
            mv "$tmpfile" "$target"
            echo "$(basename "$target") updated (no checksum available)."
            return 0
        fi
    else
        rm -f "$tmpfile"
        echo "WARNING: Download failed for $(basename "$target")."
        if [ -e "$target" ]; then
            echo "Keeping existing version."
            return 0
        fi
        return 1
    fi
}

# ─── Directory setup ─────────────────────────────────────────────────────────
cd /minecraft
mkdir -p /minecraft/downloads /minecraft/config /minecraft/backups /minecraft/plugins/Geyser-Spigot

# ─── Network check ───────────────────────────────────────────────────────────
NetworkChecks=0
DefaultRoute=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}') || DefaultRoute=""
while [ -z "$DefaultRoute" ]; do
    echo "Network interface not up, retrying in 1 second..."
    sleep 1
    DefaultRoute=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}') || DefaultRoute=""
    NetworkChecks=$((NetworkChecks + 1))
    if [ "$NetworkChecks" -gt 20 ]; then
        echo "Network wait timed out — starting without network connection."
        break
    fi
done

# ─── Permissions ─────────────────────────────────────────────────────────────
if [ -z "${NoPermCheck:-}" ]; then
    echo "Permissions set by startup block."
else
    echo "Skipping permissions check (NoPermCheck set)"
fi

# ─── Backup ──────────────────────────────────────────────────────────────────
if [ -d "world" ]; then
    extraExcludes=()
    if [ -n "${NoBackup:-}" ]; then
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
    if command -v pigz > /dev/null 2>&1; then
        echo "Backing up server (all cores) to minecraft/backups..."
        tar -I pigz --exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./paperclip.jar' \
            "${extraExcludes[@]}" -pcf "$BackupFile" . || echo "WARNING: Backup failed, continuing startup."
    else
        echo "Backing up server (single core) to minecraft/backups..."
        tar --exclude='./backups' --exclude='./cache' --exclude='./logs' --exclude='./paperclip.jar' \
            "${extraExcludes[@]}" -pczf "$BackupFile" . || echo "WARNING: Backup failed, continuing startup."
    fi
fi

# ─── Backup rotation ─────────────────────────────────────────────────────────
if [ -d /minecraft/backups ]; then
    (
        cd /minecraft/backups
        ls -1tr | head -n -"$BackupCount" | xargs -d '\n' rm -f -- || true
    )
fi

# ─── Config files (first run only) ───────────────────────────────────────────
[ -e "/minecraft/bukkit.yml" ]                        || cp /scripts/bukkit.yml /minecraft/bukkit.yml
[ -e "/minecraft/config/paper-global.yml" ]           || cp /scripts/paper-global.yml /minecraft/config/paper-global.yml
[ -e "/minecraft/spigot.yml" ]                        || cp /scripts/spigot.yml /minecraft/spigot.yml
[ -e "/minecraft/server.properties" ]                 || cp /scripts/server.properties /minecraft/server.properties
[ -e "/minecraft/plugins/Geyser-Spigot/config.yml" ] || cp /scripts/config.yml /minecraft/plugins/Geyser-Spigot/config.yml

# ─── Updates ─────────────────────────────────────────────────────────────────
echo "Checking for updates..."

if run_curl -s -o /dev/null "https://papermc.io"; then

    # Paper
    Build=$(run_curl -s "https://fill.papermc.io/v3/projects/paper/versions/$Version" \
        | jq -r '.builds[0]' 2>/dev/null) || Build=""
    if [[ -n "$Build" && "$Build" != "null" ]]; then
        echo "Latest Paper build: $Build"
        SHA256=$(run_curl -s "https://fill.papermc.io/v3/projects/paper/versions/$Version/builds/$Build" \
            | jq -r '.downloads["server:default"].checksums.sha256' 2>/dev/null) || SHA256=""
        FileName="paper-$Version-$Build.jar"
        if [[ -n "$SHA256" && "$SHA256" != "null" ]]; then
            echo "Downloading Paper $Version build $Build..."
            safe_download /minecraft/paperclip.jar \
                "https://fill-data.papermc.io/v1/objects/$SHA256/$FileName" \
                "$SHA256"
        else
            echo "Unable to retrieve Paper build info for $Build"
        fi
    else
        echo "Unable to retrieve latest Paper build"
    fi

    # Floodgate
    echo "Updating Floodgate..."
    FloodgateBuildInfo=$(run_curl -s \
        "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest") || FloodgateBuildInfo=""
    FloodgateSHA256=$(echo "$FloodgateBuildInfo" | jq -r '.downloads.spigot.sha256' 2>/dev/null) || FloodgateSHA256=""
    safe_download /minecraft/plugins/Floodgate-Spigot.jar \
        "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" \
        "${FloodgateSHA256:-}"

    # Geyser
    echo "Updating Geyser..."
    GeyserBuildInfo=$(run_curl -s \
        "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest") || GeyserBuildInfo=""
    GeyserSHA256=$(echo "$GeyserBuildInfo" | jq -r '.downloads.spigot.sha256' 2>/dev/null) || GeyserSHA256=""
    safe_download /minecraft/plugins/Geyser-Spigot.jar \
        "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" \
        "${GeyserSHA256:-}"

    # ViaVersion
    if [ -z "${NoViaVersion:-}" ]; then
        if [ -n "${ViaVersionSnapshot:-}" ]; then
            echo "Updating ViaVersion (snapshot from Jenkins CI)..."
            ViaVersionVersion=$(run_curl -s \
                "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/" \
                | grep -oE 'href="ViaVersion[^"]+' | head -1 | sed 's/href="//') || ViaVersionVersion=""
            if [ -n "$ViaVersionVersion" ]; then
                echo "Found ViaVersion snapshot: $ViaVersionVersion"
                safe_download /minecraft/plugins/ViaVersion.jar \
                    "https://ci.viaversion.com/job/ViaVersion/lastBuild/artifact/build/libs/$ViaVersionVersion" \
                    || true
            else
                echo "Unable to find ViaVersion snapshot."
            fi
        else
            echo "Updating ViaVersion (stable from GitHub Releases)..."
            ViaVersionRelease=$(run_curl -s \
                "https://api.github.com/repos/ViaVersion/ViaVersion/releases/latest") || ViaVersionRelease=""
            ViaVersionURL=$(echo "$ViaVersionRelease" | jq -r '.assets[0].browser_download_url' 2>/dev/null) \
                || ViaVersionURL=""
            ViaVersionTag=$(echo "$ViaVersionRelease" | jq -r '.tag_name' 2>/dev/null) \
                || ViaVersionTag=""
            if [[ -n "$ViaVersionURL" && "$ViaVersionURL" != "null" ]]; then
                echo "Updating ViaVersion to $ViaVersionTag..."
                safe_download /minecraft/plugins/ViaVersion.jar "$ViaVersionURL" \
                    || true
            else
                echo "Unable to find ViaVersion release."
            fi
        fi
    else
        echo "ViaVersion disabled — skipping."
    fi

else
    echo "Unable to reach update servers (internet may be down). Skipping updates."
fi

# ─── EULA ────────────────────────────────────────────────────────────────────
echo eula=true > eula.txt

# ─── Port injection ──────────────────────────────────────────────────────────
sed -i "/server-port=/c\server-port=$Port" /minecraft/server.properties
sed -i "/query\.port=/c\query\.port=$Port" /minecraft/server.properties
if [ -e /minecraft/plugins/Geyser-Spigot/config.yml ]; then
    sed -i -z "s/  port: [0-9]*/  port: $BedrockPort/" /minecraft/plugins/Geyser-Spigot/config.yml
fi

# ─── Start server ────────────────────────────────────────────────────────────
echo "Starting Minecraft server..."

if [[ -z "${MaxMemory:-}" ]] || ! [[ "${MaxMemory:-}" =~ ^[0-9]+$ ]] || [[ "${MaxMemory:-}" -le 0 ]]; then
    exec java -Xms400M -jar /minecraft/paperclip.jar
else
    exec java -Xms400M -Xmx"${MaxMemory}M" -jar /minecraft/paperclip.jar
fi
