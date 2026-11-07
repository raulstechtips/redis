# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add a custom source-built Redis image with baked startup scripts, a non-root
  runtime, and GHCR publishing ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).
- Add a Helm chart for standalone and Sentinel deployments, including dependency-chart
  use, persistence, credential sources, internal-CA TLS, restricted pod security,
  NetworkPolicy, and optional TCP ingress ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).
- Add custom unit tests, Helm tests, operating documentation, and a Jenkins pipeline
  that builds, publishes, and deploys Redis ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).

[Unreleased]: https://github.com/raulstechtips/redis/commits/main
