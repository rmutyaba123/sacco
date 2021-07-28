---Project Database File
CREATE TABLE loans (
	loan_id					serial primary key,
	entity_id 				integer references entitys,
	product_id	 			integer references products,
	activity_frequency_id	integer references activity_frequency,
	created_by 				integer references entitys,
	org_id					integer references orgs,

	account_number			varchar(32) not null unique,
	disburse_account		varchar(32) not null,
	principal_amount		real not null,
	interest_rate			real not null,
	repayment_amount		real not null,
	repayment_period		integer not null,

	disbursed_date			date,
	matured_date			date,
	expected_matured_date	date,
	expected_repayment		real,
	
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,	
	
	details					text
);
CREATE INDEX loans_entity_id ON loans(entity_id);
CREATE INDEX loans_product_id ON loans(product_id);
CREATE INDEX loans_activity_frequency_id ON loans(activity_frequency_id);
CREATE INDEX loans_created_by ON loans(created_by);
CREATE INDEX loans_org_id ON loans(org_id);

CREATE TABLE guarantees (
	guarantee_id			serial primary key,
	loan_id					integer references loans,
	entity_id 				integer references entitys,
	org_id					integer references orgs,
	
	guarantee_amount		real not null,
	guarantee_accepted		boolean default false not null,
	accepted_date			timestamp,
	
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,	
	
	details					text
);
CREATE INDEX guarantees_loan_id ON guarantees(loan_id);
CREATE INDEX guarantees_entity_id ON guarantees(entity_id);
CREATE INDEX guarantees_org_id ON guarantees(org_id);

CREATE TABLE collateral_types (
	collateral_type_id		serial primary key,
	org_id					integer references orgs,
	collateral_type_name	varchar(50) not null,
	details					text,
	UNIQUE(org_id, collateral_type_name)
);
CREATE INDEX collateral_types_org_id ON collateral_types(org_id);

CREATE TABLE collaterals (
	collateral_id			serial primary key,
	loan_id					integer references loans,
	collateral_type_id		integer references collateral_types,
	entity_id 				integer references entitys,
	org_id					integer references orgs,
	
	collateral_amount		real not null,
	collateral_received		boolean default false not null,
	collateral_released		boolean default false not null,
	
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,	
	
	details					text
);
CREATE INDEX collaterals_loan_id ON collaterals(loan_id);
CREATE INDEX collaterals_collateral_type_id ON collaterals(collateral_type_id);
CREATE INDEX collaterals_entity_id ON collaterals(entity_id);
CREATE INDEX collaterals_org_id ON collaterals(org_id);

CREATE TABLE loan_notes (
	loan_note_id			serial primary key,
	loan_id					integer references loans,
	org_id					integer references orgs,
	comment_date			timestamp default now() not null,
	narrative				varchar(320) not null,
	note					text not null
);
CREATE INDEX loan_notes_loan_id ON loan_notes(loan_id);
CREATE INDEX loan_notes_org_id ON loan_notes(org_id);

ALTER TABLE account_activity ADD loan_id integer references loans;
ALTER TABLE account_activity ADD transfer_loan_id integer references loans;
CREATE INDEX account_activity_loan_id ON account_activity(loan_id);
CREATE INDEX account_activity_transfer_loan_id ON account_activity(transfer_loan_id);


CREATE VIEW vw_loan_balance AS
	SELECT cb.loan_id, cb.loan_balance, COALESCE(ab.a_balance, 0) as actual_balance,
		COALESCE(li.l_intrest, 0) as loan_intrest, COALESCE(lp.l_penalty, 0) as loan_penalty
	FROM 
		(SELECT loan_id, sum((account_debit - account_credit) * exchange_rate) as loan_balance
			FROM account_activity GROUP BY loan_id) cb
	LEFT JOIN
		(SELECT loan_id, sum((account_debit - account_credit) * exchange_rate) as a_balance
			FROM account_activity WHERE activity_status_id < 3 GROUP BY loan_id) ab
		ON cb.loan_id = ab.loan_id
	LEFT JOIN
		(SELECT loan_id, sum((account_debit - account_credit) * exchange_rate) as l_intrest
			FROM account_activity INNER JOIN activity_types ON account_activity.activity_type_id = activity_types.activity_type_id
			WHERE (activity_types.use_key_id = 105) GROUP BY loan_id) li
		ON cb.loan_id = li.loan_id
	LEFT JOIN
		(SELECT loan_id, sum((account_debit - account_credit) * exchange_rate) as l_penalty
			FROM account_activity INNER JOIN activity_types ON account_activity.activity_type_id = activity_types.activity_type_id
			WHERE (activity_types.use_key_id = 106) GROUP BY loan_id) lp
		ON cb.loan_id = lp.loan_id;

