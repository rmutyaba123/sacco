
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (7, 'Applicants', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (8, 'Students', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (9, 'Lecturers', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (10, 'Guardian', 0);

INSERT INTO entity_types (org_id, entity_type_name, entity_role, entity_type_id, use_key_id) VALUES (0, 'Applicants', 'applicant', 7, 7);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, entity_type_id, use_key_id) VALUES (0, 'Students', 'student', 8, 8);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, entity_type_id, use_key_id) VALUES (0, 'Lecturers', 'lecturer', 9, 9);
INSERT INTO entity_types (org_id, entity_type_name, entity_role, entity_type_id, use_key_id) VALUES (0, 'Guardian', 'guardian', 10, 10);

INSERT INTO continents (continentid, continentname)
SELECT sys_continent_id, sys_continent_name
FROM sys_continents
ORDER BY sys_continent_id;


INSERT INTO countrys (countryid, continentid, countryname)
SELECT sys_country_id, sys_continent_id, sys_country_name
FROM sys_countrys
ORDER BY sys_continent_id, sys_country_id;


