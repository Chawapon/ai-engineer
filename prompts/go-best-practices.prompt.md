---
description: "Review, write, or refactor Go code following Go best practices and idiomatic guidelines. Use when writing new Go code, reviewing existing Go code, or asking how to do something in Go the right way."
name: "Go Best Practices"
argument-hint: "Describe what Go code to write, review, or improve"
agent: "agent"
tools: ["codebase", "search"]
---

Review or generate Go code following idiomatic Go guidelines. Apply the rules below based on the task.

## Code Style

- Run `gofmt` / `goimports` — no manual formatting debates
- Use `camelCase` for unexported, `PascalCase` for exported identifiers
- Acronyms stay all-caps: `userID`, `parseURL`, `HTTPClient`
- Keep line length readable (~100 chars); no hard limit but avoid wrapping mid-expression
- Group imports: stdlib → external → internal, separated by blank lines

## Error Handling

- Always handle errors explicitly — never `_` an error unless justified with a comment
- Wrap errors with context: `fmt.Errorf("loading config: %w", err)`
- Prefer `errors.Is` / `errors.As` over string matching
- Define sentinel errors as `var ErrFoo = errors.New("foo")` at package level
- Return early on error; avoid deeply nested happy-path code
- Only use `panic` for unrecoverable programmer errors (never for business logic)

## Package & Project Organization

- One package = one responsibility; avoid `util`, `common`, `helpers` catch-alls
- Package names: lowercase, single word, no underscores — `httputil` not `http_util`
- Keep `internal/` for packages not intended for external consumption
- `main` packages belong in `cmd/<name>/main.go`
- Avoid circular imports — reorganize rather than work around them

## Interfaces

- Define interfaces at the point of use (consumer), not at the point of definition (producer)
- Keep interfaces small: prefer 1–3 methods
- Accept interfaces, return concrete types (except when an interface is the natural contract)
- Do not export interfaces that only have one implementation unless testability requires it

## Concurrency

- Prefer channels for signaling ownership/transfer; prefer `sync.Mutex` for shared state
- Document goroutine lifetimes — every goroutine must have a clear owner responsible for stopping it
- Always use `context.Context` for cancellation and deadlines; pass it as the first parameter
- Use `sync.WaitGroup` to wait for goroutine groups; use `errgroup` for error propagation
- Avoid sharing memory — communicate via channels when practical
- Detect races during development: `go test -race ./...`

## Structs & Methods

- Use value receivers for small, immutable types; pointer receivers for everything that mutates or is large
- Be consistent: if any method uses a pointer receiver, all methods should
- Embed types for behavior composition, not for inheritance simulation
- Zero values should be useful where possible

## Testing

- Table-driven tests using `[]struct{ name, input, want }` slices
- Use `t.Run(tc.name, ...)` for sub-tests
- Use `testify/assert` or standard `t.Errorf` — be consistent within a codebase
- Test file names: `<file>_test.go`, same package for white-box, `<pkg>_test` for black-box
- Mock via interfaces — avoid mocking frameworks that require code generation unless the team has adopted one
- Name test functions: `TestFunctionName_Scenario` (e.g., `TestParseURL_EmptyInput`)

## Performance

- Profile before optimizing — `pprof` is built-in
- Pre-allocate slices when length is known: `make([]T, 0, n)`
- Reuse objects with `sync.Pool` only when allocation is a measured bottleneck
- Prefer `strings.Builder` over `+` concatenation in loops
- Avoid unnecessary reflection (`reflect`) in hot paths

## Security

- Validate and sanitize all external inputs at system boundaries
- Never log secrets, tokens, or PII
- Use `crypto/rand` for secure random values — never `math/rand` for secrets
- Parameterize SQL queries — never concatenate user input into queries
- Use `html/template` (not `text/template`) for HTML to prevent XSS
- Limit goroutine / resource usage when handling untrusted input to prevent DoS

## Common Anti-patterns to Avoid

- Naked returns in long functions — they hurt readability
- Returning `(bool, error)` — return only `error`; `nil` means success
- Overusing goroutines for simple sequential work
- Ignoring the `context` parameter in library functions
- Using `init()` for complex initialization — prefer explicit setup functions
- Global mutable state — pass dependencies explicitly

---

Apply these guidelines to the code described in the argument. Flag any violations found in existing code and suggest idiomatic replacements. When generating new code, produce idiomatic Go from the start.
