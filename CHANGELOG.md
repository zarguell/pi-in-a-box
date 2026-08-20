# Changelog

All notable changes to pi-in-a-box will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-20

### Added

- Initial release of pi-in-a-box.
- Dockerfile with multi-stage build (Node.js 22, Debian Bookworm).
- Pi coding agent v0.84.2 pre-installed.
- Web dashboard (`@blackbelt-technology/pi-agent-dashboard` v0.7.0) on port 8000.
- Extensions: `pi-subagents` v0.52.0, `@capyup/pi-goal` v0.6.0, `pi-agent-browser-native` v0.3.0.
- Chromium and browser dependencies for optional browser automation.
- Docker Compose with loopback-only default binding, named volumes, non-root user.
- LAN access example compose override.
- `pi-in-a-box-doctor` diagnostic script.
- Smoke test script for CI and local verification.
- GitHub Actions CI workflow (build, lint, compose validation, smoke test).
- GitHub Actions publish workflow (multi-arch amd64/arm64, GHCR, version tags).
- Dependabot configuration for GitHub Actions.
- Documentation: README, security guide, configuration reference, troubleshooting.
