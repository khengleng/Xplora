import { Pool } from "pg";

const connectionString =
  process.env.DATABASE_URL ?? "postgres://admin:secret@localhost:5432/xplora";

export const pool = new Pool({
  connectionString,
});

export async function query<T = unknown>(
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

