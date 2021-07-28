
INSERT INTO kin_types (org_id, kin_type_name) VALUES 
(0, 'Wife'),
(0, 'Husband'),
(0, 'Daughter'),
(0, 'Son'),
(0, 'Mother'),
(0, 'Father'),
(0, 'Brother'),
(0, 'Sister'),
(0, 'Others');

INSERT INTO education_class (org_id, education_class_id, education_class_name) VALUES 
(0, 1, 'Primary School'),
(0, 2, 'Secondary School'),
(0, 3, 'High School'),
(0, 4, 'Certificate'),
(0, 5, 'Diploma'),
(0, 6, 'Profesional Qualifications'),
(0, 7, 'Higher Diploma'),
(0, 8, 'Under Graduate'),
(0, 9, 'Post Graduate');
SELECT pg_catalog.setval('education_class_education_class_id_seq', 9, true);

INSERT INTO pay_scales (org_id, pay_scale_id, pay_scale_name, min_pay, max_pay) VALUES (0, 0, 'Basic', 0, 1000000);
INSERT INTO locations (org_id, location_id, location_name) VALUES (0, 0, 'Main office');
INSERT INTO pay_groups (org_id, pay_group_id, pay_group_name, gl_payment_account) VALUES (0, 0, 'Default', '40055');

INSERT INTO departments (org_id, department_id, ln_department_id, department_name) VALUES 
(0, 1, 0, 'Human Resources and Administration'),
(0, 2, 0, 'Sales and Marketing'),
(0, 3, 0, 'Finance'),
(0, 4, 4, 'Procurement');
SELECT pg_catalog.setval('departments_department_id_seq', 5, true);

INSERT INTO objective_types (org_id, objective_type_name) VALUES (0, 'General');

