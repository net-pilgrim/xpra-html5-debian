# ==============================================================================
# Ultra-lightweight Debian-based Container exposing GUI via Xpra HTML5
# Includes:
#   - XFCE4 Desktop & Xpra HTML5 Server
#   - VoltDB Management CLI (voltadmin, sqlcmd, voltdb)
#   - MinIO Client CLI (mc / mcli)
#   - OAuth2-Proxy (Injected OIDC/OAuth2 authentication proxy)
# Base: Debian 12 Bookworm Slim
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Reference official Volt Active Data distribution for CLI tools
# ------------------------------------------------------------------------------
FROM voltactivedata/volt-developer-edition:15.2.0_voltdb AS voltdb-source

# ------------------------------------------------------------------------------
# Stage 2: Main Debian Bookworm image
# ------------------------------------------------------------------------------
FROM debian:bookworm-slim

# Prevent interactive debconf prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Container user configuration (avoiding running X11/apps as root)
ARG USER=appuser
ARG UID=1000
ARG GID=1000

# 1. Install prerequisites and package management dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# 2. Add the official Xpra LTS repository for Debian Bookworm
RUN curl -fsSL https://xpra.org/xpra.asc -o /usr/share/keyrings/xpra.asc && \
    echo "Types: deb" > /etc/apt/sources.list.d/xpra-lts.sources && \
    echo "URIs: https://xpra.org/lts" >> /etc/apt/sources.list.d/xpra-lts.sources && \
    echo "Suites: bookworm" >> /etc/apt/sources.list.d/xpra-lts.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/xpra-lts.sources && \
    echo "Signed-By: /usr/share/keyrings/xpra.asc" >> /etc/apt/sources.list.d/xpra-lts.sources

# 3. Install Xpra server, HTML5 client, XFCE desktop, Java runtime (for VoltDB), and Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    xpra \
    xpra-x11 \
    xpra-server \
    xpra-html5 \
    xvfb \
    xserver-xorg-video-dummy \
    xauth \
    dbus-x11 \
    fonts-dejavu-core \
    xfce4 \
    xfce4-terminal \
    openbox \
    xterm \
    python3 \
    python3-tk \
    default-jre-headless \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/*

# 4. Install VoltDB Management CLI (voltadmin, sqlcmd, voltdb) from official distribution
COPY --from=voltdb-source /opt/voltdb /opt/voltdb
ENV VOLTDB_HOME=/opt/voltdb \
    PATH="/opt/voltdb/bin:${PATH}"

RUN echo 'export VOLTDB_HOME=/opt/voltdb' > /etc/profile.d/voltdb.sh && \
    echo 'export PATH="/opt/voltdb/bin:${PATH}"' >> /etc/profile.d/voltdb.sh && \
    chmod +x /etc/profile.d/voltdb.sh

# 5. Install MinIO Client (mc)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/minio/mc/releases/download/RELEASE.2025-08-13T08-35-41Z/mc.linux-${ARCH}.RELEASE.2025-08-13T08-35-41Z" -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc && \
    ln -sf /usr/local/bin/mc /usr/local/bin/mcli

# 6. Install oauth2-proxy (OIDC / OAuth2 authentication reverse proxy)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v7.15.6/oauth2-proxy-v7.15.6.linux-${ARCH}.tar.gz" | \
    tar -xz -C /usr/local/bin --strip-components=1 "oauth2-proxy-v7.15.6.linux-${ARCH}/oauth2-proxy" && \
    chmod +x /usr/local/bin/oauth2-proxy

# 7. Create dedicated non-root user and prepare required XDG/X11/ICE runtime directories
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} && \
    mkdir -p /run/user/${UID} /run/xpra /tmp/.X11-unix /tmp/.ICE-unix /home/${USER}/Desktop && \
    chown -R ${USER}:${USER} /run/user/${UID} /run/xpra /home/${USER} && \
    chmod 700 /run/user/${UID} && \
    chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix && \
    chmod 775 /run/xpra && \
    echo 'export VOLTDB_HOME=/opt/voltdb' >> /home/${USER}/.bashrc && \
    echo 'export PATH="/opt/voltdb/bin:${PATH}"' >> /home/${USER}/.bashrc

# 8. Install Desktop Shortcuts and customize HTML5 client for borderless desktop
COPY desktop/*.desktop /usr/share/applications/
COPY desktop/xpra-desktop.css /usr/share/xpra/www/css/desktop.css
RUN cat /usr/share/xpra/www/css/desktop.css >> /usr/share/xpra/www/css/client.css && \
    rm -f /usr/share/xpra/www/css/client.css.br /usr/share/xpra/www/css/client.css.gz && \
    gzip -k /usr/share/xpra/www/css/client.css && \
    cp /usr/share/applications/voltadmin.desktop /home/${USER}/Desktop/ && \
    cp /usr/share/applications/sqlcmd.desktop /home/${USER}/Desktop/ && \
    cp /usr/share/applications/minio-mc.desktop /home/${USER}/Desktop/ && \
    chmod +x /home/${USER}/Desktop/*.desktop && \
    chown -R ${USER}:${USER} /home/${USER}/Desktop

# 9. Copy demo app and container entrypoint script
COPY demo /opt/demo
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R ${USER}:${USER} /opt/demo

# Set runtime environment
ENV XDG_RUNTIME_DIR=/run/user/${UID} \
    USER=${USER} \
    HOME=/home/${USER}

# Switch to non-root user
USER ${USER}
WORKDIR /home/${USER}

# Expose default Xpra HTML5 web port (or oauth2-proxy port when enabled)
EXPOSE 14500

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
