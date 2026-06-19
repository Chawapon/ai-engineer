# AI Engineer

Go microservice with Clean Architecture.

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
| `/k8s-deploy` | Generate Kubernetes deployment manifests |

## Skills

| Skill | When to invoke |
|-------|---------------|
| `golang-engineer` | End-to-end workflow: scaffold → implement → test → containerise → deploy |
| `go-clean-architecture` | Deep-dive on Clean Architecture patterns for this codebase |
| `dockerfile-best-practices` | Review or generate a production-ready multi-stage Dockerfile |
