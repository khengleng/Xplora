# Xplora Platform

A complete, production-ready platform for managing sensitive data access with role-based permissions, encrypted storage, and comprehensive audit logging.

## Overview

Xplora is a secure portal for managing access to sensitive account information. It implements:

- **Role-based access control** (TELLER, SUPERVISOR, MANAGER, VVIP, ADMIN, DBA)
- **Field-level access requests** with approval workflows
- **Encrypted sensitive data** (account numbers, SSN, balances, etc.)
- **PCI-compliant audit logging** (immutable audit trail)
- **Modern web portal** built with Next.js 14 and TypeScript

## Architecture

### Database Layer (PostgreSQL)

- **Users table**: Employee accounts with roles and authentication
- **Accounts table**: Encrypted sensitive account data with searchable hints
- **Field access requests**: Request/approve/reject workflow for sensitive fields
- **PCI audit log**: Immutable audit trail for all sensitive data access
- **Database functions**: Business logic for access control and request processing

### Portal (Next.js)

- **Authentication**: NextAuth.js with PostgreSQL-backed credentials
- **API Routes**: RESTful APIs for accounts, requests, and authentication
- **Dashboard**: Modern UI for account search and request management
- **Middleware**: Route protection and session management

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ and npm
- PostgreSQL client (psql) for running migrations

### 1. Start Infrastructure

```bash
# Start PostgreSQL and Vault
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 2. Run Database Migrations

```bash
# Connect to PostgreSQL
psql postgres://admin:secret@localhost:5432/xplora

# Run migrations in order
\i migrations/001_audit.up.sql
\i migrations/001_pci_audit_schema.up.sql
\i migrations/002_core_tables.up.sql
\i migrations/003_access_functions.up.sql
\i migrations/004_add_password_hash.up.sql

# Seed test data with passwords
\i scripts/seed_with_passwords.sql

# Exit psql
\q
```

### 3. Setup Portal

```bash
cd portal

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env and set:
# - DATABASE_URL (default: postgres://admin:secret@localhost:5432/xplora)
# - NEXTAUTH_SECRET (generate a random string)
# - NEXTAUTH_URL (default: http://localhost:3000)

# Start development server
npm run dev
```

### 4. Access Portal

Open http://localhost:3000 in your browser.

**Test Users** (default password: `password`):
- `alice.teller` - TELLER role
- `carol.supervisor` - SUPERVISOR role (can approve requests)
- `dan.manager` - MANAGER role (can approve requests)
- `eve.vvip` - VVIP role (auto-access, can approve)

## Features

### Authentication & Authorization

- Secure password-based authentication with bcrypt hashing
- Role-based access control
- Session management with NextAuth.js
- Account lockout after failed login attempts

### Account Management

- Search accounts by last 4 digits
- Encrypted sensitive fields (account numbers, SSN, balances, etc.)
- Field-level access control
- Access request workflow

### Access Request Workflow

1. **TELLER** requests access to a sensitive field (e.g., SSN, balance)
2. **SUPERVISOR/MANAGER** reviews and approves/rejects the request
3. Approved access expires after configured duration (default: 30 minutes)
4. All actions are logged in the PCI audit log

### Audit & Compliance

- Immutable audit log (cannot be modified or deleted)
- Tracks all sensitive data access
- Includes user, timestamp, IP address, accessed fields
- PCI-compliant logging structure

## Project Structure

```
Xplora/
├── migrations/          # Database migrations
│   ├── 001_audit.up.sql
│   ├── 002_core_tables.up.sql
│   ├── 003_access_functions.up.sql
│   └── 004_add_password_hash.up.sql
├── scripts/            # Seed data and utilities
│   ├── seed.sql
│   └── seed_with_passwords.sql
├── portal/             # Next.js web portal
│   ├── src/
│   │   ├── app/        # Next.js app router
│   │   │   ├── api/    # API routes
│   │   │   └── dashboard/
│   │   ├── components/ # React components
│   │   ├── lib/        # Utilities (db, auth)
│   │   └── types/      # TypeScript types
│   └── package.json
├── vault/              # HashiCorp Vault config
└── docker-compose.yml  # Infrastructure setup
```

## API Endpoints

### Authentication
- `POST /api/auth/signin` - Sign in
- `POST /api/auth/signout` - Sign out
- `GET /api/auth/session` - Get current session

### Accounts
- `GET /api/accounts?q=<last4>` - Search accounts by last 4 digits
- `GET /api/accounts/[id]?field=<field>` - Get account details (requires access)

### Requests
- `GET /api/requests/pending` - List pending requests (approvers only)
- `GET /api/requests/mine` - List my requests
- `POST /api/requests` - Submit new access request
- `POST /api/requests/[id]/approve` - Approve request (approvers only)
- `POST /api/requests/[id]/reject` - Reject request (approvers only)

## Database Schema

### Users
- Employee authentication and role management
- Password hashing with bcrypt
- Account lockout support

### Accounts
- Encrypted sensitive fields (BYTEA columns)
- Searchable hints (last4, hints) for UI
- Hash-based deduplication

### Field Access Requests
- Request/approve/reject workflow
- Time-limited access grants
- Links to users and accounts

### PCI Audit Log
- Immutable audit trail
- Protected by database triggers
- Comprehensive event tracking

## Security Considerations

- **Encryption**: Sensitive fields encrypted at rest (BYTEA columns)
- **Access Control**: Role-based permissions enforced at database and API levels
- **Audit Trail**: All sensitive access logged immutably
- **Password Security**: bcrypt hashing with configurable rounds
- **Session Security**: Secure HTTP-only cookies, CSRF protection
- **Input Validation**: SQL injection prevention via parameterized queries

## Development

### Running Tests

```bash
cd portal
npm run lint
npm run build
```

### Adding New Features

1. Create database migration if schema changes needed
2. Add TypeScript types in `portal/src/types/`
3. Implement API routes in `portal/src/app/api/`
4. Build UI components in `portal/src/components/`
5. Update documentation

## Production Deployment

1. Set strong `NEXTAUTH_SECRET` and `DATABASE_URL`
2. Use proper encryption keys from Vault for sensitive data
3. Enable HTTPS/TLS
4. Configure database backups
5. Set up monitoring and alerting
6. Review and update security policies

## License

See LICENSE file for details.

## Contributing

See SECURITY.md for security reporting guidelines.
