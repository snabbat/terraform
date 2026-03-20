FROM ghcr.io/coder/coder:latest

USER root

# Install curl and jq for the entrypoint script
RUN apk add --no-cache curl jq shadow su-exec

# Pre-create the data directory with correct ownership
RUN mkdir -p /home/coder/.config/coderv2 && \
    chown -R 1000:1000 /home/coder/.config/coderv2

# Copy workspace template into the image
COPY --chown=1000:1000 workspace-template /opt/workspace-template

# Copy and set up entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV CODER_DATA_DIR=/home/coder/.config/coderv2

EXPOSE 3000

# Run as root so entrypoint can fix docker socket permissions
USER root

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
