---
description: "Generate table-driven tests for a Go function or method. Use when you want to write tests for existing Go code, create _test.go files, or generate test cases from a function signature."
name: "Go Testing"
argument-hint: "Paste the function/method signature or full function to test"
agent: "agent"
tools: ["codebase"]
---

Generate idiomatic, table-driven tests for the provided Go function or method.

## Output Structure

1. File header with correct package declaration (`<pkg>_test` for black-box, `<pkg>` for white-box)
2. Import block (stdlib first, then `testify/assert` if used in the codebase, otherwise `testing` only)
3. One `TestFunctionName` function per function under test, containing:
   - A `tests` slice of anonymous structs with fields: `name`, `input` (one field per param), `want`, and `wantErr bool` if the function returns an error
   - A `t.Run(tc.name, ...)` loop iterating over `tests`
4. Subtests call the function, assert results, and check errors with `errors.Is` when a sentinel error is expected

## Test Case Requirements

Cover all of the following:
- **Happy path** — typical valid input
- **Zero/empty values** — empty string, 0, nil, empty slice
- **Boundary values** — min, max, off-by-one where relevant
- **Error cases** — each distinct error the function can return
- **Invalid input** — malformed data, wrong types if applicable

## Naming Conventions

- Function: `TestFunctionName_Scenario` for focused scenarios; plain `TestFunctionName` for table-driven
- Sub-test `name` field: short, lowercase, human-readable — `"empty input"`, `"max limit exceeded"`

## Style Rules

- No `_` on error returns — always assert `err != nil` or `errors.Is(err, ErrFoo)`
- Use `t.Fatal` / `t.Fatalf` only when subsequent assertions are meaningless without the prior one
- Use `t.Parallel()` at the top of each sub-test when the function under test is safe to run concurrently
- Avoid test helpers unless the setup repeats 3+ times

---

Generate the complete `_test.go` content for the function provided in the argument. Search the codebase first to find the function's existing package, imports, and any sentinel errors it uses.
