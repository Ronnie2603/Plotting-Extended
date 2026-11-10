
FROM debian:bookworm-slim

ARG SAVILEROW_VERSION=1.10.0

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

# Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    flex \
    git \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install Savile Row (includes Chuffed 0.12.1 and Kissat 3.1.1)
WORKDIR /opt

RUN curl -fsSL \
        "https://www-users.york.ac.uk/peter.nightingale/savilerow/savilerow-${SAVILEROW_VERSION}-linux.tgz" \
        -o /tmp/savilerow.tgz \
    && tar -xzf /tmp/savilerow.tgz -C /opt \
    && ln -s \
        "/opt/savilerow-${SAVILEROW_VERSION}-linux" \
        /opt/savilerow \
    && install -m 0755 \
        /opt/savilerow/bin/fzn-chuffed \
        /usr/local/bin/fzn-chuffed \
    && rm /tmp/savilerow.tgz

# Savile Row command
RUN printf '%s\n' \
    '#!/bin/sh' \
    'exec /opt/savilerow/savilerow "$@"' \
    > /usr/local/bin/savilerow \
    && chmod +x /usr/local/bin/savilerow

WORKDIR /workspace

CMD ["sleep", "infinity"]
