-- Seed script with password hashes
-- Default password for all users: "password"
-- Password hash generated with: bcrypt.hashSync('password', 10)
-- You can generate new hashes using: node -e "const bcrypt = require('bcryptjs'); console.log(bcrypt.hashSync('yourpassword', 10));"

INSERT INTO users(employee_id, username, full_name, role, branch_code, password_hash) VALUES
('E001', 'alice.teller', 'Alice Teller', 'TELLER', 'NYC', '$2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZqZqZq'),
('E002', 'carol.supervisor', 'Carol Supervisor', 'SUPERVISOR', 'NYC', '$2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZqZq'),
('E003', 'dan.manager', 'Dan Manager', 'MANAGER', 'NYC', '$2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZqZq'),
('E004', 'eve.vvip', 'Eve VVIP', 'VVIP', 'HQ', '$2a$10$rOzJqZqZqZqZqZqZqZqZqOqZqZqZqZqZqZqZqZqZqZqZqZqZqZqZq')
ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash;

-- Sample accounts (encrypted fields would normally be encrypted, but for demo we'll use placeholders)
-- In production, use proper encryption with keys from Vault
INSERT INTO accounts(
  account_number_encrypted, 
  account_number_last4, 
  account_number_hash, 
  holder_name_encrypted, 
  holder_name_search,
  ssn_encrypted,
  ssn_last4,
  email_encrypted,
  email_hint,
  phone_encrypted,
  phone_last4,
  balance_encrypted,
  encryption_key_id
) VALUES
(
  '\x1234567890abcdef', -- account_number_encrypted (BYTEA placeholder)
  '1234',
  encode(digest('1234567890123456', 'sha256'), 'hex'),
  '\x4a6f686e20446f65', -- holder_name_encrypted (BYTEA placeholder)
  'John Doe',
  '\x123456789', -- ssn_encrypted
  '5678',
  '\x6a6f686e406578616d706c652e636f6d', -- email_encrypted
  'j***@example.com',
  '\x35353531323334353637', -- phone_encrypted
  '3456',
  '\x31303030302e3030', -- balance_encrypted
  'vault-key-1'
),
(
  '\xabcdef1234567890',
  '5678',
  encode(digest('9876543210987654', 'sha256'), 'hex'),
  '\x4a616e6520536d697468',
  'Jane Smith',
  '\x987654321',
  '4321',
  '\x6a616e65406578616d706c652e636f6d',
  'j***@example.com',
  '\x35353539383736353433',
  '6543',
  '\x32353030302e3030',
  'vault-key-1'
)
ON CONFLICT (account_number_hash) DO NOTHING;
