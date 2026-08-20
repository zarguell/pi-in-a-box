# Configuration Reference

All configuration is done through environment variables. Copy `.env.example` to `.env` and edit it.

## Dashboard

| Variable | Default | Secret | Description |
|----------|---------|--------|-------------|
| `PIAB_PORT` | `8000` | No | Port the dashboard listens on inside the container. |
| `PIAB_PI_HOME` | `/data/pi-home` | No | Pi home directory (sessions, config, goals). |
| `PIAB_WORKSPACE` | `/workspace` | No | Container working directory. |

**Restart required**: Changing `PIAB_PORT` requires `docker compose up -d`.

## Model Provider

Pass your provider API keys as environment variables. Pi reads these natively — no custom abstraction needed.

| Variable | Secret | Description |
|----------|--------|-------------|
| `OPENAI_API_KEY` | Yes | OpenAI API key. |
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key. |
| `GOOGLE_API_KEY` | Yes | Google Gemini API key. |
| `FIREWORKS_API_KEY` | Yes | Fireworks AI API key. |
| `OPENROUTER_API_KEY` | Yes | OpenRouter API key. |

**Restart required**: Changing provider keys requires `docker compose up -d`.

## Extension Enable/Disable

Core extensions are always installed. Optional extensions are controlled by these flags:

| Variable | Default | Description |
|----------|---------|-------------|
| `PIAB_BROWSER_ENABLED` | `false` | Enable Chromium + `pi-agent-browser-native`. |
| `PIAB_ENABLE_SAFETY_GUARDS` | `true` | Enable `safe-coder` project guardrails. |
| `PIAB_ENABLE_CREW` | `false` | Enable `pi-crew` worktree/task-graph orchestration. |
| `PIAB_ENABLE_RALPH` | `false` | Enable `pi-extensions` Ralph-style autonomous loops. |

**Restart required**: These are evaluated at build time. After changing, run:
```bash
docker compose up -d --build
```

## Extension Versions

Override pinned versions via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PIAB_VERSION_PI` | `0.84.2` | Pi coding agent version. |
| `PIAB_VERSION_DASHBOARD` | `0.7.0` | Dashboard version. |
| `PIAB_VERSION_SUBAGENTS` | `0.52.0` | pi-subagents version. |
| `PIAB_VERSION_GOAL` | `0.6.0` | @capyup/pi-goal version. |
| `PIAB_VERSION_BROWSER_NATIVE` | `0.3.0` | pi-agent-browser-native version. |
| `PIAB_VERSION_SKILLFUL` | `latest` | pi-skillful version. |
| `PIAB_VERSION_PROMPT_TEMPLATE_MODEL` | `latest` | pi-prompt-template-model version. |
| `PIAB_VERSION_BTW` | `latest` | @piex-dev/btw version. |

**Restart required**: Version overrides require `docker compose up -d --build`.

## Pi Reactor (Unattended Work)

| Variable | Default | Secret | Description |
|----------|---------|--------|-------------|
| `PIAB_REACTOR_CONCURRENCY` | `2` | No | Max parallel reactor jobs. |
| `PIAB_REACTOR_DAILY_TOKEN_CAP` | (unset) | No | Optional daily token spending limit. |
| `PIAB_REACTOR_RETENTION_DAYS` | `30` | No | How long to keep run history. |
| `PIAB_REACTOR_SHUTDOWN_GRACE` | `60s` | No | Time to drain jobs on SIGTERM. |
| `PIAB_WEBHOOK_PORT` | `8787` | No | Webhook listener port (profile: webhooks). |

**Restart required**: Reactor configuration changes require `docker compose up -d`.

## User/Group

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | UID for the container runtime user. |
| `PGID` | `1000` | GID for the container runtime user. |

**Restart required**: UID/GID changes require `docker compose up -d --build`.

## Included Extensions

### Core (always installed)

| Package | Purpose |
|---------|---------|
| `pi-subagents` | Subagent delegation, parallel audits, saved workflows |
| `@capyup/pi-goal` | Durable objectives with pause/resume/audit lifecycle |
| `pi-skillful` | Project-level skill discovery and invocation |
| `pi-prompt-template-model` | Slash-command model/skill workflows |
| `@piex-dev/btw` | Out-of-band questions without session pollution |
| `pi-reactor` | Cron/webhook triggers, durable queue, notifications |

### Optional

| Package | Trigger | Purpose |
|---------|---------|---------|
| `pi-agent-browser-native` | `PIAB_BROWSER_ENABLED=true` | Browser automation via agent-browser |
| `safe-coder` | `PIAB_ENABLE_SAFETY_GUARDS=true` | Project-specific safety guardrails |
| `pi-crew` | `PIAB_ENABLE_CREW=true` | Worktrees, task graphs, multi-agent teams |
| `pi-extensions` | `PIAB_ENABLE_RALPH=true` | Ralph-style autonomous loops, usage dashboard |
