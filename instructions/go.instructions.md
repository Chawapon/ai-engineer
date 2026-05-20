---
applyTo: "**/*.go"
---

# Go Code Guidelines

## Style
- Format with `gofmt` / `goimports`; group imports: stdlib → external → internal
- `camelCase` unexported, `PascalCase` exported; acronyms all-caps (`userID`, `HTTPClient`)

## Error Handling
- Always handle errors — never blank-assign `_` without a comment
- Wrap with context: `fmt.Errorf("doing X: %w", err)`
- Use `errors.Is` / `errors.As`; define sentinels as `var ErrFoo = errors.New("...")`
- Return early on error; no deeply nested happy-path logic
- No `panic` for business logic

## Concurrency
- Pass `context.Context` as the first parameter in any function that may block or spawn goroutines
- Every goroutine must have a documented owner and a stop mechanism (`ctx.Done()` or done channel)
- Use `errgroup` for parallel tasks with error propagation; `sync.WaitGroup` for fire-and-forget groups
- Only the sender closes a channel

## Interfaces & Structs
- Define interfaces at the consumer; keep them small (1–3 methods)
- Accept interfaces, return concrete types
- Be consistent with receiver types: all pointer or all value per type

## Testing
- Table-driven tests with `t.Run`; name pattern `TestFunctionName_Scenario`
- Use `-race` flag: `go test -race ./...`

## Security
- Use `crypto/rand` for secrets, never `math/rand`
- Parameterize all SQL — never concatenate user input
- Use `html/template` for HTML output
- Validate and sanitize all external input at system boundaries
- Never log secrets, tokens, or PII
