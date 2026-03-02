# GitHub Runner Coder Template - Implementation Details

## Overview

This template provisions a Coder workspace with a self-hosted GitHub Actions runner. The runner connects to a GitHub repository and executes CI/CD jobs on your own infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Coder Server                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              GitHub Runner Workspace                  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │         Docker Container                        │  │  │
│  │  │  ┌─────────────────────────────────────────┐   │  │  │
│  │  │  │   GitHub Actions Runner (v2.317.0)      │   │  │  │
│  │  │  │   - /home/runner                         │   │  │  │
│  │  │  │   - Listens for jobs via HTTPS          │   │  │  │
│  │  │  │   - Executes on self-hosted infrastructure│  │  │  │
│  │  │  └─────────────────────────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ HTTPS/WebSocket
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub.com                                │
│  Repository: shoneyJ/writeonce-app                         │
│  Settings → Actions → Runners                               │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Dockerfile (`build/Dockerfile`)

**Base Image**
- Uses `codercom/enterprise-base:ubuntu` - same base as main Coder template for consistency

**System Dependencies**
- `curl` - for downloading runner
- `tar` - for extracting runner archive
- `git` - for runner operations (checkout, etc.)

**User Setup**
- Creates `runner` user (non-root for security)
- Downloads GitHub Actions Runner v2.317.0
- Extracts to `/home/runner`

**Entrypoint**
- Uses `startup.sh` as entrypoint
- Container runs continuously, not just for job execution

### 2. Startup Script (`build/startup.sh`)

**Environment Variables Required**
- `GITHUB_REPO` - Repository URL (e.g., `https://github.com/owner/repo`)
- `GITHUB_TOKEN` - Runner registration token (PAT with `repo` scope)
- `RUNNER_LABELS` - Optional, defaults to `linux`

**Configuration Process**
1. Validates required environment variables
2. Checks if runner is already configured (`.runner` file exists)
3. If not configured:
   - Runs `./config.sh` with:
     - `--url` - Repository URL
     - `--token` - Registration token
     - `--labels` - Runner labels
     - `--name` - Runner name (`coder-runner`)
     - `--work` - Work directory (`_work`)
     - `--unattended` - Non-interactive mode
     - `--replace` - Replace existing runner with same name
4. Starts the runner via `./run.sh`

**Error Handling**
- Exits with error if `GITHUB_REPO` or `GITHUB_TOKEN` missing
- Uses `set -e` to exit on any command failure

### 3. Terraform Configuration (`main.tf`)

**Providers**
- `coder` - For Coder workspace agent
- `docker` - For container provisioning

**Variables**
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_repo` | string | - | Repository URL (required) |
| `github_token` | string | - | Runner token (required, sensitive) |
| `runner_labels` | string | `"linux"` | Runner labels |

**Resources**

1. **coder_agent.main**
   - Provides workspace agent connection
   - Reports "Running" status via metadata
   - Startup script shows repo/labels info

2. **docker_image.workspace**
   - Builds from `./build` context
   - Image name: `github-runner:latest`
   - Triggers rebuild on file changes (sha1 of build/*)

3. **docker_container.workspace**
   - Uses built image
   - Container name: `github-runner-{owner}-{workspace}`
   - Hostname: `{workspace}-runner`
   - Passes env vars: `GITHUB_REPO`, `GITHUB_TOKEN`, `RUNNER_LABELS`
   - Mounts Docker socket for DinD (if needed)

4. **coder_metadata.container**
   - Displays image, repo, and labels in Coder UI

### 4. Network Configuration

**Docker Networking**
- Runner container can access host Docker via `host.docker.internal`
- This allows running Docker-in-Docker jobs if needed

**GitHub Communication**
- Outbound HTTPS to `github.com` (port 443)
- WebSocket connection for job polling

## Security Considerations

### Runner User
- Runs as non-root `runner` user
- Follows principle of least privilege

### Token Security
- `github_token` is marked sensitive in Terraform
- Token stored in container environment (not secure for shared hosts)
- Consider using GitHub App authentication for production

### Network
- Runner has access to internal network (same as Coder host)
- Restrict access if running untrusted workflows

## Workflow Integration

### Basic Usage

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Build
        run: npm ci && npm run build
      
      - name: Deploy
        run: ./deploy.sh
```

### With Custom Labels

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64]
    
  deploy:
    runs-on: [self-hosted, linux, deploy]
```

## Deployment Steps

### 1. Generate Runner Token

1. Navigate to: `https://github.com/{owner}/{repo}/settings/actions/runners`
2. Click "Add runner"
3. Select: Linux → x64
4. Copy the token (starts with `ATBRK...`)

### 2. Create Coder Template

```bash
cd coder/github-runner

# Initialize Terraform (if needed)
terraform init

# Create template (Coder CLI)
coder template create github-runner \
  --variable "github_repo=https://github.com/shoneyJ/writeonce-app" \
  --variable "github_token=ATBRK..." \
  --variable "runner_labels=linux,deploy"
```

### 3. User Starts Workspace

```bash
coder workspace create github-runner
```

### 4. Verify Runner Registration

1. Go to GitHub → Repo → Settings → Actions → Runners
2. Verify runner appears with status "Idle" or "Busy"

## Troubleshooting

### Runner Not Connecting

**Symptoms**: Runner shows "offline" in GitHub

**Diagnosis**:
```bash
# Check container logs
docker logs github-runner-{name}

# Check runner logs
docker exec github-runner-{name} cat /home/runner/_diag/*.log
```

**Solutions**:
- Verify `GITHUB_TOKEN` is valid and not expired
- Check network connectivity: `docker exec github-runner-{name} curl -s https://github.com`
- Ensure repository URL matches exactly

### Permission Denied

**Symptoms**: Runner can't access files or run commands

**Diagnosis**:
```bash
docker exec github-runner-{name} ls -la /home/runner
```

**Solutions**:
- Verify file ownership: `chown -R runner:runner /home/runner`
- Check runner has correct group membership

### Jobs Not Being picked up

**Symptoms**: Jobs queue but runner doesn't pick them up

**Diagnosis**:
- Check runner labels in GitHub UI
- Verify workflow `runs-on` matches runner labels

**Solutions**:
- Update `RUNNER_LABELS` to match workflow
- Re-register runner with correct labels

## Maintenance

### Updating Runner Version

```bash
# Stop runner
docker exec github-runner-{name} ./svc.sh stop

# Remove container and rebuild with new version in Dockerfile
docker build -t github-runner:latest ./build
docker rm github-runner-{name}
docker run -d --name github-runner-{name} \
  -e GITHUB_REPO=... \
  -e GITHUB_TOKEN=... \
  github-runner:latest
```

### Runner Removal

1. In GitHub: Settings → Actions → Runners → Delete runner
2. In Coder: Delete workspace

## Comparison with GitHub-Hosted Runners

| Aspect | GitHub-Hosted | Self-Hosted (This Template) |
|--------|---------------|----------------------------|
| Cost | Free | Your infrastructure |
| Compute | 2-4 vCPU, 14-64GB RAM | Configurable |
| Max Job Time | 6 hours | No limit |
| Storage | Ephemeral | Persistent (per workspace) |
| Docker | DinD required | Direct access |
| Maintenance | None | Runner updates |

## Future Improvements

- [ ] Add GitHub App authentication support
- [ ] Implement auto-scaling with multiple runners
- [ ] Add health check endpoint
- [ ] Support runner pools with labels
- [ ] Add monitoring/alerting for runner status
- [ ] Implement secure token refresh
