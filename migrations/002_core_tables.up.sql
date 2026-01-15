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
