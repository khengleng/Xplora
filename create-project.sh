#!/bin/bash
set -e
mkdir -p migrations vault/{policies,scripts} scripts .github/workflows

cat > .gitignore << 'EOF'
.env
.env.*
!.env.example
node_modules/
.next/
*.log
.DS_Store
EOF

cat > migrations/001_pci_audit.up.sql << 'EOF'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE pci_audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id BIGINT, username VARCHAR(100), employee_id VARCHAR(50),
    event_type VARCHAR(50) NOT NULL, event_category VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    success BOOLEAN NOT NULL, ip_address INET, user_agent TEXT,
    table_name VARCHAR(100), record_id BIGINT, accessed_fields TEXT[],
    details JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_ts ON pci_audit_log(event_timestamp);
CREATE OR REPLACE FUNCTION prevent_audit_delete() RETURNS TRIGGER AS $$
BEGIN RAISE EXCEPTION 'Audit logs cannot be modified'; END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER protect_audit BEFORE UPDATE OR DELETE ON pci_audit_log
FOR EACH ROW EXECUTE FUNCTION prevent_audit_delete();
EOF

cat > migrations/002_core_tables.up.sql << 'EOF'
CREATE TYPE user_role AS ENUM ('TELLER','SUPERVISOR','MANAGER','VVIP','ADMIN','DBA');
CREATE TYPE request_status AS ENUM ('PENDING','APPROVED','REJECTED','EXPIRED');
CREATE TYPE sensitive_field AS ENUM ('account_number','ssn','balance','email','phone','address');

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    employee_id VARCHAR(20) UNIQUE NOT NULL, username VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL, role user_role DEFAULT 'TELLER',
    branch_code VARCHAR(10), is_active BOOLEAN DEFAULT true, is_locked BOOLEAN DEFAULT false,
    failed_login_attempts INT DEFAULT 0, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    account_number_encrypted BYTEA NOT NULL, account_number_last4 VARCHAR(4) NOT NULL,
    account_number_hash VARCHAR(64) UNIQUE NOT NULL,
    holder_name_encrypted BYTEA NOT NULL, holder_name_search VARCHAR(100),
    ssn_encrypted BYTEA, ssn_last4 VARCHAR(4),
    email_encrypted BYTEA, email_hint VARCHAR(50),
    phone_encrypted BYTEA, phone_last4 VARCHAR(4),
    balance_encrypted BYTEA NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE', encryption_key_id VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE field_access_requests (
    id BIGSERIAL PRIMARY KEY, request_ref UUID DEFAULT uuid_generate_v4() UNIQUE,
    requester_id BIGINT REFERENCES users(id), account_id BIGINT REFERENCES accounts(id),
    field_name sensitive_field NOT NULL, reason TEXT NOT NULL, ticket_reference VARCHAR(50),
    status request_status DEFAULT 'PENDING',
    reviewed_by BIGINT REFERENCES users(id), reviewed_at TIMESTAMPTZ, rejection_reason TEXT,
    access_expires_at TIMESTAMPTZ, access_duration_minutes INT DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_requests_pending ON field_access_requests(status) WHERE status='PENDING';
EOF

