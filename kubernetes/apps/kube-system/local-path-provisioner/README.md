# Local-path provisioner

Flux manages the local-path provisioner for dynamic application config volumes
under `/containers/config/kubernetes`. The existing HDD tree is deliberately
separate and is represented by the retained static volume in
`kubernetes/apps/media/storage`.

The provisioner keeps the k3s-compatible `local-path` StorageClass and
`rancher.io/local-path` identity so existing claims retain their interface.
