# Pi Reactor — Unattended Work

Pi Reactor turns Pi from a passive chat agent into an event-driven work engine. It handles cron schedules, GitHub webhooks, a durable job queue, and notification delivery — all without an interactive session.

## Architecture

```
pi-in-a-box (interactive)     pi-reactor (daemon)           pi-reactor-webhook
┌──────────────────────┐     ┌──────────────────────┐     ┌────────────────────┐
│ Dashboard :8000      │     │ Cron scheduler       │     │ GitHub webhooks    │
│ Live Pi sessions     │     │ Queue + gates        │     │ :8787 (opt-in)     │
│ Subagents, goals     │     │ Spawn Pi runs        │     │ Signature verify   │
│ Browser automation   │     │ Run history (30d)    │     │ Event filtering    │
│                      │     │ Telegram/Slack sinks │     │                    │
└──────────────────────┘     └──────────────────────┘     └────────────────────┘
         ▲                            │                            │
         │                            ▼                            │
         │                    pi-reactor resume                    │
         └────────────── open transcript interactively ────────────┘
```

## Quick start

The reactor daemon runs automatically with `docker compose up -d`. Configure it from inside a Pi session:

```text
every morning at nine, summarise yesterday's commits and send it to Telegram
```

Or use the CLI:

```bash
# Add an agent (working directory + model)
docker compose exec pi-reactor pi-reactor agent add report \
  --cwd /workspace/my-project \
  --model anthropic/claude-sonnet-5

# Add a notification sink
docker compose exec pi-reactor pi-reactor sink add tg --chat-id 123456

# Add a secret (via stdin, never argv)
docker compose exec pi-reactor sh -c 'printf "%s" "$TELEGRAM_BOT_TOKEN" | pi-reactor secret set tg botToken'

# Add a scheduled trigger (dry-run first)
docker compose exec pi-reactor pi-reactor trigger add nightly \
  --schedule "0 9 * * *" \
  --timezone "America/New_York" \
  --agent report \
  --task "Summarize yesterday's commits and relevant CI state." \
  --notify tg \
  --dry-run

# Apply when satisfied (drop --dry-run)
docker compose exec pi-reactor pi-reactor trigger add nightly \
  --schedule "0 9 * * *" \
  --timezone "America/New_York" \
  --agent report \
  --task "Summarize yesterday's commits and relevant CI state." \
  --notify tg
```

## Core concepts

| Concept | What it is |
|---------|-----------|
| **agent** | A working directory + model. The thing that does the work. |
| **sink** | Where notifications go: Telegram or Slack. |
| **trigger** | When to run, what to run, who to tell. |

Every trigger names an agent and a sink. Both must exist first.

## The run loop

```
event → queue → gates → spawn Pi → verdict → outbox → sink
```

- **Gates** run before spawning: credential present → working tree clean (opt-in) → daily budget not exhausted.
- **Every run starts fresh.** A new Pi session with the trigger's task text. Nothing carries over.
- **Persistent knowledge** lives in the workspace (`AGENTS.md`, project files), not in session transcripts.
- **Failures are classified.** Determinate answers ("I cannot do this") succeed. Infrastructure failures retry up to 3 times. Policy failures (timeout, budget) never retry.
- **Verdicts always reach you.** Notification committed in the same DB transaction as the run record.

## Cron triggers

```bash
pi-reactor trigger add nightly \
  --schedule "0 9 * * *" \
  --timezone "America/New_York" \
  --agent report \
  --task "Summarize yesterday's commits and CI state." \
  --notify tg
```

- Standard cron syntax, optionally with leading seconds field.
- `misfirePolicy`: `skip` (default) or `fireOnce`.
- Schedule breaker: 3 consecutive failures trips the breaker. Resume with `pi-reactor schedule resume <id>`.

## GitHub webhooks (opt-in)

### Enable the webhook profile

