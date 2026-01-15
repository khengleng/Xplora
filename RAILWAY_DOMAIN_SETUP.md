# Railway Domain Setup Guide for Xplora

## Prerequisites

1. **Fix GitHub Push Permissions**
   - The nixpacks.toml file has been committed locally but cannot be pushed to GitHub
   - Error: "Permission to khengleng/Xplora.git denied to khengleng855"
   
   **Solutions (choose one):**
   
   Option A: Add Collaborator
   - Go to https://github.com/khengleng/Xplora/settings/access
   - Add "khengleng855" as a collaborator with write access
   - Retry the push: `git push origin main`
   
   Option B: Switch to Correct Account
   ```bash
   gh auth logout
   gh auth login
   # Select "khengleng" account (not khengleng855)
   git push origin main
   ```

## Railway Deployment Steps

### 1. Push Code to GitHub
Once permissions are fixed:
```bash
git push origin main
```

### 2. Configure Railway Project

#### Create Project
1. Go to https://railway.app
2. Click "New Project" → "Deploy from GitHub repo"
3. Select `khengleng/Xplora` repository
4. Railway will automatically detect `nixpacks.toml` and `railway.json`

#### Verify Build Settings
Railway will use these settings from `nixpacks.toml`:
- **Builder**: Nixpacks
- **Node.js Version**: 22
- **Build Command**: `cd portal && npm install && npm run build`
- **Start Command**: `cd portal && npm start`
- **Environment**: Production

### 3. Configure Environment Variables

Add these variables in Railway Dashboard → Settings → Variables:

```bash
# Database Configuration
DATABASE_URL=postgresql://user:password@host:port/dbname

# NextAuth Configuration
NEXTAUTH_URL=https://www.cambobia.com
NEXTAUTH_SECRET=<generate-secret>

# Vault Configuration
VAULT_ADDR=<your-vault-url>
VAULT_TOKEN=<your-vault-token>
VAULT_NAMESPACE=<your-vault-namespace>

# Application Configuration
NODE_ENV=production
```

**Generate NEXTAUTH_SECRET:**
```bash
openssl rand -base64 32
```

### 4. Domain Configuration (www.cambobia.com)

#### Add Custom Domain
1. Go to Railway Project → Settings → Domains
2. Click "Add Domain"
3. Enter: `www.cambodia.com`
4. Click "Add Domain"

#### DNS Configuration

You'll need to add these DNS records with your domain registrar:

**Option A: CNAME Record (Recommended)**
```
Type: CNAME
Name: www
Value: [Your Railway provided domain]
TTL: 3600
```

**Option B: A Record (if needed)**
```
Type: A
Name: www
Value: [Railway provided IP address]
TTL: 3600
```

#### Update Next.js Configuration

Add `www.cambodia.com` to `portal/next.config.mjs`:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    NEXTAUTH_URL: process.env.NEXTAUTH_URL || 'https://www.cambodia.com',
  },
}

module.exports = nextConfig
```

#### Update Railway Variables
After adding the domain:
1. Go to Railway Dashboard → Settings → Variables
2. Update `NEXTAUTH_URL` to: `https://www.cambodia.com`

### 5. SSL Certificate

Railway automatically provisions SSL certificates for custom domains. After DNS propagation:
- Wait 10-30 minutes for SSL to be issued
- Check the domain status in Railway Dashboard
- The domain should show "Active" with a green checkmark

### 6. Deploy

Click "Deploy" in Railway. The build process will:
1. Install Node.js 22
2. Install dependencies
3. Build the Next.js application
4. Start the application

### 7. Verify Deployment

1. Check Railway logs for successful deployment
2. Visit `https://www.cambodia.com`
3. Verify the application loads correctly
4. Test authentication and other features

## Troubleshooting

### Deployment Fails - "npm: command not found"
**Solution**: The `nixpacks.toml` file should fix this. Ensure it's committed and pushed.

### Domain Not Resolving
**Solution**: 
- Check DNS propagation: `dig www.cambodia.com`
- Verify DNS records are correct
- Wait up to 24 hours for DNS propagation

### SSL Certificate Not Issued
**Solution**:
- Verify DNS is correctly pointing to Railway
- Wait 10-30 minutes after DNS propagation
- Check Railway Dashboard for certificate status

### NextAuth Issues
**Solution**:
- Ensure `NEXTAUTH_URL` matches your custom domain exactly
- Verify `NEXTAUTH_SECRET` is set and is at least 32 characters
- Check Railway logs for authentication errors

### Database Connection Errors
**Solution**:
- Add PostgreSQL service in Railway
- Use Railway-provided `DATABASE_URL` in environment variables
- Or configure external database connection string

## Monitoring

### View Logs
```bash
# Using Railway CLI
railway logs

# Or view in Railway Dashboard → Logs
```

### Check Status
- Railway Dashboard → Deployments
- Monitor build logs, runtime logs, and error rates

## Production Considerations

### Security
- Enable Railway's automatic builds
- Set up proper environment variable management
- Enable Railway's built-in health checks
- Configure automatic redeployments on git push

### Performance
- Enable Railway's automatic scaling
- Monitor resource usage in Railway Dashboard
- Configure Redis for caching if needed
- Set up CDN for static assets

### Backup
- Railway provides automatic backups for databases
- Export regular backups: `railway volume download`
- Test restoration process periodically

## Contact & Support

- Railway Documentation: https://docs.railway.app
- Railway Support: https://railway.app/support
- GitHub Issues: https://github.com/railwayapp/railway/issues

## Additional Resources

- Railway Nixpacks: https://docs.railway.app/deploy/nixpacks
- Custom Domains: https://docs.railway.app/deploy/domains
- Environment Variables: https://docs.railway.app/deploy/variables
- Next.js Deployment: https://nextjs.org/docs/deployment
