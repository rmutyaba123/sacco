UPDATE orgs SET org_name = 'OpenBaraza', cert_number = 'C.102554', pin = 'P051165288J', vat_number = '0142653A', 
default_country_id = 'KE', currency_id = 1,
org_full_name = 'OpenBaraza',
invoice_footer = 'Make all payments to : Dew CIS Solutions ltd
Thank you for your Business
We Turn your information into profitability'
WHERE org_id = 0;

DELETE FROM currency WHERE currency_id > 1;

INSERT INTO banks (org_id, bank_id, bank_name) VALUES (0, 1, 'Safaricom');
INSERT INTO bank_branch (org_id, bank_branch_id, bank_id, bank_branch_name) VALUES (0, 1, 1, 'MPESA');

INSERT INTO investment_types (org_id, investment_type_name, interest_amount) VALUES
(0, 'Land', 10);

INSERT INTO investment_status (org_id, investment_status_name) VALUES 
(0, 'Proposal'),
(0, 'Rejected'),
(0, 'Commited'),
(0, 'Executed');

INSERT INTO account_definations (activity_type_id, charge_activity_id, activity_frequency_id, product_id, org_id, account_defination_name, start_date, end_date, fee_amount, account_number, is_active, has_charge) 
VALUES (21, 1, 1, 3, 0, 'Opening account', '2017-01-01', NULL, 300, '400000002', true, true);


INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id, user_name, entity_name, primary_email, entity_leader, super_user, no_org, first_password) VALUES
(11, 0, 7, 7, 'cyril', 'cyril', 'cyril@localhost', true, true, false, 'baraza'),
(12, 0, 7, 7, 'idi', 'idi', 'idi@localhost', true, true, false, 'baraza'),
(14, 0, 7, 7, 'edgak', 'edga k', 'edgak@localhost', true, true, false, 'baraza'),
(15, 0, 7, 7, 'bright', 'bright', 'bright@localhost', true, true, false, 'baraza');
SELECT pg_catalog.setval('entitys_entity_id_seq', 15, true);

