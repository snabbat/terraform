#!/usr/bin/env bash
# Kasm runs this script backgrounded and restarts it if it exits, so every
# step below is written to be idempotent.
set -x

# --- Internal nginx proxy: http://localhost:6902 -> https://127.0.0.1:6901 ---
if ! pgrep -x nginx >/dev/null 2>&1; then
    mkdir -p /tmp/nginx
    nginx -c /etc/nginx/nginx-coder.conf || echo "custom_startup: nginx failed to start"
fi

# --- Coder agent: connects the workspace to the Coder server ---
# CODER_AGENT_TOKEN and CODER_AGENT_INIT_B64 are injected as env by the template
# (init script is base64-encoded to survive newlines in a Docker env var).
if [ -n "$CODER_AGENT_TOKEN" ] && [ ! -f /tmp/coder-agent-init.sh ]; then
    printf '%s' "$CODER_AGENT_INIT_B64" | base64 -d > /tmp/coder-agent-init.sh
    bash /tmp/coder-agent-init.sh >/tmp/coder-agent.log 2>&1 &
fi

# --- Launch Cursor (stock Kasm logic, preserved) ---
START_COMMAND="cursor --no-sandbox"
export MAXIMIZE="true"
export MAXIMIZE_NAME="Cursor"
MAXIMIZE_SCRIPT=$STARTUPDIR/maximize_window.sh
ARGS=${APP_ARGS:-}

# Use VirtualGL if a GPU is available (matches stock behaviour).
if [ -f /opt/VirtualGL/bin/vglrun ] && [ ! -z "${KASM_EGL_CARD}" ] && [ ! -z "${KASM_RENDERD}" ] && [ -O "${KASM_RENDERD}" ] && [ -O "${KASM_EGL_CARD}" ]; then
    START_COMMAND="/opt/VirtualGL/bin/vglrun -d ${KASM_EGL_CARD} $START_COMMAND"
fi

if [ -z "$DISABLE_CUSTOM_STARTUP" ]; then
    /usr/bin/filter_ready
    /usr/bin/desktop_ready
    bash "${MAXIMIZE_SCRIPT}" &
    $START_COMMAND $ARGS
fi
