# 📦 Database Migration Guide

Complete guide for migrating all data from your current PostgreSQL database to a new database.

## 🎯 Overview

This guide covers multiple methods to migrate your PPH database:
1. **pg_dump/pg_restore** (Recommended - Full backup/restore)
2. **Docker volume copy** (For Docker setups)
3. **SQL dump** (Simple text-based backup)
4. **Alembic migrations** (Schema only, then data copy)

---

## 📋 Prerequisites

- PostgreSQL client tools installed (`pg_dump`, `pg_restore`, `psql`)
- Access to both source and destination databases
- Docker (if using Docker setup)

---

## 🚀 Method 1: pg_dump + pg_restore (Recommended)

### Step 1: Create a Backup from Current Database

**Option A: Using Docker (if database is in Docker)**

```bash
# Create backup directory
mkdir -p backups

# Dump the database (custom format - recommended)
docker exec pph-postgres pg_dump -U pph_user -F c -b -v -f /tmp/pph_backup.dump pph_db

# Copy backup file from container to host
docker cp pph-postgres:/tmp/pph_backup.dump ./backups/pph_backup_$(date +%Y%m%d_%H%M%S).dump
```

**Option B: Direct Connection (if database is accessible directly)**

```bash
# Create backup directory
mkdir -p backups

# Dump the database (custom format)
pg_dump -h localhost -U pph_user -d pph_db -F c -b -v -f ./backups/pph_backup_$(date +%Y%m%d_%H%M%S).dump

# You'll be prompted for password: pph123
```

**Option C: Using Connection String**

```bash
# Using DATABASE_URL environment variable
pg_dump "postgresql://pph_user:pph123@localhost:5432/pph_db" \
  -F c -b -v \
  -f ./backups/pph_backup_$(date +%Y%m%d_%H%M%S).dump
```

### Step 2: Set Up New Database

**Option A: New Docker Container**

```bash
# Update docker-compose.yml with new database name
# Or create a new docker-compose file for new database

# Start new database container
docker-compose -f infra/docker-compose-new.yml up -d

# Or manually create new database
docker exec -it pph-postgres-new psql -U pph_user -c "CREATE DATABASE pph_db_new;"
```

**Option B: Different Server/Instance**

```bash
# Create new database on new server
psql -h new-server-host -U pph_user -c "CREATE DATABASE pph_db_new;"
```

### Step 3: Restore to New Database

**Option A: Using Docker**

```bash
# Copy backup file to new container
docker cp ./backups/pph_backup_YYYYMMDD_HHMMSS.dump pph-postgres-new:/tmp/pph_backup.dump

# Restore the database
docker exec pph-postgres-new pg_restore -U pph_user -d pph_db_new -v /tmp/pph_backup.dump

# Clean up
docker exec pph-postgres-new rm /tmp/pph_backup.dump
```

**Option B: Direct Connection**

```bash
# Restore to new database
pg_restore -h localhost -U pph_user -d pph_db_new -v ./backups/pph_backup_YYYYMMDD_HHMMSS.dump

# You'll be prompted for password
```

**Option C: Using Connection String**

```bash
pg_restore "postgresql://pph_user:pph123@localhost:5432/pph_db_new" \
  -v \
  ./backups/pph_backup_YYYYMMDD_HHMMSS.dump
```

### Step 4: Verify Migration

```bash
# Connect to new database and check
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "\dt"

# Check row counts
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "SELECT COUNT(*) FROM users;"
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "SELECT COUNT(*) FROM prayers;"
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "SELECT COUNT(*) FROM events;"
```

---

## 🔄 Method 2: SQL Dump (Plain Text)

### Step 1: Create SQL Dump

```bash
# Create SQL text dump
docker exec pph-postgres pg_dump -U pph_user -F p -f /tmp/pph_backup.sql pph_db

# Copy to host
docker cp pph-postgres:/tmp/pph_backup.sql ./backups/pph_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Step 2: Restore SQL Dump

```bash
# Copy to new container
docker cp ./backups/pph_backup_YYYYMMDD_HHMMSS.sql pph-postgres-new:/tmp/pph_backup.sql

# Restore
docker exec -i pph-postgres-new psql -U pph_user -d pph_db_new < /tmp/pph_backup.sql

# Or using psql directly
psql -h localhost -U pph_user -d pph_db_new < ./backups/pph_backup_YYYYMMDD_HHMMSS.sql
```

**Note:** SQL dumps are larger but human-readable. Custom format (Method 1) is faster and more efficient.

---

## 🐳 Method 3: Docker Volume Copy (For Same Server)

If both databases are on the same Docker host:

```bash
# Stop the old container (optional, for safety)
docker stop pph-postgres

# Create new container with new volume
docker-compose -f infra/docker-compose-new.yml up -d

# Copy volume data (Linux/Mac)
docker run --rm -v pph_pgdata:/source -v pph_pgdata_new:/dest \
  alpine sh -c "cd /source && cp -av . /dest"

