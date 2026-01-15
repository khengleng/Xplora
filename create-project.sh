#!/bin/bash
set -e

echo "🚀 Creating Xplora Project..."

# ===========================================
# Directory Structure
# ===========================================
mkdir -p migrations
mkdir -p vault/{config,policies,scripts}
mkdir -p portal/src/app/{login,dashboard/accounts,dashboard/requests/pending}
mkdir -p portal/src/app/api/{auth/\[...nextauth\],accounts/\[id\],requests/\[id\]/{approve,reject},requests/{mine,pending}}
mkdir -p portal/src/{components/{ui,layout,accounts,requests},lib,types}
mkdir -p scripts
mkdir -p config

echo "📁 Directories created"

# ===========================================
# .gitignore
# ===========================================
cat > .gitignore << 'EOF'
# Environment & Secrets
.env
.env.*
!.env.example
*.pem
*.key
*.crt
secrets/

# Database
*.sql.bak
*.dump
*.backup
data/

# Logs
*.log
logs/

# Dependencies
node_modules/
.next/
vendor/

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Build
dist/
build/
out/
EOF

# ===========================================
# .env.example
# ===========================================
cat > .env.example << 'EOF'
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/xplora?sslmode=require

# HashiCorp Vault
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=your-role-id
VAULT_SECRET_ID=your-secret-id

# NextAuth
NEXTAUTH_SECRET=generate-with-openssl-rand-base64-32
NEXTAUTH_URL=http://localhost:3000

# Session
SESSION_TIMEOUT_MINUTES=15
ACCESS_GRANT_DURATION_MINUTES=30
EOF

