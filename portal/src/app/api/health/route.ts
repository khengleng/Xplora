import { NextResponse } from "next/server";
import { createVaultClientFromEnv, checkVaultHealth } from "@/lib/vault";
import { pool } from "@/lib/db";

export async function GET() {
  const healthChecks = {
    timestamp: new Date().toISOString(),
    database: "unknown",
    vault: "unknown",
  };

  // Check database connection
  try {
    const client = await pool.connect();
    try {
      await client.query("SELECT 1");
      healthChecks.database = "healthy";
    } finally {
      client.release();
    }
  } catch (error) {
    healthChecks.database = "unhealthy";
    console.error("Database health check failed:", error);
  }

  // Check Vault connection
  try {
    const vaultEnabled = process.env.VAULT_ENABLED === "true";
    
    if (!vaultEnabled) {
      healthChecks.vault = "disabled";
    } else {
      const client = await createVaultClientFromEnv();
      const isHealthy = await checkVaultHealth(client);
      healthChecks.vault = isHealthy ? "healthy" : "unhealthy";
    }
  } catch (error) {
    healthChecks.vault = "error";
    console.error("Vault health check failed:", error);
  }

  // Determine overall health status
  const isHealthy =
    healthChecks.database === "healthy" &&
    (healthChecks.vault === "healthy" || healthChecks.vault === "disabled");

  const statusCode = isHealthy ? 200 : 503;

  return NextResponse.json(
    {
      status: isHealthy ? "healthy" : "unhealthy",
      checks: healthChecks,
    },
    { status: statusCode }
  );
}
