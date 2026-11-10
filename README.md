# Lightweight Debian Xpra HTML5 Container

A minimal, secure container based on **Debian 12 (Bookworm) Slim** that runs graphical Linux applications and exposes their user interface directly in any web browser via **Xpra HTML5 / WebSockets** (no client installation required).

---

## Features

- **Debian 12 (Bookworm) Slim Base**: Clean and minimal base image with XFCE4.
- **VoltDB Management CLI & Consoles**: Includes official `voltadmin` (cluster administration), `sqlcmd` (interactive SQL shell), and database loaders.
- **MinIO Client CLI (`mc` / `mcli`)**: Pre-installed official MinIO S3 object storage CLI.
- **OAuth2-Proxy Injected**: Built-in OIDC reverse proxy for single sign-on (SSO) with CyberArk Identity, Keycloak, or Okta.
- **Native HTML5 Client**: Access the application interface from any modern web browser via WebSockets.
- **Flexible Display Modes**:
  - `desktop` (default): Full XFCE4 desktop session with taskbar, start menu, workspace switcher, and settings.
  - `openbox`: Ultra-minimalist Openbox desktop session.
  - `seamless`: Application windows float independently directly on your browser tab.
- **Security-First**: Runs as a non-privileged `appuser` (UID 1000) with optional password authentication.
- **Customizable**: Run any GUI app (Python/Tkinter, Qt, GTK, terminal, or full desktops) by setting the `APP` variable or command arguments.
- **Includes Interactive Demo**: Pre-configured with an interactive Tkinter demo and `xterm`.

---

## Quick Start

### 1. Build the Container Image

```bash
# Using nerdctl (Rancher Desktop / containerd)
nerdctl build -t xpra-html5-debian .

# Or using Docker
docker build -t xpra-html5-debian .
```

### 2. Run the Container

#### Using nerdctl:
```bash
nerdctl run -d \
  -p 14500:14500 \
  --shm-size 256m \
  --name xpra-html5 \
  xpra-html5-debian
```

#### Using Docker:
```bash
docker run -d \
  -p 14500:14500 \
  --shm-size 256m \
  --name xpra-html5 \
  xpra-html5-debian
```

#### Or Using Docker Compose:
```bash
docker compose up -d
```

### 3. Open in Browser

Navigate to:
```text
http://localhost:14500
```
Click **Connect** (or it connects automatically) to interact with the GUI.

---

## Configuration & Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `APP` | `python3 /opt/demo/app.py` | Command/application to start on launch (e.g. `xterm`, `xcalc`, `python3 /app/main.py`). |
| `XPRA_MODE` | `desktop` | `desktop` (full XFCE4 desktop canvas), `openbox`, or `seamless` (floating app windows). |
| `XPRA_PORT` | `14500` | Port for the Xpra HTML5 web server inside the container. |
| `XPRA_PASSWORD` | *(empty)* | Optional password protection for web access. If empty, allows anonymous access. |
| `XPRA_RESOLUTION` | `1280x800` | Virtual display resolution (e.g., `1920x1080`, `1280x800`). |
| `EXIT_WITH_CHILDREN`| `no` | If set to `yes`, shutting down the primary app terminates the container. |

---

## Examples & Common Use Cases

### 1. Run in Full Desktop Mode (Openbox)
```bash
docker run -d -p 14500:14500 \
  -e XPRA_MODE=desktop \
  -e XPRA_RESOLUTION=1920x1080 \
  --name xpra-desktop \
  xpra-html5-debian
```

### 2. Run with Password Authentication
```bash
docker run -d -p 14500:14500 \
  -e XPRA_PASSWORD="SecretPassword123" \
  --name xpra-secure \
  xpra-html5-debian
```
When accessing `http://localhost:14500`, Xpra HTML5 will prompt for the password. You can also auto-fill it in the URL:
```text
http://localhost:14500/?password=SecretPassword123
```

### 3. Launching a Terminal (`xterm`) Directly
```bash
docker run -d -p 14500:14500 \
  -e APP="xterm" \
  --name xpra-terminal \
  xpra-html5-debian
```

