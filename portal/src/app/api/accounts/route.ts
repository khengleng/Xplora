import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { requireAuth } from "@/lib/auth";
import { logAuditEvent } from "@/lib/audit";
import type { Account } from "@/types";

export async function GET(request: Request) {
  try {
    const user = await requireAuth();

    const { searchParams } = new URL(request.url);
    const q = searchParams.get("q") ?? "";

    if (!q || q.length < 4) {
      return NextResponse.json({ accounts: [] });
    }

    const like = `%${q.replace(/\D/g, "")}%`;

    const { rows } = await query<Account>(
      `SELECT id, account_number_last4, account_number_hash, 
              holder_name_search, ssn_last4, email_hint, phone_last4, 
              status, created_at
       FROM accounts
       WHERE account_number_last4 ILIKE $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [like]
    );

    await logAuditEvent({
      user,
      eventType: "ACCOUNT_SEARCH",
      eventCategory: "ACCOUNT",
      success: true,
      tableName: "accounts",
      recordId: null,
      accessedFields: null,
      details: {
        query: q,
        resultCount: rows.length,
      },
    });

    return NextResponse.json({ accounts: rows });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}