CREATE VIEW vw_loans AS
	SELECT members.entity_id, members.member_name, members.member_type,
		vw_products.product_id, vw_products.product_name, 
		vw_products.currency_id, vw_products.currency_name, vw_products.currency_symbol,
		activity_frequency.activity_frequency_id, activity_frequency.activity_frequency_name, 
		loans.org_id, loans.loan_id, loans.account_number, loans.principal_amount, loans.interest_rate, 
		loans.repayment_amount, loans.disbursed_date, loans.expected_matured_date, loans.matured_date, 
		loans.repayment_period, loans.expected_repayment, loans.disburse_account,
		loans.application_date, loans.approve_status, loans.workflow_table_id, loans.action_date, loans.details,
		
		vw_loan_balance.loan_balance, vw_loan_balance.actual_balance, 
		(vw_loan_balance.actual_balance - vw_loan_balance.loan_balance) as committed_balance
	FROM loans INNER JOIN members ON loans.entity_id = members.entity_id
		INNER JOIN vw_products ON loans.product_id = vw_products.product_id
		INNER JOIN activity_frequency ON loans.activity_frequency_id = activity_frequency.activity_frequency_id
		LEFT JOIN vw_loan_balance ON loans.loan_id = vw_loan_balance.loan_id;
		
CREATE VIEW sv_loans AS
	SELECT orgs.org_id, orgs.org_name, aa.approved_loans, bb.pending_loans
	
	FROM orgs LEFT JOIN
		(SELECT org_id, count(loan_id) as approved_loans
			FROM vw_loans WHERE approve_status = 'Approved'
			GROUP BY org_id) as aa
		ON orgs.org_id = aa.org_id
	LEFT JOIN
		(SELECT org_id, count(loan_id) as pending_loans
			FROM vw_loans WHERE approve_status = 'Completed'
			GROUP BY org_id) as bb
		ON orgs.org_id = bb.org_id;
		
CREATE VIEW vw_guarantees AS
	SELECT vw_loans.entity_id, vw_loans.member_name, vw_loans.product_id, vw_loans.product_name, 
		vw_loans.loan_id, vw_loans.principal_amount, vw_loans.interest_rate, 
		vw_loans.activity_frequency_id, vw_loans.activity_frequency_name, 
		vw_loans.disbursed_date, vw_loans.expected_matured_date, vw_loans.matured_date, 
		members.entity_id as guarantor_id, members.member_name as guarantor_name, 
		guarantees.org_id, guarantees.guarantee_id, guarantees.guarantee_amount, guarantees.guarantee_accepted,
		guarantees.accepted_date, guarantees.application_date, 
		guarantees.approve_status, guarantees.workflow_table_id, guarantees.action_date, guarantees.details
	FROM guarantees INNER JOIN vw_loans ON guarantees.loan_id = vw_loans.loan_id
		INNER JOIN members ON guarantees.entity_id = members.entity_id;
		
CREATE VIEW vw_collaterals AS
	SELECT vw_loans.entity_id, vw_loans.member_name, vw_loans.product_id, vw_loans.product_name, 
		vw_loans.loan_id, vw_loans.principal_amount, vw_loans.interest_rate, 
		vw_loans.activity_frequency_id, vw_loans.activity_frequency_name, 
		vw_loans.disbursed_date, vw_loans.expected_matured_date, vw_loans.matured_date, 
		collateral_types.collateral_type_id, collateral_types.collateral_type_name,
		collaterals.org_id, collaterals.collateral_id, collaterals.collateral_amount, collaterals.collateral_received, 
		collaterals.collateral_released, collaterals.application_date, collaterals.approve_status, 
		collaterals.workflow_table_id, collaterals.action_date, collaterals.details
	FROM collaterals INNER JOIN vw_loans ON collaterals.loan_id = vw_loans.loan_id
		INNER JOIN collateral_types ON collaterals.collateral_type_id = collateral_types.collateral_type_id;
		
