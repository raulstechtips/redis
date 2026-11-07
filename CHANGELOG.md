# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Compile upstream Redis in a non-root image with TLS support ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).
- Add standalone and Sentinel chart modes, persistent data and Sentinel state,
  authentication sources, internal-CA TLS, restricted pod security, NetworkPolicy,
  and optional TCP ingress ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).
- Add custom unit tests, Helm tests, and branch-based Jenkins deployment ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).

### Changed

- Publish the custom source-built image to GHCR and use it for all deployments.
- Name data pods `redis-node-N` and support dependency-chart naming and values.
- Resolve credentials in order: Infisical, existing Secret, generated password.
- Enable internal-CA TLS by default and move development overrides into `charts/`.

### Fixed

- Keep startup scripts and configuration defaults in the custom image rather
  than duplicating and mounting them from the chart ([DEVSECOPS-190](https://raulstechtips.atlassian.net/browse/DEVSECOPS-190)).

[Unreleased]: https://github.com/raulstechtips/redis/commits/main
