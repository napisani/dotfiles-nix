---
name: axion-local-db-access
description: Use when Codex needs to inspect, query, troubleshoot, or validate Axion local development databases running in Docker, including tenant-scoped AlloyDB/Postgres data via psql and tenant-scoped MongoDB data via mongosh.
---

# Axion Local DB Access

## Overview

Use the local Docker databases for Axion tenant data investigation. One database exists per tenant, and the database name is the tenant name.

## Connection Info

Postgres-compatible AlloyDB:

```bash
psql "postgresql://postgres:postgres@localhost:5432/<tenant>"
```

MongoDB:

```bash
mongosh "mongodb://localhost:27017/<tenant>?directConnection=true"
```

Replace `<tenant>` with the tenant database name, for example `aisin` or another Axion tenant slug.

## Query Workflow

1. Ask for the tenant name if it is not clear from the request.
2. Use `psql` for relational/AlloyDB/Postgres questions.
3. Use `mongosh` for document/MongoDB questions.
4. Prefer read-only queries unless the user explicitly asks for a write.
5. Keep result sets small with `limit`, SQL `LIMIT`, or targeted filters.

## Command Patterns

Run one SQL statement:

```bash
psql "postgresql://postgres:postgres@localhost:5432/<tenant>" -c "select now();"
```

Run one Mongo expression:

```bash
mongosh "mongodb://localhost:27017/<tenant>?directConnection=true" --eval "db.getCollectionNames()"
```

For compact script-friendly output, use:

```bash
psql "postgresql://postgres:postgres@localhost:5432/<tenant>" -At -F $'\t' -c "<sql>"
mongosh "mongodb://localhost:27017/<tenant>?directConnection=true" --quiet --eval "<javascript>"
```

## Safety

- Do not run destructive writes, migrations, drops, deletes, or bulk updates without explicit user confirmation.
- Call out which tenant database is being queried before executing commands.
- If a connection fails, check whether Docker containers are running and whether the tenant name is correct.
