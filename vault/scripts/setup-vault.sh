#!/bin/sh
set -e
echo "Setting up Vault..."
sleep 5
vault audit enable file file_path=/vault/logs/audit.log || true
vault secrets enable transit || true
vault write -f transit/keys/customer-data type="aes256-gcm96" deletion_allowed="false" exportable="false"
vault write -f transit/keys/financial-data type="aes256-gcm96" deletion_allowed="false" exportable="false"
vault secrets enable -version=2 -path=secret kv || true
vault policy write app-policy /vault/policies/app-policy.hcl
vault policy write dba-policy /vault/policies/dba-policy.hcl
vault auth enable approle || true
vault write auth/approle/role/xplora-app token_policies="app-policy" token_ttl="1h" token_max_ttl="4h"
echo "Role ID:"; vault read auth/approle/role/xplora-app/role-id
echo "Secret ID:"; vault write -f auth/approle/role/xplora-app/secret-id
echo "Vault setup complete!"