# ===========================================
# docker-compose.yml
# ===========================================
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: xplora-postgres
    environment:
      POSTGRES_DB: xplora
      POSTGRES_USER: xplora_admin
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-SecurePassword123!}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U xplora_admin -d xplora"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - xplora-network

  vault:
    image: hashicorp/vault:1.15
    container_name: xplora-vault
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: ${VAULT_DEV_TOKEN:-dev-root-token}
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
      VAULT_ADDR: "http://127.0.0.1:8200"
    cap_add:
      - IPC_LOCK
    volumes:
      - vault_data:/vault/data
      - ./vault/policies:/vault/policies:ro
      - ./vault/scripts:/scripts:ro
    command: server -dev
    healthcheck:
      test: ["CMD", "vault", "status"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - xplora-network

networks:
  xplora-network:
    driver: bridge

volumes:
  postgres_data:
  vault_data:
EOF

# ===========================================
# Migration 001: PCI Audit Schema
# ===========================================
cat > migrations/001_pci_audit_schema.up.sql << 'EOF'
-- PCI DSS Audit Infrastructure
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE pci_audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id BIGINT,
    username VARCHAR(100),
    employee_id VARCHAR(50),
    event_type VARCHAR(50) NOT NULL,
    event_category VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    success BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    application_name VARCHAR(100),
    table_name VARCHAR(100),
    record_id BIGINT,
    accessed_fields TEXT[],
    details JSONB DEFAULT '{}',
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_pci_audit_timestamp ON pci_audit_log(event_timestamp);
CREATE INDEX idx_pci_audit_user ON pci_audit_log(user_id);
CREATE INDEX idx_pci_audit_event_type ON pci_audit_log(event_type);

CREATE TABLE failed_access_log (
    id BIGSERIAL PRIMARY KEY,
    attempted_user VARCHAR(255),
    ip_address INET NOT NULL,
    user_agent TEXT,
    failure_reason VARCHAR(100) NOT NULL,
    attempted_resource VARCHAR(255),
    attempt_timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_failed_access_ip ON failed_access_log(ip_address, attempt_timestamp);

-- Prevent audit tampering
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'PCI DSS Violation: Audit logs cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER protect_pci_audit_log
BEFORE UPDATE OR DELETE ON pci_audit_log
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

-- Logging function
CREATE OR REPLACE FUNCTION log_pci_event(
    p_user_id BIGINT,
    p_username VARCHAR,
    p_employee_id VARCHAR,
    p_event_type VARCHAR,
    p_event_category VARCHAR,
    p_success BOOLEAN,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_table_name VARCHAR DEFAULT NULL,
    p_record_id BIGINT DEFAULT NULL,
    p_accessed_fields TEXT[] DEFAULT NULL,
    p_details JSONB DEFAULT '{}',
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO pci_audit_log (
        user_id, username, employee_id,
        event_type, event_category, success,
        ip_address, user_agent, application_name,
        table_name, record_id, accessed_fields,
        details, error_message
    ) VALUES (
        p_user_id, p_username, p_employee_id,
        p_event_type, p_event_category, p_success,
        p_ip_address, p_user_agent, current_setting('application_name', true),
        p_table_name, p_record_id, p_accessed_fields,
        p_details, p_error_message
    ) RETURNING event_id INTO v_event_id;
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
EOF

cat > migrations/001_pci_audit_schema.down.sql << 'EOF'
DROP TRIGGER IF EXISTS protect_pci_audit_log ON pci_audit_log;
DROP FUNCTION IF EXISTS prevent_audit_modification();
DROP FUNCTION IF EXISTS log_pci_event;
DROP TABLE IF EXISTS failed_access_log;
DROP TABLE IF EXISTS pci_audit_log;
EOF

# ===========================================
# Migration 002: Core Tables
# ===========================================
cat > migrations/002_core_tables.up.sql << 'EOF'
-- User roles
CREATE TYPE user_role AS ENUM ('TELLER', 'SUPERVISOR', 'MANAGER', 'COMPLIANCE', 'VVIP', 'ADMIN', 'DBA');
CREATE TYPE request_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED');
CREATE TYPE sensitive_field AS ENUM ('account_number', 'routing_number', 'ssn', 'balance', 'email', 'phone', 'address', 'date_of_birth');

-- Users table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    password_changed_at TIMESTAMPTZ DEFAULT NOW(),
    password_expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '90 days',
    full_name VARCHAR(255) NOT NULL,
    email_encrypted BYTEA,
    email_hint VARCHAR(50),
    role user_role NOT NULL DEFAULT 'TELLER',
    branch_code VARCHAR(10),
    department VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    locked_at TIMESTAMPTZ,
    locked_reason TEXT,
    failed_login_attempts INT DEFAULT 0,
    last_login_at TIMESTAMPTZ,
    last_login_ip INET,
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret_encrypted BYTEA,
    session_timeout_minutes INT DEFAULT 15,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_employee ON users(employee_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);

-- Accounts table (ALL SENSITIVE DATA ENCRYPTED)
CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    account_number_encrypted BYTEA NOT NULL,
    account_number_last4 VARCHAR(4) NOT NULL,
    account_number_hash VARCHAR(64) UNIQUE NOT NULL,
    routing_number_encrypted BYTEA NOT NULL,
    account_type VARCHAR(20) DEFAULT 'CHECKING',
    holder_name_encrypted BYTEA NOT NULL,
    holder_name_search VARCHAR(100),
    ssn_encrypted BYTEA,
    ssn_last4 VARCHAR(4),
    ssn_hash VARCHAR(64) UNIQUE,
    email_encrypted BYTEA,
    email_hint VARCHAR(50),
    email_hash VARCHAR(64),
    phone_encrypted BYTEA,
    phone_last4 VARCHAR(4),
    date_of_birth_encrypted BYTEA,
    address_encrypted BYTEA,
    address_zip VARCHAR(10),
    balance_encrypted BYTEA NOT NULL,
    currency CHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'ACTIVE',
    risk_score INT DEFAULT 0,
    card_token VARCHAR(255),
    card_last4 VARCHAR(4),
    card_brand VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    encryption_key_id VARCHAR(100) NOT NULL,
    encrypted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_accounts_last4 ON accounts(account_number_last4);
CREATE INDEX idx_accounts_hash ON accounts(account_number_hash);
CREATE INDEX idx_accounts_status ON accounts(status);

-- Field Access Requests
CREATE TABLE field_access_requests (
    id BIGSERIAL PRIMARY KEY,
    request_ref UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    requester_id BIGINT NOT NULL REFERENCES users(id),
    account_id BIGINT NOT NULL REFERENCES accounts(id),
    field_name sensitive_field NOT NULL,
    reason TEXT NOT NULL,
    ticket_reference VARCHAR(50),
    status request_status NOT NULL DEFAULT 'PENDING',
    reviewed_by BIGINT REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    access_granted_at TIMESTAMPTZ,
    access_expires_at TIMESTAMPTZ,
    access_duration_minutes INT DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_far_requester ON field_access_requests(requester_id);
CREATE INDEX idx_far_account ON field_access_requests(account_id);
CREATE INDEX idx_far_status ON field_access_requests(status);
CREATE INDEX idx_far_pending ON field_access_requests(status) WHERE status = 'PENDING';

-- Data Access Log
CREATE TABLE data_access_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    account_id BIGINT NOT NULL REFERENCES accounts(id),
    request_id BIGINT REFERENCES field_access_requests(id),
    action VARCHAR(50) NOT NULL,
    field_name sensitive_field,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_dal_user ON data_access_log(user_id);
CREATE INDEX idx_dal_account ON data_access_log(account_id);
CREATE INDEX idx_dal_created ON data_access_log(created_at);

-- User Sessions
CREATE TABLE user_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    terminated_at TIMESTAMPTZ,
    termination_reason VARCHAR(50)
);

CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_active ON user_sessions(is_active, expires_at);
EOF

cat > migrations/002_core_tables.down.sql << 'EOF'
DROP TABLE IF EXISTS user_sessions;
DROP TABLE IF EXISTS data_access_log;
DROP TABLE IF EXISTS field_access_requests;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS sensitive_field;
DROP TYPE IF EXISTS request_status;
DROP TYPE IF EXISTS user_role;
EOF

# ===========================================
# Migration 003: Access Functions
# ===========================================
cat > migrations/003_access_functions.up.sql << 'EOF'
-- Check if user has active access
CREATE OR REPLACE FUNCTION has_active_access(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'APPROVED'
          AND access_expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Get access expiry
CREATE OR REPLACE FUNCTION get_access_expiry(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS TIMESTAMPTZ AS $$
BEGIN
    RETURN (
        SELECT access_expires_at FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'APPROVED'
          AND access_expires_at > NOW()
        ORDER BY access_expires_at DESC
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Get pending request ID
CREATE OR REPLACE FUNCTION get_pending_request_id(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT id FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'PENDING'
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Get user role
CREATE OR REPLACE FUNCTION get_user_role(p_user_id BIGINT)
RETURNS user_role AS $$
DECLARE
    v_role user_role;
BEGIN
    SELECT role INTO v_role FROM users 
    WHERE id = p_user_id AND is_active = true AND is_locked = false;
    RETURN v_role;
END;
$$ LANGUAGE plpgsql STABLE;

-- Check privileged access
CREATE OR REPLACE FUNCTION has_privileged_access(p_user_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_role user_role;
BEGIN
    v_role := get_user_role(p_user_id);
    RETURN v_role IN ('VVIP', 'ADMIN', 'MANAGER');
END;
$$ LANGUAGE plpgsql STABLE;

-- Submit field request
CREATE OR REPLACE FUNCTION submit_field_request(
    p_teller_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field,
    p_reason TEXT,
    p_ticket_ref VARCHAR(50) DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, request_id BIGINT, request_ref UUID, message TEXT) AS $$
DECLARE
    v_user RECORD;
    v_new_id BIGINT;
    v_new_ref UUID;
BEGIN
    SELECT * INTO v_user FROM users WHERE id = p_teller_id AND is_active = true;
    
    IF v_user IS NULL THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'User not found or inactive';
        RETURN;
    END IF;
    
    IF v_user.role = 'DBA' THEN
        PERFORM log_pci_event(p_teller_id, v_user.username, v_user.employee_id,
            'DBA_ACCESS_DENIED', 'SECURITY', false, p_ip_address, p_user_agent,
            'accounts', p_account_id, ARRAY[p_field::TEXT], NULL, 'DBA attempted data access');
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'DBA cannot access customer data';
        RETURN;
    END IF;
    
    IF v_user.is_locked THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Account is locked';
        RETURN;
    END IF;
    
    IF v_user.role IN ('VVIP', 'ADMIN', 'MANAGER') THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'You have automatic access';
        RETURN;
    END IF;
    
    IF get_pending_request_id(p_teller_id, p_account_id, p_field) IS NOT NULL THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Pending request exists';
        RETURN;
    END IF;
    
    IF has_active_access(p_teller_id, p_account_id, p_field) THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'You have active access';
        RETURN;
    END IF;
    
    IF LENGTH(TRIM(p_reason)) < 20 THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Provide detailed reason (min 20 chars)';
        RETURN;
    END IF;
    
    INSERT INTO field_access_requests (requester_id, account_id, field_name, reason, ticket_reference)
    VALUES (p_teller_id, p_account_id, p_field, p_reason, p_ticket_ref)
    RETURNING id, field_access_requests.request_ref INTO v_new_id, v_new_ref;
    
    INSERT INTO data_access_log (user_id, account_id, request_id, action, field_name, ip_address, user_agent)
    VALUES (p_teller_id, p_account_id, v_new_id, 'REQUEST_ACCESS', p_field, p_ip_address, p_user_agent);
    
    PERFORM log_pci_event(p_teller_id, v_user.username, v_user.employee_id,
        'ACCESS_REQUEST', 'ACCESS', true, p_ip_address, p_user_agent,
        'accounts', p_account_id, ARRAY[p_field::TEXT],
        jsonb_build_object('reason', p_reason, 'ticket', p_ticket_ref));
    
    RETURN QUERY SELECT true, v_new_id, v_new_ref, 'Request submitted';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Approve request
CREATE OR REPLACE FUNCTION approve_request(
    p_request_id BIGINT,
    p_approver_id BIGINT,
    p_duration_minutes INT DEFAULT 30,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
DECLARE
    v_approver RECORD;
    v_request RECORD;
BEGIN
    SELECT * INTO v_approver FROM users WHERE id = p_approver_id AND is_active = true;
    
    IF v_approver IS NULL OR v_approver.role NOT IN ('SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN') THEN
        RETURN QUERY SELECT false, 'Not authorized to approve';
        RETURN;
    END IF;
    
    SELECT * INTO v_request FROM field_access_requests WHERE id = p_request_id;
    
    IF v_request IS NULL OR v_request.status != 'PENDING' THEN
        RETURN QUERY SELECT false, 'Request not found or not pending';
        RETURN;
    END IF;
    
    IF p_duration_minutes > 480 THEN p_duration_minutes := 480; END IF;
    
    UPDATE field_access_requests SET
        status = 'APPROVED',
        reviewed_by = p_approver_id,
        reviewed_at = NOW(),
        access_granted_at = NOW(),
        access_expires_at = NOW() + (p_duration_minutes || ' minutes')::INTERVAL,
        access_duration_minutes = p_duration_minutes,
        updated_at = NOW()
    WHERE id = p_request_id;
    
    INSERT INTO data_access_log (user_id, account_id, request_id, action, field_name, ip_address, user_agent)
    VALUES (p_approver_id, v_request.account_id, p_request_id, 'APPROVE', v_request.field_name, p_ip_address, p_user_agent);
    
    PERFORM log_pci_event(p_approver_id, v_approver.username, v_approver.employee_id,
        'ACCESS_APPROVED', 'ACCESS', true, p_ip_address, p_user_agent,
        'field_access_requests', p_request_id, ARRAY[v_request.field_name::TEXT],
        jsonb_build_object('requester_id', v_request.requester_id, 'duration', p_duration_minutes));
    
    RETURN QUERY SELECT true, 'Approved for ' || p_duration_minutes || ' minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reject request
CREATE OR REPLACE FUNCTION reject_request(
    p_request_id BIGINT,
    p_rejector_id BIGINT,
    p_reason TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
DECLARE
    v_rejector RECORD;
    v_request RECORD;
BEGIN
    SELECT * INTO v_rejector FROM users WHERE id = p_rejector_id AND is_active = true;
    
    IF v_rejector IS NULL OR v_rejector.role NOT IN ('SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN') THEN
        RETURN QUERY SELECT false, 'Not authorized to reject';
        RETURN;
    END IF;
    
    SELECT * INTO v_request FROM field_access_requests WHERE id = p_request_id;
    
    IF v_request IS NULL OR v_request.status != 'PENDING' THEN
        RETURN QUERY SELECT false, 'Request not found or not pending';
        RETURN;
    END IF;
    
    UPDATE field_access_requests SET
        status = 'REJECTED',
        reviewed_by = p_rejector_id,
        reviewed_at = NOW(),
        rejection_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_request_id;
    
    PERFORM log_pci_event(p_rejector_id, v_rejector.username, v_rejector.employee_id,
        'ACCESS_REJECTED', 'ACCESS', true, p_ip_address, p_user_agent,
        'field_access_requests', p_request_id, ARRAY[v_request.field_name::TEXT],
        jsonb_build_object('reason', p_reason));
    
    RETURN QUERY SELECT true, 'Request rejected';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Expire stale access
CREATE OR REPLACE FUNCTION expire_stale_access()
RETURNS INT AS $$
DECLARE
    expired_count INT;
BEGIN
    UPDATE field_access_requests 
    SET status = 'EXPIRED', updated_at = NOW()
    WHERE status = 'APPROVED' AND access_expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    IF expired_count > 0 THEN
        PERFORM log_pci_event(NULL, 'SYSTEM', 'SYSTEM',
            'ACCESS_EXPIRED_BATCH', 'ADMIN', true, NULL, NULL, NULL, NULL, NULL,
            jsonb_build_object('expired_count', expired_count));
    END IF;
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get my requests
CREATE OR REPLACE FUNCTION get_my_requests(p_teller_id BIGINT, p_limit INT DEFAULT 50)
RETURNS TABLE (
    request_id BIGINT, request_ref UUID, account_id BIGINT, account_preview TEXT,
    customer_name VARCHAR, field_name sensitive_field, status request_status,
    reason TEXT, rejection_reason TEXT, requested_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ, reviewer_name VARCHAR, expires_at TIMESTAMPTZ,
    minutes_remaining INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.request_ref, a.id, '****' || a.account_number_last4,
        a.holder_name_search, r.field_name, r.status, r.reason, r.rejection_reason,
        r.created_at, r.reviewed_at, rev.full_name, r.access_expires_at,
        CASE WHEN r.access_expires_at > NOW() 
             THEN GREATEST(0, EXTRACT(EPOCH FROM (r.access_expires_at - NOW()))::INT / 60)
             ELSE 0 END
    FROM field_access_requests r
    JOIN accounts a ON r.account_id = a.id
    LEFT JOIN users rev ON r.reviewed_by = rev.id
    WHERE r.requester_id = p_teller_id
    ORDER BY r.created_at DESC LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pending requests dashboard
CREATE OR REPLACE VIEW pending_requests_dashboard AS
SELECT r.id AS request_id, r.request_ref, r.created_at AS requested_at,
    u.full_name AS requester_name, u.employee_id AS requester_employee_id,
    u.branch_code AS requester_branch, u.role AS requester_role,
    a.id AS account_id, a.holder_name_search AS customer_name,
    '****' || a.account_number_last4 AS account_preview,
    r.field_name AS requested_field, r.reason, r.ticket_reference,
    r.access_duration_minutes AS requested_duration,
    ROUND(EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 60) AS minutes_waiting
FROM field_access_requests r
JOIN users u ON r.requester_id = u.id
JOIN accounts a ON r.account_id = a.id
WHERE r.status = 'PENDING'
ORDER BY r.created_at ASC;

-- Login attempt tracking
CREATE OR REPLACE FUNCTION record_login_attempt(
    p_username VARCHAR, p_success BOOLEAN, p_ip_address INET, p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (result VARCHAR, is_locked BOOLEAN, lockout_minutes_remaining INT) AS $$
DECLARE
    v_user RECORD;
    v_max_attempts INT := 6;
    v_lockout_minutes INT := 30;
BEGIN
    SELECT * INTO v_user FROM users WHERE username = p_username;
    
    IF p_success THEN
        IF v_user IS NOT NULL THEN
            UPDATE users SET failed_login_attempts = 0, last_login_at = NOW(),
                last_login_ip = p_ip_address, is_locked = false, locked_at = NULL, locked_reason = NULL
            WHERE id = v_user.id;
            PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
                'LOGIN_SUCCESS', 'AUTH', true, p_ip_address, p_user_agent);
        END IF;
        RETURN QUERY SELECT 'SUCCESS'::VARCHAR, false, 0;
        RETURN;
    END IF;
    
    IF v_user IS NOT NULL THEN
        UPDATE users SET failed_login_attempts = failed_login_attempts + 1, updated_at = NOW()
        WHERE id = v_user.id RETURNING * INTO v_user;
        
        IF v_user.failed_login_attempts >= v_max_attempts THEN
            UPDATE users SET is_locked = true, locked_at = NOW(),
                locked_reason = 'Exceeded max login attempts' WHERE id = v_user.id;
            PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
                'ACCOUNT_LOCKED', 'AUTH', false, p_ip_address, p_user_agent, NULL, NULL, NULL,
                jsonb_build_object('reason', 'Max login attempts'), 'Account locked');
            RETURN QUERY SELECT 'LOCKED'::VARCHAR, true, v_lockout_minutes;
            RETURN;
        END IF;
        
        PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
            'LOGIN_FAILED', 'AUTH', false, p_ip_address, p_user_agent, NULL, NULL, NULL,
            jsonb_build_object('attempts', v_user.failed_login_attempts));
    ELSE
        INSERT INTO failed_access_log (attempted_user, ip_address, user_agent, failure_reason)
        VALUES (p_username, p_ip_address, p_user_agent, 'UNKNOWN_USER');
    END IF;
    
    RETURN QUERY SELECT 'FAILED'::VARCHAR, false, 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
EOF

cat > migrations/003_access_functions.down.sql << 'EOF'
DROP FUNCTION IF EXISTS record_login_attempt;
DROP VIEW IF EXISTS pending_requests_dashboard;
DROP FUNCTION IF EXISTS get_my_requests;
DROP FUNCTION IF EXISTS expire_stale_access;
DROP FUNCTION IF EXISTS reject_request;
DROP FUNCTION IF EXISTS approve_request;
DROP FUNCTION IF EXISTS submit_field_request;
DROP FUNCTION IF EXISTS has_privileged_access;
DROP FUNCTION IF EXISTS get_user_role;
DROP FUNCTION IF EXISTS get_pending_request_id;
DROP FUNCTION IF EXISTS get_access_expiry;
DROP FUNCTION IF EXISTS has_active_access;
EOF

# ===========================================
# Vault Policies
# ===========================================
cat > vault/policies/app-policy.hcl << 'EOF'
path "transit/encrypt/customer-data" { capabilities = ["create", "update"] }
path "transit/decrypt/customer-data" { capabilities = ["create", "update"] }
path "transit/encrypt/financial-data" { capabilities = ["create", "update"] }
path "transit/decrypt/financial-data" { capabilities = ["create", "update"] }
path "transit/keys/customer-data" { capabilities = ["read"] }
path "transit/keys/financial-data" { capabilities = ["read"] }
path "secret/data/xplora/config" { capabilities = ["read"] }
path "auth/token/renew-self" { capabilities = ["update"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
EOF

cat > vault/policies/dba-policy.hcl << 'EOF'
# DBA has NO access to encryption
path "transit/*" { capabilities = ["deny"] }
path "secret/data/xplora/keys/*" { capabilities = ["deny"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
EOF

cat > vault/scripts/setup-vault.sh << 'EOF'
#!/bin/sh
set -e
echo "Setting up Vault..."
sleep 5
vault audit enable file file_path=/vault/logs/audit.log || true
vault secrets enable transit || true
vault write -f transit/keys/customer-data type="aes256-gcm96" deletion_allowed="false" exportable="false"
vault write -f transit/keys/financial-data type="aes256-gcm96" deletion_allowed="false" exportable="false"
vault secrets enable -version=2 -path=secret kv || true
vault policy write app-policy /vault/policies/app-policy.hcl
vault policy write dba-policy /vault/policies/dba-policy.hcl
vault auth enable approle || true
vault write auth/approle/role/xplora-app token_policies="app-policy" token_ttl="1h" token_max_ttl="4h"
echo "Role ID:"; vault read auth/approle/role/xplora-app/role-id
echo "Secret ID:"; vault write -f auth/approle/role/xplora-app/secret-id
echo "Vault setup complete!"
EOF
chmod +x vault/scripts/setup-vault.sh

# ===========================================
# Test Data Script
# ===========================================
cat > scripts/seed_test_data.sql << 'EOF'
-- Test Users
INSERT INTO users (employee_id, username, full_name, role, branch_code, is_active) VALUES
    ('EMP001', 'alice.teller', 'Alice Johnson', 'TELLER', 'NYC001', true),
    ('EMP002', 'bob.teller', 'Bob Williams', 'TELLER', 'NYC001', true),
    ('EMP003', 'carol.supervisor', 'Carol Smith', 'SUPERVISOR', 'NYC001', true),
    ('EMP004', 'dan.manager', 'Dan Brown', 'MANAGER', 'NYC001', true),
    ('EMP005', 'eve.vvip', 'Eve Davis', 'VVIP', 'HQ', true),
    ('EMP006', 'frank.dba', 'Frank Miller', 'DBA', 'IT', true)
ON CONFLICT (employee_id) DO NOTHING;

-- Test Accounts (encrypted values are placeholders - real app encrypts via Vault)
INSERT INTO accounts (
    account_number_encrypted, account_number_last4, account_number_hash,
    routing_number_encrypted, holder_name_encrypted, holder_name_search,
    ssn_encrypted, ssn_last4, email_encrypted, email_hint,
    phone_encrypted, phone_last4, balance_encrypted, encryption_key_id
) VALUES (
    'vault:v1:placeholder1', '7890', encode(digest('1234567890', 'sha256'), 'hex'),
    'vault:v1:placeholder2', 'vault:v1:placeholder3', 'John',
    'vault:v1:placeholder4', '6789', 'vault:v1:placeholder5', 'j***@email.com',
    'vault:v1:placeholder6', '4567', 'vault:v1:placeholder7', 'vault-key-v1'
), (
    'vault:v1:placeholder8', '4321', encode(digest('0987654321', 'sha256'), 'hex'),
    'vault:v1:placeholder9', 'vault:v1:placeholder10', 'Jane',
    'vault:v1:placeholder11', '4321', 'vault:v1:placeholder12', 'j***@test.com',
    'vault:v1:placeholder13', '6543', 'vault:v1:placeholder14', 'vault-key-v1'
) ON CONFLICT DO NOTHING;

SELECT 'Test data seeded successfully!' AS result;
EOF

# ===========================================
# GitHub Actions CI/CD
# ===========================================
mkdir -p .github/workflows
cat > .github/workflows/database-ci.yml << 'EOF'
name: Database CI/CD

on:
  push:
    branches: [main]
    paths: ['migrations/**', 'scripts/**']
  pull_request:
    paths: ['migrations/**', 'scripts/**']

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: xplora_test
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - name: Install migrate
        run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
          sudo mv migrate /usr/local/bin/
      - name: Run migrations
        run: migrate -path ./migrations -database "postgresql://postgres:testpass@localhost:5432/xplora_test?sslmode=disable" up
      - name: Test rollback
        run: |
          migrate -path ./migrations -database "postgresql://postgres:testpass@localhost:5432/xplora_test?sslmode=disable" down -all
          migrate -path ./migrations -database "postgresql://postgres:testpass@localhost:5432/xplora_test?sslmode=disable" up

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Install migrate
        run: |
          curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
          sudo mv migrate /usr/local/bin/
      - name: Deploy to production
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: migrate -path ./migrations -database "${DATABASE_URL}" up
EOF

echo "✅ All files created!"
echo ""
echo "📦 Committing to GitHub..."

git add -A
git commit -m "feat: Add complete Xplora database platform

- PCI DSS compliant database schema with encrypted storage
- Field-level access control with approval workflow
- HashiCorp Vault integration for key management
- DBA restriction - cannot access sensitive data
- Comprehensive audit logging
- Role-based access (Teller, Supervisor, Manager, VVIP)
- GitHub Actions CI/CD pipeline"

git push origin main

echo ""
echo "🎉 Done! Project pushed to GitHub."
echo ""
echo "Next steps:"
echo "1. Set up Railway PostgreSQL and get DATABASE_URL"
echo "2. Start Vault: docker-compose up -d vault"
echo "3. Run migrations: migrate -path ./migrations -database \"\$DATABASE_URL\" up"
echo "4. Seed test data: psql \"\$DATABASE_URL\" -f scripts/seed_test_data.sql"
