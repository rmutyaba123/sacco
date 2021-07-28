CREATE TABLE adjustment_effects (
	adjustment_effect_id	integer primary key,
	adjustment_effect_name	varchar(50) not null,
	adjustment_effect_type	integer default 1 not null,
	adjustment_effect_code	varchar(50)
);

CREATE TABLE adjustments (
	adjustment_id			serial primary key,
	currency_id				integer references currency,
	adjustment_effect_id	integer references adjustment_effects,
	org_id					integer references orgs,
	adjustment_name			varchar(50) not null,
	adjustment_type			integer not null,
	adjustment_order		integer default 0 not null,
	earning_code			integer,
	formural				varchar(430),
	default_amount			real default 0 not null,
	monthly_update			boolean default true not null,
	in_payroll				boolean default true not null,
	in_tax					boolean default true not null,
	visible					boolean default true not null,
	running_balance			boolean default false not null,
	reduce_balance			boolean default false not null,

	tax_reduction_ps		float default 0 not null,
	tax_relief_ps			float default 0 not null,
	tax_max_allowed			float default 0 not null,

	account_number			varchar(32),
	details					text,
	
	UNIQUE(adjustment_name, org_id)
);
CREATE INDEX adjustments_currency_id ON adjustments(currency_id);
CREATE INDEX adjustments_adjustment_effect_id ON adjustments(adjustment_effect_id);
CREATE INDEX adjustments_org_id ON adjustments(org_id);

ALTER TABLE leave_types ADD	adjustment_id	integer references adjustments;
CREATE INDEX leave_types_adjustment_id ON leave_types(adjustment_id);

CREATE TABLE default_adjustments (
	default_adjustment_id	serial primary key,
	entity_id				integer references employees,
	adjustment_id			integer references adjustments,
	org_id					integer references orgs,
	
	amount					float default 0 not null,
	balance					float default 0 not null,
	final_date				date,
	active					boolean default true,

	Narrative				varchar(240)
);
CREATE INDEX default_adjustments_entity_id ON default_adjustments (entity_id);
CREATE INDEX default_adjustments_adjustment_id ON default_adjustments (adjustment_id);
CREATE INDEX default_adjustments_org_id ON default_adjustments(org_id);

CREATE TABLE default_banking (
	default_banking_id		serial primary key,
	entity_id				integer references employees,
	bank_branch_id			integer references bank_branch,
	currency_id				integer references currency,
	org_id					integer references orgs,
	
	amount					float default 0 not null,
	ps_amount				float default 0 not null,
	final_date				date,
	cheque					boolean default false not null,
	active					boolean default true not null,
	
	bank_account			varchar(64),

	Narrative				varchar(240)
);
CREATE INDEX default_banking_entity_id ON default_banking (entity_id);
CREATE INDEX default_banking_bank_branch_id ON default_banking (bank_branch_id);
CREATE INDEX default_banking_currency_id ON default_banking (currency_id);
CREATE INDEX default_banking_org_id ON default_banking(org_id);

CREATE TABLE pensions (
	pension_id 				serial primary key,
	entity_id				integer references employees,
	adjustment_id			integer references adjustments,
	contribution_id			integer references adjustments,
	org_id					integer references orgs,
	
	pension_company			varchar(50) not null,
	pension_number			varchar(50),
	active					boolean default true,
	
	amount					float default 0 not null,
	use_formura				boolean default false not null,
	
	employer_ps				float default 0 not null,
	employer_amount			float default 0 not null,
	employer_formural		boolean default false not null,
	
	details					text
);
CREATE INDEX pension_entity_id ON pensions (entity_id);
CREATE INDEX pension_adjustment_id ON pensions (adjustment_id);
CREATE INDEX pension_contribution_id ON pensions (contribution_id);
CREATE INDEX pension_org_id ON pensions (org_id);

CREATE TABLE employee_month (
	employee_month_id		serial primary key,
	entity_id				integer references employees not null,
	period_id				integer references periods not null,
	bank_branch_id			integer references bank_branch not null,
	pay_group_id			integer references pay_groups not null,
	department_role_id		integer references department_roles not null,
	currency_id				integer references currency,
	org_id					integer references orgs,
	
	exchange_rate			real default 1 not null,
	bank_account			varchar(32),
	basic_pay				float default 0 not null,
	hour_pay				float default 0 not null,
	worked_hours			float default 0 not null,
	
	part_time				boolean default false not null,
	details					text,
	unique (entity_id, period_id)
);
CREATE INDEX employee_month_entity_id ON employee_month (entity_id);
CREATE INDEX employee_month_period_id ON employee_month (period_id);
CREATE INDEX employee_month_bank_branch_id ON employee_month (bank_branch_id);
CREATE INDEX employee_month_bank_pay_group_id ON employee_month (pay_group_id);
CREATE INDEX employee_month_currency_id ON employee_month (currency_id);
CREATE INDEX employee_month_org_id ON employee_month(org_id);

CREATE TABLE employee_tax_types (
	employee_tax_type_id	serial primary key,
	employee_month_id		integer references employee_month not null,
	tax_type_id				integer references tax_types not null,
	org_id					integer references orgs,
	
	tax_identification		varchar(50),
	in_tax					boolean not null default false,
	amount					float default 0 not null,
	additional				float default 0 not null,
	employer				float default 0 not null,
	exchange_rate			real default 1 not null,
	
	narrative				varchar(240)
);
CREATE INDEX employee_tax_types_employee_month_id ON employee_tax_types (employee_month_id);
CREATE INDEX employee_tax_types_tax_type_id ON employee_tax_types (tax_type_id);
CREATE INDEX employee_tax_types_org_id ON employee_tax_types(org_id);

CREATE TABLE employee_advances (
	employee_advance_id		serial primary key,
	employee_month_id		integer references employee_month,
	currency_id				integer references currency,
	entity_id				integer not null references entitys,
	org_id					integer references orgs,
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
	details					text
);
CREATE INDEX employee_advances_employee_month_id ON employee_advances (employee_month_id);
CREATE INDEX employee_advances_currency_id ON employee_advances (currency_id);
CREATE INDEX employee_advances_entity_id ON employee_advances (entity_id);
CREATE INDEX employee_advances_org_id ON employee_advances(org_id);

CREATE TABLE advance_deductions (
	advance_deduction_id	serial primary key,
	employee_month_id		integer references employee_month not null,
	org_id					integer references orgs,
	pay_date				date default current_date not null,
	amount					float not null,
	exchange_rate			real default 1 not null,
	in_payroll				boolean not null default true,
	narrative				varchar(240)
);
CREATE INDEX advance_deductions_employee_month_id ON advance_deductions (employee_month_id);
CREATE INDEX advance_deductions_org_id ON advance_deductions(org_id);

CREATE TABLE employee_adjustments (
	employee_adjustment_id	serial primary key,
	employee_month_id		integer references employee_month not null,
	adjustment_id			integer references adjustments not null,
	pension_id				integer references pensions,
	org_id					integer references orgs,
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
	narrative				varchar(240)
);
CREATE INDEX employee_adjustments_employee_month_id ON employee_adjustments (employee_month_id);
CREATE INDEX employee_adjustments_adjustment_id ON employee_adjustments (adjustment_id);
CREATE INDEX employee_adjustments_pension_id ON employee_adjustments (pension_id);
CREATE INDEX employee_adjustments_org_id ON employee_adjustments(org_id);

CREATE TABLE employee_overtime (
	employee_overtime_id	serial primary key,
	employee_month_id		integer references employee_month not null,
	entity_id				integer references entitys,
	org_id					integer references orgs,
	overtime_date			date not null,
	overtime				float not null,
	overtime_rate			float not null,
	auto_computed			boolean default false not null, 
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,
	narrative				varchar(240),
	details					text
);
CREATE INDEX employee_overtime_employee_month_id ON employee_overtime (employee_month_id);
CREATE INDEX employee_overtime_entity_id ON employee_overtime (entity_id);
CREATE INDEX employee_overtime_org_id ON employee_overtime(org_id);

CREATE TABLE employee_per_diem (
	employee_per_diem_id	serial primary key,
	employee_month_id		integer references employee_month not null,
	currency_id				integer references currency,
	org_id					integer references orgs,
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
	details					text
);
CREATE INDEX employee_per_diem_employee_month_id ON employee_per_diem (employee_month_id);
CREATE INDEX employee_per_diem_currency_id ON employee_per_diem (currency_id);
CREATE INDEX employee_per_diem_org_id ON employee_per_diem(org_id);

CREATE TABLE employee_banking (
	employee_banking_id		serial primary key,
	employee_month_id		integer references employee_month not null,
	bank_branch_id			integer references bank_branch,
	currency_id				integer references currency,
	org_id					integer references orgs,
	
	amount					real default 0 not null,
	exchange_rate			real default 1 not null,
	cheque					boolean default false not null,
	bank_account			varchar(64),

	Narrative				varchar(240)
);
CREATE INDEX employee_banking_employee_month_id ON employee_banking (employee_month_id);
CREATE INDEX employee_banking_bank_branch_id ON employee_banking (bank_branch_id);
CREATE INDEX employee_banking_currency_id ON employee_banking (currency_id);
CREATE INDEX employee_banking_org_id ON employee_banking(org_id);

CREATE TABLE absent (
	absent_id				serial primary key,
	entity_id				integer references entitys,
	employee_month_id		integer references employee_month,
	org_id					integer references orgs,
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
	details					text
);
CREATE INDEX absent_entity_id ON absent (entity_id);
CREATE INDEX absent_employee_month_id ON absent (employee_month_id);
CREATE INDEX absent_org_id ON absent (org_id);
CREATE INDEX absent_absent_date ON absent (absent_date);

CREATE TABLE intern_month (
	intern_month_id			serial primary key,
	period_id				integer references periods not null,
	intern_id				integer references interns not null,
	currency_id				integer references currency,
	org_id					integer references orgs,
	
	exchange_rate			real default 1 not null,
	month_allowance			float default 0 not null,

	details					text,
	unique (intern_id, period_id)
);
CREATE INDEX intern_month_period_id ON intern_month (period_id);
CREATE INDEX intern_month_intern_id ON intern_month (intern_id);
CREATE INDEX intern_month_currency_id ON intern_month (currency_id);
CREATE INDEX intern_month_org_id ON intern_month(org_id);

CREATE TABLE casuals_month (
	casuals_month_id		serial primary key,
	period_id				integer references periods not null,
	casual_id				integer references casuals not null,
	currency_id				integer references currency,
	org_id					integer references orgs,
	
	exchange_rate			real default 1 not null,
	amount_paid				float default 0 not null,
	
	accrued_date			date default current_date not null,
	paid					boolean default false not null,
	pay_date				date default current_date not null,

	details					text
);
CREATE INDEX casuals_month_period_id ON casuals_month (period_id);
CREATE INDEX casuals_month_casual_id ON casuals_month (casual_id);
CREATE INDEX casuals_month_currency_id ON casuals_month (currency_id);
CREATE INDEX casuals_month_org_id ON casuals_month(org_id);

CREATE VIEW vw_adjustments AS
	SELECT currency.currency_id, currency.currency_name, currency.currency_symbol,
		adjustments.org_id, adjustments.adjustment_id, adjustments.adjustment_name, adjustments.adjustment_type, 
		adjustments.adjustment_order, adjustments.earning_code, adjustments.formural, adjustments.monthly_update, 
		adjustments.in_payroll, adjustments.in_tax, adjustments.visible, adjustments.running_balance, 
		adjustments.reduce_balance, adjustments.tax_reduction_ps, adjustments.tax_relief_ps, 
		adjustments.tax_max_allowed, adjustments.account_number, adjustments.details
	FROM adjustments INNER JOIN currency ON adjustments.currency_id = currency.currency_id;
	
CREATE VIEW vw_leave_types AS
	SELECT vw_adjustments.currency_id, vw_adjustments.currency_name, vw_adjustments.currency_symbol,
		vw_adjustments.adjustment_id, vw_adjustments.adjustment_name, 
		vw_adjustments.adjustment_type, vw_adjustments.adjustment_order, vw_adjustments.earning_code, 
		vw_adjustments.formural, vw_adjustments.monthly_update,
		vw_adjustments.in_payroll, vw_adjustments.in_tax, vw_adjustments.visible, vw_adjustments.running_balance, 
		vw_adjustments.reduce_balance, vw_adjustments.tax_reduction_ps, vw_adjustments.tax_relief_ps, 
		vw_adjustments.tax_max_allowed, vw_adjustments.account_number,
		leave_types.org_id, leave_types.leave_type_id, leave_types.leave_type_name, 
		leave_types.allowed_leave_days, leave_types.leave_days_span, leave_types.use_type, 
		leave_types.month_quota, leave_types.initial_days, leave_types.maximum_carry, 
		leave_types.include_holiday, leave_types.include_mon, leave_types.include_tue, leave_types.include_wed, 
		leave_types.include_thu, leave_types.include_fri, leave_types.include_sat, leave_types.include_sun, 
		leave_types.details,
		(CASE vw_adjustments.adjustment_type WHEN 1 THEN 'Leave Allowance' WHEN 2 THEN 'Leave Deduction'
			WHEN 3 THEN 'Leave Expenditure' ELSE 'No Adjustment' END) as leave_adjustment
	FROM leave_types LEFT JOIN vw_adjustments ON leave_types.adjustment_id = vw_adjustments.adjustment_id;
		
