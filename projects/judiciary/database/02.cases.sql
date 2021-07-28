---Project Database File
CREATE TABLE activity_results (
	activity_result_id		serial primary key,
	activity_result_name	varchar(320) not null unique,
	appeal					boolean default true not null,
	trial					boolean default true not null,
	details					text
);

CREATE TABLE adjorn_reasons (
	adjorn_reason_id		serial primary key,
	adjorn_reason_name		varchar(320) not null unique,
	appeal					boolean default true not null,
	trial					boolean default true not null,
	details					text
);

CREATE TABLE order_types (
	order_type_id			serial primary key,
	order_type_name			varchar(320) not null unique,
	details					text
);

CREATE TABLE case_subjects (
	case_subject_id			serial primary key,
	case_subject_name		varchar(320) not null unique,
	ep						boolean default false not null,
	criminal				boolean default false not null,
	civil					boolean default false not null,
	details					text
);

CREATE TABLE judgment_status (
	judgment_status_id		serial primary key,
	judgment_status_name	varchar(320),
	details					text
);

CREATE TABLE bench_subjects (
	bench_subject_id		serial primary key,
	entity_id				integer not null references entitys,
	case_subject_id			integer not null references case_subjects,
	org_id					integer references orgs,
	proficiency				integer default 1,
	details					text,
	UNIQUE(entity_id, case_subject_id)
);
CREATE INDEX bench_subjects_entity_id ON bench_subjects (entity_id);
CREATE INDEX bench_subjects_case_subject_id ON bench_subjects (case_subject_id);
CREATE INDEX bench_subjects_org_id ON bench_subjects (org_id);

CREATE TABLE case_types (
	case_type_id			serial primary key,
	case_type_name			varchar(320) not null unique,
	duration_unacceptable	integer,
	duration_serious		integer,
	duration_normal			integer,
	duration_low			integer,
	activity_unacceptable	integer,
	activity_serious		integer,
	activity_normal			integer,
	activity_low			integer,
	details					text
);

CREATE TABLE case_category (
	case_category_id		serial primary key,
	case_type_id			integer references case_types,
	case_category_name		varchar(320) not null,
	case_category_title		varchar(320),
	case_category_no		varchar(12),
	act_code				varchar(64),
	special_suffix			varchar(12),
	death_sentence			boolean default false not null,
	life_sentence			boolean default false not null,
	min_sentence			integer,
	max_sentence			integer,
	min_fine				real,
	max_fine				real,
	min_canes				integer,
	max_canes				integer,
	Details					text
);
CREATE INDEX case_category_case_type_id ON case_category (case_type_id);

CREATE TABLE activitys (
	activity_id				serial primary key,
	activity_name			varchar(320) not null unique,
	appeal					boolean default true not null,
	trial					boolean default true not null,
	ep						boolean default false not null,
	show_on_diary			boolean default true not null,
	activity_days			integer default 1,
	activity_hours			integer default 0,
	details					text
);

CREATE TABLE contact_types (
	contact_type_id			serial primary key,
	contact_type_name		varchar(320),
	bench					boolean default false not null,
	appeal					boolean default true not null,
	trial					boolean default true not null,
	ep						boolean default false not null,
	details					text
);

ALTER TABLE orgs ADD bench_next	integer;

CREATE TABLE political_parties (
	political_party_id		serial primary key,
	political_party_name	varchar(320),
	details					text
);

CREATE TABLE category_activitys (
	category_activity_id	serial primary key,
	case_category_id		integer references case_category,
	contact_type_id			integer references contact_types,
	activity_id				integer references activitys,
	from_activity_id		integer references activitys,
	activity_order			integer,
	warning_days			integer,
	deadline_days			integer,
	mandatory				boolean default true not null,
	details					text
);
CREATE INDEX category_activitys_case_category_id ON category_activitys (case_category_id);
CREATE INDEX category_activitys_contact_type_id ON category_activitys (contact_type_id);
CREATE INDEX category_activitys_activity_id ON category_activitys (activity_id);
CREATE INDEX category_activitys_from_activity_id ON category_activitys (from_activity_id);

CREATE TABLE decision_types (
	decision_type_id		serial primary key,
	decision_type_name		varchar(320) not null unique,
	details					text
);

CREATE TABLE cases (
	case_id					serial primary key,
	case_category_id		integer not null references case_category,
	court_division_id		integer not null references court_divisions,
	file_location_id		integer references file_locations,
	case_subject_id			integer references case_subjects,
	police_station_id		integer references police_stations,
	new_case_id				integer references cases,
	old_case_id				integer references cases,

	county_id				integer references counties,
	constituency_id			integer references constituency,
	ward_id					integer references wards,

	org_id					integer references orgs,
	case_title				varchar(320) not null,
	public_citation			varchar(320),
	case_number				varchar(50),
	file_number				varchar(50) not null,
	date_of_elections		date,
	date_of_arrest			date,
	ob_number				varchar(120),
	holding_prison			varchar(120),
	warrant_of_arrest		boolean default false not null,
	alleged_crime			text,
	start_date				date not null,
	original_case_date		date,
	end_date				date,
	nature_of_claim			varchar(320),
	value_of_claim			real,
	closed					boolean default false not null,
	case_locked				boolean default false not null,
	consolidate_cases		boolean default false not null,
	final_decision	 		varchar(1024),
	change_by				integer,
	change_date				timestamp default now(),
	detail					text
);
CREATE INDEX cases_case_category_id ON cases (case_category_id);
CREATE INDEX cases_court_division_id ON cases (court_division_id);
CREATE INDEX cases_file_location_id ON cases (file_location_id);
CREATE INDEX cases_case_subject_id ON cases (case_subject_id);
CREATE INDEX cases_police_station_id ON cases (police_station_id);
CREATE INDEX cases_new_case_id ON cases (new_case_id);
CREATE INDEX cases_old_case_id ON cases (old_case_id);
CREATE INDEX cases_constituency_id ON cases (constituency_id);
CREATE INDEX cases_ward_id ON cases (ward_id);
CREATE INDEX cases_org_id ON cases (org_id);

CREATE TABLE case_activity (
	case_activity_id		serial primary key,
	case_id					integer not null references cases,
	activity_id				integer not null references activitys,
	hearing_location_id		integer references hearing_locations,
	activity_result_id		integer references activity_results,
	adjorn_reason_id		integer references adjorn_reasons,
	order_type_id			integer references order_types,
	court_station_id		integer references court_stations,
	appleal_case_id			integer references cases,
	org_id					integer references orgs,
	activity_date			date not null,
	activity_time			time not null,
	finish_time				time not null,
	shared_hearing			boolean default false not null,
	completed				boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	urgency_certificate		varchar(50),
	order_title				varchar(320),
	order_narrative			varchar(320),
	order_details			text,
	appleal_details			text,
	result_details			text,
	adjorn_details			text,
	details					text,

	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Completed' not null,
	workflow_table_id		integer,
	action_date				timestamp
);
CREATE INDEX case_activity_case_id ON case_activity (case_id);
CREATE INDEX case_activity_activity_id ON case_activity (activity_id);
CREATE INDEX case_activity_hearing_location_id ON case_activity (hearing_location_id);
CREATE INDEX case_activity_activity_result_id ON case_activity (activity_result_id);
CREATE INDEX case_activity_adjorn_reason_id ON case_activity (adjorn_reason_id);
CREATE INDEX case_activity_order_type_id ON case_activity (order_type_id);
CREATE INDEX case_activity_court_station_id ON case_activity (court_station_id);
CREATE INDEX case_activity_org_id ON case_activity (org_id);

