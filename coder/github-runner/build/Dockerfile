FROM codercom/enterprise-base:ubuntu

USER root

RUN apt-get update && apt-get install -y \
    curl \
    tar \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash runner

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

RUN cd /home/runner && \
    curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz && \
    tar -xzf actions-runner.tar.gz && \
    rm actions-runner.tar.gz && \
    chown -R runner:runner /home/runner

USER runner

WORKDIR /home/runner

ENTRYPOINT ["/startup.sh"]
