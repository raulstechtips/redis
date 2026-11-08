# Configuration

## Credential source order

Create namespace `redis` before installation. The chart selects exactly one source:

1. If `auth.infisical.enabled` is true, an `InfisicalStaticSecret` synchronizes
   the requested remote key into `<fullname>-credentials`.
2. Otherwise, if `auth.existingSecret` is set, mount it without managing it.
3. Otherwise, generate a 64-character random password in `<fullname>-credentials`.
   Connected Helm upgrades preserve it with `lookup`; uninstall retains the Secret.

To supply an existing Secret from a protected file:

```sh
kubectl -n redis create secret generic redis-auth \
  --from-file=password=/absolute/path/to/password-file
```

The file must contain a non-empty single-line password. Set
`auth.existingSecret: redis-auth`; change `auth.passwordKey` if needed.
Do not commit the file. Password rotation requires a planned restart.

For Infisical:

```yaml
auth:
  infisical:
    enabled: true
    authRef:
      name: YOUR_EXISTING_AUTH
      namespace: infisical-secrets-operator
    projectSlug: YOUR_PROJECT
    environmentSlug: dev
    secretPath: /redis
    secretKey: REDIS_PASSWORD
```

The operator creates the target Secret before the pods can mount it. Infisical
takes precedence even when `auth.existingSecret` is also set.
For Infisical's own bootstrap Redis, use a credential source that is available
before that Infisical instance starts; avoid a circular startup dependency.

**GitOps:** `lookup` cannot retrieve live Secrets during offline Helm rendering,
including normal Argo CD rendering. Select Infisical or an existing Secret for
those deployments; do not use generated credentials for offline GitOps rendering.

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
| `sentinel.masterName` | `""` (derive `<release>-master`) | Logical group name used by Sentinel-aware clients |
| `sentinel.persistence.size` | `128Mi` | Storage requested for each Sentinel pod |
| `*.persistence.storageClass` | `longhorn-storage-class-replicas-1` | Explicit single-storage-replica class |

Both components have separate `resources.requests` and `resources.limits`.
Redis needs memory above `maxmemory` for buffers and persistence operations.
A larger PVC does not increase the in-memory dataset capacity.

Sentinel PVCs are always enabled. A default Sentinel deployment has six PVCs:
three data pods and three Sentinels. The development override has five:
two data pods and three Sentinels.

The master name comes from the Helm release name, not a pod name. Release
`redis-harbor` uses `redis-harbor-master`; release `redis` uses `redis-master`.
An explicit `sentinel.masterName` overrides that default when needed.
Clients must use the same group name. During a group-name change, coordinate
client configuration with the rollout. Startup updates the group name in saved
Sentinel records while retaining the selected primary, peer identities and
election epochs; it does not reset the PVC state.

## Development override

`charts/overrides.yaml` selects:

```yaml
mode: sentinel
redis:
  replicas: 1
```

The Jenkins pipeline renders and lints the combined deployment override before
installing it. Chart CI fixtures additionally cover a disposable standalone
cache and a Sentinel deployment.

## Permit application clients

By default, pods in the same namespace with `app.kubernetes.io/instance` equal
to the Helm release can connect. This includes a parent chart's application
pods, not only Redis. For clients in
one namespace, add a Kubernetes NetworkPolicy peer:

```yaml
networkPolicy:
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: application-namespace
```

Add a `podSelector` to that same peer to restrict it further.
If the client pod also has an egress policy, that policy must permit Redis.
This is a configuration example, not a migration of an existing application.

## TLS

TLS is enabled by default. A cert-manager `Certificate` requests a leaf
certificate from `raulstechtips-internal-ca-issuer` (ClusterIssuer).
The resulting `<fullname>-tls` Secret contains the leaf certificate, its private
key, and the CA certificate. Redis never receives the CA's private key.
The Certificate covers client Service and data/Sentinel pod DNS names.

To use a separately managed certificate, supply a Secret containing `ca.crt`,
`tls.crt`, and `tls.key`:

```yaml
tls:
  enabled: true
  existingSecret: redis-tls
```

In this case the chart does not create a Certificate. The supplied certificate
must cover the data and Sentinel pod DNS names used by the
release and its client Service names. Mount the trusted CA into application
clients. Redis continues to use port 6379 and Sentinel port 26379, but those
ports accept TLS only. Credential files are mounted read-only.

Clients must trust the CA and enable TLS. Password authentication remains
required; client certificates are not required. `tls.enabled: false` enables
plaintext Redis and prevents Certificate creation, for consumers such as Harbor.

cert-manager renews the Secret. Redis loads TLS material at process startup;
plan a controlled rollout after renewal, before the old leaf certificate expires.
Automatic certificate reload is not provided by this chart.

## Dependency charts

Add `redis` to the parent chart's dependencies, then configure values under its
name or alias. A dependency alias is included in generated resource names.
For release `harbor` with dependency name `redis`, data pods are
`harbor-redis-node-N`; for standalone release `redis`, they are `redis-node-N`.
Set `fullnameOverride` only when a fixed prefix is needed.

Harbor-style parent values:

```yaml
redis:
  tls:
    enabled: false
  auth:
    existingSecret: harbor-redis-secret
    passwordKey: REDIS_PASSWORD
```

Infisical-style parent values:

```yaml
redis:
  auth:
    existingSecret: infisical-redis-secret
```

The second example inherits TLS enabled and internal-CA issuance. The application
must separately be configured for TLS and trust the CA; adding a dependency does
not change application connection settings. Disable any old bundled Redis when
performing a later migration. Neither application is migrated by this change.

## Optional TCP route

`ingressRoute.enabled` defaults to false. Enabling it creates an
`IngressRouteTCP`, not an HTTP route:

```yaml
ingressRoute:
  enabled: true
  host: redis.dev.raulstechtips.dev
```

The route uses HostSNI and TLS passthrough. Traefik forwards encrypted traffic
to Redis on port 6379; Redis terminates TLS. Clients must send the configured SNI
hostname and trust the internal CA. DNS must point to Traefik, and the configured
entryPoint must already exist. The issued certificate includes this hostname.
NetworkPolicy additionally permits only the configured Traefik namespace and
pod labels when the route is enabled.

This initial route supports standalone with TLS enabled. External Sentinel
access also requires routing every advertised data-node address; exposing only
Sentinel's discovery Service is not a complete external HA connection design.

## Image

`image.repository` is `ghcr.io/raulstechtips/redis`, our custom source-built image.
Redis and Sentinel use the same image, including its baked startup scripts and
configuration defaults. The chart uses the image's entrypoint.

The source values pin a published custom image. Jenkins replaces `image.tag`
with its matching `<version>@<digest>` before packaging and deployment. There
is no separate image-selection mode. For manual deployments, select a published
custom build through `image.tag`. Set `imagePullSecrets` if the registry requires
authentication.
