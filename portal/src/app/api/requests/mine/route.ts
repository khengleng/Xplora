import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { requireAuth } from "@/lib/auth";
import type { FieldAccessRequest } from "@/types";

export async function GET(request: Request) {
  try {
    const user = await requireAuth();

    const { rows } = await query<FieldAccessRequest>(
      `SELECT id, request_ref, requester_id, account_id, field_name, reason,
              ticket_reference, status, reviewed_by, reviewed_at, rejection_reason,
              access_expires_at, access_duration_minutes, created_at
       FROM field_access_requests
       WHERE requester_id = $1
       ORDER BY created_at DESC
       LIMIT 100`,
      [Number(user.id)]
    );

    return NextResponse.json({ requests: rows });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}
