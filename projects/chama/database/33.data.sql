
--- Create use key types
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES 
(7, 'Sales Agents', 0),
(100, 'Member', 0),
(101, 'Receipts', 4),
(102, 'Payments', 4),
(103, 'Opening Account', 4),
(104, 'Transfer', 4),
(105, 'Loan Intrests', 4),
(106, 'Loan Penalty', 4),
(107, 'Loan Payment', 4),
(108, 'Loan Disbursement', 4),
(109, 'Account Intrests', 4),
(110, 'Account Penalty', 4),
(201, 'Initial Charges', 4),
(202, 'Transaction Charges', 4);

INSERT INTO entity_types (entity_type_id, org_id, use_key_id, entity_type_name, entity_role) VALUES (7, 0, 7, 'Sales Agent', 'salesagent');
INSERT INTO entity_types (entity_type_id, org_id, use_key_id, entity_type_name, entity_role) VALUES (10, 0, 100, 'Chama Member', 'member');
SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 10, true);

INSERT INTO collateral_types (org_id, collateral_type_name) VALUES 
(0, 'Land Title'),
(0, 'Car Log book');

INSERT INTO activity_frequency (activity_frequency_id, activity_frequency_name) 
VALUES (1, 'Once'), (4, 'Monthly');
--- (1, 'Once'), (2, 'Daily'), (3, 'Weekly'), (4, 'Monthly'), (5, 'Quartely'), (6, 'Half Yearly'), (7, 'Yearly');

INSERT INTO activity_status (activity_status_id, activity_status_name) VALUES 
(1, 'Completed'),
(2, 'UnCleared'),
(3, 'Processing'),
(4, 'Commited');


INSERT INTO activity_types (activity_type_id, cr_account_id, dr_account_id, use_key_id, org_id, activity_type_name, is_active) VALUES 
(1, 34005, 34005, 202, 0, 'No Charges', true),
(2, 34005, 34005, 101, 0, 'Cash Deposits', true),
(3, 34005, 34005, 101, 0, 'Cheque Deposits', true),
(4, 34005, 34005, 101, 0, 'MPESA Deposits', true),
(5, 34005, 34005, 102, 0, 'Cash Withdrawal', true),
(6, 34005, 34005, 102, 0, 'Cheque Withdrawal', true),
(7, 34005, 34005, 102, 0, 'MPESA Withdrawal', true),
(8, 70015, 34005, 105, 0, 'Loan Intrests', true),
(9, 70025, 34005, 106, 0, 'Loan Penalty', true),
(10, 34005, 34005, 107, 0, 'Loan Payment', true),
(11, 34005, 34005, 108, 0, 'Loan Disbursement', true),
(12, 34005, 34005, 104, 0, 'Account Transfer', true),
(14, 70015, 34005, 109, 0, 'Account Intrests', true),
(15, 70025, 34005, 110, 0, 'Account Penalty', true),
(21, 70020, 34005, 201, 0, 'Account opening charges', true),
(22, 70020, 34005, 202, 0, 'Transfer fees', true);
SELECT pg_catalog.setval('activity_types_activity_type_id_seq', 22, true);

INSERT INTO interest_methods (interest_method_id, activity_type_id, org_id, interest_method_name) VALUES (0, 8, 0, 'No Intrest');
INSERT INTO interest_methods (interest_method_id, activity_type_id, org_id, interest_method_name, formural, account_number, reducing_balance) VALUES (1, 8, 0, 'Loan reducing balance', 'get_intrest(1, loan_id, period_id)', '400000003', true);
INSERT INTO interest_methods (interest_method_id, activity_type_id, org_id, interest_method_name, formural, account_number) VALUES (2, 8, 0, 'Loan Fixed Intrest', 'get_intrest(2, loan_id, period_id)', '400000003');
INSERT INTO interest_methods (interest_method_id, activity_type_id, org_id, interest_method_name, formural, account_number) VALUES (3, 14, 0, 'Savings intrest', 'get_intrest(3, deposit_account_id, period_id)', '400000003');
INSERT INTO interest_methods (interest_method_id, activity_type_id, org_id, interest_method_name, formural, account_number, reducing_balance, reducing_payments) VALUES (4, 8, 0, 'Loan reducing balance and payments', 'get_intrest(1, loan_id, period_id)', '400000003', true, true);
SELECT pg_catalog.setval('interest_methods_interest_method_id_seq', 4, true);

INSERT INTO penalty_methods (penalty_method_id, activity_type_id, org_id, penalty_method_name)
VALUES (0, 9, 0, 'No penalty');
INSERT INTO penalty_methods (penalty_method_id, activity_type_id, org_id, penalty_method_name, formural, account_number)
VALUES (1, 9, 0, 'Loan Penalty 15', 'get_penalty(1, loan_id, period_id, 15)', '400000004');
INSERT INTO penalty_methods (penalty_method_id, activity_type_id, org_id, penalty_method_name, formural, account_number)
VALUES (2, 15, 0, 'Account Penalty 15', 'get_penalty(1, deposit_account_id, period_id, 15)', '400000004');
SELECT pg_catalog.setval('penalty_methods_penalty_method_id_seq', 2, true);

