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
