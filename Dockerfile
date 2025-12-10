# Docker environment for x86_64 Linux decompilation
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build tools
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    clang \
    binutils \
    gdb \
    jq \
    python3 \
    python3-pip \
    curl \
    wget \
    git \
    libsdl1.2-dev \
    libgtk2.0-dev \
    libglu1-mesa-dev \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install radare2 from GitHub releases
RUN wget -q https://github.com/radareorg/radare2/releases/download/5.9.6/radare2_5.9.6_amd64.deb \
    && dpkg -i radare2_5.9.6_amd64.deb || apt-get install -f -y \
    && rm radare2_5.9.6_amd64.deb

# Set up working directory
WORKDIR /project

# Default command
CMD ["/bin/bash"]
