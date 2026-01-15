import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const q = searchParams.get("q") ?? "";

  const like = `%${q.replace(/\D/g, "")}%`;

  const { rows } = await query<{
    id: number;
    account_number_last4: string;
    holder_name_search: string | null;
    created_at: string;
  }>(
    `SELECT id, account_number_last4, holder_name_search, created_at
     FROM accounts
     WHERE account_number_last4 ILIKE $1
     ORDER BY created_at DESC
     LIMIT 50`,
    [like]
  );

  return NextResponse.json({ data: rows });
}

