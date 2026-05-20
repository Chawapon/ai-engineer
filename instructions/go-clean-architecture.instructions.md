---
applyTo: "internal/*/adapter/**"
---

# Clean Architecture — Adapter Layer Rules

## Adapters must
- Translate between protocol/infrastructure types and domain types — nothing more
- Map infrastructure errors to domain sentinel errors:
  `sql.ErrNoRows` → `domain.ErrNotFound`, ORA-00001 → `domain.ErrDuplicateKey`
- Accept domain port interfaces as constructor parameters, not concrete implementations
- Use `errors.Is` / `errors.As` for all error inspection — never string matching

## Adapters must not
- Define their own interfaces — interfaces belong in the domain package, not here
- Contain business rules, calculations, or state transitions — those belong in the domain or use case
- Import other adapter packages (no adapter-to-adapter dependencies)
- Call `slog.Default()` — receive `*slog.Logger` via constructor injection
- Call `os.Getenv` — configuration is passed in from `main`

## Input adapters (HTTP handlers) — additionally
- Return HTTP status codes by inspecting domain errors with `errors.Is`:
  `ErrNotFound` → 404, `ErrInvalidState` → 409, unexpected → 500
- Validate request format (missing fields, wrong types) here — business validation stays in domain
- Never return internal error details to the caller — log the error, return a generic message

## Output adapters (repositories, API clients) — additionally
- Implement exactly the port interface defined in the domain package
- Use bind variables for all Oracle queries (`:name` syntax) — see oracle.instructions.md
- Keep SQL in the adapter file — never in the domain or use case
