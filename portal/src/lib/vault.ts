import vault from "node-vault";

export interface VaultConfig {
  url: string;
  roleId: string;
  secretId: string;
  namespace?: string;
}

export interface VaultClient {
  encrypt(plaintext: string, keyName: string): Promise<string>;
  decrypt(ciphertext: string, keyName: string): Promise<string>;
  health(): Promise<boolean>;
}

/**
 * Create and authenticate with HashiCorp Vault using AppRole
 */
export async function createVaultClient(config: VaultConfig): Promise<vault.client> {
  const client = vault({
    endpoint: config.url,
    namespace: config.namespace || "root",
  });

  // Authenticate with AppRole
  try {
    const authResponse = await client.write(`auth/approle/login`, {
      role_id: config.roleId,
      secret_id: config.secretId,
    });

    if (!authResponse.auth?.client_token) {
      throw new Error("Failed to authenticate with Vault: No token received");
    }

    // Set token for subsequent requests
    client.token = authResponse.auth.client_token;

    return client;
  } catch (error) {
    console.error("Vault authentication failed:", error);
    throw new Error("Failed to authenticate with Vault");
  }
}

/**
 * Create Vault client from environment variables
 */
export async function createVaultClientFromEnv(): Promise<vault.client> {
  const config: VaultConfig = {
    url: process.env.VAULT_ADDR || "http://localhost:8200",
    roleId: process.env.VAULT_ROLE_ID || "",
    secretId: process.env.VAULT_SECRET_ID || "",
    namespace: process.env.VAULT_NAMESPACE,
  };

  if (!config.roleId || !config.secretId) {
    throw new Error("VAULT_ROLE_ID and VAULT_SECRET_ID must be set");
  }

  return createVaultClient(config);
}

/**
 * Encrypt data using Vault Transit engine
 */
export async function encryptWithVault(
  client: vault.client,
  plaintext: string,
  keyName: string = "customer-data"
): Promise<string> {
  if (!plaintext) return "";

  try {
    const result = await client.write(`transit/encrypt/${keyName}`, {
      plaintext: Buffer.from(plaintext).toString("base64"),
    });

    if (!result?.data?.ciphertext) {
      throw new Error("Vault encryption failed: No ciphertext returned");
    }

    return result.data.ciphertext;
  } catch (error) {
    console.error("Vault encryption error:", error);
    throw new Error("Failed to encrypt data with Vault");
  }
}

/**
 * Decrypt data using Vault Transit engine
 */
export async function decryptWithVault(
  client: vault.client,
  ciphertext: string,
  keyName: string = "customer-data"
): Promise<string> {
  if (!ciphertext) return "";

  try {
    const result = await client.write(`transit/decrypt/${keyName}`, {
      ciphertext: ciphertext,
    });

    if (!result?.data?.plaintext) {
      throw new Error("Vault decryption failed: No plaintext returned");
    }

    return Buffer.from(result.data.plaintext, "base64").toString("utf8");
  } catch (error) {
    console.error("Vault decryption error:", error);
    throw new Error("Failed to decrypt data with Vault");
  }
}

/**
 * Check Vault health status
 */
export async function checkVaultHealth(client: vault.client): Promise<boolean> {
  try {
    await client.health();
    return true;
  } catch (error) {
    console.error("Vault health check failed:", error);
    return false;
  }
}

/**
 * Rotate encryption key in Vault
 */
export async function rotateVaultKey(
  client: vault.client,
  keyName: string
): Promise<void> {
  try {
    await client.write(`transit/keys/${keyName}/rotate`, {});
    console.log(`Successfully rotated Vault key: ${keyName}`);
  } catch (error) {
    console.error("Vault key rotation failed:", error);
    throw new Error("Failed to rotate Vault key");
  }
}

/**
 * Get key configuration from Vault
 */
export async function getKeyConfig(
  client: vault.client,
  keyName: string
): Promise<any> {
  try {
    const result = await client.read(`transit/keys/${keyName}`);
    return result?.data;
  } catch (error) {
    console.error("Failed to get Vault key config:", error);
    throw new Error("Failed to retrieve Vault key configuration");
  }
}

/**
 * Revoke all access tokens for a role
 */
export async function revokeVaultTokens(client: vault.client): Promise<void> {
  try {
    await client.write("auth/token/revoke-self", {});
    console.log("Successfully revoked Vault tokens");
  } catch (error) {
    console.error("Failed to revoke Vault tokens:", error);
    throw new Error("Failed to revoke Vault tokens");
  }
}

/**
 * Get Vault metrics (audit log information)
 */
export async function getVaultMetrics(client: vault.client): Promise<any> {
  try {
    const result = await client.write("sys/metrics", {});
    return result?.data;
  } catch (error) {
    console.error("Failed to get Vault metrics:", error);
    return null;
  }
}
