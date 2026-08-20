# Security Guide

## Why direct public port exposure is unsafe

pi-in-a-box runs Pi, which has shell access, file system access, and (optionally) browser automation capabilities. Exposing the dashboard directly to the public internet means anyone who reaches port 8000 can:

- Execute arbitrary shell commands inside the container.
- Read and modify files in mounted project directories.
- Access API keys and credentials passed through environment variables.
- Control browser sessions and stored profiles.

**Do not expose the dashboard to the public internet without an authenticated access layer.**

## Recommended access patterns

| Method | Complexity | Authentication |
|--------|-----------|---------------|
| **Tailscale** (recommended) | Low | Built-in mTLS per device |
| **Cloudflare Access / Zero Trust** | Medium | Identity-aware proxy |
| **Authenticated reverse proxy** (Caddy + OAuth, nginx + auth_request) | Medium | Configurable |
| **SSH tunnel** | Low | SSH key |
| **VPN** (WireGuard, OpenVPN) | Medium | Certificate/key |

For LAN-only access, use `compose.lan.example.yaml` — but remember it still provides no authentication.

## Threat model

### What pi-in-a-box protects against

- **Host-level access**: The container runs as a non-root user with dropped capabilities. It cannot access the Docker daemon, host PID namespace, or host network stack (except the published port).
- **Credential leakage**: API keys are never baked into the image. They pass through environment variables and are redacted in logs.
- **Persistence isolation**: Session data, browser profiles, and goals live on named volumes, not in the image layer.

### What pi-in-a-box does NOT protect against

- **Prompt injection**: Pi executes user-supplied prompts. A malicious prompt can instruct Pi to run shell commands, exfiltrate data, or modify files.
- **Untrusted repositories**: If you mount a repository containing malicious instructions (`.pi/` directories, AGENTS.md files), Pi may follow those instructions. Only mount repositories you trust.
- **API key abuse**: If an attacker gains dashboard access, they can use your provider API keys. Use least-privilege keys where your provider supports it.
- **Browser profile theft**: If browser automation is enabled, browser cookies and session data are stored in the container. Compromising the container exposes those profiles.
- **Container escape**: While not a default configuration, running with `--privileged` or mounting Docker socket breaks all isolation. Never do this in production.

## Container privilege boundaries

The default Compose configuration:

- Runs as non-root (`piuser`).
- Drops all Linux capabilities (`cap_drop: ALL`).
- Adds back only `NET_RAW` for network diagnostics.
- Uses `no-new-privileges:true`.
- Binds to `127.0.0.1` only.
- Does NOT mount Docker socket.
- Does NOT use `--privileged` mode.
- Does NOT use host PID namespace.

## Browser automation security

When `PIAB_BROWSER_ENABLED=true`:

- Chromium runs inside the container with sandbox disabled (required for containerized operation).
- Browser profiles persist in `/data/browser` via a named volume.
- The container has elevated Chromium dependencies but no additional host capabilities.
- Treat browser sessions as privileged: they can access any site your authenticated browser profile has access to.

**Recommendation**: Use a dedicated browser profile for automated tasks, separate from personal browsing sessions.
