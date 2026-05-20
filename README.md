# AI Engineer

Go microservice with Clean Architecture and Oracle DB backend.

## Key Conventions

- Language: **Go 1.24** — use `for range N`, `slog`, `errors.Join`, etc.
- Oracle driver: **`sijms/go-ora/v2`** (pure Go — no CGO, no Oracle Instant Client required)
- Auto-applied rules for all `*.go` files: [go.instructions.md](.github/instructions/go.instructions.md)
- Clean Architecture adapter rules: [go-clean-architecture.instructions.md](.github/instructions/go-clean-architecture.instructions.md)
- Oracle query rules: [oracle.instructions.md](.github/instructions/oracle.instructions.md)

### Clean Architecture ring

```
Domain (entity, errors, repository port, usecase)
  └─ Adapter layer only (http.go, oracle.go)
       └─ no adapter imports other adapters
```

## Slash-Command Prompts

| Command | When to use |
|---------|-------------|
| `/go-best-practices` | Review or write Go code against idiomatic guidelines |
| `/go-testing` | Generate table-driven `_test.go` files from a function signature |
| `/go-concurrency-patterns` | Design or review goroutines, channels, worker pools, errgroup |
| `/new-go-service` | Scaffold a new `cmd/<name>` + `internal/<name>` skeleton |
| `/new-bounded-context` | Scaffold a full Clean Architecture domain under `internal/<domain>/` |
| `/oracle-migration` | Generate Oracle DDL migration scripts |
| `/k8s-deploy` | Generate Kubernetes deployment manifests |
| `/docker-compose` | Generate or update docker-compose.yml |

## Skills

| Skill | When to invoke |
|-------|---------------|
| `golang-engineer` | End-to-end workflow: scaffold → implement → test → containerise → deploy |
| `go-clean-architecture` | Deep-dive on Clean Architecture patterns for this codebase |
| `oracle-developer` | Oracle-specific query, migration, and connection patterns |
| `dockerfile-best-practices` | Review or generate a production-ready multi-stage Dockerfile |
| `ci-pipeline` | Review or generate GitHub Actions CI workflow |
