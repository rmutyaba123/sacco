

--- Data
INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (5, 'US Dollar', 'USD');
INSERT INTO orgs (org_id, org_name, org_sufix, currency_id, logo) VALUES (1, 'Default', 'df', 5, 'logo.png');
UPDATE currency SET org_id = 1 WHERE currency_id = 5;
SELECT pg_catalog.setval('orgs_org_id_seq', 1, true);
SELECT pg_catalog.setval('currency_currency_id_seq', 5, true);

INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (1, 5, 1);

INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES (1, 'Users', 'user', 0);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES (1, 'Staff', 'staff', 1);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES (1, 'Client', 'client', 2);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES (1, 'Supplier', 'supplier', 3);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, start_view, use_key_id) VALUES (1, 'Applicant', 'applicant', '10:0', 4);

--- Copy over data
INSERT INTO jobs_category (org_id, jobs_category) VALUES (1, 'General Management');

INSERT INTO pay_scales (org_id, pay_scale_name, min_pay, max_pay) VALUES (1, 'Basic', 0, 1000000);
INSERT INTO locations (org_id, location_name) VALUES (1, 'Main office');
INSERT INTO pay_groups (org_id, pay_group_name, gl_payment_account) VALUES (1, 'Default', '40055');

INSERT INTO contract_status (org_id, contract_status_name)
SELECT 1, contract_status_name
FROM contract_status
WHERE org_id = 0;

INSERT INTO contract_types (org_id, contract_type_name)
SELECT 1, contract_type_name
FROM contract_types
WHERE org_id = 0;

INSERT INTO interview_types (org_id, interview_type_name, is_active)
SELECT 1, interview_type_name, is_active
FROM interview_types
WHERE (org_id = 0);

INSERT INTO kin_types (org_id, kin_type_name)
SELECT 1, kin_type_name
FROM kin_types
WHERE org_id = 0;

INSERT INTO education_class (org_id, education_class_name)
SELECT 1, education_class_name
FROM education_class
WHERE org_id = 0
ORDER BY education_class_id;

INSERT INTO skill_levels (org_id, skill_level_name)
SELECT 1, skill_level_name
FROM skill_levels
WHERE org_id = 0
ORDER BY skill_level_id;

INSERT INTO adjustments (adjustment_type, adjustment_effect_id, adjustment_id, adjustment_name, visible, in_tax, account_number) VALUES 
(1, 1, 41, 'Sitting Allowance', true, true, '90005'),
(1, 1, 42, 'Bonus', true, true, '90005'),
(2, 2, 43, 'External Loan', true, false, '40055'),
(2, 2, 44, 'Home Ownership saving plan', true, false, '40055'),
(2, 2, 45, 'Staff contribution', true, false, '40055'),
(3, 3, 46, 'Travel', true, false, '90070'),
(3, 3, 47, 'Communcation', true, false, '90070');
UPDATE adjustments SET org_id = 1, currency_id = 5 WHERE org_id is null;
SELECT pg_catalog.setval('adjustments_adjustment_id_seq', 50, true);

INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, account_number, employer_account, sys_country_id) VALUES (7, 11, 'PAYE', 'Get_Employee_Tax(employee_tax_type_id, 2)', 1162, 1, false, true, true, 0, 0, true, '40045', '40045', 'KE');
INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, account_number, employer_account, sys_country_id) VALUES (8, 12, 'NSSF', 'Get_Employee_Tax(employee_tax_type_id, 1)', 0, 0, true, true, true, 0, 0, true, '40030', '40030', 'KE');
INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, account_number, employer_account, sys_country_id) VALUES (9, 12, 'NHIF', 'Get_Employee_Tax(employee_tax_type_id, 1)', 0, 0, false, false, false, 0, 0, true, '40035', '40035', 'KE');
INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, account_number, employer_account, sys_country_id) VALUES (10, 11, 'FULL PAYE', 'Get_Employee_Tax(employee_tax_type_id, 2)', 0, 0, false, false, false, 0, 0, false, '40045', '40045', 'KE');
INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, tax_rate, account_id) VALUES (11, 15, 'Exempt', 0, '42000');
INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, tax_rate, account_id) VALUES (12, 15, 'VAT', 16, '42000');
SELECT pg_catalog.setval('tax_types_tax_type_id_seq', 50, true);

INSERT INTO tax_rates (org_id, tax_type_id, tax_range, tax_rate)
SELECT 1,  tax_type_id + 6, tax_range, tax_rate
FROM tax_rates
WHERE org_id = 0;


INSERT INTO stores (org_id, store_name) VALUES (1, 'Main Store');

INSERT INTO sys_emails (org_id, use_type,  sys_email_name, title, details) 
SELECT 1, use_type, sys_email_name, title, details
FROM sys_emails
WHERE org_id = 0
ORDER BY sys_email_id;

INSERT INTO account_class (org_id, account_class_no, chat_type_id, chat_type_name, account_class_name)
SELECT 1, account_class_no, chat_type_id, chat_type_name, account_class_name
FROM account_class
WHERE org_id = 0;


INSERT INTO account_types (org_id, account_class_id, account_type_no, account_type_name)
SELECT a.org_id, a.account_class_id, b.account_type_no, b.account_type_name
FROM account_class a INNER JOIN account_types b ON a.account_class_no = b.account_class_id
WHERE (a.org_id = 1) AND (b.org_id = 0);


INSERT INTO accounts (org_id, account_type_id, account_no, account_name)
SELECT a.org_id, a.account_type_id, b.account_no, b.account_name
FROM account_types a INNER JOIN accounts b ON a.account_type_no = b.account_type_id
WHERE (a.org_id = 1) AND (b.org_id = 0);


INSERT INTO default_accounts (org_id, use_key_id, account_id)
SELECT b.org_id, a.use_key_id, b.account_id
FROM default_accounts a INNER JOIN accounts b ON a.account_id = b.account_no
WHERE (a.org_id = 0) AND (b.org_id = 1);


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


INSERT INTO task_types (org_id, task_type_name, default_cost, default_price)
SELECT 1, task_type_name, default_cost, default_price
FROM task_types
WHERE (org_id = 0);

UPDATE transaction_counters SET document_number = '10001';

UPDATE orgs SET employee_limit = 1000, transaction_limit = 1000000;