CREATE VIEW vw_loan_notes AS
	SELECT vw_loans.entity_id, vw_loans.member_name, vw_loans.product_id, vw_loans.product_name, 
		vw_loans.loan_id, vw_loans.principal_amount, vw_loans.interest_rate, 
		vw_loans.activity_frequency_id, vw_loans.activity_frequency_name, 
		vw_loans.disbursed_date, vw_loans.expected_matured_date, vw_loans.matured_date, 
		loan_notes.org_id, loan_notes.loan_note_id, loan_notes.comment_date, loan_notes.narrative, loan_notes.note
	FROM loan_notes INNER JOIN vw_loans ON loan_notes.loan_id = vw_loans.loan_id;
	
CREATE VIEW vw_loan_activity AS
	SELECT vw_loans.entity_id, vw_loans.member_name, vw_loans.member_type,
		vw_loans.product_id, vw_loans.product_name, 
		vw_loans.loan_id, vw_loans.principal_amount, vw_loans.interest_rate, 
		vw_loans.disbursed_date, vw_loans.expected_matured_date, vw_loans.matured_date, 
		
		vw_activity_types.activity_type_id, vw_activity_types.activity_type_name, 
		vw_activity_types.dr_account_id, vw_activity_types.dr_account_no, vw_activity_types.dr_account_name,
		vw_activity_types.cr_account_id, vw_activity_types.cr_account_no, vw_activity_types.cr_account_name,
		vw_activity_types.use_key_id, vw_activity_types.use_key_name,
		
		activity_frequency.activity_frequency_id, activity_frequency.activity_frequency_name, 
		activity_status.activity_status_id, activity_status.activity_status_name,
		currency.currency_id, currency.currency_name, currency.currency_symbol,
		
		account_activity.transfer_account_id, trnf_accounts.account_number as trnf_account_number,
		trnf_accounts.entity_id as trnf_entity_id, trnf_accounts.member_name as trnf_member_name,
		trnf_accounts.product_id as trnf_product_id,  trnf_accounts.product_name as trnf_product_name,
		
		vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.fiscal_year_id, vw_periods.fiscal_year,
		
		account_activity.org_id, account_activity.account_activity_id, account_activity.activity_date, 
		account_activity.value_date, account_activity.transfer_account_no,
		account_activity.account_credit, account_activity.account_debit, account_activity.balance, 
		account_activity.exchange_rate, account_activity.application_date, account_activity.approve_status, 
		account_activity.workflow_table_id, account_activity.action_date, account_activity.details,
		
		(account_activity.account_credit * account_activity.exchange_rate) as base_credit,
		(account_activity.account_debit * account_activity.exchange_rate) as base_debit
	FROM account_activity INNER JOIN vw_loans ON account_activity.loan_id = vw_loans.loan_id
		INNER JOIN vw_activity_types ON account_activity.activity_type_id = vw_activity_types.activity_type_id
		INNER JOIN activity_frequency ON account_activity.activity_frequency_id = activity_frequency.activity_frequency_id
		INNER JOIN activity_status ON account_activity.activity_status_id = activity_status.activity_status_id
		INNER JOIN currency ON account_activity.currency_id = currency.currency_id
		LEFT JOIN vw_periods ON account_activity.period_id = vw_periods.period_id
		LEFT JOIN vw_deposit_accounts trnf_accounts ON account_activity.transfer_account_id =  trnf_accounts.deposit_account_id;
    
------------Hooks to approval trigger
CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON loans
	FOR EACH ROW EXECUTE PROCEDURE upd_action();
	
CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON guarantees
	FOR EACH ROW EXECUTE PROCEDURE upd_action();
	
CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON collaterals
	FOR EACH ROW EXECUTE PROCEDURE upd_action();
