


DELETE FROM numbers_imports;

INSERT INTO numbers_imports (address_group_id, number_name, mobile_number) VALUES (7, 'ANNIE KAMAU', '724394779');
INSERT INTO numbers_imports (address_group_id, number_name, mobile_number) VALUES (12, 'KATE KAGIRI', '720774304');

UPDATE numbers_imports SET mobile_number = trim(replace(mobile_number, '-', ''));
UPDATE numbers_imports SET mobile_number = '254' || trim(replace(mobile_number, ' ', ''));


-------------------------

SELECT *
FROM numbers_imports
WHERE length(mobile_number) <> 12

SELECT mobile_number, max(numbers_import_id)
FROM numbers_imports
GROUP BY mobile_number
HAVING count(numbers_import_id) > 1

--------------------------

DELETE FROM numbers_imports
WHERE numbers_import_id IN
(SELECT numbers_import_id
FROM numbers_imports
WHERE length(mobile_number) <> 12);


DELETE FROM numbers_imports
WHERE numbers_import_id IN
(SELECT max(numbers_import_id)
FROM numbers_imports
GROUP BY mobile_number
HAVING count(numbers_import_id) > 1);

INSERT INTO address (org_id, address_type_id, sys_country_id, address_name, table_name, mobile)
SELECT 2, 1, 'KE', numbers_imports.number_name, 'sms', numbers_imports.mobile_number
FROM numbers_imports LEFT JOIN address ON numbers_imports.mobile_number = address.mobile
WHERE (address.mobile is null);

DELETE FROM address_members WHERE address_group_id = 12;
INSERT INTO address_members (address_group_id, address_id, org_id, is_active)
SELECT numbers_imports.address_group_id, address.address_id, address.org_id, true
FROM numbers_imports INNER JOIN address ON numbers_imports.mobile_number = address.mobile;





