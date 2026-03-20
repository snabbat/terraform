#!/bin/bash
set -e

# Fix docker socket permissions so coder user (1000) can access it
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  if ! getent group "$DOCKER_GID" > /dev/null 2>&1; then
    groupadd -g "$DOCKER_GID" dockerhost
  fi
  usermod -aG "$DOCKER_GID" coder 2>/dev/null || true
  echo "Docker socket group: $DOCKER_GID — coder user added."
fi

echo "Starting Coder server as coder user..."
su-exec coder coder server &

echo "Waiting for Coder to be ready..."
until curl -sf http://localhost:3000/healthz > /dev/null 2>&1; do
  sleep 2
done
echo "Coder is ready!"

# Create first user via API if not exists
FIRST_USER_STATUS=$(curl -s http://localhost:3000/api/v2/users/first)
if echo "$FIRST_USER_STATUS" | grep -q "not been created"; then
  echo "Creating first admin user..."
  curl -s -X POST http://localhost:3000/api/v2/users/first \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"${CODER_FIRST_USER_EMAIL}\",
      \"username\": \"${CODER_FIRST_USER_USERNAME}\",
      \"password\": \"${CODER_FIRST_USER_PASSWORD}\",
      \"trial\": false
    }" | jq .
else
  echo "First user already exists."
fi

# Login and get session token
echo "Logging in as ${CODER_FIRST_USER_EMAIL}..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v2/users/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${CODER_FIRST_USER_EMAIL}\",\"password\":\"${CODER_FIRST_USER_PASSWORD}\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.session_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "Login failed: $LOGIN_RESPONSE"
  echo "Skipping template push."
else
  echo "Login successful. Pushing workspace template..."
  CODER_URL=http://localhost:3000 CODER_SESSION_TOKEN=$TOKEN \
    su-exec coder coder templates push code-server \
      --directory /opt/workspace-template \
      --yes && echo "Template pushed successfully!" || echo "Template push failed, continuing..."
fi

wait
