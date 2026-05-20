# Go Engineer Checklist

## Phase 1 — Scaffold
- [ ] `go.mod` exists with correct module path
- [ ] Entry point at `cmd/<name>/main.go` using `signal.NotifyContext` + `run(ctx)` pattern
- [ ] Domain code under `internal/<name>/` — not in `main` package
- [ ] `internal/doc.go` placeholder deleted
- [ ] `go build ./...` passes immediately after scaffold

## Phase 2 — Implementation
- [ ] No `_` on error returns (unless commented with justification)
- [ ] All errors wrapped: `fmt.Errorf("context: %w", err)`
- [ ] Sentinel errors defined at package level: `var ErrFoo = errors.New("...")`
- [ ] `errors.Is` / `errors.As` used — no string matching on error messages
- [ ] `context.Context` is the first parameter in every function that blocks or spawns goroutines
- [ ] Every goroutine has a documented owner and a stop mechanism (`ctx.Done()` or done channel)
- [ ] `errgroup` used for parallel tasks with error propagation
- [ ] Only the channel sender closes the channel
- [ ] `*slog.Logger` injected as dependency — `slog.Default()` only in `main` or tests
- [ ] Config values read from env in `main()`, passed down explicitly
- [ ] No global mutable state
- [ ] No `panic` for business logic

## Phase 3 — Testing
- [ ] Table-driven tests with `t.Run` sub-tests
- [ ] Test function naming: `TestFunctionName_Scenario`
- [ ] `t.Parallel()` in each sub-test (when safe)
- [ ] Happy path covered
- [ ] Zero/empty/nil inputs covered
- [ ] Every error path covered
- [ ] HTTP handlers tested with `httptest.NewRecorder` — no live server
- [ ] `go test ./...` passes

## Phase 4 — Code Review
- [ ] No naked returns in functions >5 lines
- [ ] No `(bool, error)` return — return `error` only; `nil` = success
- [ ] No `init()` for complex logic — use explicit setup functions
- [ ] No unnecessary reflection in hot paths
- [ ] `crypto/rand` used for any random/token generation — never `math/rand`
- [ ] SQL queries parameterised — no string concatenation with user input
- [ ] `html/template` used for HTML — not `text/template`
- [ ] No secrets, tokens, or PII in logs

## Phase 5 — Dockerfile
- [ ] Multi-stage build: builder + minimal runtime
- [ ] Base image tag pinned (not `latest`)
- [ ] `go.mod`/`go.sum` copied and dependencies downloaded before source
- [ ] `CGO_ENABLED=0 GOOS=linux -trimpath -ldflags="-s -w"`
- [ ] Runtime image is `distroless/static:nonroot` or `scratch`
- [ ] `USER nonroot:nonroot` set in runtime stage
- [ ] Exec form used: `ENTRYPOINT ["/app"]` not `ENTRYPOINT /app`
- [ ] `.dockerignore` present and excludes `.git/`, test files, markdown
- [ ] No secrets in any layer

## Phase 6 — Kubernetes
- [ ] `deploy/deployment.yaml` — `replicas: 2` minimum
- [ ] `livenessProbe` on `GET /health`, `initialDelaySeconds` ≥ 5
- [ ] `readinessProbe` on `GET /health`, gates traffic correctly
- [ ] `resources.requests` and `resources.limits` both set
- [ ] `runAsNonRoot: true` + `runAsUser: 65532`
- [ ] `readOnlyRootFilesystem: true`
- [ ] `capabilities: drop: ["ALL"]`
- [ ] `allowPrivilegeEscalation: false`
- [ ] `terminationGracePeriodSeconds: 30`
- [ ] `deploy/service.yaml` — `ClusterIP`, named port references
- [ ] Image tag is a specific version — not `latest`
- [ ] No secrets hardcoded in manifest — use `Secret` + `envFrom`
