# Static media storage

The HDD mounted at `/containers/mediaserver` already contains one live
filesystem tree:

```text
media/
scripts/
torrents/
```

It is represented by one statically provisioned `local` PersistentVolume named
`media`, rather than being offered to local-path-provisioner as a pool. The
provisioner therefore never creates, reorganizes, or removes directories on the
HDD. The PV and its bound PVC both use `Retain` semantics.

Applications that need hardlinks must live in the `media` namespace, reference
the existing `media` claim, and mount the whole claim at the same container
path. For app-template:

```yaml
persistence:
  media:
    existingClaim: media
    globalMounts:
      - path: /data
```

Applications then use `/data/media` and `/data/torrents`. Do not express those
directories as separate PVCs or volume mounts; hardlinks cannot cross volume
mount boundaries.

The `1Ti` PV capacity is Kubernetes binding metadata, not an HDD quota. Adjust
it to describe the disk if desired. Disk consumption must be monitored at the
host filesystem level.

Avoid pod-level ownership settings that recursively rewrite the entire tree.
Prepare a shared UID/GID or ACLs on the host and run media containers with
matching identities.

## Verify

```sh
findmnt -T /containers/mediaserver
kubectl get storageclass local-media
kubectl get persistentvolume media
kubectl -n media get persistentvolumeclaim media
kubectl get persistentvolume media -o jsonpath='{.spec.local.path}{"\\n"}'
```