cat > migrations/003_functions.up.sql << 'EOF'
CREATE OR REPLACE FUNCTION has_active_access(p_user BIGINT, p_account BIGINT, p_field sensitive_field)
RETURNS BOOLEAN AS $$
BEGIN RETURN EXISTS (SELECT 1 FROM field_access_requests WHERE requester_id=p_user
AND account_id=p_account AND field_name=p_field AND status='APPROVED' AND access_expires_at>NOW()); END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION submit_field_request(p_user BIGINT, p_account BIGINT, p_field sensitive_field, p_reason TEXT, p_ticket VARCHAR DEFAULT NULL)
RETURNS TABLE(success BOOLEAN, request_id BIGINT, message TEXT) AS $$
DECLARE v_role user_role; v_id BIGINT;
BEGIN
  SELECT role INTO v_role FROM users WHERE id=p_user AND is_active AND NOT is_locked;
  IF v_role IS NULL THEN RETURN QUERY SELECT false,NULL::BIGINT,'User not found'; RETURN; END IF;
  IF v_role='DBA' THEN RETURN QUERY SELECT false,NULL::BIGINT,'DBA cannot access data'; RETURN; END IF;
  IF v_role IN ('VVIP','ADMIN','MANAGER') THEN RETURN QUERY SELECT false,NULL::BIGINT,'You have auto access'; RETURN; END IF;
  IF LENGTH(TRIM(p_reason))<20 THEN RETURN QUERY SELECT false,NULL::BIGINT,'Need 20+ char reason'; RETURN; END IF;
  INSERT INTO field_access_requests(requester_id,account_id,field_name,reason,ticket_reference)
  VALUES(p_user,p_account,p_field,p_reason,p_ticket) RETURNING id INTO v_id;
  RETURN QUERY SELECT true,v_id,'Request submitted';
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION approve_request(p_request BIGINT, p_approver BIGINT, p_mins INT DEFAULT 30)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE v_role user_role;
BEGIN
  SELECT role INTO v_role FROM users WHERE id=p_approver AND is_active;
  IF v_role NOT IN ('SUPERVISOR','MANAGER','VVIP','ADMIN') THEN RETURN QUERY SELECT false,'Not authorized'; RETURN; END IF;
  UPDATE field_access_requests SET status='APPROVED',reviewed_by=p_approver,reviewed_at=NOW(),
    access_expires_at=NOW()+(p_mins||' minutes')::INTERVAL WHERE id=p_request AND status='PENDING';
  RETURN QUERY SELECT true,'Approved for '||p_mins||' min';
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW pending_requests_dashboard AS
SELECT r.id,r.request_ref,u.full_name requester,u.branch_code,'****'||a.account_number_last4 account,
  r.field_name,r.reason,r.ticket_reference,ROUND(EXTRACT(EPOCH FROM NOW()-r.created_at)/60) mins_waiting
FROM field_access_requests r JOIN users u ON r.requester_id=u.id JOIN accounts a ON r.account_id=a.id
WHERE r.status='PENDING' ORDER BY r.created_at;
EOF

cat > vault/policies/app-policy.hcl << 'EOF'
path "transit/encrypt/customer-data" { capabilities = ["create","update"] }
path "transit/decrypt/customer-data" { capabilities = ["create","update"] }
path "transit/encrypt/financial-data" { capabilities = ["create","update"] }
path "transit/decrypt/financial-data" { capabilities = ["create","update"] }
EOF

cat > vault/policies/dba-policy.hcl << 'EOF'
path "transit/*" { capabilities = ["deny"] }
EOF

cat > scripts/seed.sql << 'EOF'
INSERT INTO users(employee_id,username,full_name,role,branch_code) VALUES
('E001','alice.teller','Alice Teller','TELLER','NYC'),
('E002','carol.super','Carol Supervisor','SUPERVISOR','NYC'),
('E003','dan.manager','Dan Manager','MANAGER','NYC') ON CONFLICT DO NOTHING;
EOF

cat > docker-compose.yml << 'EOF'
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
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres: { image: 'postgres:16-alpine', env: { POSTGRES_PASSWORD: test }, ports: ['5432:5432'] }
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
          sudo mv migrate /usr/local/bin/
          migrate -path ./migrations -database "postgresql://postgres:test@localhost:5432/postgres?sslmode=disable" up
EOF

git add -A
git commit -m "feat: Add PCI DSS compliant database with field-level access control

- Encrypted data storage (DBA cannot see sensitive data)
- Field-level access requests with approval workflow
- Vault integration for encryption keys
- Audit logging for compliance
- Role-based access control"
git push origin main
echo "✅ Pushed to GitHub!"