CREATE VIEW vw_default_adjustments AS
	SELECT vw_adjustments.adjustment_id, vw_adjustments.adjustment_name, vw_adjustments.adjustment_type, 
		vw_adjustments.currency_id, vw_adjustments.currency_name, vw_adjustments.currency_symbol,
		entitys.entity_id, entitys.entity_name,
		default_adjustments.org_id, default_adjustments.default_adjustment_id, default_adjustments.amount, default_adjustments.active,
		default_adjustments.final_date, default_adjustments.narrative
	FROM default_adjustments INNER JOIN vw_adjustments ON default_adjustments.adjustment_id = vw_adjustments.adjustment_id
		INNER JOIN entitys ON default_adjustments.entity_id = entitys.entity_id;

CREATE VIEW vw_default_banking AS
	SELECT entitys.entity_id, entitys.entity_name, 
		vw_bank_branch.bank_id, vw_bank_branch.bank_name, vw_bank_branch.bank_branch_id, 
		vw_bank_branch.bank_branch_name, vw_bank_branch.bank_branch_code,
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		default_banking.org_id, default_banking.default_banking_id, default_banking.amount, 
		default_banking.ps_amount, default_banking.final_date, default_banking.active, 
		default_banking.bank_account, default_banking.narrative
	FROM default_banking INNER JOIN entitys ON default_banking.entity_id = entitys.entity_id
		INNER JOIN vw_bank_branch ON default_banking.bank_branch_id = vw_bank_branch.bank_branch_id
		INNER JOIN currency ON default_banking.currency_id = currency.currency_id;

CREATE VIEW vw_pensions AS
	SELECT entitys.entity_id, entitys.entity_name,
		adjustments.adjustment_id, adjustments.adjustment_name, 
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		pensions.contribution_id, contributions.adjustment_name as contribution_name, 
		pensions.org_id, pensions.pension_id, pensions.pension_company, pensions.pension_number, 
		pensions.amount, pensions.use_formura, pensions.employer_ps, pensions.employer_amount, 
		pensions.employer_formural, pensions.active, pensions.details
	FROM pensions INNER JOIN entitys ON pensions.entity_id = entitys.entity_id
		INNER JOIN adjustments ON pensions.adjustment_id = adjustments.adjustment_id
		INNER JOIN adjustments as contributions ON pensions.contribution_id = contributions.adjustment_id
		INNER JOIN currency ON adjustments.currency_id = currency.currency_id;
	
	
CREATE OR REPLACE FUNCTION getAdjustment(int, int, int) RETURNS float AS $$
DECLARE
	adjustment float;
BEGIN

	IF ($3 = 1) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (adjustment_type = $2);
	ELSIF ($3 = 2) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (adjustment_type = $2) AND (In_payroll = true) AND (Visible = true);
	ELSIF ($3 = 3) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (adjustment_type = $2) AND (In_Tax = true);
	ELSIF ($3 = 4) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (adjustment_type = $2) AND (In_payroll = true);
	ELSIF ($3 = 5) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (adjustment_type = $2) AND (Visible = true);
	ELSIF ($3 = 11) THEN
		SELECT SUM(exchange_rate * (amount + additional)) INTO adjustment
		FROM employee_tax_types
		WHERE (Employee_Month_ID = $1);
	ELSIF ($3 = 12) THEN
		SELECT SUM(exchange_rate * (amount + additional)) INTO adjustment
		FROM employee_tax_types
		WHERE (Employee_Month_ID = $1) AND (In_Tax = true);
	ELSIF ($3 = 14) THEN
		SELECT SUM(exchange_rate * (amount + additional)) INTO adjustment
		FROM employee_tax_types
		WHERE (Employee_Month_ID = $1) AND (Tax_Type_ID = $2);
	ELSIF ($3 = 21) THEN
		SELECT SUM(exchange_rate * amount * adjustment_factor) INTO adjustment
		FROM employee_adjustments
		WHERE (employee_month_id = $1) AND (in_tax = true);
	ELSIF ($3 = 22) THEN
		SELECT SUM(exchange_rate * amount * adjustment_factor) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (In_payroll = true) AND (Visible = true);
	ELSIF ($3 = 23) THEN
		SELECT SUM(exchange_rate * amount * adjustment_factor) INTO adjustment
		FROM employee_adjustments
		WHERE (employee_month_id = $1) AND (in_tax = true) AND (adjustment_factor = 1);
	ELSIF ($3 = 24) THEN
		SELECT SUM(exchange_rate * tax_reduction_amount) INTO adjustment
		FROM employee_adjustments
		WHERE (employee_month_id = $1) AND (in_tax = true) AND (adjustment_factor = -1);
	ELSIF ($3 = 25) THEN
		SELECT SUM(exchange_rate * tax_relief_amount) INTO adjustment
		FROM employee_adjustments
		WHERE (employee_month_id = $1) AND (in_tax = true) AND (adjustment_factor = -1);
	ELSIF ($3 = 26) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_adjustments
		WHERE (employee_month_id = $1) AND (pension_id is not null) AND (adjustment_type = 2);
	ELSIF ($3 = 27) THEN
		SELECT SUM(employee_adjustments.exchange_rate * employee_adjustments.amount) INTO adjustment
		FROM employee_adjustments INNER JOIN adjustments ON employee_adjustments.adjustment_id = adjustments.adjustment_id
		WHERE (employee_adjustments.employee_month_id = $1) AND (adjustments.adjustment_effect_id = $2);
	ELSIF ($3 = 28) THEN
		SELECT SUM(employee_adjustments.exchange_rate * employee_adjustments.tax_relief_amount) INTO adjustment
		FROM employee_adjustments INNER JOIN adjustments ON employee_adjustments.adjustment_id = adjustments.adjustment_id
		WHERE (employee_adjustments.employee_month_id = $1) AND (adjustments.adjustment_effect_id = $2);
	ELSIF ($3 = 31) THEN
		SELECT SUM(overtime * overtime_rate) INTO adjustment
		FROM employee_overtime
		WHERE (Employee_Month_ID = $1) AND (approve_status = 'Approved');
	ELSIF ($3 = 32) THEN
		SELECT SUM(exchange_rate * tax_amount) INTO adjustment
		FROM employee_per_diem
		WHERE (Employee_Month_ID = $1) AND (approve_status = 'Approved');
	ELSIF ($3 = 33) THEN
		SELECT SUM(exchange_rate * (full_amount -  cash_paid)) INTO adjustment
		FROM Employee_Per_Diem
		WHERE (Employee_Month_ID = $1) AND (approve_status = 'Approved');
	ELSIF ($3 = 34) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_advances
		WHERE (Employee_Month_ID = $1) AND (in_payroll = true);
	ELSIF ($3 = 35) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM advance_deductions
		WHERE (Employee_Month_ID = $1) AND (In_payroll = true);
	ELSIF ($3 = 36) THEN
		SELECT SUM(exchange_rate * paid_amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1) AND (In_payroll = true) AND (Visible = true);
	ELSIF ($3 = 37) THEN
		SELECT SUM(exchange_rate * tax_relief_amount) INTO adjustment
		FROM employee_adjustments
		WHERE (Employee_Month_ID = $1);

		IF(adjustment IS NULL)THEN
			adjustment := 0;
		END IF;
	ELSIF ($3 = 41) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_banking
		WHERE (employee_month_id = $1);
	ELSIF ($3 = 42) THEN
		SELECT SUM(exchange_rate * amount) INTO adjustment
		FROM employee_banking
		WHERE (employee_month_id = $1) AND (cheque = true);
	ELSIF ($3 = 51) THEN
		SELECT SUM(amount) INTO adjustment
		FROM absent
		WHERE (employee_month_id = $1) AND (deduct_payroll = true);
	ELSE
		adjustment := 0;
	END IF;

	IF(adjustment is null) THEN
		adjustment := 0;
	END IF;

	RETURN adjustment;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getAdjustment(int, int) RETURNS float AS $$
DECLARE
	adjustment float;
BEGIN

	IF ($2 = 1) THEN
		SELECT (Basic_Pay + getAdjustment(Employee_Month_ID, 4, 31) + getAdjustment(Employee_Month_ID, 4, 32) 
			+ getAdjustment(Employee_Month_ID, 4, 23) - getAdjustment(Employee_Month_ID, 4, 51)) 
		INTO adjustment
		FROM Employee_Month
		WHERE (Employee_Month_ID = $1);
	ELSIF ($2 = 2) THEN
		SELECT (Basic_Pay + getAdjustment(Employee_Month_ID, 4, 31) + getAdjustment(Employee_Month_ID, 4, 32)
			+ getAdjustment(Employee_Month_ID, 4, 23) - getAdjustment(Employee_Month_ID, 4, 51)
			- getAdjustment(Employee_Month_ID, 4, 12) - getAdjustment(Employee_Month_ID, 4, 24)) 
		INTO adjustment
		FROM Employee_Month
		WHERE (Employee_Month_ID = $1);
	ELSIF ($2 = 3) THEN
		SELECT (Basic_Pay + getAdjustment(Employee_Month_ID, 4, 31) + getAdjustment(Employee_Month_ID, 4, 32)
			 - getAdjustment(Employee_Month_ID, 4, 51)) 
		INTO adjustment
		FROM Employee_Month
		WHERE (Employee_Month_ID = $1);
	ELSE
		adjustment := 0;
	END IF;

	IF(adjustment is null) THEN
		adjustment := 0;
	END IF;

	RETURN adjustment;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getAdvanceBalance(int, date) RETURNS float AS $$
DECLARE
	advance FLOAT;
	paid 	FLOAT;
BEGIN
	SELECT SUM(Amount) INTO advance
	FROM vw_employee_advances
	WHERE (entity_id = $1) AND (start_date <= $2) AND (approve_status = 'Approved');
	IF (advance is null) THEN advance := 0; END IF;
	
	SELECT SUM(Amount) INTO paid
	FROM vw_advance_deductions
	WHERE (entity_id = $1) AND (start_date <= $2);
	IF (paid is null) THEN paid := 0; END IF;

	advance := advance - paid;

	RETURN advance;
END;
$$ LANGUAGE plpgsql;

