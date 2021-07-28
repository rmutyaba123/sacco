--- Data
INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (5, 'Kenya Shilling', 'KES');

INSERT INTO orgs (org_id, org_name, org_sufix, currency_id, logo) VALUES (1, 'Default', 'df', 5, 'logo.png');
UPDATE currency SET org_id = 1 WHERE currency_id = 5;
SELECT pg_catalog.setval('orgs_org_id_seq', 1, true);
SELECT pg_catalog.setval('currency_currency_id_seq', 5, true);

INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (1, 5, 1);

INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES 
	(1, 'Users', 'user', 0),
	(1, 'Staff', 'staff', 1), 
	(1, 'Client', 'client', 2),
	(1, 'Supplier', 'supplier', 3),
	(1, 'Tenants', 'tenants', 6);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, start_view, use_key_id) VALUES 
	(1, 'Applicant', 'applicant', '10:0', 4);


INSERT INTO subscription_levels (org_id, subscription_level_name) VALUES 
(1, 'Basic'),(1, 'Manager'),(1, 'Consumer');

---Property types
INSERT INTO property_types (org_id, property_type_name)
SELECT 1, property_type_name
FROM property_types
WHERE org_id = 0;

---Property amenity
INSERT INTO property_amenity (org_id, amenity_name)
SELECT 1, amenity_name
FROM property_amenity
WHERE org_id = 0;

---Commission Type
INSERT INTO commission_types (org_id,commission_name)
SELECT 1, commission_name
FROM commission_types
WHERE org_id = 0;

---Unit Types
INSERT INTO unit_types (org_id,unit_type_name)
SELECT 1, unit_type_name
FROM unit_types
WHERE org_id = 0;

INSERT INTO sys_emails (org_id, use_type,  sys_email_name, title, details) 
SELECT 1, use_type, sys_email_name, title, details
FROM sys_emails
WHERE org_id = 0;

INSERT INTO accounts_class (org_id, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name)
SELECT 1, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name
FROM accounts_class
WHERE org_id = 0;

INSERT INTO account_types (org_id, accounts_class_id, account_type_no, account_type_name)
SELECT a.org_id, a.accounts_class_id, b.account_type_no, b.account_type_name
FROM accounts_class a INNER JOIN account_types b ON a.accounts_class_no = b.accounts_class_id
WHERE (a.org_id = 1) AND (b.org_id = 0);


INSERT INTO accounts (org_id, account_type_id, account_no, account_name)
SELECT a.org_id, a.account_type_id, b.account_no, b.account_name
FROM account_types a INNER JOIN accounts b ON a.account_type_no = b.account_type_id
WHERE (a.org_id = 1) AND (b.org_id = 0);


INSERT INTO default_accounts (org_id, use_key_id, account_id)
SELECT b.org_id, a.use_key_id, b.account_id
FROM default_accounts a INNER JOIN accounts b ON a.account_id = b.account_no
WHERE (a.org_id = 0) AND (b.org_id = 1);

---default users
INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id, user_name, entity_name, primary_email, entity_leader, super_user, no_org, first_password,function_role)
VALUES (2, 0, 0, 0, 'admin', 'admin', 'admin@admin.com', true, false, false, 'baraza','admin');
INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id, user_name, entity_name, primary_email, entity_leader, super_user, no_org, first_password,function_role)
VALUES (3, 0, 0, 2, 'client', 'Dorcas Gicuku', 'Dori@gmail.com', true, false, false, 'baraza','client');
INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id, user_name, entity_name, primary_email, entity_leader, super_user, no_org, first_password,function_role)
VALUES (4, 0, 0, 6, 'tenant', 'Peter Mwangi', 'peter@peter.me.ke', true, false, false, 'baraza','tenants');
SELECT pg_catalog.setval('entitys_entity_id_seq', 4, true); 


INSERT INTO workflows (link_copy, org_id, source_entity_id, workflow_name, table_name, approve_email, reject_email) 
SELECT aa.workflow_id, bb.org_id, bb.entity_type_id, aa.workflow_name, aa.table_name, aa.approve_email, aa.reject_email
FROM workflows aa INNER JOIN entity_types bb ON aa.source_entity_id = bb.use_key_id
WHERE aa.org_id = 0 AND bb.org_id = 1
ORDER BY aa.workflow_id;

INSERT INTO workflow_phases (org_id, workflow_id, approval_entity_id, approval_level, return_level, 
	escalation_days, escalation_hours, required_approvals, advice, notice, 
	phase_narrative, advice_email, notice_email) 
SELECT bb.org_id, bb.workflow_id, cc.entity_type_id, aa.approval_level, aa.return_level, 
	aa.escalation_days, aa.escalation_hours, aa.required_approvals, aa.advice, aa.notice, 
	aa.phase_narrative, aa.advice_email, aa.notice_email
FROM workflow_phases aa INNER JOIN workflows bb ON aa.workflow_id = bb.link_copy
	INNER JOIN entity_types cc ON aa.approval_entity_id = cc.use_key_id
WHERE aa.org_id = 0 AND bb.org_id = 1 AND cc.org_id = 1;



UPDATE transaction_counters SET document_number = '10001';

