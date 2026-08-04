# Railway Nginx Gateway

Thin Nginx gateway template for Railway. Acts as the single public ingress point for multiple services running on Railway Private Networking.

## How it works

1. Railway sets `PORT` and injects your private service hostnames.
2. Container starts `docker-entrypoint.sh`.
3. `envsubst` renders `templates/default.conf.template` into `/etc/nginx/conf.d/default.conf`.
4. Nginx starts and proxies traffic based on path.

## Architecture

```
Internet
  ↓
Nginx Gateway
  ├── → /          → Web Application (Next.js)
  ├── → /admin     → Admin Application (Next.js)
  └── → /api       → Backend API
```

## Repository structure

- `Dockerfile` — Builds the Nginx image
- `nginx.conf` — Main Nginx config: shared zones, gzip, logging, includes
- `templates/default.conf.template` — Server block with env var placeholders
- `docker-entrypoint.sh` — Renders template and starts Nginx
- `railway.json` — Railway build/deploy config
- `html/50x.html` — Static error page
- `AGENTS.md` — Instructions for Kilo sessions

## Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `PORT` | no | `8080` | Railway sets this automatically; must match the `listen` directive |
| `WEB_HOST` | no | `fs-webtopup` | Private DNS of web service (short name auto-expanded to `*.railway.internal`) |
| `WEB_PORT` | no | `8080` | Web service port |
| `ADMIN_HOST` | no | `fs-webdashboard` | Private DNS of admin service (short name auto-expanded) |
| `ADMIN_PORT` | no | `8080` | Admin service port |
| `API_HOST` | no | `fs-webtopup` | Private DNS of API service (short name auto-expanded) |
| `API_PORT` | no | `8080` | API service port |
| `NGINX_RESOLVER` | no | auto (`/etc/resolv.conf`, fallback `127.0.0.11`) | DNS resolver used by Nginx for dynamic upstreams |

> All defaults above are the values hardcoded in `docker-entrypoint.sh`.

## Deploy to Railway

1. Push this repo to GitHub.
2. In Railway, create a new project from the repo.
3. In the service Variables tab, set:
   - `WEB_HOST` = private DNS of your web service
   - `ADMIN_HOST` = private DNS of your admin service
   - `API_HOST` = private DNS of your API service
4. Railway auto-deploys on push. Health check is at `/health`.

### Production reference (`honest-adventure`)

The live production service `FS-NginxGateway` sets these values explicitly:

| Variable | Value (production) |
|---|---|
| `WEB_HOST` | `fs-webtopup` → `fs-webtopup.railway.internal` |
| `WEB_PORT` | `8080` |
| `ADMIN_HOST` | `fs-webdashboard` → `fs-webdashboard.railway.internal` |
| `ADMIN_PORT` | `8080` |
| `API_HOST` | `fs-webtopup` → `fs-webtopup.railway.internal` |
| `API_PORT` | `8080` |

Short names are normalized to `*.railway.internal` by `docker-entrypoint.sh`.

### Connect services

Use Railway Private Networking. In Railway, you can reference another service by its name (e.g. `web`, `admin`, `api`) as the hostname, or use the full private DNS.

## Add another service

1. Add a new environment variable (e.g. `SVC_HOST`, `SVC_PORT`).
2. Add a new `location` block in `templates/default.conf.template`:
   ```nginx
   location /new-service {
       proxy_pass http://${SVC_HOST}:${SVC_PORT};
       proxy_http_version 1.1;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```
3. Rebuild and redeploy.

## Local test

```bash
docker build -t fs-nginx-gateway .
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e WEB_HOST=host.docker.internal \
  -e WEB_PORT=8080 \
  -e ADMIN_HOST=host.docker.internal \
  -e ADMIN_PORT=8080 \
  -e API_HOST=host.docker.internal \
  -e API_PORT=8080 \
  fs-nginx-gateway
```

Then verify:
```bash
curl http://localhost:8080/health
```

## Key config notes

- `PORT` must match the listen directive (Railway sets this).
- On Railway, internal upstreams should use `http` plus the private DNS name under `railway.internal`.
- For this project, the intended upstreams are `fs-webtopup.railway.internal:8080` for `/` and `/api`, and `fs-webdashboard.railway.internal:8080` for `/admin`.
- `FS-WebDashboard` must be built with `NEXT_PUBLIC_BASE_PATH=/admin`, so Nginx preserves the `/admin` prefix when proxying.
- Short upstream names such as `fs-webtopup` are expanded to `fs-webtopup.railway.internal` by `docker-entrypoint.sh`.
- `proxy_http_version 1.1` is required for websockets and keepalive.
- `proxy_set_header Connection ""` removes the Connection header so Nginx manages keepalive.
- `limit_req zone=api burst=20 nodelay` rate-limits `/api` only.
- `server_tokens off` hides Nginx version.
- `client_max_body_size 20M` caps uploads.
- `access_log /dev/stdout` integrates with Railway logs.

## Troubleshooting

- **502 Bad Gateway**: upstream host/port wrong, or service crashed. Check Railway logs.
- **404 on /health**: ensure template rendered successfully; check container logs.
- **Websocket drops**: ensure `proxy_http_version 1.1` and `proxy_set_header Connection ""` are present.
- **Config syntax error**: check Railway deploy logs for `nginx -t` output.
