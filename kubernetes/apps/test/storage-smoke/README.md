# Local-path storage smoke test

This disposable workload demonstrates how the Flux-managed
local-path-provisioner dynamically creates node-local persistent storage. The
app-template chart creates a `128Mi` ReadWriteOnce claim using the
`local-path` StorageClass and mounts it at `/data` in a small HTTP server.

On its first start the container writes a random identifier to `/data/id`. Each
later pod reads the same file, so the identifier distinguishes pod lifecycle
from volume lifecycle:

- replacing the pod changes the pod name but preserves the identifier;
- deleting and reprovisioning the claim produces a new identifier.

The requested `128Mi` is Kubernetes metadata, not a filesystem quota. The
local-path provisioner stores data in a directory on the selected node and does
not enforce the claim's capacity.

## Inspect dynamic provisioning

After Flux reports the Kustomization ready, inspect each layer:

```sh
flux -n test get kustomization storage-smoke
kubectl get storageclass local-path -o wide
kubectl -n test get deployment,pod,service,pvc -l app.kubernetes.io/name=storage-smoke
kubectl get pv
kubectl -n test describe pvc storage-smoke
```

The PVC should be `Bound` to a dynamically created PV. Inspect that PV to find
its node affinity and local backing path:

```sh
PV=$(kubectl -n test get pvc storage-smoke -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml
```

## Prove that data outlives a pod

Forward the Service in one terminal:

```sh
kubectl -n test port-forward service/storage-smoke 8080:8080
```

In another terminal, record both the persistent ID and current pod:

```sh
curl http://127.0.0.1:8080/
```

Delete the pod and wait for its replacement:

```sh
kubectl -n test delete pod -l app.kubernetes.io/name=storage-smoke
kubectl -n test rollout status deployment/storage-smoke
```

The first port-forward exits when its selected pod disappears. Start it again
and repeat the request:

```sh
kubectl -n test port-forward service/storage-smoke 8080:8080
```

```sh
curl http://127.0.0.1:8080/
```

The pod and `started-at` values should change while `persistent-id` remains the
same. This is persistence across pod replacement, not redundancy: if the node
or its underlying disk is lost, the data is lost too.

## Optional destructive reprovisioning test

This removes the Helm release, PVC, PV, and stored directory. The workload is
disposable, but verify the resource names before running it:

```sh
flux -n test suspend kustomization storage-smoke
kubectl -n test delete helmrelease storage-smoke
kubectl -n test wait --for=delete pvc/storage-smoke --timeout=2m
kubectl get pv
flux -n test resume kustomization storage-smoke
flux -n test reconcile kustomization storage-smoke --with-source
```

After the new claim binds, repeat the port-forward. Its `persistent-id` should
be different, demonstrating that a newly provisioned PV is new storage rather
than the previous directory being reattached.

## What this does not demonstrate

Local-path-provisioner is not a CSI driver, so this test does not provide
VolumeSnapshots, volume cloning, multi-node failover, or storage replication.
Those require a different storage backend. A later VolSync test can still back
up this PVC with a filesystem-level mover using its direct copy method.
