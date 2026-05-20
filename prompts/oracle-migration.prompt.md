---
description: Generate a numbered Oracle SQL migration script (Flyway/Liquibase compatible) from a schema description or diff. Produces a forward migration with rollback, audit columns, PK/FK/index conventions, and a companion test-data seed file.
---

Generate an Oracle SQL migration script following the conventions below.

## Input

Argument provided: {{ARGUMENT}}

If no argument is given, ask the user for:
- The change being made (new table, alter column, add index, etc.)
- Target schema / owner
- Whether this is Flyway (`V<n>__description.sql`) or Liquibase (`<changeset>`) format

## Migration File Rules

### Naming
- Flyway: `V<n>__<snake_case_description>.sql` (e.g. `V3__add_order_lines_table.sql`)
- Liquibase: use `<changeSet id="<n>" author="<team>">` wrapper

### Always Include
1. A header comment block:
   ```sql
   -- Migration : <description>
   -- Author    : <team>
   -- Date      : <YYYY-MM-DD>
   -- Ticket    : <JIRA-ID>
   ```
2. `SET DEFINE OFF;` at the top to prevent `&` substitution errors
3. `WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK;` to fail fast

### New Table Template
```sql
CREATE TABLE <SCHEMA>.<TABLE_NAME> (
    <TABLE_NAME>_ID  NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- domain columns here
    CREATED_AT       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    UPDATED_AT       TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CREATED_BY       VARCHAR2(100)  NOT NULL,
    CONSTRAINT <TABLE_NAME>_PK PRIMARY KEY (<TABLE_NAME>_ID)
);

-- FK indexes (Oracle does NOT auto-create these)
CREATE INDEX <TABLE_NAME>_<FK_COL>_IX ON <SCHEMA>.<TABLE_NAME>(<FK_COL>);

-- FK constraints
ALTER TABLE <SCHEMA>.<TABLE_NAME>
    ADD CONSTRAINT <TABLE_NAME>_<REF_TABLE>_FK
    FOREIGN KEY (<FK_COL>) REFERENCES <SCHEMA>.<REF_TABLE>(<REF_COL>);

-- Unique constraints
ALTER TABLE <SCHEMA>.<TABLE_NAME>
    ADD CONSTRAINT <TABLE_NAME>_<COL>_UK UNIQUE (<COL>);
```

### Column Type Mapping
| Concept | Oracle Type |
|---------|------------|
| Surrogate PK | `NUMBER GENERATED ALWAYS AS IDENTITY` |
| Short string (≤100) | `VARCHAR2(n)` |
| Long text | `CLOB` |
| Decimal money | `NUMBER(19,4)` |
| Integer counter | `NUMBER(10)` |
| Boolean flag | `NUMBER(1) CHECK (col IN (0,1))` |
| Timestamp with TZ | `TIMESTAMP WITH TIME ZONE` |
| Date only | `DATE` |

### ALTER TABLE Rules
- One logical change per `ALTER TABLE` statement
- Use `MODIFY` for existing column type/constraint changes
- Use `ADD` for new columns — always `DEFAULT … NOT NULL` or `NULL` explicitly stated

## Rollback Script
After the forward migration, generate a `-- ROLLBACK` section (or separate `U<n>__` file for Flyway undo):
```sql
-- ROLLBACK
DROP TABLE <SCHEMA>.<TABLE_NAME> CASCADE CONSTRAINTS PURGE;
```
For `ALTER` migrations, provide the inverse `ALTER` statement.

## Test Seed Data
Generate a minimal `-- SEED` block with 2–3 representative `INSERT` rows using bind-variable style comments:
```sql
-- SEED (run in test schema only, not production)
INSERT INTO <SCHEMA>.<TABLE_NAME> (col1, col2, CREATED_BY)
VALUES ('value1', 'value2', 'migration-test');
COMMIT;
```

## Output Format
Produce a single fenced SQL block with:
1. Header comment
2. `SET DEFINE OFF` + `WHENEVER SQLERROR` guard
3. Forward migration DDL
4. `ROLLBACK` section
5. `SEED` section

Flag any of these if present in the input:
- Missing NOT NULL constraint on required columns
- FK column without a matching index
- `VARCHAR2` over 4000 bytes (use `CLOB` or `VARCHAR2(n CHAR)` with AL32UTF8)
- `DATE` used where `TIMESTAMP` would be more appropriate
