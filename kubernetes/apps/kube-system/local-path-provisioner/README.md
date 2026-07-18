# Local-path provisioner

Flux owns this installation instead of k3s' packaged `local-storage` AddOn so
its lifecycle and eventual replacement are visible in Git. It is a drop-in
replacement using the conventional interface:

- controller and Helm release: `local-path-provisioner`;
- ConfigMap: `local-path-config`;
- default StorageClass: `local-path`;
- provisioner identity: `rancher.io/local-path`.

It dynamically provisions application config volumes on the NVMe-backed path
`/containers/config/kubernetes`. Each claim receives its own generated child
directory. The `Delete` reclaim policy means deleting a claim also deletes its
allocated directory. Requested PVC capacity is metadata, not a filesystem
quota.

The HDD is deliberately outside this provisioner's path map. Its existing
media and torrent tree is exposed as the single static `media` PV under
`kubernetes/apps/media/storage`.

## Replace the k3s AddOn

Push the manifests, then rebuild the node with the updated NixOS configuration.
The k3s `local-storage` disable flag removes the packaged installation. Once the
node is back, tell Flux to apply the Git-managed replacement immediately:

```sh
flux -n flux-system reconcile kustomization flux-system --with-source
kubectl -n kube-system wait \
  --for=condition=Ready kustomization/local-path-provisioner --timeout=5m
kubectl -n kube-system wait \
  --for=condition=Ready helmrelease/local-path-provisioner --timeout=5m
```

There can be a short provisioning gap between removal and reconciliation, but
the external interface is unchanged. Existing PVCs still name `local-path`, so
they do not need an immutable StorageClass migration. Existing bound volumes
keep their current host paths; newly provisioned volumes use
`/containers/config/kubernetes`.

## Verify

```sh
flux -n kube-system get kustomization local-path-provisioner
flux -n kube-system get helmrelease local-path-provisioner
kubectl -n kube-system get deployment local-path-provisioner
kubectl -n kube-system get configmap local-path-config
kubectl get storageclass local-path -o yaml
kubectl -n kube-system logs deployment/local-path-provisioner
```

To prove a new claim uses the configured NVMe path, destructively recreate the
disposable smoke-test claim after the replacement is ready:

```sh
flux -n test suspend kustomization storage-smoke
kubectl -n test delete helmrelease storage-smoke
kubectl -n test wait --for=delete pvc/storage-smoke --timeout=2m
flux -n test resume kustomization storage-smoke
flux -n test reconcile kustomization storage-smoke --with-source
kubectl -n test wait \
  --for=jsonpath='{.status.phase}'=Bound pvc/storage-smoke --timeout=2m
PV=$(kubectl -n test get pvc storage-smoke -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o jsonpath='{.spec.local.path}{"\n"}'
```

The reported path should be a generated child of
`/containers/config/kubernetes`.
