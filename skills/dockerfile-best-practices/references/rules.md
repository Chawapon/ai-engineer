# Dockerfile Rules Reference

## Base Image

- **Pin the tag** — `golang:1.24-alpine` not `golang:latest`; digest pinning (`@sha256:...`) for production
- **Minimal runtime** — prefer `gcr.io/distroless/static:nonroot` or `scratch` for Go; `alpine` only when a shell is genuinely needed
- **Official images only** — never use unverified community images as a base

## Multi-stage Builds

- Build stage contains compilers, SDKs, test tools — none of these belong in the final image
- Copy only the compiled artifact(s) into the runtime stage: `COPY --from=builder /out/app /app`
- One runtime stage per image; if you need debugging, build a separate debug target

## Layer Caching

- Order instructions from **least to most frequently changing**:
  1. Base image
  2. System packages (`apk add`, `apt-get install`)
  3. Dependency manifest (`go.mod`, `go.sum`, `package.json`, etc.)
  4. `RUN go mod download` / `npm ci`
  5. Application source (`COPY . .`)
  6. Build command
- Each `RUN`, `COPY`, `ADD` creates a new layer — combine related `RUN` steps with `&&`

## Security

- **Non-root user** — add `USER nonroot:nonroot` (distroless) or create a user in alpine:
  ```dockerfile
  RUN addgroup -S app && adduser -S app -G app
  USER app:app
  ```
- **No secrets in any layer** — environment variables set via `ENV` are visible in `docker inspect`; use secrets at runtime (Docker secrets, env injection)
- **Read-only filesystem** — run containers with `--read-only`; use `VOLUME` or tmpfs for writable paths
- **Drop capabilities** at runtime: `--cap-drop ALL --cap-add NET_BIND_SERVICE` if port <1024 is needed

## Instructions

| Rule | Detail |
|------|--------|
| `COPY` over `ADD` | `ADD` auto-extracts tarballs and fetches URLs — surprising behaviour; use `COPY` unless you need extraction |
| `WORKDIR` always absolute | `WORKDIR /app`, never relative |
| `EXPOSE` is documentation | It does not publish the port; use `-p` or `ports:` in compose |
| `ENTRYPOINT` + `CMD` | `ENTRYPOINT ["/app"]` for the fixed binary; `CMD ["--flag"]` for overridable defaults; use JSON array form (exec form) to avoid shell wrapping |
| No `SHELL` form for entrypoint | `CMD /app` spawns a shell as PID 1; `CMD ["/app"]` runs the binary as PID 1 and receives signals correctly |

## Go-specific

- `CGO_ENABLED=0` — produces a statically linked binary that works in `scratch`/distroless
- `-trimpath` — removes local build paths from the binary (reproducibility + less information disclosure)
- `-ldflags="-s -w"` — strips debug symbols and DWARF, reducing binary size ~30%
- `GOOS=linux GOARCH=amd64` — set explicitly when cross-compiling from macOS/Windows

## .dockerignore

Always create `.dockerignore` next to the Dockerfile. Minimum exclusions:

```
.git/
.github/
**/*_test.go
*.md
Dockerfile*
*.env
*.local
```

## Health Check

Add a `HEALTHCHECK` for long-running services:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/app", "--health-check"]
```
Or use `wget`/`curl` if available in the image:
```dockerfile
HEALTHCHECK CMD wget -qO- http://localhost:8080/health || exit 1
```

## Common Anti-patterns

| Anti-pattern | Fix |
|---|---|
| `FROM golang:latest` | Pin: `FROM golang:1.24-alpine` |
| Single-stage build | Split into builder + runtime |
| `RUN apt-get update` without version pin | Pin package versions or use a pinned base digest |
| `COPY . .` before dependency download | Copy manifests first, download, then copy source |
| `ENV SECRET_KEY=abc123` | Inject at runtime; never bake secrets into images |
| `CMD /app` (shell form) | Use `CMD ["/app"]` (exec form) so the binary is PID 1 |
| Root user | Add `USER nonroot:nonroot` in runtime stage |
