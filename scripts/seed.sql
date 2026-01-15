INSERT INTO users(employee_id,username,full_name,role,branch_code) VALUES
('E001','alice.teller','Alice Teller','TELLER','NYC'),
('E002','carol.supervisor','Carol Supervisor','SUPERVISOR','NYC'),
('E003','dan.manager','Dan Manager','MANAGER','NYC'),
('E004','eve.vvip','Eve VVIP','VVIP','HQ') ON CONFLICT DO NOTHING;
