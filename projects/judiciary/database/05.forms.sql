INSERT INTO forms (form_id, org_id, form_name, form_number, version, completed, is_active, form_header, form_footer, details) VALUES (7, 0, 'ACKNOWLEDGEMENT OF RECEIPT OF A PETITION', 'FORM EP 1', '1', '0', '0', NULL, NULL, NULL);

SELECT setval('forms_form_id_seq', 10);

INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (90, 0, 7, 'Received on the ', NULL, 'TEXTFIELD', NULL, '0', '0', 10, 10, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (91, 0, 7, 'at the Registry of the High /Magistrate Court, a petition concerning the election of', NULL, 'TEXTFIELD', NULL, '0', '0', 20, 20, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (92, 0, 7, 'for', NULL, 'TEXTFIELD', NULL, '0', '0', 30, 30, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (93, 0, 7, 'purporting to be singed by ', NULL, 'TEXTFIELD', NULL, '0', '0', 40, 30, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (94, 0, 7, 'Registrar (or other to whom the petition is delivered)', NULL, 'TEXTFIELD', NULL, '0', '0', 50, 40, 25, '0', '1'); 

SELECT setval('fields_field_id_seq', 100);