CREATE VIEW vw_employee_month AS
	SELECT vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.overtime_rate, 
		vw_periods.activated, vw_periods.closed, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month,
		vw_periods.quarter, vw_periods.semister, vw_periods.gl_payroll_account, vw_periods.is_posted,
		vw_periods.fiscal_year_id, vw_periods.fiscal_year, vw_periods.fiscal_year_start, vw_periods.fiscal_year_end, vw_periods.submission_date,
		
		vw_bank_branch.bank_id, vw_bank_branch.bank_name, vw_bank_branch.bank_branch_id, 
		vw_bank_branch.bank_branch_name, vw_bank_branch.bank_branch_code,
		pay_groups.pay_group_id, pay_groups.pay_group_name, pay_groups.gl_payment_account,
		pay_groups.bank_header, pay_groups.bank_address,
		vw_department_roles.department_id, vw_department_roles.department_name,
		vw_department_roles.department_role_id, vw_department_roles.department_role_name, 
		entitys.entity_id, entitys.entity_name,
		employees.employee_id, employees.surname, employees.first_name, employees.middle_name, employees.date_of_birth, 
		employees.gender, employees.nationality, employees.marital_status, employees.appointment_date, employees.exit_date, 
		employees.contract, employees.contract_period, employees.employment_terms, employees.identity_card,
		(employees.Surname || ' ' || employees.First_name || ' ' || COALESCE(employees.Middle_name, '')) as employee_name,
		employees.employee_full_name,
		currency.currency_id, currency.currency_name, currency.currency_symbol, employee_month.exchange_rate,
		
		employee_month.org_id, employee_month.employee_month_id, employee_month.bank_account, employee_month.basic_pay, 
		employee_month.hour_pay, employee_month.worked_hours,
		employee_month.part_time, employee_month.details,
		getAdjustment(employee_month.employee_month_id, 4, 31) as overtime,
		getAdjustment(employee_month.employee_month_id, 4, 51) as absent_deduction,
		getAdjustment(employee_month.employee_month_id, 1, 1) as full_allowance,
		getAdjustment(employee_month.employee_month_id, 1, 2) as payroll_allowance,
		getAdjustment(employee_month.employee_month_id, 1, 3) as tax_allowance,
		getAdjustment(employee_month.employee_month_id, 2, 1) as full_deduction,
		getAdjustment(employee_month.employee_month_id, 2, 2) as payroll_deduction,
		getAdjustment(employee_month.employee_month_id, 2, 3) as tax_deduction,
		getAdjustment(employee_month.employee_month_id, 3, 1) as full_expense,
		getAdjustment(employee_month.employee_month_id, 3, 2) as payroll_expense,
		getAdjustment(employee_month.employee_month_id, 3, 3) as tax_expense,
		getAdjustment(employee_month.employee_month_id, 4, 11) as payroll_tax,
		getAdjustment(employee_month.employee_month_id, 4, 12) as tax_tax,
		getAdjustment(employee_month.employee_month_id, 4, 22) as net_Adjustment,
		getAdjustment(employee_month.employee_month_id, 4, 33) as per_diem,
		getAdjustment(employee_month.employee_month_id, 4, 34) as advance,
		getAdjustment(employee_month.employee_month_id, 4, 35) as advance_deduction,
		getAdjustment(employee_month.employee_month_id, 4, 41) as other_banks,
		getAdjustment(employee_month.employee_month_id, 4, 42) as bank_cheques,
		
		(employee_month.Basic_Pay + getAdjustment(employee_month.employee_month_id, 4, 31)
		- getAdjustment(employee_month.employee_month_id, 4, 51)) as basic_salary,
		
		(employee_month.Basic_Pay + getAdjustment(employee_month.employee_month_id, 4, 31)
		- getAdjustment(employee_month.employee_month_id, 4, 51)
		+ getAdjustment(employee_month.employee_month_id, 1, 2)) as gross_salary,
		
		(employee_month.Basic_Pay + getAdjustment(employee_month.employee_month_id, 4, 31) 
		- getAdjustment(employee_month.employee_month_id, 4, 51)
		+ getAdjustment(employee_month.employee_month_id, 4, 22) 
		+ getAdjustment(employee_month.employee_month_id, 4, 33) - getAdjustment(employee_month.employee_month_id, 4, 11)) as net_pay,
		
		(employee_month.Basic_Pay + getAdjustment(employee_month.employee_month_id, 4, 31) 
		- getAdjustment(employee_month.employee_month_id, 4, 51)
		+ getAdjustment(employee_month.employee_month_id, 4, 22) 
		+ getAdjustment(employee_month.employee_month_id, 4, 33) + getAdjustment(employee_month.employee_month_id, 4, 34)
		- getAdjustment(employee_month.employee_month_id, 4, 11) - getAdjustment(employee_month.employee_month_id, 4, 35)
		- getAdjustment(employee_month.employee_month_id, 4, 36)
		- getAdjustment(employee_month.employee_month_id, 4, 41)) as banked,
		
		(employee_month.Basic_Pay + getAdjustment(employee_month.employee_month_id, 4, 31) 
		- getAdjustment(employee_month.employee_month_id, 4, 51)
		+ getAdjustment(employee_month.employee_month_id, 1, 1) 
		+ getAdjustment(employee_month.employee_month_id, 3, 1) + getAdjustment(employee_month.employee_month_id, 4, 33)) as cost
	FROM employee_month INNER JOIN vw_bank_branch ON employee_month.bank_branch_id = vw_bank_branch.bank_branch_id
		INNER JOIN vw_periods ON employee_month.period_id = vw_periods.period_id
		INNER JOIN pay_groups ON employee_month.pay_group_id = pay_groups.pay_group_id
		INNER JOIN entitys ON employee_month.entity_id = entitys.entity_id
		INNER JOIN vw_department_roles ON employee_month.department_role_id = vw_department_roles.department_role_id
		INNER JOIN employees ON employee_month.entity_id = employees.entity_id
		INNER JOIN currency ON employee_month.currency_id = currency.currency_id;
		
CREATE VIEW vw_ems AS
	SELECT em.org_id, em.period_id, em.start_date, em.end_date, em.overtime_rate, em.activated, em.closed, em.month_id, 
		em.period_year, em.period_month, em.quarter, em.semister, em.bank_header, em.bank_address, 
		em.gl_payroll_account, em.is_posted, 
		em.bank_id, em.bank_name, em.bank_branch_id, em.bank_branch_name, em.bank_branch_code, 
		em.pay_group_id, em.pay_group_name, em.gl_payment_account,
		em.department_id, em.department_name, em.department_role_id, em.department_role_name, 
		em.entity_id, em.entity_name, 
		em.employee_id, em.surname, em.first_name, em.middle_name, em.date_of_birth, em.gender, 
		em.nationality, em.marital_status, em.appointment_date, em.exit_date, em.contract, em.contract_period, 
		em.employment_terms, em.identity_card, em.employee_name, em.employee_full_name,
		em.currency_id, em.currency_name, em.currency_symbol, em.exchange_rate, 
		em.employee_month_id, em.bank_account, em.basic_pay, em.details, em.overtime, 
		em.full_allowance, em.payroll_allowance, em.tax_allowance, em.full_deduction, 
		em.payroll_deduction, em.tax_deduction, em.full_expense, em.payroll_expense, 
		em.tax_expense, em.payroll_tax, em.tax_tax, em.net_adjustment, em.per_diem, 
		em.advance, em.advance_deduction, em.other_banks, em.net_pay, em.banked, em.cost,
		
		(em.basic_pay * em.exchange_rate) as b_basic_pay,
		((em.banked + em.other_banks) * em.exchange_rate) as b_banked
	FROM vw_employee_month em;

CREATE VIEW vw_employee_month_list AS
	SELECT vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.overtime_rate, 
		vw_periods.activated, vw_periods.closed, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month,
		vw_periods.quarter, vw_periods.semister, vw_periods.gl_payroll_account, vw_periods.is_posted,
		vw_periods.fiscal_year_id, vw_periods.fiscal_year,
		entitys.entity_id, entitys.entity_name,
		pay_groups.pay_group_id, pay_groups.pay_group_name, pay_groups.gl_payment_account,
		pay_groups.bank_header, pay_groups.bank_address,
		employees.employee_id, employees.surname, employees.first_name, employees.middle_name, employees.date_of_birth, 
		employees.gender, employees.nationality, employees.marital_status, employees.appointment_date, employees.exit_date, 
		employees.contract, employees.contract_period, employees.employment_terms, employees.identity_card,
		(employees.Surname || ' ' || employees.First_name || ' ' || COALESCE(employees.Middle_name, '')) as employee_name,
		employees.employee_full_name,
		departments.department_id, departments.department_name, departments.department_account, departments.function_code,
		department_roles.department_role_id, department_roles.department_role_name,
		employee_month.org_id, employee_month.employee_month_id, employee_month.bank_account, employee_month.basic_pay,
		employee_month.currency_id, employee_month.exchange_rate
		
	FROM employee_month INNER JOIN vw_periods ON employee_month.period_id = vw_periods.period_id
		INNER JOIN pay_groups ON employee_month.pay_group_id = pay_groups.pay_group_id
		INNER JOIN entitys ON employee_month.entity_id = entitys.entity_id
		INNER JOIN employees ON employee_month.entity_id = employees.entity_id
		INNER JOIN department_roles ON employee_month.department_role_id = department_roles.department_role_id
		INNER JOIN departments ON department_roles.department_id = departments.department_id;

CREATE VIEW vw_employee_tax_types AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.end_date, eml.gl_payroll_account,
		eml.entity_id, eml.entity_name, eml.employee_id, eml.identity_card,
		eml.surname, eml.first_name, eml.middle_name, eml.date_of_birth, 
		eml.department_id, eml.department_name, eml.department_account, eml.function_code,
		eml.department_role_id, eml.department_role_name,
		tax_types.tax_type_id, tax_types.tax_type_name, tax_types.account_id, tax_types.tax_type_number,
		tax_types.account_number, tax_types.employer_account,
		employee_tax_types.org_id, employee_tax_types.employee_tax_type_id, employee_tax_types.tax_identification, 
		employee_tax_types.amount, 
		employee_tax_types.additional, employee_tax_types.employer, employee_tax_types.narrative,
		currency.currency_id, currency.currency_name, currency.currency_symbol, employee_tax_types.exchange_rate,
		
		(employee_tax_types.exchange_rate * employee_tax_types.amount) as base_amount,
		(employee_tax_types.exchange_rate * employee_tax_types.employer) as base_employer,
		(employee_tax_types.exchange_rate * employee_tax_types.additional) as base_additional,
		
		(employee_tax_types.exchange_rate * eml.exchange_rate * employee_tax_types.amount) as b_amount,
		(employee_tax_types.exchange_rate * eml.exchange_rate * employee_tax_types.employer) as b_employer,
		(employee_tax_types.exchange_rate * eml.exchange_rate * employee_tax_types.additional) as b_additional
				
	FROM employee_tax_types INNER JOIN vw_employee_month_list as eml ON employee_tax_types.employee_month_id = eml.employee_month_id
		INNER JOIN tax_types ON (employee_tax_types.tax_type_id = tax_types.tax_type_id)
		INNER JOIN currency ON tax_types.currency_id = currency.currency_id;
		
CREATE VIEW vw_employee_tax_month AS
	SELECT emp.period_id, emp.start_date, emp.end_date, emp.overtime_rate, 
		emp.activated, emp.closed, emp.month_id, emp.period_year, emp.period_month,
		emp.quarter, emp.semister, emp.bank_header, emp.bank_address,
		emp.gl_payroll_account, emp.is_posted,
		emp.bank_id, emp.bank_name, emp.bank_branch_id, 
		emp.bank_branch_name, emp.bank_branch_code,
		emp.pay_group_id, emp.pay_group_name, emp.department_id, emp.department_name,
		emp.department_role_id, emp.department_role_name, 
		emp.entity_id, emp.entity_name,
		emp.employee_id, emp.surname, emp.first_name, emp.middle_name, emp.date_of_birth, 
		emp.gender, emp.nationality, emp.marital_status, emp.appointment_date, emp.exit_date, 
		emp.contract, emp.contract_period, emp.employment_terms, emp.identity_card,
		emp.employee_name,
		emp.currency_id, emp.currency_name, emp.currency_symbol, emp.exchange_rate,
		
		emp.org_id, emp.employee_month_id, emp.bank_account, emp.basic_pay, emp.details,
		emp.overtime, emp.full_allowance, emp.payroll_allowance, emp.tax_allowance,
		emp.full_deduction, emp.payroll_deduction, emp.tax_deduction, emp.full_expense,
		emp.payroll_expense, emp.tax_expense, emp.payroll_tax, emp.tax_tax,
		emp.net_adjustment, emp.per_diem, emp.advance, emp.advance_deduction,
		emp.net_pay, emp.banked, emp.cost,
		
		tax_types.tax_type_id, tax_types.tax_type_name, tax_types.account_id, tax_types.use_key_id,
		employee_tax_types.employee_tax_type_id, employee_tax_types.tax_identification, 
		employee_tax_types.amount, employee_tax_types.exchange_rate as tax_exchange_rate,
		employee_tax_types.additional, employee_tax_types.employer, employee_tax_types.narrative,
		
		(employee_tax_types.amount * employee_tax_types.exchange_rate) as tax_base_amount,
		(employee_tax_types.amount * employee_tax_types.exchange_rate * emp.exchange_rate) as b_tax_amount

	FROM vw_employee_month as emp INNER JOIN employee_tax_types ON emp.employee_month_id = employee_tax_types.employee_month_id
		INNER JOIN tax_types ON employee_tax_types.tax_type_id = tax_types.tax_type_id;
	
CREATE VIEW vw_employee_advances AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, eml.end_date,
		eml.month_id, eml.period_year, eml.period_month, eml.gl_payroll_account, 
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_advances.org_id, employee_advances.employee_advance_id, 
		employee_advances.pay_date, employee_advances.pay_period, 
		employee_advances.Pay_upto, employee_advances.amount, employee_advances.in_payroll, employee_advances.completed, 
		employee_advances.approve_status, employee_advances.Action_date, employee_advances.narrative,
		
		(employee_advances.amount * eml.exchange_rate) as b_advance_amount
	FROM employee_advances INNER JOIN vw_employee_month_list as eml ON employee_advances.employee_month_id = eml.employee_month_id;

CREATE VIEW vw_advance_deductions AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, eml.end_date,
		eml.month_id, eml.period_year, eml.period_month, eml.gl_payroll_account, 
		eml.entity_id, eml.entity_name, eml.employee_id,
		advance_deductions.org_id, advance_deductions.advance_deduction_id, advance_deductions.pay_date, 
		advance_deductions.amount, advance_deductions.in_payroll, advance_deductions.narrative,
		
		(advance_deductions.amount * eml.exchange_rate) as b_advance_deduction
	FROM advance_deductions INNER JOIN vw_employee_month_list as eml ON advance_deductions.employee_month_id = eml.employee_month_id;

CREATE VIEW vw_advance_statement AS
	(SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_advances.org_id, employee_advances.pay_date, employee_advances.in_payroll, employee_advances.narrative,
		employee_advances.amount, cast(0 as real) as recovery
	FROM employee_advances INNER JOIN vw_employee_month_list as eml ON employee_advances.employee_month_id = eml.employee_month_id
	WHERE (employee_advances.approve_status = 'Approved'))
	UNION
	(SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		advance_deductions.org_id, advance_deductions.pay_date, advance_deductions.in_payroll, advance_deductions.narrative, 
		cast(0 as real), advance_deductions.amount
	FROM advance_deductions INNER JOIN vw_employee_month_list as eml ON advance_deductions.employee_month_id = eml.employee_month_id);

