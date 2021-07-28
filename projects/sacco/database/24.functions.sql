---Project Database Functions File
---after member insert trigger to create login credentials
CREATE OR REPLACE FUNCTION aft_members() RETURNS trigger AS $$
DECLARE
	v_entity_type_id		integer;
	v_entity_id				integer;
	v_user_name				varchar(32);
BEGIN

	IF((TG_OP = 'INSERT') AND (NEW.business_account = 0))THEN
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 100);
		v_entity_id := nextval('entitys_entity_id_seq');
		v_user_name := 'OR' || NEW.org_id || 'EN' || v_entity_id;
		
		INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, member_id, entity_name, user_name, primary_email, primary_telephone, function_role)
		VALUES (v_entity_id, NEW.org_id, 100, v_entity_type_id, NEW.member_id, NEW.member_name, v_user_name, lower(trim(NEW.member_email)), NEW.telephone_number, 'member');

		INSERT INTO sys_emailed (org_id, sys_email_id, table_id, table_name, email_type)
			SELECT org_id, sys_email_id, NEW.entity_id, 'entitys', 1
			FROM sys_emails
			WHERE (use_type = 2) AND (org_id = NEW.org_id);

	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_members AFTER INSERT OR UPDATE ON members
	FOR EACH ROW EXECUTE PROCEDURE aft_members();
	
---Function to get member id	
CREATE OR REPLACE FUNCTION get_member_id(integer) RETURNS integer AS $$
	SELECT member_id FROM entitys WHERE (entity_id = $1);
$$ LANGUAGE SQL;

----insert deposit accounts triggger
CREATE OR REPLACE FUNCTION ins_deposit_accounts() RETURNS trigger AS $$
DECLARE
	v_fee_amount		real;
	v_fee_ps			real;
	myrec				RECORD;
BEGIN
	--- On new insert
	IF(TG_OP = 'INSERT')THEN
		SELECT interest_rate, activity_frequency_id, min_opening_balance, lockin_period_frequency,
			minimum_balance, maximum_balance INTO myrec
		FROM products WHERE product_id = NEW.product_id;
		
		IF(NEW.member_id is null)THEN
			SELECT member_id INTO NEW.member_id
			FROM entitys WHERE (entity_id = NEW.entity_id);
		END IF;
		
		--- Creating account number for the member product
		NEW.account_number := '4' || lpad(NEW.org_id::varchar, 2, '0')  || lpad(NEW.member_id::varchar, 4, '0') || lpad(NEW.deposit_account_id::varchar, 2, '0');
		
		IF(NEW.minimum_balance is null) THEN NEW.minimum_balance := myrec.minimum_balance; END IF;
		IF(NEW.maximum_balance is null) THEN NEW.maximum_balance := myrec.maximum_balance; END IF;
		IF(NEW.interest_rate is null) THEN NEW.interest_rate := myrec.interest_rate; END IF;
		
		NEW.activity_frequency_id := myrec.activity_frequency_id;
		NEW.lockin_period_frequency := myrec.lockin_period_frequency;
	ELSE
		IF(NEW.approve_status = 'Approved')THEN
			--- when an account is approved it checks any associated charges effective to that account
			INSERT INTO account_activity (deposit_account_id, activity_type_id, activity_frequency_id,
				activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
				activity_date, value_date, account_debit)
			SELECT NEW.deposit_account_id, account_definations.activity_type_id, account_definations.activity_frequency_id,
				1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
				NEW.opening_date, NEW.opening_date, account_definations.fee_amount
			FROM account_definations INNER JOIN activity_types ON account_definations.activity_type_id = activity_types.activity_type_id
				INNER JOIN products ON account_definations.product_id = products.product_id
			WHERE (account_definations.product_id = NEW.product_id) AND (account_definations.org_id = NEW.org_id)
				AND (account_definations.activity_frequency_id = 1) AND (activity_types.use_key_id = 201) 
				AND (account_definations.is_active = true)
				AND (account_definations.start_date < NEW.opening_date);
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_deposit_accounts BEFORE INSERT OR UPDATE ON deposit_accounts
	FOR EACH ROW EXECUTE PROCEDURE ins_deposit_accounts();
	
CREATE OR REPLACE FUNCTION ins_transfer_beneficiary() RETURNS trigger AS $$
DECLARE
	v_member_id			integer;
BEGIN

	SELECT member_id INTO NEW.member_id
	FROM entitys WHERE (entity_id = NEW.entity_id);
	
	SELECT deposit_account_id, member_id INTO NEW.deposit_account_id, v_member_id
	FROM deposit_accounts
	WHERE (is_active = true) AND (approve_status = 'Approved')
		AND (account_number = NEW.account_number);
		
	IF(NEW.deposit_account_id is null)THEN
		RAISE EXCEPTION 'The account needs to exist and be active';
	ELSIF(NEW.member_id = v_member_id)THEN
		RAISE EXCEPTION 'You cannot add your own account as a beneficiary account';
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		NEW.approve_status = 'Completed';
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_transfer_beneficiary BEFORE INSERT OR UPDATE ON transfer_beneficiary
	FOR EACH ROW EXECUTE PROCEDURE ins_transfer_beneficiary();