CREATE TABLE case_notes (
	case_note_id			serial primary key,
	case_activity_id		integer references case_activity,
	entity_id				integer not null references entitys,
	org_id					integer references orgs,
	case_note_title			varchar(320),
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX case_notes_case_activity_id ON case_notes (case_activity_id);
CREATE INDEX case_notes_entity_id ON case_notes (entity_id);
CREATE INDEX case_notes_org_id ON case_notes (org_id);

CREATE TABLE case_transfers (
	case_transfer_id		serial primary key,
	case_id					integer references cases,
	case_category_id		integer references case_category,
	court_division_id		integer references court_divisions,
	org_id					integer references orgs,
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
CREATE INDEX case_transfers_case_id ON case_transfers (case_id);
CREATE INDEX case_transfers_case_category_id ON case_transfers (case_category_id);
CREATE INDEX case_transfers_court_division_id ON case_transfers (court_division_id);
CREATE INDEX case_transfers_org_id ON case_transfers (org_id);

CREATE TABLE case_contacts (
	case_contact_id			serial primary key,
	case_id					integer not null references cases,
	entity_id				integer not null references entitys,
	contact_type_id			integer not null references contact_types,
	political_party_id		integer references political_parties,
	org_id					integer references orgs,
	case_contact_no			integer,
	election_winner			boolean default false not null,
	is_disqualified			boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text,
	UNIQUE(case_id, entity_id)
);
CREATE INDEX case_contacts_case_id ON case_contacts (case_id);
CREATE INDEX case_contacts_entity_id ON case_contacts (entity_id);
CREATE INDEX case_contacts_contact_type_id ON case_contacts (contact_type_id);
CREATE INDEX case_contacts_political_party_id ON case_contacts (political_party_id);
CREATE INDEX case_contacts_org_id ON case_contacts (org_id);

CREATE TABLE case_counts (
	case_count_id			serial primary key,
	case_contact_id			integer not null references case_contacts,
	case_category_id		integer not null references case_category,
	org_id					integer references orgs,
	narrative				varchar(320),
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	detail					text,
	UNIQUE(case_contact_id, case_category_id)
);
CREATE INDEX case_counts_case_contact_id ON case_counts (case_contact_id);
CREATE INDEX case_counts_case_category_id ON case_counts (case_category_id);
CREATE INDEX case_counts_org_id ON case_counts (org_id);

CREATE TABLE case_decisions (
	case_decision_id		serial primary key,
	case_id					integer references cases,
	case_activity_id		integer references case_activity,
	case_count_id			integer references case_counts,
	decision_type_id		integer references decision_types,
	judgment_status_id		integer references judgment_status,
	org_id					integer references orgs,
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
CREATE INDEX case_decisions_case_id ON case_decisions (case_id);
CREATE INDEX case_decisions_case_activity_id ON case_decisions (case_activity_id);
CREATE INDEX case_decisions_case_count_id ON case_decisions (case_count_id);
CREATE INDEX case_decisions_decision_type_id ON case_decisions (decision_type_id);
CREATE INDEX case_decisions_judgment_status_id ON case_decisions (judgment_status_id);
CREATE INDEX case_decisions_org_id ON case_decisions (org_id);

CREATE TABLE case_quorum (
	case_quorum_id			serial primary key,
	case_activity_id		integer references case_activity,
	case_contact_id			integer not null references case_contacts,
	org_id					integer references orgs,
	narrative				varchar(320),
	UNIQUE(case_activity_id, case_contact_id)
);
CREATE INDEX case_quorum_case_activity_id ON case_quorum (case_activity_id);
CREATE INDEX case_quorum_case_contact_id ON case_quorum (case_contact_id);
CREATE INDEX case_quorum_org_id ON case_quorum (org_id);

CREATE TABLE case_bookmarks (
	case_bookmark_id		serial primary key,
	case_id					integer not null references cases,
	entity_id				integer not null references entitys,
	org_id					integer references orgs,
	entry_date				timestamp default now(),
	notes					text,
	UNIQUE(case_id, entity_id)
);
CREATE INDEX case_bookmarks_case_id ON case_bookmarks (case_id);
CREATE INDEX case_bookmarks_entity_id ON case_bookmarks (entity_id);
CREATE INDEX case_bookmarks_org_id ON case_bookmarks (org_id);

CREATE TABLE case_insurance (
	case_insurance_id		serial primary key,
	case_id					integer not null references cases,
	org_id					integer references orgs,
	entry_date				timestamp default now(),
	registration_number		varchar(320),
	type_of_claim			varchar(320),
	value_of_claim			real,
	notes					text
);
CREATE INDEX case_insurance_case_id ON case_insurance (case_id);
CREATE INDEX case_insurance_org_id ON case_insurance (org_id);

CREATE TABLE receipt_types (
	receipt_type_id			serial primary key,
	receipt_type_name		varchar(320) not null,
	receipt_type_code		varchar(12) not null,
	require_refund			boolean default false not null,
	details					text
);

CREATE TABLE receipts (
	receipt_id				serial primary key,
	case_id					integer references cases,
	case_decision_id		integer references case_decisions,
	receipt_type_id			integer not null references receipt_types,
	court_station_id		integer references court_stations,
	org_id					integer references orgs,
	receipt_for				varchar(320),
	case_number				varchar(50) not null,
	receipt_date			date,
	amount					real not null,				
	for_process				boolean default false not null,
	approved				boolean default false not null,
	refund_approved			boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX receipts_receipt_case_id ON receipts (case_id);
CREATE INDEX receipts_receipt_case_decision_id ON receipts (case_decision_id);
CREATE INDEX receipts_receipt_type_id ON receipts (receipt_type_id);
CREATE INDEX receipts_court_station_id ON receipts (court_station_id);
CREATE INDEX receipts_org_id ON receipts (org_id);

CREATE TABLE payment_types (
	payment_type_id			serial primary key,
	payment_type_name		varchar(320) not null unique,
	cash					boolean default false not null,
	non_cash				boolean default false not null,
	for_credit_note			boolean default false not null,
	for_refund				boolean default false not null,
	details					text
);

CREATE TABLE bank_accounts (
	bank_account_id			serial primary key,
	org_id					integer references orgs,
	bank_account_name		varchar(120),
	bank_account_number		varchar(50),
	bank_name				varchar(120),
	branch_name				varchar(120),
    narrative				varchar(240),
	is_default				boolean default false not null,
	is_active				boolean default true not null,
    details					text
);
CREATE INDEX bank_accounts_org_id ON bank_accounts (org_id);

CREATE TABLE court_payments (
	court_payment_id		serial primary key,
	receipt_id				integer references receipts,
	payment_type_id			integer references payment_types,
	bank_account_id			integer references bank_accounts,
	org_id					integer references orgs,
	bank_ref				varchar(50),
	payment_date			date,
	amount					real,
	r_amount				real,
	bank_code				varchar(5),
	payee_name				varchar(120),
	payee_account			varchar(32),
	jail_days				integer default 0 not null,
	credit_note				boolean default false not null,
	refund					boolean default false not null,
	is_active				boolean default true not null,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX court_payments_receipt_id ON court_payments (receipt_id);
CREATE INDEX court_payments_payment_type_id ON court_payments (payment_type_id);
CREATE INDEX court_payments_bank_account_id ON court_payments (bank_account_id);
CREATE INDEX court_payments_org_id ON court_payments (org_id);

CREATE TABLE mpesa_trxs (
	mpesa_trx_id			serial primary key,
	receipt_id				integer references receipts,
	org_id					integer references orgs,
	mpesa_id				integer,
	mpesa_orig				varchar(50),
	mpesa_dest				varchar(50),
	mpesa_tstamp			timestamp,
	mpesa_text				varchar(320),
	mpesa_code				varchar(50),
	mpesa_acc				varchar(50),
	mpesa_msisdn			varchar(50),
	mpesa_trx_date			date,
	mpesa_trx_time			time,
	mpesa_amt				real,
	mpesa_sender			varchar(50),
	mpesa_pick_time			timestamp default now(),
	voided					boolean default false not null,
	voided_by				integer,
	voided_date				timestamp
);
CREATE INDEX mpesa_trxs_receipt_id ON mpesa_trxs (receipt_id);
CREATE INDEX mpesa_trxs_org_id ON mpesa_trxs (org_id);

CREATE TABLE court_bankings (
	court_banking_id		serial primary key,
	bank_account_id			integer references bank_accounts,
	source_account_id		integer references bank_accounts,
	org_id					integer references orgs,
	bank_ref				varchar(50),
	banking_date			date,
	amount					real,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX court_bankings_bank_account_id ON court_bankings (bank_account_id);
CREATE INDEX court_bankings_source_account_id ON court_bankings (source_account_id);
CREATE INDEX court_bankings_org_id ON court_bankings (org_id);

CREATE TABLE surerity (
	surerity_id				serial primary key,
	receipts_id				integer references receipts,
	org_id					integer references orgs,
	surerity_name			varchar(120),
	relationship			varchar(120),
	id_card_no				varchar(120),
	id_issued_at			varchar(120),
	district				varchar(120),
	location				varchar(120),
	sub_location			varchar(120),
	village					varchar(120),
	residential_address		varchar(120),
	street					varchar(120),
	road					varchar(120),
	avenue					varchar(120),
	house_no				varchar(120),
	po_box					varchar(120),
	house_phone_no			varchar(120),
	occupation				varchar(120),
	employer				varchar(120),
	work_physical_address	varchar(120),
	telephone_no			varchar(120),
	surerity_income			varchar(120),
	other_information		text,
	change_by				integer,
	change_date				timestamp default now(),
	details					text
);
CREATE INDEX surerity_receipts_id ON surerity (receipts_id);
CREATE INDEX surerity_org_id ON surerity (org_id);

CREATE TABLE case_files (
	case_file_id			serial primary key,
	case_id					integer references cases,
	case_activity_id		integer references case_activity,
	case_decision_id		integer references case_decisions,
	org_id					integer references orgs,
	file_folder				varchar(320),
	file_name				varchar(320),
	file_type				varchar(320),
	file_size				integer,
	narrative				varchar(320),
	details					text
);
CREATE INDEX case_files_case_id ON case_files (case_id);
CREATE INDEX case_files_case_activity_id ON case_files (case_activity_id);
CREATE INDEX case_files_case_decision_id ON case_files (case_decision_id);
CREATE INDEX case_files_org_id ON case_files (org_id);

CREATE TABLE meetings (
	meeting_id				serial primary key,
	org_id					integer references orgs,
	meeting_name			varchar(320) not null,
	start_date				date not null,
	start_time				time not null,
	end_date				date not null,
	end_time				time not null,
	completed				boolean default false not null,
	details					text
);
CREATE INDEX meetings_org_id ON meetings (org_id);

CREATE TABLE participants (
	participant_id			serial primary key,
	meeting_id				integer references meetings,
	entity_id				integer not null references entitys,
	org_id					integer references orgs,
	meeting_role			varchar(50),
	details					text
);
CREATE INDEX participants_meeting_id ON participants (meeting_id);
CREATE INDEX participants_entity_id ON participants (entity_id);
CREATE INDEX participants_org_id ON participants (org_id);

CREATE VIEW vw_bench_subjects AS
	SELECT entitys.entity_id, entitys.entity_name, case_subjects.case_subject_id, case_subjects.case_subject_name, 
		bench_subjects.org_id, bench_subjects.bench_subject_id, bench_subjects.proficiency, bench_subjects.details
	FROM bench_subjects INNER JOIN case_subjects ON bench_subjects.case_subject_id = case_subjects.case_subject_id
	INNER JOIN entitys ON bench_subjects.entity_id = entitys.entity_id;

CREATE VIEW vw_case_category AS
	SELECT case_types.case_type_id, case_types.case_type_name, case_types.duration_unacceptable,
		case_types.duration_serious, case_types.duration_normal, case_types.duration_low,
		case_types.activity_unacceptable, case_types.activity_serious, case_types.activity_normal, case_types.activity_low,
		case_category.case_category_id, case_category.case_category_name, case_category.case_category_title, 
		case_category.case_category_no, case_category.act_code, case_category.death_sentence, case_category.life_sentence, 
		case_category.min_sentence, case_category.max_sentence, case_category.min_fine, case_category.max_fine, 
		case_category.min_canes, case_category.max_canes, case_category.details
	FROM case_category INNER JOIN case_types ON case_category.case_type_id = case_types.case_type_id;

CREATE VIEW vw_category_activitys AS
	SELECT case_types.case_type_id, case_types.case_type_name, 
		case_category.case_category_id, case_category.case_category_name,
		activitys.activity_id, activitys.activity_name, 
		from_activitys.activity_id as from_activity_id, from_activitys.activity_name as from_activity_name, 
		contact_types.contact_type_id, contact_types.contact_type_name, 
		category_activitys.category_activity_id, category_activitys.activity_order, category_activitys.warning_days, 
		category_activitys.deadline_days, category_activitys.mandatory, category_activitys.details
	FROM category_activitys INNER JOIN case_category ON category_activitys.case_category_id = case_category.case_category_id
		INNER JOIN case_types ON case_category.case_type_id = case_types.case_type_id
		INNER JOIN activitys ON category_activitys.activity_id = activitys.activity_id
		LEFT JOIN activitys as from_activitys ON category_activitys.from_activity_id = from_activitys.activity_id
		LEFT JOIN contact_types ON category_activitys.contact_type_id = contact_types.contact_type_id;

CREATE VIEW vw_cases AS
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

		cases.org_id, cases.case_id, cases.old_case_id, cases.case_title, cases.file_number, cases.case_number, cases.date_of_arrest, 
		cases.ob_number, cases.holding_prison, cases.warrant_of_arrest, cases.alleged_crime, cases.start_date, 
		cases.date_of_elections, cases.consolidate_cases, cases.new_case_id,
		cases.end_date, cases.nature_of_claim, cases.value_of_claim, cases.closed, cases.final_decision, cases.detail,

		(CASE WHEN closed = true THEN 0 ELSE 1 END) as open_cases,
		(CASE WHEN closed = true THEN 1 ELSE 0 END) as closed_cases
	FROM cases INNER JOIN vw_case_category ON cases.case_category_id = vw_case_category.case_category_id
		INNER JOIN vw_court_divisions ON cases.court_division_id = vw_court_divisions.court_division_id
		INNER JOIN case_subjects ON cases.case_subject_id = case_subjects.case_subject_id
		LEFT JOIN file_locations ON cases.file_location_id = file_locations.file_location_id
		LEFT JOIN police_stations ON cases.police_station_id = police_stations.police_station_id;

CREATE VIEW vw_case_transfers AS
	SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, 
		vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, 
		vw_case_category.case_category_no, vw_case_category.act_code,

		vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, 
		vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, 
		vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, 
		vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, 
		vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num,
		vw_court_divisions.court_division,

		case_transfers.case_id, case_transfers.org_id, case_transfers.case_transfer_id, case_transfers.judgment_date, 
		case_transfers.presiding_judge, case_transfers.previous_case_number, case_transfers.receipt_date,
		case_transfers.case_transfered,
		case_transfers.received_by, case_transfers.change_by, case_transfers.change_date, case_transfers.details
	FROM case_transfers	INNER JOIN vw_court_divisions ON case_transfers.court_division_id = vw_court_divisions.court_division_id
		INNER JOIN vw_case_category ON case_transfers.case_category_id = vw_case_category.case_category_id;

CREATE VIEW vw_case_activity AS
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
		vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.case_number, vw_cases.date_of_arrest, 
		vw_cases.date_of_elections, vw_cases.consolidate_cases, vw_cases.new_case_id,
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location,

		activitys.activity_id, activitys.activity_name, activitys.show_on_diary,
		activity_results.activity_result_id, activity_results.activity_result_name, 
		adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, 
		order_types.order_type_id, order_types.order_type_name, 

		vw_court_stations.court_station_id as transfer_station_id, vw_court_stations.court_station_name as transfer_station_name,
		vw_court_stations.court_station as transfer_station,

		case_activity.org_id, case_activity.case_activity_id, case_activity.appleal_case_id,
		case_activity.activity_date, case_activity.activity_time, case_activity.finish_time, 
		case_activity.shared_hearing, case_activity.change_by, case_activity.change_date, 
		case_activity.order_title, case_activity.order_narrative, case_activity.order_details, 
		case_activity.result_details, case_activity.adjorn_details, case_activity.appleal_details, 
		case_activity.details,


		case_activity.application_date, case_activity.approve_status, case_activity.workflow_table_id, case_activity.action_date
	FROM case_activity INNER JOIN vw_cases ON case_activity.case_id = vw_cases.case_id
		INNER JOIN vw_hearing_locations ON case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id
		INNER JOIN activitys ON case_activity.activity_id = activitys.activity_id
		INNER JOIN adjorn_reasons ON case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id
		LEFT JOIN activity_results ON case_activity.activity_result_id = activity_results.activity_result_id
		LEFT JOIN order_types ON case_activity.order_type_id = order_types.order_type_id
		LEFT JOIN vw_court_stations ON case_activity.court_station_id = vw_court_stations.court_station_id;

CREATE VIEW vw_case_entitys AS
	SELECT vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, 
		vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name,

		contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench,

		case_contacts.org_id, case_contacts.case_contact_id, case_contacts.case_id, case_contacts.case_contact_no, 
		case_contacts.is_active, case_contacts.is_disqualified, case_contacts.change_date, case_contacts.change_by
	FROM case_contacts INNER JOIN vw_entitys ON case_contacts.entity_id = vw_entitys.entity_id
		INNER JOIN contact_types ON case_contacts.contact_type_id = contact_types.contact_type_id;

CREATE VIEW vw_case_contacts AS
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
		vw_cases.date_of_elections,
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, 
		vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name,

		political_parties.political_party_id, political_parties.political_party_name,

		contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench,
		case_contacts.org_id, case_contacts.case_contact_id, case_contacts.case_contact_no, 
		case_contacts.is_active, case_contacts.is_disqualified, case_contacts.change_date, case_contacts.change_by,
		case_contacts.election_winner, case_contacts.details
	FROM case_contacts INNER JOIN vw_cases ON case_contacts.case_id = vw_cases.case_id
		INNER JOIN vw_entitys ON case_contacts.entity_id = vw_entitys.entity_id
		INNER JOIN contact_types ON case_contacts.contact_type_id = contact_types.contact_type_id
		LEFT JOIN political_parties ON case_contacts.political_party_id = political_parties.political_party_id;

CREATE VIEW vw_case_counts AS
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

		case_counts.org_id, case_counts.case_count_id, case_counts.narrative, case_counts.detail
	FROM case_counts INNER JOIN vw_case_contacts ON case_counts.case_contact_id = vw_case_contacts.case_contact_id
		INNER JOIN vw_case_category ON case_counts.case_category_id = vw_case_category.case_category_id;

CREATE VIEW vw_case_decisions AS
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
		vw_cases.date_of_elections,
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		decision_types.decision_type_id, decision_types.decision_type_name, 
		judgment_status.judgment_status_id, judgment_status.judgment_status_name,

		case_decisions.org_id, case_decisions.case_decision_id, case_decisions.case_activity_id,
		case_decisions.decision_summary, case_decisions.judgement, 
		case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, 
		case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.fine_jail,
		case_decisions.canes, case_decisions.detail
	FROM case_decisions	INNER JOIN vw_cases ON case_decisions.case_id = vw_cases.case_id
		INNER JOIN decision_types ON case_decisions.decision_type_id = decision_types.decision_type_id
		INNER JOIN judgment_status ON case_decisions.judgment_status_id = judgment_status.judgment_status_id;

CREATE VIEW vw_case_count_decisions AS
	SELECT vw_case_counts.region_id, vw_case_counts.region_name, vw_case_counts.county_id, vw_case_counts.county_name,
		vw_case_counts.court_rank_id, vw_case_counts.court_rank_name, 
		vw_case_counts.court_station_id, vw_case_counts.court_station_name, vw_case_counts.court_station_code, vw_case_counts.court_station,
		vw_case_counts.division_type_id, vw_case_counts.division_type_name, 
		vw_case_counts.court_division_id, vw_case_counts.court_division_code, vw_case_counts.court_division_num,
		vw_case_counts.court_division,
		vw_case_counts.file_location_id, vw_case_counts.file_location_name, 
		vw_case_counts.police_station_id, vw_case_counts.police_station_name,
		vw_case_counts.case_id, vw_case_counts.case_title, vw_case_counts.file_number, vw_case_counts.date_of_arrest, 
		vw_case_counts.ob_number, vw_case_counts.holding_prison, vw_case_counts.warrant_of_arrest, vw_case_counts.alleged_crime, vw_case_counts.start_date, 
		vw_case_counts.end_date, vw_case_counts.nature_of_claim, vw_case_counts.value_of_claim, vw_case_counts.closed, vw_case_counts.final_decision,
		vw_case_counts.entity_id, vw_case_counts.entity_name, vw_case_counts.user_name, vw_case_counts.primary_email, 
		vw_case_counts.gender, vw_case_counts.date_of_birth, 
		vw_case_counts.contact_type_id, vw_case_counts.contact_type_name,
		vw_case_counts.case_contact_id, vw_case_counts.case_contact_no,
		vw_case_counts.case_type_id, vw_case_counts.case_type_name, 
		vw_case_counts.case_category_id, vw_case_counts.case_category_name, vw_case_counts.case_category_title, 
		vw_case_counts.case_category_no, vw_case_counts.act_code,
		vw_case_counts.case_count_id, vw_case_counts.narrative,

		decision_types.decision_type_id, decision_types.decision_type_name,
		judgment_status.judgment_status_id, judgment_status.judgment_status_name,

		case_decisions.org_id, case_decisions.case_decision_id, case_decisions.case_activity_id,
		case_decisions.decision_summary, case_decisions.judgement, 
		case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, 
		case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.canes, 
		case_decisions.detail
	FROM case_decisions	INNER JOIN vw_case_counts ON case_decisions.case_count_id = vw_case_counts.case_count_id
		INNER JOIN decision_types ON case_decisions.decision_type_id = decision_types.decision_type_id
		INNER JOIN judgment_status ON case_decisions.judgment_status_id = judgment_status.judgment_status_id;

CREATE VIEW vw_case_quorum AS
	SELECT vw_case_activity.case_type_id, vw_case_activity.case_type_name, 
		vw_case_activity.case_category_id, vw_case_activity.case_category_name, vw_case_activity.case_category_title, 
		vw_case_activity.case_category_no, vw_case_activity.act_code, vw_case_activity.region_id, 
		vw_case_activity.region_name, vw_case_activity.county_id, vw_case_activity.county_name, vw_case_activity.court_rank_id,
		vw_case_activity.court_rank_name, vw_case_activity.court_station_id, vw_case_activity.court_station_name, 
		vw_case_activity.court_station_code, vw_case_activity.court_station, vw_case_activity.division_type_id, 
		vw_case_activity.division_type_name, vw_case_activity.court_division_id, vw_case_activity.court_division_code, 
		vw_case_activity.court_division_num, vw_case_activity.court_division, 
		vw_case_activity.file_location_id, vw_case_activity.file_location_name, 
		vw_case_activity.police_station_id, vw_case_activity.police_station_name, vw_case_activity.case_id, 
		vw_case_activity.case_title, vw_case_activity.file_number, vw_case_activity.case_number, vw_case_activity.date_of_arrest, 
		vw_case_activity.date_of_elections,
		vw_case_activity.ob_number, vw_case_activity.holding_prison, vw_case_activity.warrant_of_arrest, vw_case_activity.alleged_crime, 
		vw_case_activity.start_date, vw_case_activity.end_date, vw_case_activity.nature_of_claim, vw_case_activity.value_of_claim, 
		vw_case_activity.closed, vw_case_activity.final_decision,

		vw_case_activity.hearing_location_id, vw_case_activity.hearing_location_name, vw_case_activity.hearing_location,

		vw_case_activity.activity_id, vw_case_activity.activity_name, vw_case_activity.show_on_diary,
		vw_case_activity.activity_result_id, vw_case_activity.activity_result_name, 
		vw_case_activity.adjorn_reason_id, vw_case_activity.adjorn_reason_name, 
		vw_case_activity.order_type_id, vw_case_activity.order_type_name, 

		vw_case_activity.case_activity_id, vw_case_activity.activity_date, vw_case_activity.activity_time, 
		vw_case_activity.finish_time, vw_case_activity.shared_hearing, vw_case_activity.change_by, vw_case_activity.change_date, vw_case_activity.details,

		vw_case_entitys.entity_id, vw_case_entitys.entity_name, vw_case_entitys.user_name, vw_case_entitys.primary_email, 
		vw_case_entitys.gender, vw_case_entitys.date_of_birth, vw_case_entitys.ranking_id, vw_case_entitys.ranking_name,

		vw_case_entitys.contact_type_id, vw_case_entitys.contact_type_name, vw_case_entitys.bench,

		vw_case_entitys.case_contact_id, vw_case_entitys.case_contact_no, 
		vw_case_entitys.is_active, vw_case_entitys.is_disqualified,

		case_quorum.org_id, case_quorum.case_quorum_id, case_quorum.narrative
	FROM vw_case_activity INNER JOIN case_quorum ON vw_case_activity.case_activity_id = case_quorum.case_activity_id
		INNER JOIN vw_case_entitys ON case_quorum.case_contact_id = vw_case_entitys.case_contact_id;

CREATE VIEW vw_case_bookmarks AS
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
		vw_cases.date_of_elections,
		vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, 
		vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision,

		entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email,

		case_bookmarks.case_bookmark_id, case_bookmarks.org_id, case_bookmarks.entry_date, case_bookmarks.notes
	FROM vw_cases INNER JOIN case_bookmarks ON vw_cases.case_id = case_bookmarks.case_id
		INNER JOIN entitys ON case_bookmarks.entity_id = entitys.entity_id;

CREATE VIEW vws_court_payments AS
	SELECT receipt_id, sum(amount) as t_amount
	FROM court_payments
	GROUP BY receipt_id;

CREATE VIEW vws_mpesa_trxs AS
	SELECT receipt_id, sum(mpesa_amt) as t_mpesa_amt
	FROM mpesa_trxs 
	GROUP BY receipt_id;

CREATE VIEW vw_receipts AS
	SELECT vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name,
		receipt_types.receipt_type_id, receipt_types.receipt_type_name, receipt_types.require_refund,
		receipts.org_id, receipts.case_id, receipts.case_decision_id, receipts.receipt_id,
		receipts.receipt_for, receipts.case_number, receipts.receipt_date, receipts.amount, 
		receipts.approved, receipts.for_process, receipts.refund_approved, receipts.details,
		t_amount, t_mpesa_amt,
		(COALESCE(t_amount, 0) + COALESCE(t_mpesa_amt, 0)) as total_paid,
		(receipts.amount - (COALESCE(t_amount, 0) + COALESCE(t_mpesa_amt, 0))) as balance
	FROM receipts INNER JOIN vw_court_stations ON receipts.court_station_id = vw_court_stations.court_station_id
		INNER JOIN receipt_types ON receipts.receipt_type_id = receipt_types.receipt_type_id
		LEFT JOIN vws_court_payments ON receipts.receipt_id = vws_court_payments.receipt_id
		LEFT JOIN vws_mpesa_trxs ON receipts.receipt_id = vws_mpesa_trxs.receipt_id;

CREATE VIEW vw_court_payments AS
		SELECT vw_receipts.court_rank_id, vw_receipts.court_rank_name, vw_receipts.court_station_id, vw_receipts.court_station_name,
		vw_receipts.receipt_type_id, vw_receipts.receipt_type_name, vw_receipts.require_refund,
		vw_receipts.case_id, vw_receipts.case_decision_id, vw_receipts.receipt_id,
		vw_receipts.receipt_for, vw_receipts.case_number, vw_receipts.receipt_date, vw_receipts.amount as receipt_amount, 
		vw_receipts.approved, vw_receipts.for_process, vw_receipts.refund_approved, 
		vw_receipts.t_amount, vw_receipts.t_mpesa_amt, vw_receipts.total_paid, vw_receipts.balance,

		bank_accounts.bank_account_id, bank_accounts.bank_account_name, 
		payment_types.payment_type_id, payment_types.payment_type_name, 

		court_payments.org_id, court_payments.court_payment_id, 
		court_payments.bank_ref, court_payments.payment_date, court_payments.amount, court_payments.r_amount, 
		court_payments.jail_days, court_payments.credit_note, court_payments.refund, court_payments.is_active, 
		court_payments.change_by, court_payments.change_date, court_payments.details
	FROM vw_receipts INNER JOIN court_payments ON vw_receipts.receipt_id = court_payments.receipt_id
		INNER JOIN bank_accounts ON court_payments.bank_account_id = bank_accounts.bank_account_id
		INNER JOIN payment_types ON court_payments.payment_type_id = payment_types.payment_type_id;

CREATE VIEW vw_court_bankings AS
	SELECT sb.bank_account_id as source_account_id, sb.bank_account_name as source_account_name, 
		db.bank_account_id, db.bank_account_name, 
		court_bankings.org_id, court_bankings.court_banking_id, court_bankings.bank_ref, court_bankings.banking_date, 
		court_bankings.amount, court_bankings.change_by, court_bankings.change_date, court_bankings.details
	FROM court_bankings INNER JOIN bank_accounts as sb ON court_bankings.source_account_id = sb.bank_account_id
		INNER JOIN bank_accounts as db ON court_bankings.bank_account_id = db.bank_account_id;

CREATE VIEW vw_banking_balances AS
	(SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 
		'Payment'::text as narrative, court_payments.org_id, court_payments.bank_ref, court_payments.payment_date, 
		(CASE WHEN court_payments.refund = false THEN court_payments.amount ELSE 0::real END) as debit,
		(CASE WHEN court_payments.refund = true THEN court_payments.amount ELSE 0::real END) as credit		 
	FROM court_payments INNER JOIN bank_accounts ON court_payments.bank_account_id = bank_accounts.bank_account_id
	WHERE (court_payments.credit_note = false))
	UNION
	(SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 
		'Withdrawal'::text as narrative, court_bankings.org_id, court_bankings.bank_ref, court_bankings.banking_date, 
		0::real as debit, court_bankings.amount as credit
	FROM court_bankings INNER JOIN bank_accounts ON court_bankings.source_account_id = bank_accounts.bank_account_id)
	UNION
	(SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 
		'Banking'::text as narrative, court_bankings.org_id, court_bankings.bank_ref, court_bankings.banking_date, 
		court_bankings.amount, 0::real
	FROM court_bankings INNER JOIN bank_accounts ON court_bankings.bank_account_id = bank_accounts.bank_account_id);

CREATE VIEW vw_participants AS
	SELECT meetings.meeting_id, meetings.meeting_name, 
		meetings.start_date, meetings.start_time, meetings.end_date, meetings.end_time, meetings.completed,
		entitys.entity_id, entitys.entity_name, 
		participants.org_id, participants.participant_id, participants.meeting_role, participants.details
	FROM participants INNER JOIN meetings ON participants.meeting_id = meetings.meeting_id
	INNER JOIN entitys ON participants.entity_id = entitys.entity_id;

CREATE OR REPLACE FUNCTION ins_cases() RETURNS trigger AS $$
DECLARE
	v_code 		varchar(16);
	v_ss		varchar(12);
	v_orgid		integer;
	v_num		integer;
BEGIN

	SELECT COALESCE(court_division_code, ''), court_division_num, org_id INTO v_code, v_num, v_orgid
	FROM court_divisions
	WHERE (court_division_id = NEW.court_division_id);

	SELECT special_suffix INTO v_ss
	FROM case_category
	WHERE (case_category_id = NEW.case_category_id);

	IF(v_ss is null)THEN
		v_ss := '';
	ELSE
		v_ss := v_ss || '/';
	END IF;
	
	IF(NEW.file_number is null)THEN
		NEW.file_number := v_ss || v_code || '/' || lpad(cast(v_num as varchar), 4, '0') || '/' || to_char(current_date, 'YY');
		UPDATE court_divisions SET court_division_num = v_num + 1 WHERE (court_division_id = NEW.court_division_id);
	END IF;

	IF (NEW.consolidate_cases = true)THEN
		IF(NEW.org_id <> v_orgid)THEN
			NEW.org_id := v_orgid;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_cases BEFORE INSERT OR UPDATE ON cases
    FOR EACH ROW EXECUTE PROCEDURE ins_cases();

CREATE OR REPLACE FUNCTION ins_case_files() RETURNS trigger AS $$
BEGIN

	IF(NEW.case_activity_id is not null)THEN
		SELECT case_id INTO NEW.case_id
		FROM case_activity
		WHERE (case_activity_id = NEW.case_activity_id);
	END IF;

	IF(NEW.case_decision_id is not null)THEN
		SELECT case_id INTO NEW.case_id
		FROM case_decisions
		WHERE (case_decision_id = NEW.case_decision_id);
	END IF;

	SELECT replace(replace(file_number, '/', ''), ' ', '') INTO NEW.file_folder
	FROM cases
	WHERE (case_id = NEW.case_id);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_case_files BEFORE INSERT ON case_files
    FOR EACH ROW EXECUTE PROCEDURE ins_case_files();

CREATE OR REPLACE FUNCTION ins_case_decisions() RETURNS trigger AS $$
DECLARE
	v_caseid		INTEGER;
BEGIN
	IF(NEW.case_activity_id is not null)THEN
		SELECT case_id INTO v_caseid
		FROM case_activity
		WHERE (case_activity_id = NEW.case_activity_id);
		NEW.case_id := v_caseid;
	END IF;

	IF(NEW.case_count_id is not null)THEN
		SELECT case_contacts.case_id INTO v_caseid 
		FROM case_counts INNER JOIN case_contacts ON case_counts.case_contact_id = case_contacts.case_contact_id
		WHERE (case_counts.case_count_id = NEW.case_count_id);

		NEW.case_id := v_caseid;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_case_decisions BEFORE INSERT ON case_decisions
    FOR EACH ROW EXECUTE PROCEDURE ins_case_decisions();

CREATE OR REPLACE FUNCTION aft_case_decisions() RETURNS trigger AS $$
BEGIN
	IF(NEW.case_count_id is not null) AND (NEW.fine_amount > 0) THEN
		INSERT INTO receipts (case_id, case_decision_id, receipt_type_id, org_id, receipt_date, amount, for_process)
		VALUES (NEW.case_id, NEW.case_decision_id, 2, NEW.org_id, CURRENT_DATE, NEW.fine_amount, true);
	END IF;
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_case_decisions AFTER INSERT ON case_decisions
    FOR EACH ROW EXECUTE PROCEDURE aft_case_decisions();

CREATE OR REPLACE FUNCTION upd_receipts() RETURNS trigger AS $$
DECLARE
	v_caseid		INTEGER;
	v_courtid		INTEGER;
	v_fileno		varchar(50);
BEGIN

	IF(NEW.amount < 0)THEN
		RAISE EXCEPTION 'Cannot charge a negative amount';
	END IF;

	IF(TG_OP = 'INSERT')THEN
		IF(NEW.receipt_date < CURRENT_DATE-7)THEN
			RAISE EXCEPTION 'Cannot enter a previous date';
		END IF;

		IF(NEW.case_decision_id is not null)THEN
			SELECT case_id INTO v_caseid FROM case_decisions
			WHERE (case_decision_id = NEW.case_decision_id);
			NEW.case_id := v_caseid;
		END IF;

		IF((NEW.case_id is not null) AND (NEW.case_number is null))THEN
			SELECT file_number INTO v_fileno FROM cases
			WHERE (case_id = NEW.case_id);
			NEW.case_number := v_fileno;
		END IF;

		IF((NEW.case_id is not null) AND (NEW.court_station_id is null))THEN
			SELECT court_divisions.court_station_id INTO v_courtid
			FROM cases INNER JOIN court_divisions ON cases.court_division_id = court_divisions.court_division_id
			WHERE (cases.case_id = NEW.case_id);
			NEW.court_station_id := v_courtid;
		END IF;
	END IF;
	IF(TG_OP = 'UPDATE')THEN
		IF(OLD.amount <> NEW.amount) THEN
			RAISE EXCEPTION 'Cannot make changes to amount.';
		END IF;
		IF(OLD.approved = true) AND (NEW.approved = true) THEN
			RAISE EXCEPTION 'Cannot make changes to an approved receipt.';
		END IF;
	END IF;

	NEW.case_number := upper(trim(NEW.case_number));

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_receipts BEFORE INSERT OR UPDATE ON receipts
    FOR EACH ROW EXECUTE PROCEDURE upd_receipts();

CREATE OR REPLACE FUNCTION upd_court_payments() RETURNS trigger AS $$
BEGIN

	IF(NEW.payment_date < CURRENT_DATE-7)THEN
		RAISE EXCEPTION 'Cannot enter a previous date';
	END IF;

	IF(NEW.r_amount is not null)THEN
		NEW.amount := NEW.r_amount * (-1);
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_court_payments BEFORE INSERT OR UPDATE ON court_payments
    FOR EACH ROW EXECUTE PROCEDURE upd_court_payments();

CREATE OR REPLACE FUNCTION approve_receipt(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec 			RECORD;
	reca 			RECORD;
	recb 			RECORD;
	v_balance		REAL;
	v_receipt_no	INTEGER;
	msg 			VARCHAR(120);
BEGIN
	SELECT org_id, case_id, case_decision_id, receipt_id, amount, approved, total_paid, balance, 
		case_number, receipt_for INTO rec
	FROM vw_receipts
	WHERE (receipt_id = CAST($1 as integer));

	IF(rec.receipt_id is null) THEN
		msg := 'No transaction of this type found';
	ELSIF($3 = '2') THEN
		IF(rec.balance <= rec.amount) THEN
			UPDATE receipts SET refund_approved = true
			WHERE (receipt_id = rec.receipt_id);
			msg := 'Refund approved.';
		ELSE
			msg := 'The refund must be less than or equal to the deposit';
		END IF;
	ELSIF(rec.approved = true) THEN
		msg := 'Transaction already approved.';
	ELSIF(rec.balance > 0) THEN
		msg := 'You need to clear the payment before approval';	
	ELSIF($3 = '1') THEN
		SELECT case_decision_id, fine_amount, fine_jail INTO reca
		FROM case_decisions
		WHERE (is_active = true) AND (death_sentence = false) AND (life_sentence = false)
			AND (jail_years is null) AND (jail_days is null) AND (canes is null)
			AND (judgment_status_id =  1) AND (case_decision_id = rec.case_decision_id);
		IF(reca.case_decision_id is not null)THEN
			UPDATE case_decisions SET judgment_status_id = 3 WHERE (case_decision_id = rec.case_decision_id);
		END IF;

		SELECT case_decision_id, judgment_status_id, fine_amount, fine_jail INTO recb
		FROM case_decisions
		WHERE (is_active = true) AND ((judgment_status_id = 1) OR (judgment_status_id = 2))
			AND (case_id = rec.case_id);

		SELECT sum(balance) INTO v_balance
		FROM vw_receipts
		WHERE (case_id = rec.case_id);

		SELECT count(receipt_id) INTO v_receipt_no
		FROM vw_receipts
		WHERE (case_id = rec.case_id) and (approved = false);

		IF((rec.case_id is not null) and (recb.case_decision_id is null) AND (v_balance < 1) AND (v_receipt_no = 0))THEN
			UPDATE cases SET closed = true WHERE case_id = rec.case_id;
		END IF;

		INSERT INTO sms (folder_id, sms_origin, message_ready, org_id, sms_number, message)
		SELECT 0, 'RECEIPTS', true, rec.org_id, '+' || mpesa_msisdn,  
			'Receipt of KES ' || mpesa_amt || ' for payment of receipt number ' || rec.receipt_id 
			|| ' for case number ' || rec.case_number || ' for ' || rec.receipt_for
		FROM mpesa_trxs
		WHERE (receipt_id = rec.receipt_id);

		UPDATE receipts SET approved = true
		WHERE (receipt_id = rec.receipt_id);

		msg := 'Receipt approved.';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_allocation(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec RECORD;
	msg varchar(120);
BEGIN

	UPDATE mpesa_trxs SET receipt_id = null
	WHERE (mpesa_trx_id  = CAST($1 as integer));

	msg := 'Receipt approved.';

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_case_contacts() RETURNS trigger AS $$
DECLARE
	v_no		INTEGER;
BEGIN
	
	SELECT max(case_contact_no) INTO v_no 
	FROM case_contacts 
	WHERE (case_id = NEW.case_id) AND (contact_type_id = NEW.contact_type_id);

	IF(v_no is null)THEN
		NEW.case_contact_no := 1;
	ELSE
		NEW.case_contact_no := v_no + 1;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_case_contacts BEFORE INSERT ON case_contacts
    FOR EACH ROW EXECUTE PROCEDURE ins_case_contacts();

CREATE OR REPLACE FUNCTION aft_case_contacts() RETURNS trigger AS $$
DECLARE
	v_categoryid		INTEGER;
BEGIN
	SELECT case_category_id INTO v_categoryid FROM cases 
	WHERE (case_id = NEW.case_id);

	IF(NEW.contact_type_id = 4)THEN
		INSERT INTO case_counts (org_id, case_contact_id, case_category_id)
		VALUES(NEW.org_id, NEW.case_contact_id, v_categoryid);
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_case_contacts AFTER INSERT ON case_contacts
    FOR EACH ROW EXECUTE PROCEDURE aft_case_contacts();

CREATE OR REPLACE FUNCTION manage_case(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg 				varchar(120);
	v_case_title		varchar(320);
	v_entity_name		varchar(120);
	v_plaintaive		varchar(120);
	v_case_type_id		integer;
	v_plaintaive_count	integer;
	v_contact_count		integer;
	v_old_case_id		integer;
	v_lock				boolean;
BEGIN

	IF ($3 = '1') THEN
		UPDATE cases SET closed = true WHERE (case_id = CAST($1 as int));

		SELECT old_case_id INTO v_old_case_id
		FROM cases WHERE case_id = CAST($1 as int);

		UPDATE cases SET case_locked = false WHERE (case_id = v_old_case_id);
		msg := 'Case closed.';
	ELSIF ($3 = '2') THEN
		SELECT case_locked INTO v_lock
		FROM cases WHERE case_id = CAST($1 as int);
		IF(v_lock = true)THEN
			msg := 'Case locked by appleal, which needs to be closed first';
		ELSE
			UPDATE cases SET closed = false WHERE case_id = CAST($1 as int);
			msg := 'Case opened.';
		END IF;
	ELSIF ($3 = '3') THEN
		SELECT case_category.case_type_id, cases.case_title INTO v_case_type_id, v_case_title
		FROM case_category INNER JOIN cases ON case_category.case_category_id = cases.case_category_id
		WHERE (cases.case_id = CAST($1 as int));

		IF(v_case_type_id =  1)THEN
			SELECT count(case_contact_id) INTO v_contact_count
			FROM case_contacts
			WHERE (case_contacts.contact_type_id = 4) AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_entity_name
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id = 4) AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			IF(v_entity_name is null)THEN
				msg := 'Title not added';
			ELSIF(v_contact_count = 1)THEN
				UPDATE cases SET case_title = 'Republic Vs ' || v_entity_name 
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSE
				UPDATE cases SET case_title = 'Republic Vs ' || v_entity_name || ' and others'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			END IF;
		ELSIF(v_case_type_id =  3)THEN
						SELECT count(case_contact_id) INTO v_plaintaive_count
			FROM case_contacts
			WHERE (case_contacts.contact_type_id IN (4, 5, 7, 9, 10))
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_entity_name
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id IN (4, 5, 7, 9, 10))
				AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			IF(v_entity_name is null)THEN
				msg := 'Title not added';
			ELSIF(v_contact_count = 1)THEN
				UPDATE cases SET case_title = v_entity_name || ' Vs Republic'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSE
				UPDATE cases SET case_title = v_entity_name || ' and others Vs Republic'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			END IF;
		ELSIF((v_case_type_id =  2) OR (v_case_type_id =  4) OR (v_case_type_id =  7)) THEN
			SELECT count(case_contact_id) INTO v_plaintaive_count
			FROM case_contacts
			WHERE (case_contacts.contact_type_id IN (5, 7, 9, 10))
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT count(case_contact_id) INTO v_contact_count
			FROM case_contacts
			WHERE (case_contacts.contact_type_id IN (6, 8))
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_plaintaive
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id IN (5, 7, 9, 10))
				AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_entity_name
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id IN (6, 8))
				AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			IF((v_entity_name is null) OR (v_plaintaive is null))THEN
				msg := 'Title not added';
			ELSIF(v_plaintaive_count = 1) AND (v_contact_count = 1)THEN
				UPDATE cases SET case_title = v_plaintaive || ' Vs ' || v_entity_name 
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSIF(v_plaintaive_count > 1) AND (v_contact_count = 1)THEN
				UPDATE cases SET case_title = v_plaintaive || ' and others Vs ' || v_entity_name
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSIF(v_plaintaive_count = 1) AND (v_contact_count > 1)THEN
				UPDATE cases SET case_title = v_plaintaive || ' Vs ' || v_entity_name || ' and others'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSE
				UPDATE cases SET case_title = v_plaintaive || ' and others Vs ' || v_entity_name || ' and others'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			END IF;
		ELSIF(v_case_type_id =  5)THEN

			SELECT count(case_contact_id) INTO v_contact_count
			FROM case_contacts
			WHERE (case_contacts.contact_type_id = 8) AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_entity_name
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id = 8) AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_plaintaive
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE (case_contacts.contact_type_id = 10) AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			IF((v_entity_name is null) OR (v_plaintaive is null))THEN
				msg := 'Title not added';
			ELSIF(v_contact_count = 1)THEN
				UPDATE cases SET case_title = v_plaintaive || ' Vs ' || v_entity_name 
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSE
				UPDATE cases SET case_title = v_plaintaive || ' Vs ' || v_entity_name || ' and others'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			END IF;
		ELSE
			SELECT count(case_contact_id) INTO v_contact_count
			FROM case_contacts
			WHERE ((case_contacts.contact_type_id = 7) OR (case_contacts.contact_type_id = 9)) 
				AND (case_contacts.case_id = CAST($1 as int));

			SELECT entity_name INTO v_entity_name
			FROM entitys INNER JOIN case_contacts ON entitys.entity_id = case_contacts.entity_id
			WHERE ((case_contacts.contact_type_id = 7) OR (case_contacts.contact_type_id = 9)) 
				AND (case_contacts.case_contact_no = 1)
				AND (case_contacts.case_id = CAST($1 as int));

			IF(v_entity_name is null)THEN
				msg := 'Title not added';
			ELSIF(v_contact_count = 1)THEN
				UPDATE cases SET case_title = v_entity_name || ' Vs Republic'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			ELSE
				UPDATE cases SET case_title = v_entity_name || ' and others Vs Republic'
				WHERE (case_title = 'NEW') AND (case_id = CAST($1 as int));
			END IF;
		END IF;
		msg := 'Title added';
	ELSIF ($3 = '4') THEN
		msg := add_judges(CAST($1 as integer));
	ELSIF ($3 = '5') THEN
		INSERT INTO case_bookmarks (case_id, entity_id, org_id)
		SELECT CAST($1 AS integer), entity_id, org_id
		FROM entitys
		WHERE (entity_id = CAST($2 as integer));
		msg := 'Bookmark added';
	ELSIF ($3 = '6') THEN
		DELETE FROM case_bookmarks WHERE (case_bookmark_id = CAST($1 as integer));
		msg := 'Bookmark removed';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_judges(integer) RETURNS varchar(120) AS $$
DECLARE
	msg 			varchar(120);
	v_orgid			integer;
	v_next			integer;

	v_fentity		integer;
	v_entity		integer;
BEGIN

	SELECT orgs.org_id, orgs.bench_next INTO v_orgid, v_next
	FROM orgs INNER JOIN cases ON orgs.org_id = cases.org_id
	WHERE (cases.case_id  = $1);

	SELECT min(entity_id) INTO v_fentity
	FROM entitys
	WHERE (ranking_id is not null) AND (is_available = true) AND (org_id = v_orgid);

	IF(v_next is null)THEN
		v_entity := v_fentity;
	ELSE
		SELECT min(entity_id) INTO v_entity
		FROM entitys
		WHERE (ranking_id is not null) AND (is_available = true) AND (org_id = v_orgid)
			AND (entity_id > v_next);
		IF(v_entity is null)THEN
			v_entity := v_fentity;
		END IF;
	END IF;

	IF(v_entity is not null)THEN
		UPDATE orgs SET bench_next = v_entity WHERE (org_id = v_orgid);
		INSERT INTO case_contacts (case_id, contact_type_id, org_id, entity_id)
		VALUES ($1, 3, v_orgid, v_entity);
		msg := 'Added';
	ELSE
		msg := 'Not Added';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_case_activity() RETURNS trigger AS $$
BEGIN
	
	IF (NEW.activity_time > NEW.finish_time) THEN
		RAISE EXCEPTION 'Ending time must be greater than starting time';
	END IF;

	IF ((NEW.activity_date > current_date + 750) OR (NEW.activity_date < current_date - 750)) THEN
		RAISE EXCEPTION 'Date must be within 2 year limit';
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_case_activity BEFORE INSERT OR UPDATE ON case_activity
    FOR EACH ROW EXECUTE PROCEDURE ins_case_activity();

CREATE OR REPLACE FUNCTION checkEntity(varchar(32)) RETURNS varchar(320) AS $$
DECLARE
	v_entity_id		varchar(16);
	v_entity		varchar(320);
	msg				varchar(320);
BEGIN

	IF(length($1) > 2)THEN
		SELECT entity_id, entity_name INTO v_entity_id, v_entity
		FROM entitys 
		WHERE (identification =  trim($1));

		IF(v_entity IS NULL)  THEN           
			msg := '<RSP><MSG>Name not found</MSG></RSP>';
		ELSE
			msg := '<RSP><ID>' || v_entity_id || '</ID><MSG>Search found (' || v_entity ||')</MSG></RSP>';
		END IF;
	ELSE
		msg := '<RSP><MSG>Add more characters</MSG></RSP>';
	END IF;
 
	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION manage_qorum(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_orgid			integer;
	msg 			varchar(120);
BEGIN
	
	SELECT org_id INTO v_orgid
	FROM case_activity
	WHERE (case_activity_id = CAST($4 as integer));

	IF ($3 = '1') THEN
		INSERT INTO case_quorum (case_activity_id, case_contact_id, org_id)
		VALUES(CAST($4 as integer), CAST($1 as integer), v_orgid);
	ELSIF ($3 = '2') THEN
		DELETE FROM case_quorum WHERE case_quorum_id = CAST($1 as integer);
	END IF;

	msg := 'Done';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION manage_appleal(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec				RECORD;
	v_caseid		integer;
	v_orgid			integer;
	v_courtid		integer;
	msg 			varchar(120);
BEGIN

	IF ($3 = '1') THEN
		SELECT case_id, case_type_id, case_subject_id, police_station_id, case_title,
			date_of_arrest, ob_number, holding_prison, alleged_crime INTO rec
		FROM vw_cases
		WHERE (case_id = CAST($1 as integer));

		SELECT org_id INTO v_orgid
		FROM entitys
		WHERE (entity_id = CAST($2 as integer));

		IF (rec.case_type_id = 1) OR (rec.case_type_id = 3) THEN
			SELECT court_division_id INTO v_courtid
			FROM vw_court_divisions
			WHERE (division_type_id = 1) AND (org_id = v_orgid);

			v_caseid := nextval('cases_case_id_seq');
			INSERT INTO cases (case_id, case_category_id, court_division_id, case_subject_id, police_station_id,
				start_date, org_id, old_case_id, case_title, 
				date_of_arrest, ob_number, holding_prison, alleged_crime, change_by)
			VALUES (v_caseid, 1, v_courtid, rec.case_subject_id, rec.police_station_id,
				current_date, v_orgid, rec.case_id, rec.case_title, 
				rec.date_of_arrest, rec.ob_number, rec.holding_prison, rec.alleged_crime, CAST($2 as integer));

			INSERT INTO case_contacts (org_id, case_id, entity_id, contact_type_id, change_by)
			SELECT v_orgid, v_caseid, entity_id, contact_type_id, CAST($2 as integer)
			FROM case_contacts
			WHERE (contact_type_id = 1) AND (case_id = CAST($1 as integer));

			UPDATE case_activity SET appleal_case_id = v_caseid
			WHERE (appleal_case_id is null) AND (case_id = CAST($1 as integer));

			UPDATE cases SET closed = true, case_locked = true
			WHERE (case_id = rec.case_id);
		ELSIF (rec.case_type_id = 2) OR (rec.case_type_id = 4) THEN
			SELECT court_division_id INTO v_courtid
			FROM vw_court_divisions
			WHERE (division_type_id = 2) AND (org_id = v_orgid);

			v_caseid := nextval('cases_case_id_seq');
			INSERT INTO cases (case_id, case_category_id, court_division_id, case_subject_id, 
				start_date, org_id, old_case_id, case_title, change_by)
			VALUES (v_caseid, 2, v_courtid, rec.case_subject_id, 
				current_date, v_orgid, rec.case_id, rec.case_title, CAST($2 as integer));

			INSERT INTO case_contacts (org_id, case_id, entity_id, contact_type_id, change_by)
			SELECT v_orgid, v_caseid, entity_id, contact_type_id, CAST($2 as integer)
			FROM case_contacts
			WHERE ((contact_type_id = 5) OR (contact_type_id = 6)) AND (case_id = CAST($1 as integer));

			UPDATE case_activity SET appleal_case_id = v_caseid
			WHERE (appleal_case_id is null) AND (case_id = CAST($1 as integer));

			UPDATE cases SET closed = true, case_locked = true
			WHERE (case_id = rec.case_id);
		ELSIF (rec.case_type_id = 5) THEN
			SELECT court_division_id INTO v_courtid
			FROM vw_court_divisions
			WHERE (division_type_id = 5) AND (org_id = v_orgid);

			v_caseid := nextval('cases_case_id_seq');
			INSERT INTO cases (case_id, case_category_id, court_division_id, case_subject_id, 
				start_date, org_id, old_case_id, case_title, change_by)
			VALUES (v_caseid, 417, v_courtid, rec.case_subject_id, 
				current_date, v_orgid, rec.case_id, rec.case_title, CAST($2 as integer));

			INSERT INTO case_contacts (org_id, case_id, entity_id, contact_type_id, change_by)
			SELECT v_orgid, v_caseid, entity_id, contact_type_id, CAST($2 as integer)
			FROM case_contacts
			WHERE (contact_type_id IN (6, 7, 8, 9, 10, 11, 12, 13, 14)) 
				AND (case_id = CAST($1 as integer));

			UPDATE case_activity SET appleal_case_id = v_caseid
			WHERE (appleal_case_id is null) AND (case_id = CAST($1 as integer));

			UPDATE cases SET closed = true, case_locked = true
			WHERE (case_id = rec.case_id);
		END IF;
	END IF;
	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION manage_transfer(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec				RECORD;
	v_caseid		integer;
	v_orgid			integer;
	v_court_div		integer;
	msg 			varchar(120);
BEGIN

	IF ($3 = '1') THEN
		SELECT case_id, case_type_id, case_subject_id, police_station_id, case_title INTO rec
		FROM vw_cases
		WHERE (case_id = CAST($1 as integer));

		
		SELECT court_stations.org_id INTO v_orgid
		FROM case_activity INNER JOIN court_stations ON case_activity.court_station_id = court_stations.court_station_id
		WHERE (case_activity_id IN 
			(SELECT max(case_activity_id) FROM case_activity
			WHERE (activity_id = 26) AND (case_id = rec.case_id)));

		SELECT court_division_id INTO v_court_div
		FROM court_divisions
		WHERE (division_type_id = 7) AND (court_station_id = v_orgid);

		IF (v_orgid is not null) AND (v_court_div is not null) THEN
			UPDATE cases SET court_division_id = v_court_div, org_id = v_orgid WHERE (case_id = rec.case_id);
			UPDATE case_contacts SET org_id = v_orgid WHERE (case_id = rec.case_id);
			UPDATE case_activity SET org_id = v_orgid WHERE (case_id = rec.case_id);

			UPDATE case_activity SET approve_status = 'Approved'
			WHERE (case_activity_id IN 
				(SELECT case_activity_id FROM case_activity
				WHERE (activity_id = 26) AND (case_id = rec.case_id))); 

			msg := 'Case transfered';
		ELSE
			msg := 'Case not transfered';
		END IF;
	ELSIF ($3 = '2') THEN
		UPDATE cases SET new_case_id = CAST($4 as integer), closed = true, case_locked = true 
		WHERE (case_id = CAST($1 as integer));

		UPDATE case_activity SET approve_status = 'Approved'
			WHERE (case_activity_id IN 
				(SELECT case_activity_id FROM case_activity
				WHERE (activity_id = 24) AND (case_id = CAST($1 as integer)))); 
		msg := 'Case Consolidated';
	END IF;
	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION manage_mpesa(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg 			varchar(120);
BEGIN
	
	IF ($3 = '1') THEN
		UPDATE mpesa_trxs SET voided = true, voided_by = CAST($2 as integer), voided_date = now()
		WHERE (mpesa_trx_id = CAST($1 as integer));
	ELSIF ($3 = '2') THEN
		UPDATE mpesa_trxs SET voided = false
		WHERE (mpesa_trx_id = CAST($1 as integer));
	END IF;

	msg := 'Done';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION merge_entity(integer, integer) RETURNS varchar(120) AS $$
DECLARE
	msg 			varchar(120);
BEGIN
	
	UPDATE log_case_contacts SET entity_id = $2 WHERE entity_id = $1;
	UPDATE case_contacts SET entity_id = $2 WHERE entity_id = $1;
	DELETE FROM entity_subscriptions WHERE entity_id = $1;
	DELETE FROM entitys WHERE entity_id = $1;

	msg := 'Done';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_parties(integer, integer) RETURNS varchar(320) AS $$
DECLARE
	parties     varchar(320);
	myrec       RECORD;
BEGIN
	parties := null;

	FOR myrec IN
	(SELECT entity_name FROM vw_case_contacts WHERE (is_active = true) AND (case_id = $1) AND (contact_type_id = $2)
		ORDER BY entity_name) 
	LOOP
		IF (myrec.entity_name is not null) THEN
			IF(parties is null)THEN
				parties := trim(myrec.entity_name);
			ELSE
				parties := parties || ', ' || trim(myrec.entity_name);
			END IF;
		END IF;
	END LOOP;

	IF (parties is null) THEN
		parties := '';
	END IF;

	RETURN parties;
END
$$ LANGUAGE plpgsql; 


CREATE OR REPLACE FUNCTION activity_action() RETURNS trigger AS $$
DECLARE
	wfid		INTEGER;
	reca		RECORD;
	tbid		INTEGER;
	iswf		BOOLEAN;
	add_flow	BOOLEAN;
BEGIN
	add_flow := false;
	IF(TG_OP = 'INSERT')THEN
		IF (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	ELSE
		IF(OLD.approve_status = 'Draft') AND (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	END IF;
	
	IF(add_flow = true)THEN
		wfid := nextval('workflow_table_id_seq');
		NEW.workflow_table_id := wfid;

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id= NEW.change_by) LOOP
			iswf := false;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(tbid = reca.table_link_id)THEN
					iswf := true;
				END IF;
			END IF;

			IF(iswf = true)THEN
				INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done)
				SELECT org_id, workflow_phase_id, TG_TABLE_NAME, wfid, NEW.entity_id, escalation_days, escalation_hours, approval_level, phase_narrative, 'Approve - ' || phase_narrative
				FROM vw_workflow_entitys
				WHERE (table_name = TG_TABLE_NAME) AND (entity_id = NEW.entity_id) AND (workflow_id = reca.workflow_id)
				ORDER BY approval_level, workflow_phase_id;

				UPDATE approvals SET approve_status = 'Completed' 
				WHERE (table_id = wfid) AND (approval_level = 1);
			END IF;
		END LOOP;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER activity_action BEFORE INSERT OR UPDATE ON case_activity
    FOR EACH ROW EXECUTE PROCEDURE activity_action();

CREATE OR REPLACE FUNCTION add_transfer(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg 			varchar(120);
BEGIN

	INSERT INTO cases (case_category_id, case_subject_id, closed, case_locked, 
		case_transfer_id, old_tf_case_id, court_division_id, org_id,
		case_title, file_number, start_date, end_date, decision_summary)
	SELECT case_transfers.case_category_id, cases.case_subject_id, true, true,
		case_transfers.case_transfer_id, case_transfers.case_id, court_divisions.court_division_id, court_divisions.org_id,
		cases.case_title, case_transfers.previous_case_number, 
		case_transfers.judgment_date, case_transfers.judgment_date, 'Judgement by ' || case_transfers.presiding_judge
	FROM case_transfers INNER JOIN cases ON case_transfers.case_id = cases.case_id
		INNER JOIN court_divisions ON court_divisions.court_division_id = case_transfers.court_division_id
	WHERE (case_transfers.case_transfer_id = CAST($1 as integer));

	UPDATE case_transfers SET case_transfered = true
	WHERE (case_transfer_id = CAST($1 as integer));

	msg := 'Done';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION electrol_area(category_id integer, integer) RETURNS character varying AS $$
DECLARE
	msg			varchar(320);
	rec  		RECORD;
BEGIN
	msg:='';
	SELECT county_id,constituency_id,ward_id INTO rec
	FROM cases WHERE case_id = $2;
      
	IF(category_id=411) THEN
		msg := 'President; Kenya';
	ELSIF(category_id=412)THEN
		SELECT 'Senator; ' || county_name || ' County' INTO msg
		FROM counties WHERE county_id = rec.county_id;
	ELSIF(category_id=413)THEN
		SELECT 'Governor; ' || county_name || ' County' INTO msg
		FROM counties WHERE county_id = rec.county_id;
	ELSIF(category_id=414)THEN
		SELECT 'Women Representative; ' || county_name || ' County' INTO msg
		FROM counties WHERE county_id = rec.county_id;
	ELSIF(category_id=415)THEN
		SELECT 'Member of Parliament; ' || constituency_name || ', ' || county_name || 'County' INTO msg
		FROM constituency INNER JOIN counties ON counties.county_id = constituency.county_id
		WHERE constituency_id = rec.constituency_id;
	ELSIF(category_id=416)THEN
		SELECT 'County Representative; ' || ward_name || ', ' || constituency_name || ', ' || county_name || ' County' INTO msg
		FROM wards INNER JOIN constituency ON constituency.constituency_id = wards.constituency_id
		INNER JOIN counties ON counties.county_id = constituency.county_id
		WHERE ward_id = rec.ward_id;
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


