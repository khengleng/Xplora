import { NextResponse } from "next/server";
import { query } from "@/lib/db";

type Params = {
  params: { id: string };
};

export async function POST(_: Request, { params }: Params) {
  const id = Number(params.id);
  if (!id) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  // TODO: wire to authenticated approver id from session
  const approverId = 2; // e.g. carol.supervisor in seed

  const { rows } = await query<{ success: boolean; message: string }>(
    "SELECT * FROM approve_request($1, $2)",
    [id, approverId]
  );

  const result = rows[0];
  if (!result?.success) {
    return NextResponse.json({ error: result?.message ?? "Failed" }, { status: 400 });
  }

  return NextResponse.json({ success: true, message: result.message });
}

