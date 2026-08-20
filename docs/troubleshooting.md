# Troubleshooting

## Dashboard not accessible

**Symptoms**: `http://127.0.0.1:8000` returns connection refused.

**Checks**:
1. Container running? `docker compose ps`
2. Logs: `docker compose logs pi-in-a-box`
3. Health: `docker compose inspect pi-in-a-box --format='{{.State.Health.Status}}'`
4. Port conflict: `ss -tlnp | grep 8000`

**Fix**: Ensure no other service uses port 8000, or change `PIAB_PORT` in `.env`.

## Dashboard starts but shows blank page

**Symptoms**: HTTP 200 but empty or broken UI.

**Check**: Dashboard server may still be initializing. Wait 30 seconds and refresh. Check logs for startup errors.

## Provider authentication errors

**Symptoms**: Pi responds with "no API key configured" or similar.

**Fix**:
1. Verify your `.env` has the correct API key (e.g., `OPENAI_API_KEY=sk-...`).
2. Recreate the container: `docker compose up -d`
3. Keys are passed as environment variables — they must be set before `docker compose up`.

## Permission denied on workspace

**Symptoms**: Pi cannot read/write files in `/workspace`.

**Fix**:
```bash
# Check ownership
ls -la workspace/

# Fix ownership to match container user
sudo chown -R $(id -u):$(id -g) workspace/

# Or adjust PUID/PGID in .env to match your host user
echo "PUID=$(id -u)" >> .env
echo "PGID=$(id -g)" >> .env
docker compose up -d --build
```

## Session data lost after container recreation

**Symptoms**: Sessions disappear after `docker compose down && docker compose up -d`.

**This should not happen** if named volumes are intact. Check:
```bash
docker volume ls | grep pi-home
docker compose down   # Does NOT remove named volumes
docker compose up -d  # Volumes are reattached
```

To truly remove data: `docker compose down -v` (deletes volumes).

## Browser automation not working

**Symptoms**: Browser extension reports errors or agent-browser not found.

**Check**:
```bash
docker compose exec pi-in-a-box pi-in-a-box-doctor
```

**Fixes**:
1. Ensure `PIAB_BROWSER_ENABLED=true` in `.env`.
2. Rebuild: `docker compose up -d --build`
3. The container includes Chromium and all required libraries. The `agent-browser` binary must also be on PATH — verify with `docker compose exec pi-in-a-box which agent-browser`.

## Extensions not loading

**Symptoms**: Extensions installed but Pi doesn't use them.

**Check**:
```bash
docker compose exec pi-in-a-box pi install --list
```

**Fix**: Ensure extensions are installed at the correct `PIAB_PI_HOME`. Run:
```bash
docker compose exec pi-in-a-box bash /usr/local/bin/install-extensions.sh
```

## ARM compatibility

pi-in-a-box builds multi-architecture images (amd64, arm64). The Dockerfile uses `node:22-bookworm-slim` which supports both.

**Known issues**: Some npm packages have native bindings that may not build on ARM. If you hit build failures on ARM:
1. Check the extension's GitHub for ARM support.
2. Disable the problematic extension: set its `PIAB_ENABLE_*` to `false`.
3. Rebuild: `docker compose up -d --build`

## Viewing logs

```bash
# All logs
docker compose logs pi-in-a-box

# Last 100 lines
docker compose logs --tail 100 pi-in-a-box

# Follow live
docker compose logs -f pi-in-a-box
```

## Doctor output

```bash
docker compose exec pi-in-a-box pi-in-a-box-doctor
```

This validates: Pi, Node.js, dashboard, extensions, persistence directories, Git, and Python.

## Complete reset

```bash
# Stop and remove containers, networks, AND volumes
docker compose down -v

# Remove the built image
docker rmi pi-in-a-box-pi-in-a-box

# Start fresh
docker compose up -d --build
```

**Warning**: This deletes all session data, Pi configuration, and dashboard state.
