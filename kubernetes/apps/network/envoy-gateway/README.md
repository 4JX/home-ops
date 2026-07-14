# Envoy Gateway and Gateway API

Gateway API is a Kubernetes API for describing network entry points and routes.
It separates infrastructure concerns from application routing more clearly than
the older Ingress API.

Envoy Gateway is the controller implementation used here. It watches Gateway
API objects and creates an Envoy Proxy deployment and Service to implement them:

```text
Gateway API resources  →  Envoy Gateway controller  →  Envoy Proxy data plane
```

These are related but distinct parts. Gateway API defines the objects, Envoy
Gateway reconciles them, and Envoy Proxy handles the actual HTTP traffic.

## Current configuration

The `app/` directory installs Envoy Gateway `v1.8.2` from its OCI Helm chart.
The `gateway/` directory then creates:

- a cluster-scoped `GatewayClass` named `envoy`, selecting the Envoy Gateway
  controller;
- one `Gateway` named `envoy` in the `network` namespace;
- one HTTP listener on port 80;
- permission for routes in any namespace to attach to that listener.

Creating the Gateway causes Envoy Gateway to create an Envoy deployment and a
Service of type `LoadBalancer`. Cilium assigns the only available pool address,
`192.168.1.120`, and announces it on the LAN.

There is intentionally no hostname matching, HTTPS listener, certificate,
custom `EnvoyProxy`, public/private gateway split, or DNS integration in the
first test.

## Files and ordering

```text
envoy-gateway/
├── app/
│   ├── ocirepository.yaml
│   ├── helmrelease.yaml
│   └── kustomization.yaml
├── gateway/
│   ├── gatewayclass.yaml
│   ├── gateways.yaml
│   └── kustomization.yaml
└── ks.yaml
```

The first Flux Kustomization waits for Cilium's address configuration before
installing the controller. The second waits for the controller before applying
the GatewayClass and Gateway. Podinfo waits for that second Kustomization.

## What to inspect

```sh
kubectl -n network get pods
kubectl get gatewayclass envoy
kubectl -n network get gateway envoy -o wide
kubectl -n network describe gateway envoy
kubectl -n network get service
```

A healthy Gateway should show accepted and programmed conditions and report an
address. Envoy Gateway labels the generated deployment and Service with the
owning Gateway's name and namespace, which is useful when locating data-plane
resources.

## Documentation

- [Envoy Gateway documentation](https://gateway.envoyproxy.io/docs/)
- [Envoy Gateway HTTP routing](https://gateway.envoyproxy.io/v1.8/tasks/traffic/http-routing/)
- [Envoy Gateway Gateway API support](https://gateway.envoyproxy.io/docs/tasks/traffic/gatewayapi-support/)
- [Gateway API overview](https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/)
- [Gateway API concepts](https://gateway-api.sigs.k8s.io/guides/)