INSERT INTO department_roles (org_id, department_role_id, department_id, ln_department_role_id, department_role_name, active, job_description, job_requirements, duties, performance_measures, details) VALUES (0, 1, 0, 0, 'Chief Executive Officer', true, '- Defining short term and long term corporate strategies and objectives
- Direct overall company operations ', NULL, '- Develop and control strategic relationships with third-party companies
- Guide the development of client specific systems
- Provide leadership and monitor team performance and individual staff performance ', NULL, NULL);
INSERT INTO department_roles (org_id, department_role_id, department_id, ln_department_role_id, department_role_name, active, job_description, job_requirements, duties, performance_measures, details) VALUES (0, 2, 1, 0, 'Director, Human Resources', true, '- To direct and guide projects support services
- Train end client users 
- Provide leadership and monitor team performance and individual staff performance ', NULL, NULL, NULL, NULL);
INSERT INTO department_roles (org_id, department_role_id, department_id, ln_department_role_id, department_role_name, active, job_description, job_requirements, duties, performance_measures, details) VALUES (0, 3, 2, 0, 'Director, Sales and Marketing', true, '- To direct and guide in systems and products development.
- Provide leadership and monitor team performance and individual staff performance ', NULL, NULL, NULL, NULL);
INSERT INTO department_roles (org_id, department_role_id, department_id, ln_department_role_id, department_role_name, active, job_description, job_requirements, duties, performance_measures, details) VALUES (0, 4, 3, 0, 'Director, Finance', true, '- To direct and guide projects implementation
- Train end client users 
- Provide leadership and monitor team performance and individual staff performance ', NULL, NULL, NULL, NULL);
SELECT pg_catalog.setval('department_roles_department_role_id_seq', 9, true);

INSERT INTO skill_category (org_id, skill_category_id, skill_category_name, details) VALUES 
(0, 0, 'Others', NULL),
(0, 1, 'HARDWARE', NULL),
(0, 2, 'OPERATING SYSTEM', NULL),
(0, 3, 'SOFTWARE', NULL),
(0, 4, 'NETWORKING', NULL),
(0, 6, 'SERVERS', NULL),
(0, 8, 'COMMUNICATION/MESSAGING SUITE', NULL),
(0, 9, 'VOIP', NULL),
(0, 10, 'DEVELOPMENT', NULL);
SELECT pg_catalog.setval('skill_category_skill_category_id_seq', 10, true);
UPDATE skill_category SET skill_category_name =  initcap(skill_category_name);

INSERT INTO skill_types (skill_type_id, skill_category_id, skill_type_name, basic, intermediate, advanced, details) VALUES 
(0, 0, 'Indicate Your Skill', null, null, null, null),
(1, 1, 'Personal Computer', 'Identify the different components of a computer', 'Understand the working of each component', 'Troubleshoot, Diagonize and Repair', NULL),
(2, 1, 'Dot Matrix Printer', 'Identify the different components of a computer', 'Understand the working of each component', 'Troubleshoot, Diagonize and Repair', NULL),
(3, 1, 'Ticket Printer', 'Identify the different components of a computer', 'Understand the working of each component', 'Troubleshoot, Diagonize and Repair', NULL),
(4, 1, 'HP Printer', 'Identify the different components of a computer', 'Understand the working of each component', 'Troubleshoot, Diagonize and Repair', NULL),
(5, 2, 'DOS', 'Installation', 'Configuration', 'Troubleshooting and Support', NULL),
(6, 2, 'WindowsXP', 'Installation', 'Configuration', 'Troubleshooting and Support', NULL),
(7, 2, 'Linux', 'Installation', 'Configuration', 'Troubleshooting and Support', NULL),
(8, 2, 'Solaris UNIX', 'Installation', 'Configuration', 'Troubleshooting and Support', NULL),
(10, 3, 'Office', 'Installation, Backup and Recovery', 'Application and Usage', 'Advanced Usage', NULL),
(11, 3, 'Browsing', 'Setup ', 'Usage ', 'Troubleshooting and Support', NULL),
(12, 3, 'Galileo Products', 'Setup ', 'Usage ', 'Troubleshooting and Support', NULL),
(13, 3, 'Antivirus', 'Setup ', 'Updates and Support', 'Troubleshooting and Support', NULL),
(9, 3, 'Dialup', 'Installation', 'Configuration', 'Troubleshooting and Support', NULL),
(21, 4, 'Dialup', 'Dialup', 'Configuration', 'Troubleshooting and Support', NULL),
(22, 4, 'LAN', 'Installation ', 'Configuration', 'Troubleshooting and Support', NULL),
(23, 4, 'WAN', 'Installation', 'Configuration', 'Configuration', NULL),
(29, 6, 'SAMBA', NULL, NULL, NULL, NULL),
(30, 6, 'MAIL', NULL, NULL, NULL, NULL),
(31, 6, 'WEB', NULL, NULL, NULL, NULL),
(32, 6, 'APPLICATION ', NULL, NULL, NULL, NULL),
(33, 6, 'IDENTITY MANAGEMENT', NULL, NULL, NULL, NULL),
(34, 6, 'NETWORK MANAGEMENT   ', NULL, NULL, NULL, NULL),
(36, 6, 'BACKUP AND STORAGE SERVICES', NULL, NULL, NULL, NULL),
(37, 8, 'GROUPWARE', NULL, NULL, NULL, NULL),
(38, 9, 'ASTERIX', NULL, NULL, NULL, NULL),
(39, 10, 'DATABASE', NULL, NULL, NULL, NULL),
(40, 10, 'DESIGN', NULL, NULL, NULL, NULL),
(41, 10, 'BARAZA', NULL, NULL, NULL, NULL),
(42, 10, 'CODING JAVA', NULL, NULL, NULL, NULL);
SELECT pg_catalog.setval('skill_types_skill_type_id_seq', 42, true);
UPDATE skill_types SET skill_type_name =  initcap(skill_type_name), org_id = 0;

INSERT INTO adjustment_effects (adjustment_effect_id, adjustment_effect_type, adjustment_effect_name) VALUES 
(1, 1, 'General Allowance'),
(2, 2, 'General Deductions'),
(3, 3, 'General Expences'),
(4, 1, 'Housing Allowance'),
(5, 1, 'Transport Allowance');

INSERT INTO adjustments (adjustment_type, adjustment_id, adjustment_Name, Visible, In_Tax, account_number) VALUES 
(1, 1, 'Sacco Allowance', true, true, '90005'),
(1, 2, 'Bonus', true, true, '90005');

INSERT INTO adjustments (adjustment_type, adjustment_id, adjustment_Name, in_payroll, Visible, In_Tax, account_number) 
VALUES (1, 3, 'Employer - Pension', false, true, false, '90005');

INSERT INTO adjustments (adjustment_type, adjustment_id, adjustment_Name, Visible, In_Tax, account_number) VALUES 
(2, 11, 'SACCO', true, false, '40055'),
(2, 12, 'HELB', true, false, '40055'),
(2, 13, 'Rent Payment', true, false, '40055'),
(2, 14, 'Pension deduction', true, false, '40055'),
(2, 15, 'Internal loans', true, false, '40055'),
(3, 21, 'Travel', true, false, '90070'),
(3, 22, 'Communcation', true, false, '90070'),
(3, 23, 'Tools', true, false, '90070'),
(3, 24, 'Payroll Cost', true, false, '90070'),
(3, 25, 'Health Insurance', false, false, '90070'),
(3, 26, 'GPA Insurance', false, false, '90070'),
(3, 27, 'Accomodation', true, false, '90070'),
(3, 28, 'Avenue Health Care', false, false, '90070'),
(3, 29, 'Maternety Cost', true, false, '90070'),
(3, 30, 'Health care claims', true, false, '90070'),
(3, 31, 'Trainining', true, false, '90070'),
(3, 32, 'per diem', true, false, '90070');
SELECT pg_catalog.setval('adjustments_adjustment_id_seq', 32, true);
UPDATE adjustments SET org_id = 0, currency_id = 1, adjustment_effect_id = adjustment_type;

INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (11, 'Payroll Tax', 1);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (12, 'Payroll Statutory', 1);

INSERT INTO tax_types (tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, account_number, employer_account) VALUES 
(1, 11, 'PAYE', 'Get_Employee_Tax(employee_tax_type_id, 2)', 1408, 1, false, true, true, 0, 0, true, '40045', '40045'),
(2, 12, 'NSSF', 'Get_Employee_Tax(employee_tax_type_id, 1)', 0, 0, true, true, true, 0, 0, true, '40030', '40030'),
(3, 12, 'NHIF', 'Get_Employee_Tax(employee_tax_type_id, 1)', 0, 0, false, false, false, 0, 0, true, '40035', '40035'),
(4, 11, 'FULL PAYE', 'Get_Employee_Tax(employee_tax_type_id, 2)', 0, 0, false, false, false, 0, 0, false, '40045', '40045');
SELECT pg_catalog.setval('tax_types_tax_type_id_seq', 4, true);
UPDATE tax_types SET org_id = 0;

INSERT INTO tax_rates (tax_type_id, tax_range, tax_rate) VALUES 
(1, 12298, 10),
(1, 23885, 15),
(1, 35472, 20),
(1, 47059, 25),
(1, 10000000, 30),
(2, 18000, 6),
(2, 10000000, 0),
(3, 5999, 150),
(3, 7999, 300),
(3, 11999, 400),
(3, 14999, 500),
(3, 19999, 600),
(3, 24999, 750),
(3, 29999, 850),
(3, 34999, 900),
(3, 39999, 950),
(3, 44999, 1000),
(3, 49999, 1100),
(3, 59999, 1200),
(3, 69999, 1300),
(3, 79999, 1400),
(3, 89000, 1500),
(3, 99000, 1600),
(3, 10000000, 1700),
(4, 10000000, 30);

UPDATE Tax_Rates SET org_id = 0;

INSERT INTO sys_emails (sys_email_id, use_type, org_id, sys_email_name, title, details) VALUES
(1, 1, 0, 'Application', 'Thank you for your Application', 'Thank you {{name}} for your application.<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>'),
(2, 2, 0, 'New Staff', 'HR Your credentials ', 'Hello {{name}},<br><br>
Your credentials to the HR system have been created.<br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>'),
(3, 3, 0, 'Password reset', 'Password reset', 'Hello {{name}},<br><br>
Your password has been reset to:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>'),
(4, 4, 0, 'Subscription', 'Subscription', 'Hello {{name}},<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Your password is:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards,<br>
OpenBaraza<br>'),
(5, 5, 0, 'Subscription', 'Subscription', 'Hello {{name}},<br><br>
Your OpenBaraza SaaS Platform application has been approved<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Regards,<br>
OpenBaraza<br>'),
(7, 7, 0, 'Payroll Generated', 'Payroll Generated', 'Hello {{name}},<br><br>
They payroll has been generated for {{narrative}}<br><br>
Regards,<br>
HR Manager<br>'),
(8, 8, 0, 'Have a Happy Birthday', 'Have a Happy Birthday', 'Happy Birthday {{name}},<br><br>
A very happy birthday to you.<br><br>
Regards,<br>
HR Manager<br>'),
(9, 9, 0, 'Happy Birthday', 'Happy Birthday', 'Hello HR,<br><br>
{{narrative}}.<br><br>
Regards,<br>
HR Manager<br>'),
(10, 10, 0, 'Job Application - acknowledgement', 'Job Application', 'Hello {{name}},<br><br>
We acknowledge receipt of your job application for {{job}}<br><br>
Regards,<br>
HR Manager<br>'),
(11, 11, 0, 'Internship Application - acknowledgement', 'Job Application', 'Hello {{name}},<br><br>
We acknowledge receipt of your Internship application<br><br>
Regards,<br>
HR Manager<br>'),
(12, 12, 0, 'Contract Ending', 'Contract Ending - {{entity_name}}', 'Hello,<br><br>
Kindly note that the contract for {{entity_name}} is due to employment.<br><br>
Regards,<br>
HR Manager<br>'),
(14, 14, 0, 'Interview Invitation', 'Invitation for an Interview', 'Hello {{name}},<br><br>
Thank you for your interest in working for us.<br>
Following your application for the above post, you have been selected for the interview<br><br>
Regards,<br>
HR Manager<br>');
SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 14, true);

INSERT INTO contract_status (org_id, contract_status_name) VALUES 
(0, 'Active'),
(0, 'Resigned'),
(0, 'Deceased'),
(0, 'Terminated'),
(0, 'Transferred');

INSERT INTO contract_types (org_id, contract_type_name) VALUES 
(0, 'Default');

INSERT INTO skill_levels (org_id, skill_level_name) VALUES 
(0, 'Basic'),
(0, 'Intermediate'),
(0, 'Advanced');

INSERT INTO interview_types (org_id, interview_type_name, is_active) VALUES 
(0, 'Default', true);

INSERT INTO industry (org_id, industry_name) VALUES 
(0, 'Aerospace'),
(0, 'Agriculture'),
(0, 'Automotive'),
(0, 'Business and Consultancy Services'),
(0, 'ICT - Reseller'),
(0, 'ICT - Services and Consultancy'),
(0, 'ICT - Manufacturer'),
(0, 'ICT - Software Development'),
(0, 'Investments'),
(0, 'Education'),
(0, 'Electronics'),
(0, 'Finance, Banking, Insurance'),
(0, 'Government - National or Federal'),
(0, 'Government - State, Country or Local'),
(0, 'Healthcare'),
(0, 'Hotel and Leisure'),
(0, 'Legal'),
(0, 'Manufacturing'),
(0, 'Media, Marketing, Entertainment, Publishing, PR'),
(0, 'Real Estate'),
(0, 'Retail, Wholesale'),
(0, 'Telecoms'),
(0, 'Transportation and Distribution'),
(0, 'Travel and Tours'),
(0, 'Other');

INSERT INTO jobs_category (org_id, jobs_category) VALUES 
(0, 'Accounting'),
(0, 'Banking and Financial Services'),
(0, 'CEO'),
(0, 'General Management'),
(0, 'Creative and Design'),
(0, 'Customer Service and Call Centre'),
(0, 'Education and Training'),
(0, 'Engineering and Construction'),
(0, 'Farming and Agribusiness'),
(0, 'Government'),
(0, 'Healthcare and Pharmaceutical'),
(0, 'Human Resources'),
(0, 'Insurance'),
(0, 'ICT'),
(0, 'Telecoms'),
(0, 'Legal'),
(0, 'Manufacturing'),
(0, 'Marketing, Media and Brand'),
(0, 'NGO, Community and Social Development'),
(0, 'Office and Administration'),
(0, 'Project and Programme Management'),
(0, 'Research, Science and Biotech'),
(0, 'Retail'),
(0, 'Sales'),
(0, 'Security'),
(0, 'Strategy and Consulting'),
(0, 'Tourism and Travel'),
(0, 'Trades and Services'),
(0, 'Transport and Logistics'),
(0, 'Internships and Volunteering'),
(0, 'Real Estate'),
(0, 'Hospitality'),
(0, 'Other');

INSERT INTO leave_types (org_id, leave_type_id, leave_type_name, allowed_leave_days, leave_days_span, use_type)
VALUES (0, 0, 'Annual Leave', 21, 7, 1);

INSERT INTO loan_types(loan_type_id, adjustment_id, org_id, loan_type_name, default_interest, reducing_balance)
VALUES (0, 15, 0, 'Emergency', 6, true);

INSERT INTO products (org_id, product_name, annual_cost, details) 
VALUES (0, 'HCM Hosting per employee', 200, 'HR and Payroll Hosting per employee per year');

INSERT INTO receipt_sources (org_id, receipt_source_name) VALUES 
(0, 'MPESA'),
(0, 'Cash'),
(0, 'Cheque');

INSERT INTO review_category (review_category_id, org_id, review_category_name) VALUES (0, 0, 'Annual Review');

INSERT INTO task_types (task_type_id, org_id, task_type_name, default_cost, default_price)
VALUES (0, 0, 'Default', 0, 0);

INSERT INTO travel_types (org_id, travel_type_name) VALUES 
(0, 'Conference'),
(0, 'Site Visit'),
(0, 'Seminar'),
(0, 'Workshop'),
(0, 'Training'),
(0, 'Official duty');

INSERT INTO travel_funding (org_id, travel_funding_name, require_details) VALUES
(0, 'Organisation Core', false),
(0, 'Project (Specify)', true),
(0, 'Other Institution (specify)', true),
(0, 'Partly personal (specify)', true);

INSERT INTO claim_types (adjustment_id, org_id, claim_type_name) VALUES
(21, 0, 'Travel Claim');

INSERT INTO travel_agencys (travel_agency_id, org_id, travel_agency_name) VALUES
(0, 0, 'Others');

