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

INSERT INTO customers (customer_id, entity_id, org_id, business_account, person_title, customer_name, identification_number, identification_type, client_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES (1, 0, 0, 0, 'Mr', 'Dennis Wachira Gichangi', '787897897', 'ID', 'dennis@dennis.me.ke', '797897897', NULL, '23423', 'Nairobi', NULL, '2010-06-08', 'M', 'KE', 'M', NULL, true, false, 'Dew CIS Solutions Ltd', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:14:49.971406', 'Approved', 2, '2017-06-07 15:09:33.906413', NULL);
INSERT INTO customers (customer_id, entity_id, org_id, business_account, person_title, customer_name, identification_number, identification_type, client_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES (3, 0, 0, 0, 'Mrs', 'Rachel Mogire', '9898989', 'ID', 'rachel@gmail.com', '79878977', NULL, '778778', 'Nairobi', '00100', '1980-02-05', 'F', 'KE', 'M', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Approved', 3, '2017-06-07 15:09:33.922914', NULL);
INSERT INTO customers (customer_id, entity_id, org_id, business_account, person_title, customer_name, identification_number, identification_type, client_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES (2, 0, 0, 1, NULL, 'Dew CIS Solutions Ltd', 'C7878978', 'Certificate', 'info@dewcis.com', '797897897', NULL, '23423', 'Nairobi', '00100', '2014-06-10', NULL, 'KE', NULL, NULL, true, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:15:24.095569', 'Approved', 1, '2017-06-07 15:09:33.88081', NULL);


SELECT pg_catalog.setval('customers_customer_id_seq', 3, true);

DELETE FROM currency WHERE currency_id IN (2, 3, 4);
