---
name: go-clean-architecture
description: 'Apply Clean Architecture (Hexagonal / Ports & Adapters) to a Go project. Use when designing a new service with business logic that must be testable independently of HTTP, databases, or external APIs; refactoring a layered package into clean layers; deciding where to place an interface or type; or reviewing a package for dependency-rule violations. Produces a layered folder structure, domain entities, use cases, port interfaces, and wired adapters.'
argument-hint: "Describe the service or feature: 'design order service', 'refactor health package', 'where does retry logic go?'"
---

# Go Clean Architecture

## When to Use
- Designing a new service that has real business logic (not just CRUD pass-through)
- Deciding where a new type, interface, or function belongs in an existing layered structure
- Reviewing a package for dependency-rule violations (inner layer importing outer layer)
- Onboarding to the clean architecture conventions of this codebase

## The Three Rings

```
┌─────────────────────────────────────┐
│  Infrastructure / Adapters          │  ← HTTP handlers, DB repos, API clients
│  ┌───────────────────────────────┐  │
│  │  Application / Use Cases      │  │  ← Orchestration, business workflows
│  │  ┌─────────────────────────┐  │  │
│  │  │  Domain                 │  │  │  ← Entities, value objects, domain errors
│  │  │  (no external imports)  │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**The Dependency Rule**: source code dependencies point **inward only**.
Domain never imports Application. Application never imports Infrastructure.
Violations are build errors waiting to happen — catch them at design time.

---

## Folder Layout

```
internal/
├── <domain>/               ← one folder per bounded context
│   ├── entity.go           ← Domain: structs + methods, no framework imports
│   ├── errors.go           ← Domain: sentinel errors (var ErrNotFound = ...)
│   ├── repository.go       ← Port (output): interface the domain needs from storage
│   ├── service.go          ← Port (output): interface for external services
│   ├── usecase.go          ← Application: use-case structs + Execute methods
│   ├── usecase_test.go     ← Application tests: mock ports, no DB/HTTP
│   └── adapter/
│       ├── http.go         ← Input adapter: HTTP handler calling use cases
│       ├── http_test.go    ← httptest-based handler tests
│       ├── oracle.go       ← Output adapter: implements repository.go interface
│       └── oracle_test.go  ← Integration test (Testcontainers)
cmd/
└── <binary>/
    └── main.go             ← Wiring only: construct adapters → inject into use cases → start server
```

Full layout reference → [references/layout.md](./references/layout.md)

---

## Phase 1 — Define the Domain

Domain structs hold state and enforce invariants. They have **zero imports outside stdlib**.

```go
// internal/order/entity.go
package order

import (
    "errors"
    "time"
)

var (
    ErrNotFound     = errors.New("order not found")
    ErrInvalidState = errors.New("invalid order state")
)

type Status string

const (
    StatusPending   Status = "PENDING"
    StatusConfirmed Status = "CONFIRMED"
    StatusCancelled Status = "CANCELLED"
)

type Order struct {
    ID        int64
    CustomerID int64
    Status    Status
    Total     float64
    CreatedAt time.Time
}

// Confirm applies a domain rule — no infrastructure concern here.
func (o *Order) Confirm() error {
    if o.Status != StatusPending {
        return ErrInvalidState
    }
    o.Status = StatusConfirmed
    return nil
}
```

Domain checklist:
- [ ] No imports from `internal/<domain>/adapter/` or any infrastructure package
- [ ] No `*sql.DB`, `*http.Request`, or any framework type
- [ ] Sentinel errors defined as package-level `var`
- [ ] Methods enforce invariants — callers cannot put an entity into an illegal state

---

## Phase 2 — Define Ports (Interfaces)

Ports are interfaces defined **in the domain layer** expressing what the domain *needs*.
They are implemented by adapters in the outer ring.

```go
// internal/order/repository.go  — output port
package order

import "context"

// Repository is the storage port. Adapters (Oracle, in-memory) implement this.
type Repository interface {
    FindByID(ctx context.Context, id int64) (*Order, error)
    Save(ctx context.Context, o *Order) error
    Delete(ctx context.Context, id int64) error
}

