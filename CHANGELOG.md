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
- Core extensions: `pi-subagents` v0.52.0, `@capyup/pi-goal` v0.6.0, `pi-skillful`, `pi-prompt-template-model`, `@piex-dev/btw`.
- Pi Reactor v0.2.3 for unattended cron/webhook-triggered work with durable queue.
- Optional extensions: `pi-agent-browser-native` v0.3.0, `safe-coder`, `pi-crew`, `pi-extensions` (Ralph loops).
- Chromium and browser dependencies for optional browser automation.
- Docker Compose with loopback-only default binding, named volumes, non-root user.
- Pi Reactor daemon and webhook listener as separate Compose services.
- Webhook profile (`--profile webhooks`) for opt-in GitHub webhook support.
- LAN access example compose override.
- `pi-in-a-box-doctor` diagnostic script with reactor checks.
- Smoke test scripts for dashboard and reactor verification.
- GitHub Actions CI workflow (build, lint, compose validation, smoke test).
- GitHub Actions publish workflow (multi-arch amd64/arm64, GHCR, version tags).
- Dependabot configuration for GitHub Actions.
- Documentation: README, security guide (with webhook threat model), configuration reference, reactor guide, troubleshooting.
