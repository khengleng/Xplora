import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { requireAuth, requireApprover } from "@/lib/auth";
import { logAuditEvent } from "@/lib/audit";

type Params = {
  params: { id: string };
};

export async function POST(request: Request, { params }: Params) {
  try {
    const user = await requireAuth();
    requireApprover(user);

    const id = Number(params.id);
    if (!id) {
      return NextResponse.json({ error: "Invalid id" }, { status: 400 });
    }

    const body = await request.json();
    const rejectionReason = body.reason || "No reason provided";

    // Update request status to REJECTED
    const { rows } = await query(
      `UPDATE field_access_requests 
       SET status = 'REJECTED', 
           reviewed_by = $1, 
           reviewed_at = NOW(), 
           rejection_reason = $2 
       WHERE id = $3 AND status = 'PENDING'
       RETURNING id`,
      [Number(user.id), rejectionReason, id]
    );

    if (rows.length === 0) {
      return NextResponse.json(
        { error: "Request not found or already processed" },
        { status: 404 }
      );
    }

    await logAuditEvent({
      user,
      eventType: "FIELD_REQUEST_REJECT",
      eventCategory: "ACCESS_REQUEST",
      success: true,
      tableName: "field_access_requests",
      recordId: id,
      accessedFields: null,
      details: {
        reason: rejectionReason,
      },
    });

    return NextResponse.json({ success: true, message: "Request rejected" });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}
