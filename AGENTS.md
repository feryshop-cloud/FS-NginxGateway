# FS-NginxGateway

## Architecture

- **This repo is a thin Nginx gateway template.** Its only job is TLS termination, request routing, rate-limiting, logging, and optional auth passthrough to internal services.
- **Internal services are not in this repo.** They live behind the gateway on an orchestrated internal network (Docker compose / Kubernetes / VPC). The agent should assume no downstream code exists here unless explicitly added.
- **The gateway is the single ingress point.** Every external route must pass through Nginx. No internal service is exposed directly.

## Key Files

| Path | Purpose |
|---|---|
| `nginx.conf` | Main Nginx config: upstreams, server blocks, security headers |
| `conf.d/*.conf` | Per-service route configs (generated from templates) |
| `Dockerfile` | Build the gateway image |
| `templates/default.conf.template` | Envsubst template for routes and upstreams |
| `docker-entrypoint.sh` | Renders template then starts Nginx |
| `mime.types` | MIME types served by Nginx |
| `html/` | Static error pages (`50x.html`, etc.) |
| `railway.json` | Railway deploy config: build and start commands |

## Commands

```bash
# Test Nginx config syntax
nginx -t

# Build image
docker build -t fs-nginx-gateway .
```

```powershell
# Test Nginx config syntax
nginx -t

# Build image
docker build -t fs-nginx-gateway .
```

## Conventions

- **Never hardcode upstream addresses.** Use Docker Compose service names or K8s DNS names. Add internal-network routing configs in the infra repo, not this gateway template.
- **HTTPS only.** HTTP is disabled in production. Self-signed or ACME-managed certs are mounted as volumes (`/etc/nginx/ssl/`).
- **One upstream = one service block.** Keep route logic in `conf.d/` snippets. Do not cram all routes into the main block.
- **Headers.** Proxy headers should preserve `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` exactly once. Duplicate headers break auth and rate-limit downstream.
- **Logging.** Access logs go to stdout (container-friendly). Error logs stay local. Do not log headers containing `Authorization` or cookies.
- **Rate limiting.** Use shared zones at the `http` level, not per-server. Document limits per route in a comment above the `limit_req_zone` block.

## Security Rules

- No `proxy_pass` to public internet from inside Nginx.
- Disable `server_tokens` in production.
- Block common paths in the catch-all server block (well-known, `.env`, `.git`) before routing.
- CORS must be configured explicitly per route or globally; never assume browser defaults.

## Editing Workflow

1. Edit `templates/default.conf.template` or `nginx.conf`.
2. Run `nginx -t` inside the container to verify: `docker run --rm -v "$(pwd)/templates:/templates" nginx:alpine envsubst '${PORT}' < /templates/default.conf.template > /tmp/default.conf && nginx -t -c /etc/nginx/nginx.conf`.
3. Rebuild image: `docker build -t fs-nginx-gateway .`
4. Deploy: push to Railway (auto-deploy via `railway.json`).
5. Never restart the whole container for config changes; use Railway deploy or container restart.

## Linux to PowerShell Cheatsheet

Agent should prefer PowerShell commands on Windows/WSL. If Linux commands are unavoidable, wrap with alias or use WSL.

| Linux | PowerShell | When to use |
|---|---|---|
| `ls` | `Get-ChildItem` | List files in repo or config directory |
| `ls -la` | `Get-ChildItem -Force` | Show hidden files like `.gitignore`, `.env` |
| `cd <dir>` | `Set-Location <dir>` | Navigate into `conf.d/`, `html/`, or project root |
| `pwd` | `Get-Location` | Confirm current working directory before edits |
| `cat <file>` | `Get-Content <file>` | Read `nginx.conf`, route snippets, or logs |
| `echo "text"` | `Write-Output "text"` | Quick debug/placeholder; not for file writes |
| `cp src dst` | `Copy-Item src dst` | Backup `nginx.conf` before risky edits |
| `mv src dst` | `Move-Item src dst` | Rename or relocate config snippets |
| `rm <file>` | `Remove-Item <file>` | Remove stale config files |
| `rm -r <dir>` | `Remove-Item <dir> -Recurse -Force` | Delete generated or temp directories |
| `mkdir <dir>` | `New-Item -ItemType Directory -Path <dir>` | Create `conf.d/`, `html/`, or cert mount dirs |
| `rmdir <dir>` | `Remove-Item <dir> -Recurse -Force` | Remove empty directories |
| `touch <file>` | `New-Item -Path <file> -ItemType File` | Create empty config placeholder files |
| `clear` | `Clear-Host` | Clean terminal before running `nginx -t` |
| `grep "pattern" <file>` | `Select-String "pattern" <file>` | Search for `upstream`, `server_name`, or `proxy_pass` in configs |
| `find <dir> -name "<pattern>"` | `Get-ChildItem <dir> -Recurse -Filter "<pattern>"` | Locate all `.conf` files or certs |
| `which <cmd>` | `Get-Command <cmd>` | Verify `nginx`, `docker`, or `openssl` is installed |
| `ps aux` | `Get-Process` | Check if Nginx or Docker is already running |
| `kill <pid>` | `Stop-Process -Id <pid>` | Stop stuck local Nginx process |
| `env` / `printenv` | `Get-ChildItem Env:` / `$env:NAME` | Inspect Railway or local env vars for template vars |
| `export NAME=value` | `$env:NAME = "value"` | Set upstream host or port for local testing |
| `curl <url>` | `Invoke-WebRequest <url>` or `curl.exe <url>` | Test gateway routes after deploy |
| `wget <url>` | `Invoke-WebRequest -Uri <url> -OutFile file` | Download sample cert or test payload |
| `ping <host>` | `Test-Connection <host>` | Verify upstream service reachability |
| `ssh user@host` | `ssh user@host` | Access Railway/VPS for manual cert or config fixes |
| `scp src user@host:dst` | `scp src user@host:dst` | Push certs or config to remote gateway host |
| `sudo <cmd>` | `Start-Process <cmd> -Verb RunAs` or run PowerShell as Administrator | Install Nginx, Docker, or OpenSSL on bare metal |
| `history` | `Get-History` | Recall commands used during debugging |
| `!!` | repeat last command | Quick re-run after editing config |
| `head -n 20 file` | `Get-Content file -TotalCount 20` | Inspect start of large log file |
| `tail -n 20 file` | `Get-Content file -Tail 20` | Watch recent access or error log entries |
| `wc -l file` | `(Get-Content file).Length` | Count lines in access log or config |
| `diff file1 file2` | `Compare-Object (Get-Content file1) (Get-Content file2)` | Compare current vs backup `nginx.conf` |
| `chmod +x <file>` | outside Git Bash, use WSL or Git Bash; Windows ACLs differ | Not needed for Nginx configs inside container |
| `tar -czf out.tar.gz folder/` | `Compress-Archive -Path folder/* -DestinationPath out.zip` | Archive old certs or logs before cleanup |
| `tar -xzf archive.tar.gz` | `Expand-Archive -Path archive.zip -DestinationPath .` | Extract imported cert bundle or backup |
| `unzip archive.zip` | `Expand-Archive -Path archive.zip -DestinationPath .` | Extract cert or config archive from backup |

## What This Repo Does NOT Contain

- Application code
- Client-side code
- Database schemas
- Service discovery logic (handled by infra/orchestrator)
- Build pipelines besides a single Dockerfile
