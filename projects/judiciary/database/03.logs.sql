CREATE TABLE log_cases (
	log_case_id				serial primary key,
	case_id					integer,
	case_category_id		integer,
	court_division_id		integer,
	file_location_id		integer,
	case_subject_id			integer,
	police_station_id		integer,
	new_case_id				integer,
	old_case_id				integer,
	constituency_id			integer,
	ward_id					integer,
	org_id					integer,
	case_title				varchar(320),
	file_number				varchar(50),
	date_of_arrest			date,
	ob_number				varchar(120),
	holding_prison			varchar(120),
	warrant_of_arrest		boolean default false not null,
	alleged_crime			text,
	date_of_elections		date,
	start_date				date not null,
	end_date				date,
	nature_of_claim			varchar(320),
	value_of_claim			real,
	closed					boolean default false not null,
	case_locked				boolean default false not null,
	final_decision	 		varchar(1024),
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	detail					text
);
CREATE INDEX log_cases_case_id ON log_cases (case_id);
CREATE INDEX log_cases_case_category_id ON log_cases (case_category_id);
CREATE INDEX log_cases_case_subject_id ON log_cases (case_subject_id);
CREATE INDEX log_cases_court_division_id ON log_cases (court_division_id);
CREATE INDEX log_cases_file_location_id ON log_cases (file_location_id);
CREATE INDEX log_cases_police_station_id ON log_cases (police_station_id);
CREATE INDEX log_cases_new_case_id ON log_cases (new_case_id);
CREATE INDEX log_cases_old_case_id ON log_cases (old_case_id);
CREATE INDEX log_cases_constituency_id ON log_cases (constituency_id);
CREATE INDEX log_cases_ward_id ON log_cases (ward_id);
CREATE INDEX log_cases_org_id ON log_cases (org_id);

CREATE TABLE log_case_activity (
	log_case_activity_id	serial primary key,
	case_activity_id		integer,
	case_id					integer,
	hearing_location_id		integer,
	activity_id				integer,
	activity_result_id		integer,
	adjorn_reason_id		integer,
	order_type_id			integer,
	court_station_id		integer,
	appleal_case_id			integer,
	org_id					integer,
	activity_date			date,
	activity_time			time,
	finish_time				time,
	shared_hearing			boolean default false not null,
	completed				boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	order_narrative			varchar(320),
	order_title				varchar(320),
	order_details			text,
	appleal_details			text,
	details					text
);
CREATE INDEX log_case_activity_case_activity_id ON log_case_activity (case_activity_id);
CREATE INDEX log_case_activity_case_id ON log_case_activity (case_id);
CREATE INDEX log_case_activity_activity_id ON log_case_activity (activity_id);
CREATE INDEX log_case_activity_hearing_location_id ON log_case_activity (hearing_location_id);
CREATE INDEX log_case_activity_activity_result_id ON log_case_activity (activity_result_id);
CREATE INDEX log_case_activity_adjorn_reason_id ON log_case_activity (adjorn_reason_id);
CREATE INDEX log_case_activity_order_type_id ON log_case_activity (order_type_id);
CREATE INDEX log_case_activity_court_station_id ON log_case_activity (court_station_id);
CREATE INDEX log_case_activity_org_id ON log_case_activity (org_id);

