UPDATE orgs SET org_name = 'OpenBaraza', cert_number = 'C.102554', pin = 'P051165288J', vat_number = '0142653A', 
default_country_id = 'KE', currency_id = 1,
org_full_name = 'OpenBaraza',
invoice_footer = 'Make all payments to : OpenBaraza
Thank you for your Business
We Turn your information into profitability'
WHERE org_id = 0;

UPDATE transaction_counters SET document_number = '10001';

INSERT INTO address (org_id, sys_country_id, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) 
VALUES (0, 'KE', 'orgs', 0, '45689', '00100', '12th Floor, Barclays Plaza', 'Loita Street', 'Nairobi', '+254 (20) 2227100/2243097', NULL, '+254 725 819505 or +254 738 819505', NULL, 'accounts@dewcis.com', 'www.dewcis.com', true, NULL, NULL);

UPDATE orgs SET employee_limit = 1000, transaction_limit = 1000000;

INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details, entity_id) 
VALUES (0, 1, '7777', 0, 0, 0, 0, 0, 'System', 'Admin', 'HCM', '1979-03-29', 'M', 'KE', 'S', '2012-02-09', NULL, NULL, true, 2, 'Full Time', 'Passport', 150000, '1234567890', NULL, true, 'English', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '5628', 2, 0, 0, 0, 0, 'Patibandla', 'Ramya', 'sree', '1990-10-15', 'F', 'KE', 'S', '2012-02-09', NULL, NULL, true, 2, 'Full Time', 'Passport', 50000, '1234567890', NULL, true, 'English', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '5513', 3, 0, 0, 0, 0, 'Pusapati', 'Varma', 'Narasimha', '1973-10-12', 'M', 'KE', 'M', '2011-08-29', NULL, NULL, true, 2, 'Full Time', 'Passport', 35000, '1234567890', '4pic.png', true, 'English', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '2512', 4, 0, 0, 0, 0, 'Kamanda', 'Edwin', 'Geke', '1982-05-06', 'M', 'KE', 'S', '2013-02-08', NULL, '2013-08-10', false, 12, NULL, 'erweewr', 20000, '22365336142', NULL, true, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '2592', 4, 0, 0, 0, 0, 'Kamau', 'Joseph', 'Wanjoki', '1977-10-16', 'M', 'KE', 'M', '2012-10-16', NULL, '2012-11-01', false, 0, NULL, '8098098098', 30000, '980809809', NULL, true, 'English', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '8783', 2, 0, 0, 0, 0, 'blackshamrat', 'Sazzadur ', 'Rahman', '1993-10-08', 'M', 'BD', 'S', '2013-10-08', NULL, NULL, false, 0, NULL, '269250', 116500, '101-105-12270', NULL, true, 'English , Bangla', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO employees (org_id, currency_id, employee_id, department_role_id, pay_scale_id, pay_group_id, location_id, bank_branch_id, surname, first_name, middle_name, date_of_birth, gender, nationality, marital_status, appointment_date, current_appointment, exit_date, contract, contract_period, employment_terms, identity_card, basic_salary, bank_account, picture_file, active, language, desg_code, inc_mth, previous_sal_point, current_sal_point, halt_point, interests, objective, details) 
VALUES (0, 1, '7551', 2, 0, 0, 0, 0, 'Ondero', 'Stanley', 'Makori', '2012-11-03', 'M', 'KE', 'M', '2013-05-01', NULL, NULL, false, 0, 'Parmanent and pensionable', '25145552', 100000, '0510191137356', NULL, false, 'English', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
UPDATE employees SET currency_id = 1;

INSERT INTO entity_subscriptions (entity_type_id, entity_id, org_id)
VALUES (1, 0, 0);

INSERT INTO default_adjustments (default_adjustment_id, entity_id, adjustment_id, org_id, amount, balance, final_date, active, narrative) VALUES (1, 4, 11, 0, 5000, 0, NULL, true, NULL);
INSERT INTO default_adjustments (default_adjustment_id, entity_id, adjustment_id, org_id, amount, balance, final_date, active, narrative) VALUES (2, 6, 11, 0, 5000, 0, NULL, true, NULL);
SELECT pg_catalog.setval('default_adjustments_default_adjustment_id_seq', 2, true);


INSERT INTO applicants (org_id, surname, first_name, middle_name, applicant_email, date_of_birth, gender, nationality, marital_status, picture_file, identity_card, language, interests, objective, details) 
VALUES (0, 'Joseph', 'Kamau', 'Karanja', 'joseph.kamau@obmails.com', '1974-07-05', 'M', 'KE', 'M', NULL, '79798797998', 'English', 'Programming, study, novels', 'Career development', NULL);
INSERT INTO applicants (org_id, surname, first_name, middle_name, applicant_email, date_of_birth, gender, nationality, marital_status, picture_file, identity_card, language, interests, objective, details) 
VALUES (0, 'Gichangi', 'Dennis', 'Wachira', 'dennisgichangi@gmail.com', '1979-03-29', 'M', 'KE', 'M', NULL, '7878787', 'English', NULL, NULL, NULL);

INSERT INTO entitys (entity_id, org_id, entity_type_id, entity_name, user_name, super_user, entity_leader, function_role, is_active, account_id, attention, use_key_id) 
VALUES (10, 0, 2, 'ABCD Kenya', 'abcd', false, false, 'client', true, 30000, 'Jane Kamango', 2);
INSERT INTO entitys (entity_id, org_id, entity_type_id, user_name, entity_name, primary_email,  account_id, use_key_id)
VALUES (11, 0, 3, 'XYZ Kenya', 'xyz', 'xyz@localhost',  40000, 3);

UPDATE entitys SET first_password = 'baraza';
SELECT pg_catalog.setval('entitys_entity_id_seq', 11, true);

INSERT INTO address (sys_country_id, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) 
VALUES ('KE', 'entitys', 10, '41010', '00100', 'Barclays Plaza, 7th Floor', 'Loita Street', 'Nairobi', '+254 20 3274233/5', NULL, NULL, NULL, 'info@abcdkenya.com', 'www.abcdkenya.com', true, NULL, NULL);
INSERT INTO address (sys_country_id, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) 
VALUES ('KE', 'entitys', 11, '41010', '00100', 'Barclays Plaza, 8th Floor', 'Loita Street', 'Nairobi', '+254 20 32742243', NULL, NULL, NULL, 'info@xyzkenya.com', 'www.xyzkenya.com', true, NULL, NULL);

INSERT INTO items (item_id, org_id, item_category_id, tax_type_id, item_unit_id, sales_account_id, purchase_account_id, item_name, bar_code, inventory, for_sale, for_purchase, sales_price, purchase_price, reorder_level, lead_time, is_active, details) VALUES (1, 0, 1, 2, 1, 70010, 80000, 'Domains', NULL, false, true, false, 5000, 0, NULL, NULL, true, NULL);
INSERT INTO items (item_id, org_id, item_category_id, tax_type_id, item_unit_id, sales_account_id, purchase_account_id, item_name, bar_code, inventory, for_sale, for_purchase, sales_price, purchase_price, reorder_level, lead_time, is_active, details) VALUES (2, 0, 1, 2, 1, 70010, 80000, 'Baraza HCMS', NULL, false, true, false, 0, 0, NULL, NULL, true, NULL);
INSERT INTO items (item_id, org_id, item_category_id, tax_type_id, item_unit_id, sales_account_id, purchase_account_id, item_name, bar_code, inventory, for_sale, for_purchase, sales_price, purchase_price, reorder_level, lead_time, is_active, details) VALUES (3, 0, 1, 2, 1, 70010, 80000, 'Systems Support', NULL, false, true, false, 0, 0, NULL, NULL, false, NULL);
INSERT INTO items (item_id, org_id, item_category_id, tax_type_id, item_unit_id, sales_account_id, purchase_account_id, item_name, bar_code, inventory, for_sale, for_purchase, sales_price, purchase_price, reorder_level, lead_time, is_active, details) VALUES (4, 0, 3, 2, 1, 70005, 95500, 'Office Rent', NULL, false, false, true, 0, 0, NULL, NULL, true, NULL);
INSERT INTO items (item_id, org_id, item_category_id, tax_type_id, item_unit_id, sales_account_id, purchase_account_id, item_name, bar_code, inventory, for_sale, for_purchase, sales_price, purchase_price, reorder_level, lead_time, is_active, for_stock) VALUES (5, 0, 2, 2, 1, 70005, 95500, 'Laptops', NULL, false, false, true, 0, 0, NULL, NULL, true, true);
SELECT pg_catalog.setval('items_item_id_seq', 5, true);


--- Create a default organisation client
INSERT INTO entitys (org_id, entity_type_id, use_key_id, user_name, entity_name, primary_email, first_password)
VALUES (0, 0, 0, 'dewcis', 'Dew CIS Solutions Ltd', 'root@dewcis.com', 'baraza');

INSERT INTO project_types (org_id, project_type_name) VALUES (0, 'Software Development');

INSERT INTO projects (project_type_id, entity_id, org_id, project_name, signed, start_date)
VALUES (currval('project_types_project_type_id_seq'), currval('entitys_entity_id_seq'), 0, 'Internal', true, '2017-01-01');
