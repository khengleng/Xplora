CREATE OR REPLACE FUNCTION has_active_access(p_user BIGINT, p_account BIGINT, p_field sensitive_field)
RETURNS BOOLEAN AS $$
BEGIN RETURN EXISTS (SELECT 1 FROM field_access_requests WHERE requester_id=p_user
AND account_id=p_account AND field_name=p_field AND status='APPROVED' AND access_expires_at>NOW()); END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION submit_field_request(p_user BIGINT, p_account BIGINT, p_field sensitive_field, p_reason TEXT, p_ticket VARCHAR DEFAULT NULL)
RETURNS TABLE(success BOOLEAN, request_id BIGINT, message TEXT) AS $$
DECLARE v_role user_role; v_id BIGINT;
BEGIN
  SELECT role INTO v_role FROM users WHERE id=p_user AND is_active AND NOT is_locked;
  IF v_role IS NULL THEN RETURN QUERY SELECT false,NULL::BIGINT,'User not found'; RETURN; END IF;
  IF v_role='DBA' THEN RETURN QUERY SELECT false,NULL::BIGINT,'DBA cannot access data'; RETURN; END IF;
  IF v_role IN ('VVIP','ADMIN','MANAGER') THEN RETURN QUERY SELECT false,NULL::BIGINT,'You have auto access'; RETURN; END IF;
  IF LENGTH(TRIM(p_reason))<20 THEN RETURN QUERY SELECT false,NULL::BIGINT,'Need 20+ char reason'; RETURN; END IF;
  INSERT INTO field_access_requests(requester_id,account_id,field_name,reason,ticket_reference)
  VALUES(p_user,p_account,p_field,p_reason,p_ticket) RETURNING id INTO v_id;
  RETURN QUERY SELECT true,v_id,'Request submitted';
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION approve_request(p_request BIGINT, p_approver BIGINT, p_mins INT DEFAULT 30)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE v_role user_role;
BEGIN
  SELECT role INTO v_role FROM users WHERE id=p_approver AND is_active;
  IF v_role NOT IN ('SUPERVISOR','MANAGER','VVIP','ADMIN') THEN RETURN QUERY SELECT false,'Not authorized'; RETURN; END IF;
  UPDATE field_access_requests SET status='APPROVED',reviewed_by=p_approver,reviewed_at=NOW(),
    access_expires_at=NOW()+(p_mins||' minutes')::INTERVAL WHERE id=p_request AND status='PENDING';
  RETURN QUERY SELECT true,'Approved for '||p_mins||' min';
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW pending_requests_dashboard AS
SELECT r.id,r.request_ref,u.full_name requester,u.branch_code,'****'||a.account_number_last4 account,
  r.field_name,r.reason,r.ticket_reference,ROUND(EXTRACT(EPOCH FROM NOW()-r.created_at)/60) mins_waiting
FROM field_access_requests r JOIN users u ON r.requester_id=u.id JOIN accounts a ON r.account_id=a.id
WHERE r.status='PENDING' ORDER BY r.created_at;
