#!/bin/bash

set -e

echo "Configuring GitHub Actions Runner..."

if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_REPO and GITHUB_TOKEN environment variables are required"
    exit 1
fi

RUNNER_LABELS="${RUNNER_LABELS:-linux}"

cd /home/runner

if [ ! -f ".runner" ]; then
    echo "Configuring runner for $GITHUB_REPO with labels: $RUNNER_LABELS"
    ./config.sh --url "$GITHUB_REPO" \
                --token "$GITHUB_TOKEN" \
                --labels "$RUNNER_LABELS" \
                --name "coder-runner" \
                --work "_work" \
                --unattended \
                --replace
else
    echo "Runner already configured, starting..."
fi

echo "Starting GitHub Actions Runner..."
exec ./run.sh
