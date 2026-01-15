import { NextResponse } from "next/server";
import { query, has_active_access } from "@/lib/db";
import { requireAuth } from "@/lib/auth";
import { logAuditEvent } from "@/lib/audit";
import { decryptField } from "@/lib/crypto";
import type { Account, SensitiveField } from "@/types";

type Params = {
  params: { id: string };
};

export async function GET(request: Request, { params }: Params) {
  try {
    const user = await requireAuth();
    const accountId = Number(params.id);

    if (!accountId) {
      return NextResponse.json({ error: "Invalid account id" }, { status: 400 });
    }

    // Get account basic info
    const { rows: accountRows } = await query<Account>(
      `SELECT id, account_number_last4, account_number_hash, 
              holder_name_search, ssn_last4, email_hint, phone_last4, 
              status, created_at
       FROM accounts 
       WHERE id = $1`,
      [accountId]
    );

    if (accountRows.length === 0) {
      return NextResponse.json({ error: "Account not found" }, { status: 404 });
    }

    const account = accountRows[0];

    // Check for active access requests for each sensitive field
    const url = new URL(request.url);
    const fieldName = url.searchParams.get("field");
    let decryptedField = null;

    if (fieldName) {
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
          { error: "Invalid field parameter" },
          { status: 400 }
        );
      }

      const hasAccess = await has_active_access(
        Number(user.id),
        accountId,
        fieldName as SensitiveField
      );

      if (!hasAccess) {
        return NextResponse.json(
          {
            error: "No active access for this field",
            account: {
              ...account,
              requiresAccessRequest: true,
            },
          },
          { status: 403 }
        );
      }

      // Fetch and decrypt the sensitive field
      const { rows: fieldRows } = await query<{ encrypted_data: string }>(
        `SELECT ${fieldName}_encrypted as encrypted_data 
         FROM accounts 
         WHERE id = $1 AND ${fieldName}_encrypted IS NOT NULL`,
        [accountId]
      );

      if (fieldRows.length > 0 && fieldRows[0].encrypted_data) {
        try {
          decryptedField = await decryptField(fieldRows[0].encrypted_data);
        } catch (error) {
          console.error("Decryption error:", error);
          return NextResponse.json(
            { error: "Failed to decrypt field" },
            { status: 500 }
          );
        }
      }

      await logAuditEvent({
        user,
        eventType: "FIELD_ACCESS_VIEW",
        eventCategory: "ACCESS",
        success: true,
        tableName: "accounts",
        recordId: accountId,
        accessedFields: [fieldName as SensitiveField],
      });
    }

    return NextResponse.json({ 
      account, 
      decryptedField,
      fieldName 
    });
  } catch (error: any) {
    return NextResponse.json(
      { error: error.message || "Unauthorized" },
      { status: 401 }
    );
  }
}
