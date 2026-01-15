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
