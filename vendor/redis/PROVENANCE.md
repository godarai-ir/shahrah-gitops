# Vendored Redis chart

- Upstream: `oci://registry-1.docker.io/bitnamicharts/redis`
- Chart version: `23.1.1`
- Chart digest: `sha256:f4a368f7a67f4f2bedee2426bfb063b960565ee38a91fdf07185a014c9e63406`
- Vendored because production Argo CD could not reliably retrieve Docker Hub OCI chart blobs through the configured proxy/CDN path.

Runtime image digests are pinned in the two production Argo CD Applications rather than inherited from mutable chart defaults.
