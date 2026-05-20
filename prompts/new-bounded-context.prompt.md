---
description: Scaffold a complete Clean Architecture bounded context under internal/<name>/. Generates entity.go, errors.go, repository.go (port), usecase.go, usecase_test.go, adapter/http.go, and adapter/oracle.go with all boilerplate wired correctly. Use when adding a new domain to the service.
---

Scaffold a new Clean Architecture bounded context for the `ai-engineer` module.

## Argument
Domain name to scaffold: {{ARGUMENT}}

If no argument given, ask the user for the domain name (e.g. `order`, `customer`, `invoice`).

## Files to Generate

Use the module path `ai-engineer` and domain name `<domain>` (lowercase).

### 1. `internal/<domain>/entity.go`
```go
package <domain>

import "time"

type <Domain> struct {
    ID        int64
    CreatedAt time.Time
    UpdatedAt time.Time
    // TODO: add domain fields
}

// TODO: add methods that enforce invariants
```

### 2. `internal/<domain>/errors.go`
```go
package <domain>

import "errors"

var (
    ErrNotFound     = errors.New("<domain> not found")
    ErrInvalidState = errors.New("invalid <domain> state")
)
```

### 3. `internal/<domain>/repository.go` — output port
```go
package <domain>

import "context"

// Repository is the storage port. Implemented by adapter/oracle.go.
type Repository interface {
    FindByID(ctx context.Context, id int64) (*<Domain>, error)
    Save(ctx context.Context, e *<Domain>) error
    Delete(ctx context.Context, id int64) error
}
```

### 4. `internal/<domain>/usecase.go`
```go
package <domain>

import (
    "context"
    "fmt"
    "log/slog"
)

// Create<Domain>UseCase creates a new <domain>.
type Create<Domain>UseCase struct {
    repo Repository
    log  *slog.Logger
}

func NewCreate<Domain>UseCase(repo Repository, log *slog.Logger) *Create<Domain>UseCase {
    return &Create<Domain>UseCase{repo: repo, log: log}
}

func (uc *Create<Domain>UseCase) Execute(ctx context.Context, e *<Domain>) error {
    if err := uc.repo.Save(ctx, e); err != nil {
        return fmt.Errorf("save <domain>: %w", err)
    }
    uc.log.InfoContext(ctx, "<domain> created", "<domain>_id", e.ID)
    return nil
}
```

### 5. `internal/<domain>/usecase_test.go`
```go
package <domain>_test

import (
    "context"
    "testing"

    "ai-engineer/internal/<domain>"
)

type fakeRepo struct {
    saved *<domain>.<Domain>
    findErr error
}

func (f *fakeRepo) FindByID(_ context.Context, id int64) (*<domain>.<Domain>, error) {
    if f.findErr != nil {
        return nil, f.findErr
    }
    return &<domain>.<Domain>{ID: id}, nil
}
func (f *fakeRepo) Save(_ context.Context, e *<domain>.<Domain>) error {
    f.saved = e
    return nil
}
func (f *fakeRepo) Delete(_ context.Context, _ int64) error { return nil }

func TestCreate<Domain>UseCase_Execute(t *testing.T) {
    tests := []struct {
        name    string
        input   *<domain>.<Domain>
        wantErr bool
    }{
        {"creates valid entity", &<domain>.<Domain>{ID: 1}, false},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            repo := &fakeRepo{}
            uc   := <domain>.NewCreate<Domain>UseCase(repo, slog.Default())
            err  := uc.Execute(context.Background(), tc.input)
            if (err != nil) != tc.wantErr {
                t.Errorf("Execute() error = %v, wantErr %v", err, tc.wantErr)
            }
        })
    }
}
```

### 6. `internal/<domain>/adapter/http.go`
```go
package adapter

import (
    "errors"
    "net/http"

    "ai-engineer/internal/<domain>"
)

type <Domain>Handler struct {
    create *<domain>.Create<Domain>UseCase
}

func New<Domain>Handler(create *<domain>.Create<Domain>UseCase) *<Domain>Handler {
    return &<Domain>Handler{create: create}
}

// Register wires the handler routes onto mux.
func (h *<Domain>Handler) Register(mux *http.ServeMux) {
    mux.HandleFunc("POST /<domain>s", h.Create)
}

func (h *<Domain>Handler) Create(w http.ResponseWriter, r *http.Request) {
    // TODO: decode request body into domain entity
    var e <domain>.<Domain>
    if err := h.create.Execute(r.Context(), &e); err != nil {
        if errors.Is(err, <domain>.ErrInvalidState) {
            http.Error(w, err.Error(), http.StatusConflict)
            return
        }
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    w.WriteHeader(http.StatusCreated)
}
```

### 7. `internal/<domain>/adapter/oracle.go`
```go
package adapter

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "log/slog"

    "ai-engineer/internal/<domain>"
)

// Oracle<Domain>Repo implements <domain>.Repository.
type Oracle<Domain>Repo struct {
    db  *sql.DB
    log *slog.Logger
}

func NewOracle<Domain>Repo(db *sql.DB, log *slog.Logger) *Oracle<Domain>Repo {
    return &Oracle<Domain>Repo{db: db, log: log}
}

func (r *Oracle<Domain>Repo) FindByID(ctx context.Context, id int64) (*<domain>.<Domain>, error) {
    var e <domain>.<Domain>
    err := r.db.QueryRowContext(ctx,
        `SELECT <domain>_id, created_at, updated_at
           FROM <domain>s
          WHERE <domain>_id = :id`,
        sql.Named("id", id),
    ).Scan(&e.ID, &e.CreatedAt, &e.UpdatedAt)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, <domain>.ErrNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("find <domain> %d: %w", id, err)
    }
    return &e, nil
}

func (r *Oracle<Domain>Repo) Save(ctx context.Context, e *<domain>.<Domain>) error {
    _, err := r.db.ExecContext(ctx,
        `MERGE INTO <domain>s d
         USING dual ON (d.<domain>_id = :id)
         WHEN NOT MATCHED THEN
           INSERT (<domain>_id, created_at, updated_at)
           VALUES (:id, SYSTIMESTAMP, SYSTIMESTAMP)`,
        sql.Named("id", e.ID),
    )
    if err != nil {
        return fmt.Errorf("save <domain>: %w", err)
    }
    return nil
}

func (r *Oracle<Domain>Repo) Delete(ctx context.Context, id int64) error {
    if _, err := r.db.ExecContext(ctx,
        `DELETE FROM <domain>s WHERE <domain>_id = :id`,
        sql.Named("id", id),
    ); err != nil {
        return fmt.Errorf("delete <domain> %d: %w", id, err)
    }
    return nil
}
```

## After Generating

1. Replace every `<domain>` / `<Domain>` placeholder with the actual domain name
2. Add domain-specific fields to `entity.go` and update the SQL in `adapter/oracle.go`
3. Run `/oracle-migration create <domain>s table` to generate the DDL
4. Run `go build ./...` — fix any import errors
5. Run `go test ./internal/<domain>/...` — use case tests must pass with the fake repo
6. Wire in `cmd/ai-engineer/main.go`:
   ```go
   <domain>Repo    := adapter.NewOracle<Domain>Repo(db, log)
   create<Domain>  := <domain>.NewCreate<Domain>UseCase(<domain>Repo, log)
   <domain>Handler := adapter.New<Domain>Handler(create<Domain>)
   <domain>Handler.Register(mux)
   ```
