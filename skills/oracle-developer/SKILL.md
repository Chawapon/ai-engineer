---
name: oracle-developer
description: 'Oracle Database best practices for developers. Use when writing SQL queries against Oracle, designing schemas, calling PL/SQL stored procedures, managing transactions, or reviewing database code for security, correctness, and performance. Covers parameterized queries, connection pooling, error handling, naming conventions, index hygiene, and integration testing.'
argument-hint: "Describe the task: 'write a query for X', 'review this SQL', 'call stored procedure Y', 'design schema for Z'"
---

# Oracle Database for Developers

## When to Use
- Writing or reviewing SQL queries against an Oracle database
- Designing or migrating Oracle schemas
- Calling PL/SQL stored procedures or functions from application code
- Reviewing database code for SQL injection, N+1, or missing indexes
- Setting up connection pooling and context-aware queries
- Writing integration tests for database-layer code

---

## Phase 1 — Connection Setup

**Driver (Go)**: `godror` (`github.com/godror/godror`) via `database/sql`.

Rules:
- Configure pool limits explicitly — never rely on driver defaults in production
- Pass `context.Context` to every database call: `QueryContext`, `ExecContext`, `QueryRowContext`
- Store the DSN / credentials in environment variables — never in source code or config files
- Call `PingContext` at startup to fail fast on misconfiguration

```go
db, err := sql.Open("godror", os.Getenv("ORACLE_DSN"))
if err != nil {
    return fmt.Errorf("open oracle db: %w", err)
}
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(5 * time.Minute)

if err := db.PingContext(ctx); err != nil {
    return fmt.Errorf("ping oracle: %w", err)
}
```

---

## Phase 2 — Writing Safe Queries

**Rule**: Never concatenate user input into SQL. Always use bind variables.

| Unsafe | Safe |
|--------|------|
| `"SELECT ... WHERE id = " + id` | `"SELECT ... WHERE id = :id"` |
| `fmt.Sprintf("... WHERE name = '%s'", name)` | `"... WHERE name = :name"` with `sql.Named` |

Oracle bind variable syntax: `:name` (named, preferred) or `:1`, `:2` (positional).

```go
rows, err := db.QueryContext(ctx,
    `SELECT user_id, username
       FROM app_users
      WHERE dept_id = :dept
        AND status   = :status`,
    sql.Named("dept", deptID),
    sql.Named("status", "ACTIVE"),
)
if err != nil {
    return fmt.Errorf("query users: %w", err)
}
defer rows.Close()

for rows.Next() {
    var userID   int64
    var username string
    if err := rows.Scan(&userID, &username); err != nil {
        return fmt.Errorf("scan user row: %w", err)
    }
}
if err := rows.Err(); err != nil {
    return fmt.Errorf("rows iteration: %w", err)
}
```

Query checklist:
- [ ] All user inputs bound as parameters, not concatenated
- [ ] `rows.Close()` deferred immediately after the error check
- [ ] `rows.Err()` checked after the loop
- [ ] Column list explicit — never `SELECT *` in production queries
- [ ] `FETCH FIRST n ROWS ONLY` on unbounded result sets

---

## Phase 3 — Transaction Management

```go
tx, err := db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
if err != nil {
    return fmt.Errorf("begin tx: %w", err)
}
// Rollback guard — no-op if Commit succeeds.
defer func() { _ = tx.Rollback() }()

if _, err := tx.ExecContext(ctx,
    `UPDATE accounts SET balance = balance - :amt WHERE id = :id`,
    sql.Named("amt", amount),
    sql.Named("id", fromID),
); err != nil {
    return fmt.Errorf("debit account: %w", err)
}

if err := tx.Commit(); err != nil {
    return fmt.Errorf("commit tx: %w", err)
}
```

Rules:
- Always `defer tx.Rollback()` immediately after `BeginTx` — no-op after successful `Commit`
- Use `sql.LevelReadCommitted` (Oracle default) unless stronger isolation is required
- Keep transactions short — do not hold them open across network round trips
- Prefer explicit `SAVEPOINT` / `ROLLBACK TO` for partial rollbacks within a long transaction

---

## Phase 4 — Calling PL/SQL

**Procedure with OUT parameter:**
```go
var result string
if _, err := db.ExecContext(ctx,
    `BEGIN pkg_orders.process_order(:order_id, :result); END;`,
    sql.Named("order_id", orderID),
    sql.Named("result", sql.Out{Dest: &result}),
); err != nil {
    return fmt.Errorf("call process_order: %w", err)
}
```

**Function returning a scalar:**
```go
var total float64
if err := db.QueryRowContext(ctx,
    `SELECT pkg_billing.calculate_total(:cust_id) FROM dual`,
    sql.Named("cust_id", custID),
).Scan(&total); err != nil {
    return fmt.Errorf("calculate total: %w", err)
}
```

**REF CURSOR (result set):**
```go
var cursor godror.ObjectScanner
if _, err := db.ExecContext(ctx,
    `BEGIN pkg_reports.get_orders(:cust_id, :cur); END;`,
    sql.Named("cust_id", custID),
    sql.Named("cur", sql.Out{Dest: &cursor}),
); err != nil {
    return fmt.Errorf("get orders cursor: %w", err)
}
defer cursor.Close()
```