# For Windows, use a different approach or backup/restore method
```

---

## 📊 Method 4: Schema + Data Migration (Step-by-Step)

### Step 1: Export Schema Only

```bash
# Export schema (no data)
docker exec pph-postgres pg_dump -U pph_user -F c -s -f /tmp/pph_schema.dump pph_db
docker cp pph-postgres:/tmp/pph_schema.dump ./backups/pph_schema.dump
```

### Step 2: Export Data Only

```bash
# Export data (no schema)
docker exec pph-postgres pg_dump -U pph_user -F c -a -f /tmp/pph_data.dump pph_db
docker cp pph-postgres:/tmp/pph_data.dump ./backups/pph_data.dump
```

### Step 3: Restore Schema to New Database

```bash
# First, run Alembic migrations to create schema
cd backend
alembic upgrade head

# Or restore schema dump
docker cp ./backups/pph_schema.dump pph-postgres-new:/tmp/pph_schema.dump
docker exec pph-postgres-new pg_restore -U pph_user -d pph_db_new -v /tmp/pph_schema.dump
```

### Step 4: Restore Data

```bash
# Restore data
docker cp ./backups/pph_data.dump pph-postgres-new:/tmp/pph_data.dump
docker exec pph-postgres-new pg_restore -U pph_user -d pph_db_new -v /tmp/pph_data.dump
```

---

## 🔧 Method 5: Using Alembic + Data Export

### Step 1: Export Data as CSV/JSON

```python
# Create a script: backend/scripts/export_data.py
from app.database import SessionLocal
from app.models import User, Prayer, EventSeries, PrayerRequest
import json
import csv

db = SessionLocal()

# Export users
users = db.query(User).all()
with open('users.json', 'w') as f:
    json.dump([u.__dict__ for u in users], f, default=str)

# Repeat for other tables...
```

### Step 2: Create Schema in New Database

```bash
cd backend
# Update DATABASE_URL in .env to point to new database
alembic upgrade head
```

### Step 3: Import Data

```python
# Create a script: backend/scripts/import_data.py
# Import the exported data
```

---

## ⚙️ Update Application Configuration

After migration, update your application to use the new database:

### Update `.env` file:

```env
# Old database
# DATABASE_URL=postgresql://pph_user:pph123@localhost:5432/pph_db

# New database
DATABASE_URL=postgresql://pph_user:pph123@localhost:5432/pph_db_new
```

### Update `docker-compose.yml` (if using Docker):

```yaml
environment:
  POSTGRES_DB: pph_db_new  # Changed from pph_db
```

### Update `alembic.ini`:

```ini
sqlalchemy.url = postgresql://pph_user:pph123@localhost:5432/pph_db_new
```

---

## ✅ Verification Checklist

After migration, verify:

- [ ] All tables exist: `\dt` in psql
- [ ] Row counts match: Compare `SELECT COUNT(*)` for each table
- [ ] Foreign keys intact: Check relationships
- [ ] Sequences updated: `SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));`
- [ ] Indexes created: `\di` in psql
- [ ] Application connects: Test API endpoints
- [ ] Data integrity: Spot check a few records

---

## 🚨 Common Issues & Solutions

### Issue 1: Permission Denied

```bash
# Solution: Ensure user has proper permissions
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "GRANT ALL PRIVILEGES ON DATABASE pph_db_new TO pph_user;"
```

### Issue 2: Sequence Not Updated

```bash
# Fix sequences after data import
docker exec -it pph-postgres-new psql -U pph_user -d pph_db_new -c "
SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));
SELECT setval('prayers_id_seq', (SELECT MAX(id) FROM prayers));
-- Repeat for all tables with sequences
"
```

### Issue 3: Foreign Key Violations

```bash
# Disable foreign key checks during import (if needed)
# Then re-enable and verify
```

### Issue 4: Large Database Timeout

```bash
# Increase timeout for large databases
pg_dump -h localhost -U pph_user -d pph_db --no-password \
  -F c -b -v \
  --lock-wait-timeout=300 \
  -f ./backups/pph_backup.dump
```

---

## 📝 Quick Reference Commands

### Backup
```bash
# Custom format (recommended)
pg_dump -U pph_user -d pph_db -F c -b -v -f backup.dump

# SQL format
pg_dump -U pph_user -d pph_db -F p -f backup.sql

# Schema only
pg_dump -U pph_user -d pph_db -F c -s -f schema.dump

# Data only
pg_dump -U pph_user -d pph_db -F c -a -f data.dump
```

### Restore
```bash
# Custom format
pg_restore -U pph_user -d pph_db_new -v backup.dump

# SQL format
psql -U pph_user -d pph_db_new < backup.sql
```

### Docker Commands
```bash
# Execute command in container
docker exec pph-postgres psql -U pph_user -d pph_db -c "SELECT COUNT(*) FROM users;"

# Copy file to container
docker cp backup.dump pph-postgres:/tmp/backup.dump

# Copy file from container
docker cp pph-postgres:/tmp/backup.dump ./backup.dump
```

---

## 🎯 Recommended Workflow

1. **Create backup** using Method 1 (pg_dump custom format)
2. **Test restore** on a test database first
3. **Verify data** integrity
4. **Update configuration** to point to new database
5. **Run Alembic migrations** (if schema changed)
6. **Test application** thoroughly
7. **Keep old database** as backup for a few days

---

## 📚 Additional Resources

- [PostgreSQL Backup Documentation](https://www.postgresql.org/docs/current/backup.html)
- [pg_dump Manual](https://www.postgresql.org/docs/current/app-pgdump.html)
- [pg_restore Manual](https://www.postgresql.org/docs/current/app-pgrestore.html)

---

**Last Updated:** 2026-01-20
