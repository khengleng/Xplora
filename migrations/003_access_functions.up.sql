-- Check if user has active access
CREATE OR REPLACE FUNCTION has_active_access(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'APPROVED'
          AND access_expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Get access expiry
CREATE OR REPLACE FUNCTION get_access_expiry(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS TIMESTAMPTZ AS $$
BEGIN
    RETURN (
        SELECT access_expires_at FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'APPROVED'
          AND access_expires_at > NOW()
        ORDER BY access_expires_at DESC
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Get pending request ID
CREATE OR REPLACE FUNCTION get_pending_request_id(
    p_user_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field
)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT id FROM field_access_requests
        WHERE requester_id = p_user_id
          AND account_id = p_account_id
          AND field_name = p_field
          AND status = 'PENDING'
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Get user role
CREATE OR REPLACE FUNCTION get_user_role(p_user_id BIGINT)
RETURNS user_role AS $$
DECLARE
    v_role user_role;
BEGIN
    SELECT role INTO v_role FROM users 
    WHERE id = p_user_id AND is_active = true AND is_locked = false;
    RETURN v_role;
END;
$$ LANGUAGE plpgsql STABLE;

-- Check privileged access
CREATE OR REPLACE FUNCTION has_privileged_access(p_user_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_role user_role;
BEGIN
    v_role := get_user_role(p_user_id);
    RETURN v_role IN ('VVIP', 'ADMIN', 'MANAGER');
END;
$$ LANGUAGE plpgsql STABLE;

-- Submit field request
CREATE OR REPLACE FUNCTION submit_field_request(
    p_teller_id BIGINT,
    p_account_id BIGINT,
    p_field sensitive_field,
    p_reason TEXT,
    p_ticket_ref VARCHAR(50) DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, request_id BIGINT, request_ref UUID, message TEXT) AS $$
DECLARE
    v_user RECORD;
    v_new_id BIGINT;
    v_new_ref UUID;
BEGIN
    SELECT * INTO v_user FROM users WHERE id = p_teller_id AND is_active = true;
    
    IF v_user IS NULL THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'User not found or inactive';
        RETURN;
    END IF;
    
    IF v_user.role = 'DBA' THEN
        PERFORM log_pci_event(p_teller_id, v_user.username, v_user.employee_id,
            'DBA_ACCESS_DENIED', 'SECURITY', false, p_ip_address, p_user_agent,
            'accounts', p_account_id, ARRAY[p_field::TEXT], NULL, 'DBA attempted data access');
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'DBA cannot access customer data';
        RETURN;
    END IF;
    
    IF v_user.is_locked THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Account is locked';
        RETURN;
    END IF;
    
    IF v_user.role IN ('VVIP', 'ADMIN', 'MANAGER') THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'You have automatic access';
        RETURN;
    END IF;
    
    IF get_pending_request_id(p_teller_id, p_account_id, p_field) IS NOT NULL THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Pending request exists';
        RETURN;
    END IF;
    
    IF has_active_access(p_teller_id, p_account_id, p_field) THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'You have active access';
        RETURN;
    END IF;
    
    IF LENGTH(TRIM(p_reason)) < 20 THEN
        RETURN QUERY SELECT false, NULL::BIGINT, NULL::UUID, 'Provide detailed reason (min 20 chars)';
        RETURN;
    END IF;
    
    INSERT INTO field_access_requests (requester_id, account_id, field_name, reason, ticket_reference)
    VALUES (p_teller_id, p_account_id, p_field, p_reason, p_ticket_ref)
    RETURNING id, field_access_requests.request_ref INTO v_new_id, v_new_ref;
    
    INSERT INTO data_access_log (user_id, account_id, request_id, action, field_name, ip_address, user_agent)
    VALUES (p_teller_id, p_account_id, v_new_id, 'REQUEST_ACCESS', p_field, p_ip_address, p_user_agent);
    
    PERFORM log_pci_event(p_teller_id, v_user.username, v_user.employee_id,
        'ACCESS_REQUEST', 'ACCESS', true, p_ip_address, p_user_agent,
        'accounts', p_account_id, ARRAY[p_field::TEXT],
        jsonb_build_object('reason', p_reason, 'ticket', p_ticket_ref));
    
    RETURN QUERY SELECT true, v_new_id, v_new_ref, 'Request submitted';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Approve request
CREATE OR REPLACE FUNCTION approve_request(
    p_request_id BIGINT,
    p_approver_id BIGINT,
    p_duration_minutes INT DEFAULT 30,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
DECLARE
    v_approver RECORD;
    v_request RECORD;
BEGIN
    SELECT * INTO v_approver FROM users WHERE id = p_approver_id AND is_active = true;
    
    IF v_approver IS NULL OR v_approver.role NOT IN ('SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN') THEN
        RETURN QUERY SELECT false, 'Not authorized to approve';
        RETURN;
    END IF;
    
    SELECT * INTO v_request FROM field_access_requests WHERE id = p_request_id;
    
    IF v_request IS NULL OR v_request.status != 'PENDING' THEN
        RETURN QUERY SELECT false, 'Request not found or not pending';
        RETURN;
    END IF;
    
    IF p_duration_minutes > 480 THEN p_duration_minutes := 480; END IF;
    
    UPDATE field_access_requests SET
        status = 'APPROVED',
        reviewed_by = p_approver_id,
        reviewed_at = NOW(),
        access_granted_at = NOW(),
        access_expires_at = NOW() + (p_duration_minutes || ' minutes')::INTERVAL,
        access_duration_minutes = p_duration_minutes,
        updated_at = NOW()
    WHERE id = p_request_id;
    
    INSERT INTO data_access_log (user_id, account_id, request_id, action, field_name, ip_address, user_agent)
    VALUES (p_approver_id, v_request.account_id, p_request_id, 'APPROVE', v_request.field_name, p_ip_address, p_user_agent);
    
    PERFORM log_pci_event(p_approver_id, v_approver.username, v_approver.employee_id,
        'ACCESS_APPROVED', 'ACCESS', true, p_ip_address, p_user_agent,
        'field_access_requests', p_request_id, ARRAY[v_request.field_name::TEXT],
        jsonb_build_object('requester_id', v_request.requester_id, 'duration', p_duration_minutes));
    
    RETURN QUERY SELECT true, 'Approved for ' || p_duration_minutes || ' minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reject request
CREATE OR REPLACE FUNCTION reject_request(
    p_request_id BIGINT,
    p_rejector_id BIGINT,
    p_reason TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, message TEXT) AS $$
DECLARE
    v_rejector RECORD;
    v_request RECORD;
BEGIN
    SELECT * INTO v_rejector FROM users WHERE id = p_rejector_id AND is_active = true;
    
    IF v_rejector IS NULL OR v_rejector.role NOT IN ('SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN') THEN
        RETURN QUERY SELECT false, 'Not authorized to reject';
        RETURN;
    END IF;
    
    SELECT * INTO v_request FROM field_access_requests WHERE id = p_request_id;
    
    IF v_request IS NULL OR v_request.status != 'PENDING' THEN
        RETURN QUERY SELECT false, 'Request not found or not pending';
        RETURN;
    END IF;
    
    UPDATE field_access_requests SET
        status = 'REJECTED',
        reviewed_by = p_rejector_id,
        reviewed_at = NOW(),
        rejection_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_request_id;
    
    PERFORM log_pci_event(p_rejector_id, v_rejector.username, v_rejector.employee_id,
        'ACCESS_REJECTED', 'ACCESS', true, p_ip_address, p_user_agent,
        'field_access_requests', p_request_id, ARRAY[v_request.field_name::TEXT],
        jsonb_build_object('reason', p_reason));
    
    RETURN QUERY SELECT true, 'Request rejected';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Expire stale access
CREATE OR REPLACE FUNCTION expire_stale_access()
RETURNS INT AS $$
DECLARE
    expired_count INT;
BEGIN
    UPDATE field_access_requests 
    SET status = 'EXPIRED', updated_at = NOW()
    WHERE status = 'APPROVED' AND access_expires_at < NOW();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    IF expired_count > 0 THEN
        PERFORM log_pci_event(NULL, 'SYSTEM', 'SYSTEM',
            'ACCESS_EXPIRED_BATCH', 'ADMIN', true, NULL, NULL, NULL, NULL, NULL,
            jsonb_build_object('expired_count', expired_count));
    END IF;
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get my requests
CREATE OR REPLACE FUNCTION get_my_requests(p_teller_id BIGINT, p_limit INT DEFAULT 50)
RETURNS TABLE (
    request_id BIGINT, request_ref UUID, account_id BIGINT, account_preview TEXT,
    customer_name VARCHAR, field_name sensitive_field, status request_status,
    reason TEXT, rejection_reason TEXT, requested_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ, reviewer_name VARCHAR, expires_at TIMESTAMPTZ,
    minutes_remaining INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.request_ref, a.id, '****' || a.account_number_last4,
        a.holder_name_search, r.field_name, r.status, r.reason, r.rejection_reason,
        r.created_at, r.reviewed_at, rev.full_name, r.access_expires_at,
        CASE WHEN r.access_expires_at > NOW() 
             THEN GREATEST(0, EXTRACT(EPOCH FROM (r.access_expires_at - NOW()))::INT / 60)
             ELSE 0 END
    FROM field_access_requests r
    JOIN accounts a ON r.account_id = a.id
    LEFT JOIN users rev ON r.reviewed_by = rev.id
    WHERE r.requester_id = p_teller_id
    ORDER BY r.created_at DESC LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pending requests dashboard
CREATE OR REPLACE VIEW pending_requests_dashboard AS
SELECT r.id AS request_id, r.request_ref, r.created_at AS requested_at,
    u.full_name AS requester_name, u.employee_id AS requester_employee_id,
    u.branch_code AS requester_branch, u.role AS requester_role,
    a.id AS account_id, a.holder_name_search AS customer_name,
    '****' || a.account_number_last4 AS account_preview,
    r.field_name AS requested_field, r.reason, r.ticket_reference,
    r.access_duration_minutes AS requested_duration,
    ROUND(EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 60) AS minutes_waiting
FROM field_access_requests r
JOIN users u ON r.requester_id = u.id
JOIN accounts a ON r.account_id = a.id
WHERE r.status = 'PENDING'
ORDER BY r.created_at ASC;

-- Login attempt tracking
CREATE OR REPLACE FUNCTION record_login_attempt(
    p_username VARCHAR, p_success BOOLEAN, p_ip_address INET, p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (result VARCHAR, is_locked BOOLEAN, lockout_minutes_remaining INT) AS $$
DECLARE
    v_user RECORD;
    v_max_attempts INT := 6;
    v_lockout_minutes INT := 30;
BEGIN
    SELECT * INTO v_user FROM users WHERE username = p_username;
    
    IF p_success THEN
        IF v_user IS NOT NULL THEN
            UPDATE users SET failed_login_attempts = 0, last_login_at = NOW(),
                last_login_ip = p_ip_address, is_locked = false, locked_at = NULL, locked_reason = NULL
            WHERE id = v_user.id;
            PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
                'LOGIN_SUCCESS', 'AUTH', true, p_ip_address, p_user_agent);
        END IF;
        RETURN QUERY SELECT 'SUCCESS'::VARCHAR, false, 0;
        RETURN;
    END IF;
    
    IF v_user IS NOT NULL THEN
        UPDATE users SET failed_login_attempts = failed_login_attempts + 1, updated_at = NOW()
        WHERE id = v_user.id RETURNING * INTO v_user;
        
        IF v_user.failed_login_attempts >= v_max_attempts THEN
            UPDATE users SET is_locked = true, locked_at = NOW(),
                locked_reason = 'Exceeded max login attempts' WHERE id = v_user.id;
            PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
                'ACCOUNT_LOCKED', 'AUTH', false, p_ip_address, p_user_agent, NULL, NULL, NULL,
                jsonb_build_object('reason', 'Max login attempts'), 'Account locked');
            RETURN QUERY SELECT 'LOCKED'::VARCHAR, true, v_lockout_minutes;
            RETURN;
        END IF;
        
        PERFORM log_pci_event(v_user.id, v_user.username, v_user.employee_id,
            'LOGIN_FAILED', 'AUTH', false, p_ip_address, p_user_agent, NULL, NULL, NULL,
            jsonb_build_object('attempts', v_user.failed_login_attempts));
    ELSE
        INSERT INTO failed_access_log (attempted_user, ip_address, user_agent, failure_reason)
        VALUES (p_username, p_ip_address, p_user_agent, 'UNKNOWN_USER');
    END IF;
    
    RETURN QUERY SELECT 'FAILED'::VARCHAR, false, 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
