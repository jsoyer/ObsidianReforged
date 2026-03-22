# Runbooks — ObsidianReforged

Operational playbooks for each Prometheus alert. Each runbook follows the same structure:
**Symptoms → Likely causes → Immediate triage → Fix → Verify → Post-incident**.

---

## SLO reference

| SLO | Target | Error budget (30 days) |
|-----|--------|------------------------|
| Server availability | 99.5% | 3 h 36 min |

---

## AvailabilityFastBurn

**Severity:** Critical
**Trigger:** Server unreachable > 7.2% of scrapes over the last hour — budget exhausts in < 12 h.

### Triage

```bash
# 1. Is the container running?
docker compose ps minecraft

# 2. Check the last 50 log lines
docker compose logs --tail=50 minecraft

# 3. Can you reach the Java port from the host?
echo > /dev/tcp/localhost/25565 && echo "up" || echo "down"

# 4. Check RCON (used by exporter)
docker compose logs --tail=20 minecraft-exporter
```

### Likely causes

| Symptom | Cause |
|---------|-------|
| Container `Exited` | JVM crash (OOM, uncaught exception), see logs |
| Container `Running` but TCP closed | Server still starting (120 s normal), plugin deadlock |
| RCON refused | `enable-rcon=false` in server.properties, or wrong password |

### Fix

```bash
# OOM kill — increase memory limit and/or MaxMemory env var
docker compose down && docker compose up -d

# Plugin crash — disable last-installed plugin
# Edit /minecraft/plugins — rename plugin .jar to .jar.disabled
# Then restart
docker compose restart minecraft

# Full restart
docker compose restart minecraft

# If data volume is corrupt — restore from backup
ls /minecraft/backups/
tar -xzf /minecraft/backups/<latest>.tar.gz -C /minecraft
```

### Verify

```bash
# Wait for startup (up to 2 min), then:
echo > /dev/tcp/localhost/25565 && echo "server accepting connections"
```

---

## AvailabilitySlowBurn

**Severity:** Warning
**Trigger:** Sustained 3%+ downtime rate over 6 h — budget exhausts in ~5 days.

### Triage

Look for intermittent restarts rather than a hard crash:

```bash
# Restart count since last deploy
docker inspect minecraft --format '{{.RestartCount}}'

# Container uptime
docker inspect minecraft --format '{{.State.StartedAt}}'

# Memory trend (is it growing?)
docker stats minecraft --no-stream
```

### Likely causes

- Memory leak → periodic OOM kills → `restart: unless-stopped` auto-recovers
- Disk full → backup tar fails → server write error → crash
- Plugin update loop → bad plugin downloaded on each restart

### Fix

```bash
# Check disk space
df -h /minecraft

# Check for memory growth — compare working set to limit in Grafana
# If trending up → lower view-distance in server.properties or reduce plugins

# Disable plugin auto-update temporarily
# Add NoViaVersion=Y or pin GeyserVersion / FloodgateVersion in .env
```

---

## MinecraftServerDown

**Severity:** Critical
**Trigger:** `up{job="minecraft"} == 0` for 2 minutes (RCON not responding).

This is the raw detection alert. `AvailabilityFastBurn` fires on rate; this fires on absolute absence.

```bash
docker compose ps minecraft
docker compose logs --tail=100 minecraft
docker compose restart minecraft   # if container is running but RCON is dead
docker compose up -d               # if container is stopped
```

---

## MinecraftNearCapacity

**Severity:** Warning
**Trigger:** > 90% of max-players slots occupied for 5 minutes.

### Options

1. **Raise max-players** (cheapest):
   ```
   # In server.properties
   max-players=30
   ```
   Then restart: `docker compose restart minecraft`

2. **Raise resources** if server already under CPU/memory pressure (check Grafana).

3. **Enable whitelist** if the server is invite-only and you're hitting public traffic:
   ```
   white-list=true
   enforce-whitelist=true
   ```

---

## MinecraftBackupStale

**Severity:** Warning
**Trigger:** Last backup timestamp older than 25 h.

```bash
# Check backup directory
ls -lhtr /minecraft/backups/ | tail -5

# Check available disk space
df -h /minecraft

# Trigger a manual backup (restart server — backup runs at startup)
docker compose restart minecraft

# Or create a manual tar
cd /minecraft && tar -I pigz -pcf backups/manual-$(date +%Y%m%d%H%M%S).tar.gz \
    --exclude='./backups' --exclude='./cache' --exclude='./logs' .
```

### If disk is full

```bash
# Remove oldest backups manually
ls -1t /minecraft/backups/*.tar.gz | tail -5 | xargs rm -v
```

---

## ContainerMemoryPressure

**Severity:** Warning
**Trigger:** Container working set > 90% of memory limit for 5 minutes.

JVM heap + off-heap (Netty, NIO) is approaching the cgroup limit. Next step is OOM kill.

```bash
# Current usage
docker stats minecraft --no-stream --format "{{.MemUsage}}"
```

### Fix (choose one or more)

1. **Raise MaxMemory env var** (keeps JVM heap below cgroup limit):
   ```yaml
   # docker-compose.prod.yml or .env
   MaxMemory: "2048"   # MB — keep ≥20% below container memory limit
   ```

2. **Raise container memory limit**:
   ```yaml
   # docker-compose.prod.yml
   deploy:
     resources:
       limits:
         memory: 4g
   ```

3. **Reduce server load**: lower `view-distance` and `simulation-distance` in `server.properties`.

4. **Add JVM GC flags** via `JAVA_OPTS` (Paper supports this via `JVM_OPTS` env):
   ```
   -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled
   ```

---

## ContainerCpuThrottling

**Severity:** Warning
**Trigger:** CPU throttle ratio > 25% for 10 minutes. Minecraft TPS may drop below 20.

```bash
# Current CPU usage
docker stats minecraft --no-stream --format "{{.CPUPerc}}"
```

### Fix (choose one or more)

1. **Raise CPU limit**:
   ```yaml
   # docker-compose.prod.yml
   deploy:
     resources:
       limits:
         cpus: '2.5'
   ```

2. **Reduce world complexity**: lower `view-distance`, disable `spawn-monsters` temporarily.

3. **Check for plugin tick loops**:
   ```
   # In Minecraft console:
   /timings report
   ```
   Review the timings URL to identify slow plugins.

4. **On K8s**: raise `resources.limits.cpu` in `kubernetes/03-deployment.yaml`.
