# Base image
FROM ubuntu:24.04

# Needed packages
RUN apt update && apt install -y \
    git curl build-essential libssl-dev zlib1g-dev \
    openssl xxd \
    && rm -rf /var/lib/apt/lists/*

# MTProxy sources
RUN git clone https://github.com/TelegramMessenger/MTProxy.git /mtproxy
WORKDIR /mtproxy

# Make sources
RUN make

# Directory for mtproxy configs and secret
RUN mkdir -p /data

# Start script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
