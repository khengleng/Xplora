import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { requireAuth, canApprove } from "@/lib/auth";
import { logAuditEvent } from "@/lib/audit";
import type { PendingRequest } from "@/types";

export async function GET() {
  try {
    const user = await requireAuth();
    
    // Only approvers can see pending requests
    if (!canApprove(user.role)) {
      return NextResponse.json(
        { error: "Insufficient permissions" },
        { status: 403 }
      );
    }

    const { rows } = await query<PendingRequest>(
      "SELECT * FROM pending_requests_dashboard ORDER BY mins_waiting DESC LIMIT 100"
    );

    await logAuditEvent({
      user,
      eventType: "PENDING_REQUESTS_VIEW",
      eventCategory: "ACCESS_REQUEST",
      success: true,
      tableName: "field_access_requests",
      recordId: null,
      accessedFields: null,
      details: {
        resultCount: rows.length,
      },
    });

    return NextResponse.json({ requests: rows });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}

