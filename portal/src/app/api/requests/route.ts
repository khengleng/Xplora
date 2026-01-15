import { NextResponse } from "next/server";
import { query } from "@/lib/db";
import { requireAuth } from "@/lib/auth";
import { logAuditEvent } from "@/lib/audit";
import type { SensitiveField } from "@/types";

export async function POST(request: Request) {
  try {
    const user = await requireAuth();

    const body = await request.json();
    const { accountId, fieldName, reason, ticketReference } = body;

    if (!accountId || !fieldName || !reason) {
      return NextResponse.json(
        { error: "Missing required fields: accountId, fieldName, reason" },
        { status: 400 }
      );
    }

    const allowedFields: SensitiveField[] = [
      "account_number",
      "ssn",
      "balance",
      "email",
      "phone",
      "address",
    ];

    if (!allowedFields.includes(fieldName as SensitiveField)) {
      return NextResponse.json(
        { error: "Invalid fieldName" },
        { status: 400 }
      );
    }

    // Use the submit_field_request function from migrations
    const { rows } = await query<{
      success: boolean;
      request_id: number;
      message: string;
    }>(
      "SELECT * FROM submit_field_request($1, $2, $3::sensitive_field, $4)",
      [Number(user.id), Number(accountId), fieldName, reason]
    );

    const result = rows[0];
    if (!result?.success) {
      return NextResponse.json(
        { error: result?.message || "Failed to submit request" },
        { status: 400 }
      );
    }

    // Update ticket reference if provided
    if (ticketReference) {
      await query(
        "UPDATE field_access_requests SET ticket_reference = $1 WHERE id = $2",
        [ticketReference, result.request_id]
      );
    }

    await logAuditEvent({
      user,
      eventType: "FIELD_REQUEST_SUBMIT",
      eventCategory: "ACCESS_REQUEST",
      success: true,
      tableName: "field_access_requests",
      recordId: result.request_id,
      accessedFields: [fieldName as SensitiveField],
      details: {
        accountId,
        ticketReference: ticketReference ?? null,
      },
    });

    return NextResponse.json({
      success: true,
      requestId: result.request_id,
      message: result.message,
    });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}
