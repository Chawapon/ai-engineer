---
name: golang-engineer
description: 'End-to-end Go engineering workflow — scaffold a new service or package, implement it idiomatically, write table-driven tests, containerise with a multi-stage Dockerfile, and deploy to Kubernetes. Use when starting a new Go feature, reviewing existing Go code, or taking a service from code to production.'
argument-hint: "Describe the service or feature to build (e.g. 'chat service', 'review existing auth package')"
---

# Golang Engineer Best Practices

## When to Use
- Scaffolding a new service or internal domain package from scratch
- Reviewing existing Go code against idiomatic standards
- Taking a service from implementation to containerised Kubernetes deployment
- Onboarding to the project conventions

## Workflow

### Phase 1 — Scaffold

1. Confirm module path from `go.mod` (currently `ai-engineer`)
2. Run `/new-go-service <name>` to generate:
   - `cmd/<name>/main.go` — signal context, `run(ctx)` entry pattern
   - `internal/<name>/<name>.go` — `Service` struct, `New(*slog.Logger)` constructor
   - `internal/<name>/<name>_test.go` — test stub
3. Delete `internal/doc.go` if it still exists (placeholder only)
4. Verify: `go build ./...` and `go vet ./...` pass before writing any logic

### Phase 2 — Implement

Follow [go.instructions.md](../../instructions/go.instructions.md) throughout. Key rules:

- **Errors**: wrap with `fmt.Errorf("context: %w", err)`; define sentinels as `var ErrFoo = errors.New("...")`
- **Concurrency**: pass `context.Context` as first param; document goroutine ownership; use `errgroup` for parallel tasks
- **Interfaces**: define at the consumer, keep to 1–3 methods, accept interfaces / return concretes
- **Logging**: inject `*slog.Logger` — never call `slog.Default()` inside library code
- **Config**: read from environment variables in `main()`; pass as explicit parameters into `run(ctx)`

### Phase 3 — Test

Use `/go-testing <function>` to generate table-driven tests. Standards:
- `TestFunctionName_Scenario` naming, `t.Run` sub-tests, `t.Parallel()` in each sub-test
- Cover: happy path, zero/empty values, boundary values, every error path
- Run: `go test ./...` (use `CGO_ENABLED=1` for `-race` when available)
- Use `net/http/httptest` for HTTP handler tests — no running server needed

### Phase 4 — Review

Run `/go-best-practices review <package or paste code>` and work through violations:

| Area | Common issues |
|------|--------------|
| Error handling | `_` on errors, missing `%w` wrap, string matching instead of `errors.Is` |
| Concurrency | goroutine with no stop mechanism, channel closed by receiver, `wg.Add` inside goroutine |
| Security | `math/rand` for secrets, user input concatenated into queries, secrets in `ENV` |
| Style | naked returns, `(bool, error)` return, global mutable state |

Full rules → [checklist.md](./references/checklist.md)

### Phase 5 — Containerise

Run `/dockerfile-best-practices` to generate or review the `Dockerfile`:
- Two-stage build: `golang:1.24-alpine` builder → `gcr.io/distroless/static:nonroot` runtime
- Flags: `CGO_ENABLED=0 GOOS=linux -trimpath -ldflags="-s -w"`
- Non-root `USER nonroot:nonroot`, `readOnlyRootFilesystem`
- Create `.dockerignore` alongside the Dockerfile

### Phase 6 — Deploy to Kubernetes

Generate manifests under `deploy/`:
- **Deployment**: 2 replicas, liveness + readiness probes on `GET /health`, resource requests/limits, `runAsNonRoot`, `capabilities: drop: ["ALL"]`
- **Service**: `ClusterIP`, port 80 → container port 8080
- Wire `ADDR` from a `ConfigMap` or env injection — never hardcode
- `terminationGracePeriodSeconds: 30` to drain in-flight requests on `SIGTERM`

Apply:
```sh
docker build -t <registry>/ai-engineer:<tag> .
docker push <registry>/ai-engineer:<tag>
kubectl apply -f deploy/
```

### Phase 7 — Database Layer (Oracle)

When the service requires an Oracle database, invoke `/oracle-developer` for the full workflow. Key wiring rules:

1. Add `github.com/godror/godror` to `go.mod`: `go get github.com/godror/godror`
2. Open and configure the pool in `run(ctx)` — not in any `internal/` package:
   ```go
   db, err := sql.Open("godror", os.Getenv("ORACLE_DSN"))
   db.SetMaxOpenConns(25)
   db.SetMaxIdleConns(5)
   db.SetConnMaxLifetime(5 * time.Minute)
   ```
3. Inject `*sql.DB` into domain constructors: `internal/db/` packages receive it as a parameter
4. All files under `internal/db/` are governed by `oracle.instructions.md` (always-on)
5. Generate migration scripts with `/oracle-migration <description>`
6. Integration tests use `gvenzl/oracle-free:23-slim` via Testcontainers with per-test rollback isolation

### Phase 8 — Clean Architecture (business logic services)

When the service has real business rules beyond CRUD, apply `/go-clean-architecture`:

1. Run `/new-bounded-context <domain>` to scaffold the full layer skeleton:
   - `internal/<domain>/entity.go` — domain struct + invariant methods
   - `internal/<domain>/errors.go` — sentinel errors
   - `internal/<domain>/repository.go` — output port (interface)
   - `internal/<domain>/usecase.go` — application use case
   - `internal/<domain>/adapter/http.go` — input adapter
   - `internal/<domain>/adapter/oracle.go` — output adapter
2. Implement domain methods and use case logic, then run use-case tests (no DB/HTTP needed)
3. Implement adapters last — they depend on the domain, not the other way around
4. Wire in `main.go`: infrastructure → adapters → use cases → handlers

**When to skip Phase 8**: simple CRUD endpoints with no invariants or multi-step workflows — use a plain handler → repository pattern instead.

## Decision Points

| Situation | Decision |
|-----------|----------|
| New standalone binary | Create `cmd/<name>/main.go` + `internal/<name>/` |
| Shared library only | Create `internal/<name>/` only, no `cmd/` entry point |
| CGO needed | Cannot use `distroless/static`; use `distroless/base` or `alpine` runtime |
| External dependency | Run `go mod tidy` after adding; commit `go.sum` |
| Secrets needed at runtime | Use Kubernetes `Secret` + `envFrom`, never bake into image |

## Quality Gates (must all pass before shipping)

- [ ] `go build ./...` clean
- [ ] `go vet ./...` clean
- [ ] `go test ./...` passes
- [ ] `/go-best-practices` review shows no violations
- [ ] Dockerfile passes `/dockerfile-best-practices` checklist
- [ ] `deploy/` manifests have probes, resource limits, and non-root security context
- [ ] (if DB) `/oracle-developer` checklist passes; no raw SQL strings; `rows.Err()` checked
- [ ] (if business logic) domain package has zero non-stdlib imports; use case tests pass with fake ports
