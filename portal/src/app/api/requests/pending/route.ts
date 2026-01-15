import { NextResponse } from "next/server";
import { query } from "@/lib/db";

export async function GET() {
  const { rows } = await query<{
    id: number;
    request_ref: string;
    requester: string;
    branch_code: string | null;
    account: string;
    field_name: string;
    reason: string;
    mins_waiting: number;
  }>("SELECT * FROM pending_requests_dashboard ORDER BY mins_waiting DESC LIMIT 100");

  return NextResponse.json({ data: rows });
}

