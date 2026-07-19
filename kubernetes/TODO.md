# Kubernetes Cluster TODO

> [!WARNING]
> **Network Policies** — Both reference repos enforce cluster-wide default-deny
> egress with `CiliumClusterwideNetworkPolicy`. This becomes critical once
> multiple namespaces with different trust levels exist. Plan for this before
> adding untrusted or internet-facing workloads.

## Next Steps

### Secrets Management
Add a secrets operator before deploying any application that needs credentials.
Both reference repos use **external-secrets + 1Password Connect**. Alternatives
include SOPS+age or Sealed Secrets.

- [ ] Choose a secrets backend
- [ ] Deploy external-secrets operator
- [ ] Create a `ClusterSecretStore`

### TLS on the Gateway
The current Gateway listener is HTTP-only on port 80. Before exposing services
externally or testing TLS-dependent features:

- [ ] Deploy **cert-manager** with an ACME `ClusterIssuer`
- [ ] Add an HTTPS listener (port 443) with a `certificateRef`
- [ ] Add an HTTP→HTTPS redirect `HTTPRoute`
- [ ] Set `tls.minVersion: "1.2"` in a `ClientTrafficPolicy`

### Observability
Neither monitoring nor logging is deployed yet. A minimal starting point:

- [ ] Deploy **metrics-server** (enables `kubectl top` and HPA)
- [ ] Deploy **kube-prometheus-stack** (Prometheus + Alertmanager)
- [ ] Deploy **Grafana** (operator-based, with Cilium dashboards)
- [ ] Consider **Victoria Logs** or Loki for log aggregation

### Network Policies
See the warning at the top. When ready:

- [ ] Create a `CiliumClusterwideNetworkPolicy` for default-deny egress
- [ ] Create a DNS allowlist policy for `kube-dns`
- [ ] Add per-namespace or per-app policies as needed