CREATE VIEW vw_employee_adjustments AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, eml.end_date, 
		eml.month_id, eml.period_year, eml.period_month, 
		eml.fiscal_year_id, eml.fiscal_year,
		eml.entity_id, eml.entity_name, eml.employee_id, eml.identity_card,
		eml.department_id, eml.department_name, eml.department_account, eml.function_code,
		eml.department_role_id, eml.department_role_name,
		adjustments.adjustment_id, adjustments.adjustment_name, adjustments.adjustment_type, 
		adjustments.account_number, adjustments.earning_code, adjustments.adjustment_effect_id,
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		employee_adjustments.org_id, employee_adjustments.employee_adjustment_id, employee_adjustments.pay_date, employee_adjustments.amount, 
		employee_adjustments.in_payroll, employee_adjustments.in_tax, employee_adjustments.visible, employee_adjustments.exchange_rate,
		employee_adjustments.paid_amount, employee_adjustments.balance, employee_adjustments.narrative,
		employee_adjustments.tax_relief_amount,
		
		(employee_adjustments.exchange_rate * employee_adjustments.amount) as base_amount,
		(employee_adjustments.exchange_rate * eml.exchange_rate * employee_adjustments.amount) as b_amount,
		(employee_adjustments.exchange_rate * eml.exchange_rate * employee_adjustments.paid_amount) as b_paid_amount
		
	FROM employee_adjustments INNER JOIN adjustments ON employee_adjustments.adjustment_id = adjustments.adjustment_id
		INNER JOIN vw_employee_month_list as eml ON employee_adjustments.employee_month_id = eml.employee_month_id
		INNER JOIN currency ON adjustments.currency_id = currency.currency_id;

CREATE VIEW vw_employee_overtime AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_overtime.org_id, employee_overtime.employee_overtime_id, employee_overtime.overtime_date, employee_overtime.overtime, 
		employee_overtime.overtime_rate, employee_overtime.narrative, employee_overtime.approve_status, 
		employee_overtime.Action_date, employee_overtime.details
	FROM employee_overtime INNER JOIN vw_employee_month_list as eml ON employee_overtime.employee_month_id = eml.employee_month_id;
	
CREATE VIEW sv_employee_overtime AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_overtime.org_id, 
		sum(employee_overtime.overtime) as overtime_hours, 
		sum(employee_overtime.overtime * employee_overtime.overtime_rate) as overtime_amount
	FROM employee_overtime INNER JOIN vw_employee_month_list as eml ON employee_overtime.employee_month_id = eml.employee_month_id
	GROUP BY eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_overtime.org_id;
	
CREATE VIEW vw_employee_per_diem AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		employee_per_diem.org_id, employee_per_diem.employee_per_diem_id, employee_per_diem.travel_date, employee_per_diem.return_date, employee_per_diem.days_travelled, 
		employee_per_diem.per_diem, employee_per_diem.cash_paid, employee_per_diem.tax_amount, employee_per_diem.full_amount,
		employee_per_diem.travel_to, employee_per_diem.approve_status, employee_per_diem.action_date, 
		employee_per_diem.completed, employee_per_diem.post_account, employee_per_diem.details,
		(employee_per_diem.exchange_rate * employee_per_diem.tax_amount) as base_tax_amount, 
		(employee_per_diem.exchange_rate *  employee_per_diem.full_amount) as base_full_amount,
		
		(employee_per_diem.exchange_rate * eml.exchange_rate * employee_per_diem.full_amount) as b_full_amount,
		(employee_per_diem.exchange_rate * eml.exchange_rate * employee_per_diem.cash_paid) as b_cash_paid
	FROM employee_per_diem INNER JOIN vw_employee_month_list as eml ON employee_per_diem.employee_month_id = eml.employee_month_id;
	
CREATE VIEW vw_employee_banking AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
		eml.pay_group_id, eml.bank_Header, eml.bank_address,
		vw_bank_branch.bank_id, vw_bank_branch.bank_name, vw_bank_branch.bank_branch_id, 
		vw_bank_branch.bank_branch_name, vw_bank_branch.bank_branch_code,
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		
		employee_banking.org_id, employee_banking.employee_banking_id, employee_banking.amount, 
		employee_banking.exchange_rate, employee_banking.cheque, employee_banking.bank_account,
		employee_banking.narrative,
		
		(employee_banking.exchange_rate * employee_banking.amount) as base_amount,
		(employee_banking.exchange_rate * eml.exchange_rate * employee_banking.amount) as b_amount
	FROM employee_banking INNER JOIN vw_employee_month_list as eml ON employee_banking.employee_month_id = eml.employee_month_id
		INNER JOIN vw_bank_branch ON employee_banking.bank_branch_id = vw_bank_branch.bank_branch_id
		INNER JOIN currency ON employee_banking.currency_id = currency.currency_id;

CREATE VIEW vw_absent AS
	SELECT entitys.entity_id, entitys.entity_name, 
		absent.org_id, absent.absent_id, absent.absent_date, absent.time_in, absent.time_out, 
		absent.is_accepted, absent.acceptance_date, absent.narrative,
		absent.deduct_payroll, absent.deduction_date, absent.employee_month_id, absent.amount, 
		absent.employee_comments, absent.details
	FROM absent INNER JOIN entitys ON absent.entity_id = entitys.entity_id;
	
CREATE VIEW vw_absent_month AS
	SELECT eml.employee_month_id, eml.period_id, eml.start_date, 
		eml.month_id, eml.period_year, eml.period_month,
		eml.entity_id, eml.entity_name, eml.employee_id,
	
		absent.org_id, absent.absent_id, absent.absent_date, absent.time_in, absent.time_out, 
		absent.is_accepted, absent.deduct_payroll, absent.acceptance_date, absent.amount,
		absent.narrative, absent.employee_comments, absent.details
	FROM absent INNER JOIN vw_employee_month_list as eml ON absent.employee_month_id = eml.employee_month_id;

CREATE VIEW vw_pension_adjustments AS
	SELECT c.period_id, c.start_date,
		a.employee_adjustment_id, a.employee_month_id, a.adjustment_id, a.pension_id, 
		a.org_id, a.adjustment_type, a.adjustment_factor, a.pay_date, a.amount, 
		a.exchange_rate, a.in_payroll, a.in_tax, a.visible,
		(a.amount * a.exchange_rate) as base_amount
	FROM employee_adjustments as a INNER JOIN employee_month as b ON a.employee_month_id = b.employee_month_id
		INNER JOIN periods as c ON b.period_id = c.period_id
	WHERE (a.pension_id is not null);

CREATE VIEW vw_employee_pensions AS
	SELECT a.entity_id, a.entity_name, a.adjustment_id, a.adjustment_name, a.contribution_id, 
		a.contribution_name, a.org_id, a.pension_id, a.pension_company, a.pension_number, 
		a.active, a.currency_id, a.currency_name, a.currency_symbol,
		b.period_id, b.start_date, b.employee_month_id, 
		COALESCE(b.amount, 0) as amount, 
		COALESCE(b.base_amount, 0) as base_amount,
		COALESCE(c.amount, 0) as employer_amount, 
		COALESCE(c.base_amount, 0) as employer_base_amount,
		(b.amount + COALESCE(c.amount, 0)) as pension_amount, 
		(b.base_amount + COALESCE(c.base_amount, 0)) as pension_base_amount
	FROM (vw_pensions as a INNER JOIN vw_pension_adjustments as b 
		ON (a.pension_id = b.pension_id) AND (a.adjustment_id = b.adjustment_id))
		LEFT JOIN vw_pension_adjustments as c
		ON (a.pension_id = c.pension_id) AND (a.contribution_id = c.adjustment_id)
		AND (b.employee_month_id = c.employee_month_id);

CREATE VIEW vw_employee_per_diem_ledger AS
	(SELECT a.org_id, a.period_id, a.travel_date, 'Travel Cost' as description, 
		a.post_account, a.entity_name, a.b_full_amount as dr_amt, 0.0 as cr_amt
	FROM vw_employee_per_diem a
	WHERE (a.approve_status = 'Approved'))
	UNION
	(SELECT a.org_id, a.period_id, a.travel_date, 'Travel Payment' as description, 
		get_default_account(24, a.org_id)::varchar(32), a.entity_name, 0.0 as dr_amt, cash_paid as cr_amt
	FROM vw_employee_per_diem a
	WHERE (a.approve_status = 'Approved'))
	UNION
	(SELECT  a.org_id, a.period_id, a.travel_date, 'Travel PAYE' as description, 
		get_default_account(25, a.org_id)::varchar(32), a.entity_name, 0.0 as dr_amt, (a.b_full_amount - a.b_cash_paid) as cr_amt
	FROM vw_employee_per_diem a
	WHERE (a.approve_status = 'Approved'));

CREATE VIEW vw_payroll_ledger_trx AS
	SELECT org_id, period_id, end_date, description, gl_payroll_account, entity_name, employee_id,
		dr_amt, cr_amt 
	FROM 
	((SELECT a.org_id, a.period_id, a.end_date, 'BASIC SALARY' as description, 
		a.gl_payroll_account, a.entity_name, a.employee_id,
		a.b_basic_pay as dr_amt, '0.0'::real as cr_amt
	FROM vw_ems a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, 'SALARY PAYMENTS',
		a.gl_payment_account, a.entity_name, a.employee_id,
		'0.0'::real, a.b_banked 
	FROM vw_ems a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.tax_type_name, 
		a.account_number, a.entity_name, a.employee_id,
		'0.0'::real, (a.b_amount + a.b_additional + a.b_employer) 
	FROM vw_employee_tax_types a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, 'Employer - ' || a.tax_type_name, 
		a.account_number, a.entity_name, a.employee_id,
		a.b_employer, '0.0'::real
	FROM vw_employee_tax_types a
	WHERE (a.employer <> 0))
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.adjustment_name, a.account_number, 
		a.entity_name, a.employee_id,
		SUM(CASE WHEN a.adjustment_type = 1 THEN a.b_amount - a.b_paid_amount ELSE '0.0'::real END),
		SUM(CASE WHEN a.adjustment_type = 2 THEN a.b_amount - a.b_paid_amount ELSE '0.0'::real END)
	FROM vw_employee_adjustments a
	WHERE (a.visible = true) AND (a.adjustment_type < 3)
	GROUP BY a.org_id, a.period_id, a.end_date, a.adjustment_name, a.account_number, 
		a.entity_name, a.employee_id)
	UNION
	(SELECT a.org_id, a.period_id, a.travel_date, 'Transport' as description, 
		a.post_account, a.entity_name, a.employee_id,
		(a.b_full_amount - a.b_cash_paid), '0.0'::real
	FROM vw_employee_per_diem a
	WHERE (a.approve_status = 'Approved'))
	UNION
	(SELECT ea.org_id, ea.period_id, ea.end_date, 'SALARY ADVANCE' as description, 
		ea.gl_payroll_account, ea.entity_name, ea.employee_id,
		ea.b_advance_amount, '0.0'::real
	FROM vw_employee_advances as ea
	WHERE (ea.in_payroll = true))
	UNION
	(SELECT ead.org_id, ead.period_id, ead.end_date, 'ADVANCE DEDUCTION' as description, 
		ead.gl_payroll_account, ead.entity_name, ead.employee_id,
		'0.0'::real, ead.b_advance_deduction
	FROM vw_advance_deductions as ead
	WHERE (ead.in_payroll = true))) as b
	ORDER BY gl_payroll_account desc, dr_amt desc, cr_amt desc;

