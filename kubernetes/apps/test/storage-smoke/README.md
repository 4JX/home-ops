# Local-path storage smoke test

This disposable workload checks dynamic provisioning with the Flux-managed
`local-path` StorageClass. Its node-local PVC preserves an identifier across
pod replacement, but provides no redundancy and is deleted during claim
reprovisioning.
