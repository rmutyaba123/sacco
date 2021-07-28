INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES 
(6, 'Tenants', 0),
(7, 'Landlord', 0),
(8, 'Agency', 0),
(101, 'Payments', 0),
(102, 'Receipts', 0),
(103, 'Commissions', 0),
(104, 'Rent Payments', 0),
(105, 'Rent Remmitance', 0),
(106, 'Rent Penalty', 0),
(107, 'Transfer', 0),
(108, 'Lease Billing', 0),
(109, 'Rental Billing', 0),
(110, 'Property Billing', 0); 

--- Entity types
INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id) VALUES 
(0, 'Tenants', 'tenants', 6),
(0, 'Landlord', 'landlord', 7),
(0, 'Agency', 'agency', 8);

---payment frequency defination
INSERT INTO payment_frequency (activity_frequency_id, activity_frequency_name) 
VALUES (1, 'Once'), (4, 'Monthly'), (7, 'Yearly');
--- (1, 'Once'), (2, 'Daily'), (3, 'Weekly'), (4, 'Monthly'), (5, 'Quartely'), (6, 'Half Yearly');

---payment status defination
INSERT INTO payment_status (activity_status_id, activity_status_name) VALUES 
(1, 'Completed'), 
(2, 'UnCleared'), 
(3, 'Processing'), 
(4, 'Commited');

--- Property Types
INSERT INTO property_types (org_id, property_type_name) VALUES 
(0, 'Apartments'),
(0, 'Offices'),
(0, 'Land');

--- Property Transaction Typea
INSERT INTO property_trxs_types (property_trxs_type_id, property_trxs_name,property_trxs_no) VALUES 
(1, 'For Rental','1'),
(2, 'For Lease','2'),
(3, 'For Sale','3');

--- property amenities
INSERT INTO property_amenity (org_id, amenity_name) VALUES 
(0, 'Parking'),
(0, 'wifi/internet'),
(0, 'CCTV');

---Commission Type
INSERT INTO commission_types (org_id,commission_name) VALUES
(0, 'Tenant Sourcing'),
(0, 'Rent Collection'),
(0, 'Deposit Management'),
(0, 'property Inspection'),
(0, 'Repair Assessment');

---Unit Types
INSERT INTO unit_types (org_id,unit_type_name) VALUES
(0, 'Single room'),
(0, 'Double Room'),
(0, 'Bedsitter'),
(0, 'One Bedroom'),
(0, 'Two Bedroom'),
(0, 'Three Bedroom'),
(0, 'Bungalow'),
(0, 'Mansion'),
(0, 'Maisonette'),
(0, 'Villa');


--- Payment Types
INSERT INTO payment_types (payment_type_id, account_id, use_key_id, org_id, payment_type_name, is_active, details) VALUES 
(2, 34005, 104, 0, 'Rent Payment', true, NULL),
(3, 42010, 105, 0, 'Rent Remmitance', true, NULL),
(4, 34005, 106, 0, 'Rental Penalty Payment', true, NULL),
(5, 34005, 109, 0, 'Rental Billing', true, NULL),
(6, 70020, 103, 0, 'Commission', true, NULL),
(7, 34005, 108, 0, 'Lease Billing', true, NULL),
(8, 34005, 110, 0, 'Property Billing', true, NULL);

SELECT pg_catalog.setval('payment_types_payment_type_id_seq', 8, true);

--- workflows
INSERT INTO workflows (workflow_id, org_id, source_entity_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, details) 
VALUES (21, 0, 0, 'Property Lease', 'property_lease', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL);

SELECT pg_catalog.setval('workflows_workflow_id_seq', 30, true);

INSERT INTO workflow_phases (workflow_phase_id, org_id, workflow_id, approval_entity_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) 
VALUES (21, 0, 21, 0, 1, 0, 0, 3, 1, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 30, true);