CREATE TABLE log_case_transfers (
	log_case_transfer_id	serial primary key,
	case_transfer_id		integer,
	case_id					integer,
	case_category_id		integer,
	court_division_id		integer,
	org_id					integer,
	judgment_date			date,
	presiding_judge			varchar(50),
	previous_case_number	varchar(25),
	receipt_date			date,
	received_by				varchar(50),
	case_transfered			boolean default true not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX log_case_transfers_case_transfer_id ON log_case_transfers (case_transfer_id);
CREATE INDEX log_case_transfers_case_id ON log_case_transfers (case_id);
CREATE INDEX log_case_transfers_case_category_id ON log_case_transfers (case_category_id);
CREATE INDEX log_case_transfers_court_division_id ON log_case_transfers (court_division_id);
CREATE INDEX log_case_transfers_org_id ON log_case_transfers (org_id);

CREATE TABLE log_case_contacts (
	log_case_contact_id		serial primary key,
	case_contact_id			integer,
	case_id					integer,
	entity_id				integer,
	contact_type_id			integer,
	political_party_id		integer,
	org_id					integer,
	case_contact_no			integer,
	is_disqualified			boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX log_case_contacts_case_contact_id ON log_case_contacts (case_contact_id);
CREATE INDEX log_case_contacts_case_id ON log_case_contacts (case_id);
CREATE INDEX log_case_contacts_entity_id ON log_case_contacts (entity_id);
CREATE INDEX log_case_contacts_contact_type_id ON log_case_contacts (contact_type_id);
CREATE INDEX log_case_contacts_political_party_id ON case_contacts (political_party_id);
CREATE INDEX log_case_contacts_org_id ON log_case_contacts (org_id);

CREATE TABLE log_case_counts (
	log_case_count_id		serial primary key, 
	case_count_id			integer, 
	case_contact_id			integer, 
	case_category_id		integer, 
	org_id					integer, 
	narrative				varchar(320), 
	is_active				boolean default true not null, 
	change_by				integer, 
	change_date				timestamp default now(), 
	detail					text
);
CREATE INDEX log_case_counts_case_count_id ON log_case_counts(case_count_id);
CREATE INDEX log_case_counts_case_contact_id ON log_case_counts (case_contact_id);
CREATE INDEX log_case_counts_case_category_id ON log_case_counts (case_category_id);
CREATE INDEX log_case_counts_org_id ON log_case_counts (org_id);

CREATE TABLE log_case_decisions (
	log_case_decision_id	serial primary key,
	case_decision_id		integer,
	case_id					integer,
	case_activity_id		integer,
	case_count_id			integer,
	decision_type_id		integer,
	judgment_status_id		integer,
	org_id					integer,
	decision_summary 		varchar(1024),
	judgement				text,
	judgement_date			date,
	death_sentence			boolean default false not null,
	life_sentence			boolean default false not null,
	jail_years				integer,
	jail_days				integer,
	fine_amount				real,
	fine_jail				integer,
	canes					integer,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	detail					text
);
CREATE INDEX log_case_decisions_case_decision_id ON log_case_decisions (case_decision_id);
CREATE INDEX log_case_decisions_case_id ON log_case_decisions (case_id);
CREATE INDEX log_case_decisions_case_activity_id ON log_case_decisions (case_activity_id);
CREATE INDEX log_case_decisions_case_count_id ON log_case_decisions (case_count_id);
CREATE INDEX log_case_decisions_decision_type_id ON log_case_decisions (decision_type_id);
CREATE INDEX log_case_decisions_judgment_status_id ON log_case_decisions (judgment_status_id);
CREATE INDEX log_case_decisions_org_id ON log_case_decisions (org_id);

CREATE TABLE log_receipts (
	log_receipt_id			serial primary key, 
	receipt_id				integer,
	case_id					integer,
	case_decision_id		integer,
	receipt_type_id			integer,
	court_station_id		integer,
	org_id					integer,
	receipt_for				varchar(320),
	case_number				varchar(50) not null,
	receipt_date			date,
	amount					real,
	for_process				boolean default false not null,
	approved				boolean default false not null, 
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX log_receipts_receipt_id ON log_receipts (receipt_id);
CREATE INDEX log_receipts_case_id ON log_receipts (case_id);
CREATE INDEX log_receipts_case_decision_id ON log_receipts (case_decision_id);
CREATE INDEX log_receipts_type_id ON log_receipts (receipt_type_id);
CREATE INDEX log_receipts_court_station_id ON log_receipts (court_station_id);
CREATE INDEX log_receipts_org_id ON log_receipts (org_id);

CREATE TABLE log_court_payments (
	log_court_payment_id	serial primary key, 
	court_payment_id		integer, 
	receipt_id				integer, 
	payment_type_id			integer, 
	bank_account_id			integer,
	org_id					integer, 
	bank_ref				varchar(50), 
	payment_date			date, 
	amount					real,
	jail_days				integer default 0 not null,
	credit_note				boolean default false not null,
	refund					boolean default false not null,
	is_active				boolean default true not null, 
	change_by				integer, 
	change_date				timestamp default now(), 
	details					text
);
CREATE INDEX log_court_payments_court_payment_id ON log_court_payments (court_payment_id);
CREATE INDEX log_court_payments_receipt_id ON log_court_payments (receipt_id);
CREATE INDEX log_court_payments_payment_type_id ON log_court_payments (payment_type_id);
CREATE INDEX log_court_payments_bank_account_id ON log_court_payments (bank_account_id);
CREATE INDEX log_court_payments_org_id ON log_court_payments (org_id);

CREATE TABLE log_court_bankings (
	log_court_banking_id	serial primary key, 
	court_banking_id		integer, 
	bank_account_id			integer,
	source_account_id		integer,
	org_id					integer, 
	bank_ref				varchar(50), 
	banking_date			date, 
	amount					real, 
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX log_court_bankings_court_banking_id ON log_court_bankings (court_banking_id);
CREATE INDEX log_court_bankings_bank_account_id ON log_court_bankings (bank_account_id);
CREATE INDEX log_court_bankings_source_account_id ON log_court_bankings (source_account_id);
CREATE INDEX log_court_bankings_org_id ON log_court_bankings (org_id);

CREATE VIEW vw_log_cases AS
	SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, 
		vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, 
		vw_case_category.case_category_no, vw_case_category.act_code,

		vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name,
		vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, 
		vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station,
		vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, 
		vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num,
		vw_court_divisions.court_division,

		case_subjects.case_subject_id, case_subjects.case_subject_name,
		file_locations.file_location_id, file_locations.file_location_name, 
		police_stations.police_station_id, police_stations.police_station_name,

		log_cases.org_id, log_cases.case_id, log_cases.log_case_id, log_cases.case_title, 
		log_cases.file_number, log_cases.date_of_arrest, log_cases.ob_number, log_cases.holding_prison, 
		log_cases.warrant_of_arrest, log_cases.alleged_crime, log_cases.start_date, log_cases.end_date, 
		log_cases.nature_of_claim, log_cases.value_of_claim, log_cases.closed, log_cases.final_decision, 
		log_cases.change_date, log_cases.change_by, log_cases.detail
	FROM log_cases INNER JOIN vw_case_category ON log_cases.case_category_id = vw_case_category.case_category_id
		INNER JOIN vw_court_divisions ON log_cases.court_division_id = vw_court_divisions.court_division_id
		INNER JOIN case_subjects ON log_cases.case_subject_id = case_subjects.case_subject_id
		LEFT JOIN file_locations ON log_cases.file_location_id = file_locations.file_location_id
		LEFT JOIN police_stations ON log_cases.police_station_id = police_stations.police_station_id;

CREATE VIEW vw_log_case_transfers AS
	SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, 
		vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, 
		vw_case_category.case_category_no, vw_case_category.act_code,

		vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, 
		vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, 
		vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, 
		vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, 
		vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num,
		vw_court_divisions.court_division,

		log_case_transfers.log_case_transfer_id, log_case_transfers.case_id, log_case_transfers.org_id, 
		log_case_transfers.case_transfer_id, log_case_transfers.judgment_date, log_case_transfers.presiding_judge, 
		log_case_transfers.previous_case_number, log_case_transfers.receipt_date, log_case_transfers.received_by, 
		log_case_transfers.change_by, log_case_transfers.change_date, log_case_transfers.details
	FROM log_case_transfers	INNER JOIN vw_court_divisions ON log_case_transfers.court_division_id = vw_court_divisions.court_division_id
		INNER JOIN vw_case_category ON log_case_transfers.case_category_id = vw_case_category.case_category_id;

CREATE VIEW vw_log_case_activity AS
	SELECT vw_cases.case_type_id, vw_cases.case_type_name, 
		vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, 
		vw_cases.case_category_no, vw_cases.act_code,
		vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name,
		vw_cases.court_rank_id, vw_cases.court_rank_name, 
		vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station,
		vw_cases.division_type_id, vw_cases.division_type_name, 
		vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num,
		vw_cases.court_division,
		vw_cases.file_location_id, vw_cases.file_location_name, 
		vw_cases.police_station_id, vw_cases.police_station_name,
		vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, 
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location,

		activitys.activity_id, activitys.activity_name,
		activity_results.activity_result_id, activity_results.activity_result_name, 
		adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, 
		order_types.order_type_id, order_types.order_type_name, 

		log_case_activity.org_id, log_case_activity.case_activity_id, log_case_activity.log_case_activity_id, 
		log_case_activity.activity_date, log_case_activity.activity_time, 
		log_case_activity.finish_time, log_case_activity.shared_hearing, 
		log_case_activity.change_by, log_case_activity.change_date, log_case_activity.details
	FROM log_case_activity INNER JOIN vw_cases ON log_case_activity.case_id = vw_cases.case_id
		INNER JOIN vw_hearing_locations ON log_case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id
		INNER JOIN activitys ON log_case_activity.activity_id = activitys.activity_id
		INNER JOIN activity_results ON log_case_activity.activity_result_id = activity_results.activity_result_id
		INNER JOIN adjorn_reasons ON log_case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id
		LEFT JOIN order_types ON log_case_activity.order_type_id = order_types.order_type_id;

CREATE VIEW vw_log_case_contacts AS
	SELECT vw_cases.case_type_id, vw_cases.case_type_name, 
		vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, 
		vw_cases.case_category_no, vw_cases.act_code,
		vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name,
		vw_cases.court_rank_id, vw_cases.court_rank_name, 
		vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station,
		vw_cases.division_type_id, vw_cases.division_type_name, 
		vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num,
		vw_cases.court_division,
		vw_cases.file_location_id, vw_cases.file_location_name, 
		vw_cases.police_station_id, vw_cases.police_station_name,
		vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, 
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, 
		vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name,

		contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench,

		log_case_contacts.case_contact_id, log_case_contacts.org_id, log_case_contacts.log_case_contact_id, 
		log_case_contacts.case_contact_no, log_case_contacts.is_active, log_case_contacts.is_disqualified,
		log_case_contacts.change_date, log_case_contacts.change_by, log_case_contacts.details
	FROM log_case_contacts INNER JOIN vw_cases ON log_case_contacts.case_id = vw_cases.case_id
		INNER JOIN vw_entitys ON log_case_contacts.entity_id = vw_entitys.entity_id
		INNER JOIN contact_types ON log_case_contacts.contact_type_id = contact_types.contact_type_id;

CREATE VIEW vw_log_case_counts AS
	SELECT vw_case_contacts.region_id, vw_case_contacts.region_name, vw_case_contacts.county_id, vw_case_contacts.county_name,
		vw_case_contacts.court_rank_id, vw_case_contacts.court_rank_name, 
		vw_case_contacts.court_station_id, vw_case_contacts.court_station_name, vw_case_contacts.court_station_code, vw_case_contacts.court_station,
		vw_case_contacts.division_type_id, vw_case_contacts.division_type_name, 
		vw_case_contacts.court_division_id, vw_case_contacts.court_division_code, vw_case_contacts.court_division_num,
		vw_case_contacts.court_division,
		vw_case_contacts.file_location_id, vw_case_contacts.file_location_name, 
		vw_case_contacts.police_station_id, vw_case_contacts.police_station_name,
		vw_case_contacts.case_id, vw_case_contacts.case_title, vw_case_contacts.file_number, vw_case_contacts.date_of_arrest, 
		vw_case_contacts.ob_number, vw_case_contacts.holding_prison, vw_case_contacts.warrant_of_arrest, vw_case_contacts.alleged_crime, vw_case_contacts.start_date, 
		vw_case_contacts.end_date, vw_case_contacts.nature_of_claim, vw_case_contacts.value_of_claim, vw_case_contacts.closed, vw_case_contacts.final_decision,

		vw_case_contacts.entity_id, vw_case_contacts.entity_name, vw_case_contacts.user_name, vw_case_contacts.primary_email, 
		vw_case_contacts.gender, vw_case_contacts.date_of_birth, vw_case_contacts.ranking_id, vw_case_contacts.ranking_name,

		vw_case_contacts.contact_type_id, vw_case_contacts.contact_type_name, vw_case_contacts.bench,
		vw_case_contacts.case_contact_id, vw_case_contacts.case_contact_no, 

		vw_case_category.case_type_id, vw_case_category.case_type_name, 
		vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, 
		vw_case_category.case_category_no, vw_case_category.act_code,

		log_case_counts.log_case_count_id, log_case_counts.org_id, log_case_counts.case_count_id, 
		log_case_counts.narrative, log_case_counts.detail
	FROM log_case_counts INNER JOIN vw_case_contacts ON log_case_counts.case_contact_id = vw_case_contacts.case_contact_id
		INNER JOIN vw_case_category ON log_case_counts.case_category_id = vw_case_category.case_category_id;

CREATE VIEW vw_log_case_decisions AS
	SELECT vw_cases.case_type_id, vw_cases.case_type_name, 
		vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, 
		vw_cases.case_category_no, vw_cases.act_code,
		vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name,
		vw_cases.court_rank_id, vw_cases.court_rank_name, 
		vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station,
		vw_cases.division_type_id, vw_cases.division_type_name, 
		vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num,
		vw_cases.court_division,
		vw_cases.file_location_id, vw_cases.file_location_name, 
		vw_cases.police_station_id, vw_cases.police_station_name,
		vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, 
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		decision_types.decision_type_id, decision_types.decision_type_name, 
		judgment_status.judgment_status_id, judgment_status.judgment_status_name,

		log_case_decisions.case_activity_id,
		log_case_decisions.log_case_decision_id, log_case_decisions.org_id, log_case_decisions.case_decision_id, 
		log_case_decisions.decision_summary, log_case_decisions.judgement, log_case_decisions.judgement_date, 
		log_case_decisions.death_sentence, log_case_decisions.life_sentence, log_case_decisions.jail_years, 
		log_case_decisions.jail_days, log_case_decisions.fine_amount, log_case_decisions.canes, 
		log_case_decisions.detail
	FROM log_case_decisions	INNER JOIN vw_cases ON log_case_decisions.case_id = vw_cases.case_id
		INNER JOIN decision_types ON log_case_decisions.decision_type_id = decision_types.decision_type_id
		INNER JOIN judgment_status ON log_case_decisions.judgment_status_id = judgment_status.judgment_status_id;

CREATE FUNCTION audit_cases() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_cases (case_id, case_category_id, court_division_id, file_location_id, case_subject_id,
		old_case_id, new_case_id, constituency_id, ward_id,
		police_station_id, org_id, case_title, File_Number, date_of_arrest, 
		ob_Number, holding_prison, warrant_of_arrest, alleged_crime, start_date, end_date, nature_of_claim, 
		value_of_claim, closed, case_locked, final_decision, change_by, detail, date_of_elections)
	VALUES(NEW.case_id, NEW.case_category_id, NEW.court_division_id, NEW.file_location_id, NEW.case_subject_id,
		NEW.old_case_id, NEW.new_case_id, NEW.constituency_id, NEW.ward_id,
		NEW.police_station_id, NEW.org_id, NEW.case_title, NEW.File_Number, NEW.date_of_arrest, 
		NEW.ob_Number, NEW.holding_prison, NEW.warrant_of_arrest, NEW.alleged_crime, NEW.start_date, NEW.end_date, NEW.nature_of_claim, 
		NEW.value_of_claim, NEW.closed, NEW.case_locked, NEW.final_decision, NEW.change_by, NEW.detail, NEW.date_of_elections);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_cases AFTER INSERT OR UPDATE ON cases
    FOR EACH ROW EXECUTE PROCEDURE audit_cases();

CREATE OR REPLACE FUNCTION audit_case_transfers() RETURNS trigger AS $$
BEGIN
		INSERT INTO log_case_transfers(case_transfer_id, case_id, case_category_id, court_division_id, org_id, 
			judgment_date, presiding_judge,previous_case_number,receipt_date,received_by,
			is_active,change_by,change_date,details	)
	    VALUES(NEW.case_transfer_id, NEW.case_id, NEW.case_category_id, NEW.court_division_id, NEW.org_id, 
			NEW.judgment_date, NEW.presiding_judge, NEW.previous_case_number, NEW.receipt_date, NEW.received_by,
			NEW.is_active, NEW.change_by, NEW.change_date, NEW.details);

		RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_case_transfers AFTER INSERT OR UPDATE ON log_case_transfers
	FOR EACH ROW EXECUTE PROCEDURE audit_case_transfers();

CREATE OR REPLACE FUNCTION audit_case_activity() RETURNS trigger AS $$
BEGIN

	INSERT INTO log_case_activity (case_activity_id, case_id, activity_id, hearing_location_id, 
		activity_result_id, adjorn_reason_id, order_type_id, court_station_id, appleal_case_id, org_id, 
		activity_date, activity_time, finish_time, shared_hearing, completed, is_active, 
		change_by, change_date, order_narrative, order_title, order_details, appleal_details, details)
	VALUES (NEW.case_activity_id, NEW.case_id, NEW.activity_id, NEW.hearing_location_id, 
		NEW.activity_result_id, NEW.adjorn_reason_id, NEW.order_type_id, NEW.court_station_id, NEW.appleal_case_id, NEW.org_id, 
		NEW.activity_date, NEW.activity_time, NEW.finish_time, NEW.shared_hearing, NEW.completed, NEW.is_active, 
		NEW.change_by, NEW.change_date, NEW.order_narrative, NEW.order_title, NEW.order_details, NEW.appleal_details, NEW.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_case_activity AFTER INSERT OR UPDATE ON case_activity
    FOR EACH ROW EXECUTE PROCEDURE audit_case_activity();

CREATE OR REPLACE FUNCTION audit_case_contacts() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_case_contacts (case_contact_id, case_id, entity_id, contact_type_id, org_id, 
		case_contact_no, is_active, change_date, change_by, details, political_party_id)
	VALUES (NEW.case_contact_id, NEW.case_id, NEW.entity_id, NEW.contact_type_id, NEW.org_id, 
		NEW.case_contact_no, NEW.is_active, NEW.change_date, NEW.change_by, NEW.details, NEW.political_party_id);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_case_contacts AFTER INSERT OR UPDATE ON case_contacts
    FOR EACH ROW EXECUTE PROCEDURE audit_case_contacts();

CREATE OR REPLACE FUNCTION audit_case_counts() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_case_counts(case_count_id, case_contact_id, case_category_id, org_id, narrative, is_active, 
		change_by, change_date, detail)
	VALUES(NEW.case_count_id, NEW.case_contact_id, NEW.case_category_id, NEW.org_id, NEW.narrative, NEW.is_active, 
		NEW.change_by, NEW.change_date, NEW.detail);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_case_counts AFTER INSERT OR UPDATE ON case_counts
    FOR EACH ROW EXECUTE PROCEDURE audit_case_counts();

CREATE OR REPLACE FUNCTION audit_case_decisions() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_case_decisions(case_decision_id, case_id, case_activity_id, case_count_id, decision_type_id, judgment_status_id,
		org_id, decision_summary, judgement, judgement_date, death_sentence, life_sentence, jail_years, jail_days, fine_amount,
		fine_jail, canes, is_active, change_by, change_date, detail)
	VALUES(	NEW.case_decision_id, NEW.case_id, NEW.case_activity_id, NEW.case_count_id, NEW.decision_type_id, NEW.judgment_status_id, NEW.org_id,
		NEW.decision_summary, NEW.judgement, NEW.judgement_date, NEW.death_sentence, NEW.life_sentence, 
		NEW.fine_jail, NEW.jail_years, NEW.jail_days, NEW.fine_amount, NEW.canes, NEW.is_active, NEW.change_by, NEW.change_date, NEW.detail);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_case_decisions AFTER INSERT OR UPDATE ON case_decisions
	FOR EACH ROW EXECUTE PROCEDURE audit_case_decisions();

CREATE OR REPLACE FUNCTION audit_receipts() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_receipts(receipt_id, case_id, case_decision_id, receipt_type_id, 
		court_station_id, org_id, receipt_for, case_number, receipt_date, amount, for_process, 
		approved, is_active, change_by, change_date, details)
	VALUES(NEW.receipt_id, NEW.case_id, NEW.case_decision_id, NEW.receipt_type_id, 
		NEW.court_station_id, NEW.org_id, NEW.receipt_for, NEW.case_number, NEW.receipt_date, NEW.amount, NEW.for_process, 
		NEW.approved, NEW.is_active, NEW.change_by, NEW.change_date, NEW.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_receipts AFTER INSERT OR UPDATE ON receipts
	 FOR EACH ROW EXECUTE PROCEDURE audit_receipts();

CREATE OR REPLACE FUNCTION audit_court_payments() RETURNS trigger AS $$
BEGIN

	INSERT INTO log_court_payments (court_payment_id, receipt_id, payment_type_id, bank_account_id, 
		org_id, bank_ref, payment_date, amount, jail_days, is_active, 
		change_by, change_date, credit_note, refund, details)
	VALUES (NEW.court_payment_id, NEW.receipt_id, NEW.payment_type_id, NEW.bank_account_id,
		NEW.org_id, NEW.bank_ref, NEW.payment_date, NEW.amount, NEW.jail_days, NEW.is_active, 
		NEW.change_by, NEW.change_date, NEW.credit_note, NEW.refund, NEW.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_court_payments AFTER INSERT OR UPDATE ON court_payments
	 FOR EACH ROW EXECUTE PROCEDURE audit_court_payments();

CREATE OR REPLACE FUNCTION audit_court_bankings() RETURNS trigger AS $$
BEGIN
	INSERT INTO log_court_bankings(court_banking_id, bank_account_id, source_account_id, org_id, bank_ref, 
		banking_date, amount, change_by, change_date, details)
	VALUES(NEW.court_banking_id, NEW.bank_account_id, NEW.source_account_id, NEW.org_id, NEW.bank_ref, 
		NEW.banking_date, NEW.amount, NEW.change_by, NEW.change_date, NEW.details);
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_court_bankings AFTER INSERT OR UPDATE ON court_bankings
	 FOR EACH ROW EXECUTE PROCEDURE audit_court_bankings();

