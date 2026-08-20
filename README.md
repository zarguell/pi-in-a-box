# pi-in-a-box

Self-hosted, Docker-first [Pi](https://pi.dev) coding agent environment with a web dashboard, persistent sessions, subagents, goals, browser automation, and more — all in one container.

```
┌─────────────────────────────────────────────────────────┐
│                    Your Device                          │
│              (phone / laptop / desktop)                  │
│                                                         │
│   ┌──────────────────────┐                              │
│   │   Browser → :8000    │──── Tailscale / VPN ────┐    │
│   └──────────────────────┘                         │    │
└───────────────────────────────────────────────────┼────┘
                                                    │
┌───────────────────────────────────────────────────┼────┐
│                    Server                          │    │
│                                                   │    │
│   ┌────────────────────────────────────────────┐  │    │
│   │           Docker Container                 │  │    │
│   │                                            │  │    │
│   │  ┌──────────┐  ┌────────────────────────┐  │  │    │
│   │  │Dashboard │  │   Pi Agent             │  │  │    │
│   │  │  :8000   │──│  ├─ subagents          │  │  │    │
│   │  │          │  │  ├─ goals              │  │  │    │
│   │  └──────────┘  │  ├─ skillful           │  │  │    │
│   │                │  ├─ prompt-template     │  │  │    │
│   │                │  ├─ btw                 │  │  │    │
│   │                │  └─ browser (optional)  │  │  │    │
│   │                └────────────────────────┘  │  │    │
│   │                                            │  │    │
│   │  ┌──────────┐  ┌──────────┐  ┌─────────┐  │  │    │
│   │  │/workspace│  │/data/    │  │/data/   │  │  │    │
│   │  │ (bind)   │  │pi-home   │  │dashboard│  │  │    │
│   │  │          │  │ (vol)    │  │ (vol)   │  │  │    │
│   │  └──────────┘  └──────────┘  └─────────┘  │  │    │
│   └────────────────────────────────────────────┘  │    │
└───────────────────────────────────────────────────┼────┘
```

## Features

- **Web dashboard** — live and historical agent sessions from any browser.
- **Persistent sessions** — survive container restarts, image upgrades, browser disconnects.
- **Multiple projects** — mount any number of repos under `/workspace`.
- **Subagent delegation** — specialist agents (scout, reviewer, worker, oracle) via `pi-subagents`.
- **Durable goals** — pause/resume/audit lifecycle via `@capyup/pi-goal`.
- **Skill discovery** — project-level skills via `pi-skillful`.
- **Prompt workflows** — model/skill slash-commands via `pi-prompt-template-model`.
- **Out-of-band questions** — ask side questions without polluting context via `@piex-dev/btw`.
- **Browser automation** — optional Chromium + `pi-agent-browser-native`.
- **Safety guardrails** — optional `safe-coder` for risky repos.
- **Multi-arch** — `linux/amd64` and `linux/arm64` images on GHCR.

## Prerequisites

- Docker Engine 24+ with Compose plugin
- 2 GB RAM minimum (4 GB recommended for browser automation)
- Provider API key (OpenAI, Anthropic, Google, etc.)

## Quick start

```bash
# Clone
git clone https://github.com/zarguell/pi-in-a-box.git
cd pi-in-a-box

# Configure
cp .env.example .env
# Edit .env — add at least one provider API key

# Create workspace directory
mkdir -p workspace

# Start
docker compose up -d --build

# Open dashboard
open http://127.0.0.1:8000
```

## Included extensions

### Core (always installed)

| Extension | What it does |
|-----------|-------------|
| `pi-subagents` | Delegate to specialist child agents (scout, reviewer, worker, oracle) |
| `@capyup/pi-goal` | Durable objectives with pause/resume/audit lifecycle |
| `pi-skillful` | Project-level skill discovery and `/skill:name` invocation |
| `pi-prompt-template-model` | Slash-command workflows (`/review`, `/plan`, `/deep-debug`) |
| `@piex-dev/btw` | Out-of-band questions that retain session context |

### Optional (opt-in via environment)

| Extension | Trigger | What it does |
|-----------|---------|-------------|
| `pi-agent-browser-native` | `PIAB_BROWSER_ENABLED=true` | Browser automation via agent-browser |
| `safe-coder` | `PIAB_ENABLE_SAFETY_GUARDS=true` | Project-specific safety guardrails |
| `pi-crew` | `PIAB_ENABLE_CREW=true` | Worktrees, task graphs, multi-agent teams |
| `pi-extensions` | `PIAB_ENABLE_RALPH=true` | Ralph-style autonomous loops, usage dashboard |

## Adding projects

Place your project directories inside `workspace/`:

```bash
# Clone a repo into the workspace
git clone https://github.com/you/project workspace/project

# Or symlink an existing local project
ln -s /path/to/your/project workspace/project
```

The dashboard will show sessions grouped by folder. Create a new session within the desired project directory.

## Persistent data

| Mount | Container path | What it stores |
|-------|---------------|----------------|
| `pi-home` (named volume) | `/data/pi-home` | Pi config, sessions, goals, extensions |
| `dashboard-data` (named volume) | `/data/dashboard` | Dashboard state |
| `./workspace` (bind mount) | `/workspace` | Your project code |

All mutable data lives on volumes — it survives `docker compose down` and image upgrades.

## Dashboard

The dashboard listens on `0.0.0.0:8000` inside the container, bound to `127.0.0.1` on the host by default.

### LAN access

```bash
docker compose -f compose.yaml -f compose.lan.example.yaml up -d --build
```

**Warning**: This provides no authentication. Use on trusted networks only.

### Remote access (recommended)

- **Tailscale** — simplest zero-config solution
- **Cloudflare Access** — identity-aware proxy
- **Reverse proxy** — Caddy + OAuth, nginx + auth_request

See [docs/security.md](docs/security.md) for details.

## Configuration

All configuration is via environment variables. See [docs/configuration.md](docs/configuration.md) for the full reference.

### Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIAB_PORT` | `8000` | Dashboard port |
| `PIAB_BROWSER_ENABLED` | `false` | Enable browser automation |
| `PIAB_ENABLE_SAFETY_GUARDS` | `true` | Enable safe-coder |
| `PIAB_ENABLE_CREW` | `false` | Enable pi-crew orchestration |
| `PIAB_ENABLE_RALPH` | `false` | Enable Ralph-style loops |
| `PUID` / `PGID` | `1000` | Container user UID/GID |

## Diagnostics

```bash
# Run the diagnostic tool
docker compose exec pi-in-a-box pi-in-a-box-doctor

# View logs
docker compose logs -f pi-in-a-box

# Check extension list
docker compose exec pi-in-a-box pi install --list
```

## Updating

```bash
# Pull new image and recreate
docker compose pull
docker compose up -d

# Full rebuild (when changing .env or Dockerfile)
docker compose up -d --build
```

### Rollback

```bash
# Downgrade to a specific version tag
IMAGE=ghcr.io/zarguell/pi-in-a-box:0.1.0 docker compose up -d
```

## Running from GHCR

```bash
# Pull the latest edge image
docker pull ghcr.io/zarguell/pi-in-a-box:edge

# Run with minimal compose
docker run -d \
  --name pi-in-a-box \
  -p 127.0.0.1:8000:8000 \
  -v pi-home:/data/pi-home \
  -v ./workspace:/workspace \
  -e OPENAI_API_KEY=sk-... \
  ghcr.io/zarguell/pi-in-a-box:edge
```

## Image tags

| Git event | Tags published |
|-----------|---------------|
| Push to `main` | `edge`, `sha-<short>` |
| `v1.2.3` tag | `1.2.3`, `1.2`, `1`, `latest`, `sha-<short>` |
| Pull request | Build only, no push |

## Architectures

| Platform | Tag |
|----------|-----|
| Linux AMD64 | `linux/amd64` |
| Linux ARM64 | `linux/arm64` |

## Security

- Non-root container user (`piuser`).
- All Linux capabilities dropped; only `NET_RAW` added back.
- `no-new-privileges:true` security option.
- Dashboard bound to loopback by default.
- No Docker socket mounting.
- No secrets baked into the image.

**Pi can execute commands with the privileges granted to the container and mounted project paths.** Treat this as a privileged environment.

See [docs/security.md](docs/security.md) for the full threat model.

## Documentation

- [Security guide](docs/security.md) — threat model, access patterns, privilege boundaries
- [Configuration reference](docs/configuration.md) — every supported variable
- [Troubleshooting](docs/troubleshooting.md) — common issues and fixes

## License

[MIT](LICENSE)
