import { Pool, QueryResultRow } from "pg";
import type { SensitiveField } from "@/types";

const connectionString =
  process.env.DATABASE_URL ?? "postgres://admin:secret@localhost:5432/xplora";

export const pool = new Pool({
  connectionString,
});

export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<{ rows: T[] }> {
  const client = await pool.connect();
  try {
    const result = await client.query<T>(text, params);
    return { rows: result.rows };
  } finally {
    client.release();
  }
}

export async function has_active_access(
  userId: number,
  accountId: number,
  fieldName: SensitiveField
): Promise<boolean> {
  const { rows } = await query<{ has_active_access: boolean }>(
    "SELECT has_active_access($1, $2, $3::sensitive_field) as has_active_access",
    [userId, accountId, fieldName]
  );
  return rows[0]?.has_active_access ?? false;
}

