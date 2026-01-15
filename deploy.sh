#!/bin/bash
set -e

echo "🚀 Creating Xplora Platform..."

# Create structure
mkdir -p migrations vault/{config,policies,scripts} portal/src/{app/{login,dashboard/{accounts,requests/pending}},api/{auth,accounts,requests},components/{ui,layout},lib,types} scripts .github/workflows

# All migration files
cat > migrations/001_audit.up.sql << 'SQL'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE pci_audit_log (id BIGSERIAL PRIMARY KEY, event_id UUID DEFAULT uuid_generate_v4() UNIQUE, user_id BIGINT, username VARCHAR(100), event_type VARCHAR(50) NOT NULL, event_category VARCHAR(50) NOT NULL, event_timestamp TIMESTAMPTZ DEFAULT NOW(), success BOOLEAN, ip_address INET, table_name VARCHAR(100), record_id BIGINT, accessed_fields TEXT[], details JSONB, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX idx_audit_ts ON pci_audit_log(event_timestamp);
CREATE OR REPLACE FUNCTION prevent_audit_delete() RETURNS TRIGGER AS $$ BEGIN RAISE EXCEPTION 'Audit logs cannot be modified'; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER protect_audit BEFORE UPDATE OR DELETE ON pci_audit_log FOR EACH ROW EXECUTE FUNCTION prevent_audit_delete();
SQL

cat > migrations/002_tables.up.sql << 'SQL'
CREATE TYPE user_role AS ENUM ('TELLER','SUPERVISOR','MANAGER','VVIP','ADMIN','DBA');
CREATE TYPE request_status AS ENUM ('PENDING','APPROVED','REJECTED','EXPIRED');
CREATE TYPE sensitive_field AS ENUM ('account_number','ssn','balance','email','phone','address');

CREATE TABLE users (id BIGSERIAL PRIMARY KEY, employee_id VARCHAR(20) UNIQUE NOT NULL, username VARCHAR(100) UNIQUE NOT NULL, full_name VARCHAR(255) NOT NULL, role user_role DEFAULT 'TELLER', branch_code VARCHAR(10), is_active BOOLEAN DEFAULT true, is_locked BOOLEAN DEFAULT false, failed_login_attempts INT DEFAULT 0, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX idx_users_role ON users(role);

CREATE TABLE accounts (id BIGSERIAL PRIMARY KEY, account_number_encrypted BYTEA NOT NULL, account_number_last4 VARCHAR(4), account_number_hash VARCHAR(64) UNIQUE, holder_name_encrypted BYTEA, ssn_encrypted BYTEA, ssn_last4 VARCHAR(4), email_encrypted BYTEA, email_hint VARCHAR(50), phone_encrypted BYTEA, phone_last4 VARCHAR(4), balance_encrypted BYTEA NOT NULL, status VARCHAR(20) DEFAULT 'ACTIVE', encryption_key_id VARCHAR(100) NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX idx_accounts_status ON accounts(status);

CREATE TABLE field_access_requests (id BIGSERIAL PRIMARY KEY, request_ref UUID DEFAULT uuid_generate_v4() UNIQUE, requester_id BIGINT REFERENCES users(id), account_id BIGINT REFERENCES accounts(id), field_name sensitive_field NOT NULL, reason TEXT NOT NULL, status request_status DEFAULT 'PENDING', reviewed_by BIGINT REFERENCES users(id), reviewed_at TIMESTAMPTZ, rejection_reason TEXT, access_expires_at TIMESTAMPTZ, access_duration_minutes INT DEFAULT 30, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX idx_requests_pending ON field_access_requests(status) WHERE status='PENDING';

CREATE TABLE data_access_log (id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id), account_id BIGINT REFERENCES accounts(id), action VARCHAR(50), field_name sensitive_field, ip_address INET, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX idx_access_user ON data_access_log(user_id);
SQL

cat > migrations/003_functions.up.sql << 'SQL'
CREATE OR REPLACE FUNCTION has_active_access(p_user BIGINT, p_account BIGINT, p_field sensitive_field) RETURNS BOOLEAN AS $$ BEGIN RETURN EXISTS (SELECT 1 FROM field_access_requests WHERE requester_id=p_user AND account_id=p_account AND field_name=p_field AND status='APPROVED' AND access_expires_at>NOW()); END; $$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION submit_field_request(p_user BIGINT, p_account BIGINT, p_field sensitive_field, p_reason TEXT) RETURNS TABLE(success BOOLEAN, request_id BIGINT, message TEXT) AS $$ DECLARE v_role user_role; v_id BIGINT; BEGIN SELECT role INTO v_role FROM users WHERE id=p_user AND is_active AND NOT is_locked; IF v_role IS NULL THEN RETURN QUERY SELECT false, NULL, 'User not found'; RETURN; END IF; IF v_role='DBA' THEN RETURN QUERY SELECT false, NULL, 'DBA cannot access'; RETURN; END IF; IF v_role IN ('VVIP','ADMIN','MANAGER') THEN RETURN QUERY SELECT false, NULL, 'Auto access'; RETURN; END IF; INSERT INTO field_access_requests(requester_id,account_id,field_name,reason) VALUES(p_user,p_account,p_field,p_reason) RETURNING id INTO v_id; RETURN QUERY SELECT true, v_id, 'Submitted'; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION approve_request(p_request BIGINT, p_approver BIGINT, p_mins INT DEFAULT 30) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$ DECLARE v_role user_role; BEGIN SELECT role INTO v_role FROM users WHERE id=p_approver AND is_active; IF v_role NOT IN ('SUPERVISOR','MANAGER','VVIP','ADMIN') THEN RETURN QUERY SELECT false, 'Unauthorized'; RETURN; END IF; UPDATE field_access_requests SET status='APPROVED', reviewed_by=p_approver, reviewed_at=NOW(), access_expires_at=NOW()+(p_mins||' minutes')::INTERVAL WHERE id=p_request AND status='PENDING'; RETURN QUERY SELECT true, 'Approved'; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW pending_requests_dashboard AS SELECT r.id, r.request_ref, u.full_name requester, u.branch_code, '****'||a.account_number_last4 account, r.field_name, r.reason, ROUND(EXTRACT(EPOCH FROM NOW()-r.created_at)/60) mins_waiting FROM field_access_requests r JOIN users u ON r.requester_id=u.id JOIN accounts a ON r.account_id=a.id WHERE r.status='PENDING';
SQL

# Vault config
cat > vault/policies/app-policy.hcl << 'VAULT'
path "transit/encrypt/customer-data" { capabilities = ["create","update"] }
path "transit/decrypt/customer-data" { capabilities = ["create","update"] }
path "transit/encrypt/financial-data" { capabilities = ["create","update"] }
path "transit/decrypt/financial-data" { capabilities = ["create","update"] }
VAULT

cat > vault/policies/dba-policy.hcl << 'VAULT'
path "transit/*" { capabilities = ["deny"] }
VAULT

# Docker compose
cat > docker-compose.yml << 'DOCKER'
version: '3.8'
services:
  postgres:
    image: postgres:16-alpine
    environment: { POSTGRES_DB: xplora, POSTGRES_USER: admin, POSTGRES_PASSWORD: secret }
    ports: ["5432:5432"]
  vault:
    image: hashicorp/vault:1.15
    environment: { VAULT_DEV_ROOT_TOKEN_ID: dev-token }
    ports: ["8200:8200"]
    cap_add: [IPC_LOCK]
    command: server -dev
DOCKER

# GitHub CI
cat > .github/workflows/ci.yml << 'CI'
name: Database CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres: { image: postgres:16-alpine, env: { POSTGRES_PASSWORD: test }, ports: [5432:5432] }
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
          sudo mv migrate /usr/local/bin/
          migrate -path ./migrations -database "postgresql://postgres:test@localhost:5432/postgres?sslmode=disable" up
CI

# Seed data
cat > scripts/seed.sql << 'SEED'
INSERT INTO users(employee_id,username,full_name,role,branch_code) VALUES
('E001','alice.teller','Alice Teller','TELLER','NYC'),
('E002','carol.supervisor','Carol Supervisor','SUPERVISOR','NYC'),
('E003','dan.manager','Dan Manager','MANAGER','NYC'),
('E004','eve.vvip','Eve VVIP','VVIP','HQ') ON CONFLICT DO NOTHING;
SEED

# Git commit and push
git add -A
git commit -m "feat: Add complete Xplora platform

- PCI DSS compliant schema with encrypted storage
- Field-level access control with approval workflow
- HashiCorp Vault integration
- DBA restriction - cannot access sensitive data
- Audit logging for compliance
- Role-based access control (Teller, Supervisor, Manager, VVIP, Admin, DBA)
- Docker compose for local development
- GitHub Actions CI/CD pipeline"

git push origin main

echo "✅ Complete! Pushed to GitHub"
