# HashiCorp Vault Integration Guide

## Overview

This guide explains how to integrate HashiCorp Vault with the Xplora platform for secure encryption key management. Vault provides enterprise-grade key management, audit logging, and compliance features that enhance the platform's security posture.

## Table of Contents

1. [Architecture](#architecture)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Vault Setup](#vault-setup)
6. [Application Configuration](#application-configuration)
7. [Migration Guide](#migration-guide)
8. [Key Rotation](#key-rotation)
9. [Monitoring & Auditing](#monitoring--auditing)
10. [Troubleshooting](#troubleshooting)

## Architecture

### Encryption Flow

```
Application → Vault Transit Engine → AES-256-GCM Encryption → Encrypted Data
```

### Components

1. **Vault Server**: Centralized secrets and encryption key management
2. **Transit Engine**: Handles encryption/decryption operations without exposing keys
3. **AppRole Authentication**: Secure authentication method for applications
4. **Audit Logging**: Comprehensive logging of all Vault operations

### Benefits

- ✅ **Zero Knowledge Keys**: Application never sees encryption keys
- ✅ **Centralized Management**: All encryption operations controlled from Vault
- ✅ **Audit Trail**: All encryption/decryption operations logged
- ✅ **Key Rotation**: Easy key rotation without data re-encryption
- ✅ **High Availability**: Vault supports clustering for production
- ✅ **PCI-DSS Compliance**: Meets requirement 3 for key management

## Prerequisites

### Required Software

- Docker and Docker Compose (for local development)
- HashiCorp Vault 1.15+ (if running outside Docker)
- PostgreSQL (for Xplora database)
- Node.js 18+ (for Xplora application)

### Required Knowledge

- Basic understanding of Vault concepts
- Linux command line familiarity
- Docker basics (for containerized setup)

## Installation

### Option 1: Using Docker Compose (Recommended for Development)

The Xplora project includes a Docker Compose configuration for Vault.

```bash
# Start Vault container
docker-compose up -d vault

# Verify Vault is running
docker-compose ps vault
```

### Option 2: Local Vault Installation

For production or development without Docker:

```bash
# macOS
brew install vault

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Verify installation
vault version
```

## Configuration

### Docker Compose Configuration

The `docker-compose.yml` includes Vault configuration:

```yaml
vault:
  image: hashicorp/vault:latest
  ports:
    - "8200:8200"
  environment:
    VAULT_DEV_ROOT_TOKEN_ID: "dev-root-token"
    VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
  cap_add:
    - IPC_LOCK
  volumes:
    - ./vault:/vault
```

### Vault Configuration File

Create `vault/config/vault.hcl`:

```hcl
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
  cluster_address = "0.0.0.0:8201"
}

storage "file" {
  path = "/vault/data"
}

ui = true

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"

# Disable mlock for development
disable_mlock = true
```

## Vault Setup

### 1. Initialize and Unseal Vault

For development mode (unsealed by default):

```bash
# Set environment variables
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='dev-root-token'

# Verify connection
vault status
```

For production mode:

```bash
# Initialize Vault (generates unseal keys and root token)
vault operator init -key-shares=5 -key-threshold=3

# Unseal Vault (3 of 5 keys required)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### 2. Run Setup Script

The project includes an automated setup script:

```bash
# Make script executable
chmod +x vault/scripts/setup-vault.sh

# Run setup
docker exec -it xplora-vault /vault/scripts/setup-vault.sh
```

### Manual Setup Steps

If you prefer manual configuration:

```bash
# 1. Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# 2. Enable Transit secrets engine
vault secrets enable transit

# 3. Create encryption keys
vault write -f transit/keys/customer-data type="aes256-gcm96" \
  deletion_allowed="false" \
  exportable="false"

vault write -f transit/keys/financial-data type="aes256-gcm96" \
  deletion_allowed="false" \
  exportable="false"

# 4. Enable KV secrets engine (for storing app secrets)
vault secrets enable -version=2 -path=secret kv

# 5. Write policies
vault policy write app-policy /vault/policies/app-policy.hcl
vault policy write dba-policy /vault/policies/dba-policy.hcl

# 6. Enable AppRole authentication
vault auth enable approle

# 7. Create AppRole
vault write auth/approle/role/xplora-app \
  token_policies="app-policy" \
  token_ttl="1h" \
  token_max_ttl="4h"

# 8. Get Role ID and Secret ID
vault read auth/approle/role/xplora-app/role-id
vault write -f auth/approle/role/xplora-app/secret-id
```

### 3. Verify Setup

```bash
# Check Transit engine
vault list transit/keys

# Test encryption
vault write transit/encrypt/customer-data plaintext=$(echo -n "test-data" | base64)

# Test decryption
vault write transit/decrypt/customer-data ciphertext=<returned-ciphertext>
```

## Application Configuration

### Environment Variables

Update your `.env.local` or Railway environment variables:

```env
# Enable Vault for encryption
VAULT_ENABLED=true

# Vault connection
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=<your-role-id>
VAULT_SECRET_ID=<your-secret-id>
VAULT_NAMESPACE=root

# Fallback key (used if Vault is unavailable)
ENCRYPTION_MASTER_KEY=<your-fallback-key>
```

### Railway Deployment

For Railway deployment:

1. **Deploy Vault Service**
   - Add a new service in Railway
   - Use Docker image: `hashicorp/vault:latest`
   - Configure environment variables

2. **Configure Environment Variables**
   ```
   VAULT_ENABLED=true
   VAULT_ADDR=https://your-vault-service.railway.app
   VAULT_ROLE_ID=<role-id-from-vault-setup>
   VAULT_SECRET_ID=<secret-id-from-vault-setup>
   VAULT_NAMESPACE=root
   ENCRYPTION_MASTER_KEY=<fallback-key>
   ```

3. **Network Configuration**
   - Ensure Railway services can communicate
   - Use Railway's private networking for Vault

### Using Vault in Code

The integration is automatic. When `VAULT_ENABLED=true`:

```typescript
// Encryption - automatically uses Vault
import { encryptField } from '@/lib/crypto';

const encrypted = await encryptField("sensitive-data", "customer-data");
// Returns: "vault:v1:..."

// Decryption - automatically uses Vault
import { decryptField } from '@/lib/crypto';

const decrypted = await decryptField(encrypted, "customer-data");
// Returns: "sensitive-data"
```

### Fallback Behavior

If Vault is unavailable or `VAULT_ENABLED=false`:

- Application falls back to local AES-256-GCM encryption
- Uses `ENCRYPTION_MASTER_KEY` from environment
- Logs warnings but continues functioning
- Maintains PCI-DSS compliance with secure key derivation

## Migration Guide

### Migrating from Local Encryption to Vault

#### Step 1: Prepare Vault

```bash
# Setup Vault (see Vault Setup section above)
# Verify keys are created
vault list transit/keys
```

#### Step 2: Test with VAULT_ENABLED=false

```env
# Keep Vault disabled initially
VAULT_ENABLED=false
```

Test the application to ensure it works correctly.

#### Step 3: Enable Vault Gradually

```env
# Enable Vault
VAULT_ENABLED=true
```

New data will be encrypted with Vault. Existing data remains encrypted with local keys.

#### Step 4: Migrate Existing Data (Optional)

Create a migration script to re-encrypt existing data:

```typescript
// scripts/migrate-to-vault.ts
import { pool } from '@/lib/db';
import { encryptField, decryptField } from '@/lib/crypto';

async function migrateData() {
  const client = await pool.connect();
  
  try {
    const accounts = await client.query('SELECT id, account_number, ssn, email, phone, address FROM accounts');
    
    for (const account of accounts.rows) {
      const updates = [];
      
      // Decrypt with local encryption
      const accountNumber = await decryptField(account.account_number);
      const ssn = await decryptField(account.ssn);
      const email = await decryptField(account.email);
      const phone = await decryptField(account.phone);
      const address = await decryptField(account.address);
      
      // Encrypt with Vault
      const newAccountNumber = await encryptField(accountNumber, 'customer-data');
      const newSsn = await encryptField(ssn, 'customer-data');
      const newEmail = await encryptField(email, 'customer-data');
      const newPhone = await encryptField(phone, 'customer-data');
      const newAddress = await encryptField(address, 'customer-data');
      
      // Update database
      await client.query(
        `UPDATE accounts 
         SET account_number = $1, ssn = $2, email = $3, phone = $4, address = $5 
         WHERE id = $6`,
        [newAccountNumber, newSsn, newEmail, newPhone, newAddress, account.id]
      );
      
      console.log(`Migrated account ${account.id}`);
    }
    
    console.log('Migration complete');
  } finally {
    client.release();
  }
}

migrateData().catch(console.error);
```

Run the migration:

```bash
npm run migrate-to-vault
```

#### Step 5: Verify Migration

```bash
# Login to application
# Check account details
# Verify data decrypts correctly
# Check audit logs in Vault
vault audit file -f /vault/logs/audit.log
```

## Key Rotation

### Automatic Key Rotation

Vault supports key rotation without re-encrypting data:

```bash
# Rotate encryption key
vault write -f transit/keys/customer-data/rotate

# Verify new key version
vault read transit/keys/customer-data
```

Vault automatically uses the latest key version for encryption while maintaining older versions for decryption.

### Scheduled Rotation

Set up automated key rotation using cron:

```bash
# Add to crontab
crontab -e

# Rotate keys weekly on Sunday at 2 AM
0 2 * * 0 vault write -f transit/keys/customer-data/rotate
0 2 * * 0 vault write -f transit/keys/financial-data/rotate
```

### Key Version Management

```bash
# List key versions
vault read transit/keys/customer-data/versions

# Set minimum decryption version
vault write transit/keys/customer-data/config \
  min_decryption_version=1 \
  min_encryption_version=2
```

## Monitoring & Auditing

### Audit Logs

Vault provides comprehensive audit logging:

```bash
# View audit logs
tail -f /vault/logs/audit.log

# Filter for specific operations
grep "transit/encrypt" /vault/logs/audit.log
```

### Key Metrics

Monitor key usage:

```bash
# Get key metrics
vault read transit/keys/customer-data

# View configuration
vault read transit/keys/customer-data/config
```

### Application Monitoring

Add logging in your application:

```typescript
// portal/src/lib/crypto.ts
if (VAULT_ENABLED) {
  console.log(`[VAULT] Encrypting with key: ${keyName}`);
  const encrypted = await encryptWithVault(client, plaintext, keyName);
  console.log(`[VAULT] Encryption successful`);
  return encrypted;
}
```

### Health Checks

Implement Vault health checks:

```typescript
// portal/app/api/health/route.ts
import { createVaultClientFromEnv, checkVaultHealth } from '@/lib/vault';

export async function GET() {
  try {
    const client = await createVaultClientFromEnv();
    const isHealthy = await checkVaultHealth(client);
    
    return Response.json({
      vault: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    return Response.json({
      vault: 'error',
      error: error.message
    }, { status: 500 });
  }
}
```

## Troubleshooting

### Common Issues

#### Issue 1: Connection Refused

**Error**: `Error: connect ECONNREFUSED 127.0.0.1:8200`

**Solution**:
```bash
# Check if Vault is running
docker ps | grep vault

# Start Vault if not running
docker-compose up -d vault

# Verify port is accessible
curl http://localhost:8200/v1/sys/health
```

#### Issue 2: Authentication Failed

**Error**: `Failed to authenticate with Vault`

**Solution**:
```bash
# Verify AppRole is configured
vault read auth/approle/role/xplora-app/role-id

# Regenerate Secret ID
vault write -f auth/approle/role/xplora-app/secret-id

# Check policy permissions
vault policy read app-policy
```

#### Issue 3: Key Not Found

**Error**: `Vault encryption failed: key not found`

**Solution**:
```bash
# Check if key exists
vault list transit/keys

# Recreate key if missing
vault write -f transit/keys/customer-data type="aes256-gcm96"
```

#### Issue 4: Timeout Errors

**Error**: `Vault request timeout`

**Solution**:
```bash
# Check Vault performance
vault read sys/health

# Increase timeout in application
const client = vault({
  endpoint: VAULT_ADDR,
  requestTimeout: 30000, // 30 seconds
});
```

#### Issue 5: Vault Sealed

**Error**: `Vault is sealed`

**Solution**:
```bash
# For development mode
# Vault auto-unseals, restart container
docker restart xplora-vault

# For production mode
# Unseal with unseal keys
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### Debug Mode

Enable Vault debug logging:

```bash
# Add to Vault configuration
log_level="debug"

# Restart Vault
docker restart xplora-vault

# View logs
docker logs xplora-vault -f
```

### Testing Vault Connection

```bash
# Test connection
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='dev-root-token'

# Health check
vault status

# Test encryption
vault write transit/encrypt/customer-data plaintext=$(echo -n "test" | base64)

# Test decryption
vault write transit/decrypt/customer-data ciphertext=<ciphertext>
```

### Application Testing

```bash
# Start application with Vault enabled
VAULT_ENABLED=true npm run dev

# Check logs for Vault connection
# Look for: "Vault encryption/decryption successful"

# Test encryption in application
# Create test account
# View encrypted data
# Verify decryption with access grant
```

## Security Best Practices

### Production Deployment

1. **Enable TLS**
   ```hcl
   listener "tcp" {
     address = "0.0.0.0:8200"
     tls_cert_file = "/etc/vault/tls/cert.pem"
     tls_key_file = "/etc/vault/tls/key.pem"
     tls_client_ca_file = "/etc/vault/tls/ca.pem"
   }
   ```

2. **Use Production Mode**
   - Initialize with multiple unseal keys
   - Store unseal keys securely (HSM or secret manager)
   - Never use dev mode in production

3. **Implement Auto-Unseal**
   ```hcl
   seal "awskms" {
     region = "us-east-1"
     kms_key_id = "your-kms-key-id"
   }
   ```

4. **Enable Audit Logging**
   ```bash
   vault audit enable file file_path=/vault/logs/audit.log
   ```

5. **Regular Key Rotation**
   ```bash
   # Rotate keys monthly
   vault write -f transit/keys/customer-data/rotate
   ```

6. **Monitor Access**
   - Review audit logs daily
   - Set up alerts for suspicious activity
   - Monitor Vault metrics

### Access Control

1. **Principle of Least Privilege**
   - Use specific policies for each application
   - Grant only necessary permissions
   - Regularly review and revoke access

2. **Token TTL**
   ```bash
   # Set short TTL for application tokens
   vault write auth/approle/role/xplora-app token_ttl="1h" token_max_ttl="4h"
   ```

3. **Namespace Isolation**
   - Use separate namespaces for environments
   - Isolate production from development

## Additional Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Transit Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/transit)
- [AppRole Authentication](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Vault Best Practices](https://developer.hashicorp.com/vault/tutorials/best-practices)

## Support

For issues or questions:

1. Check this guide's troubleshooting section
2. Review Vault logs: `docker logs xplora-vault`
3. Check application logs: `npm run dev`
4. Consult HashiCorp Vault documentation
5. Open an issue on the Xplora repository

---

**Last Updated**: January 15, 2026
**Version**: 1.0.0
**Status**: Production Ready