CREATE VIEW vw_payroll_ledger AS
	SELECT org_id, period_id, end_date, description, gl_payroll_account, dr_amt, cr_amt 
	FROM 
	((SELECT a.org_id, a.period_id, a.end_date, 'BASIC SALARY' as description, a.gl_payroll_account, 
		sum(a.b_basic_pay) as dr_amt, '0.0'::real as cr_amt
	FROM vw_ems a
		GROUP BY a.org_id, a.period_id, a.end_date, a.gl_payroll_account)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, 'SALARY PAYMENTS', a.gl_payment_account, 
		'0.0'::real, sum(a.b_banked)
	FROM vw_ems a
		GROUP BY a.org_id, a.period_id, a.end_date, a.gl_payment_account)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.tax_type_name, a.account_number, 
		'0.0'::real, sum(a.b_amount + a.b_additional + a.b_employer)
	FROM vw_employee_tax_types a
		GROUP BY a.org_id, a.period_id, a.end_date, a.tax_type_name, a.account_number)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, 'Employer - ' || a.tax_type_name, a.account_number,
		sum(a.b_employer), '0.0'::real
	FROM vw_employee_tax_types a
	WHERE (a.employer <> 0)
		GROUP BY a.org_id, a.period_id, a.end_date, a.tax_type_name, a.account_number)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.adjustment_name, a.account_number,
		SUM(CASE WHEN a.adjustment_type = 1 THEN a.b_amount - a.b_paid_amount ELSE '0.0'::real END),
		SUM(CASE WHEN a.adjustment_type = 2 THEN a.b_amount - a.b_paid_amount ELSE '0.0'::real END)
	FROM vw_employee_adjustments a
	WHERE (a.visible = true) AND (a.adjustment_type < 3)
		GROUP BY a.org_id, a.period_id, a.end_date, a.adjustment_name, a.account_number)
	UNION
	(SELECT a.org_id, a.period_id, a.travel_date, 'Transport' as description, a.post_account, 
		sum(a.b_full_amount - a.b_cash_paid), '0.0'::real
	FROM vw_employee_per_diem a
	WHERE (a.approve_status = 'Approved')
		GROUP BY a.org_id, a.period_id, a.travel_date, a.post_account)
	UNION
	(SELECT ea.org_id, ea.period_id, ea.end_date, 'SALARY ADVANCE' as description, ea.gl_payroll_account,
		sum(ea.b_advance_amount), '0.0'::real
	FROM vw_employee_advances as ea
	WHERE (ea.in_payroll = true)
		GROUP BY ea.org_id, ea.period_id, ea.end_date, ea.gl_payroll_account)
	UNION
	(SELECT ead.org_id, ead.period_id, ead.end_date, 'ADVANCE DEDUCTION' as description, ead.gl_payroll_account, 
		'0.0'::real, sum(ead.b_advance_deduction)
	FROM vw_advance_deductions as ead
	WHERE (ead.in_payroll = true)
		GROUP BY ead.org_id, ead.period_id, ead.end_date, ead.gl_payroll_account)) as b
	ORDER BY gl_payroll_account desc, dr_amt desc, cr_amt desc;
	
CREATE VIEW vw_sun_ledger_trx AS
	SELECT org_id, period_id, end_date, entity_id,
		gl_payroll_account, description,
		department_account,  employee_id, function_code,
		description2, round(amount::numeric, 1) as gl_amount, debit_credit,
		(period_id::varchar || '.' || entity_id::varchar || '.' || COALESCE(gl_payroll_account, '')) as sun_ledger_id
	FROM
	((SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.gl_payroll_account, 'Payroll' as description, 
		d.department_account, a.employee_id, d.function_code,
		to_char(a.start_date, 'Month YYYY') || ' - Basic Pay' as description2, 
		a.basic_pay as amount, 'D' as debit_credit
	FROM vw_employee_month a INNER JOIN departments d ON a.department_id = d.department_id)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.employee_id, a.entity_name,
		'', '', '',
		to_char(a.start_date, 'Month YYYY') || ' - Netpay' as description2, 
		net_pay as amount, 'C' as debit_credit
	FROM vw_employee_month a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.account_number, a.adjustment_name, 
		a.department_account, a.employee_id, a.function_code,
		to_char(a.start_date, 'Month YYYY') || ' - ' || a.adjustment_name as description2, 
			
		sum(a.amount), 'D' as debit_credit
	FROM vw_employee_adjustments a
	WHERE (a.visible = true) AND (a.adjustment_type = 1)
	GROUP BY a.org_id, a.period_id, a.end_date, a.entity_id,
		a.account_number, a.adjustment_name, 
		a.department_account, a.employee_id, a.function_code, a.start_date)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.account_number, a.adjustment_name, 
		a.department_account, a.employee_id, a.function_code,
		to_char(a.start_date, 'Month YYYY') || ' - ' || a.adjustment_name as description2, 
			
		sum(a.amount), 'C' as debit_credit
	FROM vw_employee_adjustments a
	WHERE (a.visible = true) AND (a.adjustment_type = 2)
	GROUP BY a.org_id, a.period_id, a.end_date, a.entity_id,
		a.account_number, a.adjustment_name, 
		a.department_account, a.employee_id, a.function_code,
		a.start_date)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.account_number, a.tax_type_name,
		a.department_account, a.employee_id, a.function_code,
		to_char(a.start_date, 'Month YYYY') || ' - ' || a.tax_type_name || ' - Deduction',
		(a.amount + a.additional + a.employer), 'C' as debit_credit
	FROM vw_employee_tax_types a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.employer_account, a.tax_type_name,
		a.department_account, a.employee_id, a.function_code,
		to_char(a.start_date, 'Month YYYY') || ' - ' || a.tax_type_name || ' - Contribution',
		a.employer, 'D' as debit_credit
	FROM vw_employee_tax_types a
	WHERE a.employer > 0)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.employee_id, a.entity_name,
		'', '', '',
		to_char(a.start_date, 'Month YYYY') || ' - Payroll Banking' as description2, 
		banked as amount, 'D' as debit_credit
	FROM vw_employee_month a)
	UNION
	(SELECT a.org_id, a.period_id, a.end_date, a.entity_id,
		a.gl_payment_account, 'Bank Account',
		'', '', '',
		to_char(a.start_date, 'Month YYYY') || ' - Payroll Banking' as description2, 
		banked as amount, 'C' as debit_credit
	FROM vw_employee_month a)) as b
	ORDER BY gl_payroll_account desc, amount desc, debit_credit desc;
	
CREATE VIEW vw_intern_month AS
	SELECT vw_interns.entity_id, vw_interns.entity_name, vw_interns.primary_email, vw_interns.primary_telephone, 
		vw_interns.department_id, vw_interns.department_name,
		vw_interns.internship_id, vw_interns.opening_date, vw_interns.closing_date,
		vw_interns.intern_id, vw_interns.payment_amount,
		vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.overtime_rate, 
		vw_periods.activated, vw_periods.closed, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month,
		vw_periods.quarter, vw_periods.semister, vw_periods.gl_payroll_account, vw_periods.is_posted,
		vw_periods.fiscal_year_id, vw_periods.fiscal_year, vw_periods.fiscal_year_start, vw_periods.fiscal_year_end, 
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		
		intern_month.org_id, intern_month.intern_month_id, intern_month.exchange_rate,
		intern_month.month_allowance, intern_month.details,
		(intern_month.exchange_rate * intern_month.month_allowance) as b_month_allowance

	FROM vw_interns INNER JOIN intern_month ON vw_interns.intern_id = intern_month.intern_id
		INNER JOIN vw_periods ON intern_month.period_id = vw_periods.period_id
		INNER JOIN currency ON intern_month.currency_id = currency.currency_id;

CREATE VIEW vw_casuals_month AS
	SELECT vw_casuals.casual_category_id, vw_casuals.casual_category_name, 
		vw_casuals.department_id, vw_casuals.department_name, vw_casuals.casual_application_id, 
		vw_casuals.entity_id, vw_casuals.entity_name, 
		vw_casuals.casual_id, vw_casuals.pay_rate, vw_casuals.approve_status,
		vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.overtime_rate, 
		vw_periods.activated, vw_periods.closed, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month,
		vw_periods.quarter, vw_periods.semister, vw_periods.gl_payroll_account, vw_periods.is_posted,
		vw_periods.fiscal_year_id, vw_periods.fiscal_year, vw_periods.fiscal_year_start, vw_periods.fiscal_year_end, 
		currency.currency_id, currency.currency_name, currency.currency_symbol,

		casuals_month.org_id, casuals_month.casuals_month_id, casuals_month.exchange_rate,
		casuals_month.amount_paid, casuals_month.accrued_date, casuals_month.paid, casuals_month.pay_date, 
		casuals_month.details,
		
		(casuals_month.exchange_rate * casuals_month.amount_paid) as b_amount_paid
	FROM vw_casuals INNER JOIN casuals_month ON vw_casuals.casual_id = casuals_month.casual_id
		INNER JOIN vw_periods ON casuals_month.period_id = vw_periods.period_id
		INNER JOIN currency ON casuals_month.currency_id = currency.currency_id;

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON employee_overtime
	FOR EACH ROW EXECUTE PROCEDURE upd_action();

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON employee_per_diem
	FOR EACH ROW EXECUTE PROCEDURE upd_action();

CREATE OR REPLACE FUNCTION ytd_gross_salary(integer, integer, integer) RETURNS real AS $$
	SELECT sum(gross_salary)::real
	FROM vw_employee_month
	WHERE (entity_id = $1) AND (fiscal_year_id = $2) AND (period_id <= $3);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION ytd_net_pay(integer, integer, integer) RETURNS real AS $$
	SELECT sum(net_pay)::real
	FROM vw_employee_month
	WHERE (entity_id = $1) AND (fiscal_year_id = $2) AND (period_id <= $3);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_gross_salary(integer, date, date) RETURNS real AS $$
	SELECT sum(gross_salary)::real
	FROM vw_employee_month
	WHERE (entity_id = $1) AND (start_date >= $2) AND (start_date <= $3);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_months_worked(integer, date, date) RETURNS integer AS $$
	SELECT count(employee_month_id)::integer
	FROM vw_employee_month
	WHERE (entity_id = $1) AND (start_date >= $2) AND (start_date <= $3);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION ins_taxes() RETURNS trigger AS $$
BEGIN
	INSERT INTO default_tax_types (org_id, entity_id, tax_type_id)
	SELECT NEW.org_id, NEW.entity_id, tax_type_id
	FROM tax_types
	WHERE (active = true) AND (org_id = NEW.org_id)
		AND ((use_key_id = 11) OR (use_key_id = 12));

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_taxes AFTER INSERT ON employees
	FOR EACH ROW EXECUTE PROCEDURE ins_taxes();

CREATE OR REPLACE FUNCTION get_formula_adjustment(int, int, real) RETURNS float AS $$
DECLARE
	v_employee_month_id		integer;
	v_basic_pay				float;
	v_adjustment			float;
BEGIN

	SELECT employee_month.employee_month_id, employee_month.basic_pay INTO v_employee_month_id, v_basic_pay
	FROM employee_month
	WHERE (employee_month.employee_month_id = $1);

	IF ($2 = 1) THEN
		v_adjustment := v_basic_pay * $3;
	ELSE
		v_adjustment := 0;
	END IF;

	IF(v_adjustment is null) THEN
		v_adjustment := 0;
	END IF;

	RETURN v_adjustment;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_payroll(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_period_tax_type_id		integer;
	v_employee_month_id			integer;
	v_period_id					integer;
	v_currency_id				integer;
	v_org_id					integer;
	v_start_date				date;
	v_end_date					date;
	v_start_year				date;
	v_month_name				varchar(50);

	msg 						varchar(120);
BEGIN
	SELECT period_id, org_id, to_char(start_date, 'Month YYYY'), start_date, end_date
		INTO v_period_id, v_org_id, v_month_name, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = CAST($1 as integer));
	
	SELECT period_tax_type_id INTO v_period_tax_type_id
	FROM period_tax_types
	WHERE (period_id = v_period_id) AND (org_id = v_org_id);
	
	SELECT employee_month_id INTO v_employee_month_id
	FROM employee_month
	WHERE (period_id = v_period_id) AND (org_id = v_org_id);

	IF(v_period_tax_type_id is null) AND (v_employee_month_id is null)THEN
		INSERT INTO period_tax_types (period_id, org_id, tax_type_id, period_tax_type_name, formural, tax_relief, percentage, linear, employer, employer_ps, tax_type_order, in_tax, account_id, employer_formural, employer_relief, limit_employee, limit_employer)
		SELECT v_period_id, org_id, tax_type_id, tax_type_name, formural, tax_relief, percentage, linear, employer, employer_ps, tax_type_order, in_tax, account_id, employer_formural, employer_relief, limit_employee, limit_employer
		FROM tax_types
		WHERE (active = true) AND (org_id = v_org_id);

		INSERT INTO employee_month (period_id, org_id, pay_group_id, entity_id, bank_branch_id, department_role_id, currency_id, bank_account, basic_pay)
		SELECT v_period_id, org_id, pay_group_id, entity_id, bank_branch_id, department_role_id, currency_id, bank_account, basic_salary
		FROM employees
		WHERE (employees.active = true) and (employees.org_id = v_org_id);

		INSERT INTO loan_monthly (period_id, org_id, loan_id, interest_amount, interest_paid, repayment)
		SELECT v_period_id, org_id, loan_id, (loan_balance * interest / 1200), (loan_balance * interest / 1200),
			(CASE WHEN loan_balance > monthly_repayment THEN monthly_repayment ELSE loan_balance END)
		FROM vw_loans 
		WHERE (loan_balance > 0) AND (approve_status = 'Approved') AND (reducing_balance =  true) AND (org_id = v_org_id);

		INSERT INTO loan_monthly (period_id, org_id, loan_id, interest_amount, interest_paid, repayment)
		SELECT v_period_id, org_id, loan_id, (principle * interest / 1200), (principle * interest / 1200),
			(CASE WHEN loan_balance > monthly_repayment THEN monthly_repayment ELSE loan_balance END)
		FROM vw_loans 
		WHERE (loan_balance > 0) AND (approve_status = 'Approved') AND (reducing_balance =  false) AND (org_id = v_org_id);
		
		SELECT currency_id INTO v_currency_id
		FROM orgs WHERE org_id = v_org_id;
		
		INSERT INTO intern_month (period_id, currency_id, org_id, intern_id, exchange_rate, month_allowance)
		SELECT v_period_id, v_currency_id, v_org_id, intern_id, 1, payment_amount
		FROM interns
		WHERE (org_id = v_org_id) AND (approve_status = 'Approved')
			AND (start_date < v_end_date) AND (end_date > v_end_date);
		
		--- costs on projects based on staff
		msg := get_task_costs($1, $2, $3);
		
		--- compute autogenated overtime
		msg := get_attendance_pay($1, $2, $3);

		PERFORM upd_tax(employee_month_id, Period_id)
		FROM employee_month
		WHERE (period_id = v_period_id);
				
		INSERT INTO sys_emailed (sys_email_id, table_id, table_name, narrative, org_id)
		SELECT 7, entity_id, 'periods', v_month_name, v_org_id
		FROM entity_subscriptions
		WHERE entity_type_id = 6;
	
		msg := 'Payroll Generated';
	ELSE
		msg := 'Payroll was previously Generated';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_period_tax_types() RETURNS trigger AS $$
