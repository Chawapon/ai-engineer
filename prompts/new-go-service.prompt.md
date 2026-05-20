---
description: "Scaffold a new Go service or sub-package — creates cmd entry point, internal domain package, and test stub. Use when adding a new command, service, or domain to the project."
name: "New Go Service"
argument-hint: "Name of the new service or domain (e.g. 'chat', 'embeddings', 'indexer')"
agent: "agent"
tools: ["codebase"]
---

Scaffold a new Go service or internal domain package for this project. The argument is the name of the service or domain (e.g. `chat`, `embeddings`, `indexer`).

## What to Create

### 1. Entry point — `cmd/<name>/main.go`
Only create this if the domain is a standalone binary (i.e., it has its own `main`). Skip if it is purely an internal library package.

```go
package main

import (
"context"
"fmt"
"log/slog"
"os"
"os/signal"
"syscall"

"ai-engineer/internal/<name>"
)

func main() {
ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
defer stop()

if err := run(ctx); err != nil {
fmt.Fprintf(os.Stderr, "error: %v\n", err)
os.Exit(1)
}
}

func run(ctx context.Context) error {
log := slog.Default()
log.InfoContext(ctx, "starting", "service", "<name>")
// TODO: wire dependencies and start service
<-ctx.Done()
return nil
}
```

### 2. Domain package — `internal/<name>/<name>.go`

```go
package <name>

import (
"context"
"log/slog"
)

// Service is the <name> domain service.
type Service struct {
log *slog.Logger
}

// New creates a new Service.
func New(log *slog.Logger) *Service {
return &Service{log: log}
}
```

### 3. Test stub — `internal/<name>/<name>_test.go`

```go
package <name>_test

import (
"log/slog"
"testing"

"ai-engineer/internal/<name>"
)

func TestNew(t *testing.T) {
svc := <name>.New(slog.Default())
if svc == nil {
t.Fatal("expected non-nil service")
}
}
```

## Rules

- Replace every `<name>` placeholder with the actual name from the argument (lowercase, no spaces)
- Use `log/slog` (stdlib, Go 1.21+) — not `log` or third-party loggers
- Pass `*slog.Logger` as an explicit dependency — never call `slog.Default()` inside library code in production; only in `main` or tests
- Verify the module path is `ai-engineer` (from `go.mod`) before writing imports
- After creating files, run `go build ./...` and `go vet ./...` to confirm no errors
- Delete `internal/doc.go` if it still exists (it is a placeholder)

## Checklist

- [ ] Files created with correct package names
- [ ] All `<name>` placeholders substituted
- [ ] `go build ./...` passes
- [ ] `go vet ./...` passes