INSERT INTO members (org_id, member_name, joining_date, gender, date_of_birth, id_number, phone_number, sales_agent_id) VALUES
(0, 'ASBETA ALIBASI MALENGE', '2017-07-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'ATAMBA CYNTHIA', '2017-07-01', 'F', '1985-01-06', '12345678', '0722222222', '11'),
(0, 'BEATRICE KAVAI ASELI', '2017-07-01', 'F', '1996-03-22', '12345678', '0722222222', '12'),
(0, 'BEVERLYNE MILOYO', '2017-07-01', 'F', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'BRENDA MWANISA', '2017-07-01', 'F', '1962-01-01', '12345678', '0722222222', '14'),
(0, 'BRIGHT NGAIRA MALEKWA ', '2017-07-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'CECIL MILA BARRY', '2017-07-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'CHAHILU VINCENT', '2017-07-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'CHARITY MUTHONI MWINGA', '2017-08-01', 'F', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'CHRISOSTIM WERE KHAMALA', '2017-08-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'CHRISTINE ROSE MUTHENGI', '2017-08-01', 'F', '1996-03-22', '12345678', '0722222222', '12'),
(0, 'CYRILLA ANNE SHIYAYO MAKATIANI', '2017-08-01', 'F', '1988-01-07', '12345678', '0722222222', '11'),
(0, 'CYRIUS NGAIRA LILECHI', '2017-08-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'DALTON CHEGERO', '2017-08-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'DENNIS ALUCHULA OBUNYAKHA', '2017-08-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'DONALD MUDAKI LOGOVA', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'DORTA ADIRA MALEKWA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '15'),
(0, 'DOUGLAS ADOLWA', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'EDGAR ASAVA KEVERENGE', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'ELAMWENYA IMINZA LUCY', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '12'),
(0, 'ERICK IKOLOMAN MAKATIANI', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'Esther Nyonje Akengo', '2017-09-01', 'F', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'EVALYN MUHAMBE', '2017-09-01', 'F', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'EVANS CHEGERO OBUNYU', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '12'),
(0, 'FAITH KAMAGA ADIRA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'FELIX JUMBA', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'FLORENCE GIYA KAGEHA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'FLORENCE LIBESE NAMBENYA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'FRANCIS KIDEMI', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'GADAFI GAMSA JUMA', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '12'),
(0, 'GILBERT SHIKOLI MAKATIANI', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'HUMPHREY ASUZA ', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'IDI RAMADHANI KIBULELIA', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'ISINGA SAMMY', '2017-09-01', 'M', '1983-05-05', '12345678', '0722222222', '14'),
(0, 'JACK KEVERENGE', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'JOHN MUSALIA MTAFUTA', '2017-09-01', 'M', '1982-05-31', '12345678', '0722222222', '12'),
(0, 'JOSEPHINE KADESA NYANDO', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'JOSEPHINE MAKATIANI NNANDI', '2017-09-01', 'F', '1955-01-01', '12345678', '0722222222', '11'),
(0, 'JOYCE ANN JUMBA', '2017-09-01', 'F', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'JUMBA MALEYA HUDSON', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '15'),
(0, 'Justice Robbian Mutungu', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'KIDIYA KADUVANE VIOLET', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '12'),
(0, 'KNIGHT KASIDI ASIGE', '2017-09-01', 'F', '1983-12-13', '12345678', '0722222222', '12'),
(0, 'MARGARET MUGONDA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'MARIA ATIAMUGA KISUTSA', '2017-09-01', 'F', '1987-04-18', '12345678', '0722222222', '12'),
(0, 'MARTIN OPIYO GWAMBO', '2017-09-01', 'M', '1983-09-10', '12345678', '0722222222', '11'),
(0, 'MARY MURANGI RUTERE', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'MASHETI CONRAD', '2017-09-01', 'M', '1983-06-06', '12345678', '0722222222', '11'),
(0, 'MCFARLEN KIVAIRU NGERESO', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '14'),
(0, 'MIHESO MAKATIANI CEDRIC', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'MONICA MUTUNGU KONZORO', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'MOSES KALWALE', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'MUKHUNJI MAKATIANI CYRIL', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11'),
(0, 'MUTANGE MMBONE ROSE', '2017-09-01', 'F', '1983-11-02', '12345678', '0722222222', '12'),
(0, 'MWALIMU ENDEGURE', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'NAIGHT KAVOSA ONZERE', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'NOAH DEMESI MWIRUKI', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'PETER OTIENO OKOTH', '2017-09-01', 'M', '1962-01-01', '12345678', '0722222222', '12'),
(0, 'ROSE KEDOGO MAHONGA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'ROSEMARY NYAMBURA KARIUKI', '2017-09-01', 'F', '1981-04-20', '12345678', '0722222222', '11'),
(0, 'SAKINA RABEKA ABDALLA', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'SAMMY ANANDA MUDIANGA', '2017-09-01', 'M', '1950-01-01', '12345678', '0722222222', '11'),
(0, 'Samwel Simiyu Wanyama', '2017-09-01', 'M', '1989-01-14', '12345678', '0722222222', '11'),
(0, 'SARAH KAHUGANE LLUMADEDE', '2017-09-01', 'F', '1962-01-01', '12345678', '0722222222', '11'),
(0, 'SCHWAZZENNIGAR NEWTON CHAGWI', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '15'),
(0, 'SHARON AKINYI ODHIAMBO', '2017-09-01', 'F', '1985-02-19', '12345678', '0722222222', '11'),
(0, 'THOMAS OYONDI KAVAI', '2017-09-01', 'M', '1953-01-29', '12345678', '0722222222', '11'),
(0, 'VIOLET MURENGEKA', '2017-09-01', 'F', '1996-03-22', '12345678', '0722222222', '14'),
(0, 'WILLIAM LIKOBELE MAKATIANI', '2017-09-01', 'M', '1996-03-22', '12345678', '0722222222', '11');


UPDATE members SET bank_branch_id = 1, nationality = 'KE', approve_status = 'Approved'; 


INSERT INTO deposit_accounts (org_id, entity_id, product_id, is_active, approve_status, opening_date)
SELECT org_id, entity_id, 3, true, 'Draft', joining_date
FROM members
WHERE (member_type = 1)
ORDER BY entity_id;

UPDATE deposit_accounts SET approve_status = 'Completed' WHERE entity_id > 2;

SELECT pg_catalog.setval('deposit_accounts_deposit_account_id_seq', 100, true);