### 4. Running Your Own Application via Volume Mount
You can mount your custom script or project directly into the container without rebuilding:

```bash
docker run -d -p 14500:14500 \
  -v $(pwd)/my_project:/home/appuser/project \
  -e APP="python3 /home/appuser/project/main.py" \
  --name xpra-my-app \
  xpra-html5-debian
```

### 5. Using VoltDB Management CLI and MinIO Client

Both tools are available directly inside the XFCE desktop (via desktop icons, applications menu, and `xfce4-terminal`) or through `nerdctl exec`:

- **VoltDB Cluster Management**:
  ```bash
  voltadmin status --servers=<voltdb-host>:21212
  voltadmin pause --servers=<voltdb-host>:21212
  voltadmin save /backups my_snapshot
  ```
- **VoltDB Interactive SQL**:
  ```bash
  sqlcmd --servers=<voltdb-host> --port=21212 --user=<username>
  ```
- **MinIO Client (`mc`)**:
  ```bash
  mc alias set myminio https://minio.company.com <ACCESS_KEY> <SECRET_KEY>
  mc ls myminio/
  mc cp file.tar.gz myminio/my-bucket/
  ```

### 6. Running with Injected OAuth2-Proxy (SSO / OIDC Authentication)

`oauth2-proxy` is baked directly into the container image. When enabled, it protects port 14500 and proxies authenticated WebSocket/HTTP traffic to the internal desktop session:

```bash
docker run -d -p 14500:14500 \
  -e ENABLE_OAUTH2_PROXY="true" \
  -e OAUTH2_PROXY_PROVIDER="oidc" \
  -e OAUTH2_PROXY_OIDC_ISSUER_URL="https://<tenant>.id.cyberark.cloud/oauth2/<app_id>" \
  -e OAUTH2_PROXY_CLIENT_ID="<client_id>" \
  -e OAUTH2_PROXY_CLIENT_SECRET="<client_secret>" \
  --name xpra-sso \
  xpra-html5-debian
```
Or run via Docker Compose using `docker-compose.oauth2.yml`:
```bash
nerdctl compose -f docker-compose.oauth2.yml up -d
```

### 7. Simulating CyberArk Identity with Dex IdP (Local Test Stack)

To simulate and test an enterprise CyberArk Identity SSO flow locally without requiring an active CyberArk cloud tenant:

```bash
nerdctl compose -f docker-compose.dex.yml up -d
```

- **Dex OIDC Provider**: `http://localhost:5556/dex` (pre-configured static client & users)
- **Protected Xpra Desktop**: `http://localhost:14500/`
- **SSO Flow**: Navigating to `http://localhost:14500/` automatically redirects you to Dex (simulating CyberArk Identity).
- **Test Credentials**:
  - `admin@company.com` / `password`
  - `developer@company.com` / `password`
- After logging in, you are immediately redirected into the authenticated XFCE desktop with VoltDB CLI and MinIO client!

### 8. Building a Custom Container on Top
You can use `xpra-html5-debian` as a base image for your own Dockerfile:

```dockerfile
FROM xpra-html5-debian:latest

USER root
# Install your application dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

USER appuser
COPY --chown=appuser:appuser . /home/appuser/app
ENV APP="python3 /home/appuser/app/main.py"
```

---

## CyberArk Integration

For enterprise environments requiring Privileged Access Management (PAM) or Corporate Single Sign-On (SSO):
- **CyberArk PAM / PSM Web Connection Component**: Automatic vault credential injection, headless browser session proxy, keystroke logging, and session video recording.
- **CyberArk Identity (SSO / OIDC)**: Securing the container behind an OIDC proxy (e.g. `oauth2-proxy`) with corporate MFA.
- **Dynamic Credential Rotation (CCP / Conjur)**: Rotating `XPRA_PASSWORD` on container startup.

See the complete setup guide in [docs/CYBERARK.md](file:///home/dsv/work/xpra/docs/CYBERARK.md).

---

## Stopping the Container

```bash
docker stop xpra-demo && docker rm xpra-demo
```
*(or `docker compose down`)*
