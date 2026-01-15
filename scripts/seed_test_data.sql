-- Test Users
INSERT INTO users (employee_id, username, full_name, role, branch_code, is_active) VALUES
    ('EMP001', 'alice.teller', 'Alice Johnson', 'TELLER', 'NYC001', true),
    ('EMP002', 'bob.teller', 'Bob Williams', 'TELLER', 'NYC001', true),
    ('EMP003', 'carol.supervisor', 'Carol Smith', 'SUPERVISOR', 'NYC001', true),
    ('EMP004', 'dan.manager', 'Dan Brown', 'MANAGER', 'NYC001', true),
    ('EMP005', 'eve.vvip', 'Eve Davis', 'VVIP', 'HQ', true),
    ('EMP006', 'frank.dba', 'Frank Miller', 'DBA', 'IT', true)
ON CONFLICT (employee_id) DO NOTHING;

-- Test Accounts (encrypted values are placeholders - real app encrypts via Vault)
INSERT INTO accounts (
    account_number_encrypted, account_number_last4, account_number_hash,
    routing_number_encrypted, holder_name_encrypted, holder_name_search,
    ssn_encrypted, ssn_last4, email_encrypted, email_hint,
    phone_encrypted, phone_last4, balance_encrypted, encryption_key_id
) VALUES (
    'vault:v1:placeholder1', '7890', encode(digest('1234567890', 'sha256'), 'hex'),
    'vault:v1:placeholder2', 'vault:v1:placeholder3', 'John',
    'vault:v1:placeholder4', '6789', 'vault:v1:placeholder5', 'j***@email.com',
    'vault:v1:placeholder6', '4567', 'vault:v1:placeholder7', 'vault-key-v1'
), (
    'vault:v1:placeholder8', '4321', encode(digest('0987654321', 'sha256'), 'hex'),
    'vault:v1:placeholder9', 'vault:v1:placeholder10', 'Jane',
    'vault:v1:placeholder11', '4321', 'vault:v1:placeholder12', 'j***@test.com',
    'vault:v1:placeholder13', '6543', 'vault:v1:placeholder14', 'vault-key-v1'
) ON CONFLICT DO NOTHING;

SELECT 'Test data seeded successfully!' AS result;
