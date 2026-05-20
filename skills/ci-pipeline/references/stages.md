# CI Pipeline Stage Reference

## Stage 1 — Lint & Vet

```yaml
- run: go vet ./...
```

- Must pass before any other stage
- Optionally add `staticcheck` or `golangci-lint` for richer analysis:
  ```yaml
  - uses: golangci/golangci-lint-action@v6
    with:
      version: latest
  ```

## Stage 2 — Test

```yaml
- run: go test ./...
```

- Use `CGO_ENABLED=1` only if `-race` is needed and CGO is available in the runner
- Upload coverage:
  ```yaml
  - run: go test -coverprofile=coverage.out ./...
  - uses: codecov/codecov-action@v4
  ```

## Stage 3 — Build Image

```yaml
- uses: docker/build-push-action@v6
  with:
    context: .
    push: ${{ github.ref == 'refs/heads/main' }}
    tags: ${{ env.IMAGE }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

- Always enable GitHub Actions cache (`cache-from`/`cache-to`) to speed up layer reuse
- Never push on pull_request — only push when `github.ref == 'refs/heads/main'`

## Stage 4 — Image Scan (Trivy)

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    exit-code: "1"          # fail pipeline on findings
    severity: CRITICAL,HIGH
    format: sarif
    output: trivy-results.sarif
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-results.sarif
```

- `exit-code: "1"` blocks deploy on CRITICAL or HIGH CVEs
- SARIF upload surfaces findings in the GitHub Security tab
- Add `.trivyignore` at project root to suppress accepted false-positives with justification

## Stage 5 — Kubernetes Dry-run

```yaml
- name: Dry-run validate manifests
  run: kubectl apply --dry-run=server -f deploy/
```

- `--dry-run=server` validates against a live cluster's API (requires `KUBECONFIG` secret)
- Use `--dry-run=client` as a fallback when no cluster access is available in CI

## Stage 6 — Deploy

```yaml
- name: Update image tag
  run: sed -i "s|image:.*ai-engineer.*|image: ${{ env.IMAGE }}|" deploy/deployment.yaml
- name: Apply
  run: kubectl apply -f deploy/
```

- Always update the image tag in the manifest before applying — never leave a stale tag
- Use a `environment: production` job-level gate to require manual approval for production deploys

## Stage 7 — Verify Rollout

```yaml
- name: Verify rollout
  run: kubectl rollout status deployment/ai-engineer --timeout=120s
```

- Times out after 120s; failure triggers automatic rollback investigation
- Pair with a notification step (Slack, Teams) on failure:
  ```yaml
  - if: failure()
    uses: slackapi/slack-github-action@v1
    with:
      payload: '{"text":"Deploy failed: ${{ github.run_url }}"}'
    env:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  ```

## Security Checklist

- [ ] Registry credentials stored as GitHub secrets, not hardcoded
- [ ] `GITHUB_TOKEN` used for `ghcr.io` — no personal access token needed
- [ ] `permissions:` block scoped to minimum required per job
- [ ] No secrets echoed in `run:` steps
- [ ] Image tag is `${{ github.sha }}` — never `latest`
- [ ] Trivy scan gates the deploy job
- [ ] `environment: production` requires manual approval before deploy