BEGIN
	INSERT INTO period_tax_rates (org_id, period_tax_type_id, tax_range, tax_rate, employer_rate, rate_relief)
	SELECT NEW.org_id, NEW.period_tax_type_id, tax_range, tax_rate, employer_rate, rate_relief
	FROM tax_rates
	WHERE (tax_type_id = NEW.tax_type_id);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_period_tax_types AFTER INSERT ON period_tax_types
    FOR EACH ROW EXECUTE PROCEDURE ins_period_tax_types();
    
CREATE OR REPLACE FUNCTION ins_employee_month() RETURNS trigger AS $$
BEGIN

	SELECT exchange_rate INTO NEW.exchange_rate
	FROM currency_rates
	WHERE (currency_rate_id = 
		(SELECT MAX(currency_rate_id)
		FROM currency_rates
		WHERE (currency_id = NEW.currency_id) AND (org_id = NEW.org_id)
			AND (exchange_date < CURRENT_DATE)));
		
	IF(NEW.exchange_rate is null)THEN NEW.exchange_rate := 1; END IF;	
	
	SELECT contract_types.part_time INTO NEW.part_time
	FROM contract_types INNER JOIN applications ON contract_types.contract_type_id = applications.contract_type_id
	WHERE (applications.application_id IN
	(SELECT max(applications.application_id)
	FROM applications
	WHERE (applications.employee_id = NEW.entity_id)
		AND (applications.contract_start <= current_date) AND (applications.contract_close >= current_date)
		AND (approve_status = 'Approved')));
		
	IF(NEW.part_time is null)THEN NEW.part_time := false; END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_employee_month BEFORE INSERT ON employee_month
    FOR EACH ROW EXECUTE PROCEDURE ins_employee_month();

CREATE OR REPLACE FUNCTION upd_employee_month() RETURNS trigger AS $$
BEGIN
	INSERT INTO employee_tax_types (org_id, employee_month_id, tax_type_id, tax_identification, additional, amount, employer, in_tax, exchange_rate)
	SELECT NEW.org_id, NEW.employee_month_id, default_tax_types.tax_type_id, default_tax_types.tax_identification, 
		Default_Tax_Types.Additional, 0, 0, Tax_Types.In_Tax,
		(CASE WHEN Tax_Types.currency_id = NEW.currency_id THEN 1 ELSE 1 / NEW.exchange_rate END)
	FROM Default_Tax_Types INNER JOIN Tax_Types ON Default_Tax_Types.Tax_Type_id = Tax_Types.Tax_Type_id
	WHERE (Default_Tax_Types.active = true) AND (Default_Tax_Types.entity_ID = NEW.entity_ID);

	INSERT INTO employee_adjustments (org_id, employee_month_id, adjustment_id, amount, adjustment_type, in_payroll, in_tax, visible, adjustment_factor, 
		balance, tax_relief_amount, exchange_rate, narrative)
	SELECT NEW.org_id, NEW.employee_month_id, default_adjustments.adjustment_id, default_adjustments.amount,
		adjustments.adjustment_type, adjustments.in_payroll, adjustments.in_tax, adjustments.visible,
		(CASE WHEN adjustments.adjustment_type = 2 THEN -1 ELSE 1 END),
		(CASE WHEN (adjustments.running_balance = true) AND (adjustments.reduce_balance = false) THEN (default_adjustments.balance + default_adjustments.amount)
			WHEN (adjustments.running_balance = true) AND (adjustments.reduce_balance = true) THEN (default_adjustments.balance - default_adjustments.amount) END),
		(default_adjustments.amount * adjustments.tax_relief_ps / 100),
		(CASE WHEN adjustments.currency_id = NEW.currency_id THEN 1 ELSE 1 / NEW.exchange_rate END),
		narrative
	FROM default_adjustments INNER JOIN adjustments ON default_adjustments.adjustment_id = adjustments.adjustment_id
	WHERE ((default_adjustments.final_date is null) OR (default_adjustments.final_date > current_date))
		AND (default_adjustments.active = true) AND (default_adjustments.entity_id = NEW.entity_id);

	INSERT INTO advance_deductions (org_id, amount, employee_month_id)
	SELECT NEW.org_id, (Amount / Pay_Period), NEW.Employee_Month_ID
	FROM employee_advances INNER JOIN employee_month ON employee_advances.employee_month_id = employee_month.employee_month_id
	WHERE (employee_month.entity_id = NEW.entity_id) AND (employee_advances.pay_period > 0) AND (employee_advances.completed = false)
		AND (employee_advances.pay_upto >= current_date);
		
	INSERT INTO project_staff_costs (org_id, employee_month_id, project_id, project_role, payroll_ps, staff_cost, tax_cost)
	SELECT NEW.org_id, NEW.employee_month_id, 
		project_staff.project_id, project_staff.project_role, project_staff.payroll_ps, project_staff.staff_cost, project_staff.tax_cost
	FROM project_staff
	WHERE (project_staff.entity_id = NEW.entity_id) AND (project_staff.monthly_cost = true);
	
	INSERT INTO employee_banking (org_id, employee_month_id, bank_branch_id, currency_id, 
		bank_account, amount, cheque,
		exchange_rate)
	SELECT NEW.org_id, NEW.employee_month_id, bank_branch_id, currency_id,
		bank_account, amount, cheque,
		(CASE WHEN default_banking.currency_id = NEW.currency_id THEN 1 ELSE 1 / NEW.exchange_rate END)
	FROM default_banking 
	WHERE (default_banking.entity_id = NEW.entity_id) AND (default_banking.active = true)
		AND (amount > 0);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_employee_month AFTER INSERT ON employee_month
    FOR EACH ROW EXECUTE PROCEDURE upd_employee_month();

CREATE OR REPLACE FUNCTION get_tax(float, int, int) RETURNS float AS $$
DECLARE
	reca		RECORD;
	tax			REAL;
BEGIN
	SELECT period_tax_type_id, formural, tax_relief, employer_relief, percentage, linear, in_tax, 
		employer, employer_ps, limit_employee, limit_employer
	INTO reca
	FROM period_tax_types
	WHERE (period_tax_type_id = $2);

	IF(reca.linear = true) THEN
		SELECT SUM(CASE WHEN tax_range < $1 
		THEN (tax_rate / 100) * (tax_range - get_tax_min(tax_range, reca.period_tax_type_id, $3)) 
		ELSE (tax_rate / 100) * ($1 - get_tax_min(tax_range, reca.period_tax_type_id, $3)) END) INTO tax
		FROM period_tax_rates 
		WHERE (get_tax_min(tax_range, reca.period_tax_type_id, $3) <= $1) 
			AND (employer_rate = $3) AND (period_tax_type_id = reca.period_tax_type_id);
	ELSIF(reca.linear = false) AND (reca.percentage = false)THEN 
		SELECT max(tax_rate) - max(rate_relief) INTO tax
		FROM period_tax_rates 
		WHERE (get_tax_min(tax_range, reca.period_tax_type_id, $3) < $1) AND (tax_range >= $1) 
			AND (employer_rate = $3) AND (period_tax_type_id = reca.period_tax_type_id);
	ELSIF(reca.linear = false) AND (reca.percentage = true)THEN 
		SELECT (max(tax_rate) * $1 / 100)  - max(rate_relief) INTO tax
		FROM period_tax_rates 
		WHERE (get_tax_min(tax_range, reca.period_tax_type_id, $3) < $1) AND (tax_range >= $1) 
			AND (employer_rate = $3) AND (period_tax_type_id = reca.period_tax_type_id);
	END IF;

	IF (tax is null) THEN
		tax := 0;
	END IF;

	---- Employee tax relief
	IF($3 = 0)THEN
		IF (tax > reca.tax_relief) THEN
			tax := tax - reca.tax_relief;
		ELSE
			tax := 0;
		END IF;
		IF(reca.limit_employee is not null)THEN
			IF(tax > reca.limit_employee)THEN
				tax := reca.limit_employee;
			END IF;
		END IF;
	END IF;
	
	---- Employee tax relief
	IF($3 = 1)THEN
		IF (tax > reca.employer_relief) THEN
			tax := tax - reca.employer_relief;
		ELSE
			tax := 0;
		END IF;
		IF(reca.limit_employer is not null)THEN
			IF(tax > reca.limit_employer)THEN
				tax := reca.limit_employer;
			END IF;
		END IF;
	END IF;

	RETURN tax;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_employee_tax(int, int) RETURNS float AS $$
DECLARE
	v_employee_month_id			integer;
	v_period_tax_type_id		integer;
	v_exchange_rate				real;
	v_income					real;
	v_tax_relief				real;
	v_tax						real;
BEGIN

	SELECT employee_tax_types.employee_month_id, period_tax_types.period_tax_type_id, employee_tax_types.exchange_rate
		INTO v_employee_month_id, v_period_tax_type_id, v_exchange_rate
	FROM employee_tax_types INNER JOIN employee_month ON employee_tax_types.employee_month_id = employee_month.employee_month_id
		INNER JOIN period_tax_types ON (employee_month.period_id = period_tax_types.period_id)
			AND (employee_tax_types.tax_type_id = period_tax_types.tax_type_id)
	WHERE (employee_tax_types.employee_tax_type_id	= $1);
	
	IF(v_exchange_rate = 0) THEN v_exchange_rate := 1; END IF;

	IF ($2 = 1) THEN
		v_income := getAdjustment(v_employee_month_id, 1) / v_exchange_rate;
		v_tax := get_tax(v_income, v_period_tax_type_id, 0);

	ELSIF ($2 = 2) THEN
		v_income := getAdjustment(v_employee_month_id, 2) / v_exchange_rate;
		v_tax := get_tax(v_income, v_period_tax_type_id, 0) - getAdjustment(v_employee_month_id, 4, 25) / v_exchange_rate;

	ELSIF ($2 = 3) THEN
		v_income := getAdjustment(v_employee_month_id, 3) / v_exchange_rate;
		v_tax := get_tax(v_income, v_period_tax_type_id, 0);
	
	ELSIF ($2 = 4) THEN
		v_income := getAdjustment(v_employee_month_id, 2) / v_exchange_rate;
		v_tax_relief := getAdjustment(v_employee_month_id, 1) / 100;
		if(v_tax_relief < 16666.67) then v_tax_relief := 16666.67; end if;
		v_tax_relief := v_tax_relief + getAdjustment(v_employee_month_id, 1) / 5;
		v_income := v_income - v_tax_relief;
		v_tax := get_tax(v_income, v_period_tax_type_id, 0) - getAdjustment(v_employee_month_id, 4, 25) / v_exchange_rate;
		
	ELSIF ($2 = 5) THEN	---- employer tax
		v_income := getAdjustment(v_employee_month_id, 2) / v_exchange_rate;
		v_tax := get_tax(v_income, v_period_tax_type_id, 1) - getAdjustment(v_employee_month_id, 4, 25) / v_exchange_rate;
		
	ELSIF ($2 = 7) THEN	---- for Nigeria
		v_tax_relief := getAdjustment(v_employee_month_id, 1) / v_exchange_rate;
		v_tax_relief := 16666.67 +  (v_tax_relief * 0.2);
		v_income := getAdjustment(v_employee_month_id, 2) / v_exchange_rate;
		v_tax := get_tax(v_income, v_period_tax_type_id, 1) - v_tax_relief;
	ELSE
		v_tax := 0;
	END IF;

	IF(v_tax is null) THEN
		v_tax := 0;
	ELSIF(v_tax < 0) THEN
		v_tax := 0;
	END IF;

	RETURN v_tax;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upd_tax(int, int) RETURNS float AS $$
DECLARE
	reca 					RECORD;
	income 					real;
	tax 					real;
	tax_employer			real;
	InsuranceRelief 		real;
