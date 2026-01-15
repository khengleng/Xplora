# Railway Deployment Guide for Xplora

This guide will help you deploy the Xplora platform to Railway.app with PCI-DSS compliance.

## Prerequisites

- Railway account (https://railway.app)
- GitHub account with the Xplora repository
- PostgreSQL database (Railway provides this)
- Railway CLI (optional, for advanced deployments)
- HashiCorp Vault (optional, for enhanced key management - see VAULT_SETUP.md)

## Step 1: Deploy PostgreSQL Database

1. Go to Railway and create a new project
2. Add a PostgreSQL service:
   - Click "+ New Service" → "Database" → "PostgreSQL"
   - Railway will provide a connection string

3. Get the database connection string:
   - Click on the PostgreSQL service
   - Go to the "Variables" tab
   - Copy `DATABASE_URL`

## Step 2: Deploy the Portal Application

1. Connect your GitHub repository:
   - Click "+ New Service" → "Deploy from GitHub repo"
   - Select the Xplora repository
   - Railway will auto-detect the Next.js app

2. Configure build settings (if needed):
   - Root directory: `/portal`
   - Build command: `npm install && npm run build`
   - Start command: `npm start`

3. Add environment variables:
   Go to the portal service → "Variables" tab and add:

   ```env
   # Database
   DATABASE_URL=postgresql://user:password@host:port/database?sslmode=require
   
   # NextAuth (REQUIRED for production)
   NEXTAUTH_SECRET=<generate-strong-random-string>
   NEXTAUTH_URL=https://your-app.railway.app
   
   # Session Configuration
   SESSION_TIMEOUT_MINUTES=15
   ACCESS_GRANT_DURATION_MINUTES=30
   
   # Security - HashiCorp Vault (Optional but Recommended)
   # Set to "true" to enable Vault for encryption
   VAULT_ENABLED=false
   
   # If VAULT_ENABLED=true, configure Vault connection:
   VAULT_ADDR=http://localhost:8200
   VAULT_ROLE_ID=<your-vault-role-id>
   VAULT_SECRET_ID=<your-vault-secret-id>
   VAULT_NAMESPACE=root
   
   # Fallback encryption key (REQUIRED if VAULT_ENABLED=false)
   ENCRYPTION_MASTER_KEY=<generate-strong-random-32-byte-key>
   
   # Production settings
   NODE_ENV=production
   ```

## Step 3: Run Database Migrations

1. Access Railway PostgreSQL service:
   - Click on PostgreSQL service
   - Click "Open Console" or use your local psql client

2. Run migrations in order:
   ```sql
   -- Copy and paste each migration file content
   \i migrations/001_audit.up.sql
   \i migrations/001_pci_audit_schema.up.sql
   \i migrations/002_core_tables.up.sql
   \i migrations/003_access_functions.up.sql
   \i migrations/004_add_password_hash.up.sql
   ```

3. Seed initial data:
   ```sql
   \i scripts/seed_with_passwords.sql
   ```

4. Verify setup:
   ```sql
   -- Check users
   SELECT username, role, is_active FROM users;
   
   -- Check accounts
   SELECT COUNT(*) FROM accounts;
   ```

## Step 4: Update Portal for Railway URLs

The application will automatically use the Railway URL if `NEXTAUTH_URL` is set correctly.

## Step 5 (Optional): Deploy HashiCorp Vault

For enhanced security and PCI-DSS compliance, deploy HashiCorp Vault:

### Option 1: Railway Vault Service

1. Add Vault service:
   - Click "+ New Service" → "Dockerfile"
   - Use image: `hashicorp/vault:latest`
   - Configure environment variables

2. Configure Vault:
   ```env
   VAULT_DEV_ROOT_TOKEN_ID=<strong-random-token>
   VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
   ```

3. Setup Vault (see VAULT_SETUP.md for detailed instructions):
   - Access Vault console via Railway
   - Run setup script or follow manual setup
   - Get Role ID and Secret ID
   - Configure Transit engine and encryption keys

4. Update Portal environment variables:
   ```env
   VAULT_ENABLED=true
   VAULT_ADDR=https://your-vault-service.railway.app
   VAULT_ROLE_ID=<role-id-from-vault>
   VAULT_SECRET_ID=<secret-id-from-vault>
   ```

### Option 2: External Vault Service

Deploy Vault externally (AWS, GCP, Azure, or self-hosted) and configure Railway to connect:

```env
VAULT_ENABLED=true
VAULT_ADDR=https://your-external-vault.example.com
VAULT_ROLE_ID=<role-id>
VAULT_SECRET_ID=<secret-id>
```

See [VAULT_SETUP.md](VAULT_SETUP.md) for complete Vault deployment guide.

## Step 6: Test the Deployment

1. Access your app: `https://your-app.railway.app`

2. Check health endpoint:
   ```bash
   curl https://your-app.railway.app/api/health
   ```
   Should return:
   ```json
   {
     "status": "healthy",
     "checks": {
       "database": "healthy",
       "vault": "healthy" or "disabled"
     }
   }
   ```

3. Test Vault integration (if enabled):
   - Login to Vault UI
   - Check audit logs: `vault audit file -f /vault/logs/audit.log`
   - Verify encryption keys exist

4. Login with test credentials:
   - `alice.teller` / `password` (TELLER)
   - `carol.supervisor` / `password` (SUPERVISOR)

5. Test the full workflow:
   - Search for accounts
   - Request access to sensitive fields
   - Approve/reject requests (as supervisor)
   - View decrypted data

## Step 7: PCI-DSS Compliance Checklist

### ✓ Data Encryption
- [ ] AES-256-GCM encryption enabled for sensitive fields
- [ ] `ENCRYPTION_MASTER_KEY` set in Railway secrets (if Vault disabled)
- [ ] OR Vault configured with Transit engine (if Vault enabled)
- [ ] SSL/TLS enabled for all connections (Railway default)

### ✓ Access Control
- [ ] Strong passwords enforced
- [ ] Account lockout after 5 failed attempts
- [ ] Session timeout configured (15 minutes)
- [ ] Role-based access control working

### ✓ Audit Logging
- [ ] All sensitive data accesses logged
- [ ] Audit log is immutable (cannot be modified)
- [ ] Logs include user, timestamp, IP, accessed fields

### ✓ Network Security
- [ ] HTTPS enforced (Railway provides this)
- [ ] Secure HTTP-only cookies (NextAuth default)
- [ ] CSRF protection enabled (NextAuth default)

### ✓ Secure Configuration
- [ ] `NODE_ENV=production` set
- [ ] Strong `NEXTAUTH_SECRET` set
- [ ] Secrets not in code or git
- [ ] Regular backups configured

### Vault Integration (Optional but Recommended)
- [ ] Vault service deployed and configured
- [ ] Transit engine enabled with encryption keys
- [ ] AppRole authentication configured
- [ ] Audit logging enabled in Vault
- [ ] Regular key rotation scheduled
- [ ] Vault health checks implemented

## Step 8: Security Hardening (Optional but Recommended)

1. Enable Railway's built-in features:
   - Automatic backups (PostgreSQL service)
   - Private networking (Railway Pro)
   - VPC isolation (Railway Pro)

2. Set up monitoring:
   - Railway provides basic monitoring
   - Consider adding error tracking (Sentry, etc.)

3. Configure database backups:
   - Railway PostgreSQL has automatic backups
   - Verify backup retention policy

4. Set up alerts:
   - Railway can send alerts for:
     - Service restarts
     - High CPU/memory usage
     - Failed deployments

## Railway-Specific Notes

### Scaling
- Free tier: Limited resources
- Paid tiers: Better performance for production
- Scale based on user count and traffic

### Costs
- PostgreSQL: $5-10/month (depends on plan)
- Portal app: $5-10/month (depends on plan)
- Total: ~$10-20/month for basic production

### Updates
- Push to GitHub triggers automatic deployments
- Railway handles rolling updates
- Zero downtime deployments possible

### Logs
- View logs in Railway dashboard
- Logs include build and runtime errors
- Download logs for offline analysis

## Troubleshooting

### Build Failures
- Check Node.js version compatibility
- Verify all dependencies are in package.json
- Review build logs in Railway dashboard

### Database Connection Issues
- Verify `DATABASE_URL` format
- Check SSL mode: `?sslmode=require`
- Ensure database service is running

### Authentication Issues
- Verify `NEXTAUTH_SECRET` is set
- Check `NEXTAUTH_URL` matches actual domain
- Review session timeout settings

### Encryption Errors
- Ensure `ENCRYPTION_MASTER_KEY` is set
- Verify key is base64 encoded
- Check key length (32 bytes = 256 bits)

### Slow Performance
- Upgrade to paid Railway plan
- Add database indexes if needed
- Enable caching (future enhancement)

## Monitoring and Maintenance

### Health Checks

Monitor your deployment with the health endpoint:

```bash
# Check overall health
curl https://your-app.railway.app/api/health

# Expected response for Vault enabled:
{
  "status": "healthy",
  "checks": {
    "timestamp": "2026-01-15T17:42:00.000Z",
    "database": "healthy",
    "vault": "healthy"
  }
}

# Expected response for Vault disabled:
{
  "status": "healthy",
  "checks": {
    "timestamp": "2026-01-15T17:42:00.000Z",
    "database": "healthy",
    "vault": "disabled"
  }
}
```

### Vault Monitoring (if enabled)

Monitor Vault health and operations:

```bash
# Check Vault status (via Railway console)
vault status

# View audit logs
tail -f /vault/logs/audit.log

# Check encryption keys
vault list transit/keys

# Monitor key usage
vault read transit/keys/customer-data
```

### Key Rotation

If using Vault, implement regular key rotation:

```bash
# Rotate encryption keys (via Railway console or cron)
vault write -f transit/keys/customer-data/rotate
vault write -f transit/keys/financial-data/rotate

# Schedule monthly rotation via Railway cron jobs
```

If using local encryption:

```bash
# Generate new key
openssl rand -base64 32

# Update ENCRYPTION_MASTER_KEY in Railway variables
# Note: You'll need to migrate existing data
```

## Production Readiness

Before going live:

1. ✓ Change all default passwords
2. ✓ Generate and set strong secrets
3. ✓ Enable database backups
4. ✓ Set up monitoring and alerts
5. ✓ Test all user flows
6. ✓ Verify PCI-DSS compliance
7. ✓ Document deployment process
8. ✓ Train staff on security procedures

## Support

- Railway Docs: https://docs.railway.app
- Xplora README.md for detailed features
- SECURITY.md for security policies

## Important Notes

⚠️ **NEVER** commit secrets to git
⚠️ **ALWAYS** use Railway variables for secrets
⚠️ **REGULARLY** rotate encryption keys
⚠️ **MONITOR** audit logs for suspicious activity
⚠️ **BACKUP** database regularly
⚠️ **TEST** thoroughly before production
