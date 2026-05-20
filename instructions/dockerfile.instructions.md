---
applyTo: "Dockerfile*"
---

# Dockerfile Guidelines

## Base Image
- Pin the tag — `golang:1.24-alpine` not `golang:latest`; use digest (`@sha256:...`) for production
- Use minimal runtime: `gcr.io/distroless/static:nonroot` or `scratch` for Go; `alpine` only when a shell is needed
- Official images only

## Multi-stage Builds
- Build tools (compilers, SDKs) must not appear in the final stage
- Copy only the compiled binary: `COPY --from=builder /out/app /app`

## Layer Caching
- Order: base image → system packages → dependency manifests → dependency download → source → build
- Copy `go.mod go.sum` and run `go mod download` **before** `COPY . .`

## Security
- Final stage must have a non-root `USER`
- Never use `ENV` for secrets — inject at runtime
- Use exec form for `CMD`/`ENTRYPOINT`: `["cmd", "arg"]` not `cmd arg`

## Go Build Flags
- `CGO_ENABLED=0 GOOS=linux` for static binaries
- `-trimpath -ldflags="-s -w"` to strip paths and debug symbols

## Always Create `.dockerignore`
Exclude: `.git/`, `.github/`, `**/*_test.go`, `*.md`, `Dockerfile*`, `*.env`