INSERT INTO products (product_id, activity_frequency_id, interest_method_id, penalty_method_id, currency_id, org_id, product_name, description, loan_account, is_active, interest_rate, min_opening_balance, minimum_balance, maximum_balance, minimum_day, maximum_day, minimum_trx, maximum_trx) VALUES
(0, 4, 0, 0, 1, 0, 'Chama', 'Chama', false, false, 0, 0, 0, 0, 0, 0, 0, 0),
(1, 4, 0, 0, 1, 0, 'Merry go round', 'Merry go round', false, true, 0, 0, 0, 0, 0, 0, 0, 0),
(2, 4, 1, 1, 1, 0, 'Basic loans', 'Basic loans', true, true, 20, 0, 0, 0, 0, 0, 0, 0),
(3, 4, 3, 0, 1, 0, 'Savings', 'To handle savings', false, true, 12, 0, 0, 0, 0, 0, 0, 0),
(4, 4, 2, 1, 1, 0, 'Compound loans', 'Compound loans', true, true, 20, 0, 0, 0, 0, 0, 0, 0),
(5, 4, 4, 1, 1, 0, 'Reducing balance loans', 'Reducing balance loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0);
SELECT pg_catalog.setval('products_product_id_seq', 5, true);


INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) VALUES 
(2, 1, 1, 0, 0, 'Cash Deposit', '2017-01-01', NULL, '400000001', true),
(3, 1, 1, 0, 0, 'Cheque Deposit', '2017-01-01', NULL, '400000001', true),
(4, 1, 1, 0, 0, 'MPESA Deposit', '2017-01-01', NULL, '400000001', true),
(5, 1, 1, 0, 0, 'Cash Withdraw', '2017-01-01', NULL, '400000001', true),
(6, 1, 1, 0, 0, 'Cheque Withdraw', '2017-01-01', NULL, '400000001', true),
(7, 1, 1, 0, 0, 'MPESA Withdraw', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) VALUES 
(2, 1, 1, 1, 0, 'Cash Deposit', '2017-01-01', NULL, '400000001', true),
(3, 1, 1, 1, 0, 'Cheque Deposit', '2017-01-01', NULL, '400000001', true),
(4, 1, 1, 1, 0, 'MPESA Deposit', '2017-01-01', NULL, '400000001', true),
(5, 1, 1, 1, 0, 'Cash Withdraw', '2017-01-01', NULL, '400000001', true),
(6, 1, 1, 1, 0, 'Cheque Withdraw', '2017-01-01', NULL, '400000001', true),
(7, 1, 1, 1, 0, 'MPESA Withdraw', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, fee_ps, account_number, is_active, has_charge) 
VALUES (12, 22, 1, 1, 0, 'Transfer', '2017-01-01', NULL, 1, '400000002', true, true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, fee_amount, account_number, is_active, has_charge) 
VALUES (21, 1, 1, 1, 0, 'Opening account', '2017-01-01', NULL, 1000, '400000002', true, true);

INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (11, 1, 1, 2, 0, 'Loan Disbursement', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (10, 1, 1, 2, 0, 'Loan Payment', '2017-01-01', NULL, '400000001', true);

INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) VALUES 
(2, 1, 1, 3, 0, 'Cash Deposit', '2017-01-01', NULL, '400000001', true),
(3, 1, 1, 3, 0, 'Cheque Deposit', '2017-01-01', NULL, '400000001', true),
(4, 1, 1, 3, 0, 'MPESA Deposit', '2017-01-01', NULL, '400000001', true),
(5, 1, 1, 3, 0, 'Cash Withdraw', '2017-01-01', NULL, '400000001', true),
(6, 1, 1, 3, 0, 'Cheque Withdraw', '2017-01-01', NULL, '400000001', true),
(7, 1, 1, 3, 0, 'MPESA Withdraw', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, fee_ps, account_number, is_active, has_charge) 
VALUES (12, 22, 1, 3, 0, 'Transfer', '2017-01-01', NULL, 1, '400000002', true, true);

INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (11, 1, 1, 4, 0, 'Loan Disbursement', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (10, 1, 1, 4, 0, 'Loan Payment', '2017-01-01', NULL, '400000001', true);

INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (11, 1, 1, 5, 0, 'Loan Disbursement', '2017-01-01', NULL, '400000001', true);
INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, account_number, is_active) 
VALUES (10, 1, 1, 5, 0, 'Loan Payment', '2017-01-01', NULL, '400000001', true);


--- Create Initial customer and customer account
INSERT INTO members (entity_id, org_id, member_name, id_number, email, phone_number, date_of_birth, nationality, approve_status, member_type, joining_date)
VALUES (2, 0, 'OpenBaraza Chama', '0', 'info@openbaraza.org', '+254', '2017-01-01', 'KE', 'Approved', 0, '2017-01-01');

INSERT INTO deposit_accounts (entity_id, product_id, org_id, is_active, approve_status, narrative, account_number, minimum_balance) VALUES 
(2, 0, 0, true, 'Approved', 'Deposits', '400000001', -100000000000),
(2, 0, 0, true, 'Approved', 'Charges', '400000002', -100000000000),
(2, 0, 0, true, 'Approved', 'Interest', '400000003', -100000000000),
(2, 0, 0, true, 'Approved', 'Penalty', '400000004', -100000000000),
(2, 0, 0, true, 'Approved', 'Investment', '400000005', -100000000000);

SELECT pg_catalog.setval('entitys_entity_id_seq', 3, true);


---- Workflow setup

INSERT INTO workflows (workflow_id, org_id, source_entity_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, details) VALUES 
(20, 0, 10, 'Member Application', 'members', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL),
(21, 0, 10, 'Account opening', 'deposit_accounts', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL),
(22, 0, 10, 'Loan Application', 'loans', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL),
(23, 0, 0, 'Guarantees Application', 'guarantees', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL),
(24, 0, 0, 'Collaterals Application', 'collaterals', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL);
SELECT pg_catalog.setval('workflows_workflow_id_seq', 30, true);

INSERT INTO workflow_phases (workflow_phase_id, org_id, workflow_id, approval_entity_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES
(20, 0, 20, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL),
(21, 0, 21, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL),
(22, 0, 22, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL),
(23, 0, 23, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL),
(24, 0, 24, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 30, true);

