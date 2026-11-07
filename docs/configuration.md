# Configuration

## Required credential

Create namespace `redis` before installation. Create a Secret named `redis-auth`
there with key `password`, using your secret manager or a local protected file:

```sh
kubectl -n redis create secret generic redis-auth \
  --from-file=password=/absolute/path/to/password-file
```

The file must contain a non-empty single-line password. Do not commit it.
For a different release, the default name is `<release>-auth`. Set
`auth.existingSecret` and `auth.passwordKey` to use a different existing Secret.
The chart never creates or rotates the password.

## Main settings

| Value | Default | Purpose |
| --- | --- | --- |
| `mode` | `standalone` | `standalone` or `sentinel` only |
| `redis.replicas` | `2` | Replica count excluding the primary; Sentinel mode only |
| `redis.maxmemory` | `128mb` | Dataset memory threshold, below the pod memory limit |
| `redis.evictionPolicy` | `noeviction` | Reject allocating writes rather than evict keys |
| `redis.persistence.enabled` | `true` | PVC and AOF; false uses emptyDir |
| `redis.persistence.size` | `1Gi` | Storage requested for each Redis pod |
| `sentinel.replicas` | `3` | Independent Sentinel processes; supported counts 3, 5, 7 |
| `sentinel.quorum` | `2` | Failure-detection quorum; election also needs a majority |
| `sentinel.masterName` | `mymaster` | Name used by Sentinel-aware clients |
| `sentinel.persistence.size` | `128Mi` | Storage requested for each Sentinel pod |
| `*.persistence.storageClass` | `longhorn-storage-class-replicas-1` | Explicit single-storage-replica class |

Both components have separate `resources.requests` and `resources.limits`.
Redis needs memory above `maxmemory` for buffers and persistence operations.
A larger PVC does not increase the in-memory dataset capacity.

Sentinel PVCs are always enabled. A default Sentinel deployment has six PVCs:
three data pods and three Sentinels. The development override has five:
two data pods and three Sentinels.

## Development override

The root `overrides.yaml` selects:

```yaml
mode: sentinel
redis:
  replicas: 1
```

The Jenkins pipeline renders and lints the combined deployment override before
installing it. Chart CI fixtures additionally cover a disposable standalone
cache and a Sentinel deployment.

## Permit application clients

By default, only pods with the same release labels can connect. For clients in
one namespace, add a Kubernetes NetworkPolicy peer:

```yaml
networkPolicy:
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: application-namespace
```

Add a `podSelector` to that same peer to restrict it further.
This is a configuration example, not a migration of an existing application.

## TLS

Create an existing Secret containing `ca.crt`, `tls.crt`, and `tls.key`, then set:

```yaml
tls:
  enabled: true
  existingSecret: redis-tls
```

The certificate must cover the data and Sentinel pod DNS names used by the
release and its client Service names. Mount the trusted CA into application
clients. Redis continues to use port 6379 and Sentinel port 26379, but those
ports accept TLS only. Credential files are mounted read-only.

## Image

`image.repository` selects the registry/repository. `image.tag` accepts the
pipeline's `<version>@sha256:<digest>` value. Redis and Sentinel use the same
image. Set `imagePullSecrets` if the selected registry requires authentication.
The chart's source default tag is not a promise that an image has been published;
local deployments must select a built image, and Jenkins injects its pushed digest.
