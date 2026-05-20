---
description: "Design or review Go concurrency code — goroutines, channels, context cancellation, errgroup, worker pools, fan-out/fan-in. Use when writing concurrent Go code or diagnosing race conditions, goroutine leaks, or deadlocks."
name: "Go Concurrency Patterns"
argument-hint: "Describe the concurrency problem or paste existing concurrent code to review"
agent: "agent"
tools: ["codebase"]
---

Review or generate Go concurrency code using idiomatic patterns. Apply the rules and patterns below.

## Core Rules

- Every goroutine must have a clear owner responsible for stopping it — document it with a comment
- Always propagate `context.Context` as the first parameter; respect cancellation (`ctx.Done()`)
- Never share memory without synchronization — use channels to transfer ownership, `sync.Mutex` for shared state
- Run `go test -race ./...` to catch races during development

## Pattern Catalogue

### Worker Pool
Use when: bounded parallelism over a stream of jobs.

```go
func runPool(ctx context.Context, jobs <-chan Job, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    for range workers {
        g.Go(func() error {
            for {
                select {
                case job, ok := <-jobs:
                    if !ok {
                        return nil
                    }
                    if err := process(ctx, job); err != nil {
                        return err
                    }
                case <-ctx.Done():
                    return ctx.Err()
                }
            }
        })
    }
    return g.Wait()
}
```

### errgroup for parallel tasks
Use when: a fixed set of independent tasks, any one failure cancels the rest.

```go
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return fetchA(ctx) })
g.Go(func() error { return fetchB(ctx) })
if err := g.Wait(); err != nil {
    return err
}
```

## Common Mistakes to Flag

| Mistake | Fix |
|---------|-----|
| Goroutine with no stop mechanism | Add `ctx.Done()` select case or done channel |
| Closing a channel from the receiver | Only the sender closes |
| `wg.Add` inside the goroutine | Call `wg.Add` before `go func()` |
| Capturing loop variable in goroutine (pre-Go 1.22) | Pass as parameter or use `v := v` |
| Unbounded goroutine spawning per request | Use a worker pool with a semaphore |
| `sync.Mutex` copied by value | Always use pointer receiver or pointer to struct |
| Forgetting `defer wg.Done()` | Always defer, never call conditionally |

## Checklist for Review

- [ ] All goroutines have a documented owner and a stop mechanism
- [ ] `context.Context` is first param in every function that spawns goroutines
- [ ] Channels are closed only by their sender
- [ ] `errgroup` or `WaitGroup` used — no fire-and-forget goroutines in production paths
- [ ] `-race` flag used in CI test runs
- [ ] No global mutable state accessed without a mutex

---

Apply the rules and patterns above to the code or problem in the argument. For review tasks: list each violation with a corrected snippet. For generation tasks: produce the full idiomatic implementation with inline comments explaining ownership and lifecycle.
