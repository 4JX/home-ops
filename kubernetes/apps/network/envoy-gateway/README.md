# Envoy Gateway and Gateway API

Envoy Gateway implements the Gateway API entry point in the `network`
namespace. Cilium assigns its LoadBalancer service the LAN address
`192.168.1.120`; workloads attach HTTPRoutes to the shared `envoy` Gateway.

## Documentation

- [Envoy Gateway documentation](https://gateway.envoyproxy.io/docs/)
- [Envoy Gateway HTTP routing](https://gateway.envoyproxy.io/v1.8/tasks/traffic/http-routing/)
- [Envoy Gateway Gateway API support](https://gateway.envoyproxy.io/docs/tasks/traffic/gatewayapi-support/)
- [Gateway API overview](https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/)
- [Gateway API concepts](https://gateway-api.sigs.k8s.io/guides/)
