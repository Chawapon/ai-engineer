---
name: ci-pipeline
description: 'Generate or review a CI/CD pipeline for a Go service — lint, test, docker build, image security scan, Kubernetes dry-run, and rollout verification. Use when setting up GitHub Actions, reviewing an existing workflow, or debugging a failing pipeline.'
argument-hint: "CI target or issue (e.g. 'generate GitHub Actions pipeline', 'pipeline fails on image scan')"
---

# CI Pipeline for Go Services

## When to Use
- Generating a new GitHub Actions workflow from scratch
- Reviewing an existing `.github/workflows/` file for gaps or anti-patterns
- Debugging a specific failing pipeline stage
- Adding image scanning, K8s dry-run, or rollout verification to an existing pipeline

## Pipeline Stages

Full stage reference → [stages.md](./references/stages.md)

```
lint → test → build image → scan image → k8s dry-run → deploy → verify rollout
```

| Stage | Tool | Fail condition |
|-------|------|---------------|
| Lint / vet | `go vet ./...` | any vet error |
| Test | `go test ./...` | any test failure |
| Build image | `docker build` | build error |
| Scan image | `trivy image` | CRITICAL or HIGH CVE |
| K8s dry-run | `kubectl apply --dry-run=server` | manifest invalid |
| Deploy | `kubectl apply` | apply error |
| Verify rollout | `kubectl rollout status` | rollout timeout |

## Workflow Template (GitHub Actions)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  IMAGE: ghcr.io/${{ github.repository }}:${{ github.sha }}

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true
      - run: go vet ./...
      - run: go test ./...

  build-scan:
    needs: lint-test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ${{ env.IMAGE }}
      - uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}
          exit-code: "1"
          severity: CRITICAL,HIGH
          format: sarif
          output: trivy-results.sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif

  deploy:
    if: github.ref == 'refs/heads/main'
    needs: build-scan
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-kubectl@v4
      - name: Dry-run validate manifests
        run: kubectl apply --dry-run=server -f deploy/
      - name: Update image tag
        run: |
          sed -i "s|image:.*|image: ${{ env.IMAGE }}|" deploy/deployment.yaml
      - name: Apply
        run: kubectl apply -f deploy/
      - name: Verify rollout
        run: kubectl rollout status deployment/ai-engineer --timeout=120s
```

## Procedure

### Generating a New Pipeline
1. Confirm the module Go version from `go.mod`
2. Identify the container registry (default: `ghcr.io`)
3. Check if a `deploy/` folder exists — include deploy job only if it does
4. Generate the workflow file at `.github/workflows/ci.yaml`
5. Verify `.github/workflows/ci.yaml` references the correct image name and deployment name

### Reviewing an Existing Pipeline
1. Read `.github/workflows/*.yaml`
2. Work through [stages.md](./references/stages.md) — flag missing stages
3. Check for anti-patterns (see below)
4. Produce a diff with fixes

## Anti-patterns to Flag

| Anti-pattern | Fix |
|---|---|
| `go-version: "1.x"` hardcoded | Use `go-version-file: go.mod` |
| `image: latest` in deploy step | Use `${{ github.sha }}` as tag |
| No image scan | Add `trivy-action` before deploy |
| No `--dry-run=server` before apply | Add dry-run step |
| Secrets passed as env vars in `run:` | Use `${{ secrets.X }}` directly in action inputs |
| No `kubectl rollout status` after apply | Add verify step with timeout |
| `cache: false` on setup-go | Enable module cache to speed up runs |
| Deploy job runs on every push/PR | Gate with `if: github.ref == 'refs/heads/main'` |
