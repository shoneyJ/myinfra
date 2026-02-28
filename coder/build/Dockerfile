FROM codercom/enterprise-base:ubuntu

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    wget \
    unzip \
    jq \
    ripgrep \
    fd-find \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Verify installation
RUN claude --version

# Switch back to the coder user
USER coder

# Set up a workspace directory
WORKDIR /home/coder

# Default entrypoint from base image handles Coder agent
