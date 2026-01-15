import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from "crypto";
import {
  createVaultClientFromEnv,
  encryptWithVault,
  decryptWithVault,
  checkVaultHealth,
} from "./vault";

// PCI-DSS compliant encryption using AES-256-GCM
const ALGORITHM = "aes-256-gcm";
const SALT_LENGTH = 32;
const IV_LENGTH = 16;
const AUTH_TAG_LENGTH = 16;
const KEY_LENGTH = 32;

// Flag to determine if Vault is enabled
const VAULT_ENABLED = process.env.VAULT_ENABLED === "true";

/**
 * Get encryption key from environment variable
 * In production, this should come from HashiCorp Vault or Railway secrets
 */
function getEncryptionKey(): Buffer {
  const masterKey = process.env.ENCRYPTION_MASTER_KEY;
  
  if (!masterKey) {
    // For development only - in production, this must be set
    if (process.env.NODE_ENV === "production") {
      throw new Error("ENCRYPTION_MASTER_KEY must be set in production");
    }
    // Development fallback
    return scryptSync("development-key-change-in-production", "salt", KEY_LENGTH);
  }
  
  // Derive key using scrypt for additional security
  return scryptSync(masterKey, "xplora-encryption-salt-v1", KEY_LENGTH);
}

/**
 * Encrypt sensitive field data
 * If Vault is enabled, uses Vault Transit engine
 * Otherwise, falls back to local AES-256-GCM encryption
 * Returns base64 encoded string
 */
export async function encryptField(plaintext: string, keyName: string = "customer-data"): Promise<string> {
  if (!plaintext) return "";

  // Use Vault if enabled
  if (VAULT_ENABLED) {
    try {
      const client = await createVaultClientFromEnv();
      const isHealthy = await checkVaultHealth(client);
      
      if (isHealthy) {
        return await encryptWithVault(client, plaintext, keyName);
      } else {
        console.warn("Vault health check failed, falling back to local encryption");
      }
    } catch (error) {
      console.error("Vault encryption failed, falling back to local encryption:", error);
    }
  }

  // Fallback to local encryption
  try {
    const key = getEncryptionKey();
    const salt = randomBytes(SALT_LENGTH);
    const iv = randomBytes(IV_LENGTH);
    
    const cipher = createCipheriv(ALGORITHM, key, iv);
    
    let encrypted = cipher.update(plaintext, "utf8", "base64");
    encrypted += cipher.final("base64");
    
    const authTag = cipher.getAuthTag();
    
    // Combine salt, iv, authTag, and encrypted data
    const combined = Buffer.concat([
      salt,
      iv,
      authTag,
      Buffer.from(encrypted, "base64"),
    ]);
    
    return combined.toString("base64");
  } catch (error) {
    console.error("Encryption error:", error);
    throw new Error("Failed to encrypt sensitive data");
  }
}

/**
 * Decrypt sensitive field data
 * If Vault is enabled and data was encrypted with Vault, uses Vault Transit engine
 * Otherwise, falls back to local AES-256-GCM decryption
 */
export async function decryptField(encryptedData: string, keyName: string = "customer-data"): Promise<string> {
  if (!encryptedData) return "";

  // Check if it's a Vault ciphertext (starts with "vault:")
  if (VAULT_ENABLED && encryptedData.startsWith("vault:")) {
    try {
      const client = await createVaultClientFromEnv();
      const isHealthy = await checkVaultHealth(client);
      
      if (isHealthy) {
        return await decryptWithVault(client, encryptedData, keyName);
      } else {
        console.warn("Vault health check failed, falling back to local decryption");
      }
    } catch (error) {
      console.error("Vault decryption failed, falling back to local decryption:", error);
    }
  }

  // Fallback to local decryption
  try {
    const key = getEncryptionKey();
    const combined = Buffer.from(encryptedData, "base64");
    
    // Extract components
    const salt = combined.subarray(0, SALT_LENGTH);
    const iv = combined.subarray(SALT_LENGTH, SALT_LENGTH + IV_LENGTH);
    const authTag = combined.subarray(
      SALT_LENGTH + IV_LENGTH,
      SALT_LENGTH + IV_LENGTH + AUTH_TAG_LENGTH
    );
    const encrypted = combined.subarray(SALT_LENGTH + IV_LENGTH + AUTH_TAG_LENGTH);
    
    const decipher = createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);
    
    let decrypted = decipher.update(encrypted.toString("base64"), "base64", "utf8");
    decrypted += decipher.final("utf8");
    
    return decrypted;
  } catch (error) {
    console.error("Decryption error:", error);
    throw new Error("Failed to decrypt sensitive data");
  }
}

/**
 * Mask sensitive data for display
 * Shows only first and last few characters
 */
export function maskField(value: string, fieldType: string): string {
  if (!value) return "";
  
  switch (fieldType) {
    case "account_number":
      // Show last 4 digits only
      return `************${value.slice(-4)}`;
    
    case "ssn":
      // Format: XXX-XX-1234
      return `***-**-${value.slice(-4)}`;
    
    case "email":
      // Show first char and domain
      const [local, domain] = value.split("@");
      return `${local[0]}${"*".repeat(Math.min(local.length - 1, 8))}@${domain}`;
    
    case "phone":
      // Show last 4 digits
      return `***-***-${value.slice(-4)}`;
    
    case "balance":
      // Show masked amount
      return "$***,***.**";
    
    case "address":
      // Show only city/state
      const parts = value.split(",");
      return parts.length > 1 ? `***, ${parts[parts.length - 1].trim()}` : "***";
    
    default:
      return "***";
  }
}

/**
 * Generate encryption key for new deployment
 * Use this to generate ENCRYPTION_MASTER_KEY for production
 */
export function generateEncryptionKey(): string {
  return randomBytes(32).toString("base64");
}

/**
 * Hash sensitive data for deduplication checks
 * Uses SHA-256 for one-way hashing
 */
export function hashForDeduplication(value: string): string {
  const crypto = require("crypto");
  return crypto.createHash("sha256").update(value).digest("hex");
}
