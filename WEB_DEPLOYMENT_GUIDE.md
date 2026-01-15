# Railway Web Interface Deployment Guide for Xplora

This guide provides step-by-step instructions to deploy Xplora using the Railway web interface.

## Prerequisites

- Railway account (https://railway.app)
- GitHub account with the Xplora repository
- A code editor to generate secrets (or use online tools)

---

## Step 1: Create Railway Project

1. **Login to Railway**
   - Go to https://railway.app
   - Login with your GitHub account

2. **Create New Project**
   - Click "New Project" button
   - Click "Create from GitHub repo"
   - Select the `Xplora` repository from the list
   - Click "Import"

3. **Review Auto-Detection**
   - Railway should auto-detect the Next.js app in the `/portal` directory
   - If not, click "Configure" and set:
     - Root directory: `/portal`
     - Build command: `npm install && npm run build`
     - Start command: `npm start`

4. **Deploy (without database for now)**
   - Click "Deploy" to create the initial deployment
   - Wait for the build to complete (this will fail due to missing database - that's okay)

---

## Step 2: Add PostgreSQL Database

1. **Add Database Service**
   - In your project, click "New Service"
   - Select "Database"
   - Click "PostgreSQL"
   - Railway will create a PostgreSQL database

2. **Get Database URL**
   - Click on the PostgreSQL service
   - Go to the "Variables" tab
   - Copy the `DATABASE_URL` value (you'll need this later)

---

## Step 3: Configure Environment Variables

1. **Add Environment Variables to Portal Service**
   - Click on the Portal service
   - Go to the "Variables" tab
   - Click "New Variable" for each variable below:

   ```env
   # Database Connection
   DATABASE_URL=<paste the DATABASE_URL from PostgreSQL service>
   
   # Authentication Secrets (Generate these!)
   NEXTAUTH_SECRET=<generate using method below>
   NEXTAUTH_URL=<your-railway-app-url>
   
   # Session Configuration
   SESSION_TIMEOUT_MINUTES=15
   ACCESS_GRANT_DURATION_MINUTES=30
   
   # Encryption (IMPORTANT!)
   ENCRYPTION_MASTER_KEY=<generate using method below>
   
   # Production Settings
   NODE_ENV=production
   ```

2. **Generate Secrets**

   **For NEXTAUTH_SECRET:**
   - Method 1 (Terminal): `openssl rand -base64 32`
   - Method 2 (Online): https://www.random.org/strings/ (generate 32 random characters)
   - Method 3 (Node.js): Run this code:
     ```javascript
     console.log(require('crypto').randomBytes(32).toString('base64'));
     ```

   **For ENCRYPTION_MASTER_KEY:**
   - Method 1 (Terminal): `openssl rand -base64 32`
   - Method 2 (Online): https://www.random.org/strings/ (generate 32 random characters)
   - Method 3 (Node.js): Run this code:
     ```javascript
     console.log(require('crypto').randomBytes(32).toString('base64'));
     ```

3. **Get Your Railway App URL**
   - Click on the Portal service
   - Go to the "Settings" tab
   - Find "Custom Domain" or "Domain"
   - Copy the URL (e.g., `https://xplora.up.railway.app`)
   - Set this as `NEXTAUTH_URL`

---

## Step 4: Run Database Migrations

1. **Access PostgreSQL Console**
   - Click on the PostgreSQL service
   - Click "Open Console" (or "New Query")
   - This opens a SQL console in your browser

2. **Run Migrations in Order**
   
   **Migration 1 - Audit Tables:**
   ```sql
   CREATE TABLE IF NOT EXISTS audit_log (
       id SERIAL PRIMARY KEY,
       user_id INTEGER NOT NULL,
       username VARCHAR(100) NOT NULL,
       action VARCHAR(50) NOT NULL,
       table_name VARCHAR(50),
       record_id INTEGER,
       old_values JSONB,
       new_values JSONB,
       ip_address VARCHAR(45),
       user_agent TEXT,
       timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       accessed_fields TEXT[]
   );

   CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
   CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
   CREATE INDEX idx_audit_log_action ON audit_log(action);
   ```

   **Migration 2 - PCI Audit Schema:**
   ```sql
   CREATE TABLE IF NOT EXISTS pci_audit_log (
       id BIGSERIAL PRIMARY KEY,
       event_type VARCHAR(100) NOT NULL,
       user_id INTEGER NOT NULL,
       username VARCHAR(100) NOT NULL,
       account_id INTEGER,
       accessed_fields TEXT[] NOT NULL,
       access_granted_at TIMESTAMP WITH TIME ZONE,
       access_expires_at TIMESTAMP WITH TIME ZONE,
       ip_address VARCHAR(45),
       user_agent TEXT,
       request_id UUID,
       session_id VARCHAR(255),
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
   );

   CREATE INDEX idx_pci_audit_user_id ON pci_audit_log(user_id);
   CREATE INDEX idx_pci_audit_account_id ON pci_audit_log(account_id);
   CREATE INDEX idx_pci_audit_created_at ON pci_audit_log(created_at);
   CREATE INDEX idx_pci_audit_event_type ON pci_audit_log(event_type);
   ```

   **Migration 3 - Core Tables:**
   ```sql
   CREATE TABLE IF NOT EXISTS users (
       id SERIAL PRIMARY KEY,
       username VARCHAR(100) UNIQUE NOT NULL,
       password_hash VARCHAR(255) NOT NULL,
       full_name VARCHAR(200) NOT NULL,
       email VARCHAR(255) UNIQUE,
       role VARCHAR(50) NOT NULL DEFAULT 'TELLER',
       is_active BOOLEAN DEFAULT true,
       failed_login_attempts INTEGER DEFAULT 0,
       locked_until TIMESTAMP WITH TIME ZONE,
       last_login TIMESTAMP WITH TIME ZONE,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
   );

   CREATE TABLE IF NOT EXISTS accounts (
       id SERIAL PRIMARY KEY,
       account_number_encrypted TEXT NOT NULL,
       ssn_encrypted TEXT NOT NULL,
       balance_encrypted TEXT NOT NULL,
       email_encrypted TEXT,
       phone_encrypted TEXT,
       address_encrypted TEXT,
       customer_name VARCHAR(200) NOT NULL,
       account_type VARCHAR(50),
       status VARCHAR(50) DEFAULT 'ACTIVE',
       created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
   );

   CREATE TABLE IF NOT EXISTS access_requests (
       id SERIAL PRIMARY KEY,
       user_id INTEGER NOT NULL REFERENCES users(id),
       account_id INTEGER NOT NULL REFERENCES accounts(id),
       requested_fields TEXT[] NOT NULL,
       reason TEXT NOT NULL,
       status VARCHAR(50) DEFAULT 'PENDING',
       requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       reviewed_at TIMESTAMP WITH TIME ZONE,
       reviewed_by INTEGER REFERENCES users(id),
       review_reason TEXT,
       expires_at TIMESTAMP WITH TIME ZONE
   );

   CREATE TABLE IF NOT EXISTS access_grants (
       id SERIAL PRIMARY KEY,
       request_id INTEGER NOT NULL REFERENCES access_requests(id),
       user_id INTEGER NOT NULL REFERENCES users(id),
       account_id INTEGER NOT NULL REFERENCES accounts(id),
       granted_fields TEXT[] NOT NULL,
       granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
       granted_by INTEGER REFERENCES users(id)
   );

   CREATE INDEX idx_accounts_id ON accounts(id);
   CREATE INDEX idx_access_requests_user_id ON access_requests(user_id);
   CREATE INDEX idx_access_requests_account_id ON access_requests(account_id);
   CREATE INDEX idx_access_requests_status ON access_requests(status);
   CREATE INDEX idx_access_grants_user_id ON access_grants(user_id);
   CREATE INDEX idx_access_grants_account_id ON access_grants(account_id);
   CREATE INDEX idx_access_grants_expires_at ON access_grants(expires_at);
   ```

   **Migration 4 - Access Functions:**
   ```sql
   CREATE OR REPLACE FUNCTION has_active_grant(p_user_id INTEGER, p_account_id INTEGER, p_field VARCHAR) 
   RETURNS BOOLEAN AS $$
   BEGIN
       RETURN EXISTS (
           SELECT 1 FROM access_grants ag
           WHERE ag.user_id = p_user_id
           AND ag.account_id = p_account_id
           AND p_field = ANY(ag.granted_fields)
           AND ag.expires_at > CURRENT_TIMESTAMP
       );
   END;
   $$ LANGUAGE plpgsql;

   CREATE OR REPLACE FUNCTION get_active_grants(p_user_id INTEGER) 
   RETURNS TABLE(account_id INTEGER, fields TEXT[], expires_at TIMESTAMP WITH TIME ZONE) AS $$
   BEGIN
       RETURN QUERY
       SELECT ag.account_id, ag.granted_fields, ag.expires_at
       FROM access_grants ag
       WHERE ag.user_id = p_user_id
       AND ag.expires_at > CURRENT_TIMESTAMP;
   END;
   $$ LANGUAGE plpgsql;
   ```

   **Migration 5 - Password Hash Column:**
   ```sql
   ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
   ```

3. **Seed Test Data**

   ```sql
   -- Insert test users
   INSERT INTO users (username, password_hash, full_name, email, role) VALUES
   ('alice.teller', '$2b$10$rKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7', 'Alice Teller', 'alice@bank.com', 'TELLER'),
   ('carol.supervisor', '$2b$10$rKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7', 'Carol Supervisor', 'carol@bank.com', 'SUPERVISOR'),
   ('dan.manager', '$2b$10$rKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7', 'Dan Manager', 'dan@bank.com', 'MANAGER'),
   ('eve.vvip', '$2b$10$rKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7', 'Eve VVIP', 'eve@bank.com', 'VVIP'),
   ('bob.admin', '$2b$10$rKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7yQ2zLQZ9uKZyOeJ5h5Qq7', 'Bob Admin', 'bob@bank.com', 'ADMIN');

   -- Note: All passwords are "password"
   -- The hash above is a placeholder - use a real bcrypt hash in production
   
   -- For testing, you can use this method to generate a real hash:
   -- Run: node -e "console.log(require('bcrypt').hashSync('password', 10))"
   ```

4. **Verify Setup**
   ```sql
   -- Check users
   SELECT username, role, is_active FROM users;
   
   -- Check tables
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public';
   ```

---

## Step 5: Redeploy Application

1. **Trigger Deployment**
   - Go to the Portal service
   - Click "Redeploy" (top right)
   - Wait for the deployment to complete
   - The deployment should succeed now with the database configured

2. **Check Logs**
   - Click on the "Deployments" tab
   - Click on the latest deployment
   - Review the logs to ensure no errors

---

## Step 6: Verify Deployment

1. **Access Your Application**
   - Click on the Portal service
   - Click the generated URL (e.g., `https://xplora.up.railway.app`)
   - You should see the login page

2. **Test Health Endpoint**
   - Open in browser: `https://your-app-url.railway.app/api/health`
   - Should return:
     ```json
     {
       "status": "healthy",
       "checks": {
         "database": "healthy",
         "vault": "disabled"
       }
     }
     ```

3. **Login with Test Users**
   
   **Note:** The seed data uses a placeholder password hash. To generate a real hash:
   
   - Method 1 (Local Node.js):
     ```bash
     node -e "console.log(require('bcrypt').hashSync('password', 10))"
     ```
   
   - Method 2 (Online tool): Use an online bcrypt generator
     - Enter password: `password`
     - Rounds: `10`
     - Copy the resulting hash

   **Then update the users:**
   ```sql
   UPDATE users SET password_hash = '<your-generated-hash>' WHERE username = 'alice.teller';
   UPDATE users SET password_hash = '<your-generated-hash>' WHERE username = 'carol.supervisor';
   UPDATE users SET password_hash = '<your-generated-hash>' WHERE username = 'dan.manager';
   UPDATE users SET password_hash = '<your-generated-hash>' WHERE username = 'eve.vvip';
   UPDATE users SET password_hash = '<your-generated-hash>' WHERE username = 'bob.admin';
   ```

   **Test Accounts:**
   - Username: `alice.teller` / Password: `password` (TELLER - can request access)
   - Username: `carol.supervisor` / Password: `password` (SUPERVISOR - can approve requests)
   - Username: `dan.manager` / Password: `password` (MANAGER - can approve requests)
   - Username: `eve.vvip` / Password: `password` (VVIP - auto-access, can approve)
   - Username: `bob.admin` / Password: `password` (ADMIN - full access)

---

## Step 7: Test Full Workflow

1. **Test as Teller (alice.teller):**
   - Login
   - Go to Dashboard
   - Go to Accounts
   - Search for accounts (try last 4 digits)
   - Click on an account to view details
   - You should see encrypted data (masked)
   - Request access to sensitive fields

2. **Test as Supervisor (carol.supervisor):**
   - Logout and login as carol.supervisor
   - Go to Dashboard
   - You should see pending requests
   - Click on "My Requests" or "Pending Requests"
   - Approve or reject the request
   - Provide a reason

3. **Verify Access Grant:**
   - Logout and login as alice.teller again
   - Go to the account detail page
   - You should now see decrypted data
   - Check that access expires after 30 minutes

---

## Step 8: Security Checklist

Before going to production:

- [ ] Changed all default passwords
- [ ] Generated strong NEXTAUTH_SECRET
- [ ] Generated strong ENCRYPTION_MASTER_KEY
- [ ] Set NEXTAUTH_URL to correct domain
- [ ] Database is using SSL (verify in DATABASE_URL: `?sslmode=require`)
- [ ] All environment variables are set in Railway (not in code)
- [ ] Tested login functionality
- [ ] Tested encryption/decryption
- [ ] Tested access request workflow
- [ ] Tested session timeout (wait 15 minutes)
- [ ] Checked audit logs are being created

---

## Step 9: Monitor and Maintain

### Viewing Logs
- Go to Portal service → "Deployments" → Click on deployment → "Logs"
- Check for errors or warnings

### Database Monitoring
- Go to PostgreSQL service
- View metrics (CPU, memory, connections)
- Check storage usage

### Health Checks
Regularly check: `https://your-app-url.railway.app/api/health`

### Automatic Updates
- When you push to GitHub, Railway will automatically redeploy
- Monitor deployments in the "Deployments" tab

---

## Troubleshooting

### Deployment Fails
- Check build logs for errors
- Verify all dependencies are in `portal/package.json`
- Ensure Node.js version is compatible (Railway uses latest by default)

### Can't Login
- Verify NEXTAUTH_SECRET is set
- Check NEXTAUTH_URL matches actual domain
- Ensure password hash is correct in database
- Check browser console for errors

### Database Connection Error
- Verify DATABASE_URL format
- Check SSL mode: `?sslmode=require`
- Ensure PostgreSQL service is running
- Check network connectivity between services

### Encryption Errors
- Verify ENCRYPTION_MASTER_KEY is set
- Check key is base64 encoded
- Ensure key length is 32 bytes (256 bits)

### Session Timeout Issues
- Check SESSION_TIMEOUT_MINUTES is set to 15
- Verify NEXTAUTH_SECRET is correct
- Clear browser cookies and try again

---

## Getting Help

- Railway Documentation: https://docs.railway.app
- Railway Support: https://railway.app/support
- Xplora Documentation: See README.md
- Security Guidelines: See SECURITY.md

---

## Next Steps After Deployment

1. **Custom Domain** (optional)
   - Go to Portal service → Settings → Custom Domain
   - Add your own domain (e.g., xplora.yourcompany.com)
   - Configure DNS settings as shown

2. **Enable Backups**
   - Railway PostgreSQL has automatic backups
   - Verify backup retention policy in PostgreSQL settings

3. **Set Up Alerts**
   - Configure Railway alerts for:
     - Service restarts
     - High CPU/memory usage
     - Failed deployments

4. **Monitor Performance**
   - Review Railway metrics regularly
   - Set up external monitoring if needed (e.g., UptimeRobot)

5. **Regular Security Audits**
   - Review audit logs weekly
   - Rotate secrets monthly
   - Update dependencies regularly

---

**Congratulations!** Your Xplora application is now deployed on Railway and ready for use.

Remember to:
- Keep secrets secure
- Monitor logs regularly
- Update dependencies
- Test thoroughly before production use
- Follow PCI-DSS compliance guidelines
