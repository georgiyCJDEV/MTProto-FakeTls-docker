#!/bin/sh

set -e

# Configuration
DATA_DIR="/data"
PORT="${PORT:-443}"
STATS_PORT="${STATS_INTERNAL_PORT:-8888}"
WORKERS="${WORKERS:-1}"
FAKE_DOMAIN="${FAKE_DOMAIN:-}"
USE_FAKE_TLS="${USE_FAKE_TLS:-false}"
SERVER_NAME="${SERVER_NAME:-your-server-ip}"  # Set in server.env

# Download needed configs if they don't exist
if [ ! -f "$DATA_DIR/proxy-multi.conf" ]; then
    echo "Downloading proxy config..."
    curl -s https://core.telegram.org/getProxyConfig -o "$DATA_DIR/proxy-multi.conf"
fi

if [ ! -f "$DATA_DIR/proxy-secret" ]; then
    echo "Downloading proxy secret..."
    curl -s https://core.telegram.org/getProxySecret -o "$DATA_DIR/proxy-secret"
fi

# Generate secret
if [ ! -f "$DATA_DIR/secret" ]; then
    echo "Generating MTProxy secret..."
    SECRET=$(openssl rand -hex 16)
    echo "$SECRET" > "$DATA_DIR/secret"
fi

SECRET=$(cat "$DATA_DIR/secret")

if [ "$USE_FAKE_TLS" = "true" ] && [ -n "$FAKE_DOMAIN" ]; then
    # Encode tls domain to hex
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -p | tr -d '\n')
    # Generating secret for client with server's secret and hexed fake tls domain
    CLIENT_SECRET="ee${SECRET}${DOMAIN_HEX}"
else
    CLIENT_SECRET="$SECRET"
fi

# Generate tg:// connection link
if [ ! -f "$DATA_DIR/proxy_link" ]; then
    echo "Generating mtproxy link..."
    PROXY_LINK="tg://proxy?server=${SERVER_NAME}&port=${PORT}&secret=${CLIENT_SECRET}"
    echo "$PROXY_LINK" > "$DATA_DIR/proxy_link"
else
    PROXY_LINK=$(cat "$DATA_DIR/proxy_link")
fi

echo "-------------------------------------"
echo "Server: $SERVER_NAME"
echo "Port: $PORT"
echo "Server secret: $SECRET"
if [ "$USE_FAKE_TLS" = "true" ]; then
    echo "Fake TLS: ENABLED"
    echo "Fake domain: $FAKE_DOMAIN"
    echo "Client secret: $CLIENT_SECRET"
else
    echo "Fake TLS: DISABLED"
fi
echo "Telegram link: $PROXY_LINK"
echo "-------------------------------------"

echo "Starting MTProxy process..."

# Run MTProxy
if [ "$USE_FAKE_TLS" = "true" ] && [ -n "$FAKE_DOMAIN" ]; then
    exec /mtproxy/objs/bin/mtproto-proxy \
        -u nobody \
        -p "$STATS_PORT" \
        -H "$PORT" \
        -S "$SECRET" \
        -D "$FAKE_DOMAIN" \
        --aes-pwd "$DATA_DIR/proxy-secret" "$DATA_DIR/proxy-multi.conf" \
        --http-stats
else
    exec /mtproxy/objs/bin/mtproto-proxy \
        -u nobody \
        -p "$STATS_PORT" \
        -H "$PORT" \
        -S "$SECRET" \
        --aes-pwd "$DATA_DIR/proxy-secret" "$DATA_DIR/proxy-multi.conf" \
        --http-stats \
        -M "$WORKERS" 
fi