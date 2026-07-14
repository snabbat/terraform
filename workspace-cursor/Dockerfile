FROM kasmweb/cursor:x86_64-1.19.0-rolling-weekly

USER root

# Install nginx: an internal proxy that terminates plain HTTP on :6902 and
# injects KasmVNC's Basic Auth, so the Coder app proxy can reach the desktop
# without dealing with the self-signed cert or the auth prompt.
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Port 6901 is never published to the host in a Coder workspace (Coder proxies
# to :6902 over the loopback inside the container), so this internal VNC
# password only guards a loopback socket. Real auth is handled by Coder.
ENV VNC_PW=coder-internal

# nginx runs rootless (as uid 1000) via custom_startup.sh; give it writable dirs.
COPY nginx-coder.conf /etc/nginx/nginx-coder.conf
RUN mkdir -p /var/lib/nginx /var/log/nginx && \
    chown -R 1000:1000 /var/lib/nginx /var/log/nginx /etc/nginx/nginx-coder.conf

# Override Kasm's custom startup hook: start nginx + the Coder agent, then
# launch Cursor exactly as the stock script does.
COPY custom_startup.sh /dockerstartup/custom_startup.sh
RUN chmod +x /dockerstartup/custom_startup.sh && \
    chown 1000:1000 /dockerstartup/custom_startup.sh

USER 1000