// internal/order/service.go  — output port for an external service
type PaymentService interface {
    Charge(ctx context.Context, customerID int64, amount float64) error
}
```

Port rules:
- [ ] Defined in the domain package — never in the adapter package
- [ ] 1–3 methods per interface (follow interface segregation)
- [ ] Method signatures use domain types only — no `*sql.Tx`, no `http.ResponseWriter`
- [ ] Named with the role they play: `Repository`, `Cache`, `Notifier`, `PaymentService`

---

## Phase 3 — Implement Use Cases

Use cases orchestrate domain objects and ports. They contain **workflow logic**, not business rules.

```go
// internal/order/usecase.go
package order

import (
    "context"
    "fmt"
)

type ConfirmOrderUseCase struct {
    repo    Repository
    payment PaymentService
    log     *slog.Logger
}

func NewConfirmOrderUseCase(repo Repository, payment PaymentService, log *slog.Logger) *ConfirmOrderUseCase {
    return &ConfirmOrderUseCase{repo: repo, payment: payment, log: log}
}

func (uc *ConfirmOrderUseCase) Execute(ctx context.Context, orderID int64) error {
    o, err := uc.repo.FindByID(ctx, orderID)
    if err != nil {
        return fmt.Errorf("find order: %w", err)
    }
    if err := o.Confirm(); err != nil {         // domain rule enforced here
        return fmt.Errorf("confirm order: %w", err)
    }
    if err := uc.payment.Charge(ctx, o.CustomerID, o.Total); err != nil {
        return fmt.Errorf("charge payment: %w", err)
    }
    if err := uc.repo.Save(ctx, o); err != nil {
        return fmt.Errorf("save order: %w", err)
    }
    uc.log.InfoContext(ctx, "order confirmed", "order_id", orderID)
    return nil
}
```

Use-case checklist:
- [ ] Constructor accepts interfaces (ports), not concrete types
- [ ] `*slog.Logger` injected — never call `slog.Default()` here
- [ ] Returns only `error` (or a domain type + error) — never an HTTP status code
- [ ] One `Execute` method per use case struct — one responsibility

---

## Phase 4 — Write Use Case Tests (No DB, No HTTP)

Inject fake implementations of ports — test the workflow in pure Go.

```go
// internal/order/usecase_test.go
package order_test

type fakeRepo struct {
    orders map[int64]*order.Order
    saveErr error
}

func (f *fakeRepo) FindByID(_ context.Context, id int64) (*order.Order, error) {
    o, ok := f.orders[id]
    if !ok {
        return nil, order.ErrNotFound
    }
    return o, nil
}
func (f *fakeRepo) Save(_ context.Context, o *order.Order) error { return f.saveErr }
func (f *fakeRepo) Delete(_ context.Context, _ int64) error       { return nil }

func TestConfirmOrderUseCase_Execute(t *testing.T) {
    tests := []struct {
        name    string
        order   *order.Order
        saveErr error
        wantErr error
    }{
        {"pending order confirmed", &order.Order{ID: 1, Status: order.StatusPending, Total: 99.9}, nil, nil},
        {"already confirmed returns error", &order.Order{ID: 2, Status: order.StatusConfirmed}, nil, order.ErrInvalidState},
        {"save failure propagated", &order.Order{ID: 3, Status: order.StatusPending}, io.ErrUnexpectedEOF, io.ErrUnexpectedEOF},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            repo := &fakeRepo{orders: map[int64]*order.Order{tc.order.ID: tc.order}, saveErr: tc.saveErr}
            uc   := order.NewConfirmOrderUseCase(repo, &fakePayment{}, slog.Default())
            err  := uc.Execute(context.Background(), tc.order.ID)
            if !errors.Is(err, tc.wantErr) {
                t.Errorf("err = %v, want %v", err, tc.wantErr)
            }
        })
    }
}
```

---

## Phase 5 — Implement Adapters

### Input Adapter (HTTP Handler)
```go
// internal/order/adapter/http.go
package adapter