```bash
# In .env, the webhook port defaults to 8787
# Start with webhooks profile:
docker compose --profile webhooks up -d
```

### Configure GitHub

```bash
# Store the webhook secret via stdin
docker compose exec pi-reactor sh -c 'printf "%s" "$GITHUB_WEBHOOK_SECRET" | pi-reactor secret set github webhookSecret'

# Add a GitHub-triggered trigger
docker compose exec pi-reactor pi-reactor trigger add fix-on-label \
  --event github \
  --github-event issues \
  --github-action labeled \
  --github-label "pi:fix" \
  --agent coder \
  --task "Fix the issue described in the webhook payload. Use the fix skill." \
  --notify slack
```

### Expose the webhook

The webhook listener binds to `127.0.0.1:8787` by default. To receive GitHub webhooks:

1. **Tailscale Funnel** (simplest): `tailscale funnel --bg 8787 http://localhost:8787`
2. **Reverse proxy** (Caddy/nginx): point your domain to `pi-reactor-webhook:8787`
3. **Cloudflare Tunnel**: route your domain to `http://pi-reactor-webhook:8787`

Set the GitHub webhook URL to `https://your-domain/hooks/github`.

### Signature verification

Pi-reactor verifies GitHub HMAC signatures before parsing the payload. Invalid signatures are rejected with no job queued.

### Event filtering

Triggers constrain accepted events by type, action, label, and repository. Authentic but unmatched events create no run.

## Diagnostics

```bash
# Check reactor health
docker compose exec pi-reactor pi-reactor doctor

# View status
docker compose exec pi-reactor pi-reactor status

# List configured agents/triggers
docker compose exec pi-reactor pi-reactor agent ls
docker compose exec pi-reactor pi-reactor trigger ls

# View run history
docker compose exec pi-reactor pi-reactor runs

# List schedules (including tripped breakers)
docker compose exec pi-reactor pi-reactor schedule ls
```

## Resuming a completed job

Every run produces a Pi session. To resume it interactively:

```bash
docker compose exec pi-in-a-box pi-reactor resume <session-id>
```

The session ID appears in the notification message.

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIAB_REACTOR_CONCURRENCY` | `2` | Max parallel reactor jobs |
| `PIAB_REACTOR_DAILY_TOKEN_CAP` | (unset) | Optional daily token spending limit |
| `PIAB_REACTOR_RETENTION_DAYS` | `30` | How long to keep run history |
| `PIAB_REACTOR_SHUTDOWN_GRACE` | `60s` | Time to drain jobs on SIGTERM |
| `PIAB_WEBHOOK_PORT` | `8787` | Webhook listener port |

### Persistent data

| Mount | Container path | What it stores |
|-------|---------------|----------------|
| `pi-reactor` (named volume) | `/data/pi-reactor` | Reactor config, queue, run history, credentials, socket |

### Backup/restore

```bash
# Backup
docker compose exec pi-reactor tar czf /tmp/reactor-backup.tar.gz -C /data pi-reactor
docker cp pi-reactor:/tmp/reactor-backup.tar.gz ./reactor-backup.tar.gz

# Restore
docker cp ./reactor-backup.tar.gz pi-reactor:/tmp/
docker compose exec pi-reactor tar xzf /tmp/reactor-backup.tar.gz -C /data
docker compose restart pi-reactor
```

## Pi extension

The `/reactor` extension is installed inside Pi. From an interactive session, you can manage the daemon conversationally:

```text
add a daily report at 9am New York time for my-project, send to Telegram
```

The extension shows a before/after of the configuration change and waits for your approval. Configuration changes require explicit user confirmation.

## Safety boundaries

- The daemon does not bind a public port.
- Webhook listener is the only network-facing component.
- Signature verification occurs before payload parsing.
- Bot-loop prevention and author_association authorization are preserved.
- Secrets are stored in the reactor data volume, never in environment variables or logs.
- Agent runs only against declared mounted project directories.