--- Insert account activity trigger
CREATE OR REPLACE FUNCTION ins_account_activity() RETURNS trigger AS $$
DECLARE
	v_deposit_account_id		integer;
	v_period_id					integer;
	v_loan_id					integer;
	v_activity_type_id			integer;
	v_use_key_id				integer;
	v_minimum_balance			real;
	v_account_transfer			varchar(32);
BEGIN

	IF((NEW.account_credit = 0) AND (NEW.account_debit = 0))THEN
		RAISE EXCEPTION 'You must enter a debit or credit amount';
	ELSIF((NEW.account_credit < 0) OR (NEW.account_debit < 0))THEN
		RAISE EXCEPTION 'The amounts must be positive';
	ELSIF((NEW.account_credit > 0) AND (NEW.account_debit > 0))THEN
		RAISE EXCEPTION 'Both debit and credit cannot not have an amount at the same time';
	END IF;
	--- Getting opened and active periods 
	SELECT periods.period_id INTO NEW.period_id
	FROM periods
	WHERE (opened = true) AND (activated = true) AND (closed = false)
		AND (start_date <= NEW.activity_date) AND (end_date >= NEW.activity_date)
		AND (org_id = NEW.org_id);
	IF(NEW.period_id is null)THEN
		RAISE EXCEPTION 'The transaction needs to be in an open and active period';
	END IF;
	
	IF(NEW.link_activity_id is null)THEN
		NEW.link_activity_id := nextval('link_activity_id_seq');
	END IF;
	
	IF(NEW.transfer_link_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM deposit_accounts WHERE (deposit_account_id = NEW.transfer_link_id);
		NEW.activity_date := current_date;
		NEW.value_date := current_date;
		NEW.exchange_rate := 1;
		IF(NEW.transfer_account_no is null)THEN
			RAISE EXCEPTION 'Enter the correct transfer account';
		END IF;
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		IF(NEW.deposit_account_id is not null)THEN
			SELECT sum(account_credit - account_debit) INTO NEW.balance
			FROM account_activity
			WHERE (account_activity_id < NEW.account_activity_id)
				AND (deposit_account_id = NEW.deposit_account_id);
		END IF;
		IF(NEW.loan_id is not null)THEN
			SELECT sum(account_credit - account_debit) INTO NEW.balance
			FROM account_activity
			WHERE (account_activity_id < NEW.account_activity_id)
				AND (loan_id = NEW.loan_id);
		END IF;
		IF(NEW.balance is null)THEN
			NEW.balance := 0;
		END IF;
		NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);
		
		SELECT use_key_id INTO v_use_key_id
		FROM activity_types WHERE (activity_type_id = NEW.activity_type_id);
		
		IF(v_use_key_id IN (102, 104, 107))THEN
			SELECT COALESCE(minimum_balance, 0) INTO v_minimum_balance
			FROM deposit_accounts WHERE deposit_account_id = NEW.deposit_account_id;
			
			IF((NEW.balance < v_minimum_balance) AND (NEW.activity_status_id = 1))THEN
					RAISE EXCEPTION 'You cannot withdraw below allowed minimum balance';
			END IF;
		END IF;
	END IF;
	
	IF((NEW.transfer_account_no is null) AND (NEW.transfer_account_id is null) AND (NEW.transfer_loan_id is null))THEN
		SELECT vw_account_definations.account_number INTO NEW.transfer_account_no
		FROM vw_account_definations INNER JOIN deposit_accounts ON vw_account_definations.product_id = deposit_accounts.product_id
		WHERE (deposit_accounts.deposit_account_id = NEW.deposit_account_id) 
			AND (vw_account_definations.activity_type_id = NEW.activity_type_id) 
			AND (vw_account_definations.use_key_id IN (101, 102));
	END IF;
	
	IF(NEW.transfer_account_no is not null)THEN
		SELECT deposit_account_id INTO v_deposit_account_id
		FROM deposit_accounts WHERE (account_number = NEW.transfer_account_no);
		
		IF(v_deposit_account_id is null)THEN
			SELECT loan_id INTO v_loan_id
			FROM loans WHERE (account_number = NEW.transfer_account_no);
		END IF;
		
		IF((v_deposit_account_id is null) AND (v_loan_id is null))THEN
			RAISE EXCEPTION 'Enter a valid account to do transfer';
		ELSIF((v_deposit_account_id is not null) AND (NEW.deposit_account_id = v_deposit_account_id))THEN
			RAISE EXCEPTION 'You cannot do a transfer on same account';
		ELSIF((v_loan_id is not null) AND (NEW.loan_id = v_loan_id))THEN
			RAISE EXCEPTION 'You cannot do a transfer on same account';
		ELSIF(v_deposit_account_id is not null)THEN
			NEW.transfer_account_id := v_deposit_account_id;
		ELSIF(v_loan_id is not null)THEN
			NEW.transfer_loan_id := v_loan_id;
		END IF;

	ELSIF(NEW.transfer_account_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM deposit_accounts WHERE (deposit_account_id = NEW.transfer_account_id);

	ELSIF(NEW.transfer_loan_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM loans WHERE (loan_id = NEW.transfer_loan_id);
	END IF;
			
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_account_activity BEFORE INSERT ON account_activity
	FOR EACH ROW EXECUTE PROCEDURE ins_account_activity();

CREATE OR REPLACE FUNCTION aft_account_activity() RETURNS trigger AS $$
DECLARE
	reca 						RECORD;
	v_account_activity_id		integer;
	v_product_id				integer;
	v_use_key_id				integer;
	v_actual_balance			real;
	v_total_debits				real;
BEGIN

	IF(NEW.deposit_account_id is not null) THEN
		SELECT product_id INTO v_product_id
		FROM deposit_accounts WHERE deposit_account_id = NEW.deposit_account_id;
	END IF;
	IF(NEW.loan_id is not null) THEN 
		SELECT product_id INTO v_product_id
		FROM loans WHERE loan_id = NEW.loan_id;
	END IF;
	
	--- Generate the countra entry for a transfer
	IF(NEW.transfer_account_id is not null)THEN
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (deposit_account_id = NEW.transfer_account_id)
			AND (link_activity_id = NEW.link_activity_id);
			
		IF(v_account_activity_id is null)THEN
			INSERT INTO account_activity (deposit_account_id, transfer_account_id, transfer_loan_id, activity_type_id,
				currency_id, org_id, entity_id, link_activity_id, activity_date, value_date,
				activity_status_id, account_credit, account_debit, activity_frequency_id)
			VALUES (NEW.transfer_account_id, NEW.deposit_account_id, NEW.loan_id, NEW.activity_type_id,
				NEW.currency_id, NEW.org_id, NEW.entity_id, NEW.link_activity_id, NEW.activity_date, NEW.value_date,
				NEW.activity_status_id, NEW.account_debit, NEW.account_credit, 1);
		END IF;
	END IF;
	
	--- Generate the countra entry for a loan
	IF(NEW.transfer_loan_id is not null)THEN
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (loan_id = NEW.transfer_loan_id)
			AND (link_activity_id = NEW.link_activity_id);
			
		IF(v_account_activity_id is null)THEN
			INSERT INTO account_activity (loan_id, transfer_account_id, transfer_loan_id, activity_type_id,
				currency_id, org_id, entity_id, link_activity_id, activity_date, value_date,
				activity_status_id, account_credit, account_debit, activity_frequency_id)
			VALUES (NEW.transfer_loan_id, NEW.deposit_account_id, NEW.loan_id, NEW.activity_type_id,
				NEW.currency_id, NEW.org_id, NEW.entity_id, NEW.link_activity_id, NEW.activity_date, NEW.value_date,
				NEW.activity_status_id, NEW.account_debit, NEW.account_credit, 1);
		END IF;
	END IF;

	--- Posting the charge on the transfer transaction
	SELECT use_key_id INTO v_use_key_id
	FROM activity_types
	WHERE (activity_type_id = NEW.activity_type_id);
	IF((v_use_key_id < 200) AND (NEW.account_debit > 0))THEN
		INSERT INTO account_activity (deposit_account_id, activity_type_id, activity_frequency_id,
			activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
			link_activity_id, activity_date, value_date, account_debit)
		SELECT NEW.deposit_account_id, account_definations.charge_activity_id, account_definations.activity_frequency_id,
			1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
			NEW.link_activity_id, current_date, current_date, 
			(account_definations.fee_amount + account_definations.fee_ps * NEW.account_debit / 100)
			
		FROM account_definations INNER JOIN products ON account_definations.product_id = products.product_id
		WHERE (account_definations.product_id = v_product_id)
			AND (account_definations.activity_frequency_id = 1) 
			AND (account_definations.activity_type_id = NEW.activity_type_id) 
			AND (account_definations.is_active = true) AND (account_definations.has_charge = true)
			AND (account_definations.start_date < current_date);
	END IF;
	
	--- compute for Commited amounts taking the date into consideration
	IF((NEW.account_credit > 0) AND (NEW.activity_status_id = 1))THEN
		SELECT sum((account_credit - account_debit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id < 3) AND (value_date <= NEW.value_date);
		IF(v_actual_balance is null)THEN v_actual_balance := 0; END IF;
		SELECT sum(account_debit * exchange_rate) INTO v_total_debits
		FROM account_activity 
		WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id = 3) AND (value_date <= NEW.value_date);
		IF(v_total_debits is null)THEN v_total_debits := 0; END IF;
		v_actual_balance := v_actual_balance - v_total_debits;
			
		FOR reca IN SELECT account_activity_id, activity_status_id, link_activity_id, 
				(account_debit * exchange_rate) as debit_amount
			FROM account_activity 
			WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id = 4) AND (activity_date <= NEW.value_date)
				AND (account_credit = 0) AND (account_debit > 0)
			ORDER BY activity_date, account_activity_id
		LOOP
			IF(v_actual_balance > reca.debit_amount)THEN
				UPDATE account_activity SET activity_status_id = 1 WHERE link_activity_id = reca.link_activity_id;
				v_actual_balance := v_actual_balance - reca.debit_amount;
			END IF;
		END LOOP;
	END IF;
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_account_activity AFTER INSERT ON account_activity
	FOR EACH ROW EXECUTE PROCEDURE aft_account_activity();

CREATE OR REPLACE FUNCTION log_account_activity() RETURNS trigger AS $$
BEGIN

	INSERT INTO account_activity_log(account_activity_id, deposit_account_id, 
		transfer_account_id, activity_type_id, activity_frequency_id, 
		activity_status_id, currency_id, period_id, entity_id,
		loan_id, transfer_loan_id, org_id, link_activity_id, deposit_account_no, 
		transfer_link_id, transfer_account_no, activity_date, value_date, account_credit, 
		account_debit, balance, exchange_rate, application_date, approve_status, 
		workflow_table_id, action_date, details)
    VALUES (NEW.account_activity_id, NEW.deposit_account_id, 
		NEW.transfer_account_id, NEW.activity_type_id, NEW.activity_frequency_id, 
		NEW.activity_status_id, NEW.currency_id, NEW.period_id, NEW.entity_id,
		NEW.loan_id, NEW.transfer_loan_id, NEW.org_id, NEW.link_activity_id, NEW.deposit_account_no, 
		NEW.transfer_link_id, NEW.transfer_account_no, NEW.activity_date, NEW.value_date, NEW.account_credit, 
		NEW.account_debit, NEW.balance, NEW.exchange_rate, NEW.application_date, NEW.approve_status, 
		NEW.workflow_table_id, NEW.action_date, NEW.details);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_account_activity AFTER INSERT OR UPDATE ON account_activity
	FOR EACH ROW EXECUTE PROCEDURE log_account_activity();
	
CREATE OR REPLACE FUNCTION apply_approval(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg							varchar(120);
	v_deposit_account_id		integer;
	v_principal_amount			real;
	v_repayment_amount			real;
	v_maximum_repayments		integer;
	v_repayment_period			integer;
BEGIN

	IF($3 = '1')THEN
		UPDATE members SET approve_status = 'Completed' 
		WHERE (member_id = $1::integer) AND (approve_status = 'Draft');

		msg := 'Applied for member approval';
	ELSIF($3 = '2')THEN
		UPDATE deposit_accounts SET approve_status = 'Completed' 
		WHERE (deposit_account_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for account approval';
	ELSIF($3 = '3')THEN
		SELECT deposit_accounts.deposit_account_id, loans.principal_amount, loans.repayment_amount,
				loans.repayment_period, products.maximum_repayments
			INTO v_deposit_account_id, v_principal_amount, v_repayment_amount, v_repayment_period, v_maximum_repayments
		FROM deposit_accounts INNER JOIN loans ON (deposit_accounts.account_number = loans.disburse_account)
			INNER JOIN products ON loans.product_id = products.product_id
			AND (deposit_accounts.member_id = loans.member_id) AND (loans.loan_id = $1::integer)
			AND (deposit_accounts.approve_status = 'Approved');
		
		IF(v_deposit_account_id is null)THEN
			msg := 'The disburse account needs to be active and owned by the Member';
			RAISE EXCEPTION '%', msg;
		ELSIF(v_repayment_period > v_maximum_repayments)THEN
			msg := 'The repayment periods are more than what is prescribed by the product';
			RAISE EXCEPTION '%', msg;
		ELSE
			UPDATE loans SET approve_status = 'Completed' 
			WHERE (loan_id = $1::integer) AND (approve_status = 'Draft');
			
			msg := 'Applied for loan approval';
		END IF;
	ELSIF($3 = '4')THEN
		UPDATE guarantees SET approve_status = 'Completed' 
		WHERE (guarantee_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for guarantees approval';
	ELSIF($3 = '5')THEN
		UPDATE collaterals SET approve_status = 'Completed' 
		WHERE (collateral_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for collateral approval';
	ELSIF($3 = '7')THEN
		UPDATE transfer_beneficiary SET approve_status = 'Approved' 
		WHERE (transfer_beneficiary_id = $1::integer) AND (approve_status = 'Completed');
		
		msg := 'Applied for beneficiary application submited';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_approval(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg							varchar(120);
	v_account_activity_id		integer;
BEGIN

	IF($3 = '1')THEN
		v_account_activity_id := nextval('account_activity_account_activity_id_seq');
		INSERT INTO account_activity (account_activity_id, org_id, entity_id, activity_frequency_id, activity_type_id, 
			activity_status_id, currency_id, transfer_account_no, deposit_account_id,
			activity_date, value_date, account_debit, exchange_rate)
		SELECT v_account_activity_id, org_id, entity_id, activity_frequency_id, activity_type_id, 
			1, currency_id, beneficiary_account_number, deposit_account_id,
			current_date, current_date, transfer_amount, 1
		FROM vw_transfer_activity
		WHERE (transfer_activity_id = $1::integer);
		
		UPDATE transfer_activity SET approve_status = 'Approved', account_activity_id = v_account_activity_id
		WHERE (transfer_activity_id = $1::integer);
		
		msg := 'Approved transfer';
	ELSIF($3 = '2')THEN
		UPDATE transfer_activity SET approve_status = 'Declined' 
		WHERE (transfer_activity_id = $1::integer);
		
		msg := 'Reject transfer';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

--- ========Loans trigger on insert..=====
CREATE OR REPLACE FUNCTION ins_loans() RETURNS trigger AS $$
DECLARE
	myrec					RECORD;
	v_activity_type_id		integer;
	v_repayments			integer;
	v_currency_id			integer;
	v_reducing_balance		boolean;
	v_reducing_payments		boolean;
	v_nir					real;
BEGIN

	IF(NEW.repayment_period < 1)THEN
		RAISE EXCEPTION 'The repayment period has to be greater than 1 or 1';
	ELSIF(NEW.principal_amount < 1)THEN
		RAISE EXCEPTION 'The principal amount has to be greater than 1';
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		SELECT interest_rate, activity_frequency_id, min_opening_balance, lockin_period_frequency,
			minimum_balance, maximum_balance INTO myrec
		FROM products WHERE product_id = NEW.product_id;
		
		IF(NEW.member_id is null)THEN
			SELECT member_id INTO NEW.member_id
			FROM entitys WHERE (entity_id = NEW.entity_id);
		END IF;
	
		NEW.account_number := '5' || lpad(NEW.org_id::varchar, 2, '0')  || lpad(NEW.member_id::varchar, 4, '0') || lpad(NEW.loan_id::varchar, 2, '0');
			
		NEW.interest_rate := myrec.interest_rate;
		NEW.activity_frequency_id := myrec.activity_frequency_id;
	ELSIF((NEW.approve_status = 'Approved') AND (OLD.approve_status <> 'Approved'))THEN
		----- Loan disbursement
		SELECT activity_type_id INTO v_activity_type_id
		FROM vw_account_definations 
		WHERE (use_key_id = 108) AND (is_active = true) AND (product_id = NEW.product_id);
		
		SELECT currency_id INTO v_currency_id
		FROM products
		WHERE (product_id = NEW.product_id);

		--- Charge the loan processing fee
		INSERT INTO account_activity (loan_id, activity_type_id, activity_frequency_id,
			activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
			activity_date, value_date, account_debit)
		SELECT NEW.loan_id, account_definations.activity_type_id, account_definations.activity_frequency_id,
			1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
			current_date, current_date, account_definations.fee_amount
		FROM account_definations INNER JOIN activity_types ON account_definations.activity_type_id = activity_types.activity_type_id
			INNER JOIN products ON account_definations.product_id = products.product_id
		WHERE (account_definations.product_id = NEW.product_id) AND (account_definations.org_id = NEW.org_id)
			AND (account_definations.activity_frequency_id = 1) AND (activity_types.use_key_id = 204) 
			AND (account_definations.is_active = true);

		--- Update the loan status
		UPDATE loans SET loan_status = 'Active' WHERE loan_id = NEW.loan_id;
		
		IF(v_activity_type_id is not null)THEN
			INSERT INTO account_activity (loan_id, transfer_account_no, org_id, activity_type_id, currency_id, 
				activity_frequency_id, activity_date, value_date, activity_status_id, account_credit, account_debit)
			VALUES (NEW.loan_id, NEW.disburse_account, NEW.org_id, v_activity_type_id, v_currency_id, 
				1, current_date, current_date, 1, 0, NEW.principal_amount);
		
			NEW.disbursed_date := current_date;
			NEW.expected_matured_date := current_date + (NEW.repayment_period || ' months')::interval;
		END IF;

	END IF;
	
	---- Calculate for repayment
	IF(NEW.approve_status <> 'Approved')THEN
		SELECT interest_methods.reducing_balance, interest_methods.reducing_payments INTO v_reducing_balance, v_reducing_payments
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = NEW.product_id);
		IF(v_reducing_balance = true)THEN
			v_nir := NEW.interest_rate / 1200;
			IF(v_reducing_payments = true)THEN
				NEW.repayment_amount := NEW.principal_amount / NEW.repayment_period;
				NEW.expected_repayment := NEW.principal_amount * NEW.repayment_period * v_nir;
				NEW.expected_repayment := NEW.expected_repayment - (NEW.repayment_period * (NEW.repayment_period - 1) * NEW.repayment_amount * v_nir / 2);
				NEW.expected_repayment := NEW.expected_repayment + NEW.principal_amount;
			ELSE
				NEW.repayment_amount := (v_nir * NEW.principal_amount) / (1 - ((1 + v_nir) ^ (-NEW.repayment_period)));
				NEW.expected_repayment := NEW.repayment_amount * NEW.repayment_period;
			END IF;
			
			RAISE NOTICE 'Month Intrest % ', v_nir;
			RAISE NOTICE 'Expected % ', NEW.expected_repayment;
		ELSE
			NEW.expected_repayment := NEW.principal_amount * ((1.0 + (NEW.interest_rate / 100)) ^ (NEW.repayment_period::real / 12));
			NEW.repayment_amount := NEW.expected_repayment / NEW.repayment_period;
			
			RAISE NOTICE 'repayment period % ', NEW.repayment_period;
			RAISE NOTICE 'repayment annual % ', (NEW.repayment_period::real / 12);
			RAISE NOTICE 'Intrest Rate % ', (1.0 + (NEW.interest_rate / 100));
			RAISE NOTICE 'repayment rate % ', ((1.0 + (NEW.interest_rate / 100)) ^ (NEW.repayment_period::real / 12));
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_loans BEFORE INSERT OR UPDATE ON loans
	FOR EACH ROW EXECUTE PROCEDURE ins_loans();
	
CREATE OR REPLACE FUNCTION compute_loans(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	reca 						RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_start_date				date;
	v_end_date					date;
	v_account_activity_id		integer;
	v_penalty_formural			varchar(320);
	v_penalty_account			varchar(32);
	v_penalty_amount			real;
	v_activity_type_id			integer;
	v_reducing_payments			boolean;
	v_interest_formural			varchar(320);
	v_interest_account			varchar(32);
	v_interest_amount			real;
	v_repayment_amount			real;
	v_available_balance			real;
	v_activity_status_id		integer;
	msg							varchar(120);
BEGIN

	SELECT period_id, org_id, start_date, end_date
		INTO v_period_id, v_org_id, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = true) AND (closed = false);

	FOR reca IN SELECT currency_id, loan_id, member_id, product_id, activity_frequency_id,
			account_number, disburse_account, principal_amount, interest_rate,
			repayment_period, repayment_amount, disbursed_date, actual_balance
		FROM vw_loans
		WHERE (org_id = v_org_id) AND (approve_status = 'Approved') AND (actual_balance > 0) AND (disbursed_date < v_start_date)
	LOOP
	
		---- Compute for penalty
		v_repayment_amount := 0;
		v_account_activity_id := null;
		v_penalty_amount := 0;
		SELECT penalty_methods.activity_type_id, penalty_methods.formural, penalty_methods.account_number 
			INTO v_activity_type_id, v_penalty_formural, v_penalty_account
		FROM penalty_methods INNER JOIN products ON penalty_methods.penalty_method_id = products.penalty_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_penalty_formural is not null)THEN
			v_penalty_formural := replace(v_penalty_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_penalty_formural || ' FROM loans WHERE loan_id = ' || reca.loan_id 
			INTO v_penalty_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		END IF;
		IF((v_penalty_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, v_penalty_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_penalty_amount);
			v_repayment_amount := v_penalty_amount;
		END IF;
	
		---- Compute for intrest
		v_account_activity_id := null;
		v_interest_amount := 0;
		SELECT interest_methods.activity_type_id, interest_methods.formural, interest_methods.account_number, interest_methods.reducing_payments
			INTO v_activity_type_id, v_interest_formural, v_interest_account, v_reducing_payments
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_interest_formural is not null)THEN
			v_interest_formural := replace(v_interest_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_interest_formural || ' FROM loans WHERE loan_id = ' || reca.loan_id 
			INTO v_interest_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		END IF;
		IF((v_interest_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_interest_amount);
			IF(v_reducing_payments = true)THEN
				v_repayment_amount := v_repayment_amount + v_interest_amount;
			END IF;
		END IF;
		
		--- Computer for repayment
		v_account_activity_id := null;
		SELECT activity_type_id INTO v_activity_type_id
		FROM vw_account_definations 
		WHERE (product_id = reca.product_id) AND (use_key_id = 107);
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		IF((v_account_activity_id is null) AND (v_activity_type_id is not null))THEN
			v_repayment_amount := v_repayment_amount + reca.repayment_amount;
			v_activity_status_id := 1;
			
			SELECT available_balance INTO v_available_balance
			FROM vw_deposit_accounts
			WHERE (account_number = reca.disburse_account);
			IF(v_available_balance < v_repayment_amount)THEN v_activity_status_id := 4; END IF;
			
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, reca.disburse_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, v_activity_status_id, v_repayment_amount, 0);
		END IF;
	END LOOP;

	msg := 'loans computed';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION compute_savings(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	reca 						RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_start_date				date;
	v_end_date					date;
	v_account_activity_id		integer;
	v_penalty_formural			varchar(320);
	v_penalty_account			varchar(32);
	v_penalty_amount			real;
	v_activity_type_id			integer;
	v_reducing_balance			boolean;
	v_interest_formural			varchar(320);
	v_interest_account			varchar(32);
	v_interest_amount			real;
	msg							varchar(120);
BEGIN

	SELECT period_id, org_id, start_date, end_date
		INTO v_period_id, v_org_id, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = true) AND (closed = false);

	FOR reca IN SELECT currency_id, deposit_account_id, product_id, activity_frequency_id, credit_limit,
		minimum_balance, maximum_balance, interest_rate, lockin_period_frequency, lockedin_until_date
	FROM vw_deposit_accounts
	WHERE (org_id = v_org_id) AND (approve_status = 'Approved') AND (is_active = true) AND (action_date < v_start_date)
	LOOP

		---- Compute for penalty
		v_account_activity_id := null;
		v_penalty_amount := 0;
		SELECT penalty_methods.activity_type_id, penalty_methods.formural, penalty_methods.account_number 
			INTO v_activity_type_id, v_penalty_formural, v_penalty_account
		FROM penalty_methods INNER JOIN products ON penalty_methods.penalty_method_id = products.penalty_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_penalty_formural is not null)THEN
			v_penalty_formural := replace(v_penalty_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_penalty_formural || ' FROM deposit_accounts WHERE deposit_account_id = ' || reca.deposit_account_id 
			INTO v_penalty_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (deposit_account_id = reca.deposit_account_id);
		END IF;
		IF((v_penalty_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, deposit_account_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.deposit_account_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_penalty_amount);
		END IF;
	
		---- Compute for intrest
		v_account_activity_id := null;
		v_interest_amount := 0;
		SELECT interest_methods.activity_type_id, interest_methods.formural, interest_methods.account_number, interest_methods.reducing_balance
			INTO v_activity_type_id, v_interest_formural, v_interest_account, v_reducing_balance
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_interest_formural is not null)THEN
			v_interest_formural := replace(v_interest_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_interest_formural || ' FROM deposit_accounts WHERE deposit_account_id = ' || reca.deposit_account_id 
			INTO v_interest_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (deposit_account_id = reca.deposit_account_id);
		END IF;
		IF((v_interest_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, deposit_account_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.deposit_account_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, v_interest_amount, 0);
		END IF;
	END LOOP;

	msg := 'Savings computed';

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_intrest(integer, integer, integer) RETURNS real AS $$
DECLARE
	v_principal_amount 			real;
	v_interest_rate				real;
	v_actual_balance			real;
	v_total_debits				real;
	v_start_date				date;
	v_end_date					date;
	ans							real;
BEGIN
	
	SELECT start_date, end_date INTO v_start_date, v_end_date
	FROM periods WHERE (period_id = $3::integer);

	IF($1 = 1)THEN
		SELECT interest_rate INTO v_interest_rate
		FROM loans  WHERE (loan_id = $2);

		SELECT sum((account_debit - account_credit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (loan_id = $2) AND (activity_status_id < 2) AND (value_date <= v_end_date);

		ans := v_actual_balance * v_interest_rate / 1200;
	ELSIF($1 = 2)THEN
		SELECT principal_amount, interest_rate INTO v_principal_amount, v_interest_rate
		FROM vw_loans 
		WHERE (loan_id = $2);
		
		ans := v_principal_amount * v_interest_rate / 1200;
	ELSIF($1 = 3)THEN
		SELECT interest_rate INTO v_interest_rate
		FROM deposit_accounts  WHERE (deposit_account_id = $2);
		
		SELECT sum((account_credit - account_debit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (deposit_account_id = $2) AND (activity_status_id < 2) AND (value_date < v_start_date);
		IF(v_actual_balance is null)THEN v_actual_balance := 0; END IF;
		SELECT sum(account_debit * exchange_rate) INTO v_total_debits
		FROM account_activity 
		WHERE (deposit_account_id = $2) AND (activity_status_id < 2) AND (value_date BETWEEN v_start_date AND v_end_date);
		IF(v_total_debits is null)THEN v_total_debits := 0; END IF;
	
		ans := (v_actual_balance - v_total_debits) * v_interest_rate / 1200;
	END IF;

	RETURN ans;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_penalty(integer, integer, integer, real) RETURNS real AS $$
DECLARE
	v_actual_default			real;
	v_start_date				date;
	v_end_date					date;
	ans							real;
BEGIN

	SELECT start_date, end_date INTO v_start_date, v_end_date
	FROM periods WHERE (period_id = $3::integer);

	IF($1 = 1)THEN
		SELECT sum(account_credit * exchange_rate) INTO v_actual_default
		FROM account_activity 
		WHERE (loan_id = $2) AND (activity_status_id = 4) AND (value_date < v_start_date);
		
		ans := v_actual_default * $3 / 1200;
	END IF;

	RETURN ans;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION post_sacco(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	reca 						RECORD;
	v_journal_id				integer;
	v_org_id					integer;
	v_currency_id				integer;
	v_period_id					integer;
	v_start_date				date;
	v_end_date					date;

	msg							varchar(120);
BEGIN

	SELECT orgs.org_id, orgs.currency_id, periods.period_id, periods.start_date, periods.end_date
		INTO v_org_id, v_currency_id, v_period_id, v_start_date, v_end_date
	FROM periods INNER JOIN orgs ON periods.org_id = orgs.org_id
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = false) AND (closed = false);
	
	IF(v_period_id is null)THEN
		msg := 'Sacco not posted period need to be open but not active';
	ELSE
		UPDATE account_activity SET period_id = v_period_id 
		WHERE (period_id is null) AND (activity_date BETWEEN v_start_date AND v_end_date);
		
		v_journal_id := nextval('journals_journal_id_seq');
		INSERT INTO journals (journal_id, org_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (v_journal_id, v_org_id, v_currency_id, v_period_id, 1, v_end_date, 'Sacco - ' || to_char(v_start_date, 'MMYYY'));
		
		INSERT INTO gls(org_id, journal_id, account_activity_id, account_id, 
			debit, credit, gl_narrative)
		SELECT v_org_id, v_journal_id, account_activity.account_activity_id, activity_types.account_id,
			(account_activity.account_debit * account_activity.exchange_rate),
			(account_activity.account_credit * account_activity.exchange_rate),
			COALESCE(deposit_accounts.account_number, loans.account_number)
		FROM account_activity INNER JOIN activity_types ON account_activity.activity_type_id = activity_types.activity_type_id
			LEFT JOIN deposit_accounts ON account_activity.deposit_account_id = deposit_accounts.deposit_account_id
			LEFT JOIN loans ON account_activity.loan_id = loans.loan_id
		WHERE (account_activity.period_id = v_period_id);
	
		msg := 'Sacco posted';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;


---- member termination process
CREATE OR REPLACE FUNCTION member_termination(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg							varchar(120);
	v_is_active 				boolean;
	rec1 						RECORD;
	
BEGIN
	--- Application for member Termination/exit 
	IF($3 = '1')THEN
		UPDATE members SET terminate_status = 'Pending', terminate_application_date = current_date
		WHERE (member_id = $1::integer) AND (approve_status = 'Approved') AND (terminate_status = 'N/A');

		UPDATE deposit_accounts SET is_active = false
		WHERE (member_id = $1::integer) AND (approve_status = 'Approved') AND (is_active = true);

		msg := 'Applied for member Exit';
	
	END IF;
	--- completing the member exit/termination proccess and archiving the member
	IF($3 = '2')THEN		
		--- deactivating 
		UPDATE members SET terminate_status = 'Completed', terminated = true, is_active = false, terminate_date = current_date,details = ('archived/deactivated member on'|| ' :- ' ||current_date)
		WHERE (member_id = $1::integer) AND (approve_status = 'Approved') AND (terminate_status = 'Pending');
		msg := 'Member(s) Exit completed and Deactivated...';

	END IF;

	IF($3 = '3')THEN
		--Activating the member		
		UPDATE members SET terminate_status = 'N/A', terminated = false, is_active = true, terminate_date = Null,details = ('activated member on'|| ' :- ' ||current_date)
		WHERE (member_id = $1::integer) AND (approve_status = 'Approved') AND (terminate_status = 'Completed');
		msg := 'Member(s) Activated...';
		---Activating members account
		UPDATE deposit_accounts SET is_active = true
		WHERE (member_id = $1::integer) AND (approve_status = 'Approved') AND (is_active = false);

	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;



----  archiving function
CREATE OR REPLACE FUNCTION archiving(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg							varchar(120);
	
BEGIN
	---- deactivating the account product
	IF($3 = '1')THEN
		UPDATE deposit_accounts SET is_active = false, details = ('archive/deactivated account product on'|| ' :- ' ||current_date)
		WHERE (deposit_account_id = $1::integer) AND (approve_status = 'Approved') AND (is_active = true);

		msg := 'Account Product deactivated';
	
	END IF;

	--- Activating the account product
	IF($3 = '2')THEN
		UPDATE deposit_accounts SET is_active = true, details = ('Activated account product on'|| ' :- ' ||current_date)
		WHERE (deposit_account_id = $1::integer) AND (approve_status = 'Approved') AND (is_active = false);

		msg := 'Account Product Activated';
	
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;

	
