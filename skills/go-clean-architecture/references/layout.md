# Clean Architecture Folder Layout Reference

## Single Bounded Context (most services)

```
internal/
└── order/
    ├── entity.go           # Order struct, Status type, Confirm/Cancel methods
    ├── errors.go           # var ErrNotFound, ErrInvalidState
    ├── repository.go       # type Repository interface (output port)
    ├── service.go          # type PaymentService interface (output port)
    ├── usecase.go          # ConfirmOrderUseCase, CancelOrderUseCase structs
    ├── usecase_test.go     # fake port implementations, table-driven tests
    └── adapter/
        ├── http.go         # OrderHandler — input adapter
        ├── http_test.go    # httptest tests
        ├── oracle.go       # OracleOrderRepo — implements Repository
        └── oracle_test.go  # Testcontainers integration tests
```

## Multiple Bounded Contexts

```
internal/
├── order/      # Order aggregate
├── customer/   # Customer aggregate (separate — do NOT import order from customer)
├── billing/    # Billing aggregate
└── shared/     # Only truly shared value objects (Money, Address) — keep minimal
```

## What Goes Where — Quick Reference

| Item | Location | Rule |
|------|----------|------|
| `Order` struct | `internal/order/entity.go` | Domain |
| `ErrNotFound` sentinel | `internal/order/errors.go` | Domain |
| `Repository` interface | `internal/order/repository.go` | Port — domain package |
| `ConfirmOrderUseCase` | `internal/order/usecase.go` | Application |
| `OracleOrderRepo` struct | `internal/order/adapter/oracle.go` | Output adapter |
| `OrderHandler` HTTP handler | `internal/order/adapter/http.go` | Input adapter |
| Request/response structs | `internal/order/adapter/http.go` | Adapter (never in domain) |
| DB pool creation | `cmd/<binary>/main.go` | Wiring only |
| `slog.Logger` creation | `cmd/<binary>/main.go` | Wiring only |

## Import Graph (enforced by Go compiler via `internal/`)

```
cmd/ai-engineer/main.go
    → internal/order/adapter   (constructs adapters)
    → internal/order           (constructs use cases)

internal/order/adapter
    → internal/order           (uses domain types + port interfaces)
    → database/sql, net/http   (infrastructure)

internal/order
    → stdlib only              (NO adapter imports allowed here)
```

Verify domain purity:
```sh
go list -deps ./internal/order | grep -v "^internal/order" | grep -v "^std"
# Should print nothing (no non-stdlib, non-self dependencies)
```

## Anti-patterns

| Anti-pattern | Fix |
|-------------|-----|
| `usecase.go` imports `database/sql` | Move DB logic to adapter; use Repository interface |
| `entity.go` imports `encoding/json` | Keep JSON tags minimal; if complex, map in adapter |
| `adapter/http.go` contains business rules | Move rule to domain method or use case |
| Shared `models/` package | Split by bounded context; each domain owns its types |
| Interface defined in adapter package | Move interface definition to domain/usecase package |
| Use case returns `*http.Response` | Return domain type; adapter converts to HTTP response |
