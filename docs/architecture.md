# Architecture

## Image

`src/Dockerfile` compiles the verified Redis source archive. The builder contains
the compiler and development libraries; the runtime does not. Both stages use a
digest-pinned Debian bookworm base. Redis uses the system libc allocator to avoid
adding a bundled jemalloc build. TLS uses the distribution OpenSSL libraries.

The build uses `-O2` without link-time optimization to keep compiler memory use
bounded on the development workstation and Jenkins agents.
It builds the Redis core directly under `src/`, without the optional search,
JSON, time-series, or Bloom module toolchains.

The image runs as UID/GID 10001 from process start. It includes Redis server,
redis-cli, the upstream license, and `/usr/share/redis/packages.txt`, an inventory
of the installed OS packages. No root entrypoint or ownership repair is needed.
Kubernetes supplies writable `/data` and `/run/redis` mounts. The root filesystem
is read-only, all capabilities are dropped, and no Kubernetes API token is mounted.

The startup scripts and configuration defaults live only under `src/` and are
baked into the custom image. The chart passes environment settings and the
`redis` or `sentinel` argument to the image entrypoint. Credentials and TLS
certificates are mounted separately; runtime scripts are not supplied by Helm.

To update Redis, update the source version/checksum and chart `appVersion`
together. Verify the checksum against the upstream redis-hashes repository.
To update runtime libraries, rebuild from the reviewed base and distribution
packages. A bundled Redis dependency requires rebuilding Redis; updating an OS
package does not automatically replace code linked into the Redis binary.
The pinned base does not freeze the apt repository. Record the resulting image
digest and package inventory when reviewing an image update.

## Standalone

One StatefulSet pod owns one PVC. The `redis` Service routes directly to it
when the Helm release is named `redis`. Persistence uses AOF with a one-second
fsync interval. Redis loads its data back into memory after restart.

Disabling `redis.persistence.enabled` selects emptyDir and disables AOF.
This is a disposable cache configuration: pod replacement loses its data.

## Sentinel

The Redis StatefulSet contains one primary plus the requested replicas. There
is no permanent Kubernetes label that declares a pod to be primary. Each pod
advertises its stable DNS name, not its transient pod IP.

The separate Sentinel StatefulSet has one small PVC per pod. Sentinel's
identity, discovered topology, and election epochs survive pod replacement.
Startup preserves this state and refreshes chart settings and credentials.

On the first installation, all Sentinels monitor Redis ordinal zero. Both
StatefulSets use parallel pod startup and headless Services publish not-ready
addresses so bootstrap DNS works before readiness succeeds.

Redis pods ask all configured Sentinels for the primary. They start only after
a majority agrees on a valid data-pod address. The selected pod starts as primary;
the others start as replicas. Discovery retries are bounded; startup fails rather
than guessing that ordinal zero is primary when Sentinel is unavailable.

After failover, the old primary queries Sentinel on restart and rejoins the new
primary as a replica. After a full restart, persisted Sentinel state preserves
the selected primary. Do not delete Sentinel PVCs independently to reset an
established topology.

Sentinel and Redis pods of the same component are spread across different nodes.
Three Sentinels therefore require three schedulable nodes. PodDisruptionBudgets
protect quorum during voluntary evictions; they do not prevent node failures or
serialize StatefulSet updates.

Clients must use Sentinel discovery through the `redis-sentinel` Service,
with master name `<Helm release name>-master` by default. Release `redis` uses
`redis-master`; release `redis-harbor` uses `redis-harbor-master`.
The Redis headless Service includes replicas:
it is not a writable-primary endpoint.

## Storage and availability limits

Each PVC explicitly uses `longhorn-storage-class-replicas-1` by default. It has
one storage-level copy, independently of Redis application replication.
The class retains volumes after claims are removed. StatefulSet PVCs also remain
after Helm uninstall unless the operator removes them.

Redis replication is asynchronous. Sentinel provides automatic failover, not
zero-loss synchronous writes. AOF every-second fsync also has a small crash-loss
window. `noeviction` prevents memory-pressure key eviction, not data loss from
storage failure. Expiry and explicit key deletion still work.

For persistent HA use, keep persistence enabled on all data pods. Restarting an
empty primary in a non-persistent setup can propagate an empty dataset. Backups
are a separate operational responsibility; replicas are not backups.

## Network and credentials

One selected Secret supplies a shared password to Redis and Sentinel. The source
order is Infisical, an existing Secret, then a Helm-generated credential. Passwords
are read from mounted files, not passed as command-line arguments. Runtime config
files are written with a restrictive umask. Credential changes require a planned
restart; rotation is not performed automatically by this chart.

Ingress permits same-namespace release members, including parent application
pods, and explicitly configured client peers. Egress permits only this Redis
dependency's members and cluster DNS. Optional TCP ingress adds the configured
Traefik peers. No Kubernetes RBAC or public route is required for normal use.

TLS is enabled by default. cert-manager issues a leaf certificate from the
internal CA, or the operator can supply an existing TLS Secret. Plaintext ports are
disabled when TLS is enabled. Password authentication remains required. The
server does not require client certificates; internal clients use the mounted
certificate for replication and Sentinel communication.