type OrderHandler struct {
    confirm *order.ConfirmOrderUseCase
}

func NewOrderHandler(confirm *order.ConfirmOrderUseCase) *OrderHandler {
    return &OrderHandler{confirm: confirm}
}

func (h *OrderHandler) ConfirmOrder(w http.ResponseWriter, r *http.Request) {
    id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
    if err != nil {
        http.Error(w, "invalid order id", http.StatusBadRequest)
        return
    }
    if err := h.confirm.Execute(r.Context(), id); err != nil {
        if errors.Is(err, order.ErrNotFound) {
            http.Error(w, "not found", http.StatusNotFound)
            return
        }
        if errors.Is(err, order.ErrInvalidState) {
            http.Error(w, err.Error(), http.StatusConflict)
            return
        }
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    w.WriteHeader(http.StatusNoContent)
}
```

### Output Adapter (Oracle Repository)
```go
// internal/order/adapter/oracle.go
package adapter

// OracleOrderRepo implements order.Repository.
type OracleOrderRepo struct {
    db  *sql.DB
    log *slog.Logger
}

func NewOracleOrderRepo(db *sql.DB, log *slog.Logger) *OracleOrderRepo {
    return &OracleOrderRepo{db: db, log: log}
}

func (r *OracleOrderRepo) FindByID(ctx context.Context, id int64) (*order.Order, error) {
    var o order.Order
    err := r.db.QueryRowContext(ctx,
        `SELECT order_id, customer_id, status, total, created_at
           FROM orders WHERE order_id = :id`,
        sql.Named("id", id),
    ).Scan(&o.ID, &o.CustomerID, &o.Status, &o.Total, &o.CreatedAt)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, order.ErrNotFound   // ← map infrastructure error to domain error
    }
    if err != nil {
        return nil, fmt.Errorf("find order %d: %w", id, err)
    }
    return &o, nil
}
```

Adapter rules:
- [ ] Input adapters translate protocol → domain type; never contain business logic
- [ ] Output adapters map infrastructure errors to domain sentinel errors (`sql.ErrNoRows` → `order.ErrNotFound`)
- [ ] Adapters import domain types but domain never imports adapters

---

## Phase 6 — Wire in main.go

```go
func run(ctx context.Context) error {
    log := slog.Default()

    // Infrastructure
    db, err := sql.Open("godror", os.Getenv("ORACLE_DSN"))
    // ... configure pool, ping

    // Output adapters
    orderRepo := adapter.NewOracleOrderRepo(db, log)
    paymentSvc := adapter.NewStripePaymentService(os.Getenv("STRIPE_KEY"), log)

    // Use cases
    confirmOrder := order.NewConfirmOrderUseCase(orderRepo, paymentSvc, log)

    // Input adapters
    orderHandler := adapter.NewOrderHandler(confirmOrder)

    // HTTP server
    mux := http.NewServeMux()
    mux.HandleFunc("POST /orders/{id}/confirm", orderHandler.ConfirmOrder)
    mux.Handle("GET /health", health.Handler(log))
    // ... start server
}
```

---

## Decision Points

| Question | Answer |
|----------|--------|
| Where does validation go? | Input validation (format) in the adapter; business validation in the domain |
| Where do DTOs / request structs go? | In the adapter package — domain types are the internal contract |
| Should I share a domain package across bounded contexts? | No — copy if needed; avoid coupling bounded contexts through shared domain types |
| When NOT to use clean architecture? | CRUD-only services with no business rules — plain `handler → repo` is simpler and correct |
| Where do cross-cutting concerns go? (logging, tracing) | Middleware (HTTP) or injected `*slog.Logger`; never a global singleton inside domain/usecase |

## Quality Gates

- [ ] `go build ./...` clean — import violations often manifest as cycles
- [ ] Domain package has zero imports outside stdlib (`go list -deps ./internal/<domain>`)
- [ ] Use case tests pass with fake ports — no DB or HTTP server started
- [ ] Adapter tests use `httptest` (input) or Testcontainers (output)
- [ ] `/go-best-practices` shows no violations in domain or use case packages
