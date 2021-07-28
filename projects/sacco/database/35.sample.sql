UPDATE orgs SET org_name = 'Dew CIS Solutions Ltd', cert_number = 'C.102554', pin = 'P051165288J', vat_number = '0142653A', 
default_country_id = 'KE', currency_id = 1,
org_full_name = 'Dew CIS Solutions Ltd',
invoice_footer = 'Make all payments to : Dew CIS Solutions ltd
Thank you for your Business
We Turn your information into profitability'
WHERE org_id = 0;



INSERT INTO members (member_id, entity_id, org_id, business_account, person_title, member_name, identification_number, identification_type, member_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES (1, 0, 0, 0, 'Mr', 'Peter Mwangi', '302589631', 'ID', 'peter@peter.me.ke', '797897897', NULL, '0725741369', 'Nairobi', NULL, '2010-06-08', 'M', 'KE', 'S', NULL, true, false, 'Dew CIS Solutions Ltd', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:14:49.971406', 'Completed', 2, '2017-06-07 15:09:33.906413', NULL);
INSERT INTO members (member_id, entity_id, org_id, business_account, person_title, member_name, identification_number, identification_type, member_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES (3, 0, 0, 0, 'Miss', 'Dorcas Mwigereri', '258741369', 'ID', 'dorcusmwigereri@gmail.com', '0708066768', NULL, '3698547', 'Nairobi', '00200', '1993-06-09', 'F', 'KE', 'S', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Completed', 3, '2017-06-07 15:09:33.922914', NULL);


SELECT pg_catalog.setval('members_member_id_seq', 3, true);

DELETE FROM currency WHERE currency_id IN (2, 3, 4);
