# Operations

## Install

First create the namespace and select the credential source described in
configuration.md. Default TLS requires cert-manager and the internal-CA issuer.
Use a published custom image from GHCR. The source values pin a known build;
Jenkins stamps each packaged chart with the image produced by that pipeline.
Run Helm from the chart directory:

```sh
cd charts
helm upgrade -i redis . -n redis --wait --timeout 10m
```

For the development Sentinel configuration:

```sh
helm upgrade -i redis . -f overrides.yaml -n redis --wait --timeout 10m
```

Expected: standalone has one ready Redis pod. The development Sentinel mode has
two ready Redis pods and three ready Sentinel pods.

```sh
kubectl -n redis get pods,pvc
helm status redis -n redis
```

## Check authentication and data

The following commands read the mounted password inside the pod without printing it:

```sh
kubectl -n redis exec redis-node-0 -- sh -c \
  'REDISCLI_AUTH=$(cat /secrets/password) redis-cli --tls --cacert /tls/ca.crt PING'
```

Expected: `PONG`. If TLS is explicitly disabled, omit `--tls --cacert /tls/ca.crt`.
An unauthenticated command must return `NOAUTH`, not data.

In standalone mode, write a temporary key, replace the pod, wait for it to be
Ready, and read the key again. Remove the key when the check is complete.
Use a test release only; pod replacement interrupts service.

## Check Sentinel

```sh
kubectl -n redis exec redis-sentinel-0 -- sh -c \
  'REDISCLI_AUTH=$(cat /secrets/password) redis-cli --tls --cacert /tls/ca.crt -p 26379 SENTINEL get-master-addr-by-name mymaster'
kubectl -n redis exec redis-sentinel-0 -- sh -c \
  'REDISCLI_AUTH=$(cat /secrets/password) redis-cli --tls --cacert /tls/ca.crt -p 26379 SENTINEL CKQUORUM mymaster'
```

Expected: one data-pod DNS name and port 6379, and an `OK` quorum response.
Use `INFO replication` on each data pod to check the primary and replica roles.
The replica must report `master_link_status:up`.

During a manual failover check, subscribe to Sentinel's `+switch-master` event
before pausing the current primary. In a separate terminal:

```sh
kubectl -n redis exec redis-sentinel-0 -- sh -c \
  'export REDISCLI_AUTH=$(cat /secrets/password); redis-cli --tls --cacert /tls/ca.crt -p 26379 SUBSCRIBE +switch-master'
```

Wait for the subscription acknowledgement. Find the current primary using the
discovery command above, then run the following on that pod, replacing
`PRIMARY_POD` with its pod name:

```sh
kubectl -n redis exec PRIMARY_POD -- sh -c \
  'REDISCLI_AUTH=$(cat /secrets/password) redis-cli --tls --cacert /tls/ca.crt CLIENT PAUSE 60000 ALL'
```

This suspends command processing for at most 60 seconds. The liveness probe may
restart the container during the test. Do not use this on a production release.
Confirm that a new primary is selected,
that a known replicated test key survives, and that the returning old primary
becomes a replica. Do not assume pod zero remains primary after this test.
These are manual development checks, not an automated integration suite.

## Scale and upgrade

In Sentinel mode, increase `redis.replicas` from 1 to 2 and run the normal Helm
upgrade. The added pod must discover the current primary and synchronize.
Do not reduce replicas blindly: the highest ordinal can be the current primary.
Arrange and verify a failover to a retained ordinal before removing that pod.

An image update restarts pods through StatefulSet rolling updates. Monitor
Sentinel quorum and Redis replication during the rollout. Keep the same Secret
and master name for an established deployment.

Do not switch an established Sentinel deployment between plaintext and TLS
through an ordinary rolling upgrade. Mixed transports cannot communicate.
Use a separate test release to verify TLS, then plan a coordinated maintenance
change for an established deployment.

Changing from standalone to Sentinel is not a migration procedure for production
data. Test both modes on separate development releases first. A later migration
must cover data transfer, credentials, and application connection changes.

## Recovery and retained storage

If a pod restarts, allow it to reuse its own PVC. Do not copy one Sentinel's
configuration file onto another Sentinel: each stores a distinct identity.
After a full outage, restore Sentinel access and let data pods discover the
persisted primary. If quorum cannot agree, inspect the Sentinel logs and retained
state; do not force every data pod to become primary.

A lost single-replica volume has no Longhorn storage replica to recover from.
Restore from a verified backup, or use a surviving Redis replica as part of a
controlled recovery. This chart does not automate disaster recovery or backups.

Helm uninstall leaves StatefulSet PVCs. The configured storage class has a
Retain reclaim policy. Inspect and remove unused claims and retained volumes
deliberately after confirming their data is no longer needed.

The review naming change creates `data-redis-node-N` and `state-redis-sentinel-N`
claims for release `redis`. Old `data-redis-redis-N` and `data-redis-sentinel-N`
test claims are not adopted or deleted. This prevents stale Sentinel addresses
from being reused after the naming change. This is not a data migration.
