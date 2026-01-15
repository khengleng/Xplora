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
