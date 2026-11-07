# Redis

A custom non-root Redis image and Helm chart. The image compiles upstream Redis
8.2.11 with TLS support. The chart has no dependencies.

## Modes

| Mode | Data pods | Sentinel pods | Failover |
| --- | --- | --- | --- |
| `standalone` (default) | One | None | Restart the same instance |
| `sentinel` | One primary plus `redis.replicas` | Three by default | Sentinel elects a new primary |

`redis.replicas` excludes the primary. The chart default is two replicas in
Sentinel mode. `overrides.yaml` selects Sentinel with one replica for development.
There is no primary-and-replica mode without Sentinel.

## Repository

- `src/`: multi-stage image, runtime defaults, and startup/probe scripts.
- `charts/`: Helm chart, schema, unit tests, and CI values.
- `tests/unit/`: deterministic tests of the custom shell logic, without a live cluster.
- `overrides.yaml`: development deployment settings.
- `project-pipeline-config.yaml`: image/chart publishing and direct Helm deployment.
- `docs/`: architecture, settings, and operating procedures.

## Development pipeline

The Jenkinsfile uses
`jenkins-shared-library@feature/DEVSECOPS-190-Build-custom-redis-chart-with-HA`
while shared-library PR #5 remains unmerged.

Jenkins validates the chart and combined overrides, builds and publishes the image
to Harbor, runs custom unit tests, packages the chart with the image digest, and
installs release `redis` in namespace `redis` on feature/PR builds.
Main builds publish artifacts but do not deploy. Argo deployment is disabled by
the library default. The same namespace/release is shared by development jobs;
do not start competing deployments.

The namespace and Secret `redis-auth` must exist before deployment. The Secret
must contain a non-empty, single-line `password` key. No credential is stored in
this repository or image. See [configuration](docs/configuration.md).

## Local checks

Run these commands from the repository root:

```sh
sh tests/unit/run.sh
shellcheck -x src/scripts/*.sh tests/unit/run.sh
helm unittest charts
helm lint --strict charts
helm lint --strict charts -f overrides.yaml
helm template redis charts -n redis -f overrides.yaml | kubeconform -strict -summary
docker build --platform linux/amd64 -t redis:dev -f src/Dockerfile src
```

The cluster uses amd64 nodes. Use a matching image architecture.
Helm unittest is a developer/CI tool, not a chart dependency.
There is no automated live integration suite. Deployment, persistence, and
failover are checked manually during development.

## Start and operate

- [Architecture and startup](docs/architecture.md)
- [Configuration and credentials](docs/configuration.md)
- [Installation, upgrades, and recovery](docs/operations.md)
