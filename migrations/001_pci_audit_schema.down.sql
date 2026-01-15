DROP TRIGGER IF EXISTS protect_pci_audit_log ON pci_audit_log;
DROP FUNCTION IF EXISTS prevent_audit_modification();
DROP FUNCTION IF EXISTS log_pci_event;
DROP TABLE IF EXISTS failed_access_log;
DROP TABLE IF EXISTS pci_audit_log;