BEGIN

	FOR reca IN SELECT employee_tax_types.employee_tax_type_id, employee_tax_types.tax_type_id, period_tax_types.formural,
			 period_tax_types.employer, period_tax_types.employer_ps, period_tax_types.employer_formural
		FROM employee_tax_types INNER JOIN period_tax_types ON (employee_tax_types.tax_type_id = period_tax_types.tax_type_id)
		WHERE (employee_month_id = $1) AND (Period_Tax_Types.Period_ID = $2)
		ORDER BY Period_Tax_Types.Tax_Type_order 
	LOOP

		EXECUTE 'SELECT ' || reca.formural || ' FROM employee_tax_types WHERE employee_tax_type_id = ' || reca.employee_tax_type_id 
		INTO tax;
		
		tax_employer := 0;
		IF(reca.employer_formural is not null)THEN
			EXECUTE 'SELECT ' || reca.employer_formural || ' FROM employee_tax_types WHERE employee_tax_type_id = ' || reca.employee_tax_type_id 
			INTO tax_employer;
			IF(tax_employer is null)THEN tax_employer := 0; END IF;
		END IF;
		tax_employer := tax_employer + reca.employer + (tax * reca.employer_ps / 100);
		
		UPDATE employee_tax_types SET amount = tax, employer = tax_employer
		WHERE employee_tax_type_id = reca.employee_tax_type_id;
	END LOOP;

	RETURN tax;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_payroll(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec 						RECORD;
	v_start_date				date;
	v_end_date					date;
	v_start_year				date;
	msg 						varchar(120);
BEGIN
	IF ($3 = '1') THEN
		UPDATE employee_adjustments SET tax_reduction_amount = 0 
		FROM employee_month 
		WHERE (employee_adjustments.employee_month_id = employee_month.employee_month_id) 
			AND (employee_month.period_id = $1::int);
			
		--- compute autogenated overtime
		msg := get_attendance_pay($1, $2, $3);
		
		--- costs on projects based on staff
		msg := get_task_costs($1, $2, $3);
	
		PERFORM upd_tax(employee_month_id, period_id)
		FROM employee_month
		WHERE (period_id = $1::int);
		
		--- Update the Average Day Rate
		SELECT start_date - '1 year'::interval, start_date INTO v_start_year, v_start_date
		FROM periods WHERE (period_id = $1::int);
		UPDATE employees SET average_daily_rate = get_gross_salary(entity_id, v_start_year, v_start_date) / (24 * get_months_worked(entity_id, v_start_year, v_start_date))
		WHERE (active = true) AND (get_months_worked(entity_id, v_start_year, v_start_date) > 0);

		msg := 'Payroll Processed';
	ELSIF ($3 = '2') THEN
		UPDATE periods SET entity_id = $2::int, approve_status = 'Completed'
		WHERE (period_id = $1::int);

		msg := 'Application for approval';
	ELSIF ($3 = '3') THEN
		UPDATE periods SET closed = true
		WHERE (period_id = $1::int);

		msg := 'Period closed';
	ELSIF ($3 = '4') THEN
		UPDATE periods SET closed = false
		WHERE (period_id = $1::int);

		msg := 'Period opened';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ins_employee_adjustments() RETURNS trigger AS $$
DECLARE
	v_formural				varchar(430);
	v_tax_relief_ps			float;
	v_tax_reduction_ps		float;
	v_tax_max_allowed		float;
BEGIN
	IF((NEW.Amount = 0) AND (NEW.paid_amount <> 0))THEN
		NEW.Amount = NEW.paid_amount / 0.7;
	END IF;
	
	IF(NEW.exchange_rate is null) THEN NEW.exchange_rate = 1; END IF;
	IF(NEW.exchange_rate = 0) THEN NEW.exchange_rate = 1; END IF;

	SELECT adjustment_type, formural INTO NEW.adjustment_type, v_formural
	FROM adjustments 
	WHERE (adjustments.adjustment_id = NEW.adjustment_id);
	
	IF(NEW.adjustment_type = 2)THEN
		NEW.adjustment_factor = -1;
	END IF;
	
	IF(NEW.Amount = 0) and (v_formural is not null)THEN
		EXECUTE 'SELECT ' || v_formural || ' FROM employee_month WHERE employee_month_id = ' || NEW.employee_month_id
		INTO NEW.Amount;
		NEW.Amount := NEW.Amount / NEW.exchange_rate;
	END IF;

	IF(NEW.in_tax = true)THEN
		SELECT tax_reduction_ps, tax_relief_ps, tax_max_allowed INTO v_tax_reduction_ps, v_tax_relief_ps, v_tax_max_allowed
		FROM adjustments
		WHERE (adjustments.adjustment_id = NEW.adjustment_id);

		IF(v_tax_reduction_ps is null)THEN
			NEW.tax_reduction_amount := 0;
		ELSE
			NEW.tax_reduction_amount := NEW.amount * v_tax_reduction_ps / 100;
			NEW.tax_reduction_amount := NEW.tax_reduction_amount;
		END IF;

		IF(v_tax_relief_ps is null)THEN
			NEW.tax_relief_amount := 0;
		ELSE
			NEW.tax_relief_amount := NEW.amount * v_tax_relief_ps / 100;
			NEW.tax_relief_amount := NEW.tax_relief_amount;
		END IF;

		IF(v_tax_max_allowed is not null)THEN
			IF(NEW.tax_reduction_amount > v_tax_max_allowed)THEN
				NEW.tax_reduction_amount := v_tax_max_allowed;
			END IF;
			IF(NEW.tax_relief_amount > v_tax_max_allowed)THEN
				NEW.tax_relief_amount := v_tax_max_allowed;
			END IF;
		END IF;
	ELSE
		NEW.tax_relief_amount := 0;
		NEW.tax_reduction_amount := 0;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_employee_adjustments BEFORE INSERT OR UPDATE ON employee_adjustments
    FOR EACH ROW EXECUTE PROCEDURE ins_employee_adjustments();

CREATE OR REPLACE FUNCTION upd_employee_adjustments() RETURNS trigger AS $$
DECLARE
	rec 			RECORD;
	entityid 		integer;
	periodid 		integer;
	v_balance		real;
BEGIN
	SELECT monthly_update, running_balance INTO rec
	FROM adjustments WHERE adjustment_id = NEW.Adjustment_ID;

	SELECT entity_id, period_id INTO entityid, periodid
	FROM employee_month WHERE employee_month_id = NEW.employee_month_id;

	IF(rec.running_balance = true) THEN
		SELECT sum(amount) INTO v_balance
		FROM vw_employee_adjustments
		WHERE (entity_id = entityid) AND (adjustment_id = NEW.adjustment_id);
		IF(v_balance is null)THEN v_balance := 0; END IF;
		
		UPDATE default_adjustments SET balance = v_balance
		WHERE (entity_id = entityid) AND (adjustment_id = NEW.adjustment_id);
	END IF;

	IF(TG_OP = 'UPDATE')THEN
		IF (OLD.amount <> NEW.amount)THEN
			IF(rec.monthly_update = true)THEN
				UPDATE default_adjustments SET amount = NEW.amount 
				WHERE (entity_id = entityid) AND (adjustment_id = NEW.adjustment_id);
			END IF;

			PERFORM upd_tax(employee_month_id, Period_id)
			FROM employee_month
			WHERE (period_id = periodid);
		END IF;
	ELSE
		PERFORM upd_tax(employee_month_id, Period_id)
		FROM employee_month
		WHERE (period_id = periodid);
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_employee_adjustments AFTER INSERT OR UPDATE ON employee_adjustments
    FOR EACH ROW EXECUTE PROCEDURE upd_employee_adjustments();

CREATE OR REPLACE FUNCTION upd_employee_per_diem() RETURNS trigger AS $$
DECLARE
	v_period_id			integer;
	v_tax_limit			real;
BEGIN
	SELECT periods.period_id, periods.per_diem_tax_limit INTO v_period_id, v_tax_limit
	FROM employee_month INNER JOIN periods ON employee_month.period_id = periods.period_id
	WHERE employee_month_id = NEW.employee_month_id;
	
	IF(NEW.days_travelled  is null)THEN
		NEW.days_travelled := NEW.return_date - NEW.travel_date;
	END IF;

	IF(NEW.cash_paid = 0) THEN
		NEW.cash_paid := NEW.per_diem;
	END IF;
	IF(NEW.tax_amount = 0) THEN
		NEW.full_amount := (NEW.per_diem - (v_tax_limit * NEW.days_travelled * 0.3)) / 0.7;
		NEW.tax_amount := NEW.full_amount - (v_tax_limit * NEW.days_travelled);
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_Employee_Per_Diem BEFORE INSERT OR UPDATE ON Employee_Per_Diem
    FOR EACH ROW EXECUTE PROCEDURE upd_Employee_Per_Diem();

CREATE OR REPLACE FUNCTION process_ledger(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec						RECORD;
	v_period_id				integer;
	v_journal_id			integer;
	v_account_no			varchar(32);
	ledger_diff				real;
	msg						varchar(120);
BEGIN

	v_period_id := $1::int;

	SELECT periods.period_id, periods.is_posted, periods.opened, periods.closed, periods.end_date,
		orgs.org_id, orgs.currency_id, orgs.payroll_payable
		INTO rec
	FROM periods INNER JOIN orgs ON periods.org_id = orgs.org_id
	WHERE (periods.period_id = v_period_id);

	SELECT abs(sum(dr_amt) - sum(cr_amt)) INTO ledger_diff
	FROM vw_payroll_ledger
	WHERE (period_id = v_period_id);
	
	SELECT vw_payroll_ledger.gl_payroll_account INTO v_account_no
	FROM vw_payroll_ledger LEFT JOIN accounts ON (vw_payroll_ledger.gl_payroll_account = accounts.account_no::text)
		AND (vw_payroll_ledger.org_id = accounts.org_id)
	WHERE (vw_payroll_ledger.period_id = v_period_id) AND (accounts.account_id is null);
	
	IF(rec.is_posted = true)THEN
		msg := 'The payroll for this period is already posted';
	ELSIF(ledger_diff > 1) THEN
		msg := 'The ledger is not balanced';
	ELSIF((rec.opened = false) OR (rec.closed = true)) THEN
		msg := 'Transaction period has to be opened and not closed.';
	ELSIF(v_account_no is not null) THEN
		msg := 'Ensure the accounts match the ledger accounts';
	ELSE
		v_journal_id := nextval('journals_journal_id_seq');
		INSERT INTO journals (journal_id, org_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (v_journal_id, rec.org_id, rec.currency_id, rec.period_id, 1, rec.end_date, 'Payroll posting for ' || to_char(rec.end_date, 'MMM YYYY'));

		INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
		SELECT aa.org_id, v_journal_id, bb.account_id, aa.dr_amt, aa.cr_amt, aa.description
		FROM vw_payroll_ledger aa LEFT JOIN accounts bb ON (aa.gl_payroll_account = bb.account_no::text) AND (aa.org_id = bb.org_id)
		WHERE (aa.period_id = v_period_id);
		
		IF(rec.payroll_payable = true)THEN
			msg := payroll_payable(v_period_id, $2::integer);
		END IF;

		UPDATE periods SET is_posted = true
		WHERE (period_id = v_period_id);

		msg := 'Payroll Ledger Processed';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION del_period(int) RETURNS varchar(120) AS $$
DECLARE
	msg 		varchar(120);
BEGIN
	DELETE FROM loan_monthly WHERE period_id = $1;
	
	DELETE FROM advance_deductions WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM employee_advances WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM employee_banking WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM employee_adjustments WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM employee_overtime WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM employee_tax_types WHERE (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = $1));
	DELETE FROM period_tax_rates WHERE (period_tax_type_id IN (SELECT period_tax_type_id FROM period_tax_types WHERE period_id = $1));
	DELETE FROM period_tax_types WHERE period_id = $1;

	DELETE FROM employee_month WHERE period_id = $1;
	DELETE FROM periods WHERE period_id = $1;

	msg := 'Period Deleted';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_payroll(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_entity_id		integer;
	v_pay_step_id	integer;
	v_pay_step		integer;
	v_next_step_id	integer;
	v_pay_scale_id	integer;
	v_currency_id	integer;
	v_pay_amount	real;
	msg 			varchar(120);
BEGIN

	v_entity_id := CAST($1 as int);
	
	IF ($3 = '1') THEN
		SELECT pay_scale_steps.pay_scale_step_id, pay_scale_steps.pay_amount, pay_scales.currency_id
			INTO v_pay_step_id, v_pay_amount, v_currency_id
		FROM employees INNER JOIN pay_scale_steps ON employees.pay_scale_step_id = pay_scale_steps.pay_scale_step_id
			INNER JOIN pay_scales ON pay_scale_steps.pay_scale_id = pay_scales.pay_scale_id
		WHERE employees.entity_id = v_entity_id;
		
		IF((v_pay_amount is not null) AND (v_currency_id is not null))THEN
			UPDATE employees SET basic_salary = v_pay_amount, currency_id = v_currency_id
			WHERE entity_id = v_entity_id;
		END IF;

		msg := 'Updated the pay';
	ELSIF ($3 = '2') THEN
		SELECT pay_scale_steps.pay_scale_step_id, pay_scale_steps.pay_scale_id, pay_scale_steps.pay_step
			INTO v_pay_step_id, v_pay_scale_id, v_pay_step
		FROM employees INNER JOIN pay_scale_steps ON employees.pay_scale_step_id = pay_scale_steps.pay_scale_step_id
		WHERE employees.entity_id = v_entity_id;
		
		SELECT pay_scale_steps.pay_scale_step_id INTO v_next_step_id
		FROM pay_scale_steps
		WHERE (pay_scale_steps.pay_scale_id = v_pay_scale_id) AND (pay_scale_steps.pay_step = v_pay_step + 1);
		
		IF(v_next_step_id is not null)THEN
			UPDATE employees SET pay_scale_step_id = v_next_step_id
			WHERE entity_id = v_entity_id;
		END IF;

		msg := 'Pay step incremented';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_adjustment(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	adj							RECORD;
	rec							RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_adjustment_factor			integer;
	v_default_adjustment_id		integer;
	v_amount					real;
	msg							varchar(120);
BEGIN

	SELECT adjustment_id, adjustment_name, org_id, adjustment_type, formural, default_amount, in_payroll, in_tax, visible INTO adj
	FROM adjustments
	WHERE (adjustment_id = $1::integer);
	
	IF(adj.adjustment_type = 2)THEN
		v_adjustment_factor := -1;
	ELSE
		v_adjustment_factor := 1;
	END IF;
	
	IF ($3 = '1') THEN
		SELECT max(period_id) INTO v_period_id
		FROM periods
		WHERE (closed = false) AND (org_id = adj.org_id);
		
		FOR rec IN SELECT employee_month_id, exchange_rate
			FROM employee_month 
			WHERE (period_id = v_period_id) 
		LOOP
			
			IF(adj.formural is not null)THEN
				EXECUTE 'SELECT ' || adj.formural || ' FROM employee_month WHERE employee_month_id = ' || rec.employee_month_id
				INTO v_amount;
			END IF;
			IF(v_amount is null)THEN
				v_amount := adj.default_amount;
			END IF;
	
			IF(v_amount is not null)THEN
				INSERT INTO employee_adjustments (employee_month_id, adjustment_id, org_id,
					adjustment_type, adjustment_factor, pay_date, amount,
					exchange_rate, in_payroll, in_tax, visible)
				VALUES(rec.employee_month_id, adj.adjustment_id, adj.org_id,
					adj.adjustment_type, v_adjustment_factor, current_date, v_amount,
				(1 / rec.exchange_rate), adj.in_payroll, adj.in_tax, adj.visible);
			END IF;
		END LOOP;
		msg := 'Added ' || adj.adjustment_name || ' to month';
	ELSIF ($3 = '2') THEN	
		FOR rec IN SELECT entity_id
			FROM employees
			WHERE (active = true) AND (org_id = adj.org_id) 
		LOOP
			
			SELECT default_adjustment_id INTO v_default_adjustment_id
			FROM default_adjustments
			WHERE (entity_id = rec.entity_id) AND (adjustment_id = adj.adjustment_id);
			
			IF(v_default_adjustment_id is null)THEN
				INSERT INTO default_adjustments (entity_id, adjustment_id, org_id,
					amount, active)
				VALUES (rec.entity_id, adj.adjustment_id, adj.org_id,
					adj.default_amount, true);
			END IF;
		END LOOP;
		msg := 'Added ' || adj.adjustment_name || ' to employees';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_pensions(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec							RECORD;
	adj							RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_employee_month_id			integer;
	v_employee_adjustment_id	integer;
	v_currency_id				integer;
	v_exchange_rate				real;
	a_exchange_rate				real;
	v_amount					real;
	msg							varchar(120);
BEGIN

	SELECT period_id, org_id INTO v_period_id, v_org_id
	FROM periods WHERE period_id = $1::int;
	
	FOR rec IN SELECT pension_id, entity_id, adjustment_id, contribution_id, 
		pension_company, pension_number, amount, use_formura, 
		employer_ps, employer_amount, employer_formural
		FROM pensions WHERE (active = true) AND (org_id = v_org_id) 
	LOOP
	
		SELECT employee_month_id, currency_id, exchange_rate 
			INTO v_employee_month_id, v_currency_id, v_exchange_rate
		FROM employee_month
		WHERE (period_id = v_period_id) AND (entity_id = rec.entity_id);
		
		--- Deduction
		SELECT employee_adjustment_id INTO v_employee_adjustment_id
		FROM employee_adjustments
		WHERE (employee_month_id = v_employee_month_id) AND (pension_id = rec.pension_id)
			AND (adjustment_id = rec.adjustment_id);
		
		SELECT adjustment_id, currency_id, org_id, adjustment_name, adjustment_type, 
			adjustment_order, earning_code, formural, monthly_update, in_payroll, 
			in_tax, visible, running_balance, reduce_balance, tax_reduction_ps, 
			tax_relief_ps, tax_max_allowed, account_number
		INTO adj
		FROM adjustments
		WHERE (adjustment_id = rec.adjustment_id);
		
		v_amount := 0;
		IF(rec.use_formura = true) AND (adj.formural is not null) AND (v_employee_month_id is not null) THEN
			EXECUTE 'SELECT ' || adj.formural || ' FROM employee_month WHERE employee_month_id = ' || v_employee_month_id
			INTO v_amount;
			IF(v_currency_id <> adj.currency_id)THEN
				v_amount := v_amount * v_exchange_rate;
			END IF;
		ELSIF(rec.amount > 0)THEN
			v_amount := rec.amount;
		END IF;
		
		a_exchange_rate := 1;
		IF(v_currency_id <> adj.currency_id)THEN
			a_exchange_rate := 1 / v_exchange_rate;
		END IF;
		
		IF(v_employee_adjustment_id is null) AND (v_employee_month_id is not null) THEN
			INSERT INTO employee_adjustments(employee_month_id, pension_id, org_id, 
				adjustment_id, adjustment_type, adjustment_factor, 
				in_payroll, in_tax, visible,
				exchange_rate, pay_date, amount)
			VALUES (v_employee_month_id, rec.pension_id, v_org_id,
				adj.adjustment_id, adj.adjustment_type, -1, 
				adj.in_payroll, adj.in_tax, adj.visible,
				a_exchange_rate, current_date, v_amount);
		ELSIF (v_employee_month_id is not null) THEN
			UPDATE employee_adjustments SET amount = v_amount, exchange_rate = a_exchange_rate
			WHERE employee_adjustment_id = v_employee_adjustment_id;
		END IF;
	
		--- Employer contribution
		IF((rec.employer_ps > 0) OR (rec.employer_amount > 0) OR (rec.employer_formural = true))THEN
			SELECT employee_adjustment_id INTO v_employee_adjustment_id
			FROM employee_adjustments
			WHERE (employee_month_id = v_employee_month_id) AND (pension_id = rec.pension_id)
				AND (adjustment_id = rec.contribution_id);
			
			SELECT adjustment_id, currency_id, org_id, adjustment_name, adjustment_type, 
				adjustment_order, earning_code, formural, monthly_update, in_payroll, 
				in_tax, visible, running_balance, reduce_balance, tax_reduction_ps, 
				tax_relief_ps, tax_max_allowed, account_number
			INTO adj
			FROM adjustments
			WHERE (adjustment_id = rec.contribution_id);
			
			a_exchange_rate := 1;
			IF(v_currency_id <> adj.currency_id)THEN
				a_exchange_rate := 1 / v_exchange_rate;
			END IF;
			
			v_amount := 0;
			IF(rec.employer_formural = true) AND (adj.formural is not null) AND (v_employee_month_id is not null) THEN
				EXECUTE 'SELECT ' || adj.formural || ' FROM employee_month WHERE employee_month_id = ' || v_employee_month_id
				INTO v_amount;
				IF(v_currency_id <> adj.currency_id)THEN
					v_amount := v_amount * v_exchange_rate;
				END IF;
			ELSIF(rec.employer_ps > 0)THEN
				v_amount := v_amount * rec.employer_ps / 100;
			ELSIF(rec.employer_amount > 0)THEN
				v_amount := rec.employer_amount;
			END IF;
			
			IF(v_employee_adjustment_id is null) AND (v_employee_month_id is not null) AND (v_amount > 0) THEN
				INSERT INTO employee_adjustments(employee_month_id, pension_id, org_id, 
					adjustment_id, adjustment_type, adjustment_factor, 
					in_payroll, in_tax, visible,
					exchange_rate, pay_date, amount)
				VALUES (v_employee_month_id, rec.pension_id, v_org_id,
					adj.adjustment_id, adj.adjustment_type, 1, 
					adj.in_payroll, adj.in_tax, adj.visible,
					a_exchange_rate, current_date, v_amount);
			ELSIF (v_employee_month_id is not null) THEN
				UPDATE employee_adjustments SET amount = v_amount, exchange_rate = a_exchange_rate
				WHERE employee_adjustment_id = v_employee_adjustment_id;
			END IF;
		END IF;
		
	END LOOP;

	msg := 'Pension Processed';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON employee_advances
    FOR EACH ROW EXECUTE PROCEDURE upd_action();
    
    
CREATE OR REPLACE FUNCTION advance_aplication(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg 				varchar(120);
BEGIN
	msg := 'Advance applied';
	
	UPDATE employee_advances SET approve_status = 'Completed'
	WHERE (employee_advance_id = CAST($1 as int)) AND (approve_status = 'Draft');

	return msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ins_employee_advances() RETURNS trigger AS $$
DECLARE
	v_period_id			integer;
BEGIN

	IF(NEW.pay_upto is null)THEN
		NEW.pay_upto := current_date;
	END IF;
	IF(NEW.payment_amount is null)THEN
		NEW.payment_amount := NEW.amount;
		NEW.pay_period := 1;
	END IF;
	
	IF(TG_OP = 'UPDATE') AND (NEW.employee_month_id is null)THEN
		IF((NEW.approve_status = 'Approved') AND (OLD.approve_status = 'Completed'))THEN
			SELECT min(period_id) INTO v_period_id
			FROM periods
			WHERE (activated = true);
			
			SELECT max(employee_month_id) INTO NEW.employee_month_id
			FROM employee_month
			WHERE (period_id = v_period_id) AND (entity_id = NEW.entity_id);
			
			IF(v_period_id is null)THEN
				RAISE EXCEPTION 'You need to have the current active period';
			ELSIF(NEW.employee_month_id is null)THEN
				RAISE EXCEPTION 'You need to have the staff in the current active month';
			END IF;
		END IF;
	ELSIF(NEW.entity_id is null)THEN
		SELECT entity_id INTO NEW.entity_id
		FROM employee_month
		WHERE employee_month_id = NEW.employee_month_id;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_employee_advances BEFORE INSERT OR UPDATE ON employee_advances
    FOR EACH ROW EXECUTE PROCEDURE ins_employee_advances();

CREATE OR REPLACE FUNCTION adj_leave_update(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg		 				varchar(120);
BEGIN

	IF ($3 = '1') THEN
		UPDATE leave_types SET adjustment_id = null
		WHERE leave_type_id = CAST($1 as int);
		
		msg := 'Cleared the adjustment';
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ins_absent() RETURNS trigger AS $$
DECLARE
	v_period_id			integer;
	v_basic_pay			real;
BEGIN

	IF((NEW.deduct_payroll = true) AND (NEW.deduction_date is null))THEN
		RAISE EXCEPTION 'Indicate the date for the deduction';
	ELSIF((NEW.employee_month_id is null) AND (NEW.deduct_payroll = true))THEN
		SELECT max(period_id) INTO v_period_id
		FROM periods
		WHERE (opened = true) AND (closed = false) 
			AND (NEW.deduction_date BETWEEN start_date AND end_date);
		
		SELECT employee_month_id, basic_pay INTO NEW.employee_month_id, v_basic_pay
		FROM employee_month
		WHERE (period_id = v_period_id) AND (entity_id = NEW.entity_id);
		
		IF(NEW.amount = 0)THEN
			NEW.amount := v_basic_pay / 25;
		END IF;
		
		IF(v_period_id is null)THEN
			RAISE EXCEPTION 'You need to have the current active period';
		ELSIF(NEW.employee_month_id is null)THEN
			RAISE EXCEPTION 'You need to have the staff in the current active month';
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_absent BEFORE INSERT OR UPDATE ON absent
    FOR EACH ROW EXECUTE PROCEDURE ins_absent();
    
    
CREATE OR REPLACE FUNCTION accept_absent(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_is_accepted			boolean;
	msg		 				varchar(120);
BEGIN

	SELECT is_accepted INTO v_is_accepted
	FROM absent WHERE (absent_id = $1::int);
	
	IF(v_is_accepted = false)THEN
		UPDATE absent SET is_accepted = true, acceptance_date = current_timestamp
		WHERE (absent_id = $1::int);
		msg := 'Accepted absence';
	ELSE
		msg := 'Absence already accepted previously';
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;
