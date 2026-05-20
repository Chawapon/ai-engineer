---
applyTo: "{internal/db/**,internal/*/adapter/oracle*.go}"
---

# Oracle Database Code Rules

## Queries — always
- Use bind variables for every external input: `:name` (named) or `:1` (positional) — never string concatenation
- List columns explicitly — no `SELECT *`
- Call `defer rows.Close()` immediately after the error check on `QueryContext`
- Check `rows.Err()` after every `for rows.Next()` loop
- Add `FETCH FIRST n ROWS ONLY` to any query without a natural row limit

## Transactions — always
- Call `defer func() { _ = tx.Rollback() }()` immediately after `BeginTx` — no-op after `Commit`
- Never call `COMMIT` or `ROLLBACK` inside a PL/SQL procedure invoked from Go — let the caller own the boundary

## Connections — always
- Pass `context.Context` as the first argument to every database call
- Read DSN from `os.Getenv` in `main`/`run` only — never inside library packages
- Set `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime` on `*sql.DB` before first use

## Error handling — always
- Use `errors.As(err, &oraErr)` to inspect Oracle error codes — never match on error strings
- Driver: `github.com/sijms/go-ora/v2` — use its error type for ORA- code inspection
- Map known ORA- codes to package-level sentinel errors (`var ErrDuplicateKey = errors.New(...)`)
- Wrap database errors: `fmt.Errorf("operation name: %w", err)`

## Security — never
- Concatenate user input into SQL strings
- Log DSN, passwords, tokens, or PII
- Connect as DBA, SYS, or SYSDBA from application code
- Hard-code credentials in source files or committed config
