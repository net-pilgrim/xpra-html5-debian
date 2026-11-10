#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration parameters with sensible defaults
XPRA_PORT="${XPRA_PORT:-14500}"
XPRA_DISPLAY="${XPRA_DISPLAY:-:100}"
XPRA_PASSWORD="${XPRA_PASSWORD:-}"
XPRA_MODE="${XPRA_MODE:-desktop}" # "desktop" (XFCE4), "openbox", or "seamless" (app only)
XPRA_RESOLUTION="${XPRA_RESOLUTION:-1920x1080}"
XPRA_DYNAMIC_RESOLUTION="${XPRA_DYNAMIC_RESOLUTION:-yes}"
EXIT_WITH_CHILDREN="${EXIT_WITH_CHILDREN:-no}"

# Determine application to launch:
# 1. Any arguments passed to `docker run ...`
# 2. Or $APP environment variable
# 3. Or fallback to default demo app
if [ $# -gt 0 ]; then
    APP_CMD="$*"
elif [ -n "${APP:-}" ]; then
    APP_CMD="${APP}"
else
    APP_CMD="python3 /opt/demo/app.py"
fi

# Clean up stale locks if container was previously stopped abruptly
DISP_NUM="${XPRA_DISPLAY#:}"
rm -f "/tmp/.X${DISP_NUM}-lock" "/tmp/.X11-unix/X${DISP_NUM}" "/run/xpra/${XPRA_DISPLAY}" 2>/dev/null || true

# ------------------------------------------------------------------------------
# Logout / Disconnect Customization
# ------------------------------------------------------------------------------
XPRA_LOGOUT_URL="${XPRA_LOGOUT_URL:-}"
if [ -n "${XPRA_LOGOUT_URL}" ] && [ -w "/usr/share/xpra/www/index.html" ]; then
    sed -i "s|/oauth2/sign_out|${XPRA_LOGOUT_URL}|g" /usr/share/xpra/www/index.html /usr/share/xpra/www/connect.html 2>/dev/null || true
    rm -f /usr/share/xpra/www/index.html.br /usr/share/xpra/www/connect.html.br 2>/dev/null || true
    gzip -f -k /usr/share/xpra/www/index.html /usr/share/xpra/www/connect.html 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# OAuth2-Proxy / OIDC Reverse Proxy Configuration
# ------------------------------------------------------------------------------
ENABLE_OAUTH2_PROXY="${ENABLE_OAUTH2_PROXY:-no}"
OAUTH_CHILD_ARGS=()
XPRA_LISTEN_HOST="0.0.0.0"
XPRA_LISTEN_PORT="${XPRA_PORT}"

# Enable if explicitly requested, or if OIDC client credentials or config file exist
if [ "${ENABLE_OAUTH2_PROXY}" = "yes" ] || [ "${ENABLE_OAUTH2_PROXY}" = "true" ] || [ "${ENABLE_OAUTH2_PROXY}" = "1" ] || \
   [ -n "${OAUTH2_PROXY_CLIENT_ID:-}" ] || [ -f "/etc/oauth2-proxy.cfg" ]; then

    INTERNAL_PORT="${XPRA_INTERNAL_PORT:-14501}"
    XPRA_LISTEN_HOST="127.0.0.1"
    XPRA_LISTEN_PORT="${INTERNAL_PORT}"

    # Auto-detect configuration file if mounted
    if [ -f "/etc/oauth2-proxy.cfg" ] && [ -z "${OAUTH2_PROXY_CONFIG:-}" ]; then
        export OAUTH2_PROXY_CONFIG="/etc/oauth2-proxy.cfg"
    fi

    # Set default oauth2-proxy environment variables
    export OAUTH2_PROXY_HTTP_ADDRESS="${OAUTH2_PROXY_HTTP_ADDRESS:-0.0.0.0:${XPRA_PORT}}"
    export OAUTH2_PROXY_UPSTREAMS="${OAUTH2_PROXY_UPSTREAMS:-http://127.0.0.1:${INTERNAL_PORT}/}"
    export OAUTH2_PROXY_PROVIDER="${OAUTH2_PROXY_PROVIDER:-oidc}"
    export OAUTH2_PROXY_COOKIE_SECURE="${OAUTH2_PROXY_COOKIE_SECURE:-false}"
    export OAUTH2_PROXY_EMAIL_DOMAINS="${OAUTH2_PROXY_EMAIL_DOMAINS:-*}"
    export OAUTH2_PROXY_REVERSE_PROXY="${OAUTH2_PROXY_REVERSE_PROXY:-true}"
    export OAUTH2_PROXY_PROXY_WEBSOCKETS="${OAUTH2_PROXY_PROXY_WEBSOCKETS:-true}"

    # Generate a random 32-byte secret if not provided
    if [ -z "${OAUTH2_PROXY_COOKIE_SECRET:-}" ]; then
        export OAUTH2_PROXY_COOKIE_SECRET="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32)"
    fi

    echo "=========================================================="
    echo " OAuth2-Proxy Injected & Active"
    echo " Public Listening : ${OAUTH2_PROXY_HTTP_ADDRESS}"
    echo " Upstream Xpra    : ${OAUTH2_PROXY_UPSTREAMS}"
    echo " Provider         : ${OAUTH2_PROXY_PROVIDER}"
    echo " OIDC Issuer      : ${OAUTH2_PROXY_OIDC_ISSUER_URL:-(not set)}"
    echo " Client ID        : ${OAUTH2_PROXY_CLIENT_ID:-(not set)}"
    echo " WebSocket Proxy  : Enabled"
    echo "=========================================================="

    if [ -z "${OAUTH2_PROXY_CLIENT_ID:-}" ] && [ -z "${OAUTH2_PROXY_CONFIG:-}" ]; then
        echo "==> WARNING: OAuth2-Proxy is active but OAUTH2_PROXY_CLIENT_ID is not configured."
        echo "    To authenticate with CyberArk / OIDC, pass:"
        echo "      -e OAUTH2_PROXY_CLIENT_ID=<id>"
        echo "      -e OAUTH2_PROXY_CLIENT_SECRET=<secret>"
        echo "      -e OAUTH2_PROXY_OIDC_ISSUER_URL=<issuer-url>"
    fi

    OAUTH_CHILD_ARGS=( "--start=oauth2-proxy" )
fi

# Prepare authentication parameters for Xpra backend
AUTH_ARGS=()
if [ -n "${XPRA_PASSWORD}" ]; then
    PW_FILE="/tmp/.xpra-password"
    printf "%s" "${XPRA_PASSWORD}" > "${PW_FILE}"
    chmod 600 "${PW_FILE}"
    AUTH_ARGS=(
        "--bind-tcp=${XPRA_LISTEN_HOST}:${XPRA_LISTEN_PORT},auth=file(filename=${PW_FILE})"
        "--password-file=${PW_FILE}"
    )
    echo "==> Security: Password authentication enabled on Xpra (${XPRA_LISTEN_HOST}:${XPRA_LISTEN_PORT})."
else
    AUTH_ARGS=(
        "--bind-tcp=${XPRA_LISTEN_HOST}:${XPRA_LISTEN_PORT},auth=none"
        "--tcp-auth=none"
    )
    echo "==> Security: Anonymous access to Xpra backend (${XPRA_LISTEN_HOST}:${XPRA_LISTEN_PORT})."
fi

# Virtual display server:
# When dynamic resolution is enabled and Xorg xorg.conf is available, use Xorg with the dummy driver
# so that the virtual display dynamically adapts to the exact client browser viewport via RandR.
# Otherwise, fall back to Xvfb with the specified resolution.
if [ "${XPRA_DYNAMIC_RESOLUTION}" = "yes" ] && [ -f "/etc/xpra/xorg.conf" ] && command -v Xorg >/dev/null 2>&1; then
    XVFB_CMD="Xorg -noreset -novtswitch -config /etc/xpra/xorg.conf"
    RES_INFO="dynamic (browser viewport)"
else
    XVFB_CMD="Xvfb +extension GLX +extension Composite -screen 0 ${XPRA_RESOLUTION}x24+32 -nolisten tcp -noreset -s 0 -dpms"
    RES_INFO="${XPRA_RESOLUTION}"
fi

echo "=========================================================="
echo " Starting Xpra HTML5 Server (Debian Base)"
echo " Display     : ${XPRA_DISPLAY} (${RES_INFO})"
echo " Web Port    : ${XPRA_PORT}"
echo " Mode        : ${XPRA_MODE}"
echo " Application : ${APP_CMD}"
echo " Web URL     : http://localhost:${XPRA_PORT}/"
echo "=========================================================="

# Choose start flag based on lifecycle setting
if [ "${EXIT_WITH_CHILDREN}" = "yes" ]; then
    START_OPT="--start-child"
else
    START_OPT="--start"
fi

# Start according to selected mode
if [ "${XPRA_MODE}" = "desktop" ] || [ "${XPRA_MODE}" = "xfce" ]; then
    # Full XFCE4 desktop session with dbus-run-session
    echo "==> Launching XFCE4 desktop session..."
    exec xpra start-desktop "${XPRA_DISPLAY}" \
        --daemon=no \
        --html=on \
        "${AUTH_ARGS[@]}" \
        "${OAUTH_CHILD_ARGS[@]}" \
        --xvfb="${XVFB_CMD}" \
        --desktop-fullscreen=yes \
        --start="dbus-run-session xfce4-session" \
        --exit-with-children="${EXIT_WITH_CHILDREN}" \
        --notifications=no \
        --bell=no \
        --pulseaudio=no \
        --printing=no \
        --mdns=no \
        --webcam=no
elif [ "${XPRA_MODE}" = "openbox" ]; then
    # Minimal Openbox window manager session
    echo "==> Launching Openbox desktop session..."
    exec xpra start-desktop "${XPRA_DISPLAY}" \
        --daemon=no \
        --html=on \
        "${AUTH_ARGS[@]}" \
        "${OAUTH_CHILD_ARGS[@]}" \
        --xvfb="${XVFB_CMD}" \
        --desktop-fullscreen=yes \
        --start="openbox-session" \
        "${START_OPT}=${APP_CMD}" \
        --exit-with-children="${EXIT_WITH_CHILDREN}" \
        --notifications=no \
        --bell=no \
        --pulseaudio=no \
        --printing=no \
        --mdns=no \
        --webcam=no
else
    # Seamless / rootless application mode
    echo "==> Launching seamless application mode..."
    exec xpra start "${XPRA_DISPLAY}" \
        --daemon=no \
        --html=on \
        "${AUTH_ARGS[@]}" \
        "${OAUTH_CHILD_ARGS[@]}" \
        --xvfb="${XVFB_CMD}" \
        "${START_OPT}=${APP_CMD}" \
        --exit-with-children="${EXIT_WITH_CHILDREN}" \
        --notifications=no \
        --bell=no \
        --pulseaudio=no \
        --printing=no \
        --mdns=no \
        --webcam=no
fi
