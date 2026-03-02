# GitHub Runner Coder Template

This template creates a Coder workspace with a GitHub Actions self-hosted runner.

## Files

```
github-runner/
├── build/
│   ├── Dockerfile      # Runner container image
│   └── startup.sh      # Runner startup script
├── main.tf             # Terraform configuration
└── README.md           # This file
```

## Usage

### 1. Generate Runner Registration Token

1. Go to GitHub → Repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Select "Linux" → "x64"
4. Copy the token from the configuration command (the `--token` value)

### 2. Create Coder Template

```bash
cd coder/github-runner
coder template create github-runner \
  --variable "github_repo=https://github.com/shoneyJ/writeonce-app" \
  --variable "github_token=YOUR_RUNNER_TOKEN" \
  --variable "runner_labels=linux,deploy"
```

### 3. Start Workspace

Users start the workspace and the runner will automatically:
1. Configure itself with the repository
2. Register with the specified labels
3. Start listening for jobs

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_REPO` | Yes | Repository URL (e.g., `https://github.com/owner/repo`) |
| `GITHUB_TOKEN` | Yes | Runner registration token |
| `RUNNER_LABELS` | No | Comma-separated labels (default: `linux`) |

## Workflow Usage

```yaml
jobs:
  deploy:
    runs-on: self-hosted  # or your custom labels like: runs-on: [self-hosted,linux]
    steps:
      - uses: actions/checkout@v4
      - run: ./deploy.sh
```

## Updating the Runner

```bash
cd ~/actions-runner
./svc.sh stop
./svc.sh uninstall
rm -rf ~/actions-runner

# Recreate using Dockerfile
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Runner not connecting | Check `GITHUB_TOKEN` is valid and not expired |
| Permission denied | Ensure runner user has correct file permissions |
| Job not picked up | Check runner labels match workflow `runs-on` |