Rules:
- Use anonymous PL/SQL blocks (`BEGIN … END;`) to call procedures
- Use `FROM dual` for function calls that return scalar values
- Never call `COMMIT` or `ROLLBACK` inside a PL/SQL procedure called from application code — let the caller control the transaction boundary

---

## Phase 5 — Oracle Error Handling

```go
import "github.com/godror/godror"

var oraErr *godror.OraErr
if errors.As(err, &oraErr) {
    switch oraErr.Code() {
    case 1:     // ORA-00001: unique constraint violated
        return ErrDuplicateKey
    case 2292:  // ORA-02292: integrity constraint (child record exists)
        return ErrForeignKeyViolation
    case 1400:  // ORA-01400: cannot insert NULL
        return ErrRequiredFieldMissing
    case 12899: // ORA-12899: value too large for column
        return ErrValueTooLarge
    }
}
return fmt.Errorf("database operation: %w", err)
```

Define sentinel errors at package level:
```go
var (
    ErrDuplicateKey         = errors.New("record already exists")
    ErrForeignKeyViolation  = errors.New("referenced record does not exist")
    ErrRequiredFieldMissing = errors.New("required field is missing")
    ErrValueTooLarge        = errors.New("value exceeds column length")
)
```

Common Oracle error codes:

| Code     | Meaning |
|----------|---------|
| ORA-00001 | Unique constraint violated |
| ORA-01400 | Cannot insert NULL |
| ORA-01403 | No data found (PL/SQL) |
| ORA-01422 | Exact fetch returns more than one row |
| ORA-02292 | Child record exists (FK violation) |
| ORA-12899 | Value too large for column |

---

## Phase 6 — Schema Naming Conventions

| Object | Convention | Example |
|--------|-----------|---------|
| Table | `UPPER_SNAKE_CASE` | `APP_USERS`, `ORDER_LINES` |
| Column | `UPPER_SNAKE_CASE` | `USER_ID`, `CREATED_AT` |
| Primary key constraint | `<TABLE>_PK` | `APP_USERS_PK` |
| Foreign key constraint | `<TABLE>_<REF>_FK` | `ORDER_LINES_ORDERS_FK` |
| Index | `<TABLE>_<COLS>_IX` | `APP_USERS_EMAIL_IX` |
| Unique constraint | `<TABLE>_<COLS>_UK` | `APP_USERS_EMAIL_UK` |
| Sequence (pre-12c) | `<TABLE>_SEQ` | `APP_USERS_SEQ` |

Always include audit columns:
```sql
CREATED_AT  TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
UPDATED_AT  TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
CREATED_BY  VARCHAR2(100)                  NOT NULL
```

Primary keys — prefer identity columns (Oracle 12c+):
```sql
USER_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

---

## Phase 7 — Performance Checklist

- [ ] Index exists on every FK column (Oracle does **not** auto-create FK indexes)
- [ ] `EXPLAIN PLAN` reviewed — no unexpected `FULL TABLE SCAN` on large tables
- [ ] Pagination uses `OFFSET n ROWS FETCH NEXT m ROWS ONLY`
- [ ] `ROWNUM` filtering happens **before** `ORDER BY` (use a subquery)
- [ ] Bulk inserts use `INSERT ALL` or PL/SQL `FORALL` — not row-by-row loops
- [ ] `LIKE '%term'` leading wildcard avoided on large tables (use Oracle Text)
- [ ] Statistics up to date: `DBMS_STATS.GATHER_TABLE_STATS`

---

## Phase 8 — Integration Testing

Prefer a real Oracle instance via Testcontainers:
```go
container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
    ContainerRequest: testcontainers.ContainerRequest{
        Image:        "gvenzl/oracle-free:23-slim",
        ExposedPorts: []string{"1521/tcp"},
        Env: map[string]string{
            "ORACLE_PASSWORD":   "testpass",
            "APP_USER":          "testuser",
            "APP_USER_PASSWORD": "testpass",
        },
        WaitingFor: wait.ForLog("DATABASE IS READY TO USE!"),
    },
    Started: true,
})
```

Test isolation — roll back after every test:
```go
func withTx(t *testing.T, db *sql.DB, fn func(tx *sql.Tx)) {
    t.Helper()
    tx, err := db.BeginTx(context.Background(), nil)
    if err != nil {
        t.Fatal(err)
    }
    defer tx.Rollback() // always rolls back — test data never persists
    fn(tx)
}
```

Rules:
- Never run integration tests against a shared or production schema
- Seed minimal fixture data per test — never depend on pre-existing rows
- Use a dedicated test schema with the minimum required grants

---

## Security Checklist

- [ ] Zero SQL string concatenation anywhere in the codebase
- [ ] DSN / password loaded from environment variables, never hardcoded
- [ ] Database user has least-privilege grants (only required tables and procedures)
- [ ] No credentials, tokens, or PII written to application logs
- [ ] Connection pool is bounded (prevents DB resource exhaustion under load)
- [ ] Every `QueryContext` / `ExecContext` uses a context with a deadline or timeout
- [ ] Application connects as a non-DBA, non-SYS account
