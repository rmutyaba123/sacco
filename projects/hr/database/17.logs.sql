---------------- change log tables

CREATE SCHEMA logs;

CREATE TABLE logs.lg_employees (
	log_employee_id			serial primary key,
	entity_id				integer,
	department_role_id		integer,
	bank_branch_id			integer,
	disability_id			integer,
	employee_id				varchar(12) not null,
	pay_scale_id			integer,
	pay_scale_step_id		integer,
	pay_group_id			integer,
	location_id				integer,
	currency_id				integer,
	org_id					integer,

	person_title			varchar(7),
	surname					varchar(50) not null,
	first_name				varchar(50) not null,
	middle_name				varchar(50),
	employee_full_name		varchar(120),
	employee_email			varchar(120),
	date_of_birth			date,
	dob_email				date default '2016-01-01'::date,
	
	gender					varchar(1),
	phone					varchar(120),
	nationality				char(2),
	
	nation_of_birth			char(2),
	place_of_birth			varchar(50),
	
	marital_status 			varchar(2),
	appointment_date		date,
	current_appointment		date,

	exit_date				date,
	contract				boolean default false not null,
	contract_period			integer not null,
	employment_terms		text,
	identity_card			varchar(50),
	basic_salary			real not null,
	bank_account			varchar(32),
	picture_file			varchar(32),
	active					boolean default true not null,
	language				varchar(320),
	desg_code				varchar(16),
	inc_mth					varchar(16),
	previous_sal_point		varchar(16),
	current_sal_point		varchar(16),
	halt_point				varchar(16),

	bio_metric_number		varchar(32),
	average_daily_rate		real default 0 not null,
	normal_work_hours		real default 9 not null,
	overtime_rate			real default 1.5 not null,
	special_time_rate		real default 2 not null,
	per_day_earning			boolean default false not null,

	height					real, 
	weight					real, 
	blood_group				varchar(3),
	allergies				text,

	field_of_study			text,
	interests				text,
	objective				text,
	details					text,
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_month (
	log_employee_month_id	serial primary key,
	employee_month_id		integer,
	entity_id				integer,
	period_id				integer,
	bank_branch_id			integer,
	pay_group_id			integer,
	department_role_id		integer,
	currency_id				integer,
	org_id					integer,
	
	exchange_rate			real default 1 not null,
	bank_account			varchar(32),
	basic_pay				float default 0 not null,
	hour_pay				float default 0 not null,
	worked_hours			float default 0 not null,
	
	part_time				boolean default false not null,
	details					text,
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_tax_types (
	log_employee_tax_type_id	serial primary key,
	employee_tax_type_id	integer,
	employee_month_id		integer,
	tax_type_id				integer,
	org_id					integer,
	
	tax_identification		varchar(50),
	in_tax					boolean not null default false,
	amount					float default 0 not null,
	additional				float default 0 not null,
	employer				float default 0 not null,
	exchange_rate			real default 1 not null,
	narrative				varchar(240),
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_advances (
	log_employee_advance_id	serial primary key,
	employee_advance_id		integer,
	employee_month_id		integer,
	currency_id				integer,
	entity_id				integer,
	org_id					integer,
	pay_date				date default current_date not null,
	pay_upto				date not null,
	pay_period				integer default 3 not null,
	amount					float not null,
	payment_amount			float not null,
	exchange_rate			real default 1 not null,
	in_payroll				boolean not null default false,
	completed				boolean not null default false,

	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,

	narrative				varchar(240),
	details					text,
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_advance_deductions (
	log_advance_deduction_id	serial primary key,
	advance_deduction_id	integer,
	employee_month_id		integer,
	org_id					integer,
	pay_date				date default current_date not null,
	amount					float not null,
	exchange_rate			real default 1 not null,
	in_payroll				boolean not null default true,
	narrative				varchar(240),
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_adjustments (
	log_employee_adjustment_id	serial primary key,
	employee_adjustment_id	integer,
	employee_month_id		integer,
	adjustment_id			integer,
	pension_id				integer,
	org_id					integer,
	adjustment_type			integer,
	adjustment_factor		integer default 1 not null,
	pay_date				date default current_date not null,
	amount					float not null,
	balance					float,
	paid_amount				float default 0 not null,
	exchange_rate			real default 1 not null,

	tax_reduction_amount	float default 0 not null,
	tax_relief_amount		float default 0 not null,

	in_payroll				boolean not null default true,
	in_tax					boolean not null default true,
	visible					boolean not null default true,
	narrative				varchar(240),
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_overtime (
	log_employee_overtime_id	serial primary key,
	employee_overtime_id	integer,
	employee_month_id		integer,
	entity_id				integer,
	org_id					integer,
	overtime_date			date not null,
	overtime				float not null,
	overtime_rate			float not null,
	auto_computed			boolean default false not null, 
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,
	narrative				varchar(240),
	details					text,
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_per_diem (
	log_employee_per_diem_id	serial primary key,
	employee_per_diem_id	integer,
	employee_month_id		integer,
	currency_id				integer,
	org_id					integer,
	travel_date				date not null,
	return_date				date not null,
	days_travelled			integer not null,
	per_diem				float default 0 not null,
	cash_paid				float default 0 not null,
	tax_amount				float default 0 not null,
	full_amount				float default 0 not null,
	exchange_rate			real default 1 not null,
	travel_to				varchar(240),
	post_account			varchar(32),
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,
	completed				boolean default false not null,
	details					text,
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_employee_banking (
	log_employee_banking_id	serial primary key,
	employee_banking_id		integer,
	employee_month_id		integer,
	bank_branch_id			integer,
	currency_id				integer,
	org_id					integer,
	
	amount					float default 0 not null,
	exchange_rate			real default 1 not null,
	cheque					boolean default false not null,
	bank_account			varchar(64),

	Narrative				varchar(240),
	
	created					timestamp default current_timestamp not null
);

CREATE TABLE logs.lg_absent (
	lg_absent_id			serial primary key,
	absent_id				integer,
	entity_id				integer,
	employee_month_id		integer,
	org_id					integer,
	absent_date				date not null,
	time_in					time,
	time_out				time,
	is_accepted				boolean default false not null,
	acceptance_date			timestamp,
	deduct_payroll			boolean default false not null,
	deduction_date			date,
	amount					real default 0 not null,
	narrative				varchar(120),
	employee_comments		text,
	details					text,
	
	created					timestamp default current_timestamp not null
);


--------------------- Functions


CREATE OR REPLACE FUNCTION log_employees() RETURNS trigger AS $$
BEGIN

	INSERT INTO logs.lg_employees (entity_id, department_role_id, bank_branch_id, disability_id, 
		employee_id, pay_scale_id, pay_scale_step_id, pay_group_id, location_id, 
		currency_id, org_id, person_title, surname, first_name, middle_name, 
		employee_full_name, employee_email, date_of_birth, dob_email, 
		gender, phone, nationality, nation_of_birth, place_of_birth, 
		marital_status, appointment_date, current_appointment, exit_date, 
		contract, contract_period, employment_terms, identity_card, basic_salary, 
		bank_account, picture_file, active, language, desg_code, inc_mth, 
		previous_sal_point, current_sal_point, halt_point, bio_metric_number, 
		average_daily_rate, normal_work_hours, overtime_rate, special_time_rate, 
		per_day_earning, height, weight, blood_group, allergies, field_of_study, 
		interests, objective, details)
    VALUES (OLD.entity_id, OLD.department_role_id, OLD.bank_branch_id, OLD.disability_id,
		OLD.employee_id, OLD.pay_scale_id, OLD.pay_scale_step_id, OLD.pay_group_id, OLD.location_id,
		OLD.currency_id, OLD.org_id, OLD.person_title, OLD.surname, OLD.first_name, OLD.middle_name,
		OLD.employee_full_name, OLD.employee_email, OLD.date_of_birth, OLD.dob_email,
		OLD.gender, OLD.phone, OLD.nationality, OLD.nation_of_birth, OLD.place_of_birth,
		OLD.marital_status, OLD.appointment_date, OLD.current_appointment, OLD.exit_date,
		OLD.contract, OLD.contract_period, OLD.employment_terms, OLD.identity_card, OLD.basic_salary,
		OLD.bank_account, OLD.picture_file, OLD.active, OLD.language, OLD.desg_code, OLD.inc_mth,
		OLD.previous_sal_point, OLD.current_sal_point, OLD.halt_point, OLD.bio_metric_number,
		OLD.average_daily_rate, OLD.normal_work_hours, OLD.overtime_rate, OLD.special_time_rate,
		OLD.per_day_earning, OLD.height, OLD.weight, OLD.blood_group, OLD.allergies, OLD.field_of_study,
		OLD.interests, OLD.objective, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employees AFTER UPDATE OR DELETE ON employees
	FOR EACH ROW EXECUTE PROCEDURE log_employees();


CREATE OR REPLACE FUNCTION log_employee_month() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_month (employee_month_id, entity_id, period_id, bank_branch_id, pay_group_id, 
		department_role_id, currency_id, org_id, exchange_rate, bank_account, 
		basic_pay, hour_pay, worked_hours, part_time, details)
	VALUES (OLD.employee_month_id, OLD.entity_id, OLD.period_id, OLD.bank_branch_id, OLD.pay_group_id,
		OLD.department_role_id, OLD.currency_id, OLD.org_id, OLD.exchange_rate, OLD.bank_account,
		OLD.basic_pay, OLD.hour_pay, OLD.worked_hours, OLD.part_time, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_month AFTER UPDATE OR DELETE ON employee_month
	FOR EACH ROW EXECUTE PROCEDURE log_employee_month();

	
CREATE OR REPLACE FUNCTION log_employee_tax_types() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_tax_types (employee_tax_type_id, employee_month_id, tax_type_id, org_id, 
		tax_identification, in_tax, amount, additional, employer, exchange_rate, narrative)
    VALUES (OLD.employee_tax_type_id, OLD.employee_month_id, OLD.tax_type_id, OLD.org_id,
		OLD.tax_identification, OLD.in_tax, OLD.amount, OLD.additional, OLD.employer, OLD.exchange_rate, OLD.narrative);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_tax_types AFTER UPDATE OR DELETE ON employee_tax_types
	FOR EACH ROW EXECUTE PROCEDURE log_employee_tax_types();

CREATE OR REPLACE FUNCTION log_employee_advances() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_advances (employee_advance_id, employee_month_id, currency_id, entity_id, 
		org_id, pay_date, pay_upto, pay_period, amount, payment_amount, 
		exchange_rate, in_payroll, completed, application_date, approve_status, 
		workflow_table_id, action_date, narrative, details)
    VALUES (OLD.employee_advance_id, OLD.employee_month_id, OLD.currency_id, OLD.entity_id,
		OLD.org_id, OLD.pay_date, OLD.pay_upto, OLD.pay_period, OLD.amount, OLD.payment_amount,
		OLD.exchange_rate, OLD.in_payroll, OLD.completed, OLD.application_date, OLD.approve_status,
		OLD.workflow_table_id, OLD.action_date, OLD.narrative, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_advances AFTER UPDATE OR DELETE ON employee_advances
	FOR EACH ROW EXECUTE PROCEDURE log_employee_advances();
	
CREATE OR REPLACE FUNCTION log_advance_deductions() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_advance_deductions (advance_deduction_id, employee_month_id, org_id, pay_date, amount, 
		exchange_rate, in_payroll, narrative)
	VALUES (OLD.advance_deduction_id, OLD.employee_month_id, OLD.org_id, OLD.pay_date, OLD.amount,
		OLD.exchange_rate, OLD.in_payroll, OLD.narrative);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_advance_deductions AFTER UPDATE OR DELETE ON advance_deductions
	FOR EACH ROW EXECUTE PROCEDURE log_advance_deductions();

CREATE OR REPLACE FUNCTION log_employee_adjustments() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_adjustments (employee_adjustment_id, employee_month_id, adjustment_id, pension_id, 
		org_id, adjustment_type, adjustment_factor, pay_date, amount, 
		balance, paid_amount, exchange_rate, tax_reduction_amount, tax_relief_amount, 
		in_payroll, in_tax, visible, narrative)
	VALUES (OLD.employee_adjustment_id, OLD.employee_month_id, OLD.adjustment_id, OLD.pension_id,
		OLD.org_id, OLD.adjustment_type, OLD.adjustment_factor, OLD.pay_date, OLD.amount,
		OLD.balance, OLD.paid_amount, OLD.exchange_rate, OLD.tax_reduction_amount, OLD.tax_relief_amount,
		OLD.in_payroll, OLD.in_tax, OLD.visible, OLD.narrative);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_adjustments AFTER UPDATE OR DELETE ON employee_adjustments
	FOR EACH ROW EXECUTE PROCEDURE log_employee_adjustments();

CREATE OR REPLACE FUNCTION log_employee_overtime() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_overtime (employee_overtime_id, employee_month_id, entity_id, org_id, overtime_date, 
		overtime, overtime_rate, auto_computed, application_date, approve_status, 
		workflow_table_id, action_date, narrative, details)
	VALUES (OLD.employee_overtime_id, OLD.employee_month_id, OLD.entity_id, OLD.org_id, OLD.overtime_date,
		OLD.overtime, OLD.overtime_rate, OLD.auto_computed, OLD.application_date, OLD.approve_status,
		OLD.workflow_table_id, OLD.action_date, OLD.narrative, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_overtime AFTER UPDATE OR DELETE ON employee_overtime
	FOR EACH ROW EXECUTE PROCEDURE log_employee_overtime();

CREATE OR REPLACE FUNCTION log_employee_per_diem() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_per_diem (employee_per_diem_id, employee_month_id, currency_id, org_id, 
		travel_date, return_date, days_travelled, per_diem, cash_paid, 
		tax_amount, full_amount, exchange_rate, travel_to, post_account, 
		application_date, approve_status, workflow_table_id, action_date, 
		completed, details)
	VALUES (OLD.employee_per_diem_id, OLD.employee_month_id, OLD.currency_id, OLD.org_id,
		OLD.travel_date, OLD.return_date, OLD.days_travelled, OLD.per_diem, OLD.cash_paid,
		OLD.tax_amount, OLD.full_amount, OLD.exchange_rate, OLD.travel_to, OLD.post_account,
		OLD.application_date, OLD.approve_status, OLD.workflow_table_id, OLD.action_date,
		OLD.completed, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_per_diem AFTER UPDATE OR DELETE ON employee_per_diem
	FOR EACH ROW EXECUTE PROCEDURE log_employee_per_diem();
	
CREATE OR REPLACE FUNCTION log_employee_banking() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_employee_banking (employee_banking_id, employee_month_id, bank_branch_id, currency_id, 
		org_id, amount, exchange_rate, cheque, bank_account, narrative)
	VALUES (OLD.employee_banking_id, OLD.employee_month_id, OLD.bank_branch_id, OLD.currency_id,
		OLD.org_id, OLD.amount, OLD.exchange_rate, OLD.cheque, OLD.bank_account, OLD.narrative);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employee_banking AFTER UPDATE OR DELETE ON employee_banking
	FOR EACH ROW EXECUTE PROCEDURE log_employee_banking();


CREATE OR REPLACE FUNCTION log_absent() RETURNS trigger AS $$
BEGIN
	
	INSERT INTO logs.lg_absent(absent_id, entity_id, employee_month_id, org_id, absent_date, 
		time_in, time_out, is_accepted, acceptance_date, deduct_payroll, 
		deduction_date, amount, narrative, employee_comments, details)
	VALUES (OLD.absent_id, OLD.entity_id, OLD.employee_month_id, OLD.org_id, OLD.absent_date, 
		OLD.time_in, OLD.time_out, OLD.is_accepted, OLD.acceptance_date, OLD.deduct_payroll, 
		OLD.deduction_date, OLD.amount, OLD.narrative, OLD.employee_comments, OLD.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_absent AFTER UPDATE OR DELETE ON absent
	FOR EACH ROW EXECUTE PROCEDURE log_absent();



    