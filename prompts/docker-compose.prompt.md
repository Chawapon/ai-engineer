---
description: "Generate a docker-compose.yaml for local development. Use when you want to run services locally with health checks, environment variables, and dependent service ordering."
name: "Docker Compose"
argument-hint: "Name of the service or describe what to compose (e.g. 'ai-engineer with postgres')"
agent: "agent"
tools: ["codebase"]
---

Generate a `compose.yaml` for local development of the service described in the argument.

## Rules

- Use `compose.yaml` (not the legacy `docker-compose.yml`)
- Always wire the service's `/health` endpoint as a `healthcheck:` so dependent services use `condition: service_healthy`
- Never hardcode secrets — use `environment:` with `${VAR:-default}` and document required vars in a comment block at the top
- Pin image tags — not `latest`
- Set `restart: unless-stopped` for long-running services
- Add a named `network:` block; avoid default bridge networking
- Use `volumes:` with named volumes for persistent data, not bind mounts to host paths (except for local dev source overrides)

## Template

```yaml
# Required environment variables (copy to .env and fill in):
# ADDR=:8080

name: ai-engineer

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    image: ai-engineer:dev
    ports:
      - "8080:8080"
    environment:
      ADDR: "${ADDR:-:8080}"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      start_period: 5s
      retries: 3
    restart: unless-stopped
    networks:
      - backend

networks:
  backend:
    driver: bridge
```

## Adding a Dependent Service (e.g. Postgres)

```yaml
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: "${POSTGRES_DB:-appdb}"
      POSTGRES_USER: "${POSTGRES_USER:-app}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  api:
    depends_on:
      db:
        condition: service_healthy   # waits for db healthcheck to pass
    ...

volumes:
  db-data:
```

## Checklist

- [ ] `compose.yaml` created at project root
- [ ] `.env.example` created documenting all `${VAR}` references
- [ ] `healthcheck:` present on every service
- [ ] No secrets hardcoded
- [ ] Image tags pinned
- [ ] Named network declared

---

Search the codebase for: the exposed port (check `main.go`), any existing `Dockerfile`, and any datasource connection strings to determine if dependent services are needed. Then generate the complete `compose.yaml` and `.env.example`.
