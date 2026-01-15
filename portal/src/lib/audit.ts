import { query } from "@/lib/db";
import type { SensitiveField, SessionUser } from "@/types";

type AuditParams = {
  user?: SessionUser | null;
  eventType: string;
  eventCategory: string;
  success: boolean;
  tableName?: string;
  recordId?: number | null;
  accessedFields?: SensitiveField[] | null;
  details?: unknown;
};

export async function logAuditEvent(params: AuditParams): Promise<void> {
  const {
    user,
    eventType,
    eventCategory,
    success,
    tableName,
    recordId,
    accessedFields,
    details,
  } = params;

  try {
    await query(
      `INSERT INTO pci_audit_log
         (user_id, username, event_type, event_category, success, table_name, record_id, accessed_fields, details)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb)`,
      [
        user ? Number(user.id) : null,
        user?.username ?? null,
        eventType,
        eventCategory,
        success,
        tableName ?? null,
        recordId ?? null,
        accessedFields && accessedFields.length > 0 ? accessedFields : null,
        details ? JSON.stringify(details) : null,
      ]
    );
  } catch {
    // Audit logging must never break main flows; swallow errors.
  }
}

