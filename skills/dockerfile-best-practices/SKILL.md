---
name: dockerfile-best-practices
description: 'Review or write a Dockerfile following security and efficiency best practices — multi-stage builds, minimal base images, non-root user, layer caching, .dockerignore, no secrets in layers. Use when creating a new Dockerfile, auditing an existing one, or containerizing a Go service.'
argument-hint: "Describe what to containerize or paste the Dockerfile to review"
---

# Dockerfile Best Practices

## When to Use
- Writing a new Dockerfile for any service in this project
- Auditing an existing Dockerfile for security issues or bloated image size
- Containerizing a Go binary with a minimal production image

## Procedure

### For Review Tasks
1. Read the existing Dockerfile (and `.dockerignore` if present)
2. Work through [rules.md](./references/rules.md) section by section
3. List each violation with the line number and a corrected snippet
4. Produce a final clean Dockerfile incorporating all fixes

### For New Dockerfiles (Go service)
1. Confirm the binary name and module path from `go.mod`
2. Use the two-stage pattern below as the starting point
3. Apply all rules from [rules.md](./references/rules.md)
4. Create `.dockerignore` alongside the Dockerfile

## Go Two-Stage Template

```dockerfile
# ── Stage 1: build ──────────────────────────────────────────────
FROM golang:1.24-alpine AS builder
WORKDIR /src

# Fetch dependencies first (cached unless go.mod/go.sum change)
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/app ./cmd/<name>

# ── Stage 2: runtime ────────────────────────────────────────────
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

## .dockerignore Template

```
.git/
.github/
**/*_test.go
*.md
Dockerfile*
```

## Checklist (quick reference)
Full rules with rationale → [rules.md](./references/rules.md)

- [ ] Multi-stage build — build tools not in final image
- [ ] Pinned base image tag — not `latest`
- [ ] Non-root user in final stage
- [ ] `.dockerignore` present
- [ ] No secrets, tokens, or credentials in any layer
- [ ] `COPY` used, not `ADD` (unless tar extraction needed)
- [ ] Dependencies copied and downloaded before source (cache optimization)
- [ ] `CGO_ENABLED=0` + `-trimpath` + `-ldflags="-s -w"` for Go binaries
- [ ] `ENTRYPOINT` for fixed binary, `CMD` for default arguments
- [ ] `EXPOSE` documents the port (does not publish it)
