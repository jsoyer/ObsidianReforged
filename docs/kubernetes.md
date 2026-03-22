# Kubernetes Deployment

## Prerequisites

- Kubernetes cluster (tested with K3s and standard kubeadm clusters)
- A storage class that supports `ReadWriteOnce` — the manifests default to `longhorn-retain`
- `kubectl` configured against your cluster

## Apply all manifests

```bash
kubectl apply -f kubernetes/
```

This creates, in order:

| File | Resource | Description |
|------|----------|-------------|
| `01-namespace.yaml` | Namespace `minecraft` | Isolates all resources |
| `02-pvc.yaml` | PersistentVolumeClaim | 3 Gi data volume (world, plugins, backups) |
| `03-deployment.yaml` | Deployment | Server pod with liveness + readiness probes |
| `04-service.yaml` | Service (LoadBalancer) | Exposes Java TCP 25565 + Bedrock UDP 19132/19133 |
| `05-serviceaccount.yaml` | ServiceAccount | Named SA, no auto-mounted token |
| `06-configmap.yaml` | ConfigMap | Environment variables (port, version, TZ…) |
| `07-networkpolicy.yaml` | NetworkPolicy | Default-deny + explicit allow for player ports + outbound HTTPS |

## Storage class

The default storage class is `longhorn-retain`. To change it:

```bash
# Edit before applying
sed -i 's/longhorn-retain/YOUR_STORAGE_CLASS/' kubernetes/02-pvc.yaml
```

Or patch an existing PVC:

```bash
kubectl patch pvc minecraft-pvc -n minecraft \
  -p '{"spec":{"storageClassName":"YOUR_STORAGE_CLASS"}}'
```

## Adjusting resources

Edit `kubernetes/03-deployment.yaml`:

```yaml
resources:
  limits:
    cpu: 1500m
    memory: 2048M    # Keep in sync with MaxMemory env var
  requests:
    cpu: 750m
    memory: 750M
```

Also update the `MaxMemory` env var to stay below the memory limit.

## Configuration

Edit `kubernetes/06-configmap.yaml` to change environment variables (version, timezone, backup count, etc.) before applying.

See [configuration.md](configuration.md) for the full variable reference.

## Verify deployment

```bash
# Watch pod come up (takes ~2 minutes for server startup)
kubectl get pods -n minecraft -w

# Check readiness
kubectl describe deployment minecraft -n minecraft

# Tail logs
kubectl logs -n minecraft deployment/minecraft -f

# Check service (get external IP)
kubectl get svc -n minecraft
```

## Rollback

```bash
# Roll back to previous deployment revision
kubectl rollout undo deployment/minecraft -n minecraft

# Roll back to a specific image tag
kubectl set image deployment/minecraft \
  minecraft=jsoyer/obsidian-reforged:1.0.0 \
  -n minecraft
```

## World backup / restore

Backups are stored inside the PVC at `/minecraft/backups/*.tar.gz`. To extract one:

```bash
# Exec into the pod
kubectl exec -it -n minecraft deployment/minecraft -- bash

# List backups
ls /minecraft/backups/

# Extract a backup (stop the server first)
tar -xzf /minecraft/backups/2026.03.22.06.00.00.tar.gz -C /minecraft
```

## Notes

- The Deployment uses `strategy: Recreate` — only one pod runs at a time, required for the `ReadWriteOnce` PVC.
- Bedrock ports are UDP only — the Service and NetworkPolicy are configured accordingly.
- The NetworkPolicy allows outbound HTTPS so the server can download plugin updates on startup.
