--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: add_periods(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_periods(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	msg					varchar(120);
BEGIN

	SELECT org_id INTO v_org_id
	FROM fiscal_years
	WHERE (fiscal_year_id = $1::int);
	
	UPDATE periods SET fiscal_year_id = fiscal_years.fiscal_year_id
	FROM fiscal_years WHERE (fiscal_years.fiscal_year_id = $1::int)
		AND (fiscal_years.fiscal_year_start <= start_date) AND (fiscal_years.fiscal_year_end >= end_date);
	
	SELECT period_id INTO v_period_id
	FROM periods
	WHERE (fiscal_year_id = $1::int) AND (org_id = v_org_id);
	
	IF(v_period_id is null)THEN
		INSERT INTO periods (fiscal_year_id, org_id, start_date, end_date)
		SELECT $1::int, v_org_id, period_start, CAST(period_start + CAST('1 month' as interval) as date) - 1
		FROM (SELECT CAST(generate_series(fiscal_year_start, fiscal_year_end, '1 month') as date) as period_start
			FROM fiscal_years WHERE fiscal_year_id = $1::int) as a;
		msg := 'Months for the year generated';
	ELSE
		msg := 'Months year already created';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.add_periods(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: add_tx_link(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_tx_link(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
	
	INSERT INTO transaction_details (transaction_id, org_id, item_id, quantity, amount, tax_amount, narrative, details)
	SELECT CAST($3 as integer), org_id, item_id, quantity, amount, tax_amount, narrative, details
	FROM transaction_details
	WHERE (transaction_detail_id = CAST($1 as integer));

	INSERT INTO transaction_links (org_id, transaction_detail_id, transaction_detail_to, quantity, amount)
	SELECT org_id, transaction_detail_id, currval('transaction_details_transaction_detail_id_seq'), quantity, amount
	FROM transaction_details
	WHERE (transaction_detail_id = CAST($1 as integer));

	return 'DONE';
END;
$_$;


ALTER FUNCTION public.add_tx_link(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: af_upd_transaction_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION af_upd_transaction_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_amount					real;
	v_tax_amount				real;
BEGIN

	IF(TG_OP = 'DELETE')THEN
		SELECT SUM(quantity * (amount + tax_amount)), SUM(quantity *  tax_amount) INTO v_amount, v_tax_amount
		FROM transaction_details WHERE (transaction_id = OLD.transaction_id);
		
		UPDATE transactions SET transaction_amount = v_amount, transaction_tax_amount = v_tax_amount
		WHERE (transaction_id = OLD.transaction_id);	
	ELSE
		SELECT SUM(quantity * (amount + tax_amount)), SUM(quantity *  tax_amount) INTO v_amount, v_tax_amount
		FROM transaction_details WHERE (transaction_id = NEW.transaction_id);
		
		UPDATE transactions SET transaction_amount = v_amount, transaction_tax_amount = v_tax_amount
		WHERE (transaction_id = NEW.transaction_id);	
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.af_upd_transaction_details() OWNER TO postgres;

--
-- Name: amount_in_words(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION amount_in_words(n bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
	DECLARE
 		 e TEXT;
	BEGIN

 	 WITH Below20(Word, Id) AS
 	 (
  	  VALUES
     	 ('Zero', 0), ('One', 1),( 'Two', 2 ), ( 'Three', 3), ( 'Four', 4 ), ( 'Five', 5 ), ( 'Six', 6 ), ( 'Seven', 7 ),
    	  ( 'Eight', 8), ( 'Nine', 9), ( 'Ten', 10), ( 'Eleven', 11 ),( 'Twelve', 12 ), ( 'Thirteen', 13 ), ( 'Fourteen', 14),
    	  ( 'Fifteen', 15 ), ('Sixteen', 16 ), ( 'Seventeen', 17),
    	  ('Eighteen', 18 ), ( 'Nineteen', 19 )
  	 ),
  		 Below100(Word, Id) AS
  	 (
     	 VALUES
      	 ('Twenty', 2), ('Thirty', 3),('Forty', 4), ('Fifty', 5),
      	 ('Sixty', 6), ('Seventy', 7), ('Eighty', 8), ('Ninety', 9)
  	 )
  		 SELECT
     		CASE
    		  WHEN n = 0 THEN  ''
     		 WHEN n BETWEEN 1 AND 19
       			 THEN (SELECT Word FROM Below20 WHERE ID=n)
    		 WHEN n BETWEEN 20 AND 99
     			  THEN  (SELECT Word FROM Below100 WHERE ID=n/10) ||  '-'  ||
           		  amount_in_words( n % 10)
    		 WHEN n BETWEEN 100 AND 999
      			 THEN  (amount_in_words( n / 100)) || ' Hundred ' ||
          		 amount_in_words( n % 100)
    		 WHEN n BETWEEN 1000 AND 999999
    			   THEN  (amount_in_words( n / 1000)) || ' Thousand ' ||
         			  amount_in_words( n % 1000)
    		 WHEN n BETWEEN 1000000 AND 999999999
     			  THEN  (amount_in_words( n / 1000000)) || ' Million ' ||
         		  amount_in_words( n % 1000000)
   			 WHEN n BETWEEN 1000000000 AND 999999999999
     			  THEN  (amount_in_words( n / 1000000000)) || ' Billion ' ||
           			amount_in_words( n % 1000000000)
    		 WHEN n BETWEEN 1000000000000 AND 999999999999999
      			 THEN  (amount_in_words( n / 1000000000000)) || ' Trillion ' ||
           			amount_in_words( n % 1000000000000)
   			 WHEN n BETWEEN 1000000000000000 AND 999999999999999999
      			 THEN  (amount_in_words( n / 1000000000000000)) || ' Quadrillion ' ||
          			 amount_in_words( n % 1000000000000000)
   			 WHEN n BETWEEN 1000000000000000000 AND 999999999999999999999
       			THEN  (amount_in_words( n / 1000000000000000000)) || ' Quintillion ' ||
          			 amount_in_words( n % 1000000000000000000)
         	 ELSE ' INVALID INPUT' END INTO e;
 			 e := RTRIM(e);
 			 IF RIGHT(e,1)='-' THEN
   			 e := RTRIM(LEFT(e,length(e)-1));
 		 END IF;

 		 RETURN e;
		END;
	$$;


ALTER FUNCTION public.amount_in_words(n bigint) OWNER TO postgres;

--
-- Name: aud_period_rentals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION aud_period_rentals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	INSERT INTO log_period_rentals (period_rental_id, rental_id, period_id, 
		sys_audit_trail_id, org_id, rental_amount, service_fees,
		repair_amount, status, commision, commision_pct, narrative)
	VALUES (OLD.period_rental_id, OLD.rental_id, OLD.period_id, 
		OLD.sys_audit_trail_id, OLD.org_id, OLD.rental_amount, OLD.service_fees,
		OLD.repair_amount, OLD.status, OLD.commision, OLD.commision_pct, OLD.narrative);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aud_period_rentals() OWNER TO postgres;

--
-- Name: change_password(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION change_password(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	old_password 	varchar(64);
	passchange 		varchar(120);
	entityID		integer;
BEGIN
	passchange := 'Password Error';
	entityID := CAST($1 AS INT);
	SELECT Entity_password INTO old_password
	FROM entitys WHERE (entity_id = entityID);

	IF ($2 = '0') THEN
		passchange := first_password();
		UPDATE entitys SET first_password = passchange, Entity_password = md5(passchange) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSIF (old_password = md5($2)) THEN
		UPDATE entitys SET Entity_password = md5($3) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSE
		passchange := null;
	END IF;

	return passchange;
END;
$_$;


ALTER FUNCTION public.change_password(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_issue(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_issue(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 					varchar(120);
BEGIN

	msg := null;
	
	IF($3 = '1')THEN
		UPDATE helpdesk SET closed_by = $2::integer, solved_time = current_timestamp, is_solved = true
		WHERE helpdesk_id = $1::integer;
		
		msg := 'Closed the call';
	END IF;
	
	return msg;
END;
$_$;


ALTER FUNCTION public.close_issue(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_periods(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_periods(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 					varchar(120);
BEGIN
	
	IF(v_period_id is null)THEN
		INSERT INTO periods (fiscal_year_id, org_id, start_date, end_date)
		SELECT $1::int, v_org_id, period_start, CAST(period_start + CAST('1 month' as interval) as date) - 1
		FROM (SELECT CAST(generate_series(fiscal_year_start, fiscal_year_end, '1 month') as date) as period_start
			FROM fiscal_years WHERE fiscal_year_id = $1::int) as a;
		msg := 'Months for the year generated';
	ELSE
		msg := 'Months year already created';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.close_periods(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_year(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_year(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	trx_date		DATE;
	periodid		INTEGER;
	journalid		INTEGER;
	profit_acct		INTEGER;
	retain_acct		INTEGER;
	rec				RECORD;
	msg				varchar(120);
BEGIN
	SELECT fiscal_year_id, fiscal_year_start, fiscal_year_end, year_opened, year_closed INTO rec
	FROM fiscal_years
	WHERE (fiscal_year_id = CAST($1 as integer));

	SELECT account_id INTO profit_acct FROM default_accounts WHERE default_account_id = 1;
	SELECT account_id INTO retain_acct FROM default_accounts WHERE default_account_id = 2;
	
	trx_date := CAST($1 || '-12-31' as date);
	periodid := get_open_period(trx_date);
	IF(periodid is null) THEN
		msg := 'Cannot post. No active period to post.';
	ELSIF(rec.year_opened = false)THEN
		msg := 'Cannot post. The year is not opened.';
	ELSIF(rec.year_closed = true)THEN
		msg := 'Cannot post. The year is closed.';
	ELSE
		INSERT INTO journals (period_id, journal_date, narrative, year_closing)
		VALUES (periodid, trx_date, 'End of year closing', false);
		journalid := currval('journals_journal_id_seq');

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, account_id, dr_amount, cr_amount, 'Account Balance'
		FROM ((SELECT account_id, sum(bal_credit) as dr_amount, sum(bal_debit) as cr_amount
		FROM vw_ledger
		WHERE (chat_type_id > 3) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0)
		GROUP BY account_id)
		UNION
		(SELECT profit_acct, (CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END),
		(CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END)
		FROM vw_ledger
		WHERE (chat_type_id > 3) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0))) as a;

		msg := process_journal(CAST(journalid as varchar),'0','0');

		INSERT INTO journals (period_id, journal_date, narrative, year_closing)
		VALUES (periodid, trx_date, 'Retained Earnings', false);
		journalid := currval('journals_journal_id_seq');

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, profit_acct, (CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END),
			(CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END), 'Retained Earnings'
		FROM vw_ledger
		WHERE (account_id = profit_acct) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0);

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, retain_acct, (CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END),
			(CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END), 'Retained Earnings'
		FROM vw_ledger
		WHERE (account_id = profit_acct) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0);

		msg := process_journal(CAST(journalid as varchar),'0','0');

		UPDATE fiscal_years SET year_closed = true WHERE fiscal_year_id = rec.fiscal_year_id;
		UPDATE periods SET period_closed = true WHERE fiscal_year_id = rec.fiscal_year_id;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.close_year(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: complete_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION complete_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	bankacc INTEGER;
	msg varchar(120);
BEGIN
	SELECT transaction_id, transaction_type_id, transaction_status_id, bank_account_id INTO rec
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	IF($3 = '2') THEN
		UPDATE transactions SET transaction_status_id = 4 
		WHERE transaction_id = rec.transaction_id;
		msg := 'Transaction Archived';
	ELSIF($3 = '1') AND (rec.transaction_status_id = 1)THEN
		IF((rec.transaction_type_id = 7) or (rec.transaction_type_id = 8)) THEN
			IF(rec.bank_account_id is null)THEN
				msg := 'Transaction completed.';
				RAISE EXCEPTION 'You need to add the bank account to receive the funds';
			ELSE
				UPDATE transactions SET transaction_status_id = 2, approve_status = 'Completed'
				WHERE transaction_id = rec.transaction_id;
				msg := 'Transaction completed.';
			END IF;
		ELSE
			UPDATE transactions SET transaction_status_id = 2, approve_status = 'Completed'
			WHERE transaction_id = rec.transaction_id;
			msg := 'Transaction completed.';
		END IF;
	ELSE
		msg := 'Transaction alerady completed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.complete_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: copy_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION copy_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg varchar(120);
BEGIN

	INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, order_number, payment_terms, job, narrative, details)
	SELECT org_id, department_id, entity_id, currency_id, transaction_type_id, CURRENT_DATE, order_number, payment_terms, job, narrative, details
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	INSERT INTO transaction_details (org_id, transaction_id, account_id, item_id, quantity, amount, tax_amount, narrative, details)
	SELECT org_id, currval('transactions_transaction_id_seq'), account_id, item_id, quantity, amount, tax_amount, narrative, details
	FROM transaction_details
	WHERE (transaction_id = CAST($1 as integer));

	msg := 'Transaction Copied';

	return msg;
END;
$_$;


ALTER FUNCTION public.copy_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: cpy_trx_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION cpy_trx_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_ledger_date				timestamp;
	last_date					timestamp;
	v_start						integer;
	v_end						integer;
	v_inteval					interval;
	msg							varchar(120);
BEGIN

	SELECT max(payment_date)::timestamp INTO last_date
	FROM transactions
	WHERE (to_char(payment_date, 'YYYY.MM') = $1);
	v_start := EXTRACT(YEAR FROM last_date) * 12 + EXTRACT(MONTH FROM last_date);
	
	SELECT max(payment_date)::timestamp INTO v_ledger_date
	FROM transactions;
	v_end := EXTRACT(YEAR FROM v_ledger_date) * 12 + EXTRACT(MONTH FROM v_ledger_date) + 1;
	v_inteval :=  ((v_end - v_start) || ' months')::interval;

	IF ($3 = '1') THEN
		INSERT INTO transactions(ledger_type_id, entity_id, bank_account_id, 
				currency_id, journal_id, org_id, exchange_rate, tx_type, payment_date, 
				transaction_amount, transaction_tax_amount, reference_number, 
				narrative, transaction_type_id, transaction_date)
		SELECT ledger_type_id, entity_id, bank_account_id, 
			currency_id, journal_id, org_id, exchange_rate, tx_type, (payment_date + v_inteval), 
			transaction_amount, transaction_tax_amount, reference_number,
			narrative, transaction_type_id, (transaction_date  + v_inteval)
		FROM transactions
		WHERE (tx_type is not null) AND (to_char(payment_date, 'YYYY.MM') = $1);

		msg := 'Appended a new month';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.cpy_trx_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: curr_base_returns(date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION curr_base_returns(date, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(base_credit - base_debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (year_closing = false)
		AND (journal_date >= $1) AND (journal_date <= $2);
$_$;


ALTER FUNCTION public.curr_base_returns(date, date) OWNER TO postgres;

--
-- Name: curr_returns(date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION curr_returns(date, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(credit - debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (year_closing = false)
		AND (journal_date >= $1) AND (journal_date <= $2);
$_$;


ALTER FUNCTION public.curr_returns(date, date) OWNER TO postgres;

--
-- Name: default_currency(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION default_currency(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT orgs.currency_id
	FROM orgs INNER JOIN entitys ON orgs.org_id = entitys.org_id
	WHERE (entitys.entity_id = CAST($1 as integer));
$_$;


ALTER FUNCTION public.default_currency(character varying) OWNER TO postgres;

--
-- Name: emailed(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION emailed(integer, character varying) RETURNS void
    LANGUAGE sql
    AS $_$
    UPDATE sys_emailed SET emailed = true WHERE (sys_emailed_id = CAST($2 as int));
$_$;


ALTER FUNCTION public.emailed(integer, character varying) OWNER TO postgres;

--
-- Name: first_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION first_password() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	rnd integer;
	passchange varchar(12);
BEGIN
	passchange := trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	passchange := passchange || trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);

	return passchange;
END;
$$;


ALTER FUNCTION public.first_password() OWNER TO postgres;

--
-- Name: generate_rentals(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION generate_rentals(character varying, character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	v_total_rent		float;
	myrec				RECORD;
	msg					varchar(120);
BEGIN
	IF ($3 = '1') THEN
	SELECT period_id INTO v_period_id FROM period_rentals WHERE period_id = $1::int AND rental_id = rental_id;
		IF(v_period_id is NULL) THEN
			INSERT INTO period_rentals (period_id, org_id, entity_id, property_id, rental_id, rental_amount, service_fees, commision, commision_pct, sys_audit_trail_id)
			SELECT $1::int, org_id, entity_id, property_id,rental_id, rental_value, service_fees, commision_value, commision_pct, $5::int
				FROM rentals 
				WHERE is_active = true;
			msg := 'Rentals generated';
		ELSE 
			msg := 'Rentals exists';
		END IF;		
	END IF;
	return msg;
END;
$_$;


ALTER FUNCTION public.generate_rentals(character varying, character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: get_acct(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_acct(integer, date, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT sum(gls.debit - gls.credit)
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) AND (journals.year_closing = false)
		AND (journals.journal_date >= $2) AND (journals.journal_date <= $3);
$_$;


ALTER FUNCTION public.get_acct(integer, date, date) OWNER TO postgres;

--
-- Name: get_balance(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_balance(integer, character varying) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_bal					real;
BEGIN

	SELECT COALESCE(sum(debit_amount - credit_amount), 0) INTO v_bal
	FROM vw_trx
	WHERE (vw_trx.approve_status = 'Approved')
		AND (vw_trx.for_posting = true)
		AND (vw_trx.entity_id = $1)
		AND (vw_trx.transaction_date < $2::date);
		
		
	RETURN v_bal;
END;
$_$;


ALTER FUNCTION public.get_balance(integer, character varying) OWNER TO postgres;

--
-- Name: get_base_acct(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_base_acct(integer, date, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT sum(gls.debit * journals.exchange_rate - gls.credit * journals.exchange_rate) 
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) AND (journals.year_closing = false)
		AND (journals.journal_date >= $2) AND (journals.journal_date <= $3);
$_$;


ALTER FUNCTION public.get_base_acct(integer, date, date) OWNER TO postgres;

--
-- Name: get_budgeted(integer, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_budgeted(integer, date, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reca		RECORD;
	app_id		Integer;
	v_bill		real;
	v_variance	real;
BEGIN

	FOR reca IN SELECT transaction_detail_id, account_id, amount 
		FROM transaction_details WHERE (transaction_id = $1) LOOP

		SELECT sum(amount) INTO v_bill
		FROM transactions INNER JOIN transaction_details ON transactions.transaction_id = transaction_details.transaction_id
		WHERE (transactions.department_id = $3) AND (transaction_details.account_id = reca.account_id)
			AND (transactions.journal_id is null) AND (transaction_details.transaction_detail_id <> reca.transaction_detail_id);
		IF(v_bill is null)THEN
			v_bill := 0;
		END IF;

		SELECT sum(budget_lines.amount) INTO v_variance
		FROM fiscal_years INNER JOIN budgets ON fiscal_years.fiscal_year_id = budgets.fiscal_year_id
			INNER JOIN budget_lines ON budgets.budget_id = budget_lines.budget_id
		WHERE (budgets.department_id = $3) AND (budget_lines.account_id = reca.account_id)
			AND (budgets.approve_status = 'Approved')
			AND (fiscal_years.fiscal_year_start <= $2) AND (fiscal_years.fiscal_year_end >= $2);
		IF(v_variance is null)THEN
			v_variance := 0;
		END IF;

		v_variance := v_variance - (reca.amount + v_bill);

		IF(v_variance < 0)THEN
			RETURN v_variance;
		END IF;
	END LOOP;

	RETURN v_variance;
END;
$_$;


ALTER FUNCTION public.get_budgeted(integer, date, integer) OWNER TO postgres;

--
-- Name: get_currency_rate(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_currency_rate(integer, integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT max(exchange_rate)
	FROM currency_rates
	WHERE (org_id = $1) AND (currency_id = $2)
		AND (exchange_date = (SELECT max(exchange_date) FROM currency_rates WHERE (org_id = $1) AND (currency_id = $2)));
$_$;


ALTER FUNCTION public.get_currency_rate(integer, integer) OWNER TO postgres;

--
-- Name: get_default_account(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_account(integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$
    SELECT accounts.account_no
	FROM default_accounts INNER JOIN accounts ON default_accounts.account_id = accounts.account_id
	WHERE (default_accounts.use_key_id = $1) AND (default_accounts.org_id = $2);
$_$;


ALTER FUNCTION public.get_default_account(integer, integer) OWNER TO postgres;

--
-- Name: get_default_account_id(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_account_id(integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$
    SELECT accounts.account_id
	FROM default_accounts INNER JOIN accounts ON default_accounts.account_id = accounts.account_id
	WHERE (default_accounts.use_key_id = $1) AND (default_accounts.org_id = $2);
$_$;


ALTER FUNCTION public.get_default_account_id(integer, integer) OWNER TO postgres;

--
-- Name: get_default_country(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_country(integer) RETURNS character
    LANGUAGE sql
    AS $_$
	SELECT default_country_id::varchar(2)
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_country(integer) OWNER TO postgres;

--
-- Name: get_default_currency(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_currency(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT currency_id
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_currency(integer) OWNER TO postgres;

--
-- Name: get_end_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_end_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '31/12/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_end_year(character varying) OWNER TO postgres;

--
-- Name: get_ledger_link(integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_ledger_link(integer, integer, integer, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_ledger_type_id		integer;
	v_account_no			integer;
	v_account_id			integer;
BEGIN

	SELECT ledger_types.ledger_type_id, accounts.account_no INTO v_ledger_type_id, v_account_no
	FROM ledger_types INNER JOIN ledger_links ON ledger_types.ledger_type_id = ledger_links.ledger_type_id
		INNER JOIN accounts ON ledger_types.account_id = accounts.account_id
	WHERE (ledger_links.org_id = $1) AND (ledger_links.link_type = $2) AND (ledger_links.link_id = $3);
	
	IF(v_ledger_type_id is null)THEN
		v_ledger_type_id := nextval('ledger_types_ledger_type_id_seq');
		SELECT accounts.account_id INTO v_account_id
		FROM accounts
		WHERE (accounts.org_id = $1) AND (accounts.account_no::text = $4);
		
		INSERT INTO ledger_types (ledger_type_id, account_id, tax_account_id, org_id,
			ledger_type_name, ledger_posting, expense_ledger, income_ledger)
		VALUES (v_ledger_type_id, v_account_id, v_account_id, $1,
			$5, true, true, false);

		INSERT INTO ledger_links (ledger_type_id, org_id, link_type, link_id)
		VALUES (v_ledger_type_id, $1, $2, $3);
	END IF;
	
	RETURN v_ledger_type_id;
END;
$_$;


ALTER FUNCTION public.get_ledger_link(integer, integer, integer, character varying, character varying) OWNER TO postgres;

--
-- Name: get_occupied(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_occupied(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(count(rental_id), 0)::integer
	FROM rentals
	WHERE (is_active = true) AND (property_id = $1);
$_$;


ALTER FUNCTION public.get_occupied(integer) OWNER TO postgres;

--
-- Name: get_open_period(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_open_period(date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT period_id FROM periods WHERE (start_date <= $1) AND (end_date >= $1)
		AND (opened = true) AND (closed = false); 
$_$;


ALTER FUNCTION public.get_open_period(date) OWNER TO postgres;

--
-- Name: get_org_logo(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_org_logo(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT orgs.logo
	FROM orgs WHERE (orgs.org_id = $1);
$_$;


ALTER FUNCTION public.get_org_logo(integer) OWNER TO postgres;

--
-- Name: get_period(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_period(date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT period_id FROM periods WHERE (start_date <= $1) AND (end_date >= $1); 
$_$;


ALTER FUNCTION public.get_period(date) OWNER TO postgres;

--
-- Name: get_periodic_remmit(double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_periodic_remmit(double precision) RETURNS double precision
    LANGUAGE sql
    AS $$
  SELECT sum(period_rentals.rental_amount + period_rentals.commision)::float
	FROM vw_property 
		INNER JOIN period_rentals ON period_rentals.property_id = vw_property.property_id
			GROUP BY vw_property.property_id,period_rentals.period_id
$$;


ALTER FUNCTION public.get_periodic_remmit(double precision) OWNER TO postgres;

--
-- Name: get_phase_email(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_email(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	myemail	varchar(320);
BEGIN
	myemail := null;
	FOR myrec IN SELECT entitys.primary_email
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myemail is null) THEN
			IF (myrec.primary_email is not null) THEN
				myemail := myrec.primary_email;
			END IF;
		ELSE
			IF (myrec.primary_email is not null) THEN
				myemail := myemail || ', ' || myrec.primary_email;
			END IF;
		END IF;

	END LOOP;

	RETURN myemail;
END;
$_$;


ALTER FUNCTION public.get_phase_email(integer) OWNER TO postgres;

--
-- Name: get_phase_entitys(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_entitys(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec			RECORD;
	myentitys		varchar(320);
BEGIN
	myentitys := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myentitys is null) THEN
			IF (myrec.entity_name is not null) THEN
				myentitys := myrec.entity_name;
			END IF;
		ELSE
			IF (myrec.entity_name is not null) THEN
				myentitys := myentitys || ', ' || myrec.entity_name;
			END IF;
		END IF;

	END LOOP;

	RETURN myentitys;
END;
$_$;


ALTER FUNCTION public.get_phase_entitys(integer) OWNER TO postgres;

--
-- Name: get_phase_status(boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_status(boolean, boolean) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ps		varchar(16);
BEGIN
	ps := 'Draft';
	IF ($1 = true) THEN
		ps := 'Approved';
	END IF;
	IF ($2 = true) THEN
		ps := 'Rejected';
	END IF;

	RETURN ps;
END;
$_$;


ALTER FUNCTION public.get_phase_status(boolean, boolean) OWNER TO postgres;

--
-- Name: get_reporting_list(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_reporting_list(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	mylist	varchar(320);
BEGIN
	mylist := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM reporting INNER JOIN entitys ON reporting.report_to_id = entitys.entity_id
		WHERE (reporting.primary_report = true) AND (reporting.entity_id = $1) 
	LOOP

		IF (mylist is null) THEN
			mylist := myrec.entity_name;
		ELSE
			mylist := mylist || ', ' || myrec.entity_name;
		END IF;
	END LOOP;

	RETURN mylist;
END;
$_$;


ALTER FUNCTION public.get_reporting_list(integer) OWNER TO postgres;

--
-- Name: get_start_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_start_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '01/01/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_start_year(character varying) OWNER TO postgres;

--
-- Name: get_total_remit(double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_remit(double precision) RETURNS double precision
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(SUM(rent_to_remit), 0)::float 
	FROM vw_period_rentals
	WHERE (is_active = true) AND (period_id = $1);
$_$;


ALTER FUNCTION public.get_total_remit(double precision) OWNER TO postgres;

--
-- Name: get_total_remit(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_remit(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(rental_amount), 0)::integer
	FROM period_rentals
	WHERE (status='Draft') AND (property_id = $1);
$_$;


ALTER FUNCTION public.get_total_remit(integer) OWNER TO postgres;

--
-- Name: gettaxmin(double precision, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION gettaxmin(double precision, integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN max(tax_range) is null THEN 0 ELSE max(tax_range) END 
	FROM period_tax_rates WHERE (tax_range < $1) AND (period_tax_type_id = $2);
$_$;


ALTER FUNCTION public.gettaxmin(double precision, integer) OWNER TO postgres;

--
-- Name: ins_address(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_address_id		integer;
BEGIN
	SELECT address_id INTO v_address_id
	FROM address WHERE (is_default = true)
		AND (table_name = NEW.table_name) AND (table_id = NEW.table_id) AND (address_id <> NEW.address_id);

	IF(NEW.is_default is null)THEN
		NEW.is_default := false;
	END IF;

	IF(NEW.is_default = true) AND (v_address_id is not null) THEN
		RAISE EXCEPTION 'Only one default Address allowed.';
	ELSIF (NEW.is_default = false) AND (v_address_id is null) THEN
		NEW.is_default := true;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_address() OWNER TO postgres;

--
-- Name: ins_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
BEGIN

	IF (NEW.forward_id is not null) THEN
		SELECT workflow_phase_id, org_entity_id, app_entity_id, approval_level, table_name, table_id INTO reca
		FROM approvals
		WHERE (approval_id = NEW.forward_id);

		NEW.workflow_phase_id := reca.workflow_phase_id;
		NEW.approval_level := reca.approval_level;
		NEW.table_name := reca.table_name;
		NEW.table_id := reca.table_id;
		NEW.approve_status := 'Completed';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_approvals() OWNER TO postgres;

--
-- Name: ins_entitys(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entitys() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.entity_type_id is not null) THEN
		INSERT INTO Entity_subscriptions (org_id, entity_type_id, entity_id, subscription_level_id)
		VALUES (NEW.org_id, NEW.entity_type_id, NEW.entity_id, 0);
	END IF;

	INSERT INTO entity_values (org_id, entity_id, entity_field_id)
	SELECT NEW.org_id, NEW.entity_id, entity_field_id
	FROM entity_fields
	WHERE (org_id = NEW.org_id) AND (is_active = true);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_entitys() OWNER TO postgres;

--
-- Name: ins_entry_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec 		RECORD;
	vorgid		integer;
	formName 	varchar(120);
	msg 		varchar(120);
BEGIN
	SELECT entry_form_id, org_id INTO rec
	FROM entry_forms 
	WHERE (form_id = CAST($1 as int)) AND (entity_ID = CAST($2 as int))
		AND (approve_status = 'Draft');

	SELECT form_name, org_id INTO formName, vorgid
	FROM forms WHERE (form_id = CAST($1 as int));

	IF rec.entry_form_id is null THEN
		INSERT INTO entry_forms (form_id, entity_id, org_id) 
		VALUES (CAST($1 as int), CAST($2 as int), vorgid);
		msg := 'Added Form : ' || formName;
	ELSE
		msg := 'There is an incomplete form : ' || formName;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.ins_entry_form(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: ins_entry_forms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_forms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca		RECORD;
BEGIN
	
	SELECT default_values, default_sub_values INTO reca
	FROM forms
	WHERE (form_id = NEW.form_id);
	
	NEW.answer := reca.default_values;
	NEW.sub_answer := reca.default_sub_values;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_entry_forms() OWNER TO postgres;

--
-- Name: ins_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.field_order is null) THEN
		SELECT max(field_order) INTO v_ord
		FROM fields
		WHERE (form_id = NEW.form_id);

		IF (v_ord is null) THEN
			NEW.field_order := 10;
		ELSE
			NEW.field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_fields() OWNER TO postgres;

--
-- Name: ins_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (trim(lower(user_name)) = trim(lower(NEW.user_name)))
		AND entity_id <> NEW.entity_id;
		
	IF(v_entity_id is not null)THEN
		RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
	END IF;

	IF(TG_OP = 'INSERT') THEN
		IF(NEW.first_password is null)THEN
			NEW.first_password := first_password();
		END IF;

		IF (NEW.entity_password is null) THEN
			NEW.entity_password := md5(NEW.first_password);
		END IF;
	ELSIF(OLD.first_password <> NEW.first_password) THEN
		NEW.Entity_password := md5(NEW.first_password);
	END IF;
	
	IF(NEW.user_name is null)THEN
		SELECT org_sufix || '.' || lower(trim(replace(NEW.entity_name, ' ', ''))) INTO NEW.user_name
		FROM orgs
		WHERE org_id = NEW.org_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_password() OWNER TO postgres;

--
-- Name: ins_payments(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_payments() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec					RECORD;
BEGIN
	
	IF(NEW.payment_id is not null AND NEW.tx_type = 1)THEN
		SELECT sum(account_credit - account_debit) INTO NEW.balance
		FROM payments
		WHERE (payment_id < NEW.payment_id) AND (rental_id = NEW.rental_id);
	ELSIF(NEW.payment_id is not null AND NEW.tx_type = -1)THEN
		SELECT sum(account_debit - account_credit) INTO NEW.balance
		FROM payments
		WHERE (payment_id < NEW.payment_id) AND (entity_id = NEW.entity_id);
	END IF;

	IF(NEW.balance is null)THEN
		NEW.balance := 0;
	END IF;

	IF(NEW.payment_id is not null AND NEW.tx_type = 1)THEN
		NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);
	ELSIF (NEW.payment_id is not null AND NEW.tx_type = -1)THEN
		NEW.balance := NEW.balance + (NEW.account_debit - NEW.account_credit);
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_payments() OWNER TO postgres;

--
-- Name: ins_period_rentals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_period_rentals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec					RECORD;
BEGIN
	SELECT rental_value, service_fees, commision_value, commision_pct INTO rec
	FROM rentals
	WHERE rental_id = NEW.rental_id;

	IF(NEW.rental_amount is null)THEN
		NEW.rental_amount := rec.rental_value;
	END IF;
	IF(NEW.service_fees is null)THEN
		NEW.service_fees := rec.service_fees;
	END IF;
	IF((NEW.commision is null) AND (NEW.commision_pct is null))THEN
		NEW.commision := rec.commision_value;
		NEW.commision_pct := rec.commision_pct;
	END IF;
	
	IF(NEW.commision is null)THEN NEW.commision := 0; END IF;
	IF(NEW.commision_pct is null)THEN NEW.commision_pct := 0; END IF;
	
	IF((NEW.commision = 0) AND (NEW.commision_pct > 0))THEN
		NEW.commision := NEW.rental_amount * NEW.commision_pct / 100;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_period_rentals() OWNER TO postgres;

--
-- Name: ins_periods(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_periods() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	year_close 		BOOLEAN;
BEGIN
	SELECT year_closed INTO year_close
	FROM fiscal_years
	WHERE (fiscal_year_id = NEW.fiscal_year_id);
	
	IF(TG_OP = 'UPDATE')THEN    
		IF (OLD.closed = true) AND (NEW.closed = false) THEN
			NEW.approve_status := 'Draft';
		END IF;
	ELSE
		IF(NEW.gl_payroll_account is null)THEN NEW.gl_payroll_account := get_default_account(27, NEW.org_id); END IF;
		IF(NEW.gl_advance_account is null)THEN NEW.gl_advance_account := get_default_account(28, NEW.org_id); END IF;
	END IF;

	IF (NEW.approve_status = 'Approved') THEN
		NEW.opened = false;
		NEW.activated = false;
		NEW.closed = true;
	END IF;

	IF(year_close = true)THEN
		RAISE EXCEPTION 'The year is closed not transactions are allowed.';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_periods() OWNER TO postgres;

--
-- Name: ins_property(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_property() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	IF((NEW.commision_value = 0) AND (NEW.commision_pct > 0))THEN
		NEW.commision_value := NEW.rental_value * NEW.commision_pct / 100;
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_property() OWNER TO postgres;

--
-- Name: ins_rentals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_rentals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec					RECORD;
BEGIN
	SELECT rental_value, service_fees, commision_value, commision_pct INTO rec
	FROM property
	WHERE property_id = NEW.property_id;

	IF(NEW.rental_value is null)THEN
		NEW.rental_value := rec.rental_value;
	END IF;
	IF(NEW.service_fees is null)THEN
		NEW.service_fees := rec.service_fees;
	END IF;
	IF((NEW.commision_value is null) AND (NEW.commision_pct is null))THEN
		NEW.commision_value := rec.commision_value;
		NEW.commision_pct := rec.commision_pct;
	END IF;
	
	IF(NEW.commision_value is null)THEN NEW.commision_value := 0; END IF;
	IF(NEW.commision_pct is null)THEN NEW.commision_pct := 0; END IF;
	
	IF((NEW.commision_value = 0) AND (NEW.commision_pct > 0))THEN
		NEW.commision_value := NEW.rental_value * NEW.commision_pct / 100;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_rentals() OWNER TO postgres;

--
-- Name: ins_sub_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sub_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.sub_field_order is null) THEN
		SELECT max(sub_field_order) INTO v_ord
		FROM sub_fields
		WHERE (field_id = NEW.field_id);

		IF (v_ord is null) THEN
			NEW.sub_field_order := 10;
		ELSE
			NEW.sub_field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_sub_fields() OWNER TO postgres;

--
-- Name: ins_subscriptions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_subscriptions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_org_id				integer;
	v_currency_id			integer;
	v_department_id			integer;
	v_bank_id				integer;
	v_tax_type_id			integer;
	v_workflow_id			integer;
	v_org_suffix			char(2);
	myrec 					RECORD;
BEGIN

	IF (TG_OP = 'INSERT') THEN
		SELECT entity_id INTO v_entity_id
		FROM entitys WHERE lower(trim(user_name)) = lower(trim(NEW.primary_email));

		IF(v_entity_id is null)THEN
			NEW.entity_id := nextval('entitys_entity_id_seq');
			INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, entity_name, User_name, primary_email,  function_role, first_password)
			VALUES (NEW.entity_id, 0, 5, 5, NEW.primary_contact, lower(trim(NEW.primary_email)), lower(trim(NEW.primary_email)), 'subscription', null);
		
			INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
			VALUES (4, 0, NEW.entity_id, 'subscription');
		
			NEW.approve_status := 'Completed';
		ELSE
			RAISE EXCEPTION 'You already have an account, login and request for services';
		END IF;
	ELSIF(NEW.approve_status = 'Approved')THEN

		NEW.org_id := nextval('orgs_org_id_seq');
		INSERT INTO orgs(org_id, currency_id, org_name, org_sufix, default_country_id, logo)
		VALUES(NEW.org_id, 2, NEW.business_name, NEW.org_id, NEW.country_id, 'logo.png');
		
		INSERT INTO address (address_name, sys_country_id, table_name, table_id, premises, town, phone_number, website, is_default) 
		VALUES (NEW.business_name, NEW.country_id, 'orgs', NEW.org_id, NEW.business_address, NEW.city, NEW.telephone, NEW.website, true);
		
		v_currency_id := nextval('currency_currency_id_seq');
		INSERT INTO currency (org_id, currency_id, currency_name, currency_symbol) VALUES (NEW.org_id, v_currency_id, 'Default Currency', 'DC');
		UPDATE orgs SET currency_id = v_currency_id WHERE org_id = NEW.org_id;
		
		INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (NEW.org_id, v_currency_id, 1);
		
		INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id)
		SELECT NEW.org_id, entity_type_name, entity_role, use_key_id
		FROM entity_types WHERE org_id = 1;
		
		INSERT INTO subscription_levels (org_id, subscription_level_name)
		SELECT NEW.org_id, subscription_level_name
		FROM subscription_levels WHERE org_id = 1;
		
		v_department_id := nextval('departments_department_id_seq');
		INSERT INTO departments (org_id, department_id, department_name) VALUES (NEW.org_id, v_department_id, 'Board of Directors');
		
		v_bank_id := nextval('banks_bank_id_seq');
		INSERT INTO banks (org_id, bank_id, bank_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		INSERT INTO bank_branch (org_id, bank_id, bank_branch_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		
		INSERT INTO transaction_counters(transaction_type_id, org_id, document_number)
		SELECT transaction_type_id, NEW.org_id, 1
		FROM transaction_types;
		
		INSERT INTO sys_emails (org_id, use_type,  sys_email_name, title, details) 
		SELECT NEW.org_id, use_type, sys_email_name, title, details
		FROM sys_emails
		WHERE org_id = 1;
		
		INSERT INTO accounts_class (org_id, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name)
		SELECT NEW.org_id, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name
		FROM accounts_class
		WHERE org_id = 1;
		
		INSERT INTO account_types (org_id, accounts_class_id, account_type_no, account_type_name)
		SELECT a.org_id, a.accounts_class_id, b.account_type_no, b.account_type_name
		FROM accounts_class a INNER JOIN vw_account_types b ON a.accounts_class_no = b.accounts_class_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO accounts (org_id, account_type_id, account_no, account_name)
		SELECT a.org_id, a.account_type_id, b.account_no, b.account_name
		FROM account_types a INNER JOIN vw_accounts b ON a.account_type_no = b.account_type_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO default_accounts (org_id, use_key_id, account_id)
		SELECT c.org_id, a.use_key_id, c.account_id
		FROM default_accounts a INNER JOIN accounts b ON a.account_id = b.account_id
			INNER JOIN accounts c ON b.account_no = c.account_no
		WHERE (a.org_id = 1) AND (c.org_id = NEW.org_id);
		
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Services');
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Goods');

		INSERT INTO item_units (org_id, item_unit_name) VALUES (NEW.org_id, 'Each');
		
		INSERT INTO stores (org_id, store_name) VALUES (NEW.org_id, 'Main Store');
		
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 0);
				
		UPDATE entitys SET org_id = NEW.org_id, entity_type_id = v_entity_type_id, function_role='subscription,admin,staff,finance'
		WHERE entity_id = NEW.entity_id;
		
		UPDATE entity_subscriptions SET entity_type_id = v_entity_type_id
		WHERE entity_id = NEW.entity_id;
		
		INSERT INTO workflows (link_copy, org_id, source_entity_id, workflow_name, table_name, approve_email, reject_email) 
		SELECT aa.workflow_id, cc.org_id, cc.entity_type_id, aa.workflow_name, aa.table_name, aa.approve_email, aa.reject_email
		FROM workflows aa INNER JOIN entity_types bb ON aa.source_entity_id = bb.entity_type_id
			INNER JOIN entity_types cc ON bb.use_key_id = cc.use_key_id
		WHERE aa.org_id = 1 AND cc.org_id = NEW.org_id
		ORDER BY aa.workflow_id;

		INSERT INTO workflow_phases (org_id, workflow_id, approval_entity_id, approval_level, return_level, 
			escalation_days, escalation_hours, required_approvals, advice, notice, 
			phase_narrative, advice_email, notice_email) 
		SELECT bb.org_id, bb.workflow_id, dd.entity_type_id, aa.approval_level, aa.return_level, 
			aa.escalation_days, aa.escalation_hours, aa.required_approvals, aa.advice, aa.notice, 
			aa.phase_narrative, aa.advice_email, aa.notice_email
		FROM workflow_phases aa INNER JOIN workflows bb ON aa.workflow_id = bb.link_copy
			INNER JOIN entity_types cc ON aa.approval_entity_id = cc.entity_type_id
			INNER JOIN entity_types dd ON cc.use_key_id = dd.use_key_id
		WHERE aa.org_id = 1 AND bb.org_id = NEW.org_id AND dd.org_id = NEW.org_id;
		
		INSERT INTO sys_emails (org_id, use_type, sys_email_name, title, details)
		SELECT NEW.org_id, use_type, sys_email_name, title, details
		FROM sys_emails
		WHERE org_id = 1;

		INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
		VALUES (4, NEW.org_id, NEW.entity_id, 'subscription');
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_subscriptions() OWNER TO postgres;

--
-- Name: ins_sys_reset(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sys_reset() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id			integer;
	v_org_id			integer;
	v_password			varchar(32);
BEGIN
	SELECT entity_id, org_id INTO v_entity_id, v_org_id
	FROM entitys
	WHERE (lower(trim(primary_email)) = lower(trim(NEW.request_email)));

	IF(v_entity_id is not null) THEN
		v_password := upper(substring(md5(random()::text) from 3 for 9));

		UPDATE entitys SET first_password = v_password, entity_password = md5(v_password)
		WHERE entity_id = v_entity_id;

		INSERT INTO sys_emailed (org_id, sys_email_id, table_id, table_name)
		VALUES(v_org_id, 3, v_entity_id, 'entitys');
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_sys_reset() OWNER TO postgres;

--
-- Name: ins_transactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_counter_id	integer;
	transid 		integer;
	currid			integer;
BEGIN

	IF(TG_OP = 'INSERT') THEN
		SELECT transaction_counter_id, document_number INTO v_counter_id, transid
		FROM transaction_counters 
		WHERE (transaction_type_id = NEW.transaction_type_id) AND (org_id = NEW.org_id);
		UPDATE transaction_counters SET document_number = transid + 1 
		WHERE (transaction_counter_id = v_counter_id);

		NEW.document_number := transid;
		IF(NEW.currency_id is null)THEN
			SELECT currency_id INTO NEW.currency_id
			FROM orgs
			WHERE (org_id = NEW.org_id);
		END IF;
				
		IF(NEW.payment_date is null) AND (NEW.transaction_date is not null)THEN
			NEW.payment_date := NEW.transaction_date;
		END IF;
	ELSE
			
		IF (OLD.journal_id is null) AND (NEW.journal_id is not null) THEN
		ELSIF ((OLD.approve_status != 'Completed') AND (NEW.approve_status = 'Completed')) THEN
			NEW.completed = true;
		ELSIF ((OLD.approve_status = 'Completed') AND (NEW.approve_status != 'Completed')) THEN
		ELSIF ((OLD.is_cleared = false) AND (NEW.is_cleared = true)) THEN
		ELSIF ((OLD.journal_id is not null) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already posted no changes are allowed.', NEW.transaction_id;
		ELSIF ((OLD.transaction_status_id > 1) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already completed no changes are allowed.', NEW.transaction_id;
		END IF;
	END IF;
	
	IF ((NEW.approve_status = 'Draft') AND (NEW.completed = true)) THEN
		NEW.approve_status := 'Completed';
		NEW.transaction_status_id := 2;
	END IF;
	
	IF(NEW.transaction_type_id = 7)THEN
		NEW.tx_type := 1;
	END IF;
	IF(NEW.transaction_type_id = 8)THEN
		NEW.tx_type := -1;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_transactions() OWNER TO postgres;

--
-- Name: open_periods(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION open_periods(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	msg					varchar(120);
BEGIN

	IF ($3 = '1') THEN
		UPDATE periods SET opened = true WHERE period_id = $1::int;
		msg := 'Period Opened';
	ELSIF ($3 = '2') THEN
		UPDATE periods SET closed = true WHERE period_id = $1::int;
		msg := 'Period Closed';
	ELSIF ($3 = '3') THEN
		UPDATE periods SET activated = true WHERE period_id = $1::int;
		msg := 'Period Activated';
	ELSIF ($3 = '4') THEN
		UPDATE periods SET activated = false WHERE period_id = $1::int;
		msg := 'Period De-activated';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.open_periods(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: payment_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION payment_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rnd 			integer;
	receipt_no  	varchar(12);
BEGIN
	receipt_no := trunc(random()*1000);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);
	receipt_no := receipt_no || trunc(random()*1000);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);

	NEW.payment_number:=receipt_no;
	---RAISE EXCEPTION '%',receipt_no;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.payment_number() OWNER TO postgres;

--
-- Name: payroll_payable(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION payroll_payable(integer, integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id				integer;
	v_org_name				varchar(50);
	v_org_client_id			integer;
	v_account_id			integer;
	v_entity_type_id		integer;
	v_bank_account_id		integer;
	reca					RECORD;
	msg						varchar(120);
BEGIN

	SELECT orgs.org_id, orgs.org_client_id, orgs.org_name INTO v_org_id, v_org_client_id, v_org_name
	FROM orgs INNER JOIN periods ON orgs.org_id = periods.org_id
	WHERE (periods.period_id = $1);
	
	IF(v_org_client_id is null)THEN
		SELECT account_id INTO v_account_id
		FROM default_accounts 
		WHERE (org_id = v_org_id) AND (use_key_id = 52);
		
		SELECT max(entity_type_id) INTO v_entity_type_id
		FROM entity_types
		WHERE (org_id = v_org_id) AND (use_key_id = 3);
		
		IF((v_account_id is not null) AND (v_entity_type_id is not null))THEN
			v_org_client_id := nextval('entitys_entity_id_seq');
			
			INSERT INTO entitys (entity_id, org_id, entity_type_id, account_id, entity_name, user_name, function_role, use_key_id)
			VALUES (v_org_client_id, v_org_id, v_entity_type_id, v_account_id, v_org_name, lower(trim(v_org_name)), 'supplier', 3);
		END IF;
	END IF;
	
	SELECT bank_account_id INTO v_bank_account_id
	FROM bank_accounts
	WHERE (org_id = v_org_id) AND (is_default = true);
	
	IF((v_org_client_id is not null) AND (v_bank_account_id is not null))THEN
		--- add transactions for banking payments	
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 1, a.pay_group_id, a.gl_payment_account, 'PAYROLL Payments ' || a.pay_group_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.b_banked),
			'PAYROLL Payments ' || a.pay_group_name
		FROM vw_ems a
		WHERE (a.period_id = $1)
		GROUP BY a.org_id, a.period_id, a.end_date, a.gl_payment_account, a.pay_group_id, a.currency_id, 
			a.exchange_rate, a.pay_group_name;

		--- add transactions for deduction remitance
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 2, a.adjustment_id, a.account_number, 'PAYROLL Deduction ' || a.adjustment_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.amount),
			'PAYROLL Deduction ' || a.adjustment_name
		FROM vw_employee_adjustments a
		WHERE (a.period_id = $1)
		GROUP BY a.currency_id, a.org_id, a.adjustment_id, a.account_number, a.adjustment_name, 
			a.exchange_rate, a.end_date;
			
		--- add transactions for tax remitance
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 3, a.tax_type_id, a.account_number, 'PAYROLL Tax ' || a.tax_type_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.amount + a.employer),
			'PAYROLL Tax ' || a.tax_type_name
		FROM vw_employee_tax_types a
		WHERE (a.period_id = $1)
		GROUP BY a.currency_id, a.org_id, a.tax_type_id, a.account_number, a.tax_type_name, 
			a.exchange_rate, a.end_date;
	END IF;
		
	RETURN msg;
END;
$_$;


ALTER FUNCTION public.payroll_payable(integer, integer) OWNER TO postgres;

--
-- Name: post_period_rentals(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION post_period_rentals(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
	DECLARE
		v_org_id			integer;
		v_use_key_id		integer;
		v_currency_id		integer;
		v_client_id			integer;
		v_status			varchar(50);
		v_total_rent		float;
		v_total_remmit		float;
		myrec				RECORD;
		msg					varchar(120);
	BEGIN
		IF ($3::int = 2) THEN
			SELECT status INTO v_status FROM period_rentals WHERE period_rental_id = $1::int;
			IF (v_status = 'Draft') THEN
				SELECT currency_id INTO v_currency_id FROM orgs WHERE is_active = true;

				FOR myrec IN SELECT org_id,entity_id,property_id,rental_id,period_id,rental_amount,service_fees,
				repair_amount,commision,commision_pct,status,narrative,sys_audit_trail_id FROM period_rentals
				WHERE status = 'Draft' AND period_rental_id = $1::int

				LOOP

					SELECT use_key_id INTO v_use_key_id FROM entitys WHERE is_active = true AND entity_id = myrec.entity_id;
					
					--SELECT client_id INTO v_client_id FROM vw_period_rentals  WHERE vw_period_rentals.rental_id = myrec.rental_id;
					
					v_total_rent = myrec.rental_amount+myrec.service_fees+myrec.repair_amount;
					v_total_remmit= myrec.rental_amount-myrec.commision;

					---Debit all tenants rental accounts
						INSERT INTO payments (payment_type_id,org_id,entity_id,property_id,rental_id,period_id,currency_id,tx_type,account_credit,account_debit,activity_name)
						VALUES(5,myrec.org_id,myrec.entity_id,myrec.property_id,myrec.rental_id,myrec.period_id,v_currency_id,1,0,v_total_rent::float,'Rental Billing');

					---Credit all Clients Property accounts
						INSERT INTO payments (payment_type_id,org_id,property_id,period_id,currency_id,tx_type,account_credit,account_debit,activity_name)
						VALUES(5,myrec.org_id,myrec.property_id,myrec.period_id,v_currency_id,-1,v_total_remmit::float,0,'Property Billing');				
						
					UPDATE period_rentals SET status = 'Posted' WHERE period_rental_id = $1::int;
				END LOOP;
					msg := 'Period Rental Posted';
			ELSE
				msg := 'Period Rental Already Posted';
			END IF;
		END IF;
		return msg;
	END;
$_$;


ALTER FUNCTION public.post_period_rentals(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: post_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION post_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec					RECORD;
	v_period_id			int;
	v_journal_id		int;
	msg					varchar(120);
BEGIN
	SELECT org_id, department_id, transaction_id, transaction_type_id, transaction_type_name as tx_name, 
		transaction_status_id, journal_id, gl_bank_account_id, currency_id, exchange_rate,
		transaction_date, transaction_amount, transaction_tax_amount, document_number, 
		credit_amount, debit_amount, entity_account_id, entity_name, approve_status, 
		ledger_account_id, tax_account_id, ledger_posting INTO rec
	FROM vw_transactions
	WHERE (transaction_id = CAST($1 as integer));

	v_period_id := get_open_period(rec.transaction_date);
	IF(v_period_id is null) THEN
		msg := 'No active period to post.';
		RAISE EXCEPTION 'No active period to post.';
	ELSIF(rec.journal_id is not null) THEN
		msg := 'Transaction previously Posted.';
		RAISE EXCEPTION 'Transaction previously Posted.';
	ELSIF(rec.transaction_status_id = 1) THEN
		msg := 'Transaction needs to be completed first.';
		RAISE EXCEPTION 'Transaction needs to be completed first.';
	ELSIF(rec.approve_status != 'Approved') THEN
		msg := 'Transaction is not yet approved.';
		RAISE EXCEPTION 'Transaction is not yet approved.';
	ELSIF((rec.ledger_account_id is not null) AND (rec.ledger_posting = false)) THEN
		msg := 'Transaction not for posting.';
		RAISE EXCEPTION 'Transaction not for posting.';
	ELSE
		v_journal_id := nextval('journals_journal_id_seq');
		INSERT INTO journals (journal_id, org_id, department_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (v_journal_id, rec.org_id, rec.department_id, rec.currency_id, v_period_id, rec.exchange_rate, rec.transaction_date, rec.tx_name || ' - posting for ' || rec.document_number);
		
		IF((rec.transaction_type_id = 7) or (rec.transaction_type_id = 8)) THEN
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.entity_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.gl_bank_account_id, rec.credit_amount, rec.debit_amount, rec.tx_name || ' - ' || rec.entity_name);
		ELSIF((rec.transaction_type_id = 21) or (rec.transaction_type_id = 22)) THEN		
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.gl_bank_account_id, rec.credit_amount, rec.debit_amount, rec.tx_name || ' - ' || rec.entity_name);
			
			IF(rec.transaction_tax_amount = 0)THEN
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);
			ELSIF(rec.transaction_type_id = 21)THEN
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount - rec.transaction_tax_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);
				
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.tax_account_id, rec.transaction_tax_amount, 0, rec.tx_name || ' - ' || rec.entity_name);
			ELSE
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount, rec.credit_amount - rec.transaction_tax_amount, rec.tx_name || ' - ' || rec.entity_name);
				
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.tax_account_id, 0, rec.transaction_tax_amount, rec.tx_name || ' - ' || rec.entity_name);			
			END IF;
		ELSE
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.entity_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, v_journal_id, trans_account_id, full_debit_amount, full_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_amount > 0);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, v_journal_id, tax_account_id, tax_debit_amount, tax_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_tax_amount > 0);
		END IF;

		UPDATE transactions SET journal_id = v_journal_id WHERE (transaction_id = rec.transaction_id);
		msg := process_journal(CAST(v_journal_id as varchar),'0','0');
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.post_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: prev_acct(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_acct(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT sum(gls.debit - gls.credit)
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) 
		AND (journals.journal_date < $2);
$_$;


ALTER FUNCTION public.prev_acct(integer, date) OWNER TO postgres;

--
-- Name: prev_balance(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_balance(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(transactions.exchange_rate * transactions.tx_type * transactions.transaction_amount), 0)::real
	FROM transactions
	WHERE (transactions.payment_date < $1) 
		AND (transactions.tx_type is not null);
$_$;


ALTER FUNCTION public.prev_balance(date) OWNER TO postgres;

--
-- Name: prev_base_acct(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_base_acct(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT sum(gls.debit * journals.exchange_rate - gls.credit * journals.exchange_rate) 
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) 
		AND (journals.journal_date < $2);
$_$;


ALTER FUNCTION public.prev_base_acct(integer, date) OWNER TO postgres;

--
-- Name: prev_base_returns(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_base_returns(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(base_credit - base_debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (journal_date < $1);
$_$;


ALTER FUNCTION public.prev_base_returns(date) OWNER TO postgres;

--
-- Name: prev_clear_balance(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_clear_balance(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(transactions.exchange_rate * transactions.tx_type * transactions.transaction_amount), 0)::real
	FROM transactions
	WHERE (transactions.payment_date < $1) AND (transactions.completed = true) 
		AND (transactions.is_cleared = true) AND (transactions.tx_type is not null);
$_$;


ALTER FUNCTION public.prev_clear_balance(date) OWNER TO postgres;

--
-- Name: prev_returns(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_returns(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(credit - debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (journal_date < $1);
$_$;


ALTER FUNCTION public.prev_returns(date) OWNER TO postgres;

--
-- Name: process_journal(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION process_journal(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	msg varchar(120);
BEGIN
	SELECT periods.start_date, periods.end_date, periods.opened, periods.closed, journals.journal_date, journals.posted, 
		sum(debit) as sum_debit, sum(credit) as sum_credit INTO rec
	FROM (periods INNER JOIN journals ON periods.period_id = journals.period_id)
		INNER JOIN gls ON journals.journal_id = gls.journal_id
	WHERE (journals.journal_id = CAST($1 as integer))
	GROUP BY periods.start_date, periods.end_date, periods.opened, periods.closed, journals.journal_date, journals.posted;

	IF(rec.posted = true) THEN
		msg := 'Journal previously Processed.';
	ELSIF((rec.start_date > rec.journal_date) OR (rec.end_date < rec.journal_date)) THEN
		msg := 'Journal date has to be within periods date.';
	ELSIF((rec.opened = false) OR (rec.closed = true)) THEN
		msg := 'Transaction period has to be opened and not closed.';
	ELSIF(rec.sum_debit <> rec.sum_credit) THEN
		msg := 'Cannot process Journal because credits do not equal debits.';
	ELSE
		UPDATE journals SET posted = true WHERE (journals.journal_id = CAST($1 as integer));
		msg := 'Journal Processed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.process_journal(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: process_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION process_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	bankacc INTEGER;
	msg varchar(120);
BEGIN
	SELECT org_id, transaction_id, transaction_type_id, transaction_status_id, transaction_amount INTO rec
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	IF(rec.transaction_status_id = 1) THEN
		msg := 'Transaction needs to be completed first.';
	ELSIF(rec.transaction_status_id = 2) THEN
		IF (($3 = '7') AND ($3 = '8')) THEN
			SELECT max(bank_account_id) INTO bankacc
			FROM bank_accounts WHERE (is_default = true);

			INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, bank_account_id, transaction_amount)
			SELECT transactions.org_id, transactions.department_id, transactions.entity_id, transactions.currency_id, 1, CURRENT_DATE, bankacc, 
				SUM(transaction_details.quantity * (transaction_details.amount + transaction_details.tax_amount))
			FROM transactions INNER JOIN transaction_details ON transactions.transaction_id = transaction_details.transaction_id
			WHERE (transactions.transaction_id = rec.transaction_id)
			GROUP BY transactions.transaction_id, transactions.entity_id;

			INSERT INTO transaction_links (org_id, transaction_id, transaction_to, amount)
			VALUES (rec.org_id, currval('transactions_transaction_id_seq'), rec.transaction_id, rec.transaction_amount);
		
			UPDATE transactions SET transaction_status_id = 3 WHERE transaction_id = rec.transaction_id;
		ELSE
			INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, order_number, payment_terms, job, narrative, details)
			SELECT org_id, department_id, entity_id, currency_id, CAST($3 as integer), CURRENT_DATE, order_number, payment_terms, job, narrative, details
			FROM transactions
			WHERE (transaction_id = rec.transaction_id);

			INSERT INTO transaction_details (org_id, transaction_id, account_id, item_id, quantity, amount, tax_amount, narrative, details)
			SELECT org_id, currval('transactions_transaction_id_seq'), account_id, item_id, quantity, amount, tax_amount, narrative, details
			FROM transaction_details
			WHERE (transaction_id = rec.transaction_id);

			INSERT INTO transaction_links (org_id, transaction_id, transaction_to, amount)
			VALUES (REC.org_id, currval('transactions_transaction_id_seq'), rec.transaction_id, rec.transaction_amount);

			UPDATE transactions SET transaction_status_id = 3 WHERE transaction_id = rec.transaction_id;
		END IF;
		msg := 'Transaction proccesed';
	ELSE
		msg := 'Transaction previously Processed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.process_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: un_archive(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION un_archive(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
	DECLARE
		msg				varchar(120);
	BEGIN
		IF($3::integer = 1)THEN
			UPDATE entitys SET is_active = true WHERE entity_id = $1::int;
		msg := 'Activated';
		END IF;

		IF($3::integer = 2)THEN
			UPDATE property SET is_active = true WHERE property_id = $1::int;
		msg := 'Activated';
		END IF;
		
RETURN msg;
END;
$_$;


ALTER FUNCTION public.un_archive(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_action(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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

		IF(TG_OP = 'UPDATE')THEN
			IF(OLD.workflow_table_id is not null)THEN
				INSERT INTO workflow_logs (org_id, table_name, table_id, table_old_id)
				VALUES (NEW.org_id, TG_TABLE_NAME, wfid, OLD.workflow_table_id);
			END IF;
		END IF;

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id= NEW.entity_id) LOOP
			iswf := true;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(TG_TABLE_NAME = 'entry_forms')THEN
					tbid := NEW.form_id;
				END IF;
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
$$;


ALTER FUNCTION public.upd_action() OWNER TO postgres;

--
-- Name: upd_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
	wfid	integer;
	vorgid	integer;
	vnotice	boolean;
	vadvice	boolean;
BEGIN

	SELECT notice, advice, org_id INTO vnotice, vadvice, vorgid
	FROM workflow_phases
	WHERE (workflow_phase_id = NEW.workflow_phase_id);

	IF (NEW.approve_status = 'Completed') THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vadvice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vnotice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 2, vorgid);
	END IF;

	IF(TG_OP = 'INSERT') AND (NEW.forward_id is null) THEN
		INSERT INTO approval_checklists (approval_id, checklist_id, requirement, manditory, org_id)
		SELECT NEW.approval_id, checklist_id, requirement, manditory, org_id
		FROM checklists
		WHERE (workflow_phase_id = NEW.workflow_phase_id)
		ORDER BY checklist_number;
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.upd_approvals() OWNER TO postgres;

--
-- Name: upd_approvals(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	app_id		Integer;
	reca 		RECORD;
	recb		RECORD;
	recc		RECORD;
	recd		RECORD;

	min_level	Integer;
	mysql		varchar(240);
	msg 		varchar(120);
BEGIN
	app_id := CAST($1 as int);
	SELECT approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id, 
		approvals.approval_level, approvals.review_advice,
		workflow_phases.workflow_phase_id, workflow_phases.workflow_id, workflow_phases.return_level INTO reca
	FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
	WHERE (approvals.approval_id = app_id);

	SELECT count(approval_checklist_id) as cl_count INTO recc
	FROM approval_checklists
	WHERE (approval_id = app_id) AND (manditory = true) AND (done = false);

	SELECT orgs.org_id, transactions.transaction_type_id, orgs.enforce_budget,
		get_budgeted(transactions.transaction_id, transactions.transaction_date, transactions.department_id) as budget_var 
		INTO recd
	FROM orgs INNER JOIN transactions ON orgs.org_id = transactions.org_id
	WHERE (transactions.workflow_table_id = reca.table_id);

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF (recd.transaction_type_id = 5) AND (recd.enforce_budget = true) AND (recd.budget_var < 0) THEN
		msg := 'You need a budget to approve the expenditure.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false);
		
		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved') 
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;

			INSERT INTO sys_emailed (table_id, table_name, email_type)
			VALUES (reca.table_id, 'vw_workflow_approvals', 1);
			
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level >= reca.approval_level) LOOP
				IF (recb.advice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level <= min_level) LOOP
				IF (recb.advice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				ELSE
					UPDATE approvals SET approve_status = 'Completed', completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		END IF;
		msg := 'Approved';
	ELSIF ($3 = '3') THEN
		UPDATE approvals SET approve_status = 'Rejected',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Rejected') 
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (reca.table_id, 'vw_workflow_approvals', 2, reca.org_id);
		msg := 'Rejected';
	ELSIF ($3 = '4') AND (reca.return_level = 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Draft')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		msg := 'Forwarded for review';
	ELSIF ($3 = '4') AND (reca.return_level <> 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, workflow_phase_id, reca.table_name, reca.table_id, CAST($2 as int), escalation_days, escalation_hours, approval_level, phase_narrative, reca.review_advice, 'Completed'
		FROM vw_workflow_entitys
		WHERE (workflow_id = reca.workflow_id) AND (approval_level = reca.return_level)
		ORDER BY workflow_phase_id;

		UPDATE approvals SET approve_status = 'Draft' WHERE approval_id = app_id;

		msg := 'Forwarded to owner for review';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_approvals(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_checklist(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_checklist(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	cl_id		Integer;
	reca 		RECORD;
	recc 		RECORD;
	msg 		varchar(120);
BEGIN
	cl_id := CAST($1 as int);

	SELECT approval_checklist_id, approval_id, checklist_id, requirement, manditory, done INTO reca
	FROM approval_checklists
	WHERE (approval_checklist_id = cl_id);

	IF ($3 = '1') THEN
		UPDATE approval_checklists SET done = true WHERE (approval_checklist_id = cl_id);

		SELECT count(approval_checklist_id) as cl_count INTO recc
		FROM approval_checklists
		WHERE (approval_id = reca.approval_id) AND (manditory = true) AND (done = false);
		msg := 'Checklist done.';

		IF(recc.cl_count = 0) THEN
			msg := upd_approvals(CAST(reca.approval_id as varchar(12)), $2, '2');
		END IF;
	ELSIF ($3 = '2') THEN
		UPDATE approval_checklists SET done = false WHERE (approval_checklist_id = cl_id);
		msg := 'Checklist not done.';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_checklist(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_complete_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_complete_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg varchar(120);
BEGIN
	IF ($3 = '1') THEN
		UPDATE entry_forms SET approve_status = 'Completed', completion_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Completed the form';
	ELSIF ($3 = '2') THEN
		UPDATE entry_forms SET approve_status = 'Approved', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Approved the form';
	ELSIF ($3 = '3') THEN
		UPDATE entry_forms SET approve_status = 'Rejected', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Rejected the form';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.upd_complete_form(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_gls(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_gls() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	isposted BOOLEAN;
BEGIN
	SELECT posted INTO isposted
	FROM journals 
	WHERE (journal_id = NEW.journal_id);

	IF (isposted = true) THEN
		RAISE EXCEPTION '% Journal is already posted no changes are allowed.', NEW.journal_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_gls() OWNER TO postgres;

--
-- Name: upd_transaction_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_transaction_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	statusID 	INTEGER;
	journalID 	INTEGER;
	v_for_sale	BOOLEAN;
	accountid 	INTEGER;
	taxrate 	REAL;
BEGIN
	SELECT transactions.transaction_status_id, transactions.journal_id, transaction_types.for_sales
		INTO statusID, journalID, v_for_sale
	FROM transaction_types INNER JOIN transactions ON transaction_types.transaction_type_id = transactions.transaction_type_id
	WHERE (transaction_id = NEW.transaction_id);

	IF ((statusID > 1) OR (journalID is not null)) THEN
		RAISE EXCEPTION 'Transaction is already posted no changes are allowed.';
	END IF;

	IF(v_for_sale = true)THEN
		SELECT items.sales_account_id, tax_types.tax_rate INTO accountid, taxrate
		FROM tax_types INNER JOIN items ON tax_types.tax_type_id = items.tax_type_id
		WHERE (items.item_id = NEW.item_id);
	ELSE
		SELECT items.purchase_account_id, tax_types.tax_rate INTO accountid, taxrate
		FROM tax_types INNER JOIN items ON tax_types.tax_type_id = items.tax_type_id
		WHERE (items.item_id = NEW.item_id);
	END IF;

	NEW.tax_amount := NEW.amount * taxrate / 100;
	IF(accountid is not null)THEN
		NEW.account_id := accountid;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_transaction_details() OWNER TO postgres;

--
-- Name: upd_trx_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_trx_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg							varchar(120);
BEGIN
	
	IF ($3 = '1') THEN
		UPDATE transactions SET for_processing = true WHERE transaction_id = $1::integer;
		msg := 'Opened for processing';
	ELSIF ($3 = '2') THEN
		UPDATE transactions SET for_processing = false WHERE transaction_id = $1::integer;
		msg := 'Closed for processing';
	ELSIF ($3 = '3') THEN
		UPDATE transactions  SET payment_date = current_date, completed = true
		WHERE transaction_id = $1::integer AND completed = false;
		msg := 'Completed';
	ELSIF ($3 = '4') THEN
		UPDATE transactions  SET is_cleared = true WHERE transaction_id = $1::integer;
		msg := 'Cleared for posting ';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_trx_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: account_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_types (
    account_type_id integer NOT NULL,
    account_type_no integer NOT NULL,
    accounts_class_id integer,
    org_id integer,
    account_type_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.account_types OWNER TO postgres;

--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_types_account_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_types_account_type_id_seq OWNER TO postgres;

--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_types_account_type_id_seq OWNED BY account_types.account_type_id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE accounts (
    account_id integer NOT NULL,
    account_no integer NOT NULL,
    account_type_id integer,
    org_id integer,
    account_name character varying(120) NOT NULL,
    is_header boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE accounts_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.accounts_account_id_seq OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE accounts_account_id_seq OWNED BY accounts.account_id;


--
-- Name: accounts_class; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE accounts_class (
    accounts_class_id integer NOT NULL,
    accounts_class_no integer NOT NULL,
    org_id integer,
    chat_type_id integer NOT NULL,
    chat_type_name character varying(50) NOT NULL,
    accounts_class_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.accounts_class OWNER TO postgres;

--
-- Name: accounts_class_accounts_class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE accounts_class_accounts_class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.accounts_class_accounts_class_id_seq OWNER TO postgres;

--
-- Name: accounts_class_accounts_class_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE accounts_class_accounts_class_id_seq OWNED BY accounts_class.accounts_class_id;


--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address (
    address_id integer NOT NULL,
    address_type_id integer,
    sys_country_id character(2),
    org_id integer,
    address_name character varying(120),
    table_name character varying(32),
    table_id integer,
    post_office_box character varying(50),
    postal_code character varying(12),
    premises character varying(120),
    street character varying(120),
    town character varying(50),
    phone_number character varying(150),
    extension character varying(15),
    mobile character varying(150),
    fax character varying(150),
    email character varying(120),
    website character varying(120),
    is_default boolean DEFAULT false NOT NULL,
    first_password character varying(32),
    details text
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_address_id_seq OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_address_id_seq OWNED BY address.address_id;


--
-- Name: address_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address_types (
    address_type_id integer NOT NULL,
    org_id integer,
    address_type_name character varying(50)
);


ALTER TABLE public.address_types OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_types_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_types_address_type_id_seq OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_types_address_type_id_seq OWNED BY address_types.address_type_id;


--
-- Name: approval_checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approval_checklists (
    approval_checklist_id integer NOT NULL,
    approval_id integer NOT NULL,
    checklist_id integer NOT NULL,
    org_id integer,
    requirement text,
    manditory boolean DEFAULT false NOT NULL,
    done boolean DEFAULT false NOT NULL,
    narrative character varying(320)
);


ALTER TABLE public.approval_checklists OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approval_checklists_approval_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approval_checklists_approval_checklist_id_seq OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approval_checklists_approval_checklist_id_seq OWNED BY approval_checklists.approval_checklist_id;


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approvals (
    approval_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_entity_id integer NOT NULL,
    app_entity_id integer,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    escalation_time timestamp without time zone DEFAULT now() NOT NULL,
    forward_id integer,
    table_name character varying(64),
    table_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    action_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    approval_narrative character varying(240),
    to_be_done text,
    what_is_done text,
    review_advice text,
    details text
);


ALTER TABLE public.approvals OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approvals_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approvals_approval_id_seq OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approvals_approval_id_seq OWNED BY approvals.approval_id;


--
-- Name: bank_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bank_accounts (
    bank_account_id integer NOT NULL,
    org_id integer,
    bank_branch_id integer,
    account_id integer,
    currency_id integer,
    bank_account_name character varying(120),
    bank_account_number character varying(50),
    narrative character varying(240),
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.bank_accounts OWNER TO postgres;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bank_accounts_bank_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bank_accounts_bank_account_id_seq OWNER TO postgres;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bank_accounts_bank_account_id_seq OWNED BY bank_accounts.bank_account_id;


--
-- Name: bank_branch; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bank_branch (
    bank_branch_id integer NOT NULL,
    bank_id integer,
    org_id integer,
    bank_branch_name character varying(50) NOT NULL,
    bank_branch_code character varying(50),
    narrative character varying(240)
);


ALTER TABLE public.bank_branch OWNER TO postgres;

--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bank_branch_bank_branch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bank_branch_bank_branch_id_seq OWNER TO postgres;

--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bank_branch_bank_branch_id_seq OWNED BY bank_branch.bank_branch_id;


--
-- Name: banks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE banks (
    bank_id integer NOT NULL,
    sys_country_id character(2),
    org_id integer,
    bank_name character varying(50) NOT NULL,
    bank_code character varying(25),
    swift_code character varying(25),
    sort_code character varying(25),
    narrative character varying(240)
);


ALTER TABLE public.banks OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE banks_bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.banks_bank_id_seq OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE banks_bank_id_seq OWNED BY banks.bank_id;


--
-- Name: checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE checklists (
    checklist_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    checklist_number integer,
    manditory boolean DEFAULT false NOT NULL,
    requirement text,
    details text
);


ALTER TABLE public.checklists OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE checklists_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.checklists_checklist_id_seq OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE checklists_checklist_id_seq OWNED BY checklists.checklist_id;


--
-- Name: currency; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency (
    currency_id integer NOT NULL,
    currency_name character varying(50),
    currency_symbol character varying(3),
    org_id integer
);


ALTER TABLE public.currency OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_currency_id_seq OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_currency_id_seq OWNED BY currency.currency_id;


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency_rates (
    currency_rate_id integer NOT NULL,
    currency_id integer,
    org_id integer,
    exchange_date date DEFAULT ('now'::text)::date NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL
);


ALTER TABLE public.currency_rates OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_rates_currency_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_rates_currency_rate_id_seq OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_rates_currency_rate_id_seq OWNED BY currency_rates.currency_rate_id;


--
-- Name: default_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE default_accounts (
    default_account_id integer NOT NULL,
    account_id integer,
    use_key_id integer NOT NULL,
    org_id integer,
    narrative character varying(240)
);


ALTER TABLE public.default_accounts OWNER TO postgres;

--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE default_accounts_default_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.default_accounts_default_account_id_seq OWNER TO postgres;

--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE default_accounts_default_account_id_seq OWNED BY default_accounts.default_account_id;


--
-- Name: default_tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE default_tax_types (
    default_tax_type_id integer NOT NULL,
    entity_id integer,
    tax_type_id integer,
    org_id integer,
    tax_identification character varying(50),
    narrative character varying(240),
    additional double precision DEFAULT 0 NOT NULL,
    active boolean DEFAULT true
);


ALTER TABLE public.default_tax_types OWNER TO postgres;

--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE default_tax_types_default_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.default_tax_types_default_tax_type_id_seq OWNER TO postgres;

--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE default_tax_types_default_tax_type_id_seq OWNED BY default_tax_types.default_tax_type_id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE departments (
    department_id integer NOT NULL,
    ln_department_id integer,
    org_id integer,
    department_name character varying(120),
    department_account character varying(50),
    function_code character varying(50),
    active boolean DEFAULT true NOT NULL,
    petty_cash boolean DEFAULT false NOT NULL,
    cost_center boolean DEFAULT true NOT NULL,
    revenue_center boolean DEFAULT true NOT NULL,
    description text,
    duties text,
    reports text,
    details text
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE departments_department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.departments_department_id_seq OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE departments_department_id_seq OWNED BY departments.department_id;


--
-- Name: entity_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_fields (
    entity_field_id integer NOT NULL,
    org_id integer NOT NULL,
    use_type integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true,
    entity_field_name character varying(240),
    entity_field_source character varying(320)
);


ALTER TABLE public.entity_fields OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_fields_entity_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_fields_entity_field_id_seq OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_fields_entity_field_id_seq OWNED BY entity_fields.entity_field_id;


--
-- Name: entity_subscriptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_subscriptions (
    entity_subscription_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    entity_id integer NOT NULL,
    subscription_level_id integer NOT NULL,
    org_id integer,
    details text
);


ALTER TABLE public.entity_subscriptions OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_subscriptions_entity_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_subscriptions_entity_subscription_id_seq OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_subscriptions_entity_subscription_id_seq OWNED BY entity_subscriptions.entity_subscription_id;


--
-- Name: entity_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_types (
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer,
    entity_type_name character varying(50) NOT NULL,
    entity_role character varying(240),
    start_view character varying(120),
    group_email character varying(120),
    description text,
    details text
);


ALTER TABLE public.entity_types OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_types_entity_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_types_entity_type_id_seq OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_types_entity_type_id_seq OWNED BY entity_types.entity_type_id;


--
-- Name: entity_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_values (
    entity_value_id integer NOT NULL,
    entity_id integer,
    entity_field_id integer,
    org_id integer,
    entity_value character varying(240)
);


ALTER TABLE public.entity_values OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_values_entity_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_values_entity_value_id_seq OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_values_entity_value_id_seq OWNED BY entity_values.entity_value_id;


--
-- Name: entitys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entitys (
    entity_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer NOT NULL,
    entity_name character varying(120) NOT NULL,
    user_name character varying(120) NOT NULL,
    primary_email character varying(120),
    primary_telephone character varying(50),
    super_user boolean DEFAULT false NOT NULL,
    entity_leader boolean DEFAULT false NOT NULL,
    no_org boolean DEFAULT false NOT NULL,
    function_role character varying(240),
    date_enroled timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    entity_password character varying(64) NOT NULL,
    first_password character varying(64) NOT NULL,
    new_password character varying(64),
    start_url character varying(64),
    is_picked boolean DEFAULT false NOT NULL,
    details text,
    attention character varying(50),
    credit_limit real DEFAULT 0,
    account_id integer
);


ALTER TABLE public.entitys OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entitys_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entitys_entity_id_seq OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entitys_entity_id_seq OWNED BY entitys.entity_id;


--
-- Name: entry_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entry_forms (
    entry_form_id integer NOT NULL,
    org_id integer,
    entity_id integer,
    form_id integer,
    entered_by_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(240),
    answer text,
    sub_answer text,
    details text
);


ALTER TABLE public.entry_forms OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entry_forms_entry_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entry_forms_entry_form_id_seq OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entry_forms_entry_form_id_seq OWNED BY entry_forms.entry_form_id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fields (
    field_id integer NOT NULL,
    org_id integer,
    form_id integer,
    field_name character varying(50),
    question text,
    field_lookup text,
    field_type character varying(25) NOT NULL,
    field_class character varying(25),
    field_bold character(1) DEFAULT '0'::bpchar NOT NULL,
    field_italics character(1) DEFAULT '0'::bpchar NOT NULL,
    field_order integer NOT NULL,
    share_line integer,
    field_size integer DEFAULT 25 NOT NULL,
    label_position character(1) DEFAULT 'L'::bpchar,
    field_fnct character varying(120),
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    tab character varying(25),
    details text
);


ALTER TABLE public.fields OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE fields_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fields_field_id_seq OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE fields_field_id_seq OWNED BY fields.field_id;


--
-- Name: fiscal_years; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fiscal_years (
    fiscal_year_id integer NOT NULL,
    fiscal_year character varying(9) NOT NULL,
    org_id integer,
    fiscal_year_start date NOT NULL,
    fiscal_year_end date NOT NULL,
    year_opened boolean DEFAULT true NOT NULL,
    year_closed boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.fiscal_years OWNER TO postgres;

--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE fiscal_years_fiscal_year_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fiscal_years_fiscal_year_id_seq OWNER TO postgres;

--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE fiscal_years_fiscal_year_id_seq OWNED BY fiscal_years.fiscal_year_id;


--
-- Name: forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE forms (
    form_id integer NOT NULL,
    org_id integer,
    form_name character varying(240) NOT NULL,
    form_number character varying(50),
    table_name character varying(50),
    version character varying(25),
    completed character(1) DEFAULT '0'::bpchar NOT NULL,
    is_active character(1) DEFAULT '0'::bpchar NOT NULL,
    use_key integer DEFAULT 0,
    form_header text,
    form_footer text,
    default_values text,
    details text
);


ALTER TABLE public.forms OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE forms_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.forms_form_id_seq OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE forms_form_id_seq OWNED BY forms.form_id;


--
-- Name: gls; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE gls (
    gl_id integer NOT NULL,
    journal_id integer NOT NULL,
    account_id integer NOT NULL,
    org_id integer,
    debit real DEFAULT 0 NOT NULL,
    credit real DEFAULT 0 NOT NULL,
    gl_narrative character varying(240)
);


ALTER TABLE public.gls OWNER TO postgres;

--
-- Name: gls_gl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE gls_gl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.gls_gl_id_seq OWNER TO postgres;

--
-- Name: gls_gl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE gls_gl_id_seq OWNED BY gls.gl_id;


--
-- Name: helpdesk; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE helpdesk (
    helpdesk_id integer NOT NULL,
    pdefinition_id integer,
    plevel_id integer,
    client_id integer,
    recorded_by integer,
    closed_by integer,
    org_id integer,
    description character varying(120) NOT NULL,
    reported_by character varying(50) NOT NULL,
    recoded_time timestamp without time zone DEFAULT now() NOT NULL,
    solved_time timestamp without time zone,
    is_solved boolean DEFAULT false NOT NULL,
    curr_action character varying(50),
    curr_status character varying(50),
    problem text,
    solution text,
    property_id integer
);


ALTER TABLE public.helpdesk OWNER TO postgres;

--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE helpdesk_helpdesk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.helpdesk_helpdesk_id_seq OWNER TO postgres;

--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE helpdesk_helpdesk_id_seq OWNED BY helpdesk.helpdesk_id;


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE holidays (
    holiday_id integer NOT NULL,
    org_id integer,
    holiday_name character varying(50) NOT NULL,
    holiday_date date,
    details text
);


ALTER TABLE public.holidays OWNER TO postgres;

--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE holidays_holiday_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.holidays_holiday_id_seq OWNER TO postgres;

--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE holidays_holiday_id_seq OWNED BY holidays.holiday_id;


--
-- Name: industry; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE industry (
    industry_id integer NOT NULL,
    org_id integer,
    industry_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.industry OWNER TO postgres;

--
-- Name: industry_industry_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE industry_industry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.industry_industry_id_seq OWNER TO postgres;

--
-- Name: industry_industry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE industry_industry_id_seq OWNED BY industry.industry_id;


--
-- Name: item_category; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE item_category (
    item_category_id integer NOT NULL,
    org_id integer,
    item_category_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.item_category OWNER TO postgres;

--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE item_category_item_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.item_category_item_category_id_seq OWNER TO postgres;

--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE item_category_item_category_id_seq OWNED BY item_category.item_category_id;


--
-- Name: item_units; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE item_units (
    item_unit_id integer NOT NULL,
    org_id integer,
    item_unit_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.item_units OWNER TO postgres;

--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE item_units_item_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.item_units_item_unit_id_seq OWNER TO postgres;

--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE item_units_item_unit_id_seq OWNED BY item_units.item_unit_id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE items (
    item_id integer NOT NULL,
    org_id integer,
    item_category_id integer,
    tax_type_id integer,
    item_unit_id integer,
    sales_account_id integer,
    purchase_account_id integer,
    item_name character varying(120),
    bar_code character varying(32),
    inventory boolean DEFAULT false NOT NULL,
    for_sale boolean DEFAULT true NOT NULL,
    for_purchase boolean DEFAULT true NOT NULL,
    sales_price real,
    purchase_price real,
    reorder_level integer,
    lead_time integer,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.items OWNER TO postgres;

--
-- Name: items_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE items_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.items_item_id_seq OWNER TO postgres;

--
-- Name: items_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE items_item_id_seq OWNED BY items.item_id;


--
-- Name: journals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE journals (
    journal_id integer NOT NULL,
    period_id integer NOT NULL,
    currency_id integer,
    department_id integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    journal_date date NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    year_closing boolean DEFAULT false NOT NULL,
    narrative character varying(240),
    details text
);


ALTER TABLE public.journals OWNER TO postgres;

--
-- Name: journals_journal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE journals_journal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.journals_journal_id_seq OWNER TO postgres;

--
-- Name: journals_journal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE journals_journal_id_seq OWNED BY journals.journal_id;


--
-- Name: ledger_links; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ledger_links (
    ledger_link_id integer NOT NULL,
    ledger_type_id integer,
    org_id integer,
    link_type integer,
    link_id integer
);


ALTER TABLE public.ledger_links OWNER TO postgres;

--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ledger_links_ledger_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ledger_links_ledger_link_id_seq OWNER TO postgres;

--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ledger_links_ledger_link_id_seq OWNED BY ledger_links.ledger_link_id;


--
-- Name: ledger_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ledger_types (
    ledger_type_id integer NOT NULL,
    account_id integer,
    tax_account_id integer,
    org_id integer,
    ledger_type_name character varying(120) NOT NULL,
    ledger_posting boolean DEFAULT true NOT NULL,
    income_ledger boolean DEFAULT true NOT NULL,
    expense_ledger boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.ledger_types OWNER TO postgres;

--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ledger_types_ledger_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ledger_types_ledger_type_id_seq OWNER TO postgres;

--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ledger_types_ledger_type_id_seq OWNED BY ledger_types.ledger_type_id;


--
-- Name: log_period_rentals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE log_period_rentals (
    log_period_rental_id integer NOT NULL,
    sys_audit_trail_id integer,
    period_rental_id integer,
    rental_id integer,
    period_id integer,
    org_id integer,
    rental_amount double precision,
    service_fees double precision,
    repair_amount double precision,
    commision double precision,
    commision_pct double precision,
    status character varying(50),
    narrative character varying(240)
);


ALTER TABLE public.log_period_rentals OWNER TO postgres;

--
-- Name: log_period_rentals_log_period_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE log_period_rentals_log_period_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_period_rentals_log_period_rental_id_seq OWNER TO postgres;

--
-- Name: log_period_rentals_log_period_rental_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE log_period_rentals_log_period_rental_id_seq OWNED BY log_period_rentals.log_period_rental_id;


--
-- Name: orgs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orgs (
    org_id integer NOT NULL,
    currency_id integer,
    default_country_id character(2),
    parent_org_id integer,
    org_name character varying(50) NOT NULL,
    org_full_name character varying(120),
    org_sufix character varying(4) NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    logo character varying(50),
    pin character varying(50),
    pcc character varying(12),
    system_key character varying(64),
    system_identifier character varying(64),
    mac_address character varying(64),
    public_key bytea,
    license bytea,
    details text,
    org_client_id integer,
    payroll_payable boolean DEFAULT true NOT NULL,
    cert_number character varying(50),
    vat_number character varying(50),
    enforce_budget boolean DEFAULT true NOT NULL,
    invoice_footer text,
    expiry_date date
);


ALTER TABLE public.orgs OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orgs_org_id_seq OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_id_seq OWNED BY orgs.org_id;


--
-- Name: payment_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE payment_types (
    payment_type_id integer NOT NULL,
    account_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer,
    payment_type_name character varying(120) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.payment_types OWNER TO postgres;

--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE payment_types_payment_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payment_types_payment_type_id_seq OWNER TO postgres;

--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE payment_types_payment_type_id_seq OWNED BY payment_types.payment_type_id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE payments (
    payment_id integer NOT NULL,
    payment_type_id integer,
    currency_id integer,
    period_id integer,
    entity_id integer,
    property_id integer,
    rental_id integer,
    org_id integer,
    journal_id integer,
    sys_audit_trail_id integer,
    payment_number character varying(50),
    payment_date date DEFAULT ('now'::text)::date NOT NULL,
    tx_type integer DEFAULT 1 NOT NULL,
    account_credit real DEFAULT 0 NOT NULL,
    account_debit real DEFAULT 0 NOT NULL,
    balance real NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL,
    activity_name character varying(50),
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE payments_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payments_payment_id_seq OWNER TO postgres;

--
-- Name: payments_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE payments_payment_id_seq OWNED BY payments.payment_id;


--
-- Name: pdefinitions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pdefinitions (
    pdefinition_id integer NOT NULL,
    ptype_id integer,
    org_id integer,
    pdefinition_name character varying(50) NOT NULL,
    description text,
    solution text
);


ALTER TABLE public.pdefinitions OWNER TO postgres;

--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pdefinitions_pdefinition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdefinitions_pdefinition_id_seq OWNER TO postgres;

--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pdefinitions_pdefinition_id_seq OWNED BY pdefinitions.pdefinition_id;


--
-- Name: period_rentals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE period_rentals (
    period_rental_id integer NOT NULL,
    rental_id integer,
    period_id integer,
    property_id integer,
    entity_id integer,
    sys_audit_trail_id integer,
    org_id integer,
    rental_amount double precision NOT NULL,
    service_fees double precision NOT NULL,
    repair_amount double precision DEFAULT 0 NOT NULL,
    commision double precision NOT NULL,
    commision_pct double precision NOT NULL,
    status character varying(50) DEFAULT 'Draft'::character varying NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.period_rentals OWNER TO postgres;

--
-- Name: period_rentals_period_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE period_rentals_period_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.period_rentals_period_rental_id_seq OWNER TO postgres;

--
-- Name: period_rentals_period_rental_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE period_rentals_period_rental_id_seq OWNED BY period_rentals.period_rental_id;


--
-- Name: period_tax_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE period_tax_rates (
    period_tax_rate_id integer NOT NULL,
    period_tax_type_id integer,
    tax_rate_id integer,
    org_id integer,
    tax_range double precision NOT NULL,
    tax_rate double precision NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.period_tax_rates OWNER TO postgres;

--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE period_tax_rates_period_tax_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.period_tax_rates_period_tax_rate_id_seq OWNER TO postgres;

--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE period_tax_rates_period_tax_rate_id_seq OWNED BY period_tax_rates.period_tax_rate_id;


--
-- Name: period_tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE period_tax_types (
    period_tax_type_id integer NOT NULL,
    period_id integer,
    tax_type_id integer,
    account_id integer,
    org_id integer,
    period_tax_type_name character varying(50) NOT NULL,
    pay_date date DEFAULT ('now'::text)::date NOT NULL,
    formural character varying(320),
    tax_relief real DEFAULT 0 NOT NULL,
    percentage boolean DEFAULT true NOT NULL,
    linear boolean DEFAULT true NOT NULL,
    tax_type_order integer DEFAULT 0 NOT NULL,
    in_tax boolean DEFAULT false NOT NULL,
    employer double precision NOT NULL,
    employer_ps double precision NOT NULL,
    account_number character varying(32),
    details text
);


ALTER TABLE public.period_tax_types OWNER TO postgres;

--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE period_tax_types_period_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.period_tax_types_period_tax_type_id_seq OWNER TO postgres;

--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE period_tax_types_period_tax_type_id_seq OWNED BY period_tax_types.period_tax_type_id;


--
-- Name: periods; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE periods (
    period_id integer NOT NULL,
    fiscal_year_id integer,
    org_id integer,
    start_date date NOT NULL,
    end_date date NOT NULL,
    opened boolean DEFAULT false NOT NULL,
    activated boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    overtime_rate double precision DEFAULT 1 NOT NULL,
    per_diem_tax_limit double precision DEFAULT 2000 NOT NULL,
    is_posted boolean DEFAULT false NOT NULL,
    loan_approval boolean DEFAULT false NOT NULL,
    gl_payroll_account character varying(32),
    gl_advance_account character varying(32),
    entity_id integer,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.periods OWNER TO postgres;

--
-- Name: periods_period_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE periods_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.periods_period_id_seq OWNER TO postgres;

--
-- Name: periods_period_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE periods_period_id_seq OWNED BY periods.period_id;


--
-- Name: picture_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE picture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.picture_id_seq OWNER TO postgres;

--
-- Name: plevels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE plevels (
    plevel_id integer NOT NULL,
    org_id integer,
    plevel_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.plevels OWNER TO postgres;

--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE plevels_plevel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.plevels_plevel_id_seq OWNER TO postgres;

--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE plevels_plevel_id_seq OWNED BY plevels.plevel_id;


--
-- Name: property; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE property (
    property_id integer NOT NULL,
    property_type_id integer,
    entity_id integer,
    org_id integer,
    property_name character varying(50),
    estate character varying(50),
    plot_no character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    units integer,
    rental_value double precision DEFAULT 0 NOT NULL,
    service_fees double precision DEFAULT 0 NOT NULL,
    commision_value double precision DEFAULT 0 NOT NULL,
    commision_pct double precision DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.property OWNER TO postgres;

--
-- Name: property_property_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE property_property_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.property_property_id_seq OWNER TO postgres;

--
-- Name: property_property_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE property_property_id_seq OWNED BY property.property_id;


--
-- Name: property_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE property_types (
    property_type_id integer NOT NULL,
    org_id integer,
    property_type_name character varying(50),
    commercial_property boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.property_types OWNER TO postgres;

--
-- Name: property_types_property_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE property_types_property_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.property_types_property_type_id_seq OWNER TO postgres;

--
-- Name: property_types_property_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE property_types_property_type_id_seq OWNED BY property_types.property_type_id;


--
-- Name: ptypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ptypes (
    ptype_id integer NOT NULL,
    org_id integer,
    ptype_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.ptypes OWNER TO postgres;

--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ptypes_ptype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ptypes_ptype_id_seq OWNER TO postgres;

--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ptypes_ptype_id_seq OWNED BY ptypes.ptype_id;


--
-- Name: quotations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE quotations (
    quotation_id integer NOT NULL,
    org_id integer,
    item_id integer,
    entity_id integer,
    active boolean DEFAULT false NOT NULL,
    amount real,
    valid_from date,
    valid_to date,
    lead_time integer,
    details text
);


ALTER TABLE public.quotations OWNER TO postgres;

--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE quotations_quotation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.quotations_quotation_id_seq OWNER TO postgres;

--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE quotations_quotation_id_seq OWNED BY quotations.quotation_id;


--
-- Name: rentals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE rentals (
    rental_id integer NOT NULL,
    property_id integer,
    entity_id integer,
    org_id integer,
    start_rent date,
    hse_no character varying(10),
    elec_no character varying(50),
    water_no character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    rental_value double precision NOT NULL,
    service_fees double precision NOT NULL,
    commision_value double precision NOT NULL,
    commision_pct double precision NOT NULL,
    deposit_fee double precision,
    deposit_fee_date date,
    deposit_refund double precision,
    deposit_refund_date date,
    details text
);


ALTER TABLE public.rentals OWNER TO postgres;

--
-- Name: rentals_rental_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE rentals_rental_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rentals_rental_id_seq OWNER TO postgres;

--
-- Name: rentals_rental_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE rentals_rental_id_seq OWNED BY rentals.rental_id;


--
-- Name: reporting; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE reporting (
    reporting_id integer NOT NULL,
    entity_id integer,
    report_to_id integer,
    org_id integer,
    date_from date,
    date_to date,
    reporting_level integer DEFAULT 1 NOT NULL,
    primary_report boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    ps_reporting real,
    details text
);


ALTER TABLE public.reporting OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reporting_reporting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reporting_reporting_id_seq OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reporting_reporting_id_seq OWNED BY reporting.reporting_id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE stores (
    store_id integer NOT NULL,
    org_id integer,
    store_name character varying(120),
    details text
);


ALTER TABLE public.stores OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE stores_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stores_store_id_seq OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE stores_store_id_seq OWNED BY stores.store_id;


--
-- Name: sub_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sub_fields (
    sub_field_id integer NOT NULL,
    org_id integer,
    field_id integer,
    sub_field_order integer NOT NULL,
    sub_title_share character varying(120),
    sub_field_type character varying(25),
    sub_field_lookup text,
    sub_field_size integer NOT NULL,
    sub_col_spans integer DEFAULT 1 NOT NULL,
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    question text
);


ALTER TABLE public.sub_fields OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sub_fields_sub_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sub_fields_sub_field_id_seq OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sub_fields_sub_field_id_seq OWNED BY sub_fields.sub_field_id;


--
-- Name: subscription_levels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subscription_levels (
    subscription_level_id integer NOT NULL,
    org_id integer,
    subscription_level_name character varying(50),
    details text
);


ALTER TABLE public.subscription_levels OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE subscription_levels_subscription_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscription_levels_subscription_level_id_seq OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE subscription_levels_subscription_level_id_seq OWNED BY subscription_levels.subscription_level_id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subscriptions (
    subscription_id integer NOT NULL,
    entity_id integer,
    account_manager_id integer,
    org_id integer,
    business_name character varying(50),
    business_address character varying(100),
    city character varying(30),
    state character varying(50),
    country_id character(2),
    number_of_employees integer,
    telephone character varying(50),
    website character varying(120),
    primary_contact character varying(120),
    job_title character varying(120),
    primary_email character varying(120),
    confirm_email character varying(120),
    system_key character varying(64),
    subscribed boolean,
    subscribed_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    application_date timestamp without time zone DEFAULT now(),
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.subscriptions OWNER TO postgres;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE subscriptions_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscriptions_subscription_id_seq OWNER TO postgres;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE subscriptions_subscription_id_seq OWNED BY subscriptions.subscription_id;


--
-- Name: sys_audit_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_details (
    sys_audit_trail_id integer NOT NULL,
    old_value text
);


ALTER TABLE public.sys_audit_details OWNER TO postgres;

--
-- Name: sys_audit_trail; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_trail (
    sys_audit_trail_id integer NOT NULL,
    user_id character varying(50) NOT NULL,
    user_ip character varying(50),
    change_date timestamp without time zone DEFAULT now() NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(50) NOT NULL,
    change_type character varying(50) NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.sys_audit_trail OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_audit_trail_sys_audit_trail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_audit_trail_sys_audit_trail_id_seq OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_audit_trail_sys_audit_trail_id_seq OWNED BY sys_audit_trail.sys_audit_trail_id;


--
-- Name: sys_continents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_continents (
    sys_continent_id character(2) NOT NULL,
    sys_continent_name character varying(120)
);


ALTER TABLE public.sys_continents OWNER TO postgres;

--
-- Name: sys_countrys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_countrys (
    sys_country_id character(2) NOT NULL,
    sys_continent_id character(2),
    sys_country_code character varying(3),
    sys_country_number character varying(3),
    sys_phone_code character varying(3),
    sys_country_name character varying(120),
    sys_currency_name character varying(50),
    sys_currency_cents character varying(50),
    sys_currency_code character varying(3),
    sys_currency_exchange real
);


ALTER TABLE public.sys_countrys OWNER TO postgres;

--
-- Name: sys_dashboard; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_dashboard (
    sys_dashboard_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    narrative character varying(240),
    details text
);


ALTER TABLE public.sys_dashboard OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_dashboard_sys_dashboard_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_dashboard_sys_dashboard_id_seq OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_dashboard_sys_dashboard_id_seq OWNED BY sys_dashboard.sys_dashboard_id;


--
-- Name: sys_emailed; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emailed (
    sys_emailed_id integer NOT NULL,
    sys_email_id integer,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    email_type integer DEFAULT 1 NOT NULL,
    emailed boolean DEFAULT false NOT NULL,
    created timestamp without time zone DEFAULT now(),
    narrative character varying(240),
    mail_body text
);


ALTER TABLE public.sys_emailed OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emailed_sys_emailed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emailed_sys_emailed_id_seq OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emailed_sys_emailed_id_seq OWNED BY sys_emailed.sys_emailed_id;


--
-- Name: sys_emails; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emails (
    sys_email_id integer NOT NULL,
    org_id integer,
    use_type integer DEFAULT 1 NOT NULL,
    sys_email_name character varying(50),
    default_email character varying(320),
    title character varying(240) NOT NULL,
    details text
);


ALTER TABLE public.sys_emails OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emails_sys_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emails_sys_email_id_seq OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emails_sys_email_id_seq OWNED BY sys_emails.sys_email_id;


--
-- Name: sys_errors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_errors (
    sys_error_id integer NOT NULL,
    sys_error character varying(240) NOT NULL,
    error_message text NOT NULL
);


ALTER TABLE public.sys_errors OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_errors_sys_error_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_errors_sys_error_id_seq OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_errors_sys_error_id_seq OWNED BY sys_errors.sys_error_id;


--
-- Name: sys_files; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_files (
    sys_file_id integer NOT NULL,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    file_name character varying(320),
    file_type character varying(320),
    file_size integer,
    narrative character varying(320),
    details text
);


ALTER TABLE public.sys_files OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_files_sys_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_files_sys_file_id_seq OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_files_sys_file_id_seq OWNED BY sys_files.sys_file_id;


--
-- Name: sys_logins; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_logins (
    sys_login_id integer NOT NULL,
    entity_id integer,
    login_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_logins OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_logins_sys_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_logins_sys_login_id_seq OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_logins_sys_login_id_seq OWNED BY sys_logins.sys_login_id;


--
-- Name: sys_menu_msg; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_menu_msg (
    sys_menu_msg_id integer NOT NULL,
    menu_id character varying(16) NOT NULL,
    menu_name character varying(50) NOT NULL,
    xml_file character varying(50) NOT NULL,
    msg text
);


ALTER TABLE public.sys_menu_msg OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_menu_msg_sys_menu_msg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_menu_msg_sys_menu_msg_id_seq OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_menu_msg_sys_menu_msg_id_seq OWNED BY sys_menu_msg.sys_menu_msg_id;


--
-- Name: sys_news; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_news (
    sys_news_id integer NOT NULL,
    org_id integer,
    sys_news_group integer,
    sys_news_title character varying(240) NOT NULL,
    publish boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.sys_news OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_news_sys_news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_news_sys_news_id_seq OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_news_sys_news_id_seq OWNED BY sys_news.sys_news_id;


--
-- Name: sys_queries; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_queries (
    sys_queries_id integer NOT NULL,
    org_id integer,
    sys_query_name character varying(50),
    query_date timestamp without time zone DEFAULT now() NOT NULL,
    query_text text,
    query_params text
);


ALTER TABLE public.sys_queries OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_queries_sys_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_queries_sys_queries_id_seq OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_queries_sys_queries_id_seq OWNED BY sys_queries.sys_queries_id;


--
-- Name: sys_reset; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_reset (
    sys_reset_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    request_email character varying(320),
    request_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_reset OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_reset_sys_reset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_reset_sys_reset_id_seq OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_reset_sys_reset_id_seq OWNED BY sys_reset.sys_reset_id;


--
-- Name: tax_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tax_rates (
    tax_rate_id integer NOT NULL,
    tax_type_id integer,
    org_id integer,
    tax_range double precision NOT NULL,
    tax_rate double precision NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.tax_rates OWNER TO postgres;

--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tax_rates_tax_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tax_rates_tax_rate_id_seq OWNER TO postgres;

--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tax_rates_tax_rate_id_seq OWNED BY tax_rates.tax_rate_id;


--
-- Name: tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tax_types (
    tax_type_id integer NOT NULL,
    account_id integer,
    currency_id integer,
    use_key_id integer NOT NULL,
    sys_country_id character(2),
    org_id integer,
    tax_type_name character varying(50) NOT NULL,
    tax_type_number character varying(50),
    formural character varying(320),
    tax_relief real DEFAULT 0 NOT NULL,
    tax_type_order integer DEFAULT 0 NOT NULL,
    in_tax boolean DEFAULT false NOT NULL,
    tax_rate real DEFAULT 0 NOT NULL,
    tax_inclusive boolean DEFAULT false NOT NULL,
    linear boolean DEFAULT true,
    percentage boolean DEFAULT true,
    employer double precision DEFAULT 0 NOT NULL,
    employer_ps double precision DEFAULT 0 NOT NULL,
    account_number character varying(32),
    employer_account character varying(32),
    active boolean DEFAULT true,
    details text
);


ALTER TABLE public.tax_types OWNER TO postgres;

--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tax_types_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tax_types_tax_type_id_seq OWNER TO postgres;

--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tax_types_tax_type_id_seq OWNED BY tax_types.tax_type_id;


--
-- Name: tomcat_users; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW tomcat_users AS
 SELECT entitys.user_name,
    entitys.entity_password,
    entity_types.entity_role
   FROM ((entity_subscriptions
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
  WHERE (entitys.is_active = true);


ALTER TABLE public.tomcat_users OWNER TO postgres;

--
-- Name: transaction_counters; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_counters (
    transaction_counter_id integer NOT NULL,
    transaction_type_id integer,
    org_id integer,
    document_number integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.transaction_counters OWNER TO postgres;

--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_counters_transaction_counter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_counters_transaction_counter_id_seq OWNER TO postgres;

--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_counters_transaction_counter_id_seq OWNED BY transaction_counters.transaction_counter_id;


--
-- Name: transaction_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_details (
    transaction_detail_id integer NOT NULL,
    transaction_id integer,
    account_id integer,
    item_id integer,
    store_id integer,
    org_id integer,
    quantity integer NOT NULL,
    amount real DEFAULT 0 NOT NULL,
    tax_amount real DEFAULT 0 NOT NULL,
    narrative character varying(240),
    purpose character varying(320),
    details text
);


ALTER TABLE public.transaction_details OWNER TO postgres;

--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_details_transaction_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_details_transaction_detail_id_seq OWNER TO postgres;

--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_details_transaction_detail_id_seq OWNED BY transaction_details.transaction_detail_id;


--
-- Name: transaction_links; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_links (
    transaction_link_id integer NOT NULL,
    org_id integer,
    transaction_id integer,
    transaction_to integer,
    transaction_detail_id integer,
    transaction_detail_to integer,
    amount real DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.transaction_links OWNER TO postgres;

--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_links_transaction_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_links_transaction_link_id_seq OWNER TO postgres;

--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_links_transaction_link_id_seq OWNED BY transaction_links.transaction_link_id;


--
-- Name: transaction_status; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_status (
    transaction_status_id integer NOT NULL,
    transaction_status_name character varying(50) NOT NULL
);


ALTER TABLE public.transaction_status OWNER TO postgres;

--
-- Name: transaction_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_types (
    transaction_type_id integer NOT NULL,
    transaction_type_name character varying(50) NOT NULL,
    document_prefix character varying(16) DEFAULT 'D'::character varying NOT NULL,
    for_sales boolean DEFAULT true NOT NULL,
    for_posting boolean DEFAULT true NOT NULL
);


ALTER TABLE public.transaction_types OWNER TO postgres;

--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transactions (
    transaction_id integer NOT NULL,
    entity_id integer,
    transaction_type_id integer,
    ledger_type_id integer,
    transaction_status_id integer DEFAULT 1,
    bank_account_id integer,
    journal_id integer,
    currency_id integer,
    department_id integer,
    entered_by integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    transaction_date date NOT NULL,
    payment_date date NOT NULL,
    transaction_amount real DEFAULT 0 NOT NULL,
    transaction_tax_amount real DEFAULT 0 NOT NULL,
    document_number integer DEFAULT 1 NOT NULL,
    tx_type integer,
    for_processing boolean DEFAULT false NOT NULL,
    is_cleared boolean DEFAULT false NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    reference_number character varying(50),
    payment_number character varying(50),
    order_number character varying(50),
    payment_terms character varying(50),
    job character varying(240),
    point_of_use character varying(240),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(120),
    details text,
    property_id integer
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transactions_transaction_id_seq OWNED BY transactions.transaction_id;


--
-- Name: use_keys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE use_keys (
    use_key_id integer NOT NULL,
    use_key_name character varying(32) NOT NULL,
    use_function integer
);


ALTER TABLE public.use_keys OWNER TO postgres;

--
-- Name: vw_account_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_account_types AS
 SELECT accounts_class.accounts_class_id,
    accounts_class.accounts_class_no,
    accounts_class.accounts_class_name,
    accounts_class.chat_type_id,
    accounts_class.chat_type_name,
    account_types.account_type_id,
    account_types.account_type_no,
    account_types.org_id,
    account_types.account_type_name,
    account_types.details
   FROM (account_types
     JOIN accounts_class ON ((account_types.accounts_class_id = accounts_class.accounts_class_id)));


ALTER TABLE public.vw_account_types OWNER TO postgres;

--
-- Name: vw_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_accounts AS
 SELECT vw_account_types.chat_type_id,
    vw_account_types.chat_type_name,
    vw_account_types.accounts_class_id,
    vw_account_types.accounts_class_no,
    vw_account_types.accounts_class_name,
    vw_account_types.account_type_id,
    vw_account_types.account_type_no,
    vw_account_types.account_type_name,
    accounts.account_id,
    accounts.account_no,
    accounts.org_id,
    accounts.account_name,
    accounts.is_header,
    accounts.is_active,
    accounts.details,
    ((((((accounts.account_no || ' : '::text) || (vw_account_types.accounts_class_name)::text) || ' : '::text) || (vw_account_types.account_type_name)::text) || ' : '::text) || (accounts.account_name)::text) AS account_description
   FROM (accounts
     JOIN vw_account_types ON ((accounts.account_type_id = vw_account_types.account_type_id)));


ALTER TABLE public.vw_accounts OWNER TO postgres;

--
-- Name: vw_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    address.address_id,
    address.org_id,
    address.address_name,
    address.table_name,
    address.table_id,
    address.post_office_box,
    address.postal_code,
    address.premises,
    address.street,
    address.town,
    address.phone_number,
    address.extension,
    address.mobile,
    address.fax,
    address.email,
    address.is_default,
    address.website,
    address.details,
    address_types.address_type_id,
    address_types.address_type_name
   FROM ((address
     JOIN sys_countrys ON ((address.sys_country_id = sys_countrys.sys_country_id)))
     LEFT JOIN address_types ON ((address.address_type_id = address_types.address_type_id)));


ALTER TABLE public.vw_address OWNER TO postgres;

--
-- Name: vw_address_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address_entitys AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_address_entitys OWNER TO postgres;

--
-- Name: workflows; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflows (
    workflow_id integer NOT NULL,
    source_entity_id integer NOT NULL,
    org_id integer,
    workflow_name character varying(240) NOT NULL,
    table_name character varying(64),
    table_link_field character varying(64),
    table_link_id integer,
    approve_email text NOT NULL,
    reject_email text NOT NULL,
    approve_file character varying(320),
    reject_file character varying(320),
    link_copy integer,
    details text
);


ALTER TABLE public.workflows OWNER TO postgres;

--
-- Name: vw_workflows; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflows AS
 SELECT entity_types.entity_type_id AS source_entity_id,
    entity_types.entity_type_name AS source_entity_name,
    workflows.workflow_id,
    workflows.org_id,
    workflows.workflow_name,
    workflows.table_name,
    workflows.table_link_field,
    workflows.table_link_id,
    workflows.approve_email,
    workflows.reject_email,
    workflows.approve_file,
    workflows.reject_file,
    workflows.details
   FROM (workflows
     JOIN entity_types ON ((workflows.source_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflows OWNER TO postgres;

--
-- Name: workflow_phases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_phases (
    workflow_phase_id integer NOT NULL,
    workflow_id integer NOT NULL,
    approval_entity_id integer NOT NULL,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    return_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    required_approvals integer DEFAULT 1 NOT NULL,
    reporting_level integer DEFAULT 1 NOT NULL,
    use_reporting boolean DEFAULT false NOT NULL,
    advice boolean DEFAULT false NOT NULL,
    notice boolean DEFAULT false NOT NULL,
    phase_narrative character varying(240) NOT NULL,
    advice_email text,
    notice_email text,
    advice_file character varying(320),
    notice_file character varying(320),
    details text
);


ALTER TABLE public.workflow_phases OWNER TO postgres;

--
-- Name: vw_workflow_phases; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_phases AS
 SELECT vw_workflows.source_entity_id,
    vw_workflows.source_entity_name,
    vw_workflows.workflow_id,
    vw_workflows.workflow_name,
    vw_workflows.table_name,
    vw_workflows.table_link_field,
    vw_workflows.table_link_id,
    vw_workflows.approve_email,
    vw_workflows.reject_email,
    vw_workflows.approve_file,
    vw_workflows.reject_file,
    entity_types.entity_type_id AS approval_entity_id,
    entity_types.entity_type_name AS approval_entity_name,
    workflow_phases.workflow_phase_id,
    workflow_phases.org_id,
    workflow_phases.approval_level,
    workflow_phases.return_level,
    workflow_phases.escalation_days,
    workflow_phases.escalation_hours,
    workflow_phases.notice,
    workflow_phases.notice_email,
    workflow_phases.notice_file,
    workflow_phases.advice,
    workflow_phases.advice_email,
    workflow_phases.advice_file,
    workflow_phases.required_approvals,
    workflow_phases.use_reporting,
    workflow_phases.reporting_level,
    workflow_phases.phase_narrative,
    workflow_phases.details
   FROM ((workflow_phases
     JOIN vw_workflows ON ((workflow_phases.workflow_id = vw_workflows.workflow_id)))
     JOIN entity_types ON ((workflow_phases.approval_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflow_phases OWNER TO postgres;

--
-- Name: vw_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.approve_email,
    vw_workflow_phases.reject_email,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    ae.entity_id AS app_entity_id,
    ae.entity_name AS app_entity_name,
    ae.user_name AS app_user_name,
    ae.primary_email AS app_primary_email
   FROM (((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     LEFT JOIN entitys ae ON ((approvals.app_entity_id = ae.entity_id)));


ALTER TABLE public.vw_approvals OWNER TO postgres;

--
-- Name: vw_approvals_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN entity_subscriptions ON ((vw_workflow_phases.approval_entity_id = entity_subscriptions.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
  WHERE ((approvals.forward_id IS NULL) AND (vw_workflow_phases.use_reporting = false))
UNION
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN reporting ON (((approvals.org_entity_id = reporting.entity_id) AND (vw_workflow_phases.reporting_level = reporting.reporting_level))))
     JOIN entitys ON ((reporting.report_to_id = entitys.entity_id)))
  WHERE ((((approvals.forward_id IS NULL) AND (reporting.primary_report = true)) AND (reporting.is_active = true)) AND (vw_workflow_phases.use_reporting = true));


ALTER TABLE public.vw_approvals_entitys OWNER TO postgres;

--
-- Name: vw_bank_branch; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_bank_branch AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_code,
    sys_countrys.sys_country_name,
    banks.bank_id,
    banks.bank_name,
    banks.bank_code,
    banks.swift_code,
    banks.sort_code,
    bank_branch.bank_branch_id,
    bank_branch.org_id,
    bank_branch.bank_branch_name,
    bank_branch.bank_branch_code,
    bank_branch.narrative
   FROM ((bank_branch
     JOIN banks ON ((bank_branch.bank_id = banks.bank_id)))
     LEFT JOIN sys_countrys ON ((banks.sys_country_id = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_bank_branch OWNER TO postgres;

--
-- Name: vw_bank_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_bank_accounts AS
 SELECT vw_bank_branch.bank_id,
    vw_bank_branch.bank_name,
    vw_bank_branch.bank_branch_id,
    vw_bank_branch.bank_branch_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    bank_accounts.bank_account_id,
    bank_accounts.org_id,
    bank_accounts.bank_account_name,
    bank_accounts.bank_account_number,
    bank_accounts.narrative,
    bank_accounts.is_active,
    bank_accounts.details
   FROM (((bank_accounts
     JOIN vw_bank_branch ON ((bank_accounts.bank_branch_id = vw_bank_branch.bank_branch_id)))
     JOIN vw_accounts ON ((bank_accounts.account_id = vw_accounts.account_id)))
     JOIN currency ON ((bank_accounts.currency_id = currency.currency_id)));


ALTER TABLE public.vw_bank_accounts OWNER TO postgres;

--
-- Name: vw_budget_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_ledger AS
 SELECT journals.org_id,
    periods.fiscal_year_id,
    journals.department_id,
    accounts.account_id,
    accounts.account_no,
    accounts.account_type_id,
    accounts.account_name,
    sum((journals.exchange_rate * gls.debit)) AS bl_debit,
    sum((journals.exchange_rate * gls.credit)) AS bl_credit,
    sum((journals.exchange_rate * (gls.debit - gls.credit))) AS bl_diff
   FROM (((journals
     JOIN gls ON ((journals.journal_id = gls.journal_id)))
     JOIN accounts ON ((gls.account_id = accounts.account_id)))
     JOIN periods ON ((journals.period_id = periods.period_id)))
  WHERE (journals.posted = true)
  GROUP BY journals.org_id, periods.fiscal_year_id, journals.department_id, accounts.account_id, accounts.account_no, accounts.account_type_id, accounts.account_name;


ALTER TABLE public.vw_budget_ledger OWNER TO postgres;

--
-- Name: vw_periods; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_periods AS
 SELECT fiscal_years.fiscal_year_id,
    fiscal_years.fiscal_year,
    fiscal_years.fiscal_year_start,
    fiscal_years.fiscal_year_end,
    fiscal_years.year_opened,
    fiscal_years.year_closed,
    periods.period_id,
    periods.org_id,
    periods.start_date,
    periods.end_date,
    periods.opened,
    periods.activated,
    periods.closed,
    periods.overtime_rate,
    periods.per_diem_tax_limit,
    periods.is_posted,
    periods.gl_payroll_account,
    periods.gl_advance_account,
    periods.details,
    date_part('month'::text, periods.start_date) AS month_id,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY'::text) AS period_year,
    to_char((periods.start_date)::timestamp with time zone, 'Month'::text) AS period_month,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY, Month'::text) AS period_disp,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (3)::double precision)) + (1)::double precision) AS quarter,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (6)::double precision)) + (1)::double precision) AS semister,
    to_char((periods.start_date)::timestamp with time zone, 'YYYYMM'::text) AS period_code
   FROM (periods
     LEFT JOIN fiscal_years ON ((periods.fiscal_year_id = fiscal_years.fiscal_year_id)))
  ORDER BY periods.start_date;


ALTER TABLE public.vw_periods OWNER TO postgres;

--
-- Name: vw_property; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_property AS
 SELECT entitys.entity_id AS client_id,
    entitys.entity_name AS client_name,
    property_types.property_type_id,
    property_types.property_type_name,
    property.org_id,
    property.property_id,
    property.property_name,
    property.estate,
    property.plot_no,
    property.is_active,
    property.units,
    property.rental_value,
    property.service_fees,
    property.commision_value,
    property.commision_pct,
    property.details,
    get_occupied(property.property_id) AS accupied,
    (property.units - get_occupied(property.property_id)) AS vacant
   FROM ((property
     JOIN entitys ON ((property.entity_id = entitys.entity_id)))
     JOIN property_types ON ((property.property_type_id = property_types.property_type_id)));


ALTER TABLE public.vw_property OWNER TO postgres;

--
-- Name: vw_client_bill; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_client_bill AS
 SELECT payment_types.account_id,
    payment_types.use_key_id,
    payment_types.payment_type_name,
    payment_types.is_active,
    payments.payment_id,
    payments.payment_type_id,
    payments.currency_id,
    payments.period_id,
    payments.entity_id,
    payments.rental_id,
    payments.org_id,
    payments.journal_id,
    payments.payment_number,
    payments.payment_date,
    payments.tx_type,
    payments.account_credit,
    payments.account_debit,
    payments.balance,
    payments.exchange_rate,
    payments.activity_name,
    payments.action_date,
    currency.currency_name,
    currency.currency_symbol,
    vw_property.client_id,
    vw_property.client_name,
    vw_property.property_type_id,
    vw_property.property_type_name,
    vw_property.property_id,
    vw_property.property_name,
    vw_property.estate,
    vw_property.plot_no,
    vw_property.units,
    vw_periods.period_disp,
    vw_periods.period_month
   FROM ((((payments
     JOIN currency ON ((currency.currency_id = payments.currency_id)))
     JOIN vw_periods ON ((vw_periods.period_id = payments.period_id)))
     JOIN payment_types ON ((payment_types.payment_type_id = payments.payment_type_id)))
     JOIN vw_property ON ((vw_property.client_id = payments.entity_id)))
  WHERE (payments.tx_type = (-1));


ALTER TABLE public.vw_client_bill OWNER TO postgres;

--
-- Name: vw_client_property; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_client_property AS
 SELECT entitys.entity_id,
    entitys.entity_name AS client_name,
    property_types.property_type_id,
    property_types.property_type_name,
    property.org_id,
    property.property_id,
    property.property_name,
    property.estate,
    property.plot_no,
    property.is_active,
    property.units,
    property.details,
    get_occupied(property.property_id) AS accupied,
    (property.units - get_occupied(property.property_id)) AS vacant
   FROM ((property
     JOIN entitys ON ((property.entity_id = entitys.entity_id)))
     JOIN property_types ON ((property.property_type_id = property_types.property_type_id)));


ALTER TABLE public.vw_client_property OWNER TO postgres;

--
-- Name: vw_curr_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_curr_orgs AS
 SELECT currency.currency_id AS base_currency_id,
    currency.currency_name AS base_currency_name,
    currency.currency_symbol AS base_currency_symbol,
    orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.cert_number,
    orgs.pin,
    orgs.vat_number,
    orgs.invoice_footer,
    orgs.details
   FROM (orgs
     JOIN currency ON ((orgs.currency_id = currency.currency_id)));


ALTER TABLE public.vw_curr_orgs OWNER TO postgres;

--
-- Name: vw_default_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_default_accounts AS
 SELECT vw_accounts.accounts_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.accounts_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    default_accounts.default_account_id,
    default_accounts.org_id,
    default_accounts.narrative
   FROM ((vw_accounts
     JOIN default_accounts ON ((vw_accounts.account_id = default_accounts.account_id)))
     JOIN use_keys ON ((default_accounts.use_key_id = use_keys.use_key_id)));


ALTER TABLE public.vw_default_accounts OWNER TO postgres;

--
-- Name: vw_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tax_types AS
 SELECT vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    tax_types.org_id,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.formural,
    tax_types.tax_relief,
    tax_types.tax_type_order,
    tax_types.in_tax,
    tax_types.tax_rate,
    tax_types.tax_inclusive,
    tax_types.linear,
    tax_types.percentage,
    tax_types.employer,
    tax_types.employer_ps,
    tax_types.account_number,
    tax_types.employer_account,
    tax_types.active,
    tax_types.tax_type_number,
    tax_types.details
   FROM (((tax_types
     JOIN currency ON ((tax_types.currency_id = currency.currency_id)))
     JOIN use_keys ON ((tax_types.use_key_id = use_keys.use_key_id)))
     LEFT JOIN vw_accounts ON ((tax_types.account_id = vw_accounts.account_id)));


ALTER TABLE public.vw_tax_types OWNER TO postgres;

--
-- Name: vw_default_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_default_tax_types AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    vw_tax_types.tax_type_id,
    vw_tax_types.tax_type_name,
    vw_tax_types.tax_type_number,
    vw_tax_types.currency_id,
    vw_tax_types.currency_name,
    vw_tax_types.currency_symbol,
    default_tax_types.default_tax_type_id,
    default_tax_types.org_id,
    default_tax_types.tax_identification,
    default_tax_types.active,
    default_tax_types.narrative
   FROM ((default_tax_types
     JOIN entitys ON ((default_tax_types.entity_id = entitys.entity_id)))
     JOIN vw_tax_types ON ((default_tax_types.tax_type_id = vw_tax_types.tax_type_id)));


ALTER TABLE public.vw_default_tax_types OWNER TO postgres;

--
-- Name: vw_departments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_departments AS
 SELECT departments.ln_department_id,
    p_departments.department_name AS ln_department_name,
    departments.department_id,
    departments.org_id,
    departments.department_name,
    departments.active,
    departments.function_code,
    departments.petty_cash,
    departments.cost_center,
    departments.revenue_center,
    departments.description,
    departments.duties,
    departments.reports,
    departments.details
   FROM (departments
     LEFT JOIN departments p_departments ON ((departments.ln_department_id = p_departments.department_id)));


ALTER TABLE public.vw_departments OWNER TO postgres;

--
-- Name: vw_entity_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_address AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_entity_address OWNER TO postgres;

--
-- Name: vw_entity_subscriptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_subscriptions AS
 SELECT entity_types.entity_type_id,
    entity_types.entity_type_name,
    entitys.entity_id,
    entitys.entity_name,
    subscription_levels.subscription_level_id,
    subscription_levels.subscription_level_name,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.org_id,
    entity_subscriptions.details
   FROM (((entity_subscriptions
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN subscription_levels ON ((entity_subscriptions.subscription_level_id = subscription_levels.subscription_level_id)));


ALTER TABLE public.vw_entity_subscriptions OWNER TO postgres;

--
-- Name: vw_entity_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_types AS
 SELECT use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    entity_types.entity_type_id,
    entity_types.org_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entity_types.start_view,
    entity_types.group_email,
    entity_types.description,
    entity_types.details
   FROM (use_keys
     JOIN entity_types ON ((use_keys.use_key_id = entity_types.use_key_id)));


ALTER TABLE public.vw_entity_types OWNER TO postgres;

--
-- Name: vw_entity_values; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_values AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    entity_fields.entity_field_id,
    entity_fields.entity_field_name,
    entity_values.org_id,
    entity_values.entity_value_id,
    entity_values.entity_value
   FROM ((entity_values
     JOIN entitys ON ((entity_values.entity_id = entitys.entity_id)))
     JOIN entity_fields ON ((entity_values.entity_field_id = entity_fields.entity_field_id)));


ALTER TABLE public.vw_entity_values OWNER TO postgres;

--
-- Name: vw_org_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_address AS
 SELECT vw_address.sys_country_id AS org_sys_country_id,
    vw_address.sys_country_name AS org_sys_country_name,
    vw_address.address_id AS org_address_id,
    vw_address.table_id AS org_table_id,
    vw_address.table_name AS org_table_name,
    vw_address.post_office_box AS org_post_office_box,
    vw_address.postal_code AS org_postal_code,
    vw_address.premises AS org_premises,
    vw_address.street AS org_street,
    vw_address.town AS org_town,
    vw_address.phone_number AS org_phone_number,
    vw_address.extension AS org_extension,
    vw_address.mobile AS org_mobile,
    vw_address.fax AS org_fax,
    vw_address.email AS org_email,
    vw_address.website AS org_website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'orgs'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_org_address OWNER TO postgres;

--
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_orgs AS
 SELECT orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.org_full_name,
    orgs.pin,
    orgs.pcc,
    orgs.details,
    orgs.cert_number,
    orgs.vat_number,
    orgs.invoice_footer,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_org_address.org_sys_country_id,
    vw_org_address.org_sys_country_name,
    vw_org_address.org_address_id,
    vw_org_address.org_table_name,
    vw_org_address.org_post_office_box,
    vw_org_address.org_postal_code,
    vw_org_address.org_premises,
    vw_org_address.org_street,
    vw_org_address.org_town,
    vw_org_address.org_phone_number,
    vw_org_address.org_extension,
    vw_org_address.org_mobile,
    vw_org_address.org_fax,
    vw_org_address.org_email,
    vw_org_address.org_website
   FROM ((orgs
     JOIN currency ON ((orgs.currency_id = currency.currency_id)))
     LEFT JOIN vw_org_address ON ((orgs.org_id = vw_org_address.org_table_id)));


ALTER TABLE public.vw_orgs OWNER TO postgres;

--
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entitys AS
 SELECT vw_orgs.org_id,
    vw_orgs.org_name,
    vw_orgs.is_default AS org_is_default,
    vw_orgs.is_active AS org_is_active,
    vw_orgs.logo AS org_logo,
    vw_orgs.cert_number AS org_cert_number,
    vw_orgs.pin AS org_pin,
    vw_orgs.vat_number AS org_vat_number,
    vw_orgs.invoice_footer AS org_invoice_footer,
    vw_orgs.org_sys_country_id,
    vw_orgs.org_sys_country_name,
    vw_orgs.org_address_id,
    vw_orgs.org_table_name,
    vw_orgs.org_post_office_box,
    vw_orgs.org_postal_code,
    vw_orgs.org_premises,
    vw_orgs.org_street,
    vw_orgs.org_town,
    vw_orgs.org_phone_number,
    vw_orgs.org_extension,
    vw_orgs.org_mobile,
    vw_orgs.org_fax,
    vw_orgs.org_email,
    vw_orgs.org_website,
    addr.address_id,
    addr.address_name,
    addr.sys_country_id,
    addr.sys_country_name,
    addr.table_name,
    addr.is_default,
    addr.post_office_box,
    addr.postal_code,
    addr.premises,
    addr.street,
    addr.town,
    addr.phone_number,
    addr.extension,
    addr.mobile,
    addr.fax,
    addr.email,
    addr.website,
    entity_types.entity_type_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entitys.entity_id,
    entitys.use_key_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.super_user,
    entitys.entity_leader,
    entitys.date_enroled,
    entitys.is_active,
    entitys.entity_password,
    entitys.first_password,
    entitys.function_role,
    entitys.attention,
    entitys.primary_email,
    entitys.primary_telephone,
    entitys.credit_limit
   FROM (((entitys
     LEFT JOIN vw_address_entitys addr ON ((entitys.entity_id = addr.table_id)))
     JOIN vw_orgs ON ((entitys.org_id = vw_orgs.org_id)))
     JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_entitys OWNER TO postgres;

--
-- Name: vw_entry_forms; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entry_forms AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    forms.form_id,
    forms.form_name,
    forms.form_number,
    forms.completed,
    forms.is_active,
    forms.use_key,
    entry_forms.org_id,
    entry_forms.entry_form_id,
    entry_forms.approve_status,
    entry_forms.application_date,
    entry_forms.completion_date,
    entry_forms.action_date,
    entry_forms.narrative,
    entry_forms.answer,
    entry_forms.workflow_table_id,
    entry_forms.details
   FROM ((entry_forms
     JOIN entitys ON ((entry_forms.entity_id = entitys.entity_id)))
     JOIN forms ON ((entry_forms.form_id = forms.form_id)));


ALTER TABLE public.vw_entry_forms OWNER TO postgres;

--
-- Name: vw_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_fields AS
 SELECT forms.form_id,
    forms.form_name,
    fields.field_id,
    fields.org_id,
    fields.question,
    fields.field_lookup,
    fields.field_type,
    fields.field_order,
    fields.share_line,
    fields.field_size,
    fields.field_fnct,
    fields.manditory,
    fields.field_bold,
    fields.field_italics
   FROM (fields
     JOIN forms ON ((fields.form_id = forms.form_id)));


ALTER TABLE public.vw_fields OWNER TO postgres;

--
-- Name: vw_journals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_journals AS
 SELECT vw_periods.fiscal_year_id,
    vw_periods.fiscal_year_start,
    vw_periods.fiscal_year_end,
    vw_periods.year_opened,
    vw_periods.year_closed,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.opened,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    departments.department_id,
    departments.department_name,
    journals.journal_id,
    journals.org_id,
    journals.journal_date,
    journals.posted,
    journals.year_closing,
    journals.narrative,
    journals.exchange_rate,
    journals.details
   FROM (((journals
     JOIN vw_periods ON ((journals.period_id = vw_periods.period_id)))
     JOIN currency ON ((journals.currency_id = currency.currency_id)))
     LEFT JOIN departments ON ((journals.department_id = departments.department_id)));


ALTER TABLE public.vw_journals OWNER TO postgres;

--
-- Name: vw_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_gls AS
 SELECT vw_accounts.accounts_class_id,
    vw_accounts.accounts_class_no,
    vw_accounts.accounts_class_name,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_no,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    vw_journals.fiscal_year_id,
    vw_journals.fiscal_year_start,
    vw_journals.fiscal_year_end,
    vw_journals.year_opened,
    vw_journals.year_closed,
    vw_journals.period_id,
    vw_journals.start_date,
    vw_journals.end_date,
    vw_journals.opened,
    vw_journals.closed,
    vw_journals.month_id,
    vw_journals.period_year,
    vw_journals.period_month,
    vw_journals.quarter,
    vw_journals.semister,
    vw_journals.currency_id,
    vw_journals.currency_name,
    vw_journals.currency_symbol,
    vw_journals.exchange_rate,
    vw_journals.journal_id,
    vw_journals.journal_date,
    vw_journals.posted,
    vw_journals.year_closing,
    vw_journals.narrative,
    gls.gl_id,
    gls.org_id,
    gls.debit,
    gls.credit,
    gls.gl_narrative,
    (gls.debit * vw_journals.exchange_rate) AS base_debit,
    (gls.credit * vw_journals.exchange_rate) AS base_credit
   FROM ((gls
     JOIN vw_accounts ON ((gls.account_id = vw_accounts.account_id)))
     JOIN vw_journals ON ((gls.journal_id = vw_journals.journal_id)));


ALTER TABLE public.vw_gls OWNER TO postgres;

--
-- Name: vw_pdefinitions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pdefinitions AS
 SELECT ptypes.ptype_id,
    ptypes.ptype_name,
    pdefinitions.org_id,
    pdefinitions.pdefinition_id,
    pdefinitions.pdefinition_name,
    pdefinitions.description,
    pdefinitions.solution
   FROM (pdefinitions
     JOIN ptypes ON ((pdefinitions.ptype_id = ptypes.ptype_id)));


ALTER TABLE public.vw_pdefinitions OWNER TO postgres;

--
-- Name: vw_helpdesk; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_helpdesk AS
 SELECT vw_pdefinitions.ptype_id,
    vw_pdefinitions.ptype_name,
    vw_pdefinitions.pdefinition_id,
    vw_pdefinitions.pdefinition_name,
    plevels.plevel_id,
    plevels.plevel_name,
    helpdesk.client_id,
    clients.entity_name AS client_name,
    helpdesk.recorded_by,
    recorder.entity_name AS recorder_name,
    helpdesk.closed_by,
    closer.entity_name AS closer_name,
    helpdesk.org_id,
    helpdesk.helpdesk_id,
    helpdesk.description,
    helpdesk.reported_by,
    helpdesk.recoded_time,
    helpdesk.solved_time,
    helpdesk.is_solved,
    helpdesk.curr_action,
    helpdesk.curr_status,
    helpdesk.problem,
    helpdesk.solution
   FROM (((((helpdesk
     JOIN vw_pdefinitions ON ((helpdesk.pdefinition_id = vw_pdefinitions.pdefinition_id)))
     JOIN plevels ON ((helpdesk.plevel_id = plevels.plevel_id)))
     JOIN entitys clients ON ((helpdesk.client_id = clients.entity_id)))
     JOIN entitys recorder ON ((helpdesk.recorded_by = recorder.entity_id)))
     LEFT JOIN entitys closer ON ((helpdesk.closed_by = closer.entity_id)));


ALTER TABLE public.vw_helpdesk OWNER TO postgres;

--
-- Name: vw_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_items AS
 SELECT sales_account.account_id AS sales_account_id,
    sales_account.account_name AS sales_account_name,
    purchase_account.account_id AS purchase_account_id,
    purchase_account.account_name AS purchase_account_name,
    item_category.item_category_id,
    item_category.item_category_name,
    item_units.item_unit_id,
    item_units.item_unit_name,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.account_id AS tax_account_id,
    tax_types.tax_rate,
    tax_types.tax_inclusive,
    items.item_id,
    items.org_id,
    items.item_name,
    items.inventory,
    items.bar_code,
    items.for_sale,
    items.for_purchase,
    items.sales_price,
    items.purchase_price,
    items.reorder_level,
    items.lead_time,
    items.is_active,
    items.details
   FROM (((((items
     JOIN accounts sales_account ON ((items.sales_account_id = sales_account.account_id)))
     JOIN accounts purchase_account ON ((items.purchase_account_id = purchase_account.account_id)))
     JOIN item_category ON ((items.item_category_id = item_category.item_category_id)))
     JOIN item_units ON ((items.item_unit_id = item_units.item_unit_id)))
     JOIN tax_types ON ((items.tax_type_id = tax_types.tax_type_id)));


ALTER TABLE public.vw_items OWNER TO postgres;

--
-- Name: vw_sm_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sm_gls AS
 SELECT vw_gls.org_id,
    vw_gls.accounts_class_id,
    vw_gls.accounts_class_no,
    vw_gls.accounts_class_name,
    vw_gls.chat_type_id,
    vw_gls.chat_type_name,
    vw_gls.account_type_id,
    vw_gls.account_type_no,
    vw_gls.account_type_name,
    vw_gls.account_id,
    vw_gls.account_no,
    vw_gls.account_name,
    vw_gls.is_header,
    vw_gls.is_active,
    vw_gls.fiscal_year_id,
    vw_gls.fiscal_year_start,
    vw_gls.fiscal_year_end,
    vw_gls.year_opened,
    vw_gls.year_closed,
    vw_gls.period_id,
    vw_gls.start_date,
    vw_gls.end_date,
    vw_gls.opened,
    vw_gls.closed,
    vw_gls.month_id,
    vw_gls.period_year,
    vw_gls.period_month,
    vw_gls.quarter,
    vw_gls.semister,
    sum(vw_gls.debit) AS acc_debit,
    sum(vw_gls.credit) AS acc_credit,
    sum(vw_gls.base_debit) AS acc_base_debit,
    sum(vw_gls.base_credit) AS acc_base_credit
   FROM vw_gls
  WHERE (vw_gls.posted = true)
  GROUP BY vw_gls.org_id, vw_gls.accounts_class_id, vw_gls.accounts_class_no, vw_gls.accounts_class_name, vw_gls.chat_type_id, vw_gls.chat_type_name, vw_gls.account_type_id, vw_gls.account_type_no, vw_gls.account_type_name, vw_gls.account_id, vw_gls.account_no, vw_gls.account_name, vw_gls.is_header, vw_gls.is_active, vw_gls.fiscal_year_id, vw_gls.fiscal_year_start, vw_gls.fiscal_year_end, vw_gls.year_opened, vw_gls.year_closed, vw_gls.period_id, vw_gls.start_date, vw_gls.end_date, vw_gls.opened, vw_gls.closed, vw_gls.month_id, vw_gls.period_year, vw_gls.period_month, vw_gls.quarter, vw_gls.semister
  ORDER BY vw_gls.account_id;


ALTER TABLE public.vw_sm_gls OWNER TO postgres;

--
-- Name: vw_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ledger AS
 SELECT vw_sm_gls.org_id,
    vw_sm_gls.accounts_class_id,
    vw_sm_gls.accounts_class_no,
    vw_sm_gls.accounts_class_name,
    vw_sm_gls.chat_type_id,
    vw_sm_gls.chat_type_name,
    vw_sm_gls.account_type_id,
    vw_sm_gls.account_type_no,
    vw_sm_gls.account_type_name,
    vw_sm_gls.account_id,
    vw_sm_gls.account_no,
    vw_sm_gls.account_name,
    vw_sm_gls.is_header,
    vw_sm_gls.is_active,
    vw_sm_gls.fiscal_year_id,
    vw_sm_gls.fiscal_year_start,
    vw_sm_gls.fiscal_year_end,
    vw_sm_gls.year_opened,
    vw_sm_gls.year_closed,
    vw_sm_gls.period_id,
    vw_sm_gls.start_date,
    vw_sm_gls.end_date,
    vw_sm_gls.opened,
    vw_sm_gls.closed,
    vw_sm_gls.month_id,
    vw_sm_gls.period_year,
    vw_sm_gls.period_month,
    vw_sm_gls.quarter,
    vw_sm_gls.semister,
    vw_sm_gls.acc_debit,
    vw_sm_gls.acc_credit,
    (vw_sm_gls.acc_debit - vw_sm_gls.acc_credit) AS acc_balance,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_debit > vw_sm_gls.acc_credit) THEN (vw_sm_gls.acc_debit - vw_sm_gls.acc_credit)
            ELSE (0)::real
        END, (0)::real) AS bal_debit,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_debit < vw_sm_gls.acc_credit) THEN (vw_sm_gls.acc_credit - vw_sm_gls.acc_debit)
            ELSE (0)::real
        END, (0)::real) AS bal_credit,
    vw_sm_gls.acc_base_debit,
    vw_sm_gls.acc_base_credit,
    (vw_sm_gls.acc_base_debit - vw_sm_gls.acc_base_credit) AS acc_base_balance,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_base_debit > vw_sm_gls.acc_base_credit) THEN (vw_sm_gls.acc_base_debit - vw_sm_gls.acc_base_credit)
            ELSE (0)::real
        END, (0)::real) AS bal_base_debit,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_base_debit < vw_sm_gls.acc_base_credit) THEN (vw_sm_gls.acc_base_credit - vw_sm_gls.acc_base_debit)
            ELSE (0)::real
        END, (0)::real) AS bal_base_credit
   FROM vw_sm_gls;


ALTER TABLE public.vw_ledger OWNER TO postgres;

--
-- Name: vw_ledger_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ledger_types AS
 SELECT vw_accounts.accounts_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.accounts_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    ta.accounts_class_id AS t_accounts_class_id,
    ta.chat_type_id AS t_chat_type_id,
    ta.chat_type_name AS t_chat_type_name,
    ta.accounts_class_name AS t_accounts_class_name,
    ta.account_type_id AS t_account_type_id,
    ta.account_type_name AS t_account_type_name,
    ta.account_id AS t_account_id,
    ta.account_no AS t_account_no,
    ta.account_name AS t_account_name,
    ledger_types.org_id,
    ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.ledger_posting,
    ledger_types.income_ledger,
    ledger_types.expense_ledger,
    ledger_types.details
   FROM ((ledger_types
     JOIN vw_accounts ON ((ledger_types.account_id = vw_accounts.account_id)))
     JOIN vw_accounts ta ON ((ledger_types.tax_account_id = ta.account_id)));


ALTER TABLE public.vw_ledger_types OWNER TO postgres;

--
-- Name: vw_org_select; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_select AS
 SELECT orgs.org_id,
    orgs.parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE ((orgs.is_active = true) AND (orgs.org_id <> orgs.parent_org_id))
UNION
 SELECT orgs.org_id,
    orgs.org_id AS parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE (orgs.is_active = true);


ALTER TABLE public.vw_org_select OWNER TO postgres;

--
-- Name: vw_period_month; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_month AS
 SELECT vw_periods.org_id,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month
  ORDER BY vw_periods.month_id, vw_periods.period_year, vw_periods.period_month;


ALTER TABLE public.vw_period_month OWNER TO postgres;

--
-- Name: vw_period_quarter; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_quarter AS
 SELECT vw_periods.org_id,
    vw_periods.quarter
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.quarter
  ORDER BY vw_periods.quarter;


ALTER TABLE public.vw_period_quarter OWNER TO postgres;

--
-- Name: vw_rentals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rentals AS
 SELECT vw_property.client_id,
    vw_property.client_name,
    vw_property.property_type_id,
    vw_property.property_type_name,
    vw_property.property_id,
    vw_property.property_name,
    vw_property.estate,
    vw_property.plot_no,
    vw_property.units,
    entitys.entity_id AS tenant_id,
    entitys.entity_name AS tenant_name,
    rentals.org_id,
    rentals.rental_id,
    rentals.start_rent,
    rentals.hse_no,
    rentals.elec_no,
    rentals.water_no,
    rentals.is_active,
    rentals.rental_value,
    rentals.commision_value,
    rentals.commision_pct,
    rentals.service_fees,
    rentals.deposit_fee,
    rentals.deposit_fee_date,
    rentals.deposit_refund,
    rentals.deposit_refund_date,
    rentals.details
   FROM ((vw_property
     JOIN rentals ON ((vw_property.property_id = rentals.property_id)))
     JOIN entitys ON ((rentals.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_rentals OWNER TO postgres;

--
-- Name: vw_period_rentals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_rentals AS
 SELECT vw_rentals.client_id,
    vw_rentals.client_name,
    vw_rentals.property_type_id,
    vw_rentals.property_type_name,
    vw_rentals.property_id,
    vw_rentals.property_name,
    vw_rentals.estate,
    vw_rentals.plot_no,
    vw_rentals.units,
    vw_rentals.tenant_id,
    vw_rentals.tenant_name,
    vw_rentals.rental_id,
    vw_rentals.start_rent,
    vw_rentals.hse_no,
    vw_rentals.elec_no,
    vw_rentals.water_no,
    vw_rentals.is_active,
    vw_rentals.rental_value,
    vw_rentals.deposit_fee,
    vw_rentals.deposit_fee_date,
    vw_rentals.deposit_refund,
    vw_rentals.deposit_refund_date,
    vw_periods.fiscal_year_id,
    vw_periods.fiscal_year_start,
    vw_periods.fiscal_year_end,
    vw_periods.year_opened,
    vw_periods.year_closed,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.opened,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    period_rentals.org_id,
    period_rentals.period_rental_id,
    period_rentals.rental_amount,
    period_rentals.service_fees,
    period_rentals.commision,
    period_rentals.commision_pct,
    period_rentals.repair_amount,
    period_rentals.narrative,
    period_rentals.status,
    (period_rentals.rental_amount - period_rentals.commision) AS rent_to_remit,
    ((period_rentals.rental_amount + period_rentals.service_fees) + period_rentals.repair_amount) AS rent_to_pay
   FROM ((vw_rentals
     JOIN period_rentals ON ((vw_rentals.rental_id = period_rentals.rental_id)))
     JOIN vw_periods ON ((period_rentals.period_id = vw_periods.period_id)));


ALTER TABLE public.vw_period_rentals OWNER TO postgres;

--
-- Name: vw_period_semister; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_semister AS
 SELECT vw_periods.org_id,
    vw_periods.semister
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.semister
  ORDER BY vw_periods.semister;


ALTER TABLE public.vw_period_semister OWNER TO postgres;

--
-- Name: vw_period_tax_rates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_tax_rates AS
 SELECT period_tax_types.period_tax_type_id,
    period_tax_types.period_tax_type_name,
    period_tax_types.tax_type_id,
    period_tax_types.period_id,
    period_tax_rates.period_tax_rate_id,
    gettaxmin(period_tax_rates.tax_range, period_tax_types.period_tax_type_id) AS min_range,
    period_tax_rates.org_id,
    period_tax_rates.tax_range AS max_range,
    period_tax_rates.tax_rate,
    period_tax_rates.narrative
   FROM (period_tax_rates
     JOIN period_tax_types ON ((period_tax_rates.period_tax_type_id = period_tax_types.period_tax_type_id)));


ALTER TABLE public.vw_period_tax_rates OWNER TO postgres;

--
-- Name: vw_period_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_tax_types AS
 SELECT vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.overtime_rate,
    vw_periods.activated,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    period_tax_types.period_tax_type_id,
    tax_types.tax_type_number,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    period_tax_types.period_tax_type_name,
    period_tax_types.org_id,
    period_tax_types.pay_date,
    period_tax_types.tax_relief,
    period_tax_types.linear,
    period_tax_types.percentage,
    period_tax_types.formural,
    period_tax_types.details
   FROM (((period_tax_types
     JOIN vw_periods ON ((period_tax_types.period_id = vw_periods.period_id)))
     JOIN tax_types ON ((period_tax_types.tax_type_id = tax_types.tax_type_id)))
     JOIN use_keys ON ((tax_types.use_key_id = use_keys.use_key_id)));


ALTER TABLE public.vw_period_tax_types OWNER TO postgres;

--
-- Name: vw_period_year; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_year AS
 SELECT vw_periods.org_id,
    vw_periods.period_year
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.period_year
  ORDER BY vw_periods.period_year;


ALTER TABLE public.vw_period_year OWNER TO postgres;

--
-- Name: vw_quotations; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_quotations AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    items.item_id,
    items.item_name,
    quotations.quotation_id,
    quotations.org_id,
    quotations.active,
    quotations.amount,
    quotations.valid_from,
    quotations.valid_to,
    quotations.lead_time,
    quotations.details
   FROM ((quotations
     JOIN entitys ON ((quotations.entity_id = entitys.entity_id)))
     JOIN items ON ((quotations.item_id = items.item_id)));


ALTER TABLE public.vw_quotations OWNER TO postgres;

--
-- Name: vw_receipt; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_receipt AS
 SELECT payment_types.account_id,
    payment_types.use_key_id,
    payment_types.payment_type_name,
    payment_types.is_active,
    payments.payment_id,
    payments.payment_type_id,
    payments.currency_id,
    payments.period_id,
    payments.property_id,
    payments.rental_id,
    payments.org_id,
    payments.journal_id,
    payments.payment_number,
    payments.payment_date,
    payments.tx_type,
    payments.account_credit,
    payments.account_debit,
    payments.balance,
    payments.exchange_rate,
    payments.activity_name,
    payments.action_date,
    amount_in_words(((payments.account_credit)::integer)::bigint) AS amount_paid,
    currency.currency_name,
    currency.currency_symbol,
    vw_rentals.property_type_name,
    vw_rentals.property_name,
    vw_rentals.estate,
    vw_rentals.tenant_name,
    vw_rentals.hse_no,
    vw_rentals.rental_value,
    vw_rentals.tenant_id AS entity_id,
    vw_periods.period_disp,
    vw_periods.period_month,
    vw_periods.start_date,
    vw_periods.end_date
   FROM ((((payments
     JOIN currency ON ((currency.currency_id = payments.currency_id)))
     JOIN payment_types ON ((payment_types.payment_type_id = payments.payment_type_id)))
     JOIN vw_rentals ON ((vw_rentals.rental_id = payments.rental_id)))
     JOIN vw_periods ON ((vw_periods.period_id = payments.period_id)))
  WHERE (payments.tx_type = 1);


ALTER TABLE public.vw_receipt OWNER TO postgres;

--
-- Name: vw_tenant_payments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tenant_payments AS
 SELECT payment_types.account_id,
    payment_types.use_key_id,
    payment_types.payment_type_name,
    payment_types.is_active,
    payments.payment_id,
    payments.payment_type_id,
    payments.currency_id,
    payments.period_id,
    payments.entity_id,
    payments.property_id,
    payments.rental_id,
    payments.org_id,
    payments.journal_id,
    payments.payment_number,
    payments.payment_date,
    payments.tx_type,
    payments.account_credit,
    payments.account_debit,
    payments.balance,
    payments.exchange_rate,
    payments.activity_name,
    payments.action_date,
    currency.currency_name,
    currency.currency_symbol,
    vw_rentals.property_type_name,
    vw_rentals.property_name,
    vw_rentals.estate,
    vw_rentals.tenant_name,
    vw_rentals.hse_no,
    vw_rentals.rental_value,
    vw_periods.period_disp,
    vw_periods.period_month
   FROM ((((payments
     JOIN currency ON ((currency.currency_id = payments.currency_id)))
     JOIN payment_types ON ((payment_types.payment_type_id = payments.payment_type_id)))
     JOIN vw_rentals ON ((vw_rentals.rental_id = payments.rental_id)))
     JOIN vw_periods ON ((vw_periods.period_id = payments.period_id)))
  WHERE (payments.tx_type = 1);


ALTER TABLE public.vw_tenant_payments OWNER TO postgres;

--
-- Name: vw_receipts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_receipts AS
 SELECT vw_tenant_payments.org_id,
    vw_tenant_payments.rental_id,
    vw_tenant_payments.period_id,
    vw_tenant_payments.payment_id,
    vw_tenant_payments.payment_type_id,
    vw_tenant_payments.payment_number,
    vw_tenant_payments.payment_date,
    vw_tenant_payments.account_credit,
    vw_tenant_payments.balance,
    vw_tenant_payments.currency_symbol,
    (((((vw_tenant_payments.property_name)::text || ','::text) || (vw_tenant_payments.property_type_name)::text) || ','::text) || (vw_tenant_payments.estate)::text) AS property,
    (((vw_tenant_payments.tenant_name)::text || '-'::text) || (vw_tenant_payments.hse_no)::text) AS tenant_details,
    vw_tenant_payments.period_disp,
    vw_tenant_payments.period_month
   FROM vw_tenant_payments
  WHERE (vw_tenant_payments.payment_type_id = 2);


ALTER TABLE public.vw_receipts OWNER TO postgres;

--
-- Name: vw_reporting; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_reporting AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    rpt.entity_id AS rpt_id,
    rpt.entity_name AS rpt_name,
    reporting.org_id,
    reporting.reporting_id,
    reporting.date_from,
    reporting.date_to,
    reporting.primary_report,
    reporting.is_active,
    reporting.ps_reporting,
    reporting.reporting_level,
    reporting.details
   FROM ((reporting
     JOIN entitys ON ((reporting.entity_id = entitys.entity_id)))
     JOIN entitys rpt ON ((reporting.report_to_id = rpt.entity_id)));


ALTER TABLE public.vw_reporting OWNER TO postgres;

--
-- Name: vw_sub_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sub_fields AS
 SELECT vw_fields.form_id,
    vw_fields.form_name,
    vw_fields.field_id,
    sub_fields.sub_field_id,
    sub_fields.org_id,
    sub_fields.sub_field_order,
    sub_fields.sub_title_share,
    sub_fields.sub_field_type,
    sub_fields.sub_field_lookup,
    sub_fields.sub_field_size,
    sub_fields.sub_col_spans,
    sub_fields.manditory,
    sub_fields.question
   FROM (sub_fields
     JOIN vw_fields ON ((sub_fields.field_id = vw_fields.field_id)));


ALTER TABLE public.vw_sub_fields OWNER TO postgres;

--
-- Name: vw_subscriptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_subscriptions AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    entitys.entity_id,
    entitys.entity_name,
    account_manager.entity_id AS account_manager_id,
    account_manager.entity_name AS account_manager_name,
    orgs.org_id,
    orgs.org_name,
    subscriptions.subscription_id,
    subscriptions.business_name,
    subscriptions.business_address,
    subscriptions.city,
    subscriptions.state,
    subscriptions.country_id,
    subscriptions.number_of_employees,
    subscriptions.telephone,
    subscriptions.website,
    subscriptions.primary_contact,
    subscriptions.job_title,
    subscriptions.primary_email,
    subscriptions.approve_status,
    subscriptions.workflow_table_id,
    subscriptions.application_date,
    subscriptions.action_date,
    subscriptions.system_key,
    subscriptions.subscribed,
    subscriptions.subscribed_date,
    subscriptions.details
   FROM ((((subscriptions
     JOIN sys_countrys ON ((subscriptions.country_id = sys_countrys.sys_country_id)))
     LEFT JOIN entitys ON ((subscriptions.entity_id = entitys.entity_id)))
     LEFT JOIN entitys account_manager ON ((subscriptions.account_manager_id = account_manager.entity_id)))
     LEFT JOIN orgs ON ((subscriptions.org_id = orgs.org_id)));


ALTER TABLE public.vw_subscriptions OWNER TO postgres;

--
-- Name: vw_sys_countrys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_countrys AS
 SELECT sys_continents.sys_continent_id,
    sys_continents.sys_continent_name,
    sys_countrys.sys_country_id,
    sys_countrys.sys_country_code,
    sys_countrys.sys_country_number,
    sys_countrys.sys_phone_code,
    sys_countrys.sys_country_name
   FROM (sys_continents
     JOIN sys_countrys ON ((sys_continents.sys_continent_id = sys_countrys.sys_continent_id)));


ALTER TABLE public.vw_sys_countrys OWNER TO postgres;

--
-- Name: vw_sys_emailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_emailed AS
 SELECT sys_emails.sys_email_id,
    sys_emails.org_id,
    sys_emails.sys_email_name,
    sys_emails.title,
    sys_emails.details,
    sys_emailed.sys_emailed_id,
    sys_emailed.table_id,
    sys_emailed.table_name,
    sys_emailed.email_type,
    sys_emailed.emailed,
    sys_emailed.narrative
   FROM (sys_emails
     RIGHT JOIN sys_emailed ON ((sys_emails.sys_email_id = sys_emailed.sys_email_id)));


ALTER TABLE public.vw_sys_emailed OWNER TO postgres;

--
-- Name: vw_tax_rates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tax_rates AS
 SELECT tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.tax_relief,
    tax_types.linear,
    tax_types.percentage,
    tax_rates.org_id,
    tax_rates.tax_rate_id,
    tax_rates.tax_range,
    tax_rates.tax_rate,
    tax_rates.narrative
   FROM (tax_rates
     JOIN tax_types ON ((tax_rates.tax_type_id = tax_types.tax_type_id)));


ALTER TABLE public.vw_tax_rates OWNER TO postgres;

--
-- Name: vw_tenant_invoice; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tenant_invoice AS
 SELECT ((vw_period_rentals.period_year || '-'::text) || vw_period_rentals.period_month) AS period_disp,
    (((((vw_period_rentals.property_name)::text || ' '::text) || (vw_period_rentals.property_type_name)::text) || ' '::text) || (vw_period_rentals.estate)::text) AS property_details,
    vw_period_rentals.tenant_name,
    vw_period_rentals.hse_no,
    vw_period_rentals.rental_amount,
    vw_period_rentals.service_fees,
    vw_period_rentals.commision,
    vw_period_rentals.repair_amount,
    vw_period_rentals.status,
    payments.payment_id,
    payments.payment_type_id,
    payments.period_id,
    payments.entity_id,
    payments.property_id,
    payments.rental_id,
    payments.org_id,
    payments.payment_number,
    payments.payment_date,
    payments.account_debit,
    payments.exchange_rate,
    payments.activity_name,
    currency.currency_name,
    currency.currency_symbol,
    vw_orgs.org_name,
    vw_orgs.org_full_name
   FROM (((payments
     JOIN vw_period_rentals ON ((vw_period_rentals.rental_id = payments.rental_id)))
     JOIN currency ON ((currency.currency_id = payments.currency_id)))
     JOIN vw_orgs ON ((vw_orgs.org_id = payments.org_id)))
  WHERE ((payments.tx_type = 1) AND (payments.payment_type_id = 5));


ALTER TABLE public.vw_tenant_invoice OWNER TO postgres;

--
-- Name: vw_tenant_rentals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tenant_rentals AS
 SELECT entitys.entity_id,
    entitys.entity_name AS tenant_name,
    rentals.org_id,
    rentals.rental_id,
    rentals.start_rent,
    rentals.hse_no,
    rentals.elec_no,
    rentals.water_no,
    rentals.is_active,
    rentals.rental_value,
    rentals.commision_value,
    rentals.commision_pct,
    rentals.service_fees,
    rentals.deposit_fee,
    rentals.deposit_fee_date,
    rentals.deposit_refund,
    rentals.deposit_refund_date,
    rentals.details
   FROM (rentals
     JOIN entitys ON ((rentals.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_tenant_rentals OWNER TO postgres;

--
-- Name: vw_tenant_statement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tenant_statement AS
 SELECT vw_tenant_payments.rental_id,
    vw_tenant_payments.tenant_name,
    (((((vw_tenant_payments.property_name)::text || ','::text) || (vw_tenant_payments.property_type_name)::text) || ','::text) || (vw_tenant_payments.estate)::text) AS property_info,
    vw_tenant_payments.hse_no,
    vw_tenant_payments.payment_date,
    vw_tenant_payments.payment_number,
    (((((vw_tenant_payments.activity_name)::text || ','::text) || (vw_tenant_payments.hse_no)::text) || ','::text) || vw_tenant_payments.period_disp) AS details,
    vw_tenant_payments.account_debit AS rent_to_pay,
    vw_tenant_payments.account_credit AS rent_paid,
    vw_tenant_payments.balance
   FROM vw_tenant_payments
  ORDER BY vw_tenant_payments.payment_id;


ALTER TABLE public.vw_tenant_statement OWNER TO postgres;

--
-- Name: vw_transaction_counters; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transaction_counters AS
 SELECT transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_posting,
    transaction_types.for_sales,
    transaction_counters.org_id,
    transaction_counters.transaction_counter_id,
    transaction_counters.document_number
   FROM (transaction_counters
     JOIN transaction_types ON ((transaction_counters.transaction_type_id = transaction_types.transaction_type_id)));


ALTER TABLE public.vw_transaction_counters OWNER TO postgres;

--
-- Name: vw_transactions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transactions AS
 SELECT transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_posting,
    transaction_types.for_sales,
    entitys.entity_id,
    entitys.entity_name,
    entitys.account_id AS entity_account_id,
    currency.currency_id,
    currency.currency_name,
    vw_bank_accounts.bank_id,
    vw_bank_accounts.bank_name,
    vw_bank_accounts.bank_branch_name,
    vw_bank_accounts.account_id AS gl_bank_account_id,
    vw_bank_accounts.bank_account_id,
    vw_bank_accounts.bank_account_name,
    vw_bank_accounts.bank_account_number,
    departments.department_id,
    departments.department_name,
    ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.account_id AS ledger_account_id,
    ledger_types.tax_account_id,
    ledger_types.ledger_posting,
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    transactions.journal_id,
    transactions.transaction_id,
    transactions.org_id,
    transactions.transaction_date,
    transactions.transaction_amount,
    transactions.transaction_tax_amount,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.document_number,
    transactions.payment_number,
    transactions.order_number,
    transactions.exchange_rate,
    transactions.payment_terms,
    transactions.job,
    transactions.details,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
        CASE
            WHEN ((((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) OR (transactions.transaction_type_id = 21)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN ((((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) OR (transactions.transaction_type_id = 22)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS credit_amount
   FROM (((((((transactions
     JOIN transaction_types ON ((transactions.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN transaction_status ON ((transactions.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     LEFT JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
     LEFT JOIN vw_bank_accounts ON ((vw_bank_accounts.bank_account_id = transactions.bank_account_id)))
     LEFT JOIN departments ON ((transactions.department_id = departments.department_id)))
     LEFT JOIN ledger_types ON ((transactions.ledger_type_id = ledger_types.ledger_type_id)));


ALTER TABLE public.vw_transactions OWNER TO postgres;

--
-- Name: vw_transaction_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transaction_details AS
 SELECT vw_transactions.department_id,
    vw_transactions.department_name,
    vw_transactions.transaction_type_id,
    vw_transactions.transaction_type_name,
    vw_transactions.document_prefix,
    vw_transactions.transaction_id,
    vw_transactions.transaction_date,
    vw_transactions.entity_id,
    vw_transactions.entity_name,
    vw_transactions.approve_status,
    vw_transactions.workflow_table_id,
    vw_transactions.currency_name,
    vw_transactions.exchange_rate,
    accounts.account_id,
    accounts.account_name,
    vw_items.item_id,
    vw_items.item_name,
    vw_items.tax_type_id,
    vw_items.tax_account_id,
    vw_items.tax_type_name,
    vw_items.tax_rate,
    vw_items.tax_inclusive,
    vw_items.sales_account_id,
    vw_items.purchase_account_id,
    stores.store_id,
    stores.store_name,
    transaction_details.transaction_detail_id,
    transaction_details.org_id,
    transaction_details.quantity,
    transaction_details.amount,
    transaction_details.tax_amount,
    transaction_details.narrative,
    transaction_details.details,
    COALESCE(transaction_details.narrative, vw_items.item_name) AS item_description,
    ((transaction_details.quantity)::double precision * transaction_details.amount) AS full_amount,
    ((transaction_details.quantity)::double precision * transaction_details.tax_amount) AS full_tax_amount,
    ((transaction_details.quantity)::double precision * (transaction_details.amount + transaction_details.tax_amount)) AS full_total_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 5) OR (vw_transactions.transaction_type_id = 9)) THEN ((transaction_details.quantity)::double precision * transaction_details.tax_amount)
            ELSE (0)::double precision
        END AS tax_debit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 10)) THEN ((transaction_details.quantity)::double precision * transaction_details.tax_amount)
            ELSE (0)::double precision
        END AS tax_credit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 5) OR (vw_transactions.transaction_type_id = 9)) THEN ((transaction_details.quantity)::double precision * transaction_details.amount)
            ELSE (0)::double precision
        END AS full_debit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 10)) THEN ((transaction_details.quantity)::double precision * transaction_details.amount)
            ELSE (0)::double precision
        END AS full_credit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 9)) THEN vw_items.sales_account_id
            ELSE vw_items.purchase_account_id
        END AS trans_account_id
   FROM ((((transaction_details
     JOIN vw_transactions ON ((transaction_details.transaction_id = vw_transactions.transaction_id)))
     LEFT JOIN vw_items ON ((transaction_details.item_id = vw_items.item_id)))
     LEFT JOIN accounts ON ((transaction_details.account_id = accounts.account_id)))
     LEFT JOIN stores ON ((transaction_details.store_id = stores.store_id)));


ALTER TABLE public.vw_transaction_details OWNER TO postgres;

--
-- Name: vw_trx; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_trx AS
 SELECT vw_orgs.org_id,
    vw_orgs.org_name,
    vw_orgs.is_default AS org_is_default,
    vw_orgs.is_active AS org_is_active,
    vw_orgs.logo AS org_logo,
    vw_orgs.cert_number AS org_cert_number,
    vw_orgs.pin AS org_pin,
    vw_orgs.vat_number AS org_vat_number,
    vw_orgs.invoice_footer AS org_invoice_footer,
    vw_orgs.org_sys_country_id,
    vw_orgs.org_sys_country_name,
    vw_orgs.org_address_id,
    vw_orgs.org_table_name,
    vw_orgs.org_post_office_box,
    vw_orgs.org_postal_code,
    vw_orgs.org_premises,
    vw_orgs.org_street,
    vw_orgs.org_town,
    vw_orgs.org_phone_number,
    vw_orgs.org_extension,
    vw_orgs.org_mobile,
    vw_orgs.org_fax,
    vw_orgs.org_email,
    vw_orgs.org_website,
    vw_entitys.address_id,
    vw_entitys.address_name,
    vw_entitys.sys_country_id,
    vw_entitys.sys_country_name,
    vw_entitys.table_name,
    vw_entitys.is_default,
    vw_entitys.post_office_box,
    vw_entitys.postal_code,
    vw_entitys.premises,
    vw_entitys.street,
    vw_entitys.town,
    vw_entitys.phone_number,
    vw_entitys.extension,
    vw_entitys.mobile,
    vw_entitys.fax,
    vw_entitys.email,
    vw_entitys.website,
    vw_entitys.entity_id,
    vw_entitys.entity_name,
    vw_entitys.user_name,
    vw_entitys.super_user,
    vw_entitys.attention,
    vw_entitys.date_enroled,
    vw_entitys.is_active,
    vw_entitys.entity_type_id,
    vw_entitys.entity_type_name,
    vw_entitys.entity_role,
    vw_entitys.use_key_id,
    transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_sales,
    transaction_types.for_posting,
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    departments.department_id,
    departments.department_name,
    transactions.journal_id,
    transactions.bank_account_id,
    transactions.transaction_id,
    transactions.transaction_date,
    transactions.transaction_amount,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.document_number,
    transactions.payment_number,
    transactions.order_number,
    transactions.exchange_rate,
    transactions.payment_terms,
    transactions.job,
    transactions.details,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
        CASE
            WHEN ((((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) OR (transactions.transaction_type_id = 21)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN ((((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) OR (transactions.transaction_type_id = 22)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS credit_amount
   FROM ((((((transactions
     JOIN transaction_types ON ((transactions.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN vw_orgs ON ((transactions.org_id = vw_orgs.org_id)))
     JOIN transaction_status ON ((transactions.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     LEFT JOIN vw_entitys ON ((transactions.entity_id = vw_entitys.entity_id)))
     LEFT JOIN departments ON ((transactions.department_id = departments.department_id)));


ALTER TABLE public.vw_trx OWNER TO postgres;

--
-- Name: vw_trx_sum; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_trx_sum AS
 SELECT transaction_details.transaction_id,
    sum(((transaction_details.quantity)::double precision * transaction_details.amount)) AS total_amount,
    sum(((transaction_details.quantity)::double precision * transaction_details.tax_amount)) AS total_tax_amount,
    sum(((transaction_details.quantity)::double precision * (transaction_details.amount + transaction_details.tax_amount))) AS total_sale_amount
   FROM transaction_details
  GROUP BY transaction_details.transaction_id;


ALTER TABLE public.vw_trx_sum OWNER TO postgres;

--
-- Name: vw_tx_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tx_ledger AS
 SELECT ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.account_id,
    ledger_types.ledger_posting,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    entitys.entity_id,
    entitys.entity_name,
    bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    transactions.org_id,
    transactions.transaction_id,
    transactions.journal_id,
    transactions.exchange_rate,
    transactions.tx_type,
    transactions.transaction_date,
    transactions.payment_date,
    transactions.transaction_amount,
    transactions.transaction_tax_amount,
    transactions.reference_number,
    transactions.payment_number,
    transactions.for_processing,
    transactions.completed,
    transactions.is_cleared,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.details,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
    to_char((transactions.payment_date)::timestamp with time zone, 'YYYY.MM'::text) AS ledger_period,
    to_char((transactions.payment_date)::timestamp with time zone, 'YYYY'::text) AS ledger_year,
    to_char((transactions.payment_date)::timestamp with time zone, 'Month'::text) AS ledger_month,
    ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount) AS base_amount,
    ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_tax_amount) AS base_tax_amount,
        CASE
            WHEN (transactions.completed = true) THEN ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount)
            ELSE ((0)::real)::double precision
        END AS base_balance,
        CASE
            WHEN (transactions.is_cleared = true) THEN ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount)
            ELSE ((0)::real)::double precision
        END AS cleared_balance,
        CASE
            WHEN (transactions.tx_type = 1) THEN (transactions.exchange_rate * transactions.transaction_amount)
            ELSE (0)::real
        END AS dr_amount,
        CASE
            WHEN (transactions.tx_type = (-1)) THEN (transactions.exchange_rate * transactions.transaction_amount)
            ELSE (0)::real
        END AS cr_amount
   FROM ((((transactions
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
     LEFT JOIN bank_accounts ON ((transactions.bank_account_id = bank_accounts.bank_account_id)))
     LEFT JOIN ledger_types ON ((transactions.ledger_type_id = ledger_types.ledger_type_id)))
  WHERE (transactions.tx_type IS NOT NULL);


ALTER TABLE public.vw_tx_ledger OWNER TO postgres;

--
-- Name: vw_workflow_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_approvals AS
 SELECT vw_approvals.workflow_id,
    vw_approvals.org_id,
    vw_approvals.workflow_name,
    vw_approvals.approve_email,
    vw_approvals.reject_email,
    vw_approvals.source_entity_id,
    vw_approvals.source_entity_name,
    vw_approvals.table_name,
    vw_approvals.table_id,
    vw_approvals.org_entity_id,
    vw_approvals.org_entity_name,
    vw_approvals.org_user_name,
    vw_approvals.org_primary_email,
    rt.rejected_count,
        CASE
            WHEN (rt.rejected_count IS NULL) THEN ((vw_approvals.workflow_name)::text || ' Approved'::text)
            ELSE ((vw_approvals.workflow_name)::text || ' declined'::text)
        END AS workflow_narrative
   FROM (vw_approvals
     LEFT JOIN ( SELECT approvals.table_id,
            count(approvals.approval_id) AS rejected_count
           FROM approvals
          WHERE (((approvals.approve_status)::text = 'Rejected'::text) AND (approvals.forward_id IS NULL))
          GROUP BY approvals.table_id) rt ON ((vw_approvals.table_id = rt.table_id)))
  GROUP BY vw_approvals.workflow_id, vw_approvals.org_id, vw_approvals.workflow_name, vw_approvals.approve_email, vw_approvals.reject_email, vw_approvals.source_entity_id, vw_approvals.source_entity_name, vw_approvals.table_name, vw_approvals.table_id, vw_approvals.org_entity_id, vw_approvals.org_entity_name, vw_approvals.org_user_name, vw_approvals.org_primary_email, rt.rejected_count;


ALTER TABLE public.vw_workflow_approvals OWNER TO postgres;

--
-- Name: vw_workflow_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.org_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.table_name,
    vw_workflow_phases.table_link_id,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.return_level,
    vw_workflow_phases.escalation_days,
    vw_workflow_phases.escalation_hours,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.use_reporting,
    vw_workflow_phases.phase_narrative,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.entity_id,
    entity_subscriptions.subscription_level_id
   FROM (vw_workflow_phases
     JOIN entity_subscriptions ON ((vw_workflow_phases.source_entity_id = entity_subscriptions.entity_type_id)));


ALTER TABLE public.vw_workflow_entitys OWNER TO postgres;

--
-- Name: vws_tx_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vws_tx_ledger AS
 SELECT vw_tx_ledger.org_id,
    vw_tx_ledger.ledger_period,
    vw_tx_ledger.ledger_year,
    vw_tx_ledger.ledger_month,
    sum(vw_tx_ledger.base_amount) AS sum_base_amount,
    sum(vw_tx_ledger.base_tax_amount) AS sum_base_tax_amount,
    sum(vw_tx_ledger.base_balance) AS sum_base_balance,
    sum(vw_tx_ledger.cleared_balance) AS sum_cleared_balance,
    sum(vw_tx_ledger.dr_amount) AS sum_dr_amount,
    sum(vw_tx_ledger.cr_amount) AS sum_cr_amount,
    to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text) AS start_date,
    (sum(vw_tx_ledger.base_amount) + prev_balance(to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text))) AS prev_balance_amount,
    (sum(vw_tx_ledger.cleared_balance) + prev_clear_balance(to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text))) AS prev_clear_balance_amount
   FROM vw_tx_ledger
  GROUP BY vw_tx_ledger.org_id, vw_tx_ledger.ledger_period, vw_tx_ledger.ledger_year, vw_tx_ledger.ledger_month;


ALTER TABLE public.vws_tx_ledger OWNER TO postgres;

--
-- Name: workflow_logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_logs (
    workflow_log_id integer NOT NULL,
    org_id integer,
    table_name character varying(64),
    table_id integer,
    table_old_id integer
);


ALTER TABLE public.workflow_logs OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_logs_workflow_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_logs_workflow_log_id_seq OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_logs_workflow_log_id_seq OWNED BY workflow_logs.workflow_log_id;


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_phases_workflow_phase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_phases_workflow_phase_id_seq OWNER TO postgres;

--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_phases_workflow_phase_id_seq OWNED BY workflow_phases.workflow_phase_id;


--
-- Name: workflow_sql; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_sql (
    workflow_sql_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    workflow_sql_name character varying(50),
    is_condition boolean DEFAULT false,
    is_action boolean DEFAULT false,
    message_number character varying(32),
    ca_sql text
);


ALTER TABLE public.workflow_sql OWNER TO postgres;

--
-- Name: workflow_table_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_table_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflows_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflows_workflow_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflows_workflow_id_seq OWNED BY workflows.workflow_id;


--
-- Name: account_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types ALTER COLUMN account_type_id SET DEFAULT nextval('account_types_account_type_id_seq'::regclass);


--
-- Name: account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts ALTER COLUMN account_id SET DEFAULT nextval('accounts_account_id_seq'::regclass);


--
-- Name: accounts_class_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts_class ALTER COLUMN accounts_class_id SET DEFAULT nextval('accounts_class_accounts_class_id_seq'::regclass);


--
-- Name: address_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address ALTER COLUMN address_id SET DEFAULT nextval('address_address_id_seq'::regclass);


--
-- Name: address_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types ALTER COLUMN address_type_id SET DEFAULT nextval('address_types_address_type_id_seq'::regclass);


--
-- Name: approval_checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists ALTER COLUMN approval_checklist_id SET DEFAULT nextval('approval_checklists_approval_checklist_id_seq'::regclass);


--
-- Name: approval_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals ALTER COLUMN approval_id SET DEFAULT nextval('approvals_approval_id_seq'::regclass);


--
-- Name: bank_account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts ALTER COLUMN bank_account_id SET DEFAULT nextval('bank_accounts_bank_account_id_seq'::regclass);


--
-- Name: bank_branch_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch ALTER COLUMN bank_branch_id SET DEFAULT nextval('bank_branch_bank_branch_id_seq'::regclass);


--
-- Name: bank_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks ALTER COLUMN bank_id SET DEFAULT nextval('banks_bank_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: currency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency ALTER COLUMN currency_id SET DEFAULT nextval('currency_currency_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: default_account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts ALTER COLUMN default_account_id SET DEFAULT nextval('default_accounts_default_account_id_seq'::regclass);


--
-- Name: default_tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types ALTER COLUMN default_tax_type_id SET DEFAULT nextval('default_tax_types_default_tax_type_id_seq'::regclass);


--
-- Name: department_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments ALTER COLUMN department_id SET DEFAULT nextval('departments_department_id_seq'::regclass);


--
-- Name: entity_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields ALTER COLUMN entity_field_id SET DEFAULT nextval('entity_fields_entity_field_id_seq'::regclass);


--
-- Name: entity_subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions ALTER COLUMN entity_subscription_id SET DEFAULT nextval('entity_subscriptions_entity_subscription_id_seq'::regclass);


--
-- Name: entity_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types ALTER COLUMN entity_type_id SET DEFAULT nextval('entity_types_entity_type_id_seq'::regclass);


--
-- Name: entity_value_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values ALTER COLUMN entity_value_id SET DEFAULT nextval('entity_values_entity_value_id_seq'::regclass);


--
-- Name: entity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys ALTER COLUMN entity_id SET DEFAULT nextval('entitys_entity_id_seq'::regclass);


--
-- Name: entry_form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms ALTER COLUMN entry_form_id SET DEFAULT nextval('entry_forms_entry_form_id_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: fiscal_year_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fiscal_years ALTER COLUMN fiscal_year_id SET DEFAULT nextval('fiscal_years_fiscal_year_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: gl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls ALTER COLUMN gl_id SET DEFAULT nextval('gls_gl_id_seq'::regclass);


--
-- Name: helpdesk_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk ALTER COLUMN helpdesk_id SET DEFAULT nextval('helpdesk_helpdesk_id_seq'::regclass);


--
-- Name: holiday_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays ALTER COLUMN holiday_id SET DEFAULT nextval('holidays_holiday_id_seq'::regclass);


--
-- Name: industry_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY industry ALTER COLUMN industry_id SET DEFAULT nextval('industry_industry_id_seq'::regclass);


--
-- Name: item_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_category ALTER COLUMN item_category_id SET DEFAULT nextval('item_category_item_category_id_seq'::regclass);


--
-- Name: item_unit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_units ALTER COLUMN item_unit_id SET DEFAULT nextval('item_units_item_unit_id_seq'::regclass);


--
-- Name: item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items ALTER COLUMN item_id SET DEFAULT nextval('items_item_id_seq'::regclass);


--
-- Name: journal_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals ALTER COLUMN journal_id SET DEFAULT nextval('journals_journal_id_seq'::regclass);


--
-- Name: ledger_link_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links ALTER COLUMN ledger_link_id SET DEFAULT nextval('ledger_links_ledger_link_id_seq'::regclass);


--
-- Name: ledger_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types ALTER COLUMN ledger_type_id SET DEFAULT nextval('ledger_types_ledger_type_id_seq'::regclass);


--
-- Name: log_period_rental_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_period_rentals ALTER COLUMN log_period_rental_id SET DEFAULT nextval('log_period_rentals_log_period_rental_id_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: payment_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_types ALTER COLUMN payment_type_id SET DEFAULT nextval('payment_types_payment_type_id_seq'::regclass);


--
-- Name: payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments ALTER COLUMN payment_id SET DEFAULT nextval('payments_payment_id_seq'::regclass);


--
-- Name: pdefinition_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions ALTER COLUMN pdefinition_id SET DEFAULT nextval('pdefinitions_pdefinition_id_seq'::regclass);


--
-- Name: period_rental_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals ALTER COLUMN period_rental_id SET DEFAULT nextval('period_rentals_period_rental_id_seq'::regclass);


--
-- Name: period_tax_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates ALTER COLUMN period_tax_rate_id SET DEFAULT nextval('period_tax_rates_period_tax_rate_id_seq'::regclass);


--
-- Name: period_tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types ALTER COLUMN period_tax_type_id SET DEFAULT nextval('period_tax_types_period_tax_type_id_seq'::regclass);


--
-- Name: period_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods ALTER COLUMN period_id SET DEFAULT nextval('periods_period_id_seq'::regclass);


--
-- Name: plevel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY plevels ALTER COLUMN plevel_id SET DEFAULT nextval('plevels_plevel_id_seq'::regclass);


--
-- Name: property_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property ALTER COLUMN property_id SET DEFAULT nextval('property_property_id_seq'::regclass);


--
-- Name: property_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property_types ALTER COLUMN property_type_id SET DEFAULT nextval('property_types_property_type_id_seq'::regclass);


--
-- Name: ptype_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ptypes ALTER COLUMN ptype_id SET DEFAULT nextval('ptypes_ptype_id_seq'::regclass);


--
-- Name: quotation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations ALTER COLUMN quotation_id SET DEFAULT nextval('quotations_quotation_id_seq'::regclass);


--
-- Name: rental_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rentals ALTER COLUMN rental_id SET DEFAULT nextval('rentals_rental_id_seq'::regclass);


--
-- Name: reporting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting ALTER COLUMN reporting_id SET DEFAULT nextval('reporting_reporting_id_seq'::regclass);


--
-- Name: store_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stores ALTER COLUMN store_id SET DEFAULT nextval('stores_store_id_seq'::regclass);


--
-- Name: sub_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields ALTER COLUMN sub_field_id SET DEFAULT nextval('sub_fields_sub_field_id_seq'::regclass);


--
-- Name: subscription_level_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels ALTER COLUMN subscription_level_id SET DEFAULT nextval('subscription_levels_subscription_level_id_seq'::regclass);


--
-- Name: subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions ALTER COLUMN subscription_id SET DEFAULT nextval('subscriptions_subscription_id_seq'::regclass);


--
-- Name: sys_audit_trail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_trail ALTER COLUMN sys_audit_trail_id SET DEFAULT nextval('sys_audit_trail_sys_audit_trail_id_seq'::regclass);


--
-- Name: sys_dashboard_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard ALTER COLUMN sys_dashboard_id SET DEFAULT nextval('sys_dashboard_sys_dashboard_id_seq'::regclass);


--
-- Name: sys_emailed_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed ALTER COLUMN sys_emailed_id SET DEFAULT nextval('sys_emailed_sys_emailed_id_seq'::regclass);


--
-- Name: sys_email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails ALTER COLUMN sys_email_id SET DEFAULT nextval('sys_emails_sys_email_id_seq'::regclass);


--
-- Name: sys_error_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_errors ALTER COLUMN sys_error_id SET DEFAULT nextval('sys_errors_sys_error_id_seq'::regclass);


--
-- Name: sys_file_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files ALTER COLUMN sys_file_id SET DEFAULT nextval('sys_files_sys_file_id_seq'::regclass);


--
-- Name: sys_login_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins ALTER COLUMN sys_login_id SET DEFAULT nextval('sys_logins_sys_login_id_seq'::regclass);


--
-- Name: sys_menu_msg_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_menu_msg ALTER COLUMN sys_menu_msg_id SET DEFAULT nextval('sys_menu_msg_sys_menu_msg_id_seq'::regclass);


--
-- Name: sys_news_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news ALTER COLUMN sys_news_id SET DEFAULT nextval('sys_news_sys_news_id_seq'::regclass);


--
-- Name: sys_queries_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries ALTER COLUMN sys_queries_id SET DEFAULT nextval('sys_queries_sys_queries_id_seq'::regclass);


--
-- Name: sys_reset_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset ALTER COLUMN sys_reset_id SET DEFAULT nextval('sys_reset_sys_reset_id_seq'::regclass);


--
-- Name: tax_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates ALTER COLUMN tax_rate_id SET DEFAULT nextval('tax_rates_tax_rate_id_seq'::regclass);


--
-- Name: tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types ALTER COLUMN tax_type_id SET DEFAULT nextval('tax_types_tax_type_id_seq'::regclass);


--
-- Name: transaction_counter_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters ALTER COLUMN transaction_counter_id SET DEFAULT nextval('transaction_counters_transaction_counter_id_seq'::regclass);


--
-- Name: transaction_detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details ALTER COLUMN transaction_detail_id SET DEFAULT nextval('transaction_details_transaction_detail_id_seq'::regclass);


--
-- Name: transaction_link_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links ALTER COLUMN transaction_link_id SET DEFAULT nextval('transaction_links_transaction_link_id_seq'::regclass);


--
-- Name: transaction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions ALTER COLUMN transaction_id SET DEFAULT nextval('transactions_transaction_id_seq'::regclass);


--
-- Name: workflow_log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs ALTER COLUMN workflow_log_id SET DEFAULT nextval('workflow_logs_workflow_log_id_seq'::regclass);


--
-- Name: workflow_phase_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases ALTER COLUMN workflow_phase_id SET DEFAULT nextval('workflow_phases_workflow_phase_id_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows ALTER COLUMN workflow_id SET DEFAULT nextval('workflows_workflow_id_seq'::regclass);


--
-- Data for Name: account_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (100, 100, 10, 0, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (110, 110, 10, 0, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (200, 200, 20, 0, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (210, 210, 20, 0, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (300, 300, 30, 0, 'DEBTORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (310, 310, 30, 0, 'INVESTMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (320, 320, 30, 0, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (330, 330, 30, 0, 'CASH ON HAND', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (340, 340, 30, 0, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (400, 400, 40, 0, 'CREDITORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (410, 410, 40, 0, 'ADVANCED BILLING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (420, 420, 40, 0, 'TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (430, 430, 40, 0, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (500, 500, 50, 0, 'LOANS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (600, 600, 60, 0, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (610, 610, 60, 0, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (700, 700, 70, 0, 'SALES REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (710, 710, 70, 0, 'OTHER INCOME', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (800, 800, 80, 0, 'COST OF REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (900, 900, 90, 0, 'STAFF COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (905, 905, 90, 0, 'COMMUNICATIONS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (910, 910, 90, 0, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (915, 915, 90, 0, 'TRANSPORT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (920, 920, 90, 0, 'TRAVEL', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (925, 925, 90, 0, 'POSTAL and COURIER', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (930, 930, 90, 0, 'ICT PROJECT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (935, 935, 90, 0, 'STATIONERY', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (940, 940, 90, 0, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (945, 945, 90, 0, 'REPAIRS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (950, 950, 90, 0, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (955, 955, 90, 0, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (960, 960, 90, 0, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (965, 965, 90, 0, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (970, 970, 90, 0, 'DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (975, 975, 90, 0, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (980, 980, 90, 0, 'FINANCE COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (985, 985, 90, 0, 'TAXES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (990, 990, 90, 0, 'INSURANCE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (995, 995, 90, 0, 'OTHER EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1000, 110, 108, 1, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1001, 100, 108, 1, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1002, 210, 107, 1, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1003, 200, 107, 1, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1004, 340, 106, 1, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1005, 330, 106, 1, 'CASH ON HAND', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1006, 320, 106, 1, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1007, 310, 106, 1, 'INVESTMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1008, 300, 106, 1, 'DEBTORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1009, 430, 105, 1, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1010, 420, 105, 1, 'TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1011, 410, 105, 1, 'ADVANCED BILLING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1012, 400, 105, 1, 'CREDITORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1013, 500, 104, 1, 'LOANS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1014, 610, 103, 1, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1015, 600, 103, 1, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1016, 710, 102, 1, 'OTHER INCOME', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1017, 700, 102, 1, 'SALES REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1018, 800, 101, 1, 'COST OF REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1019, 995, 100, 1, 'OTHER EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1020, 990, 100, 1, 'INSURANCE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1021, 985, 100, 1, 'TAXES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1022, 980, 100, 1, 'FINANCE COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1023, 975, 100, 1, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1024, 970, 100, 1, 'DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1025, 965, 100, 1, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1026, 960, 100, 1, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1027, 955, 100, 1, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1028, 950, 100, 1, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1029, 945, 100, 1, 'REPAIRS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1030, 940, 100, 1, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1031, 935, 100, 1, 'STATIONERY', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1032, 930, 100, 1, 'ICT PROJECT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1033, 925, 100, 1, 'POSTAL and COURIER', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1034, 920, 100, 1, 'TRAVEL', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1035, 915, 100, 1, 'TRANSPORT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1036, 910, 100, 1, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1037, 905, 100, 1, 'COMMUNICATIONS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, accounts_class_id, org_id, account_type_name, details) VALUES (1038, 900, 100, 1, 'STAFF COSTS', NULL);


--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_types_account_type_id_seq', 1038, true);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (10000, 10000, 100, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (10005, 10005, 100, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (11000, 11000, 110, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (11005, 11005, 110, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (20000, 20000, 200, 0, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (20005, 20005, 200, 0, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (20010, 20010, 200, 0, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (21000, 21000, 210, 0, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30000, 30000, 300, 0, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30005, 30005, 300, 0, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30010, 30010, 300, 0, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30015, 30015, 300, 0, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30020, 30020, 300, 0, 'INVENTORY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30025, 30025, 300, 0, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (30030, 30030, 300, 0, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (31005, 31005, 310, 0, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (32000, 32000, 320, 0, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (32005, 32005, 320, 0, 'MPESA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (33000, 33000, 330, 0, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (33005, 33005, 330, 0, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (34000, 34000, 340, 0, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (34005, 34005, 340, 0, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (34010, 34010, 340, 0, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (34015, 34015, 340, 0, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40000, 40000, 400, 0, 'TRADE CREDITORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40005, 40005, 400, 0, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40010, 40010, 400, 0, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40015, 40015, 400, 0, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40020, 40020, 400, 0, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40025, 40025, 400, 0, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40030, 40030, 400, 0, 'NSSF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40035, 40035, 400, 0, 'NHIF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40040, 40040, 400, 0, 'HELB', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40045, 40045, 400, 0, 'PAYE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40050, 40050, 400, 0, 'PENSION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (40055, 40055, 400, 0, 'PAYROLL LIABILITIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (41000, 41000, 410, 0, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (42000, 42000, 420, 0, 'Value Added Tax (VAT)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (42010, 42010, 420, 0, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (43000, 43000, 430, 0, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (50000, 50000, 500, 0, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (60000, 60000, 600, 0, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (60005, 60005, 600, 0, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (60010, 60010, 600, 0, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (61000, 61000, 610, 0, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (61005, 61005, 610, 0, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (61010, 61010, 610, 0, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (70005, 70005, 700, 0, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (70010, 70010, 700, 0, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (70015, 70015, 700, 0, 'SALES DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71000, 71000, 710, 0, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71005, 71005, 710, 0, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71010, 71010, 710, 0, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71015, 71015, 710, 0, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71020, 71020, 710, 0, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71025, 71025, 710, 0, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71030, 71030, 710, 0, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (71035, 71035, 710, 0, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (80000, 80000, 800, 0, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90000, 90000, 900, 0, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90005, 90005, 900, 0, 'STAFF ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90010, 90010, 900, 0, 'AIRTIME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90012, 90012, 900, 0, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90015, 90015, 900, 0, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90020, 90020, 900, 0, 'EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90025, 90025, 900, 0, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90035, 90035, 900, 0, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90040, 90040, 900, 0, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90045, 90045, 900, 0, 'BONUSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90050, 90050, 900, 0, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90055, 90055, 900, 0, 'WELFARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90056, 90056, 900, 0, 'STAFF WELLFARE: CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90060, 90060, 900, 0, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90065, 90065, 900, 0, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90070, 90070, 900, 0, 'STAFF EXPENDITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90075, 90075, 900, 0, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90500, 90500, 905, 0, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90505, 90505, 905, 0, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90510, 90510, 905, 0, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90515, 90515, 905, 0, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (90520, 90520, 905, 0, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91000, 91000, 910, 0, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91005, 91005, 910, 0, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91010, 91010, 910, 0, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91500, 91500, 915, 0, 'CAB FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91505, 91505, 915, 0, 'FUEL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91510, 91510, 915, 0, 'BUS FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (91515, 91515, 915, 0, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (92000, 92000, 920, 0, 'TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (92005, 92005, 920, 0, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (92505, 92505, 925, 0, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (92510, 92510, 925, 0, 'COURIER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93000, 93000, 930, 0, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93010, 93010, 930, 0, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93500, 93500, 935, 0, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93505, 93505, 935, 0, 'PAPER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93510, 93510, 935, 0, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93515, 93515, 935, 0, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (93520, 93520, 935, 0, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (94010, 94010, 940, 0, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (94015, 94015, 940, 0, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (94500, 94500, 945, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (94505, 94505, 945, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (94510, 94510, 945, 0, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95000, 95000, 950, 0, 'AUDIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95005, 95005, 950, 0, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95010, 95010, 950, 0, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95015, 95015, 950, 0, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95020, 95020, 950, 0, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95025, 95025, 950, 0, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95030, 95030, 950, 0, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95035, 95035, 950, 0, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95040, 95040, 950, 0, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95045, 95045, 950, 0, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95500, 95500, 955, 0, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95502, 95502, 955, 0, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95505, 95505, 955, 0, 'CLEANING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95510, 95510, 955, 0, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95515, 95515, 955, 0, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (95520, 95520, 955, 0, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (96005, 96005, 960, 0, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (96505, 96505, 965, 0, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (96510, 96510, 965, 0, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (97000, 97000, 970, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (97005, 97005, 970, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (97010, 97010, 970, 0, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (97500, 97500, 975, 0, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (97505, 97505, 975, 0, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98000, 98000, 980, 0, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98005, 98005, 980, 0, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98010, 98010, 980, 0, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98015, 98015, 980, 0, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98020, 98020, 980, 0, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98025, 98025, 980, 0, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98030, 98030, 980, 0, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98035, 98035, 980, 0, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98040, 98040, 980, 0, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98500, 98500, 985, 0, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98505, 98505, 985, 0, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98510, 98510, 985, 0, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (98515, 98515, 985, 0, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99000, 99000, 990, 0, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99005, 99005, 990, 0, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99010, 99010, 990, 0, 'BURGLARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99015, 99015, 990, 0, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99500, 99500, 995, 0, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99505, 99505, 995, 0, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99510, 99510, 995, 0, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99515, 99515, 995, 0, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (99999, 99999, 995, 0, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100000, 90075, 1038, 1, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100001, 90070, 1038, 1, 'STAFF EXPENDITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100002, 90065, 1038, 1, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100003, 90060, 1038, 1, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100004, 90056, 1038, 1, 'STAFF WELLFARE: CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100005, 90055, 1038, 1, 'WELFARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100006, 90050, 1038, 1, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100007, 90045, 1038, 1, 'BONUSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100008, 90040, 1038, 1, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100009, 90035, 1038, 1, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100010, 90025, 1038, 1, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100011, 90020, 1038, 1, 'EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100012, 90015, 1038, 1, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100013, 90012, 1038, 1, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100014, 90010, 1038, 1, 'AIRTIME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100015, 90005, 1038, 1, 'STAFF ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100016, 90000, 1038, 1, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100017, 90520, 1037, 1, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100018, 90515, 1037, 1, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100019, 90510, 1037, 1, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100020, 90505, 1037, 1, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100021, 90500, 1037, 1, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100022, 91010, 1036, 1, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100023, 91005, 1036, 1, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100024, 91000, 1036, 1, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100025, 91515, 1035, 1, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100026, 91510, 1035, 1, 'BUS FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100027, 91505, 1035, 1, 'FUEL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100028, 91500, 1035, 1, 'CAB FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100029, 92005, 1034, 1, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100030, 92000, 1034, 1, 'TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100031, 92510, 1033, 1, 'COURIER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100032, 92505, 1033, 1, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100033, 93010, 1032, 1, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100034, 93000, 1032, 1, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100035, 93520, 1031, 1, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100036, 93515, 1031, 1, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100037, 93510, 1031, 1, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100038, 93505, 1031, 1, 'PAPER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100039, 93500, 1031, 1, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100040, 94015, 1030, 1, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100041, 94010, 1030, 1, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100042, 94510, 1029, 1, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100043, 94505, 1029, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100044, 94500, 1029, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100045, 95045, 1028, 1, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100046, 95040, 1028, 1, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100047, 95035, 1028, 1, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100048, 95030, 1028, 1, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100049, 95025, 1028, 1, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100050, 95020, 1028, 1, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100051, 95015, 1028, 1, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100052, 95010, 1028, 1, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100053, 95005, 1028, 1, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100054, 95000, 1028, 1, 'AUDIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100055, 95520, 1027, 1, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100056, 95515, 1027, 1, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100057, 95510, 1027, 1, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100058, 95505, 1027, 1, 'CLEANING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100059, 95502, 1027, 1, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100060, 95500, 1027, 1, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100061, 96005, 1026, 1, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100062, 96510, 1025, 1, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100063, 96505, 1025, 1, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100064, 97010, 1024, 1, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100065, 97005, 1024, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100066, 97000, 1024, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100067, 97505, 1023, 1, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100068, 97500, 1023, 1, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100069, 98040, 1022, 1, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100070, 98035, 1022, 1, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100071, 98030, 1022, 1, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100072, 98025, 1022, 1, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100073, 98020, 1022, 1, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100074, 98015, 1022, 1, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100075, 98010, 1022, 1, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100076, 98005, 1022, 1, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100077, 98000, 1022, 1, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100078, 98515, 1021, 1, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100079, 98510, 1021, 1, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100080, 98505, 1021, 1, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100081, 98500, 1021, 1, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100082, 99015, 1020, 1, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100083, 99010, 1020, 1, 'BURGLARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100084, 99005, 1020, 1, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100085, 99000, 1020, 1, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100086, 99999, 1019, 1, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100087, 99515, 1019, 1, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100088, 99510, 1019, 1, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100089, 99505, 1019, 1, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100090, 99500, 1019, 1, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100091, 80000, 1018, 1, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100092, 70015, 1017, 1, 'SALES DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100093, 70010, 1017, 1, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100094, 70005, 1017, 1, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100095, 71035, 1016, 1, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100096, 71030, 1016, 1, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100097, 71025, 1016, 1, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100098, 71020, 1016, 1, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100099, 71015, 1016, 1, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100100, 71010, 1016, 1, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100101, 71005, 1016, 1, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100102, 71000, 1016, 1, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100103, 60010, 1015, 1, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100104, 60005, 1015, 1, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100105, 60000, 1015, 1, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100106, 61010, 1014, 1, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100107, 61005, 1014, 1, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100108, 61000, 1014, 1, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100109, 50000, 1013, 1, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100110, 40055, 1012, 1, 'PAYROLL LIABILITIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100111, 40050, 1012, 1, 'PENSION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100112, 40045, 1012, 1, 'PAYE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100113, 40040, 1012, 1, 'HELB', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100114, 40035, 1012, 1, 'NHIF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100115, 40030, 1012, 1, 'NSSF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100116, 40025, 1012, 1, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100117, 40020, 1012, 1, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100118, 40015, 1012, 1, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100119, 40010, 1012, 1, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100120, 40005, 1012, 1, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100121, 40000, 1012, 1, 'TRADE CREDITORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100122, 41000, 1011, 1, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100123, 42010, 1010, 1, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100124, 42000, 1010, 1, 'Value Added Tax (VAT)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100125, 43000, 1009, 1, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100126, 30030, 1008, 1, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100127, 30025, 1008, 1, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100128, 30020, 1008, 1, 'INVENTORY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100129, 30015, 1008, 1, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100130, 30010, 1008, 1, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100131, 30005, 1008, 1, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100132, 30000, 1008, 1, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100133, 31005, 1007, 1, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100134, 32005, 1006, 1, 'MPESA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100135, 32000, 1006, 1, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100136, 33005, 1005, 1, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100137, 33000, 1005, 1, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100138, 34015, 1004, 1, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100139, 34010, 1004, 1, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100140, 34005, 1004, 1, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100141, 34000, 1004, 1, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100142, 20010, 1003, 1, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100143, 20005, 1003, 1, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100144, 20000, 1003, 1, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100145, 21000, 1002, 1, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100146, 10005, 1001, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100147, 10000, 1001, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100148, 11005, 1000, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, account_type_id, org_id, account_name, is_header, is_active, details) VALUES (100149, 11000, 1000, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);


--
-- Name: accounts_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('accounts_account_id_seq', 100149, true);


--
-- Data for Name: accounts_class; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (10, 10, 0, 1, 'ASSETS', 'FIXED ASSETS', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (20, 20, 0, 1, 'ASSETS', 'INTANGIBLE ASSETS', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (30, 30, 0, 1, 'ASSETS', 'CURRENT ASSETS', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (40, 40, 0, 2, 'LIABILITIES', 'CURRENT LIABILITIES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (50, 50, 0, 2, 'LIABILITIES', 'LONG TERM LIABILITIES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (60, 60, 0, 3, 'EQUITY', 'EQUITY AND RESERVES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (70, 70, 0, 4, 'REVENUE', 'REVENUE AND OTHER INCOME', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (80, 80, 0, 5, 'COST OF REVENUE', 'COST OF REVENUE', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (90, 90, 0, 6, 'EXPENSES', 'EXPENSES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (100, 90, 1, 6, 'EXPENSES', 'EXPENSES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (101, 80, 1, 5, 'COST OF REVENUE', 'COST OF REVENUE', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (102, 70, 1, 4, 'REVENUE', 'REVENUE AND OTHER INCOME', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (103, 60, 1, 3, 'EQUITY', 'EQUITY AND RESERVES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (104, 50, 1, 2, 'LIABILITIES', 'LONG TERM LIABILITIES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (105, 40, 1, 2, 'LIABILITIES', 'CURRENT LIABILITIES', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (106, 30, 1, 1, 'ASSETS', 'CURRENT ASSETS', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (107, 20, 1, 1, 'ASSETS', 'INTANGIBLE ASSETS', NULL);
INSERT INTO accounts_class (accounts_class_id, accounts_class_no, org_id, chat_type_id, chat_type_name, accounts_class_name, details) VALUES (108, 10, 1, 1, 'ASSETS', 'FIXED ASSETS', NULL);


--
-- Name: accounts_class_accounts_class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('accounts_class_accounts_class_id_seq', 108, true);


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_address_id_seq', 1, false);


--
-- Data for Name: address_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_types_address_type_id_seq', 1, false);


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approval_checklists_approval_checklist_id_seq', 1, false);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approvals_approval_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approvals_approval_id_seq', 1, false);


--
-- Data for Name: bank_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO bank_accounts (bank_account_id, org_id, bank_branch_id, account_id, currency_id, bank_account_name, bank_account_number, narrative, is_default, is_active, details) VALUES (0, 0, 0, 33000, 1, 'Cash Account', NULL, NULL, true, true, NULL);


--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bank_accounts_bank_account_id_seq', 1, false);


--
-- Data for Name: bank_branch; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO bank_branch (bank_branch_id, bank_id, org_id, bank_branch_name, bank_branch_code, narrative) VALUES (0, 0, 0, 'Cash', NULL, NULL);


--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bank_branch_bank_branch_id_seq', 1, false);


--
-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO banks (bank_id, sys_country_id, org_id, bank_name, bank_code, swift_code, sort_code, narrative) VALUES (0, NULL, 0, 'Cash', NULL, NULL, NULL, NULL);


--
-- Name: banks_bank_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('banks_bank_id_seq', 1, false);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (1, 'Kenya Shillings', 'KES', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (2, 'US Dollar', 'USD', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (3, 'British Pound', 'BPD', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (4, 'Euro', 'ERO', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (5, 'US Dollar', 'USD', 1);


--
-- Name: currency_currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_currency_id_seq', 5, true);


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) VALUES (0, 1, 0, '2017-06-27', 1);
INSERT INTO currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) VALUES (1, 5, 1, '2017-08-28', 1);


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, true);


--
-- Data for Name: default_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (1, 90012, 23, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (2, 30005, 24, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (3, 40045, 25, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (4, 40055, 26, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (5, 90000, 27, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (6, 40055, 28, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (7, 90005, 29, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (8, 40055, 30, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (9, 90070, 31, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (10, 30000, 51, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (11, 40000, 52, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (12, 70005, 53, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (13, 80000, 54, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (14, 42000, 55, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (15, 99999, 56, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (16, 61000, 57, 0, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (17, 100108, 57, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (18, 100086, 56, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (19, 100124, 55, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (20, 100091, 54, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (21, 100094, 53, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (22, 100121, 52, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (23, 100132, 51, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (24, 100001, 31, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (25, 100110, 30, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (26, 100015, 29, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (27, 100110, 28, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (28, 100016, 27, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (29, 100110, 26, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (30, 100112, 25, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (31, 100131, 24, 1, NULL);
INSERT INTO default_accounts (default_account_id, account_id, use_key_id, org_id, narrative) VALUES (32, 100013, 23, 1, NULL);


--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('default_accounts_default_account_id_seq', 32, true);


--
-- Data for Name: default_tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('default_tax_types_default_tax_type_id_seq', 1, false);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO departments (department_id, ln_department_id, org_id, department_name, department_account, function_code, active, petty_cash, cost_center, revenue_center, description, duties, reports, details) VALUES (0, 0, 0, 'Board of Directors', NULL, NULL, true, false, true, true, NULL, NULL, NULL, NULL);


--
-- Name: departments_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('departments_department_id_seq', 1, false);


--
-- Data for Name: entity_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_fields_entity_field_id_seq', 1, false);


--
-- Data for Name: entity_subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entity_subscriptions (entity_subscription_id, entity_type_id, entity_id, subscription_level_id, org_id, details) VALUES (1, 0, 0, 0, 0, NULL);
INSERT INTO entity_subscriptions (entity_subscription_id, entity_type_id, entity_id, subscription_level_id, org_id, details) VALUES (2, 0, 1, 0, 0, NULL);


--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_subscriptions_entity_subscription_id_seq', 2, true);


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (0, 0, 0, 'Users', 'user', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (1, 1, 0, 'Staff', 'staff', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (2, 2, 0, 'Client', 'client', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (3, 3, 0, 'Supplier', 'supplier', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (4, 4, 0, 'Applicant', 'applicant', '10:0', NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (5, 5, 0, 'Subscription', 'subscription', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (6, 6, 0, 'Tenants', 'tenants', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (7, 0, 1, 'Users', 'user', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (8, 1, 1, 'Staff', 'staff', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (9, 2, 1, 'Client', 'client', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (10, 3, 1, 'Supplier', 'supplier', NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (11, 4, 1, 'Applicant', 'applicant', '10:0', NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, use_key_id, org_id, entity_type_name, entity_role, start_view, group_email, description, details) VALUES (12, 6, 1, 'Tenants', 'tenants', NULL, NULL, NULL, NULL);


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 12, true);


--
-- Data for Name: entity_values; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_values_entity_value_id_seq', 1, false);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entitys (entity_id, entity_type_id, use_key_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, attention, credit_limit, account_id) VALUES (0, 0, 0, 0, 'root', 'root', 'root@localhost', NULL, true, true, false, NULL, '2017-06-27 17:18:53.617653', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 0, NULL);
INSERT INTO entitys (entity_id, entity_type_id, use_key_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, attention, credit_limit, account_id) VALUES (1, 0, 0, 0, 'repository', 'repository', 'repository@localhost', NULL, false, true, false, NULL, '2017-06-27 17:18:53.617653', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 0, NULL);


--
-- Name: entitys_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entitys_entity_id_seq', 1, true);


--
-- Data for Name: entry_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entry_forms_entry_form_id_seq', 1, false);


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fields_field_id_seq', 1, false);


--
-- Data for Name: fiscal_years; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fiscal_years_fiscal_year_id_seq', 1, false);


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: forms_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('forms_form_id_seq', 1, false);


--
-- Data for Name: gls; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: gls_gl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('gls_gl_id_seq', 1, false);


--
-- Data for Name: helpdesk; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('helpdesk_helpdesk_id_seq', 1, false);


--
-- Data for Name: holidays; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('holidays_holiday_id_seq', 1, false);


--
-- Data for Name: industry; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: industry_industry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('industry_industry_id_seq', 1, false);


--
-- Data for Name: item_category; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO item_category (item_category_id, org_id, item_category_name, details) VALUES (1, 0, 'Services', NULL);
INSERT INTO item_category (item_category_id, org_id, item_category_name, details) VALUES (2, 0, 'Goods', NULL);
INSERT INTO item_category (item_category_id, org_id, item_category_name, details) VALUES (3, 0, 'Utilities', NULL);


--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('item_category_item_category_id_seq', 3, true);


--
-- Data for Name: item_units; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO item_units (item_unit_id, org_id, item_unit_name, details) VALUES (1, 0, 'Each', NULL);
INSERT INTO item_units (item_unit_id, org_id, item_unit_name, details) VALUES (2, 0, 'Man Hours', NULL);
INSERT INTO item_units (item_unit_id, org_id, item_unit_name, details) VALUES (3, 0, '100KG', NULL);


--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('item_units_item_unit_id_seq', 3, true);


--
-- Data for Name: items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: items_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('items_item_id_seq', 1, false);


--
-- Data for Name: journals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: journals_journal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('journals_journal_id_seq', 1, false);


--
-- Data for Name: ledger_links; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ledger_links_ledger_link_id_seq', 1, false);


--
-- Data for Name: ledger_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ledger_types_ledger_type_id_seq', 1, false);


--
-- Data for Name: log_period_rentals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: log_period_rentals_log_period_rental_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('log_period_rentals_log_period_rental_id_seq', 1, false);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_full_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details, org_client_id, payroll_payable, cert_number, vat_number, enforce_budget, invoice_footer, expiry_date) VALUES (0, 1, NULL, NULL, 'default', NULL, 'dc', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, NULL, true, NULL, NULL);
INSERT INTO orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_full_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details, org_client_id, payroll_payable, cert_number, vat_number, enforce_budget, invoice_footer, expiry_date) VALUES (1, 5, NULL, NULL, 'Default', NULL, 'df', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, NULL, true, NULL, NULL);


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, true);


--
-- Data for Name: payment_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO payment_types (payment_type_id, account_id, use_key_id, org_id, payment_type_name, is_active, details) VALUES (2, 34005, 101, 0, 'Rent Payment', true, NULL);
INSERT INTO payment_types (payment_type_id, account_id, use_key_id, org_id, payment_type_name, is_active, details) VALUES (3, 34005, 102, 0, 'Rent Remmitance', true, NULL);
INSERT INTO payment_types (payment_type_id, account_id, use_key_id, org_id, payment_type_name, is_active, details) VALUES (4, 34005, 103, 0, 'Rental Penalty Payment', true, NULL);
INSERT INTO payment_types (payment_type_id, account_id, use_key_id, org_id, payment_type_name, is_active, details) VALUES (5, 34005, 103, 0, 'Billing', true, NULL);


--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('payment_types_payment_type_id_seq', 22, true);


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: payments_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('payments_payment_id_seq', 1, false);


--
-- Data for Name: pdefinitions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pdefinitions_pdefinition_id_seq', 1, false);


--
-- Data for Name: period_rentals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: period_rentals_period_rental_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('period_rentals_period_rental_id_seq', 1, false);


--
-- Data for Name: period_tax_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('period_tax_rates_period_tax_rate_id_seq', 1, false);


--
-- Data for Name: period_tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('period_tax_types_period_tax_type_id_seq', 1, false);


--
-- Data for Name: periods; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: periods_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('periods_period_id_seq', 1, false);


--
-- Name: picture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('picture_id_seq', 1, false);


--
-- Data for Name: plevels; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('plevels_plevel_id_seq', 1, false);


--
-- Data for Name: property; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: property_property_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('property_property_id_seq', 1, false);


--
-- Data for Name: property_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO property_types (property_type_id, org_id, property_type_name, commercial_property, details) VALUES (1, 0, 'Apartments', false, NULL);


--
-- Name: property_types_property_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('property_types_property_type_id_seq', 1, true);


--
-- Data for Name: ptypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ptypes_ptype_id_seq', 1, false);


--
-- Data for Name: quotations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('quotations_quotation_id_seq', 1, false);


--
-- Data for Name: rentals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: rentals_rental_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('rentals_rental_id_seq', 1, false);


--
-- Data for Name: reporting; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reporting_reporting_id_seq', 1, false);


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: stores_store_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stores_store_id_seq', 1, false);


--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sub_fields_sub_field_id_seq', 1, false);


--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (0, 0, 'Basic', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (1, 0, 'Manager', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (2, 0, 'Consumer', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (4, 1, 'Basic', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (5, 1, 'Manager', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (6, 1, 'Consumer', NULL);


--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscription_levels_subscription_level_id_seq', 6, true);


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscriptions_subscription_id_seq', 1, false);


--
-- Data for Name: sys_audit_details; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sys_audit_trail; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_audit_trail_sys_audit_trail_id_seq', 1, false);


--
-- Data for Name: sys_continents; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AF', 'Africa');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AS', 'Asia');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('EU', 'Europe');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('NA', 'North America');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('SA', 'South America');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('OC', 'Oceania');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AN', 'Antarctica');


--
-- Data for Name: sys_countrys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AF', 'AS', 'AFG', '004', NULL, 'Afghanistan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AX', 'EU', 'ALA', '248', NULL, 'Aland Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AL', 'EU', 'ALB', '008', NULL, 'Albania', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DZ', 'AF', 'DZA', '012', NULL, 'Algeria', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AS', 'OC', 'ASM', '016', NULL, 'American Samoa', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AD', 'EU', 'AND', '020', NULL, 'Andorra', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AO', 'AF', 'AGO', '024', NULL, 'Angola', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AI', 'NA', 'AIA', '660', NULL, 'Anguilla', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AQ', 'AN', 'ATA', '010', NULL, 'Antarctica', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AG', 'NA', 'ATG', '028', NULL, 'Antigua and Barbuda', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AR', 'SA', 'ARG', '032', NULL, 'Argentina', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AM', 'AS', 'ARM', '051', NULL, 'Armenia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AW', 'NA', 'ABW', '533', NULL, 'Aruba', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AU', 'OC', 'AUS', '036', NULL, 'Australia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AT', 'EU', 'AUT', '040', NULL, 'Austria', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AZ', 'AS', 'AZE', '031', NULL, 'Azerbaijan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BS', 'NA', 'BHS', '044', NULL, 'Bahamas', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BH', 'AS', 'BHR', '048', NULL, 'Bahrain', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BD', 'AS', 'BGD', '050', NULL, 'Bangladesh', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BB', 'NA', 'BRB', '052', NULL, 'Barbados', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BY', 'EU', 'BLR', '112', NULL, 'Belarus', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BE', 'EU', 'BEL', '056', NULL, 'Belgium', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BZ', 'NA', 'BLZ', '084', NULL, 'Belize', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BJ', 'AF', 'BEN', '204', NULL, 'Benin', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BM', 'NA', 'BMU', '060', NULL, 'Bermuda', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BT', 'AS', 'BTN', '064', NULL, 'Bhutan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BO', 'SA', 'BOL', '068', NULL, 'Bolivia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BA', 'EU', 'BIH', '070', NULL, 'Bosnia and Herzegovina', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BW', 'AF', 'BWA', '072', NULL, 'Botswana', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BV', 'AN', 'BVT', '074', NULL, 'Bouvet Island', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BR', 'SA', 'BRA', '076', NULL, 'Brazil', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IO', 'AS', 'IOT', '086', NULL, 'British Indian Ocean Territory', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VG', 'NA', 'VGB', '092', NULL, 'British Virgin Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BN', 'AS', 'BRN', '096', NULL, 'Brunei Darussalam', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BG', 'EU', 'BGR', '100', NULL, 'Bulgaria', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BF', 'AF', 'BFA', '854', NULL, 'Burkina Faso', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BI', 'AF', 'BDI', '108', NULL, 'Burundi', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KH', 'AS', 'KHM', '116', NULL, 'Cambodia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CM', 'AF', 'CMR', '120', NULL, 'Cameroon', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CA', 'NA', 'CAN', '124', NULL, 'Canada', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CV', 'AF', 'CPV', '132', NULL, 'Cape Verde', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KY', 'NA', 'CYM', '136', NULL, 'Cayman Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CF', 'AF', 'CAF', '140', NULL, 'Central African Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TD', 'AF', 'TCD', '148', NULL, 'Chad', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CL', 'SA', 'CHL', '152', NULL, 'Chile', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CN', 'AS', 'CHN', '156', NULL, 'China', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CX', 'AS', 'CXR', '162', NULL, 'Christmas Island', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CC', 'AS', 'CCK', '166', NULL, 'Cocos Keeling Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CO', 'SA', 'COL', '170', NULL, 'Colombia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KM', 'AF', 'COM', '174', NULL, 'Comoros', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CD', 'AF', 'COD', '180', NULL, 'Democratic Republic of Congo', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CG', 'AF', 'COG', '178', NULL, 'Republic of Congo', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CK', 'OC', 'COK', '184', NULL, 'Cook Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CR', 'NA', 'CRI', '188', NULL, 'Costa Rica', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CI', 'AF', 'CIV', '384', NULL, 'Cote d Ivoire', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HR', 'EU', 'HRV', '191', NULL, 'Croatia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CU', 'NA', 'CUB', '192', NULL, 'Cuba', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CY', 'AS', 'CYP', '196', NULL, 'Cyprus', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CZ', 'EU', 'CZE', '203', NULL, 'Czech Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DK', 'EU', 'DNK', '208', NULL, 'Denmark', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DJ', 'AF', 'DJI', '262', NULL, 'Djibouti', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DM', 'NA', 'DMA', '212', NULL, 'Dominica', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DO', 'NA', 'DOM', '214', NULL, 'Dominican Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('EC', 'SA', 'ECU', '218', NULL, 'Ecuador', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('EG', 'AF', 'EGY', '818', NULL, 'Egypt', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SV', 'NA', 'SLV', '222', NULL, 'El Salvador', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GQ', 'AF', 'GNQ', '226', NULL, 'Equatorial Guinea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ER', 'AF', 'ERI', '232', NULL, 'Eritrea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('EE', 'EU', 'EST', '233', NULL, 'Estonia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ET', 'AF', 'ETH', '231', NULL, 'Ethiopia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FO', 'EU', 'FRO', '234', NULL, 'Faroe Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FK', 'SA', 'FLK', '238', NULL, 'Falkland Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FJ', 'OC', 'FJI', '242', NULL, 'Fiji', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FI', 'EU', 'FIN', '246', NULL, 'Finland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FR', 'EU', 'FRA', '250', NULL, 'France', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GF', 'SA', 'GUF', '254', NULL, 'French Guiana', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PF', 'OC', 'PYF', '258', NULL, 'French Polynesia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TF', 'AN', 'ATF', '260', NULL, 'French Southern Territories', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GA', 'AF', 'GAB', '266', NULL, 'Gabon', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GM', 'AF', 'GMB', '270', NULL, 'Gambia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GE', 'AS', 'GEO', '268', NULL, 'Georgia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('DE', 'EU', 'DEU', '276', NULL, 'Germany', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GH', 'AF', 'GHA', '288', NULL, 'Ghana', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GI', 'EU', 'GIB', '292', NULL, 'Gibraltar', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GR', 'EU', 'GRC', '300', NULL, 'Greece', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GL', 'NA', 'GRL', '304', NULL, 'Greenland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GD', 'NA', 'GRD', '308', NULL, 'Grenada', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GP', 'NA', 'GLP', '312', NULL, 'Guadeloupe', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GU', 'OC', 'GUM', '316', NULL, 'Guam', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GT', 'NA', 'GTM', '320', NULL, 'Guatemala', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GG', 'EU', 'GGY', '831', NULL, 'Guernsey', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GN', 'AF', 'GIN', '324', NULL, 'Guinea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GW', 'AF', 'GNB', '624', NULL, 'Guinea-Bissau', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GY', 'SA', 'GUY', '328', NULL, 'Guyana', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HT', 'NA', 'HTI', '332', NULL, 'Haiti', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HM', 'AN', 'HMD', '334', NULL, 'Heard Island and McDonald Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VA', 'EU', 'VAT', '336', NULL, 'Vatican City State', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HN', 'NA', 'HND', '340', NULL, 'Honduras', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HK', 'AS', 'HKG', '344', NULL, 'Hong Kong', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('HU', 'EU', 'HUN', '348', NULL, 'Hungary', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IS', 'EU', 'ISL', '352', NULL, 'Iceland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IN', 'AS', 'IND', '356', NULL, 'India', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ID', 'AS', 'IDN', '360', NULL, 'Indonesia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IR', 'AS', 'IRN', '364', NULL, 'Iran', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IQ', 'AS', 'IRQ', '368', NULL, 'Iraq', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IE', 'EU', 'IRL', '372', NULL, 'Ireland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IM', 'EU', 'IMN', '833', NULL, 'Isle of Man', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IL', 'AS', 'ISR', '376', NULL, 'Israel', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('IT', 'EU', 'ITA', '380', NULL, 'Italy', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('JM', 'NA', 'JAM', '388', NULL, 'Jamaica', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('JP', 'AS', 'JPN', '392', NULL, 'Japan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('JE', 'EU', 'JEY', '832', NULL, 'Bailiwick of Jersey', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('JO', 'AS', 'JOR', '400', NULL, 'Jordan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KZ', 'AS', 'KAZ', '398', NULL, 'Kazakhstan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KE', 'AF', 'KEN', '404', NULL, 'Kenya', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KI', 'OC', 'KIR', '296', NULL, 'Kiribati', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KP', 'AS', 'PRK', '408', NULL, 'North Korea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KR', 'AS', 'KOR', '410', NULL, 'South Korea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KW', 'AS', 'KWT', '414', NULL, 'Kuwait', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KG', 'AS', 'KGZ', '417', NULL, 'Kyrgyz Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LA', 'AS', 'LAO', '418', NULL, 'Lao Peoples Democratic Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LV', 'EU', 'LVA', '428', NULL, 'Latvia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LB', 'AS', 'LBN', '422', NULL, 'Lebanon', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LS', 'AF', 'LSO', '426', NULL, 'Lesotho', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LR', 'AF', 'LBR', '430', NULL, 'Liberia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LY', 'AF', 'LBY', '434', NULL, 'Libyan Arab Jamahiriya', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LI', 'EU', 'LIE', '438', NULL, 'Liechtenstein', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LT', 'EU', 'LTU', '440', NULL, 'Lithuania', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LU', 'EU', 'LUX', '442', NULL, 'Luxembourg', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MO', 'AS', 'MAC', '446', NULL, 'Macao', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MK', 'EU', 'MKD', '807', NULL, 'Macedonia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MG', 'AF', 'MDG', '450', NULL, 'Madagascar', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MW', 'AF', 'MWI', '454', NULL, 'Malawi', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MY', 'AS', 'MYS', '458', NULL, 'Malaysia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MV', 'AS', 'MDV', '462', NULL, 'Maldives', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ML', 'AF', 'MLI', '466', NULL, 'Mali', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MT', 'EU', 'MLT', '470', NULL, 'Malta', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MH', 'OC', 'MHL', '584', NULL, 'Marshall Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MQ', 'NA', 'MTQ', '474', NULL, 'Martinique', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MR', 'AF', 'MRT', '478', NULL, 'Mauritania', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MU', 'AF', 'MUS', '480', NULL, 'Mauritius', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('YT', 'AF', 'MYT', '175', NULL, 'Mayotte', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MX', 'NA', 'MEX', '484', NULL, 'Mexico', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('FM', 'OC', 'FSM', '583', NULL, 'Micronesia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MD', 'EU', 'MDA', '498', NULL, 'Moldova', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MC', 'EU', 'MCO', '492', NULL, 'Monaco', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MN', 'AS', 'MNG', '496', NULL, 'Mongolia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ME', 'EU', 'MNE', '499', NULL, 'Montenegro', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MS', 'NA', 'MSR', '500', NULL, 'Montserrat', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MA', 'AF', 'MAR', '504', NULL, 'Morocco', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MZ', 'AF', 'MOZ', '508', NULL, 'Mozambique', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MM', 'AS', 'MMR', '104', NULL, 'Myanmar', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NA', 'AF', 'NAM', '516', NULL, 'Namibia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NR', 'OC', 'NRU', '520', NULL, 'Nauru', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NP', 'AS', 'NPL', '524', NULL, 'Nepal', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AN', 'NA', 'ANT', '530', NULL, 'Netherlands Antilles', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NL', 'EU', 'NLD', '528', NULL, 'Netherlands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NC', 'OC', 'NCL', '540', NULL, 'New Caledonia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NZ', 'OC', 'NZL', '554', NULL, 'New Zealand', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NI', 'NA', 'NIC', '558', NULL, 'Nicaragua', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NE', 'AF', 'NER', '562', NULL, 'Niger', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NG', 'AF', 'NGA', '566', NULL, 'Nigeria', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NU', 'OC', 'NIU', '570', NULL, 'Niue', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NF', 'OC', 'NFK', '574', NULL, 'Norfolk Island', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MP', 'OC', 'MNP', '580', NULL, 'Northern Mariana Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('NO', 'EU', 'NOR', '578', NULL, 'Norway', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('OM', 'AS', 'OMN', '512', NULL, 'Oman', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PK', 'AS', 'PAK', '586', NULL, 'Pakistan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PW', 'OC', 'PLW', '585', NULL, 'Palau', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PS', 'AS', 'PSE', '275', NULL, 'Palestinian Territory', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PA', 'NA', 'PAN', '591', NULL, 'Panama', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PG', 'OC', 'PNG', '598', NULL, 'Papua New Guinea', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PY', 'SA', 'PRY', '600', NULL, 'Paraguay', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PE', 'SA', 'PER', '604', NULL, 'Peru', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PH', 'AS', 'PHL', '608', NULL, 'Philippines', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PN', 'OC', 'PCN', '612', NULL, 'Pitcairn Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PL', 'EU', 'POL', '616', NULL, 'Poland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PT', 'EU', 'PRT', '620', NULL, 'Portugal', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PR', 'NA', 'PRI', '630', NULL, 'Puerto Rico', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('QA', 'AS', 'QAT', '634', NULL, 'Qatar', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('RE', 'AF', 'REU', '638', NULL, 'Reunion', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('RO', 'EU', 'ROU', '642', NULL, 'Romania', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('RU', 'EU', 'RUS', '643', NULL, 'Russian Federation', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('RW', 'AF', 'RWA', '646', NULL, 'Rwanda', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('BL', 'NA', 'BLM', '652', NULL, 'Saint Barthelemy', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SH', 'AF', 'SHN', '654', NULL, 'Saint Helena', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('KN', 'NA', 'KNA', '659', NULL, 'Saint Kitts and Nevis', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LC', 'NA', 'LCA', '662', NULL, 'Saint Lucia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('MF', 'NA', 'MAF', '663', NULL, 'Saint Martin', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('PM', 'NA', 'SPM', '666', NULL, 'Saint Pierre and Miquelon', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VC', 'NA', 'VCT', '670', NULL, 'Saint Vincent and the Grenadines', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('WS', 'OC', 'WSM', '882', NULL, 'Samoa', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SM', 'EU', 'SMR', '674', NULL, 'San Marino', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ST', 'AF', 'STP', '678', NULL, 'Sao Tome and Principe', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SA', 'AS', 'SAU', '682', NULL, 'Saudi Arabia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SN', 'AF', 'SEN', '686', NULL, 'Senegal', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('RS', 'EU', 'SRB', '688', NULL, 'Serbia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SC', 'AF', 'SYC', '690', NULL, 'Seychelles', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SL', 'AF', 'SLE', '694', NULL, 'Sierra Leone', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SG', 'AS', 'SGP', '702', NULL, 'Singapore', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SK', 'EU', 'SVK', '703', NULL, 'Slovakia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SI', 'EU', 'SVN', '705', NULL, 'Slovenia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SB', 'OC', 'SLB', '090', NULL, 'Solomon Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SO', 'AF', 'SOM', '706', NULL, 'Somalia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ZA', 'AF', 'ZAF', '710', NULL, 'South Africa', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GS', 'AN', 'SGS', '239', NULL, 'South Georgia and the South Sandwich Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ES', 'EU', 'ESP', '724', NULL, 'Spain', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('LK', 'AS', 'LKA', '144', NULL, 'Sri Lanka', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SD', 'AF', 'SDN', '736', NULL, 'Sudan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SS', 'AF', 'SSN', '737', NULL, 'South Sudan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SR', 'SA', 'SUR', '740', NULL, 'Suriname', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SJ', 'EU', 'SJM', '744', NULL, 'Svalbard & Jan Mayen Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SZ', 'AF', 'SWZ', '748', NULL, 'Swaziland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SE', 'EU', 'SWE', '752', NULL, 'Sweden', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('CH', 'EU', 'CHE', '756', NULL, 'Switzerland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('SY', 'AS', 'SYR', '760', NULL, 'Syrian Arab Republic', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TW', 'AS', 'TWN', '158', NULL, 'Taiwan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TJ', 'AS', 'TJK', '762', NULL, 'Tajikistan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TZ', 'AF', 'TZA', '834', NULL, 'Tanzania', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TH', 'AS', 'THA', '764', NULL, 'Thailand', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TL', 'AS', 'TLS', '626', NULL, 'Timor-Leste', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TG', 'AF', 'TGO', '768', NULL, 'Togo', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TK', 'OC', 'TKL', '772', NULL, 'Tokelau', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TO', 'OC', 'TON', '776', NULL, 'Tonga', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TT', 'NA', 'TTO', '780', NULL, 'Trinidad and Tobago', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TN', 'AF', 'TUN', '788', NULL, 'Tunisia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TR', 'AS', 'TUR', '792', NULL, 'Turkey', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TM', 'AS', 'TKM', '795', NULL, 'Turkmenistan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TC', 'NA', 'TCA', '796', NULL, 'Turks and Caicos Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('TV', 'OC', 'TUV', '798', NULL, 'Tuvalu', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('UG', 'AF', 'UGA', '800', NULL, 'Uganda', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('UA', 'EU', 'UKR', '804', NULL, 'Ukraine', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('AE', 'AS', 'ARE', '784', NULL, 'United Arab Emirates', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('GB', 'EU', 'GBR', '826', NULL, 'United Kingdom of Great Britain & Northern Ireland', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('US', 'NA', 'USA', '840', NULL, 'United States of America', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('UM', 'OC', 'UMI', '581', NULL, 'United States Minor Outlying Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VI', 'NA', 'VIR', '850', NULL, 'United States Virgin Islands', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('UY', 'SA', 'URY', '858', NULL, 'Uruguay', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('UZ', 'AS', 'UZB', '860', NULL, 'Uzbekistan', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VU', 'OC', 'VUT', '548', NULL, 'Vanuatu', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VE', 'SA', 'VEN', '862', NULL, 'Venezuela', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('VN', 'AS', 'VNM', '704', NULL, 'Vietnam', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('WF', 'OC', 'WLF', '876', NULL, 'Wallis and Futuna', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('EH', 'AF', 'ESH', '732', NULL, 'Western Sahara', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('YE', 'AS', 'YEM', '887', NULL, 'Yemen', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ZM', 'AF', 'ZMB', '894', NULL, 'Zambia', NULL, NULL, NULL, NULL);
INSERT INTO sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) VALUES ('ZW', 'AF', 'ZWE', '716', NULL, 'Zimbabwe', NULL, NULL, NULL, NULL);


--
-- Data for Name: sys_dashboard; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_dashboard_sys_dashboard_id_seq', 1, false);


--
-- Data for Name: sys_emailed; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emailed_sys_emailed_id_seq', 1, false);


--
-- Data for Name: sys_emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (1, 0, 1, 'Tenant Rent Adjustment', '', 'Tenant Rent Adjustment', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (2, 0, 2, 'Release of bills/invoices', '', 'Release of bills/invoices', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (3, 0, 3, 'Overdue Payment', '', 'Overdue Payment', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (4, 0, 4, 'contracts/rental agreements', '', 'contracts/rental agreements', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (5, 1, 4, 'contracts/rental agreements', NULL, 'contracts/rental agreements', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (6, 1, 3, 'Overdue Payment', NULL, 'Overdue Payment', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (7, 1, 2, 'Release of bills/invoices', NULL, 'Release of bills/invoices', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (8, 1, 1, 'Tenant Rent Adjustment', NULL, 'Tenant Rent Adjustment', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (9, 1, 4, 'contracts/rental agreements', NULL, 'contracts/rental agreements', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (10, 1, 3, 'Overdue Payment', NULL, 'Overdue Payment', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (11, 1, 2, 'Release of bills/invoices', NULL, 'Release of bills/invoices', '');
INSERT INTO sys_emails (sys_email_id, org_id, use_type, sys_email_name, default_email, title, details) VALUES (12, 1, 1, 'Tenant Rent Adjustment', NULL, 'Tenant Rent Adjustment', '');


--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 12, true);


--
-- Data for Name: sys_errors; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_errors_sys_error_id_seq', 1, false);


--
-- Data for Name: sys_files; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_files_sys_file_id_seq', 1, false);


--
-- Data for Name: sys_logins; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (1, 0, '2017-08-25 17:03:36.739703', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (2, 0, '2017-08-28 10:08:06.282369', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (3, 0, '2017-08-28 10:08:49.766289', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (4, 0, '2017-08-28 10:08:50.440663', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (5, 0, '2017-08-28 10:08:53.213923', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (6, 0, '2017-08-28 10:09:16.096948', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (7, 0, '2017-08-28 10:09:16.651112', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (8, 0, '2017-08-28 10:09:19.922365', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (9, 0, '2017-08-28 10:09:20.501182', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (10, 0, '2017-08-28 10:09:21.820593', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (11, 0, '2017-08-28 10:09:22.372129', '127.0.0.1', NULL);


--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 11, true);


--
-- Data for Name: sys_menu_msg; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_menu_msg_sys_menu_msg_id_seq', 1, false);


--
-- Data for Name: sys_news; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_news_sys_news_id_seq', 1, false);


--
-- Data for Name: sys_queries; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_queries_sys_queries_id_seq', 1, false);


--
-- Data for Name: sys_reset; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_reset_sys_reset_id_seq', 1, false);


--
-- Data for Name: tax_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tax_rates_tax_rate_id_seq', 1, false);


--
-- Data for Name: tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO tax_types (tax_type_id, account_id, currency_id, use_key_id, sys_country_id, org_id, tax_type_name, tax_type_number, formural, tax_relief, tax_type_order, in_tax, tax_rate, tax_inclusive, linear, percentage, employer, employer_ps, account_number, employer_account, active, details) VALUES (1, 42000, 1, 15, NULL, 0, 'Exempt', NULL, NULL, 0, 0, false, 0, false, true, true, 0, 0, NULL, NULL, true, NULL);
INSERT INTO tax_types (tax_type_id, account_id, currency_id, use_key_id, sys_country_id, org_id, tax_type_name, tax_type_number, formural, tax_relief, tax_type_order, in_tax, tax_rate, tax_inclusive, linear, percentage, employer, employer_ps, account_number, employer_account, active, details) VALUES (2, 42000, 1, 15, NULL, 0, 'VAT', NULL, NULL, 0, 0, false, 16, false, true, true, 0, 0, NULL, NULL, true, NULL);


--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tax_types_tax_type_id_seq', 2, true);


--
-- Data for Name: transaction_counters; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (1, 16, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (2, 14, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (3, 15, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (4, 1, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (5, 2, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (6, 3, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (7, 4, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (8, 5, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (9, 6, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (10, 7, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (11, 8, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (12, 9, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (13, 10, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (14, 11, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (15, 12, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (16, 17, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (17, 21, 0, 10001);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (18, 22, 0, 10001);


--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_counters_transaction_counter_id_seq', 18, true);


--
-- Data for Name: transaction_details; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_details_transaction_detail_id_seq', 1, false);


--
-- Data for Name: transaction_links; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_links_transaction_link_id_seq', 1, false);


--
-- Data for Name: transaction_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_status (transaction_status_id, transaction_status_name) VALUES (1, 'Draft');
INSERT INTO transaction_status (transaction_status_id, transaction_status_name) VALUES (2, 'Completed');
INSERT INTO transaction_status (transaction_status_id, transaction_status_name) VALUES (3, 'Processed');
INSERT INTO transaction_status (transaction_status_id, transaction_status_name) VALUES (4, 'Archive');


--
-- Data for Name: transaction_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (16, 'Requisitions', 'D', false, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (14, 'Sales Quotation', 'D', true, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (15, 'Purchase Quotation', 'D', false, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (1, 'Sales Order', 'D', true, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (2, 'Sales Invoice', 'D', true, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (3, 'Sales Template', 'D', true, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (4, 'Purchase Order', 'D', false, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (5, 'Purchase Invoice', 'D', false, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (6, 'Purchase Template', 'D', false, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (7, 'Receipts', 'D', true, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (8, 'Payments', 'D', false, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (9, 'Credit Note', 'D', true, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (10, 'Debit Note', 'D', false, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (11, 'Delivery Note', 'D', true, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (12, 'Receipt Note', 'D', false, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (17, 'Work Use', 'D', true, false);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (21, 'Direct Expenditure', 'D', true, true);
INSERT INTO transaction_types (transaction_type_id, transaction_type_name, document_prefix, for_sales, for_posting) VALUES (22, 'Direct Income', 'D', false, true);


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transactions_transaction_id_seq', 1, false);


--
-- Data for Name: use_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (0, 'Users', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (1, 'Staff', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (2, 'Client', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (3, 'Supplier', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (4, 'Applicant', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (5, 'Subscription', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (15, 'Transaction Tax', 2);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (23, 'Travel Cost', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (24, 'Travel Payment', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (25, 'Travel Tax', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (26, 'Salary Payment', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (27, 'Basic Salary', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (28, 'Payroll Advance', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (29, 'Staff Allowance', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (30, 'Staff Remitance', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (31, 'Staff Expenditure', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (51, 'Client Account', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (52, 'Supplier Account', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (53, 'Sales Account', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (54, 'Purchase Account', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (55, 'VAT Account', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (56, 'Suplus/Deficit', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (57, 'Retained Earnings', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (101, 'Payment', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (102, 'Receipts/Remmitance', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (103, 'Penalty Payments', 3);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (6, 'Tenants', 0);


--
-- Data for Name: workflow_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_logs_workflow_log_id_seq', 1, false);


--
-- Data for Name: workflow_phases; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (1, 1, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (2, 2, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (3, 3, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (4, 4, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (5, 5, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (14, 17, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (15, 16, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (16, 15, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases (workflow_phase_id, workflow_id, approval_entity_id, org_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, reporting_level, use_reporting, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) VALUES (17, 14, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 17, true);


--
-- Data for Name: workflow_sql; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: workflow_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_table_id_seq', 1, false);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (1, 0, 0, 'Budget', 'budgets', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (2, 0, 0, 'Requisition', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (3, 3, 0, 'Purchase Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (4, 2, 0, 'Sales Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (5, 5, 0, 'subscriptions', 'subscriptions', NULL, NULL, 'subscription approved', 'subscription rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (14, 7, 1, 'Budget', 'budgets', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 1, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (15, 7, 1, 'Requisition', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 2, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (16, 10, 1, 'Purchase Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 3, NULL);
INSERT INTO workflows (workflow_id, source_entity_id, org_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, link_copy, details) VALUES (17, 9, 1, 'Sales Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 4, NULL);


--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflows_workflow_id_seq', 17, true);


--
-- Name: account_types_account_type_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_account_type_no_org_id_key UNIQUE (account_type_no, org_id);


--
-- Name: account_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_pkey PRIMARY KEY (account_type_id);


--
-- Name: accounts_account_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_account_no_org_id_key UNIQUE (account_no, org_id);


--
-- Name: accounts_class_accounts_class_name_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts_class
    ADD CONSTRAINT accounts_class_accounts_class_name_org_id_key UNIQUE (accounts_class_name, org_id);


--
-- Name: accounts_class_accounts_class_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts_class
    ADD CONSTRAINT accounts_class_accounts_class_no_org_id_key UNIQUE (accounts_class_no, org_id);


--
-- Name: accounts_class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts_class
    ADD CONSTRAINT accounts_class_pkey PRIMARY KEY (accounts_class_id);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_id);


--
-- Name: address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: address_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (address_type_id);


--
-- Name: approval_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_pkey PRIMARY KEY (approval_checklist_id);


--
-- Name: approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (approval_id);


--
-- Name: bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_pkey PRIMARY KEY (bank_account_id);


--
-- Name: bank_branch_bank_id_bank_branch_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_bank_id_bank_branch_name_key UNIQUE (bank_id, bank_branch_name);


--
-- Name: bank_branch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_pkey PRIMARY KEY (bank_branch_id);


--
-- Name: banks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (bank_id);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: currency_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (currency_id);


--
-- Name: currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (currency_rate_id);


--
-- Name: default_accounts_account_id_use_key_id_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_account_id_use_key_id_org_id_key UNIQUE (account_id, use_key_id, org_id);


--
-- Name: default_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_pkey PRIMARY KEY (default_account_id);


--
-- Name: default_tax_types_entity_id_tax_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_entity_id_tax_type_id_key UNIQUE (entity_id, tax_type_id);


--
-- Name: default_tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_pkey PRIMARY KEY (default_tax_type_id);


--
-- Name: departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: entity_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_pkey PRIMARY KEY (entity_field_id);


--
-- Name: entity_subscriptions_entity_id_entity_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_entity_type_id_key UNIQUE (entity_id, entity_type_id);


--
-- Name: entity_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_pkey PRIMARY KEY (entity_subscription_id);


--
-- Name: entity_types_org_id_entity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_entity_type_name_key UNIQUE (org_id, entity_type_name);


--
-- Name: entity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (entity_type_id);


--
-- Name: entity_values_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_pkey PRIMARY KEY (entity_value_id);


--
-- Name: entitys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_pkey PRIMARY KEY (entity_id);


--
-- Name: entitys_user_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_user_name_key UNIQUE (user_name);


--
-- Name: entry_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_pkey PRIMARY KEY (entry_form_id);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: fiscal_years_fiscal_year_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_fiscal_year_org_id_key UNIQUE (fiscal_year, org_id);


--
-- Name: fiscal_years_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_pkey PRIMARY KEY (fiscal_year_id);


--
-- Name: forms_form_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_form_name_version_key UNIQUE (form_name, version);


--
-- Name: forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_pkey PRIMARY KEY (form_id);


--
-- Name: gls_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_pkey PRIMARY KEY (gl_id);


--
-- Name: helpdesk_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_pkey PRIMARY KEY (helpdesk_id);


--
-- Name: holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (holiday_id);


--
-- Name: industry_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY industry
    ADD CONSTRAINT industry_pkey PRIMARY KEY (industry_id);


--
-- Name: item_category_org_id_item_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_org_id_item_category_name_key UNIQUE (org_id, item_category_name);


--
-- Name: item_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_pkey PRIMARY KEY (item_category_id);


--
-- Name: item_units_org_id_item_unit_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_org_id_item_unit_name_key UNIQUE (org_id, item_unit_name);


--
-- Name: item_units_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_pkey PRIMARY KEY (item_unit_id);


--
-- Name: items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_pkey PRIMARY KEY (item_id);


--
-- Name: journals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (journal_id);


--
-- Name: ledger_links_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_pkey PRIMARY KEY (ledger_link_id);


--
-- Name: ledger_types_org_id_ledger_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_org_id_ledger_type_name_key UNIQUE (org_id, ledger_type_name);


--
-- Name: ledger_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_pkey PRIMARY KEY (ledger_type_id);


--
-- Name: log_period_rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY log_period_rentals
    ADD CONSTRAINT log_period_rentals_pkey PRIMARY KEY (log_period_rental_id);


--
-- Name: orgs_org_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_name_key UNIQUE (org_name);


--
-- Name: orgs_org_sufix_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_sufix_key UNIQUE (org_sufix);


--
-- Name: orgs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_pkey PRIMARY KEY (org_id);


--
-- Name: payment_types_org_id_payment_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_org_id_payment_type_name_key UNIQUE (org_id, payment_type_name);


--
-- Name: payment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_pkey PRIMARY KEY (payment_type_id);


--
-- Name: payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (payment_id);


--
-- Name: pdefinitions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_pkey PRIMARY KEY (pdefinition_id);


--
-- Name: period_rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_pkey PRIMARY KEY (period_rental_id);


--
-- Name: period_tax_rates_period_tax_type_id_tax_rate_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_period_tax_type_id_tax_rate_id_key UNIQUE (period_tax_type_id, tax_rate_id);


--
-- Name: period_tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_pkey PRIMARY KEY (period_tax_rate_id);


--
-- Name: period_tax_types_period_id_tax_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_period_id_tax_type_id_key UNIQUE (period_id, tax_type_id);


--
-- Name: period_tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_pkey PRIMARY KEY (period_tax_type_id);


--
-- Name: periods_org_id_start_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_org_id_start_date_key UNIQUE (org_id, start_date);


--
-- Name: periods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_pkey PRIMARY KEY (period_id);


--
-- Name: plevels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_pkey PRIMARY KEY (plevel_id);


--
-- Name: plevels_plevel_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_plevel_name_key UNIQUE (plevel_name);


--
-- Name: property_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY property
    ADD CONSTRAINT property_pkey PRIMARY KEY (property_id);


--
-- Name: property_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY property_types
    ADD CONSTRAINT property_types_pkey PRIMARY KEY (property_type_id);


--
-- Name: ptypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ptypes
    ADD CONSTRAINT ptypes_pkey PRIMARY KEY (ptype_id);


--
-- Name: quotations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_pkey PRIMARY KEY (quotation_id);


--
-- Name: rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rentals
    ADD CONSTRAINT rentals_pkey PRIMARY KEY (rental_id);


--
-- Name: reporting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_pkey PRIMARY KEY (reporting_id);


--
-- Name: stores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (store_id);


--
-- Name: sub_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_pkey PRIMARY KEY (sub_field_id);


--
-- Name: subscription_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_pkey PRIMARY KEY (subscription_level_id);


--
-- Name: subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (subscription_id);


--
-- Name: sys_audit_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_audit_trail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_trail
    ADD CONSTRAINT sys_audit_trail_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_continents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_pkey PRIMARY KEY (sys_continent_id);


--
-- Name: sys_continents_sys_continent_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_sys_continent_name_key UNIQUE (sys_continent_name);


--
-- Name: sys_countrys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_pkey PRIMARY KEY (sys_country_id);


--
-- Name: sys_countrys_sys_country_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_country_name_key UNIQUE (sys_country_name);


--
-- Name: sys_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_pkey PRIMARY KEY (sys_dashboard_id);


--
-- Name: sys_emailed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_pkey PRIMARY KEY (sys_emailed_id);


--
-- Name: sys_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_pkey PRIMARY KEY (sys_email_id);


--
-- Name: sys_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_errors
    ADD CONSTRAINT sys_errors_pkey PRIMARY KEY (sys_error_id);


--
-- Name: sys_files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_pkey PRIMARY KEY (sys_file_id);


--
-- Name: sys_logins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_pkey PRIMARY KEY (sys_login_id);


--
-- Name: sys_menu_msg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_menu_msg
    ADD CONSTRAINT sys_menu_msg_pkey PRIMARY KEY (sys_menu_msg_id);


--
-- Name: sys_news_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_pkey PRIMARY KEY (sys_news_id);


--
-- Name: sys_queries_org_id_sys_query_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_sys_query_name_key UNIQUE (org_id, sys_query_name);


--
-- Name: sys_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_pkey PRIMARY KEY (sys_queries_id);


--
-- Name: sys_reset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_pkey PRIMARY KEY (sys_reset_id);


--
-- Name: tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_pkey PRIMARY KEY (tax_rate_id);


--
-- Name: tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_pkey PRIMARY KEY (tax_type_id);


--
-- Name: tax_types_tax_type_name_org_id_sys_country_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_tax_type_name_org_id_sys_country_id_key UNIQUE (tax_type_name, org_id, sys_country_id);


--
-- Name: transaction_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_pkey PRIMARY KEY (transaction_counter_id);


--
-- Name: transaction_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_pkey PRIMARY KEY (transaction_detail_id);


--
-- Name: transaction_links_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_pkey PRIMARY KEY (transaction_link_id);


--
-- Name: transaction_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_status
    ADD CONSTRAINT transaction_status_pkey PRIMARY KEY (transaction_status_id);


--
-- Name: transaction_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_types
    ADD CONSTRAINT transaction_types_pkey PRIMARY KEY (transaction_type_id);


--
-- Name: transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: use_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY use_keys
    ADD CONSTRAINT use_keys_pkey PRIMARY KEY (use_key_id);


--
-- Name: workflow_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_pkey PRIMARY KEY (workflow_log_id);


--
-- Name: workflow_phases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_pkey PRIMARY KEY (workflow_phase_id);


--
-- Name: workflow_sql_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_pkey PRIMARY KEY (workflow_sql_id);


--
-- Name: workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (workflow_id);


--
-- Name: account_types_accounts_class_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_types_accounts_class_id ON account_types USING btree (accounts_class_id);


--
-- Name: account_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_types_org_id ON account_types USING btree (org_id);


--
-- Name: accounts_account_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_account_type_id ON accounts USING btree (account_type_id);


--
-- Name: accounts_class_chat_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_class_chat_type_id ON accounts_class USING btree (chat_type_id);


--
-- Name: accounts_class_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_class_org_id ON accounts_class USING btree (org_id);


--
-- Name: accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_org_id ON accounts USING btree (org_id);


--
-- Name: address_address_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_address_type_id ON address USING btree (address_type_id);


--
-- Name: address_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_org_id ON address USING btree (org_id);


--
-- Name: address_sys_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_sys_country_id ON address USING btree (sys_country_id);


--
-- Name: address_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_id ON address USING btree (table_id);


--
-- Name: address_table_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_name ON address USING btree (table_name);


--
-- Name: address_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_types_org_id ON address_types USING btree (org_id);


--
-- Name: approval_checklists_approval_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_approval_id ON approval_checklists USING btree (approval_id);


--
-- Name: approval_checklists_checklist_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_checklist_id ON approval_checklists USING btree (checklist_id);


--
-- Name: approval_checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_org_id ON approval_checklists USING btree (org_id);


--
-- Name: approvals_app_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_app_entity_id ON approvals USING btree (app_entity_id);


--
-- Name: approvals_approve_status; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_approve_status ON approvals USING btree (approve_status);


--
-- Name: approvals_forward_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_forward_id ON approvals USING btree (forward_id);


--
-- Name: approvals_org_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_entity_id ON approvals USING btree (org_entity_id);


--
-- Name: approvals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_id ON approvals USING btree (org_id);


--
-- Name: approvals_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_table_id ON approvals USING btree (table_id);


--
-- Name: approvals_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_workflow_phase_id ON approvals USING btree (workflow_phase_id);


--
-- Name: bank_accounts_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_account_id ON bank_accounts USING btree (account_id);


--
-- Name: bank_accounts_bank_branch_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_bank_branch_id ON bank_accounts USING btree (bank_branch_id);


--
-- Name: bank_accounts_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_currency_id ON bank_accounts USING btree (currency_id);


--
-- Name: bank_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_org_id ON bank_accounts USING btree (org_id);


--
-- Name: bank_branch_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_branch_org_id ON bank_branch USING btree (org_id);


--
-- Name: banks_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX banks_org_id ON banks USING btree (org_id);


--
-- Name: branch_bankid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX branch_bankid ON bank_branch USING btree (bank_id);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: currency_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_org_id ON currency USING btree (org_id);


--
-- Name: currency_rates_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_currency_id ON currency_rates USING btree (currency_id);


--
-- Name: currency_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_org_id ON currency_rates USING btree (org_id);


--
-- Name: default_accounts_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_account_id ON default_accounts USING btree (account_id);


--
-- Name: default_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_org_id ON default_accounts USING btree (org_id);


--
-- Name: default_accounts_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_use_key_id ON default_accounts USING btree (use_key_id);


--
-- Name: default_tax_types_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_entity_id ON default_tax_types USING btree (entity_id);


--
-- Name: default_tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_org_id ON default_tax_types USING btree (org_id);


--
-- Name: default_tax_types_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_tax_type_id ON default_tax_types USING btree (tax_type_id);


--
-- Name: departments_ln_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX departments_ln_department_id ON departments USING btree (ln_department_id);


--
-- Name: departments_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX departments_org_id ON departments USING btree (org_id);


--
-- Name: entity_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_fields_org_id ON entity_fields USING btree (org_id);


--
-- Name: entity_subscriptions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_id ON entity_subscriptions USING btree (entity_id);


--
-- Name: entity_subscriptions_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_type_id ON entity_subscriptions USING btree (entity_type_id);


--
-- Name: entity_subscriptions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_org_id ON entity_subscriptions USING btree (org_id);


--
-- Name: entity_subscriptions_subscription_level_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_subscription_level_id ON entity_subscriptions USING btree (subscription_level_id);


--
-- Name: entity_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_org_id ON entity_types USING btree (org_id);


--
-- Name: entity_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_use_key_id ON entity_types USING btree (use_key_id);


--
-- Name: entity_values_entity_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_field_id ON entity_values USING btree (entity_field_id);


--
-- Name: entity_values_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_id ON entity_values USING btree (entity_id);


--
-- Name: entity_values_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_org_id ON entity_values USING btree (org_id);


--
-- Name: entitys_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_account_id ON entitys USING btree (account_id);


--
-- Name: entitys_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_entity_type_id ON entitys USING btree (entity_type_id);


--
-- Name: entitys_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_org_id ON entitys USING btree (org_id);


--
-- Name: entitys_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_use_key_id ON entitys USING btree (use_key_id);


--
-- Name: entitys_user_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_user_name ON entitys USING btree (user_name);


--
-- Name: entry_forms_entered_by_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entered_by_id ON entry_forms USING btree (entered_by_id);


--
-- Name: entry_forms_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entity_id ON entry_forms USING btree (entity_id);


--
-- Name: entry_forms_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_form_id ON entry_forms USING btree (form_id);


--
-- Name: entry_forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_org_id ON entry_forms USING btree (org_id);


--
-- Name: fields_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_form_id ON fields USING btree (form_id);


--
-- Name: fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_org_id ON fields USING btree (org_id);


--
-- Name: fiscal_years_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fiscal_years_org_id ON fiscal_years USING btree (org_id);


--
-- Name: forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX forms_org_id ON forms USING btree (org_id);


--
-- Name: gls_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_account_id ON gls USING btree (account_id);


--
-- Name: gls_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_journal_id ON gls USING btree (journal_id);


--
-- Name: gls_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_org_id ON gls USING btree (org_id);


--
-- Name: helpdesk_client_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_client_id ON helpdesk USING btree (client_id);


--
-- Name: helpdesk_closed_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_closed_by ON helpdesk USING btree (closed_by);


--
-- Name: helpdesk_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_org_id ON helpdesk USING btree (org_id);


--
-- Name: helpdesk_pdefinition_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_pdefinition_id ON helpdesk USING btree (pdefinition_id);


--
-- Name: helpdesk_plevel_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_plevel_id ON helpdesk USING btree (plevel_id);


--
-- Name: helpdesk_property_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_property_id ON helpdesk USING btree (property_id);


--
-- Name: helpdesk_recorded_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_recorded_by ON helpdesk USING btree (recorded_by);


--
-- Name: holidays_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX holidays_org_id ON holidays USING btree (org_id);


--
-- Name: industry_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX industry_org_id ON industry USING btree (org_id);


--
-- Name: item_category_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX item_category_org_id ON item_category USING btree (org_id);


--
-- Name: item_units_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX item_units_org_id ON item_units USING btree (org_id);


--
-- Name: items_item_category_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_item_category_id ON items USING btree (item_category_id);


--
-- Name: items_item_unit_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_item_unit_id ON items USING btree (item_unit_id);


--
-- Name: items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_org_id ON items USING btree (org_id);


--
-- Name: items_purchase_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_purchase_account_id ON items USING btree (purchase_account_id);


--
-- Name: items_sales_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_sales_account_id ON items USING btree (sales_account_id);


--
-- Name: items_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_tax_type_id ON items USING btree (tax_type_id);


--
-- Name: journals_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_currency_id ON journals USING btree (currency_id);


--
-- Name: journals_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_department_id ON journals USING btree (department_id);


--
-- Name: journals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_org_id ON journals USING btree (org_id);


--
-- Name: journals_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_period_id ON journals USING btree (period_id);


--
-- Name: ledger_links_ledger_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_links_ledger_type_id ON ledger_links USING btree (ledger_type_id);


--
-- Name: ledger_links_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_links_org_id ON ledger_links USING btree (org_id);


--
-- Name: ledger_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_account_id ON ledger_types USING btree (account_id);


--
-- Name: ledger_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_org_id ON ledger_types USING btree (org_id);


--
-- Name: ledger_types_tax_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_tax_account_id ON ledger_types USING btree (tax_account_id);


--
-- Name: log_period_rentals_period_rental_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX log_period_rentals_period_rental_id ON log_period_rentals USING btree (period_rental_id);


--
-- Name: log_period_rentals_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX log_period_rentals_sys_audit_trail_id ON log_period_rentals USING btree (sys_audit_trail_id);


--
-- Name: orgs_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_currency_id ON orgs USING btree (currency_id);


--
-- Name: orgs_default_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_default_country_id ON orgs USING btree (default_country_id);


--
-- Name: orgs_parent_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_parent_org_id ON orgs USING btree (parent_org_id);


--
-- Name: payment_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payment_types_account_id ON payment_types USING btree (account_id);


--
-- Name: payment_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payment_types_org_id ON payment_types USING btree (org_id);


--
-- Name: payment_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payment_types_use_key_id ON payment_types USING btree (use_key_id);


--
-- Name: payments_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_currency_id ON payments USING btree (currency_id);


--
-- Name: payments_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_entity_id ON payments USING btree (entity_id);


--
-- Name: payments_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_journal_id ON payments USING btree (journal_id);


--
-- Name: payments_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_org_id ON payments USING btree (org_id);


--
-- Name: payments_payment_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_payment_type_id ON payments USING btree (payment_type_id);


--
-- Name: payments_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_period_id ON payments USING btree (period_id);


--
-- Name: payments_property_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_property_id ON payments USING btree (property_id);


--
-- Name: payments_rental_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_rental_id ON payments USING btree (rental_id);


--
-- Name: payments_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX payments_sys_audit_trail_id ON payments USING btree (sys_audit_trail_id);


--
-- Name: pdefinitions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pdefinitions_org_id ON pdefinitions USING btree (org_id);


--
-- Name: pdefinitions_ptype_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pdefinitions_ptype_id ON pdefinitions USING btree (ptype_id);


--
-- Name: period_rentals_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_entity_id ON period_rentals USING btree (entity_id);


--
-- Name: period_rentals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_org_id ON period_rentals USING btree (org_id);


--
-- Name: period_rentals_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_period_id ON period_rentals USING btree (period_id);


--
-- Name: period_rentals_property_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_property_id ON period_rentals USING btree (property_id);


--
-- Name: period_rentals_rental_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_rental_id ON period_rentals USING btree (rental_id);


--
-- Name: period_rentals_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_rentals_sys_audit_trail_id ON period_rentals USING btree (sys_audit_trail_id);


--
-- Name: period_tax_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_rates_org_id ON period_tax_rates USING btree (org_id);


--
-- Name: period_tax_rates_period_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_rates_period_tax_type_id ON period_tax_rates USING btree (period_tax_type_id);


--
-- Name: period_tax_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_account_id ON period_tax_types USING btree (account_id);


--
-- Name: period_tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_org_id ON period_tax_types USING btree (org_id);


--
-- Name: period_tax_types_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_period_id ON period_tax_types USING btree (period_id);


--
-- Name: period_tax_types_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_tax_type_id ON period_tax_types USING btree (tax_type_id);


--
-- Name: periods_fiscal_year_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX periods_fiscal_year_id ON periods USING btree (fiscal_year_id);


--
-- Name: periods_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX periods_org_id ON periods USING btree (org_id);


--
-- Name: plevels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX plevels_org_id ON plevels USING btree (org_id);


--
-- Name: property_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX property_entity_id ON property USING btree (entity_id);


--
-- Name: property_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX property_org_id ON property USING btree (org_id);


--
-- Name: property_property_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX property_property_type_id ON property USING btree (property_type_id);


--
-- Name: property_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX property_types_org_id ON property_types USING btree (org_id);


--
-- Name: ptypes_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ptypes_org_id ON ptypes USING btree (org_id);


--
-- Name: quotations_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_entity_id ON quotations USING btree (entity_id);


--
-- Name: quotations_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_item_id ON quotations USING btree (item_id);


--
-- Name: quotations_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_org_id ON quotations USING btree (org_id);


--
-- Name: rentals_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX rentals_entity_id ON rentals USING btree (entity_id);


--
-- Name: rentals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX rentals_org_id ON rentals USING btree (org_id);


--
-- Name: rentals_property_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX rentals_property_id ON rentals USING btree (property_id);


--
-- Name: reporting_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_entity_id ON reporting USING btree (entity_id);


--
-- Name: reporting_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_org_id ON reporting USING btree (org_id);


--
-- Name: reporting_report_to_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_report_to_id ON reporting USING btree (report_to_id);


--
-- Name: stores_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stores_org_id ON stores USING btree (org_id);


--
-- Name: sub_fields_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_field_id ON sub_fields USING btree (field_id);


--
-- Name: sub_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_org_id ON sub_fields USING btree (org_id);


--
-- Name: subscription_levels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscription_levels_org_id ON subscription_levels USING btree (org_id);


--
-- Name: subscriptions_account_manager_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_account_manager_id ON subscriptions USING btree (account_manager_id);


--
-- Name: subscriptions_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_country_id ON subscriptions USING btree (country_id);


--
-- Name: subscriptions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_entity_id ON subscriptions USING btree (entity_id);


--
-- Name: subscriptions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_org_id ON subscriptions USING btree (org_id);


--
-- Name: sys_countrys_sys_continent_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_countrys_sys_continent_id ON sys_countrys USING btree (sys_continent_id);


--
-- Name: sys_dashboard_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_entity_id ON sys_dashboard USING btree (entity_id);


--
-- Name: sys_dashboard_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_org_id ON sys_dashboard USING btree (org_id);


--
-- Name: sys_emailed_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_org_id ON sys_emailed USING btree (org_id);


--
-- Name: sys_emailed_sys_email_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_sys_email_id ON sys_emailed USING btree (sys_email_id);


--
-- Name: sys_emailed_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_table_id ON sys_emailed USING btree (table_id);


--
-- Name: sys_emails_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emails_org_id ON sys_emails USING btree (org_id);


--
-- Name: sys_files_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_org_id ON sys_files USING btree (org_id);


--
-- Name: sys_files_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_table_id ON sys_files USING btree (table_id);


--
-- Name: sys_logins_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_logins_entity_id ON sys_logins USING btree (entity_id);


--
-- Name: sys_news_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_news_org_id ON sys_news USING btree (org_id);


--
-- Name: sys_queries_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_queries_org_id ON sys_queries USING btree (org_id);


--
-- Name: sys_reset_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_entity_id ON sys_reset USING btree (entity_id);


--
-- Name: sys_reset_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_org_id ON sys_reset USING btree (org_id);


--
-- Name: tax_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_rates_org_id ON tax_rates USING btree (org_id);


--
-- Name: tax_rates_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_rates_tax_type_id ON tax_rates USING btree (tax_type_id);


--
-- Name: tax_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_account_id ON tax_types USING btree (account_id);


--
-- Name: tax_types_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_currency_id ON tax_types USING btree (currency_id);


--
-- Name: tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_org_id ON tax_types USING btree (org_id);


--
-- Name: tax_types_sys_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_sys_country_id ON tax_types USING btree (sys_country_id);


--
-- Name: tax_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_use_key_id ON tax_types USING btree (use_key_id);


--
-- Name: transaction_counters_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_counters_org_id ON transaction_counters USING btree (org_id);


--
-- Name: transaction_counters_transaction_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_counters_transaction_type_id ON transaction_counters USING btree (transaction_type_id);


--
-- Name: transaction_details_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_account_id ON transaction_details USING btree (account_id);


--
-- Name: transaction_details_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_item_id ON transaction_details USING btree (item_id);


--
-- Name: transaction_details_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_org_id ON transaction_details USING btree (org_id);


--
-- Name: transaction_details_transaction_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_transaction_id ON transaction_details USING btree (transaction_id);


--
-- Name: transaction_links_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_org_id ON transaction_links USING btree (org_id);


--
-- Name: transaction_links_transaction_detail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_detail_id ON transaction_links USING btree (transaction_detail_id);


--
-- Name: transaction_links_transaction_detail_to; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_detail_to ON transaction_links USING btree (transaction_detail_to);


--
-- Name: transaction_links_transaction_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_id ON transaction_links USING btree (transaction_id);


--
-- Name: transaction_links_transaction_to; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_to ON transaction_links USING btree (transaction_to);


--
-- Name: transactions_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_bank_account_id ON transactions USING btree (bank_account_id);


--
-- Name: transactions_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_currency_id ON transactions USING btree (currency_id);


--
-- Name: transactions_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_department_id ON transactions USING btree (department_id);


--
-- Name: transactions_entered_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_entered_by ON transactions USING btree (entered_by);


--
-- Name: transactions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_entity_id ON transactions USING btree (entity_id);


--
-- Name: transactions_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_journal_id ON transactions USING btree (journal_id);


--
-- Name: transactions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_org_id ON transactions USING btree (org_id);


--
-- Name: transactions_property_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_property_id ON transactions USING btree (property_id);


--
-- Name: transactions_transaction_status_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_transaction_status_id ON transactions USING btree (transaction_status_id);


--
-- Name: transactions_transaction_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_transaction_type_id ON transactions USING btree (transaction_type_id);


--
-- Name: transactions_workflow_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_workflow_table_id ON transactions USING btree (workflow_table_id);


--
-- Name: workflow_logs_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_logs_org_id ON workflow_logs USING btree (org_id);


--
-- Name: workflow_phases_approval_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_approval_entity_id ON workflow_phases USING btree (approval_entity_id);


--
-- Name: workflow_phases_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_org_id ON workflow_phases USING btree (org_id);


--
-- Name: workflow_phases_workflow_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_workflow_id ON workflow_phases USING btree (workflow_id);


--
-- Name: workflow_sql_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_org_id ON workflow_sql USING btree (org_id);


--
-- Name: workflow_sql_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_workflow_phase_id ON workflow_sql USING btree (workflow_phase_id);


--
-- Name: workflows_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_org_id ON workflows USING btree (org_id);


--
-- Name: workflows_source_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_source_entity_id ON workflows USING btree (source_entity_id);


--
-- Name: af_upd_transaction_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER af_upd_transaction_details AFTER INSERT OR DELETE OR UPDATE ON transaction_details FOR EACH ROW EXECUTE PROCEDURE af_upd_transaction_details();


--
-- Name: aud_period_rentals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aud_period_rentals AFTER DELETE OR UPDATE ON period_rentals FOR EACH ROW EXECUTE PROCEDURE aud_period_rentals();


--
-- Name: ins_address; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_address BEFORE INSERT OR UPDATE ON address FOR EACH ROW EXECUTE PROCEDURE ins_address();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_entitys; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entitys AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_entitys();


--
-- Name: ins_entry_forms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entry_forms BEFORE INSERT ON entry_forms FOR EACH ROW EXECUTE PROCEDURE ins_entry_forms();


--
-- Name: ins_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_fields BEFORE INSERT ON fields FOR EACH ROW EXECUTE PROCEDURE ins_fields();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


--
-- Name: ins_payments; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_payments BEFORE INSERT OR UPDATE ON payments FOR EACH ROW EXECUTE PROCEDURE ins_payments();


--
-- Name: ins_period_rentals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_period_rentals BEFORE INSERT OR UPDATE ON period_rentals FOR EACH ROW EXECUTE PROCEDURE ins_period_rentals();


--
-- Name: ins_periods; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_periods BEFORE INSERT OR UPDATE ON periods FOR EACH ROW EXECUTE PROCEDURE ins_periods();


--
-- Name: ins_property; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_property BEFORE INSERT OR UPDATE ON property FOR EACH ROW EXECUTE PROCEDURE ins_property();


--
-- Name: ins_rentals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_rentals BEFORE INSERT OR UPDATE ON rentals FOR EACH ROW EXECUTE PROCEDURE ins_rentals();


--
-- Name: ins_sub_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sub_fields BEFORE INSERT ON sub_fields FOR EACH ROW EXECUTE PROCEDURE ins_sub_fields();


--
-- Name: ins_subscriptions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_subscriptions BEFORE INSERT OR UPDATE ON subscriptions FOR EACH ROW EXECUTE PROCEDURE ins_subscriptions();


--
-- Name: ins_sys_reset; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sys_reset AFTER INSERT ON sys_reset FOR EACH ROW EXECUTE PROCEDURE ins_sys_reset();


--
-- Name: ins_transactions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_transactions BEFORE INSERT OR UPDATE ON transactions FOR EACH ROW EXECUTE PROCEDURE ins_transactions();


--
-- Name: payment_number; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER payment_number BEFORE INSERT ON payments FOR EACH ROW EXECUTE PROCEDURE payment_number();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON periods FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON transactions FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON subscriptions FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: upd_gls; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_gls BEFORE INSERT OR UPDATE ON gls FOR EACH ROW EXECUTE PROCEDURE upd_gls();


--
-- Name: upd_transaction_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_transaction_details BEFORE INSERT OR UPDATE ON transaction_details FOR EACH ROW EXECUTE PROCEDURE upd_transaction_details();


--
-- Name: account_types_accounts_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_accounts_class_id_fkey FOREIGN KEY (accounts_class_id) REFERENCES accounts_class(accounts_class_id);


--
-- Name: account_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: accounts_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES account_types(account_type_id);


--
-- Name: accounts_class_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts_class
    ADD CONSTRAINT accounts_class_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: address_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES address_types(address_type_id);


--
-- Name: address_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: address_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: address_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approval_checklists_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES approvals(approval_id);


--
-- Name: approval_checklists_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES checklists(checklist_id);


--
-- Name: approval_checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_app_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_app_entity_id_fkey FOREIGN KEY (app_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_entity_id_fkey FOREIGN KEY (org_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: bank_accounts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: bank_accounts_bank_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_bank_branch_id_fkey FOREIGN KEY (bank_branch_id) REFERENCES bank_branch(bank_branch_id);


--
-- Name: bank_accounts_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: bank_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: bank_branch_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES banks(bank_id);


--
-- Name: bank_branch_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: banks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: banks_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: checklists_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: currency_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: currency_rates_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: currency_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_accounts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: default_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_accounts_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: default_tax_types_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: default_tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_tax_types_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: departments_ln_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_ln_department_id_fkey FOREIGN KEY (ln_department_id) REFERENCES departments(department_id);


--
-- Name: departments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_subscriptions_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entity_subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_subscription_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_subscription_level_id_fkey FOREIGN KEY (subscription_level_id) REFERENCES subscription_levels(subscription_level_id);


--
-- Name: entity_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entity_values_entity_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_field_id_fkey FOREIGN KEY (entity_field_id) REFERENCES entity_fields(entity_field_id);


--
-- Name: entity_values_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_values_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: entitys_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entitys_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entry_forms_entered_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entered_by_id_fkey FOREIGN KEY (entered_by_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: entry_forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fields_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fiscal_years_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: gls_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: gls_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: gls_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: helpdesk_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_client_id_fkey FOREIGN KEY (client_id) REFERENCES entitys(entity_id);


--
-- Name: helpdesk_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES entitys(entity_id);


--
-- Name: helpdesk_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: helpdesk_pdefinition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_pdefinition_id_fkey FOREIGN KEY (pdefinition_id) REFERENCES pdefinitions(pdefinition_id);


--
-- Name: helpdesk_plevel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_plevel_id_fkey FOREIGN KEY (plevel_id) REFERENCES plevels(plevel_id);


--
-- Name: helpdesk_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_property_id_fkey FOREIGN KEY (property_id) REFERENCES property(property_id);


--
-- Name: helpdesk_recorded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES entitys(entity_id);


--
-- Name: holidays_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: industry_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY industry
    ADD CONSTRAINT industry_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: item_category_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: item_units_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: items_item_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_item_category_id_fkey FOREIGN KEY (item_category_id) REFERENCES item_category(item_category_id);


--
-- Name: items_item_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_item_unit_id_fkey FOREIGN KEY (item_unit_id) REFERENCES item_units(item_unit_id);


--
-- Name: items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: items_purchase_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_purchase_account_id_fkey FOREIGN KEY (purchase_account_id) REFERENCES accounts(account_id);


--
-- Name: items_sales_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_sales_account_id_fkey FOREIGN KEY (sales_account_id) REFERENCES accounts(account_id);


--
-- Name: items_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: journals_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: journals_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: journals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: journals_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: ledger_links_ledger_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_ledger_type_id_fkey FOREIGN KEY (ledger_type_id) REFERENCES ledger_types(ledger_type_id);


--
-- Name: ledger_links_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ledger_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: ledger_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ledger_types_tax_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_tax_account_id_fkey FOREIGN KEY (tax_account_id) REFERENCES accounts(account_id);


--
-- Name: log_period_rentals_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY log_period_rentals
    ADD CONSTRAINT log_period_rentals_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: orgs_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: orgs_default_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_default_country_id_fkey FOREIGN KEY (default_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: orgs_org_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_client_id_fkey FOREIGN KEY (org_client_id) REFERENCES entitys(entity_id);


--
-- Name: orgs_parent_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_parent_org_id_fkey FOREIGN KEY (parent_org_id) REFERENCES orgs(org_id);


--
-- Name: payment_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: payment_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: payment_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: payments_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: payments_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: payments_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: payments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: payments_payment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_payment_type_id_fkey FOREIGN KEY (payment_type_id) REFERENCES payment_types(payment_type_id);


--
-- Name: payments_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: payments_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_property_id_fkey FOREIGN KEY (property_id) REFERENCES property(property_id);


--
-- Name: payments_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rentals(rental_id);


--
-- Name: payments_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: pdefinitions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pdefinitions_ptype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_ptype_id_fkey FOREIGN KEY (ptype_id) REFERENCES ptypes(ptype_id);


--
-- Name: period_rentals_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: period_rentals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_rentals_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: period_rentals_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_property_id_fkey FOREIGN KEY (property_id) REFERENCES property(property_id);


--
-- Name: period_rentals_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES rentals(rental_id);


--
-- Name: period_rentals_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_rentals
    ADD CONSTRAINT period_rentals_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: period_tax_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_tax_rates_period_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_period_tax_type_id_fkey FOREIGN KEY (period_tax_type_id) REFERENCES period_tax_types(period_tax_type_id);


--
-- Name: period_tax_rates_tax_rate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_tax_rate_id_fkey FOREIGN KEY (tax_rate_id) REFERENCES tax_rates(tax_rate_id);


--
-- Name: period_tax_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: period_tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_tax_types_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: period_tax_types_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: periods_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: periods_fiscal_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_fiscal_year_id_fkey FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(fiscal_year_id);


--
-- Name: periods_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: plevels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: property_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property
    ADD CONSTRAINT property_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: property_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property
    ADD CONSTRAINT property_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: property_property_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property
    ADD CONSTRAINT property_property_type_id_fkey FOREIGN KEY (property_type_id) REFERENCES property_types(property_type_id);


--
-- Name: property_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY property_types
    ADD CONSTRAINT property_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ptypes_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ptypes
    ADD CONSTRAINT ptypes_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: quotations_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: quotations_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: quotations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: rentals_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rentals
    ADD CONSTRAINT rentals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: rentals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rentals
    ADD CONSTRAINT rentals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: rentals_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY rentals
    ADD CONSTRAINT rentals_property_id_fkey FOREIGN KEY (property_id) REFERENCES property(property_id);


--
-- Name: reporting_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: reporting_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: reporting_report_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_report_to_id_fkey FOREIGN KEY (report_to_id) REFERENCES entitys(entity_id);


--
-- Name: stores_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sub_fields_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_field_id_fkey FOREIGN KEY (field_id) REFERENCES fields(field_id);


--
-- Name: sub_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscription_levels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscriptions_account_manager_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_account_manager_id_fkey FOREIGN KEY (account_manager_id) REFERENCES entitys(entity_id);


--
-- Name: subscriptions_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_country_id_fkey FOREIGN KEY (country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_audit_details_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: sys_countrys_sys_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_continent_id_fkey FOREIGN KEY (sys_continent_id) REFERENCES sys_continents(sys_continent_id);


--
-- Name: sys_dashboard_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_dashboard_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_sys_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_sys_email_id_fkey FOREIGN KEY (sys_email_id) REFERENCES sys_emails(sys_email_id);


--
-- Name: sys_emails_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_logins_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_news_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_queries_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_reset_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_reset_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_rates_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: tax_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: tax_types_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_types_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: tax_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: transaction_counters_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_counters_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(transaction_type_id);


--
-- Name: transaction_details_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: transaction_details_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: transaction_details_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_details_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(store_id);


--
-- Name: transaction_details_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id);


--
-- Name: transaction_links_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_links_transaction_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_detail_id_fkey FOREIGN KEY (transaction_detail_id) REFERENCES transaction_details(transaction_detail_id);


--
-- Name: transaction_links_transaction_detail_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_detail_to_fkey FOREIGN KEY (transaction_detail_to) REFERENCES transaction_details(transaction_detail_id);


--
-- Name: transaction_links_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id);


--
-- Name: transaction_links_transaction_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_to_fkey FOREIGN KEY (transaction_to) REFERENCES transactions(transaction_id);


--
-- Name: transactions_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: transactions_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: transactions_entered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES entitys(entity_id);


--
-- Name: transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: transactions_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: transactions_ledger_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_ledger_type_id_fkey FOREIGN KEY (ledger_type_id) REFERENCES ledger_types(ledger_type_id);


--
-- Name: transactions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transactions_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_property_id_fkey FOREIGN KEY (property_id) REFERENCES property(property_id);


--
-- Name: transactions_transaction_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_transaction_status_id_fkey FOREIGN KEY (transaction_status_id) REFERENCES transaction_status(transaction_status_id);


--
-- Name: transactions_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(transaction_type_id);


--
-- Name: workflow_logs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_approval_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_approval_entity_id_fkey FOREIGN KEY (approval_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: workflow_phases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id);


--
-- Name: workflow_sql_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_sql_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflows_source_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_source_entity_id_fkey FOREIGN KEY (source_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

