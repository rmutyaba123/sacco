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
-- Name: add_member_meeting(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_member_meeting(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg		 				varchar(120);
	v_member_id				integer;
	v_org_id				integer;
BEGIN

	SELECT member_id INTO v_member_id
	FROM member_meeting WHERE (member_id = $1::int) AND (meeting_id = $3::int);
	
	IF(v_member_id is null)THEN
		SELECT org_id INTO v_org_id
		FROM meetings WHERE (meeting_id = $3::int);
		
		INSERT INTO  member_meeting (meeting_id, member_id, org_id)
		VALUES ($3::int, $1::int, v_org_id);

		msg := 'Added to meeting';
	ELSE
		msg := 'Already Added to meeting';
	END IF;
	
	return msg;
END;
$_$;


ALTER FUNCTION public.add_member_meeting(character varying, character varying, character varying) OWNER TO postgres;

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
	tamount REAL;
BEGIN

	IF(TG_OP = 'DELETE')THEN
		SELECT SUM(quantity * (amount + tax_amount)) INTO tamount
		FROM transaction_details WHERE (transaction_id = OLD.transaction_id);
		UPDATE transactions SET transaction_amount = tamount WHERE (transaction_id = OLD.transaction_id);	
	ELSE
		SELECT SUM(quantity * (amount + tax_amount)) INTO tamount
		FROM transaction_details WHERE (transaction_id = NEW.transaction_id);
		UPDATE transactions SET transaction_amount = tamount WHERE (transaction_id = NEW.transaction_id);	
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.af_upd_transaction_details() OWNER TO postgres;

--
-- Name: borrowing_aplication(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION borrowing_aplication(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 				varchar(120);
BEGIN
	msg := 'borrowing applied';
	
	UPDATE borrowing SET approve_status = 'Completed'
	WHERE (borrowing_id = CAST($1 as int)) AND (approve_status = 'Draft');

	return msg;
END;
$_$;


ALTER FUNCTION public.borrowing_aplication(character varying, character varying, character varying) OWNER TO postgres;

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
	SELECT transaction_id, transaction_type_id, transaction_status_id INTO rec
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	IF($3 = '2') THEN
		UPDATE transactions SET transaction_status_id = 4 
		WHERE transaction_id = rec.transaction_id;
		msg := 'Transaction Archived';
	ELSIF(rec.transaction_status_id = 1) THEN
		IF($3 = '1') THEN
			UPDATE transactions SET transaction_status_id = 2, approve_status = 'Completed'
			WHERE transaction_id = rec.transaction_id;
		END IF;
		msg := 'Transaction completed.';
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
-- Name: cpy_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION cpy_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
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

	SELECT max(tx_ledger_date)::timestamp INTO last_date
	FROM tx_ledger
	WHERE (to_char(tx_ledger_date, 'YYYY.MM') = $1);
	v_start := EXTRACT(YEAR FROM last_date) * 12 + EXTRACT(MONTH FROM last_date);
	
	SELECT max(tx_ledger_date)::timestamp INTO v_ledger_date
	FROM tx_ledger;
	v_end := EXTRACT(YEAR FROM v_ledger_date) * 12 + EXTRACT(MONTH FROM v_ledger_date) + 1;
	v_inteval :=  ((v_end - v_start) || ' months')::interval;

	IF ($3 = '1') THEN
		INSERT INTO tx_ledger(ledger_type_id, entity_id, bpartner_id, bank_account_id, 
				currency_id, journal_id, org_id, exchange_rate, tx_type, tx_ledger_date, 
				tx_ledger_quantity, tx_ledger_amount, tx_ledger_tax_amount, reference_number, 
				narrative)
		SELECT ledger_type_id, entity_id, bpartner_id, bank_account_id, 
			currency_id, journal_id, org_id, exchange_rate, tx_type, (tx_ledger_date + v_inteval), 
			tx_ledger_quantity, tx_ledger_amount, tx_ledger_tax_amount, reference_number,
			narrative
		FROM tx_ledger
		WHERE (tx_type = -1) AND (to_char(tx_ledger_date, 'YYYY.MM') = $1);

		msg := 'Appended a new month';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.cpy_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: email_after(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION email_after(integer, integer, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg		 				varchar(120);
BEGIN
	INSERT INTO sys_emailed ( table_id, org_id, table_name, email_type)
	VALUES ($1, $2, 'meetings', 8);
msg := 'Email Sent';
return msg;
END;
$_$;


ALTER FUNCTION public.email_after(integer, integer, character varying) OWNER TO postgres;

--
-- Name: email_before(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION email_before(integer, integer, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg		 				varchar(120);
BEGIN
	INSERT INTO sys_emailed ( table_id, org_id, table_name, email_type)
	VALUES ($1, $2, 'meetings', 7);
msg := 'Email Sent';
return msg;
END;
$_$;


ALTER FUNCTION public.email_before(integer, integer, character varying) OWNER TO postgres;

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
-- Name: generate_contribs(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION generate_contribs(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec						RECORD;
	recu			RECORD;
	v_period_id		integer;
	vi_period_id		integer;
	reca			RECORD;
	v_org_id		integer;
	v_month_name	varchar(50);
	v_member_id		integer;

	msg 			varchar(120);
BEGIN
	SELECT period_id, org_id, to_char(start_date, 'Month YYYY') INTO v_period_id, v_org_id, v_month_name
	FROM periods
	WHERE (period_id = $1::integer);

	SELECT period_id INTO vi_period_id FROM contributions WHERE period_id in (v_period_id) AND org_id in (v_org_id);

	IF( vi_period_id is null) THEN

	FOR reca IN SELECT member_id, entity_id FROM members WHERE (org_id = v_org_id) LOOP
	
	FOR rec IN SELECT org_id, frequency, contribution_type_id, investment_amount, merry_go_round_amount, applies_to_all
	FROM contribution_types WHERE  (org_id = v_org_id) LOOP
	IF(rec.applies_to_all = true) THEN
		IF (rec.frequency = 'Weekly') THEN
		FOR i in 1..4 LOOP
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount, member_id, entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END LOOP;
		END IF;
		IF (rec.frequency = 'Fortnightly') THEN
		FOR i in 1..2 LOOP
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id, entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END LOOP;
		END IF;
		IF (rec.frequency = 'Monthly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Irregularly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Quarterly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Semi-annually') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Annually') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		END IF;
	IF(rec.applies_to_all = false)THEN
	SELECT contribution_type_id, entity_id INTO recu FROM contribution_defaults WHERE entity_id = reca.entity_id
	AND contribution_type_id = rec.contribution_type_id;
		IF (rec.frequency = 'Weekly') THEN
		FOR i in 1..4 LOOP
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount, member_id, entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, recu.entity_id);
		END LOOP;
		END IF;
		IF (rec.frequency = 'Fortnightly') THEN
		FOR i in 1..2 LOOP
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id, entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, recu.entity_id);
		END LOOP;
		END IF;
		IF (rec.frequency = 'Monthly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, recu.entity_id);
		END IF;
		IF (rec.frequency = 'Irregularly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Quarterly') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Semi-annually') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
		IF (rec.frequency = 'Annually') THEN
			INSERT INTO contributions (period_id, org_id, contribution_type_id, investment_amount, merry_go_round_amount,member_id,entity_id)
			VALUES(v_period_id, rec.org_id, rec.contribution_type_id, rec.investment_amount, rec.merry_go_round_amount,
			reca.member_id, reca.entity_id);
		END IF;
	END IF;
	
	END LOOP;
	
	END LOOP;
	msg := 'Contributions Generated';
	ELSE
	msg := 'Contributions already exist';
	END IF;
	

RETURN msg;	
END;
$_$;


ALTER FUNCTION public.generate_contribs(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: generate_paid(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION generate_paid(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg		 				varchar(120);
	v_paid				boolean;	
BEGIN
	SELECT paid INTO v_paid FROM contributions WHERE contribution_id = $1::int;
	--RAISE EXCEPTION '%', v_paid;
	IF(v_paid = false) THEN
	UPDATE contributions SET paid = true WHERE contribution_id = $1::int ;
	msg = 'Paid';
	ELSE
	msg = 'Already paid';
	
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.generate_paid(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: generate_repayment(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION generate_repayment(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec            RECORD;
    recu            RECORD;
    reca            RECORD;
    v_penalty        real;
    v_org_id        integer;
    v_period_id        integer;
    v_month_name        varchar(20);
    vi_period_id        integer;
    v_loan_type_id        integer;
    v_loan_intrest        real;
    v_loan_id        integer;
    msg            varchar(120);
BEGIN
SELECT   period_id, org_id, to_char(start_date, 'Month YYYY') INTO v_period_id, v_org_id, v_month_name
    FROM periods
    WHERE (period_id = $1::integer);
SELECT loan_month_id, loan_id, period_id, org_id, interest_amount, repayment, interest_paid, penalty_paid INTO recu
FROM loan_monthly WHERE period_id in (v_period_id) AND org_id in (v_org_id);

    IF( recu.period_id is null) THEN
    
        FOR rec IN SELECT org_id, loan_id, loan_type_id, monthly_repayment FROM loans WHERE (org_id = v_org_id) LOOP
        raise exception '%',rec.loan_id;    
        SELECT loan_intrest, loan_id INTO v_loan_intrest, v_loan_id FROM vw_loan_payments WHERE v_loan_id = rec.loan_id;
        recu.repayment = rec.monthly_repayment - v_loan_intrest;
            
    
        INSERT INTO loan_monthly (loan_id, period_id, org_id, interest_amount, repayment, interest_paid)
        VALUES(rec.loan_id, v_period_id, rec.org_id, v_loan_intrest, recu.repayment,  v_loan_intrest);
    END LOOP;
    

msg := 'Repayment Generated';
    END IF;

    return msg;
END;
$_$;


ALTER FUNCTION public.generate_repayment(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: get_approval_date(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_approval_date(integer) RETURNS date
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_workflow_table_id		integer;
	v_date					date;
BEGIN
	v_workflow_table_id := $1;

	SELECT action_date INTO v_date
	FROM approvals 
	WHERE (approvals.table_id = v_workflow_table_id) AND (approvals.workflow_phase_id = 6);

	return v_date;
END;
$_$;


ALTER FUNCTION public.get_approval_date(integer) OWNER TO postgres;

--
-- Name: get_approver(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_approver(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_workflow_table_id		integer;
	v_approver				varchar(120);
BEGIN
	v_approver :='';
	v_workflow_table_id := $1;

	SELECT entitys.entity_name INTO v_approver
	FROM entitys 
	INNER JOIN approvals ON entitys.entity_id = approvals.app_entity_id
	WHERE (approvals.table_id = v_workflow_table_id) AND (approvals.workflow_phase_id = 6);

	return v_approver;
END;
$_$;


ALTER FUNCTION public.get_approver(integer) OWNER TO postgres;

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
-- Name: get_borrowing_period(real, real, integer, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_borrowing_period(real, real, integer, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	borrowing_balance real;
	ri real;
BEGIN
	ri := 1 + ($2/1200);
	IF (ri = 1) THEN
		borrowing_balance := $1;
	ELSE
		borrowing_balance := $1 * (ri ^ $3) - ($4 * ((ri ^ $3)  - 1) / (ri - 1));
	END IF;
	RETURN borrowing_balance;
END;
$_$;


ALTER FUNCTION public.get_borrowing_period(real, real, integer, real) OWNER TO postgres;

--
-- Name: get_borrowing_repayment(real, real, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_borrowing_repayment(real, real, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	repayment real;
	ri real;
BEGIN
	ri := 1 + ($2/1200);
	IF ((ri ^ $3) = 1) THEN
		repayment := $1;
	ELSE
		repayment := $1 * (ri ^ $3) * (ri - 1) / ((ri ^ $3) - 1);
	END IF;
	RETURN repayment;
END;
$_$;


ALTER FUNCTION public.get_borrowing_repayment(real, real, integer) OWNER TO postgres;

--
-- Name: get_borrowing_repayment(real, real, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_borrowing_repayment(real, real, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
    repayment real;
    ri real;
BEGIN
    ri := 1 + ($2/1200);
    IF ((ri ^ $3) = 1) THEN
        repayment := $1;
    ELSE
        repayment := $1 * (ri ^ $3) * (ri - 1) / ((ri ^ $3) - 1);
    END IF;
    RETURN repayment;
END;
$_$;


ALTER FUNCTION public.get_borrowing_repayment(real, real, real) OWNER TO postgres;

--
-- Name: get_bpayment_period(real, real, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_bpayment_period(real, real, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	paymentperiod real;
	q real;
BEGIN
	q := $3/1200;
	
	IF ($2 = 0) OR (q = -1) OR ((q * $1) >= $2) THEN
		paymentperiod := 1;
	ELSIF (log(q + 1) = 0) THEN
		paymentperiod := 1;
	ELSE
		paymentperiod := (log($2) - log($2 - (q * $1))) / log(q + 1);
	END IF;

	RETURN paymentperiod;
END;
$_$;


ALTER FUNCTION public.get_bpayment_period(real, real, real) OWNER TO postgres;

--
-- Name: get_bpenalty(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_bpenalty(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(penalty_paid) is null THEN 0 ELSE sum(penalty_paid) END
	FROM borrowing_repayment INNER JOIN periods ON borrowing_repayment.period_id = periods.period_id
	WHERE (borrowing_repayment.borrowing_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_bpenalty(integer, date) OWNER TO postgres;

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
-- Name: get_interest_amount(real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_interest_amount(real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ri real;
BEGIN
	ri := 1 + ($1/1200);
RETURN ri;
END;
$_$;


ALTER FUNCTION public.get_interest_amount(real) OWNER TO postgres;

--
-- Name: get_interest_amount(real, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_interest_amount(real, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ri real;
BEGIN
	ri :=($1 * $2)/1200;
RETURN ri;
END;
$_$;


ALTER FUNCTION public.get_interest_amount(real, integer) OWNER TO postgres;

--
-- Name: get_interest_amount(real, real, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_interest_amount(real, real, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ri real;
BEGIN
	ri :=(($1* $2 * $3)/1200);
RETURN ri;
END;
$_$;


ALTER FUNCTION public.get_interest_amount(real, real, integer) OWNER TO postgres;

--
-- Name: get_interest_amount(real, real, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_interest_amount(real, real, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ri real;
BEGIN
	ri :=(($1* $2 * $3)/1200);
RETURN ri;
END;
$_$;


ALTER FUNCTION public.get_interest_amount(real, real, real) OWNER TO postgres;

--
-- Name: get_interest_brepayment(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_interest_brepayment(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_paid) is null THEN 0 ELSE sum(interest_paid) END
	FROM borrowing_repayment INNER JOIN periods ON borrowing_repayment.period_id = periods.period_id
	WHERE (borrowing_repayment.borrowing_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_interest_brepayment(integer, date) OWNER TO postgres;

--
-- Name: get_intrest_repayment(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_intrest_repayment(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_paid) is null THEN 0 ELSE sum(interest_paid) END
	FROM loan_monthly INNER JOIN periods ON loan_monthly.period_id = periods.period_id
	WHERE (loan_monthly.loan_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_intrest_repayment(integer, date) OWNER TO postgres;

--
-- Name: get_loan_period(real, real, integer, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_loan_period(real, real, integer, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	loanbalance real;
	ri real;
BEGIN
	ri := 1 + ($2/1200);
	IF (ri = 1) THEN
		loanbalance := $1;
	ELSE
		loanbalance := $1 * (ri ^ $3) - ($4 * ((ri ^ $3)  - 1) / (ri - 1));
	END IF;
	RETURN loanbalance;
END;
$_$;


ALTER FUNCTION public.get_loan_period(real, real, integer, real) OWNER TO postgres;

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
-- Name: get_payment_period(real, real, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_payment_period(real, real, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	paymentperiod real;
	q real;
BEGIN
	q := $3/1200;
	
	IF ($2 = 0) OR (q = -1) OR ((q * $1) >= $2) THEN
		paymentperiod := 1;
	ELSIF (log(q + 1) = 0) THEN
		paymentperiod := 1;
	ELSE
		paymentperiod := (log($2) - log($2 - (q * $1))) / log(q + 1);
	END IF;

	RETURN paymentperiod;
END;
$_$;


ALTER FUNCTION public.get_payment_period(real, real, real) OWNER TO postgres;

--
-- Name: get_penalty(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_penalty(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(penalty_paid) is null THEN 0 ELSE sum(penalty_paid) END
	FROM loan_monthly INNER JOIN periods ON loan_monthly.period_id = periods.period_id
	WHERE (loan_monthly.loan_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_penalty(integer, date) OWNER TO postgres;

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
-- Name: get_repayment(real, real, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_repayment(real, real, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	repayment real;
	ri real;
BEGIN
	ri := 1 + ($2/1200);
	IF ((ri ^ $3) = 1) THEN
		repayment := $1;
	ELSE
		repayment := $1 * (ri ^ $3) * (ri - 1) / ((ri ^ $3) - 1);
	END IF;
	RETURN repayment;
END;
$_$;


ALTER FUNCTION public.get_repayment(real, real, integer) OWNER TO postgres;

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
-- Name: get_total_binterest(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_binterest(integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_amount) is null THEN 0 ELSE sum(interest_amount) END 
	FROM borrowing_repayment
	WHERE (borrowing_id = $1);
$_$;


ALTER FUNCTION public.get_total_binterest(integer) OWNER TO postgres;

--
-- Name: get_total_binterest(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_binterest(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_amount) is null THEN 0 ELSE sum(interest_amount) END 
	FROM borrowing_repayment INNER JOIN periods ON borrowing_repayment.period_id = periods.period_id
	WHERE (borrowing_repayment.borrowing_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_total_binterest(integer, date) OWNER TO postgres;

--
-- Name: get_total_brepayment(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_brepayment(integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(repayment + interest_paid + penalty_paid) is null THEN 0 
		ELSE sum(repayment + interest_paid + penalty_paid) END
	FROM borrowing_repayment
	WHERE (borrowing_id = $1);
$_$;


ALTER FUNCTION public.get_total_brepayment(integer) OWNER TO postgres;

--
-- Name: get_total_brepayment(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_brepayment(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(repayment + interest_paid + penalty_paid) is null THEN 0 
		ELSE sum(repayment + interest_paid + penalty_paid) END
	FROM borrowing_repayment INNER JOIN periods ON borrowing_repayment.period_id = periods.period_id
	WHERE (borrowing_repayment.borrowing_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_total_brepayment(integer, date) OWNER TO postgres;

--
-- Name: get_total_brepayment(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_brepayment(integer, integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(monthly_repayment + borrowing_interest)
	FROM vw_borrowing_payments
	WHERE (borrowing_id = $1) and (months <= $2);
$_$;


ALTER FUNCTION public.get_total_brepayment(integer, integer) OWNER TO postgres;

--
-- Name: get_total_expenditure(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_expenditure(integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_transaction_amount real;

BEGIN
	SELECT SUM(transaction_amount) INTO v_transaction_amount FROM transactions WHERE tx_type = -1 and investment_id  = $1;
	RETURN v_transaction_amount;

END;
$_$;


ALTER FUNCTION public.get_total_expenditure(integer) OWNER TO postgres;

--
-- Name: get_total_income(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_income(integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_transaction_amount real;

BEGIN
	SELECT SUM(transaction_amount) INTO v_transaction_amount FROM transactions WHERE tx_type = 1 and investment_id  = $1;
	RETURN v_transaction_amount;

END;
$_$;


ALTER FUNCTION public.get_total_income(integer) OWNER TO postgres;

--
-- Name: get_total_interest(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_interest(integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_amount) is null THEN 0 ELSE sum(interest_amount) END 
	FROM loan_monthly
	WHERE (loan_id = $1);
$_$;


ALTER FUNCTION public.get_total_interest(integer) OWNER TO postgres;

--
-- Name: get_total_interest(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_interest(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(interest_amount) is null THEN 0 ELSE sum(interest_amount) END 
	FROM loan_monthly INNER JOIN periods ON loan_monthly.period_id = periods.period_id
	WHERE (loan_monthly.loan_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_total_interest(integer, date) OWNER TO postgres;

--
-- Name: get_total_repayment(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_repayment(integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(repayment + interest_paid + penalty_paid) is null THEN 0 
		ELSE sum(repayment + interest_paid + penalty_paid) END
	FROM loan_monthly
	WHERE (loan_id = $1);
$_$;


ALTER FUNCTION public.get_total_repayment(integer) OWNER TO postgres;

--
-- Name: get_total_repayment(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_repayment(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN sum(repayment + interest_paid + penalty_paid) is null THEN 0 
		ELSE sum(repayment + interest_paid + penalty_paid) END
	FROM loan_monthly INNER JOIN periods ON loan_monthly.period_id = periods.period_id
	WHERE (loan_monthly.loan_id = $1) AND (periods.start_date < $2);
$_$;


ALTER FUNCTION public.get_total_repayment(integer, date) OWNER TO postgres;

--
-- Name: get_total_repayment(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_repayment(integer, integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(monthly_repayment + loan_intrest)
	FROM vw_loan_payments 
	WHERE (loan_id = $1) and (months <= $2);
$_$;


ALTER FUNCTION public.get_total_repayment(integer, integer) OWNER TO postgres;

--
-- Name: get_total_repayment(real, real, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_repayment(real, real, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	repayment real;
	ri real;
BEGIN
	ri := (($1* $2 * $3)/1200);
	repayment := $1 + (($1* $2 * $3)/1200);
	RETURN repayment;
END;
$_$;


ALTER FUNCTION public.get_total_repayment(real, real, integer) OWNER TO postgres;

--
-- Name: get_total_repayment(real, real, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_total_repayment(real, real, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	repayment real;
	ri real;
BEGIN
	ri := (($1* $2 * $3)/1200);
	repayment := $1 + (($1* $2 * $3)/1200);
	RETURN repayment;
END;
$_$;


ALTER FUNCTION public.get_total_repayment(real, real, real) OWNER TO postgres;

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
-- Name: ins_applicants(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_applicants() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec 			RECORD;
	v_entity_id		integer;
BEGIN
	IF (TG_OP = 'INSERT') THEN
		
		IF(NEW.entity_id IS NULL) THEN
			SELECT entity_id INTO v_entity_id
			FROM entitys
			WHERE (trim(lower(user_name)) = trim(lower(NEW.applicant_email)));
				
			IF(v_entity_id is null)THEN
				SELECT org_id INTO rec
				FROM orgs WHERE (is_default = true);

				NEW.entity_id := nextval('entitys_entity_id_seq');

				INSERT INTO entitys (entity_id, org_id, entity_type_id, entity_name, User_name, 
					primary_email, primary_telephone, function_role)
				VALUES (NEW.entity_id, rec.org_id, 4, 
					(NEW.Surname || ' ' || NEW.First_name || ' ' || COALESCE(NEW.Middle_name, '')),
					lower(NEW.applicant_email), lower(NEW.applicant_email), NEW.applicant_phone, 'applicant');
			ELSE
				RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
			END IF;
		END IF;

		INSERT INTO sys_emailed (sys_email_id, table_id, table_name)
		VALUES (1, NEW.entity_id, 'applicant');
	ELSIF (TG_OP = 'UPDATE') THEN
		UPDATE entitys  SET entity_name = (NEW.Surname || ' ' || NEW.First_name || ' ' || COALESCE(NEW.Middle_name, ''))
		WHERE entity_id = NEW.entity_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_applicants() OWNER TO postgres;

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
-- Name: ins_borrowing(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_borrowing() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_default_interest	real;
	v_reducing_balance	boolean;
BEGIN

	SELECT default_interest, reducing_balance INTO v_default_interest, v_reducing_balance
	FROM borrowing_types 
	WHERE (borrowing_type_id = NEW.borrowing_type_id);
		
	IF(NEW.interest is null)THEN
		NEW.interest := v_default_interest;
	END IF;
	IF (NEW.reducing_balance is null)THEN
		NEW.reducing_balance := v_reducing_balance;
	END IF;
	IF(NEW.monthly_repayment is null) THEN
		NEW.monthly_repayment := 0;
	END IF;
	IF (NEW.repayment_period is null)THEN
		NEW.repayment_period := 0;
	END IF;
	IF(NEW.approve_status = 'Draft')THEN
		NEW.repayment_period := 0;
	END IF;
	SELECT CAST (repayment_period AS FLOAT);
	IF(NEW.principle is null)THEN
		RAISE EXCEPTION 'You have to enter a principle amount';
	ELSIF((NEW.monthly_repayment = 0) AND (NEW.repayment_period = 0))THEN
		RAISE EXCEPTION 'You have need to enter either monthly repayment amount or repayment period';
	ELSIF((NEW.monthly_repayment = 0) AND (NEW.repayment_period < 1))THEN
		RAISE EXCEPTION 'The repayment period should be greater than 0';
	ELSIF((NEW.repayment_period = 0) AND (NEW.monthly_repayment < 1))THEN
		RAISE EXCEPTION 'The monthly repayment should be greater than 0';
	ELSIF((NEW.monthly_repayment = 0) AND (NEW.repayment_period > 0))THEN
		NEW.monthly_repayment := NEW.principle / NEW.repayment_period;
	ELSIF((NEW.repayment_period = 0) AND (NEW.monthly_repayment > 0))THEN
		NEW.repayment_period := NEW.principle / NEW.monthly_repayment;
	END IF;
	
	IF(NEW.monthly_repayment > NEW.principle)THEN
		RAISE EXCEPTION 'Repayment should be less than the principal amount';
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_borrowing() OWNER TO postgres;

--
-- Name: ins_contrib(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_contrib() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_investment_amount			real;
	v_period_id					integer;
	v_org_id					integer;
	v_contribution_type_id		integer;
	v_merry_go_round_amount		real;
	 v_mgr_number				integer;
	 v_merry_go_round_number	integer;
	v_money_out					real;
	v_entity_id			integer;

BEGIN
	
	SELECT   org_id, contribution_type_id, SUM(merry_go_round_amount)
	INTO  v_org_id, v_contribution_type_id, v_money_out
	FROM contributions
		WHERE paid = true AND period_id = NEW.period_id 
		GROUP BY contribution_type_id,org_id;
	v_period_id := NEW.period_id;
	
RAISE EXCEPTION '%',v_contribution_type_id;
			IF (v_money_out = 0)THEN
			UPDATE contributions SET money_out  = 0 WHERE paid = true AND period_id =  v_period_id AND contribution_type_id = v_contribution_type_id;
	ELSIF 	(v_money_out != 0)THEN
	
		SELECT mgr_number INTO v_mgr_number FROM periods  WHERE period_id = NEW.period_id AND org_id = v_org_id;
		SELECT entity_id, merry_go_round_number INTO v_entity_id, v_merry_go_round_number 
		FROM vw_member_contrib 
		WHERE merry_go_round_number = v_mgr_number;
		
			UPDATE contributions SET money_out  = v_money_out WHERE paid = true AND period_id =  v_period_id AND contribution_type_id = v_contribution_type_id AND entity_id = v_entity_id;
	
	END IF;

RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_contrib() OWNER TO postgres;

--
-- Name: ins_contributions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_contributions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
reca 				record;
rec 				record;
reco 				record;
v_entity_id		integer;
recp record;
v_bal				real;
v_total_loan			real;
v_investment_amount		real;
BEGIN
SELECT SUM(investment_amount) INTO v_investment_amount FROM contributions WHERE paid = true AND entity_id = NEW.entity_id AND period_id = NEW.period_id;
v_entity_id := NEW.entity_id;
FOR reca IN SELECT loan_id, approve_status FROM vw_loans WHERE entity_id = v_entity_id LOOP
	IF(reca.approve_status = 'Approved' ) THEN

		FOR rec IN  SELECT (interest_amount+repayment+penalty_paid)AS amount FROM vw_loan_monthly
		 WHERE entity_id = v_entity_id AND period_id = NEW.period_id AND loan_id = reca.loan_id LOOP
			v_bal := v_investment_amount - rec.amount;
			IF (v_bal > 0) THEN
				FOR recp IN SELECT SUM(amount - penalty_paid) AS penalty_amount, penalty_type_id, bank_account_id,
				 currency_id, org_id, penalty_paid FROM penalty WHERE entity_id = v_entity_id GROUP BY penalty_type_id, bank_account_id,
				 currency_id, org_id, penalty_paid  LOOP
				 IF((v_bal <= recp.penalty_amount) )THEN
					INSERT INTO penalty ( penalty_type_id, bank_account_id, currency_id, org_id, penalty_paid)
					VALUES(recp.penalty_type_id, recp.bank_account_id, recp.currency_id, recp.org_id, v_bal);
					v_bal := 0;
				 END IF;
				 IF((v_bal - recp.penalty_amount) > 0 )THEN
					v_bal := v_bal - recp.penalty_amount;
				 
					INSERT INTO penalty ( penalty_type_id, bank_account_id, currency_id, org_id, penalty_paid)
					VALUES(recp.penalty_type_id, recp.bank_account_id, recp.currency_id, recp.org_id, recp.penalty_amount);
					
				 END IF;
					
				END LOOP;
				
			END IF;
		END LOOP;
	END IF;
END LOOP;
--NEW.money_in := v_bal;
UPDATE contributions SET money_in = v_bal WHERE contribution_id = New.contribution_id;
--raise exception '%',v_bal;
   RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_contributions() OWNER TO postgres;

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
-- Name: ins_fiscal_years(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_fiscal_years() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO periods (fiscal_year_id, org_id, start_date, end_date)
	SELECT NEW.fiscal_year_id, NEW.org_id, period_start, CAST(period_start + CAST('1 month' as interval) as date) - 1
	FROM (SELECT CAST(generate_series(fiscal_year_start, fiscal_year_end, '1 month') as date) as period_start
		FROM fiscal_years WHERE fiscal_year_id = NEW.fiscal_year_id) as a;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_fiscal_years() OWNER TO postgres;

--
-- Name: ins_investment(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_investment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_interests			real;
	
BEGIN
	SELECT interest_amount INTO v_interests FROM  investment_types WHERE investment_type_id = NEW. investment_type_id;
		
	IF (NEW.monthly_payments is null and NEW.principal is not null and  NEW.repayment_period is not null) THEN
		NEW.monthly_payments := NEW.principal/ NEW.repayment_period;
	ELSEIF (NEW.repayment_period is null and NEW.principal is not null and NEW.monthly_payments is not null ) THEN
		NEW.repayment_period := NEW.principal/NEW.monthly_payments;
	ELSEIF (NEW.repayment_period is null AND NEW.monthly_payments is null) THEN
		RAISE EXCEPTION 'Please enter the repayment period or the monthly payments';
	END IF;
	
	RETURN NEW;
END;

$$;


ALTER FUNCTION public.ins_investment() OWNER TO postgres;

--
-- Name: ins_loans(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_loans() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	SELECT CAST (repayment_period AS FLOAT);
	IF(NEW.principle is null) OR (NEW.interest is null)THEN
		RAISE EXCEPTION 'You have to enter a principle and interest amount';
	ELSIF(NEW.monthly_repayment is null) AND (NEW.repayment_period is null)THEN
		RAISE EXCEPTION 'You have need to enter either monthly repayment amount or repayment period';
	ELSIF(NEW.monthly_repayment is null) AND (NEW.repayment_period is not null)THEN
		IF(NEW.repayment_period > 0)THEN
			NEW.monthly_repayment := NEW.principle / NEW.repayment_period;
		ELSE
			RAISE EXCEPTION 'The repayment period should be greater than 0';
		END IF;
	ELSIF(NEW.monthly_repayment is not null) AND (NEW.repayment_period is null)THEN
		IF(NEW.monthly_repayment > 0)THEN
			NEW.repayment_period := NEW.principle / NEW.monthly_repayment;
		ELSE
			RAISE EXCEPTION 'The monthly repayment should be greater than 0';
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_loans() OWNER TO postgres;

--
-- Name: ins_member_limit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_member_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_member_count	integer;
	v_member_limit	integer;
BEGIN

	SELECT count(entity_id) INTO v_member_count
	FROM members
	WHERE (org_id = NEW.org_id);
	
	SELECT member_limit INTO v_member_limit
	FROM orgs
	WHERE (org_id = NEW.org_id);
	
	IF(v_member_count > v_member_limit)THEN
		RAISE EXCEPTION 'You have reached the maximum staff limit, request for a quite for more';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_member_limit() OWNER TO postgres;

--
-- Name: ins_members(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_members() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec 			RECORD;
	v_entity_id		integer;
BEGIN
	IF (TG_OP = 'INSERT') THEN
	
	IF (New.email is null)THEN
		RAISE EXCEPTION 'You have to enter an Email';
	ELSIF(NEW.first_name is null) AND (NEW.surname is null)THEN
		RAISE EXCEPTION 'You have need to enter Surname and First Name';
	
	ELSE
	Raise NOTICE 'Thank you';
	END IF;
	NEW.entity_id := nextval('entitys_entity_id_seq');

	INSERT INTO entitys (entity_id,entity_name,org_id,entity_type_id,user_name,primary_email,primary_telephone,function_role,details)
	VALUES (New.entity_id,New.surname,New.org_id::INTEGER,1,NEW.email,NEW.email,NEW.phone,'member',NEW.details) RETURNING entity_id INTO v_entity_id;

	NEW.entity_id := v_entity_id;

	update members set full_name = (NEW.Surname || ' ' || NEW.First_name || ' ' || COALESCE(NEW.Middle_name, '')) where member_id = New.member_id;
END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_members() OWNER TO postgres;

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

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_password() OWNER TO postgres;

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
	v_entity_id		integer;
	v_org_id		integer;
	v_currency_id	integer;
	v_department_id	integer;
	v_bank_id		integer;
	v_org_suffix    char(2);
	v_member_id		integer;
	rec 			RECORD;
BEGIN

	IF (TG_OP = 'INSERT') THEN
		SELECT entity_id INTO v_entity_id
		FROM entitys WHERE lower(trim(user_name)) = lower(trim(NEW.primary_email));
		IF(v_entity_id is null)THEN
			NEW.entity_id := nextval('entitys_entity_id_seq');
			INSERT INTO entitys (entity_id, org_id, entity_type_id, entity_name, User_name, primary_email,  function_role, first_password)
			VALUES (NEW.entity_id, 0, 5, NEW.primary_contact, lower(trim(NEW.primary_email)), lower(trim(NEW.primary_email)), 'subscription', null);
		
			INSERT INTO sys_emailed ( org_id, table_id, table_name)
			VALUES ( 0, 1, 'subscription');
		
			ELSE
			RAISE EXCEPTION 'You already have an account, login and request for services';
		END IF ;
		
	ELSIF(NEW.approve_status = 'Approved')THEN

		NEW.org_id := nextval('orgs_org_id_seq');
		
		INSERT INTO orgs(org_id, currency_id, org_name, org_sufix, default_country_id)
		VALUES(NEW.org_id, 1, NEW.chama_name, NEW.org_id, NEW.country_id);
		
		v_currency_id := nextval('currency_currency_id_seq');
		INSERT INTO currency (org_id, currency_id, currency_name, currency_symbol) VALUES (NEW.org_id, v_currency_id, 'Default Currency', 'DC');
		UPDATE orgs SET currency_id = v_currency_id WHERE org_id = NEW.org_id;
		v_bank_id := nextval('banks_bank_id_seq');

		INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (NEW.org_id, v_currency_id, 1);
		
		INSERT INTO banks (org_id, bank_id, bank_name) VALUES (NEW.org_id, v_bank_id, 'Cash');

		INSERT INTO bank_branch (org_id, bank_id, bank_branch_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		
		INSERT INTO locations (org_id, location_name) VALUES (NEW.org_id, 'Main');

		INSERT INTO transaction_counters(transaction_type_id, org_id, document_number)
		SELECT transaction_type_id, NEW.org_id, 1
		FROM transaction_types;
		

		UPDATE entitys SET org_id = NEW.org_id, function_role='subscription,admin,staff,finance'
		WHERE entity_id = NEW.entity_id;
		
		v_member_id := nextval('members_member_id_seq');
		INSERT INTO members(org_id, member_id, entity_id, email, surname) VALUES (NEW.org_id, v_member_id, NEW.entity_id, NEW.primary_email, NEW.primary_contact);

		INSERT INTO sys_emailed ( org_id, table_id, table_name)
		VALUES ( NEW.org_id, NEW.entity_id, 'subscription');
		
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
-- Name: ins_transactions_limit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_transactions_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_transaction_count	integer;
	v_transaction_limit	integer;
BEGIN

	SELECT count(transaction_id) INTO v_transaction_count
	FROM transactions
	WHERE (org_id = NEW.org_id);
	
	SELECT transaction_limit INTO v_transaction_limit
	FROM orgs
	WHERE (org_id = NEW.org_id);
	
	IF(v_transaction_count > v_transaction_limit)THEN
		RAISE EXCEPTION 'You have reached the maximum transaction limit, request for a quite for more';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_transactions_limit() OWNER TO postgres;

--
-- Name: investment_aplication(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION investment_aplication(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 		varchar(120);
BEGIN
	msg := 'Investment applied';
	
	UPDATE investments SET approve_status = 'Completed', investment_status = 'Committed'
	WHERE (investment_id = CAST($1 as int)) AND (approve_status = 'Draft') AND investment_status = 'Prospective';

	return msg;
END;
$_$;


ALTER FUNCTION public.investment_aplication(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: post_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION post_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	periodid INTEGER;
	journalid INTEGER;
	msg varchar(120);
BEGIN
	SELECT org_id, department_id, transaction_id, transaction_type_id, transaction_type_name as tx_name, 
		transaction_status_id, journal_id, gl_bank_account_id, currency_id, exchange_rate,
		transaction_date, transaction_amount, document_number, credit_amount, debit_amount,
		entity_account_id, entity_name, approve_status INTO rec
	FROM vw_transactions
	WHERE (transaction_id = CAST($1 as integer));

	periodid := get_open_period(rec.transaction_date);
	IF(periodid is null) THEN
		msg := 'No active period to post.';
	ELSIF(rec.journal_id is not null) THEN
		msg := 'Transaction previously Posted.';
	ELSIF(rec.transaction_status_id = 1) THEN
		msg := 'Transaction needs to be completed first.';
	ELSIF(rec.approve_status != 'Approved') THEN
		msg := 'Transaction is not yet approved.';
	ELSE
		INSERT INTO journals (org_id, department_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (rec.org_id, rec.department_id, rec.currency_id, periodid, rec.exchange_rate, rec.transaction_date, rec.tx_name || ' - posting for ' || rec.document_number);
		journalid := currval('journals_journal_id_seq');

		INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
		VALUES (rec.org_id, journalid, rec.entity_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);

		IF((rec.transaction_type_id = 7) or (rec.transaction_type_id = 8)) THEN
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, journalid, rec.gl_bank_account_id, rec.credit_amount, rec.debit_amount, rec.tx_name || ' - ' || rec.entity_name);
		ELSE
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, journalid, trans_account_id, full_debit_amount, full_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_amount > 0);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, journalid, tax_account_id, tax_debit_amount, tax_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_tax_amount > 0);
		END IF;

		UPDATE transactions SET journal_id = journalid WHERE (transaction_id = rec.transaction_id);
		msg := process_journal(CAST(journalid as varchar),'0','0');
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
-- Name: process_loans(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION process_loans(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec					RECORD;
	v_exchange_rate		real;
	msg					varchar(120);
BEGIN
	
	FOR rec IN SELECT vw_loan_monthly.loan_month_id, vw_loan_monthly.loan_id, vw_loan_monthly.entity_id, vw_loan_monthly.period_id, 
		vw_loan_monthly.loan_balance, vw_loan_monthly.repayment, (vw_loan_monthly.interest_paid + vw_loan_monthly.penalty_paid) as total_interest
	FROM vw_loan_monthly
	WHERE (vw_loan_monthly.period_id = CAST($1 as int)) LOOP
	
		IF(rec.currency_id = rec.adj_currency_id)THEN
			v_exchange_rate := 1;
		ELSE
			v_exchange_rate := 1 / rec.exchange_rate;
		END IF;
	END LOOP;

	msg := 'Loan Processed';

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.process_loans(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: remove_member_meeting(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION remove_member_meeting(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg		 				varchar(120);
	v_member_id				integer;
	v_org_id				integer;
BEGIN

	SELECT member_id INTO v_member_id
	FROM member_meeting WHERE (member_id = $1::int) AND (meeting_id = $3::int);
	
	IF(v_member_id is not null)THEN
		SELECT org_id INTO v_org_id
		FROM meetings WHERE (meeting_id = $3::int);
		
		DELETE FROM  member_meeting WHERE member_id = v_member_id AND (meeting_id = $3::int);
		

		msg := 'Removed from meeting';
		END IF;
	
	return msg;
END;
$_$;


ALTER FUNCTION public.remove_member_meeting(character varying, character varying, character varying) OWNER TO postgres;

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
			iswf := false;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(TG_TABLE_NAME = 'entry_forms')THEN
					tbid := NEW.form_id;
				ELSIF(TG_TABLE_NAME = 'employee_leave')THEN
					tbid := NEW.leave_type_id;
				END IF;
				IF(tbid = reca.table_link_id)THEN
					iswf := true;
				END IF;
			END IF;

			IF(iswf = true)THEN
				INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done)
				SELECT org_id, workflow_phase_id, tg_table_name, wfid, new.entity_id, escalation_days, escalation_hours, approval_level, phase_narrative, 'Approve - ' || phase_narrative
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
	SELECT approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id, approvals.review_advice,
		workflow_phases.workflow_phase_id, workflow_phases.workflow_id, workflow_phases.return_level INTO reca
	FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
	WHERE (approvals.approval_id = app_id);

	SELECT count(approval_checklist_id) as cl_count INTO recc
	FROM approval_checklists
	WHERE (approval_id = app_id) AND (manditory = true) AND (done = false);

	SELECT transaction_type_id, get_budgeted(transaction_id, transaction_date, department_id) as budget_var INTO recd
	FROM transactions
	WHERE (workflow_table_id = reca.table_id);

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF (recd.transaction_type_id = 5) AND (recd.budget_var < 0) THEN
		msg := 'You need a budget to approve the expenditure.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false) AND (workflow_phases.notice = false);
		
		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved') 
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;

			INSERT INTO sys_emailed (table_id, table_name, email_type)
			VALUES (reca.table_id, 'vw_workflow_approvals', 1);
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level = min_level) LOOP
				IF (recb.advice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				ELSE
					UPDATE approvals SET approve_status = 'Completed', completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
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
		INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, workflow_phase_id, reca.table_name, reca.table_id, CAST($2 as int), escalation_days, escalation_hours, approval_level, phase_narrative, reca.review_advice, 'Completed'
		FROM vw_workflow_entitys
		WHERE (workflow_id = reca.workflow_id) AND (approval_level = reca.return_level)
		ORDER BY workflow_phase_id;
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
-- Name: upd_email(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_email() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF (TG_OP = 'INSERT') THEN
	INSERT INTO sys_emailed ( table_id, table_name, email_type)
	VALUES (10, TG_TABLE_NAME, 6);
END IF;

RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_email() OWNER TO postgres;

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
-- Name: upd_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg							varchar(120);
BEGIN
	
	IF ($3 = '1') THEN
		UPDATE tx_ledger SET for_processing = true WHERE tx_ledger_id = $1::integer;
		msg := 'Opened for processing';
	ELSIF ($3 = '2') THEN
		UPDATE tx_ledger SET for_processing = false WHERE tx_ledger_id = $1::integer;
		msg := 'Closed for processing';
	ELSIF ($3 = '3') THEN
		UPDATE tx_ledger  SET tx_ledger_date = current_date, completed = true
		WHERE tx_ledger_id = $1::integer AND completed = false;
		msg := 'Completed';
	ELSIF ($3 = '4') THEN
		UPDATE tx_ledger  SET is_cleared = true WHERE tx_ledger_id = $1::integer;
		msg := 'Cleared for posting ';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: upd_transactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_transactions() RETURNS trigger
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
	ELSE
		IF ((OLD.approve_status = 'Draft') AND (NEW.completed = true)) THEN
			NEW.approve_status := 'Completed';
		END IF;
	
		IF (OLD.journal_id is null) AND (NEW.journal_id is not null) THEN
		ELSIF ((OLD.approve_status = 'Completed') AND (NEW.approve_status != 'Completed')) THEN
		ELSIF ((OLD.journal_id is not null) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already posted no changes are allowed.', NEW.transaction_id;
		ELSIF ((OLD.transaction_status_id > 1) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already completed no changes are allowed.', NEW.transaction_id;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_transactions() OWNER TO postgres;

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
		UPDATE transactions  SET tx_ledger_date = current_date, completed = true
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
    org_id integer,
    accounts_class_id integer,
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
    org_id integer,
    account_type_id integer,
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
    is_default boolean,
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
-- Name: applicants; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE applicants (
    entity_id integer NOT NULL,
    org_id integer,
    person_title character varying(7),
    surname character varying(50) NOT NULL,
    first_name character varying(50) NOT NULL,
    middle_name character varying(50),
    applicant_email character varying(50) NOT NULL,
    applicant_phone character varying(50),
    date_of_birth date,
    gender character varying(1),
    nationality character(2),
    marital_status character varying(2),
    picture_file character varying(32),
    identity_card character varying(50),
    language character varying(320),
    previous_salary real,
    expected_salary real,
    how_you_heard character varying(320),
    created timestamp without time zone DEFAULT now(),
    field_of_study text,
    interests text,
    objective text,
    details text
);


ALTER TABLE public.applicants OWNER TO postgres;

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
-- Name: borrowing; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE borrowing (
    borrowing_id integer NOT NULL,
    borrowing_type_id integer,
    currency_id integer,
    org_id integer,
    bank_account_id integer,
    principle real NOT NULL,
    interest real NOT NULL,
    monthly_repayment real,
    borrowing_date date,
    initial_payment real DEFAULT 0 NOT NULL,
    reducing_balance boolean DEFAULT true NOT NULL,
    repayment_period integer NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    CONSTRAINT borrowing_repayment_period_check CHECK ((repayment_period > 0))
);


ALTER TABLE public.borrowing OWNER TO postgres;

--
-- Name: borrowing_borrowing_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE borrowing_borrowing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.borrowing_borrowing_id_seq OWNER TO postgres;

--
-- Name: borrowing_borrowing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE borrowing_borrowing_id_seq OWNED BY borrowing.borrowing_id;


--
-- Name: borrowing_repayment; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE borrowing_repayment (
    borrowing_repayment_id integer NOT NULL,
    org_id integer,
    borrowing_id integer,
    period_id integer,
    interest_amount real DEFAULT 0 NOT NULL,
    repayment real DEFAULT 0 NOT NULL,
    interest_paid real DEFAULT 0 NOT NULL,
    penalty_paid real DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.borrowing_repayment OWNER TO postgres;

--
-- Name: borrowing_repayment_borrowing_repayment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE borrowing_repayment_borrowing_repayment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.borrowing_repayment_borrowing_repayment_id_seq OWNER TO postgres;

--
-- Name: borrowing_repayment_borrowing_repayment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE borrowing_repayment_borrowing_repayment_id_seq OWNED BY borrowing_repayment.borrowing_repayment_id;


--
-- Name: borrowing_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE borrowing_types (
    borrowing_type_id integer NOT NULL,
    org_id integer,
    borrowing_type_name character varying(120),
    default_interest real,
    reducing_balance boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.borrowing_types OWNER TO postgres;

--
-- Name: borrowing_types_borrowing_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE borrowing_types_borrowing_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.borrowing_types_borrowing_type_id_seq OWNER TO postgres;

--
-- Name: borrowing_types_borrowing_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE borrowing_types_borrowing_type_id_seq OWNED BY borrowing_types.borrowing_type_id;


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
-- Name: contribution_defaults; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contribution_defaults (
    contribution_default_id integer NOT NULL,
    contribution_type_id integer,
    entity_id integer,
    org_id integer,
    investment_amount real DEFAULT 0 NOT NULL,
    merry_go_round_amount real DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.contribution_defaults OWNER TO postgres;

--
-- Name: contribution_defaults_contribution_default_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contribution_defaults_contribution_default_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contribution_defaults_contribution_default_id_seq OWNER TO postgres;

--
-- Name: contribution_defaults_contribution_default_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contribution_defaults_contribution_default_id_seq OWNED BY contribution_defaults.contribution_default_id;


--
-- Name: contribution_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contribution_types (
    contribution_type_id integer NOT NULL,
    org_id integer,
    contribution_type_name character varying(240),
    investment_amount real DEFAULT 0 NOT NULL,
    merry_go_round_amount real DEFAULT 0 NOT NULL,
    frequency character varying(15),
    applies_to_all boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.contribution_types OWNER TO postgres;

--
-- Name: contribution_types_contribution_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contribution_types_contribution_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contribution_types_contribution_type_id_seq OWNER TO postgres;

--
-- Name: contribution_types_contribution_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contribution_types_contribution_type_id_seq OWNED BY contribution_types.contribution_type_id;


--
-- Name: contributions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contributions (
    contribution_id integer NOT NULL,
    contribution_type_id integer,
    bank_account_id integer,
    entity_id integer,
    member_id integer,
    period_id integer,
    org_id integer,
    contribution_date timestamp without time zone,
    investment_amount real NOT NULL,
    merry_go_round_amount real,
    paid boolean DEFAULT false,
    money_in real,
    money_out real,
    details text
);


ALTER TABLE public.contributions OWNER TO postgres;

--
-- Name: contributions_contribution_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contributions_contribution_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contributions_contribution_id_seq OWNER TO postgres;

--
-- Name: contributions_contribution_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contributions_contribution_id_seq OWNED BY contributions.contribution_id;


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
-- Name: day_ledgers; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE day_ledgers (
    day_ledger_id integer NOT NULL,
    entity_id integer,
    transaction_type_id integer,
    bank_account_id integer,
    journal_id integer,
    transaction_status_id integer DEFAULT 1,
    currency_id integer,
    department_id integer,
    item_id integer,
    store_id integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    day_ledger_date date NOT NULL,
    day_ledger_quantity integer NOT NULL,
    day_ledger_amount real DEFAULT 0 NOT NULL,
    day_ledger_tax_amount real DEFAULT 0 NOT NULL,
    document_number integer DEFAULT 1 NOT NULL,
    payment_number character varying(50),
    order_number character varying(50),
    payment_terms character varying(50),
    job character varying(240),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(120),
    details text
);


ALTER TABLE public.day_ledgers OWNER TO postgres;

--
-- Name: day_ledgers_day_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE day_ledgers_day_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.day_ledgers_day_ledger_id_seq OWNER TO postgres;

--
-- Name: day_ledgers_day_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE day_ledgers_day_ledger_id_seq OWNED BY day_ledgers.day_ledger_id;


--
-- Name: default_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE default_accounts (
    default_account_id integer NOT NULL,
    org_id integer,
    account_id integer,
    use_key integer NOT NULL,
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
-- Name: drawings; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE drawings (
    drawing_id integer NOT NULL,
    org_id integer,
    period_id integer,
    entity_id integer,
    bank_account_id integer,
    withdrawal_date date,
    narrative character varying(120),
    amount real,
    details text
);


ALTER TABLE public.drawings OWNER TO postgres;

--
-- Name: drawings_drawing_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE drawings_drawing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.drawings_drawing_id_seq OWNER TO postgres;

--
-- Name: drawings_drawing_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE drawings_drawing_id_seq OWNED BY drawings.drawing_id;


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
    org_id integer,
    entity_type_name character varying(50) NOT NULL,
    entity_role character varying(240),
    use_key integer DEFAULT 0 NOT NULL,
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
-- Name: entitys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entitys (
    entity_id integer NOT NULL,
    entity_type_id integer NOT NULL,
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
-- Name: expenses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE expenses (
    expense_id integer NOT NULL,
    entity_id integer,
    bank_account_id integer,
    org_id integer,
    currency_id integer,
    date_accrued date,
    amount real NOT NULL,
    details text
);


ALTER TABLE public.expenses OWNER TO postgres;

--
-- Name: expenses_expense_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE expenses_expense_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.expenses_expense_id_seq OWNER TO postgres;

--
-- Name: expenses_expense_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE expenses_expense_id_seq OWNED BY expenses.expense_id;


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
    fiscal_year_id character varying(9) NOT NULL,
    org_id integer,
    fiscal_year_start date NOT NULL,
    fiscal_year_end date NOT NULL,
    year_opened boolean DEFAULT true NOT NULL,
    year_closed boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.fiscal_years OWNER TO postgres;

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
    org_id integer,
    journal_id integer NOT NULL,
    account_id integer NOT NULL,
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
-- Name: investment_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE investment_types (
    investment_type_id integer NOT NULL,
    org_id integer,
    investment_type_name character varying(120),
    interest_amount real,
    details text
);


ALTER TABLE public.investment_types OWNER TO postgres;

--
-- Name: investment_types_investment_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE investment_types_investment_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.investment_types_investment_type_id_seq OWNER TO postgres;

--
-- Name: investment_types_investment_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE investment_types_investment_type_id_seq OWNED BY investment_types.investment_type_id;


--
-- Name: investments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE investments (
    investment_id integer NOT NULL,
    investment_type_id integer,
    currency_id integer,
    org_id integer,
    bank_account_id integer,
    investment_name character varying(120),
    investment_status character varying(25) DEFAULT 'Prospective'::character varying NOT NULL,
    date_of_accrual date,
    principal real,
    interest real,
    repayment_period real,
    initial_payment real DEFAULT 0 NOT NULL,
    monthly_payments real,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.investments OWNER TO postgres;

--
-- Name: investments_investment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE investments_investment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.investments_investment_id_seq OWNER TO postgres;

--
-- Name: investments_investment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE investments_investment_id_seq OWNED BY investments.investment_id;


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
    org_id integer,
    period_id integer NOT NULL,
    currency_id integer,
    department_id integer,
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
-- Name: kin_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE kin_types (
    kin_type_id integer NOT NULL,
    org_id integer,
    kin_type_name character varying(50),
    details text
);


ALTER TABLE public.kin_types OWNER TO postgres;

--
-- Name: kin_types_kin_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE kin_types_kin_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.kin_types_kin_type_id_seq OWNER TO postgres;

--
-- Name: kin_types_kin_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE kin_types_kin_type_id_seq OWNED BY kin_types.kin_type_id;


--
-- Name: kins; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE kins (
    kin_id integer NOT NULL,
    entity_id integer,
    kin_type_id integer,
    org_id integer,
    full_names character varying(120),
    date_of_birth date,
    identification character varying(50),
    relation character varying(50),
    emergency_contact boolean DEFAULT false NOT NULL,
    beneficiary boolean DEFAULT false NOT NULL,
    beneficiary_ps real,
    details text
);


ALTER TABLE public.kins OWNER TO postgres;

--
-- Name: kins_kin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE kins_kin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.kins_kin_id_seq OWNER TO postgres;

--
-- Name: kins_kin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE kins_kin_id_seq OWNED BY kins.kin_id;


--
-- Name: ledger_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ledger_types (
    ledger_type_id integer NOT NULL,
    account_id integer,
    org_id integer,
    ledger_type_name character varying(120) NOT NULL,
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
-- Name: loan_monthly; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE loan_monthly (
    loan_month_id integer NOT NULL,
    loan_id integer,
    period_id integer,
    org_id integer,
    interest_amount real DEFAULT 0 NOT NULL,
    repayment real DEFAULT 0 NOT NULL,
    interest_paid real DEFAULT 0 NOT NULL,
    penalty_paid real DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.loan_monthly OWNER TO postgres;

--
-- Name: loan_monthly_loan_month_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE loan_monthly_loan_month_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_monthly_loan_month_id_seq OWNER TO postgres;

--
-- Name: loan_monthly_loan_month_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE loan_monthly_loan_month_id_seq OWNED BY loan_monthly.loan_month_id;


--
-- Name: loan_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE loan_types (
    loan_type_id integer NOT NULL,
    org_id integer,
    loan_type_name character varying(50) NOT NULL,
    default_interest real,
    reducing_balance boolean DEFAULT true NOT NULL,
    penalty real DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.loan_types OWNER TO postgres;

--
-- Name: loan_types_loan_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE loan_types_loan_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_types_loan_type_id_seq OWNER TO postgres;

--
-- Name: loan_types_loan_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE loan_types_loan_type_id_seq OWNED BY loan_types.loan_type_id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE loans (
    loan_id integer NOT NULL,
    loan_type_id integer NOT NULL,
    bank_account_id integer,
    entity_id integer NOT NULL,
    org_id integer,
    principle real NOT NULL,
    interest real NOT NULL,
    monthly_repayment real NOT NULL,
    loan_date date,
    initial_payment real DEFAULT 0 NOT NULL,
    reducing_balance boolean DEFAULT true NOT NULL,
    repayment_period integer NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    CONSTRAINT loans_repayment_period_check CHECK ((repayment_period > 0))
);


ALTER TABLE public.loans OWNER TO postgres;

--
-- Name: loans_loan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE loans_loan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loans_loan_id_seq OWNER TO postgres;

--
-- Name: loans_loan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE loans_loan_id_seq OWNED BY loans.loan_id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE locations (
    location_id integer NOT NULL,
    org_id integer,
    location_name character varying(50),
    details text
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE locations_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.locations_location_id_seq OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE locations_location_id_seq OWNED BY locations.location_id;


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE meetings (
    meeting_id integer NOT NULL,
    org_id integer,
    meeting_date date,
    meeting_place character varying(120) NOT NULL,
    minutes character varying(120),
    status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    details text
);


ALTER TABLE public.meetings OWNER TO postgres;

--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE meetings_meeting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.meetings_meeting_id_seq OWNER TO postgres;

--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE meetings_meeting_id_seq OWNED BY meetings.meeting_id;


--
-- Name: member_meeting; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE member_meeting (
    member_meeting_id integer NOT NULL,
    member_id integer,
    meeting_id integer,
    org_id integer,
    narrative text
);


ALTER TABLE public.member_meeting OWNER TO postgres;

--
-- Name: member_meeting_member_meeting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE member_meeting_member_meeting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.member_meeting_member_meeting_id_seq OWNER TO postgres;

--
-- Name: member_meeting_member_meeting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE member_meeting_member_meeting_id_seq OWNED BY member_meeting.member_meeting_id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE members (
    member_id integer NOT NULL,
    entity_id integer,
    bank_id integer,
    bank_account_id integer,
    bank_branch_id integer,
    currency_id integer,
    org_id integer,
    location_id integer,
    person_title character varying(50),
    surname character varying(50),
    first_name character varying(50),
    middle_name character varying(50),
    full_name character varying(50),
    id_number character varying(50),
    email character varying(50),
    date_of_birth date,
    gender character varying(10),
    phone character varying(50),
    bank_account_number character varying(50),
    nationality character(2),
    nation_of_birth character(2),
    marital_status character varying(20),
    joining_date date,
    exit_date date,
    merry_go_round_number integer,
    picture_file character varying(32),
    active boolean DEFAULT true,
    details text
);


ALTER TABLE public.members OWNER TO postgres;

--
-- Name: members_member_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE members_member_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.members_member_id_seq OWNER TO postgres;

--
-- Name: members_member_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE members_member_id_seq OWNED BY members.member_id;


--
-- Name: orgs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orgs (
    org_id integer NOT NULL,
    currency_id integer,
    default_country_id character(2),
    parent_org_id integer,
    org_name character varying(50) NOT NULL,
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
    cert_number character varying(50),
    vat_number character varying(50),
    fixed_budget boolean DEFAULT true,
    invoice_footer text,
    member_limit integer DEFAULT 5 NOT NULL,
    transaction_limit integer DEFAULT 100 NOT NULL
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
-- Name: penalty; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE penalty (
    penalty_id integer NOT NULL,
    penalty_type_id integer,
    bank_account_id integer,
    currency_id integer,
    org_id integer,
    entity_id integer,
    date_of_accrual date,
    amount real NOT NULL,
    paid boolean DEFAULT true NOT NULL,
    penalty_paid real DEFAULT 0 NOT NULL,
    action_date timestamp without time zone,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.penalty OWNER TO postgres;

--
-- Name: penalty_penalty_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE penalty_penalty_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.penalty_penalty_id_seq OWNER TO postgres;

--
-- Name: penalty_penalty_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE penalty_penalty_id_seq OWNED BY penalty.penalty_id;


--
-- Name: penalty_type; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE penalty_type (
    penalty_type_id integer NOT NULL,
    org_id integer,
    penalty_type_name character varying(120),
    details text
);


ALTER TABLE public.penalty_type OWNER TO postgres;

--
-- Name: penalty_type_penalty_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE penalty_type_penalty_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.penalty_type_penalty_type_id_seq OWNER TO postgres;

--
-- Name: penalty_type_penalty_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE penalty_type_penalty_type_id_seq OWNED BY penalty_type.penalty_type_id;


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
    fiscal_year_id character varying(9),
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
    gl_bank_account character varying(32),
    gl_advance_account character varying(32),
    bank_header text,
    bank_address text,
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
-- Name: productions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE productions (
    production_id integer NOT NULL,
    subscription_id integer,
    product_id integer,
    entity_id integer,
    org_id integer,
    approve_status character varying(16) DEFAULT 'draft'::character varying NOT NULL,
    workflow_table_id integer,
    application_date timestamp without time zone DEFAULT now(),
    action_date timestamp without time zone,
    montly_billing boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.productions OWNER TO postgres;

--
-- Name: productions_production_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE productions_production_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productions_production_id_seq OWNER TO postgres;

--
-- Name: productions_production_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE productions_production_id_seq OWNED BY productions.production_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE products (
    product_id integer NOT NULL,
    org_id integer,
    product_name character varying(50),
    is_montly_bill boolean DEFAULT false NOT NULL,
    montly_cost real DEFAULT 0 NOT NULL,
    is_annual_bill boolean DEFAULT true NOT NULL,
    annual_cost real DEFAULT 0 NOT NULL,
    transaction_limit integer NOT NULL,
    details text
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE products_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.products_product_id_seq OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE products_product_id_seq OWNED BY products.product_id;


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
    chama_name character varying(50),
    chama_address character varying(100),
    city character varying(30),
    state character varying(50),
    country_id character(2),
    number_of_members integer,
    telephone character varying(50),
    website character varying(120),
    primary_contact character varying(120),
    job_title character varying(120),
    primary_email character varying(120),
    confirm_email character varying(120),
    approve_status character varying(16) DEFAULT 'Completed'::character varying NOT NULL,
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
    use_key integer DEFAULT 0 NOT NULL,
    use_type integer DEFAULT 0 NOT NULL,
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
    investment_id integer
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
-- Name: tx_ledger; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tx_ledger (
    tx_ledger_id integer NOT NULL,
    ledger_type_id integer,
    entity_id integer,
    bpartner_id integer,
    bank_account_id integer,
    investment_id integer,
    currency_id integer,
    journal_id integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    tx_type integer DEFAULT 1 NOT NULL,
    tx_ledger_date date NOT NULL,
    tx_ledger_quantity integer DEFAULT 1 NOT NULL,
    tx_ledger_amount real DEFAULT 0 NOT NULL,
    tx_ledger_tax_amount real DEFAULT 0 NOT NULL,
    reference_number character varying(50),
    payment_reference character varying(50),
    for_processing boolean DEFAULT false NOT NULL,
    is_cleared boolean DEFAULT false NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(120),
    details text
);


ALTER TABLE public.tx_ledger OWNER TO postgres;

--
-- Name: tx_ledger_tx_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tx_ledger_tx_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tx_ledger_tx_ledger_id_seq OWNER TO postgres;

--
-- Name: tx_ledger_tx_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tx_ledger_tx_ledger_id_seq OWNED BY tx_ledger.tx_ledger_id;


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
-- Name: vw_all_contributions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_all_contributions AS
 SELECT bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    contribution_types.contribution_type_id,
    contribution_types.contribution_type_name,
    entitys.entity_id,
    entitys.entity_name,
    members.member_id,
    members.middle_name,
    contributions.org_id,
    contributions.period_id,
    contributions.contribution_id,
    contributions.contribution_date,
    contributions.investment_amount,
    contributions.merry_go_round_amount,
    contributions.paid,
    contributions.money_in,
    contributions.money_out,
    (contributions.investment_amount + contributions.merry_go_round_amount) AS total_contribution,
    contributions.details
   FROM ((((contributions
     JOIN contribution_types ON ((contributions.contribution_type_id = contribution_types.contribution_type_id)))
     JOIN entitys ON ((contributions.entity_id = entitys.entity_id)))
     JOIN members ON ((contributions.member_id = members.member_id)))
     LEFT JOIN bank_accounts ON ((contributions.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_all_contributions OWNER TO postgres;

--
-- Name: vw_applicants; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_applicants AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    applicants.entity_id,
    applicants.surname,
    applicants.org_id,
    applicants.first_name,
    applicants.middle_name,
    applicants.date_of_birth,
    applicants.nationality,
    applicants.identity_card,
    applicants.language,
    applicants.objective,
    applicants.interests,
    applicants.picture_file,
    applicants.details,
    applicants.person_title,
    applicants.field_of_study,
    applicants.applicant_email,
    applicants.applicant_phone,
    applicants.previous_salary,
    applicants.expected_salary,
    (((((applicants.surname)::text || ' '::text) || (applicants.first_name)::text) || ' '::text) || (COALESCE(applicants.middle_name, ''::character varying))::text) AS applicant_name,
    to_char(age((applicants.date_of_birth)::timestamp with time zone), 'YY'::text) AS applicant_age,
        CASE
            WHEN ((applicants.gender)::text = 'M'::text) THEN 'Male'::text
            ELSE 'Female'::text
        END AS gender_name,
        CASE
            WHEN ((applicants.marital_status)::text = 'M'::text) THEN 'Married'::text
            ELSE 'Single'::text
        END AS marital_status_name
   FROM (applicants
     JOIN sys_countrys ON ((applicants.nationality = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_applicants OWNER TO postgres;

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
-- Name: vw_borrowing; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_borrowing AS
 SELECT borrowing_types.borrowing_type_id,
    borrowing_types.borrowing_type_name,
    bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    borrowing.org_id,
    borrowing.borrowing_id,
    borrowing.principle,
    borrowing.interest,
    borrowing.monthly_repayment,
    borrowing.reducing_balance,
    borrowing.repayment_period,
    borrowing.initial_payment,
    borrowing.borrowing_date,
    borrowing.application_date,
    borrowing.approve_status,
    borrowing.workflow_table_id,
    borrowing.action_date,
    borrowing.details,
    get_borrowing_repayment(borrowing.principle, borrowing.interest, borrowing.repayment_period) AS repayment_amount,
    (borrowing.initial_payment + get_total_brepayment(borrowing.borrowing_id)) AS total_repayment,
    get_total_binterest(borrowing.borrowing_id) AS total_interest,
    (((borrowing.principle + get_total_binterest(borrowing.borrowing_id)) - borrowing.initial_payment) - get_total_brepayment(borrowing.borrowing_id)) AS borrowing_balance,
    get_bpayment_period(borrowing.principle, borrowing.monthly_repayment, borrowing.interest) AS calc_repayment_period
   FROM (((borrowing
     JOIN bank_accounts ON ((borrowing.bank_account_id = bank_accounts.bank_account_id)))
     JOIN borrowing_types ON ((borrowing.borrowing_type_id = borrowing_types.borrowing_type_id)))
     JOIN currency ON ((borrowing.currency_id = currency.currency_id)));


ALTER TABLE public.vw_borrowing OWNER TO postgres;

--
-- Name: vw_periods; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_periods AS
 SELECT fiscal_years.fiscal_year_id,
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
    periods.gl_bank_account,
    periods.gl_advance_account,
    periods.bank_header,
    periods.bank_address,
    periods.details,
    date_part('month'::text, periods.start_date) AS month_id,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY'::text) AS period_year,
    to_char((periods.start_date)::timestamp with time zone, 'Month'::text) AS period_month,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (3)::double precision)) + (1)::double precision) AS quarter,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (6)::double precision)) + (1)::double precision) AS semister,
    to_char((periods.start_date)::timestamp with time zone, 'YYYYMM'::text) AS period_code
   FROM (periods
     LEFT JOIN fiscal_years ON (((periods.fiscal_year_id)::text = (fiscal_years.fiscal_year_id)::text)))
  ORDER BY periods.start_date;


ALTER TABLE public.vw_periods OWNER TO postgres;

--
-- Name: vw_borrowing_mrepayment; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_borrowing_mrepayment AS
 SELECT vw_borrowing.currency_id,
    vw_borrowing.currency_name,
    vw_borrowing.currency_symbol,
    vw_borrowing.borrowing_type_id,
    vw_borrowing.borrowing_type_name,
    vw_borrowing.borrowing_date,
    vw_borrowing.borrowing_id,
    vw_borrowing.principle,
    vw_borrowing.interest,
    vw_borrowing.monthly_repayment,
    vw_borrowing.reducing_balance,
    vw_borrowing.repayment_period,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.activated,
    vw_periods.closed,
    borrowing_repayment.org_id,
    borrowing_repayment.borrowing_repayment_id,
    borrowing_repayment.interest_amount,
    borrowing_repayment.repayment,
    borrowing_repayment.interest_paid,
    borrowing_repayment.penalty_paid,
    borrowing_repayment.details,
    get_total_binterest(vw_borrowing.borrowing_id, vw_periods.start_date) AS total_interest,
    get_total_brepayment(vw_borrowing.borrowing_id, vw_periods.start_date) AS total_repayment,
    ((((vw_borrowing.principle + get_total_binterest(vw_borrowing.borrowing_id, (vw_periods.start_date + 1))) + get_bpenalty(vw_borrowing.borrowing_id, (vw_periods.start_date + 1))) - vw_borrowing.initial_payment) - get_total_brepayment(vw_borrowing.borrowing_id, (vw_periods.start_date + 1))) AS borrowing_balance
   FROM ((borrowing_repayment
     JOIN vw_borrowing ON ((borrowing_repayment.borrowing_id = vw_borrowing.borrowing_id)))
     JOIN vw_periods ON ((borrowing_repayment.period_id = vw_periods.period_id)));


ALTER TABLE public.vw_borrowing_mrepayment OWNER TO postgres;

--
-- Name: vw_borrowing_payments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_borrowing_payments AS
 SELECT vw_borrowing.currency_id,
    vw_borrowing.currency_name,
    vw_borrowing.currency_symbol,
    vw_borrowing.borrowing_type_id,
    vw_borrowing.borrowing_type_name,
    vw_borrowing.borrowing_date,
    vw_borrowing.borrowing_id,
    vw_borrowing.principle,
    vw_borrowing.interest,
    vw_borrowing.monthly_repayment,
    vw_borrowing.reducing_balance,
    vw_borrowing.repayment_period,
    vw_borrowing.application_date,
    vw_borrowing.approve_status,
    vw_borrowing.initial_payment,
    vw_borrowing.org_id,
    vw_borrowing.action_date,
    generate_series(1, vw_borrowing.repayment_period) AS months,
    get_borrowing_period(vw_borrowing.principle, vw_borrowing.interest, generate_series(1, vw_borrowing.repayment_period), vw_borrowing.repayment_amount) AS borrowing_balance,
    (get_borrowing_period(vw_borrowing.principle, vw_borrowing.interest, (generate_series(1, vw_borrowing.repayment_period) - 1), vw_borrowing.repayment_amount) * (vw_borrowing.interest / (1200)::double precision)) AS borrowing_interest
   FROM vw_borrowing;


ALTER TABLE public.vw_borrowing_payments OWNER TO postgres;

--
-- Name: vw_borrowing_projection; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_borrowing_projection AS
 SELECT vw_borrowing.org_id,
    vw_borrowing.borrowing_id,
    vw_borrowing.borrowing_type_name,
    vw_borrowing.principle,
    vw_borrowing.monthly_repayment,
    vw_borrowing.borrowing_date,
    ((date_part('year'::text, age((('now'::text)::date)::timestamp with time zone, '2010-05-01 00:00:00+03'::timestamp with time zone)) * (12)::double precision) + date_part('month'::text, age((('now'::text)::date)::timestamp with time zone, (vw_borrowing.borrowing_date)::timestamp with time zone))) AS borrowing_months,
    get_total_brepayment(vw_borrowing.borrowing_id, (((date_part('year'::text, age((('now'::text)::date)::timestamp with time zone, '2010-05-01 00:00:00+03'::timestamp with time zone)) * (12)::double precision) + date_part('month'::text, age((('now'::text)::date)::timestamp with time zone, (vw_borrowing.borrowing_date)::timestamp with time zone))))::integer) AS borrowing_paid
   FROM vw_borrowing;


ALTER TABLE public.vw_borrowing_projection OWNER TO postgres;

--
-- Name: vw_borrowing_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_borrowing_types AS
 SELECT borrowing_types.org_id,
    borrowing_types.borrowing_type_id,
    borrowing_types.borrowing_type_name,
    borrowing_types.details
   FROM borrowing_types;


ALTER TABLE public.vw_borrowing_types OWNER TO postgres;

--
-- Name: vw_budget_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_ledger AS
 SELECT journals.org_id,
    periods.fiscal_year_id,
    journals.department_id,
    gls.account_id,
    sum((journals.exchange_rate * gls.debit)) AS bl_debit,
    sum((journals.exchange_rate * gls.credit)) AS bl_credit,
    sum((journals.exchange_rate * (gls.debit - gls.credit))) AS bl_diff
   FROM ((journals
     JOIN gls ON ((journals.journal_id = gls.journal_id)))
     JOIN periods ON ((journals.period_id = periods.period_id)))
  WHERE (journals.posted = true)
  GROUP BY journals.org_id, periods.fiscal_year_id, journals.department_id, gls.account_id;


ALTER TABLE public.vw_budget_ledger OWNER TO postgres;

--
-- Name: vw_contributions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_contributions AS
 SELECT bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    contribution_types.contribution_type_id,
    contribution_types.contribution_type_name,
    entitys.entity_id,
    entitys.entity_name,
    members.member_id,
    members.middle_name,
    contributions.org_id,
    contributions.period_id,
    contributions.contribution_id,
    contributions.contribution_date,
    contributions.investment_amount,
    contributions.merry_go_round_amount,
    contributions.paid,
    contributions.money_in,
    contributions.money_out,
    (contributions.investment_amount + contributions.merry_go_round_amount) AS total_contribution,
    contributions.details
   FROM ((((contributions
     JOIN contribution_types ON ((contributions.contribution_type_id = contribution_types.contribution_type_id)))
     JOIN entitys ON ((contributions.entity_id = entitys.entity_id)))
     JOIN members ON ((contributions.member_id = members.member_id)))
     LEFT JOIN bank_accounts ON ((contributions.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_contributions OWNER TO postgres;

--
-- Name: vw_drawings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_drawings AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    drawings.org_id,
    drawings.period_id,
    drawings.drawing_id,
    drawings.amount,
    drawings.narrative,
    drawings.withdrawal_date,
    drawings.details
   FROM ((drawings
     JOIN entitys ON ((drawings.entity_id = entitys.entity_id)))
     JOIN bank_accounts ON ((drawings.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_drawings OWNER TO postgres;

--
-- Name: vw_investments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_investments AS
 SELECT currency.currency_id,
    currency.currency_name,
    investment_types.investment_type_id,
    investment_types.investment_type_name,
    bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    investments.org_id,
    investments.investment_id,
    investments.investment_name,
    investments.date_of_accrual,
    investments.principal,
    investments.interest,
    investments.repayment_period,
    investments.initial_payment,
    investments.monthly_payments,
    investments.investment_status,
    investments.approve_status,
    investments.workflow_table_id,
    investments.action_date,
    investments.is_active,
    investments.details,
    get_total_repayment(investments.principal, investments.interest, investments.repayment_period) AS total_repayment,
    get_interest_amount(investments.principal, investments.interest, investments.repayment_period) AS interest_amount,
    get_total_expenditure(investments.investment_id) AS expenditure,
    get_total_income(investments.investment_id) AS income
   FROM (((investments
     JOIN currency ON ((investments.currency_id = currency.currency_id)))
     JOIN investment_types ON ((investments.investment_type_id = investment_types.investment_type_id)))
     LEFT JOIN bank_accounts ON ((investments.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_investments OWNER TO postgres;

--
-- Name: vw_loan_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_types AS
 SELECT currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    loan_types.org_id,
    loan_types.loan_type_id,
    loan_types.loan_type_name,
    loan_types.default_interest,
    loan_types.reducing_balance,
    loan_types.penalty,
    loan_types.details
   FROM (loan_types
     JOIN currency ON ((loan_types.org_id = currency.org_id)));


ALTER TABLE public.vw_loan_types OWNER TO postgres;

--
-- Name: vw_loans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loans AS
 SELECT vw_loan_types.currency_id,
    vw_loan_types.currency_name,
    vw_loan_types.currency_symbol,
    vw_loan_types.loan_type_id,
    vw_loan_types.loan_type_name,
    entitys.entity_id,
    entitys.entity_name,
    loans.org_id,
    loans.loan_id,
    loans.principle,
    loans.interest,
    loans.monthly_repayment,
    loans.reducing_balance,
    loans.repayment_period,
    loans.application_date,
    loans.approve_status,
    loans.initial_payment,
    loans.loan_date,
    loans.action_date,
    loans.details,
    get_repayment(loans.principle, loans.interest, loans.repayment_period) AS repayment_amount,
    (loans.initial_payment + get_total_repayment(loans.loan_id)) AS total_repayment,
    get_total_interest(loans.loan_id) AS total_interest,
    (((loans.principle + get_total_interest(loans.loan_id)) - loans.initial_payment) - get_total_repayment(loans.loan_id)) AS loan_balance,
    get_payment_period(loans.principle, loans.monthly_repayment, loans.interest) AS calc_repayment_period
   FROM ((loans
     JOIN entitys ON ((loans.entity_id = entitys.entity_id)))
     JOIN vw_loan_types ON ((loans.loan_type_id = vw_loan_types.loan_type_id)));


ALTER TABLE public.vw_loans OWNER TO postgres;

--
-- Name: vw_loan_monthly; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_monthly AS
 SELECT vw_loans.currency_id,
    vw_loans.currency_name,
    vw_loans.currency_symbol,
    vw_loans.loan_type_id,
    vw_loans.loan_type_name,
    vw_loans.entity_id,
    vw_loans.entity_name,
    vw_loans.loan_date,
    vw_loans.loan_id,
    vw_loans.principle,
    vw_loans.interest,
    vw_loans.monthly_repayment,
    vw_loans.reducing_balance,
    vw_loans.repayment_period,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.activated,
    vw_periods.closed,
    loan_monthly.org_id,
    loan_monthly.loan_month_id,
    loan_monthly.interest_amount,
    loan_monthly.repayment,
    loan_monthly.interest_paid,
    loan_monthly.penalty_paid,
    loan_monthly.details,
    get_total_interest(vw_loans.loan_id, vw_periods.start_date) AS total_interest,
    get_total_repayment(vw_loans.loan_id, vw_periods.start_date) AS total_repayment,
    ((((vw_loans.principle + get_total_interest(vw_loans.loan_id, (vw_periods.start_date + 1))) + get_penalty(vw_loans.loan_id, (vw_periods.start_date + 1))) - vw_loans.initial_payment) - get_total_repayment(vw_loans.loan_id, (vw_periods.start_date + 1))) AS loan_balance
   FROM ((loan_monthly
     JOIN vw_loans ON ((loan_monthly.loan_id = vw_loans.loan_id)))
     JOIN vw_periods ON ((loan_monthly.period_id = vw_periods.period_id)));


ALTER TABLE public.vw_loan_monthly OWNER TO postgres;

--
-- Name: vw_penalty; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_penalty AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    penalty.org_id,
    penalty_type.penalty_type_id,
    penalty_type.penalty_type_name,
    bank_accounts.bank_account_id,
    penalty.penalty_id,
    penalty.date_of_accrual,
    penalty.amount,
    penalty.paid,
    penalty.action_date,
    penalty.is_active,
    penalty.details
   FROM (((penalty
     JOIN entitys ON ((penalty.entity_id = entitys.entity_id)))
     JOIN penalty_type ON ((penalty.penalty_type_id = penalty_type.penalty_type_id)))
     LEFT JOIN bank_accounts ON ((penalty.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_penalty OWNER TO postgres;

--
-- Name: vw_tx_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tx_ledger AS
 SELECT ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
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
    transactions.investment_id,
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
     JOIN ledger_types ON ((transactions.ledger_type_id = ledger_types.ledger_type_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     JOIN bank_accounts ON ((transactions.bank_account_id = bank_accounts.bank_account_id)))
     JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
  WHERE (transactions.tx_type IS NOT NULL);


ALTER TABLE public.vw_tx_ledger OWNER TO postgres;

--
-- Name: vw_chama_statement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_chama_statement AS
 SELECT a.title,
    a.date,
    a.contribution,
    a.drawings,
    a.loans,
    a.repayments,
    a.investments,
    a.borrowing,
    a.penalty,
    a.income,
    a.expenditure,
    a.org_id
   FROM ( SELECT 'contributions'::character varying(50) AS title,
            vw_contributions.contribution_date AS date,
            vw_contributions.total_contribution AS contribution,
            (0)::real AS drawings,
            (0)::real AS loans,
            (0)::real AS repayments,
            (0)::real AS investments,
            (0)::real AS borrowing,
            (0)::real AS penalty,
            (0)::real AS income,
            (0)::real AS expenditure,
            vw_contributions.org_id
           FROM vw_contributions
          WHERE (vw_contributions.paid = true)
        UNION
         SELECT 'Drawings'::character varying(50) AS title,
            vw_drawings.withdrawal_date AS date,
            (0)::real AS float4,
            vw_drawings.amount,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_drawings.org_id
           FROM vw_drawings
        UNION
         SELECT 'loans'::character varying(50) AS title,
            vw_loans.loan_date AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loans.principle,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loans.org_id
           FROM (vw_loans
             JOIN periods ON (((vw_loans.loan_date >= periods.start_date) AND (vw_loans.loan_date <= periods.end_date))))
        UNION
         SELECT 'Repayment'::character varying(50) AS title,
            vw_loan_monthly.start_date AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loan_monthly.total_repayment,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loan_monthly.org_id
           FROM vw_loan_monthly
        UNION
         SELECT 'Investment'::character varying(50) AS title,
            vw_investments.date_of_accrual AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_investments.principal,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_investments.org_id
           FROM vw_investments
        UNION
         SELECT 'borrowing'::character varying(50) AS title,
            vw_borrowing.borrowing_date AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_borrowing.principle,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_borrowing.org_id
           FROM vw_borrowing
        UNION
         SELECT 'Penalty'::character varying(50) AS title,
            vw_penalty.date_of_accrual AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_penalty.amount,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_penalty.org_id
           FROM vw_penalty
        UNION
         SELECT 'Income'::character varying(50) AS title,
            vw_tx_ledger.transaction_date AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_tx_ledger.dr_amount,
            (0)::real AS float4,
            vw_tx_ledger.org_id
           FROM vw_tx_ledger
          WHERE (vw_tx_ledger.tx_type = 1)
        UNION
         SELECT 'Expenditure'::character varying(50) AS title,
            vw_tx_ledger.transaction_date AS date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_tx_ledger.cr_amount,
            vw_tx_ledger.org_id
           FROM vw_tx_ledger
          WHERE (vw_tx_ledger.tx_type = (-1))) a
  ORDER BY a.date;


ALTER TABLE public.vw_chama_statement OWNER TO postgres;

--
-- Name: vw_contribution_defaults; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_contribution_defaults AS
 SELECT contribution_types.contribution_type_id,
    contribution_types.contribution_type_name,
    entitys.entity_id,
    entitys.entity_name,
    contribution_defaults.org_id,
    contribution_defaults.contribution_default_id,
    contribution_defaults.investment_amount,
    contribution_defaults.merry_go_round_amount,
    contribution_defaults.details
   FROM ((contribution_defaults
     LEFT JOIN contribution_types ON ((contribution_defaults.contribution_type_id = contribution_types.contribution_type_id)))
     JOIN entitys ON ((contribution_defaults.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_contribution_defaults OWNER TO postgres;

--
-- Name: vw_contribution_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_contribution_types AS
 SELECT contribution_types.org_id,
    contribution_types.contribution_type_id,
    contribution_types.contribution_type_name,
    contribution_types.investment_amount,
    contribution_types.merry_go_round_amount,
    contribution_types.frequency,
    contribution_types.applies_to_all,
    contribution_types.details
   FROM contribution_types;


ALTER TABLE public.vw_contribution_types OWNER TO postgres;

--
-- Name: vw_contributions_unpaid; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_contributions_unpaid AS
 SELECT bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    contribution_types.contribution_type_id,
    contribution_types.contribution_type_name,
    entitys.entity_id,
    entitys.entity_name,
    members.member_id,
    members.middle_name,
    contributions.org_id,
    contributions.period_id,
    contributions.contribution_id,
    contributions.contribution_date,
    contributions.investment_amount,
    contributions.merry_go_round_amount,
    contributions.paid,
    contributions.money_in,
    contributions.money_out,
    (contributions.investment_amount + contributions.merry_go_round_amount) AS total_contribution,
    contributions.details
   FROM ((((contributions
     JOIN contribution_types ON ((contributions.contribution_type_id = contribution_types.contribution_type_id)))
     JOIN entitys ON ((contributions.entity_id = entitys.entity_id)))
     JOIN members ON ((contributions.member_id = members.member_id)))
     LEFT JOIN bank_accounts ON ((contributions.bank_account_id = bank_accounts.bank_account_id)))
  WHERE (contributions.paid = false);


ALTER TABLE public.vw_contributions_unpaid OWNER TO postgres;

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
-- Name: vw_day_ledgers; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_day_ledgers AS
 SELECT currency.currency_id,
    currency.currency_name,
    departments.department_id,
    departments.department_name,
    entitys.entity_id,
    entitys.entity_name,
    items.item_id,
    items.item_name,
    orgs.org_id,
    orgs.org_name,
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    vw_bank_accounts.bank_id,
    vw_bank_accounts.bank_name,
    vw_bank_accounts.bank_branch_name,
    vw_bank_accounts.account_id AS gl_bank_account_id,
    vw_bank_accounts.bank_account_id,
    vw_bank_accounts.bank_account_name,
    vw_bank_accounts.bank_account_number,
    stores.store_id,
    stores.store_name,
    day_ledgers.journal_id,
    day_ledgers.day_ledger_id,
    day_ledgers.exchange_rate,
    day_ledgers.day_ledger_date,
    day_ledgers.day_ledger_quantity,
    day_ledgers.day_ledger_amount,
    day_ledgers.day_ledger_tax_amount,
    day_ledgers.document_number,
    day_ledgers.payment_number,
    day_ledgers.order_number,
    day_ledgers.payment_terms,
    day_ledgers.job,
    day_ledgers.application_date,
    day_ledgers.approve_status,
    day_ledgers.workflow_table_id,
    day_ledgers.action_date,
    day_ledgers.narrative,
    day_ledgers.details
   FROM (((((((((day_ledgers
     JOIN currency ON ((day_ledgers.currency_id = currency.currency_id)))
     JOIN departments ON ((day_ledgers.department_id = departments.department_id)))
     JOIN entitys ON ((day_ledgers.entity_id = entitys.entity_id)))
     JOIN items ON ((day_ledgers.item_id = items.item_id)))
     JOIN orgs ON ((day_ledgers.org_id = orgs.org_id)))
     JOIN transaction_status ON ((day_ledgers.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN transaction_types ON ((day_ledgers.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN vw_bank_accounts ON ((day_ledgers.bank_account_id = vw_bank_accounts.bank_account_id)))
     LEFT JOIN stores ON ((day_ledgers.store_id = stores.store_id)));


ALTER TABLE public.vw_day_ledgers OWNER TO postgres;

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
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    default_accounts.default_account_id,
    default_accounts.org_id,
    default_accounts.narrative
   FROM (vw_accounts
     JOIN default_accounts ON ((vw_accounts.account_id = default_accounts.account_id)));


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
    tax_types.use_key,
    tax_types.details
   FROM ((tax_types
     JOIN currency ON ((tax_types.currency_id = currency.currency_id)))
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
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_orgs AS
 SELECT orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.details,
    orgs.cert_number,
    orgs.pin,
    orgs.vat_number,
    orgs.invoice_footer,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.address_id,
    vw_address.table_name,
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
   FROM ((orgs
     JOIN vw_address ON ((orgs.org_id = vw_address.table_id)))
     JOIN currency ON ((orgs.currency_id = currency.currency_id)))
  WHERE ((((vw_address.table_name)::text = 'orgs'::text) AND (vw_address.is_default = true)) AND (orgs.is_active = true));


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
    vw_orgs.sys_country_id AS org_sys_country_id,
    vw_orgs.sys_country_name AS org_sys_country_name,
    vw_orgs.address_id AS org_address_id,
    vw_orgs.table_name AS org_table_name,
    vw_orgs.post_office_box AS org_post_office_box,
    vw_orgs.postal_code AS org_postal_code,
    vw_orgs.premises AS org_premises,
    vw_orgs.street AS org_street,
    vw_orgs.town AS org_town,
    vw_orgs.phone_number AS org_phone_number,
    vw_orgs.extension AS org_extension,
    vw_orgs.mobile AS org_mobile,
    vw_orgs.fax AS org_fax,
    vw_orgs.email AS org_email,
    vw_orgs.website AS org_website,
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
    entitys.entity_id,
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
    entity_types.entity_type_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entity_types.use_key
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
-- Name: vw_expenses; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_expenses AS
 SELECT bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    currency.currency_id,
    currency.currency_name,
    entitys.entity_id,
    entitys.entity_name,
    expenses.org_id,
    expenses.expense_id,
    expenses.date_accrued,
    expenses.amount,
    expenses.details
   FROM (((expenses
     JOIN bank_accounts ON ((expenses.bank_account_id = bank_accounts.bank_account_id)))
     JOIN currency ON ((expenses.currency_id = currency.currency_id)))
     JOIN entitys ON ((expenses.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_expenses OWNER TO postgres;

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
 SELECT vw_periods.period_id,
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
     JOIN departments ON ((journals.department_id = departments.department_id)));


ALTER TABLE public.vw_journals OWNER TO postgres;

--
-- Name: vw_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_gls AS
 SELECT vw_accounts.accounts_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.accounts_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
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
-- Name: vw_investment_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_investment_types AS
 SELECT orgs.org_id,
    orgs.org_name,
    investment_types.investment_type_id,
    investment_types.investment_type_name,
    investment_types.details
   FROM (investment_types
     JOIN orgs ON ((investment_types.org_id = orgs.org_id)));


ALTER TABLE public.vw_investment_types OWNER TO postgres;

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
-- Name: vw_kins; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_kins AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    kin_types.kin_type_id,
    kin_types.kin_type_name,
    kins.org_id,
    kins.kin_id,
    kins.full_names,
    kins.date_of_birth,
    kins.identification,
    kins.relation,
    kins.emergency_contact,
    kins.beneficiary,
    kins.beneficiary_ps,
    kins.details
   FROM ((kins
     JOIN entitys ON ((kins.entity_id = entitys.entity_id)))
     JOIN kin_types ON ((kins.kin_type_id = kin_types.kin_type_id)));


ALTER TABLE public.vw_kins OWNER TO postgres;

--
-- Name: vw_sm_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sm_gls AS
 SELECT vw_gls.org_id,
    vw_gls.accounts_class_id,
    vw_gls.chat_type_id,
    vw_gls.chat_type_name,
    vw_gls.accounts_class_name,
    vw_gls.account_type_id,
    vw_gls.account_type_name,
    vw_gls.account_id,
    vw_gls.account_name,
    vw_gls.is_header,
    vw_gls.is_active,
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
  GROUP BY vw_gls.org_id, vw_gls.accounts_class_id, vw_gls.chat_type_id, vw_gls.chat_type_name, vw_gls.accounts_class_name, vw_gls.account_type_id, vw_gls.account_type_name, vw_gls.account_id, vw_gls.account_name, vw_gls.is_header, vw_gls.is_active, vw_gls.period_id, vw_gls.start_date, vw_gls.end_date, vw_gls.opened, vw_gls.closed, vw_gls.month_id, vw_gls.period_year, vw_gls.period_month, vw_gls.quarter, vw_gls.semister
  ORDER BY vw_gls.account_id;


ALTER TABLE public.vw_sm_gls OWNER TO postgres;

--
-- Name: vw_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ledger AS
 SELECT vw_sm_gls.org_id,
    vw_sm_gls.accounts_class_id,
    vw_sm_gls.chat_type_id,
    vw_sm_gls.chat_type_name,
    vw_sm_gls.accounts_class_name,
    vw_sm_gls.account_type_id,
    vw_sm_gls.account_type_name,
    vw_sm_gls.account_id,
    vw_sm_gls.account_name,
    vw_sm_gls.is_header,
    vw_sm_gls.is_active,
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
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    ledger_types.org_id,
    ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.details
   FROM (ledger_types
     JOIN vw_accounts ON ((vw_accounts.account_id = ledger_types.account_id)));


ALTER TABLE public.vw_ledger_types OWNER TO postgres;

--
-- Name: vw_loan_payments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_payments AS
 SELECT vw_loans.currency_id,
    vw_loans.currency_name,
    vw_loans.currency_symbol,
    vw_loans.loan_type_id,
    vw_loans.loan_type_name,
    vw_loans.entity_id,
    vw_loans.entity_name,
    vw_loans.loan_date,
    vw_loans.loan_id,
    vw_loans.principle,
    vw_loans.interest,
    vw_loans.monthly_repayment,
    vw_loans.reducing_balance,
    vw_loans.repayment_period,
    vw_loans.application_date,
    vw_loans.approve_status,
    vw_loans.initial_payment,
    vw_loans.org_id,
    vw_loans.action_date,
    generate_series(1, vw_loans.repayment_period) AS months,
    get_loan_period(vw_loans.principle, vw_loans.interest, generate_series(1, vw_loans.repayment_period), vw_loans.repayment_amount) AS loan_balance,
    (get_loan_period(vw_loans.principle, vw_loans.interest, (generate_series(1, vw_loans.repayment_period) - 1), vw_loans.repayment_amount) * (vw_loans.interest / (1200)::double precision)) AS loan_intrest
   FROM vw_loans;


ALTER TABLE public.vw_loan_payments OWNER TO postgres;

--
-- Name: vw_loan_projection; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_projection AS
 SELECT vw_loans.org_id,
    vw_loans.loan_id,
    vw_loans.loan_type_name,
    vw_loans.entity_name,
    vw_loans.principle,
    vw_loans.monthly_repayment,
    vw_loans.loan_date,
    ((date_part('year'::text, age((('now'::text)::date)::timestamp with time zone, '2010-05-01 00:00:00+03'::timestamp with time zone)) * (12)::double precision) + date_part('month'::text, age((('now'::text)::date)::timestamp with time zone, (vw_loans.loan_date)::timestamp with time zone))) AS loan_months,
    get_total_repayment(vw_loans.loan_id, (((date_part('year'::text, age((('now'::text)::date)::timestamp with time zone, '2010-05-01 00:00:00+03'::timestamp with time zone)) * (12)::double precision) + date_part('month'::text, age((('now'::text)::date)::timestamp with time zone, (vw_loans.loan_date)::timestamp with time zone))))::integer) AS loan_paid
   FROM vw_loans;


ALTER TABLE public.vw_loan_projection OWNER TO postgres;

--
-- Name: vw_meetings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_meetings AS
 SELECT meetings.org_id,
    meetings.meeting_id,
    meetings.meeting_date,
    meetings.meeting_place,
    meetings.minutes,
    meetings.status,
    meetings.details
   FROM meetings;


ALTER TABLE public.vw_meetings OWNER TO postgres;

--
-- Name: vw_members; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_members AS
 SELECT bank_branch.bank_branch_id,
    bank_branch.bank_branch_name,
    banks.bank_id,
    banks.bank_name,
    currency.currency_id,
    currency.currency_name,
    entitys.entity_id,
    entitys.entity_name,
    locations.location_id,
    locations.location_name,
    sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    members.org_id,
    members.member_id,
    members.person_title,
    members.surname,
    members.first_name,
    members.middle_name,
    members.full_name,
    members.id_number,
    members.email,
    members.date_of_birth,
    members.gender,
    members.phone,
    members.bank_account_number,
    members.nationality,
    members.nation_of_birth,
    members.marital_status,
    members.joining_date,
    members.exit_date,
    members.picture_file,
    members.active,
    members.details,
    members.merry_go_round_number
   FROM ((((((members
     JOIN bank_branch ON ((members.bank_branch_id = bank_branch.bank_branch_id)))
     JOIN banks ON ((members.bank_id = banks.bank_id)))
     JOIN currency ON ((members.currency_id = currency.currency_id)))
     JOIN entitys ON ((members.entity_id = entitys.entity_id)))
     JOIN locations ON ((members.location_id = locations.location_id)))
     JOIN sys_countrys ON ((members.nationality = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_members OWNER TO postgres;

--
-- Name: vw_member_contrib; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_member_contrib AS
 SELECT vw_contributions.bank_account_id,
    vw_contributions.bank_account_name,
    vw_contributions.contribution_type_id,
    vw_contributions.contribution_type_name,
    vw_members.entity_id,
    vw_members.entity_name,
    vw_members.member_id,
    vw_members.merry_go_round_number,
    vw_contributions.org_id,
    vw_contributions.period_id,
    vw_contributions.contribution_id,
    vw_contributions.contribution_date,
    vw_contributions.investment_amount,
    vw_contributions.merry_go_round_amount,
    vw_contributions.paid,
    vw_contributions.money_in,
    vw_contributions.money_out
   FROM (vw_contributions
     JOIN vw_members ON ((vw_contributions.entity_id = vw_members.entity_id)));


ALTER TABLE public.vw_member_contrib OWNER TO postgres;

--
-- Name: vw_member_meeting; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_member_meeting AS
 SELECT members.member_id,
    members.surname,
    members.first_name,
    meetings.meeting_id,
    meetings.meeting_date,
    member_meeting.org_id,
    member_meeting.member_meeting_id,
    member_meeting.narrative
   FROM ((member_meeting
     JOIN members ON ((member_meeting.member_id = members.member_id)))
     JOIN meetings ON ((member_meeting.meeting_id = meetings.meeting_id)));


ALTER TABLE public.vw_member_meeting OWNER TO postgres;

--
-- Name: vw_member_statement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_member_statement AS
 SELECT a.entity_id,
    a.entity_name,
    a.contribution_date,
    a.contribution,
    a.drawings,
    a.loan,
    a.repayments,
    a.penalty
   FROM ( SELECT vw_contributions.entity_id,
            vw_contributions.entity_name,
            vw_contributions.contribution_date,
            (vw_contributions.investment_amount + vw_contributions.merry_go_round_amount) AS contribution,
            (0)::real AS drawings,
            (0)::real AS loan,
            (0)::real AS repayments,
            (0)::real AS penalty
           FROM vw_contributions
          WHERE (vw_contributions.paid = true)
        UNION
         SELECT vw_drawings.entity_id,
            vw_drawings.entity_name,
            vw_drawings.withdrawal_date,
            (0)::real AS float4,
            vw_drawings.amount,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4
           FROM vw_drawings
        UNION
         SELECT vw_loans.entity_id,
            vw_loans.entity_name,
            vw_loans.application_date,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loans.principle,
            (0)::real AS float4,
            (0)::real AS float4
           FROM vw_loans
        UNION
         SELECT vw_loan_monthly.entity_id,
            vw_loan_monthly.entity_name,
            vw_loan_monthly.start_date,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_loan_monthly.total_repayment,
            (0)::real AS float4
           FROM vw_loan_monthly
        UNION
         SELECT vw_penalty.entity_id,
            vw_penalty.entity_name,
            vw_penalty.date_of_accrual,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            (0)::real AS float4,
            vw_penalty.amount
           FROM vw_penalty) a
  ORDER BY a.contribution_date;


ALTER TABLE public.vw_member_statement OWNER TO postgres;

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
-- Name: vw_penalty_type; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_penalty_type AS
 SELECT orgs.org_id,
    orgs.org_name,
    penalty_type.penalty_type_id,
    penalty_type.penalty_type_name,
    penalty_type.details
   FROM (penalty_type
     JOIN orgs ON ((penalty_type.org_id = orgs.org_id)));


ALTER TABLE public.vw_penalty_type OWNER TO postgres;

--
-- Name: vw_period_borrowing; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_borrowing AS
 SELECT vw_borrowing_mrepayment.org_id,
    vw_borrowing_mrepayment.period_id,
    sum(vw_borrowing_mrepayment.interest_amount) AS sum_interest_amount,
    sum(vw_borrowing_mrepayment.repayment) AS sum_repayment,
    sum(vw_borrowing_mrepayment.penalty_paid) AS sum_penalty_paid,
    sum(vw_borrowing_mrepayment.interest_paid) AS sum_interest_paid,
    sum(vw_borrowing_mrepayment.borrowing_balance) AS sum_borrowing_balance
   FROM vw_borrowing_mrepayment
  GROUP BY vw_borrowing_mrepayment.org_id, vw_borrowing_mrepayment.period_id;


ALTER TABLE public.vw_period_borrowing OWNER TO postgres;

--
-- Name: vw_period_loans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_loans AS
 SELECT vw_loan_monthly.org_id,
    vw_loan_monthly.period_id,
    sum(vw_loan_monthly.interest_amount) AS sum_interest_amount,
    sum(vw_loan_monthly.repayment) AS sum_repayment,
    sum(vw_loan_monthly.penalty_paid) AS sum_penalty_paid,
    sum(vw_loan_monthly.interest_paid) AS sum_interest_paid,
    sum(vw_loan_monthly.loan_balance) AS sum_loan_balance
   FROM vw_loan_monthly
  GROUP BY vw_loan_monthly.org_id, vw_loan_monthly.period_id;


ALTER TABLE public.vw_period_loans OWNER TO postgres;

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
    period_tax_types.period_tax_type_name,
    tax_types.use_key,
    period_tax_types.org_id,
    period_tax_types.pay_date,
    period_tax_types.tax_relief,
    period_tax_types.linear,
    period_tax_types.percentage,
    period_tax_types.formural,
    period_tax_types.details
   FROM ((period_tax_types
     JOIN vw_periods ON ((period_tax_types.period_id = vw_periods.period_id)))
     JOIN tax_types ON ((period_tax_types.tax_type_id = tax_types.tax_type_id)));


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
-- Name: vw_productions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_productions AS
 SELECT orgs.org_id,
    orgs.org_name,
    products.product_id,
    products.product_name,
    products.transaction_limit,
    subscriptions.subscription_id,
    subscriptions.chama_name,
    productions.production_id,
    productions.approve_status,
    productions.workflow_table_id,
    productions.application_date,
    productions.action_date,
    productions.montly_billing,
    productions.is_active,
    productions.details
   FROM (((productions
     JOIN orgs ON ((productions.org_id = orgs.org_id)))
     JOIN products ON ((productions.product_id = products.product_id)))
     JOIN subscriptions ON ((productions.subscription_id = subscriptions.subscription_id)));


ALTER TABLE public.vw_productions OWNER TO postgres;

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
    subscriptions.chama_name,
    subscriptions.chama_address,
    subscriptions.city,
    subscriptions.state,
    subscriptions.country_id,
    subscriptions.number_of_members,
    subscriptions.telephone,
    subscriptions.website,
    subscriptions.primary_contact,
    subscriptions.job_title,
    subscriptions.primary_email,
    subscriptions.approve_status,
    subscriptions.workflow_table_id,
    subscriptions.application_date,
    subscriptions.action_date,
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
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    transactions.journal_id,
    transactions.transaction_id,
    transactions.org_id,
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
            WHEN (((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN (((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS credit_amount
   FROM ((((((transactions
     JOIN transaction_types ON ((transactions.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN transaction_status ON ((transactions.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     LEFT JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
     LEFT JOIN vw_bank_accounts ON ((vw_bank_accounts.bank_account_id = transactions.bank_account_id)))
     LEFT JOIN departments ON ((transactions.department_id = departments.department_id)));


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
    vw_orgs.sys_country_id AS org_sys_country_id,
    vw_orgs.sys_country_name AS org_sys_country_name,
    vw_orgs.address_id AS org_address_id,
    vw_orgs.table_name AS org_table_name,
    vw_orgs.post_office_box AS org_post_office_box,
    vw_orgs.postal_code AS org_postal_code,
    vw_orgs.premises AS org_premises,
    vw_orgs.street AS org_street,
    vw_orgs.town AS org_town,
    vw_orgs.phone_number AS org_phone_number,
    vw_orgs.extension AS org_extension,
    vw_orgs.mobile AS org_mobile,
    vw_orgs.fax AS org_fax,
    vw_orgs.email AS org_email,
    vw_orgs.website AS org_website,
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
    vw_entitys.use_key,
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
            WHEN (((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN (((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) THEN transactions.transaction_amount
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
-- Name: borrowing_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing ALTER COLUMN borrowing_id SET DEFAULT nextval('borrowing_borrowing_id_seq'::regclass);


--
-- Name: borrowing_repayment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_repayment ALTER COLUMN borrowing_repayment_id SET DEFAULT nextval('borrowing_repayment_borrowing_repayment_id_seq'::regclass);


--
-- Name: borrowing_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_types ALTER COLUMN borrowing_type_id SET DEFAULT nextval('borrowing_types_borrowing_type_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: contribution_default_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_defaults ALTER COLUMN contribution_default_id SET DEFAULT nextval('contribution_defaults_contribution_default_id_seq'::regclass);


--
-- Name: contribution_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_types ALTER COLUMN contribution_type_id SET DEFAULT nextval('contribution_types_contribution_type_id_seq'::regclass);


--
-- Name: contribution_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions ALTER COLUMN contribution_id SET DEFAULT nextval('contributions_contribution_id_seq'::regclass);


--
-- Name: currency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency ALTER COLUMN currency_id SET DEFAULT nextval('currency_currency_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: day_ledger_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers ALTER COLUMN day_ledger_id SET DEFAULT nextval('day_ledgers_day_ledger_id_seq'::regclass);


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
-- Name: drawing_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY drawings ALTER COLUMN drawing_id SET DEFAULT nextval('drawings_drawing_id_seq'::regclass);


--
-- Name: entity_subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions ALTER COLUMN entity_subscription_id SET DEFAULT nextval('entity_subscriptions_entity_subscription_id_seq'::regclass);


--
-- Name: entity_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types ALTER COLUMN entity_type_id SET DEFAULT nextval('entity_types_entity_type_id_seq'::regclass);


--
-- Name: entity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys ALTER COLUMN entity_id SET DEFAULT nextval('entitys_entity_id_seq'::regclass);


--
-- Name: entry_form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms ALTER COLUMN entry_form_id SET DEFAULT nextval('entry_forms_entry_form_id_seq'::regclass);


--
-- Name: expense_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY expenses ALTER COLUMN expense_id SET DEFAULT nextval('expenses_expense_id_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: gl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls ALTER COLUMN gl_id SET DEFAULT nextval('gls_gl_id_seq'::regclass);


--
-- Name: holiday_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays ALTER COLUMN holiday_id SET DEFAULT nextval('holidays_holiday_id_seq'::regclass);


--
-- Name: investment_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investment_types ALTER COLUMN investment_type_id SET DEFAULT nextval('investment_types_investment_type_id_seq'::regclass);


--
-- Name: investment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investments ALTER COLUMN investment_id SET DEFAULT nextval('investments_investment_id_seq'::regclass);


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
-- Name: kin_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kin_types ALTER COLUMN kin_type_id SET DEFAULT nextval('kin_types_kin_type_id_seq'::regclass);


--
-- Name: kin_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kins ALTER COLUMN kin_id SET DEFAULT nextval('kins_kin_id_seq'::regclass);


--
-- Name: ledger_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types ALTER COLUMN ledger_type_id SET DEFAULT nextval('ledger_types_ledger_type_id_seq'::regclass);


--
-- Name: loan_month_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_monthly ALTER COLUMN loan_month_id SET DEFAULT nextval('loan_monthly_loan_month_id_seq'::regclass);


--
-- Name: loan_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_types ALTER COLUMN loan_type_id SET DEFAULT nextval('loan_types_loan_type_id_seq'::regclass);


--
-- Name: loan_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans ALTER COLUMN loan_id SET DEFAULT nextval('loans_loan_id_seq'::regclass);


--
-- Name: location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations ALTER COLUMN location_id SET DEFAULT nextval('locations_location_id_seq'::regclass);


--
-- Name: meeting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY meetings ALTER COLUMN meeting_id SET DEFAULT nextval('meetings_meeting_id_seq'::regclass);


--
-- Name: member_meeting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY member_meeting ALTER COLUMN member_meeting_id SET DEFAULT nextval('member_meeting_member_meeting_id_seq'::regclass);


--
-- Name: member_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members ALTER COLUMN member_id SET DEFAULT nextval('members_member_id_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: penalty_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty ALTER COLUMN penalty_id SET DEFAULT nextval('penalty_penalty_id_seq'::regclass);


--
-- Name: penalty_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty_type ALTER COLUMN penalty_type_id SET DEFAULT nextval('penalty_type_penalty_type_id_seq'::regclass);


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
-- Name: production_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY productions ALTER COLUMN production_id SET DEFAULT nextval('productions_production_id_seq'::regclass);


--
-- Name: product_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products ALTER COLUMN product_id SET DEFAULT nextval('products_product_id_seq'::regclass);


--
-- Name: quotation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations ALTER COLUMN quotation_id SET DEFAULT nextval('quotations_quotation_id_seq'::regclass);


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
-- Name: tx_ledger_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger ALTER COLUMN tx_ledger_id SET DEFAULT nextval('tx_ledger_tx_ledger_id_seq'::regclass);


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

INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (100, 100, 0, 10, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (110, 110, 0, 10, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (200, 200, 0, 20, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (210, 210, 0, 20, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (300, 300, 0, 30, 'DEBTORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (310, 310, 0, 30, 'INVESTMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (320, 320, 0, 30, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (330, 330, 0, 30, 'CASH ON HAND', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (340, 340, 0, 30, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (400, 400, 0, 40, 'CREDITORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (410, 410, 0, 40, 'ADVANCED BILLING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (420, 420, 0, 40, 'VAT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (430, 430, 0, 40, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (500, 500, 0, 50, 'LOANS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (600, 600, 0, 60, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (610, 610, 0, 60, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (700, 700, 0, 70, 'SALES REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (710, 710, 0, 70, 'OTHER INCOME', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (800, 800, 0, 80, 'COST OF REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (900, 900, 0, 90, 'STAFF COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (905, 905, 0, 90, 'COMMUNICATIONS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (910, 910, 0, 90, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (915, 915, 0, 90, 'TRANSPORT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (920, 920, 0, 90, 'TRAVEL', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (925, 925, 0, 90, 'POSTAL and COURIER', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (930, 930, 0, 90, 'ICT PROJECT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (935, 935, 0, 90, 'STATIONERY', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (940, 940, 0, 90, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (945, 945, 0, 90, 'REPAIRS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (950, 950, 0, 90, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (955, 955, 0, 90, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (960, 960, 0, 90, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (965, 965, 0, 90, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (970, 970, 0, 90, 'DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (975, 975, 0, 90, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (980, 980, 0, 90, 'FINANCE COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (985, 985, 0, 90, 'TAXES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (990, 990, 0, 90, 'INSURANCE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (995, 995, 0, 90, 'OTHER EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1000, 110, 1, 108, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1001, 100, 1, 108, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1002, 210, 1, 107, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1003, 200, 1, 107, 'COST', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1004, 340, 1, 106, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1005, 330, 1, 106, 'CASH ON HAND', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1006, 320, 1, 106, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1007, 310, 1, 106, 'INVESTMENTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1008, 300, 1, 106, 'DEBTORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1009, 430, 1, 105, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1010, 420, 1, 105, 'VAT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1011, 410, 1, 105, 'ADVANCED BILLING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1012, 400, 1, 105, 'CREDITORS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1013, 500, 1, 104, 'LOANS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1014, 610, 1, 103, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1015, 600, 1, 103, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1016, 710, 1, 102, 'OTHER INCOME', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1017, 700, 1, 102, 'SALES REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1018, 800, 1, 101, 'COST OF REVENUE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1019, 995, 1, 100, 'OTHER EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1020, 990, 1, 100, 'INSURANCE', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1021, 985, 1, 100, 'TAXES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1022, 980, 1, 100, 'FINANCE COSTS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1023, 975, 1, 100, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1024, 970, 1, 100, 'DEPRECIATION', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1025, 965, 1, 100, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1026, 960, 1, 100, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1027, 955, 1, 100, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1028, 950, 1, 100, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1029, 945, 1, 100, 'REPAIRS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1030, 940, 1, 100, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1031, 935, 1, 100, 'STATIONERY', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1032, 930, 1, 100, 'ICT PROJECT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1033, 925, 1, 100, 'POSTAL and COURIER', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1034, 920, 1, 100, 'TRAVEL', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1035, 915, 1, 100, 'TRANSPORT', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1036, 910, 1, 100, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1037, 905, 1, 100, 'COMMUNICATIONS', NULL);
INSERT INTO account_types (account_type_id, account_type_no, org_id, accounts_class_id, account_type_name, details) VALUES (1038, 900, 1, 100, 'STAFF COSTS', NULL);


--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_types_account_type_id_seq', 1038, true);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (10000, 10000, 0, 100, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (10005, 10005, 0, 100, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (11000, 11000, 0, 110, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (11005, 11005, 0, 110, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (20000, 20000, 0, 200, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (20005, 20005, 0, 200, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (20010, 20010, 0, 200, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (21000, 21000, 0, 210, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30000, 30000, 0, 300, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30005, 30005, 0, 300, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30010, 30010, 0, 300, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30015, 30015, 0, 300, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30020, 30020, 0, 300, 'INVENTORY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30025, 30025, 0, 300, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (30030, 30030, 0, 300, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (31005, 31005, 0, 310, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (32000, 32000, 0, 320, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (32005, 32005, 0, 320, 'MPESA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (33000, 33000, 0, 330, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (33005, 33005, 0, 330, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (34000, 34000, 0, 340, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (34005, 34005, 0, 340, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (34010, 34010, 0, 340, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (34015, 34015, 0, 340, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40000, 40000, 0, 400, 'CREDITORS- ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40005, 40005, 0, 400, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40010, 40010, 0, 400, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40015, 40015, 0, 400, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40020, 40020, 0, 400, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40025, 40025, 0, 400, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40030, 40030, 0, 400, 'NSSF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40035, 40035, 0, 400, 'NHIF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40040, 40040, 0, 400, 'HELB', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40045, 40045, 0, 400, 'PAYE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (40050, 40050, 0, 400, 'PENSION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (41000, 41000, 0, 410, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (42000, 42000, 0, 420, 'INPUT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (42005, 42005, 0, 420, 'OUTPUT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (42010, 42010, 0, 420, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (43000, 43000, 0, 430, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (50000, 50000, 0, 500, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (60000, 60000, 0, 600, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (60005, 60005, 0, 600, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (60010, 60010, 0, 600, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (61000, 61000, 0, 610, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (61005, 61005, 0, 610, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (61010, 61010, 0, 610, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (70005, 70005, 0, 700, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (70010, 70010, 0, 700, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (70015, 70015, 0, 700, 'SALES DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71000, 71000, 0, 710, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71005, 71005, 0, 710, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71010, 71010, 0, 710, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71015, 71015, 0, 710, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71020, 71020, 0, 710, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71025, 71025, 0, 710, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71030, 71030, 0, 710, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (71035, 71035, 0, 710, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (80000, 80000, 0, 800, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90000, 90000, 0, 900, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90005, 90005, 0, 900, 'LEAVE ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90010, 90010, 0, 900, 'AIRTIME ', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90012, 90012, 0, 900, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90015, 90015, 0, 900, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90020, 90020, 0, 900, 'ICEA EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90025, 90025, 0, 900, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90035, 90035, 0, 900, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90040, 90040, 0, 900, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90045, 90045, 0, 900, 'BONUSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90050, 90050, 0, 900, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90055, 90055, 0, 900, 'WELFARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90056, 90056, 0, 900, 'STAFF WELLFARE: WATER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90057, 90057, 0, 900, 'STAFF WELLFARE: TEA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90058, 90058, 0, 900, 'STAFF WELLFARE: OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90060, 90060, 0, 900, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90065, 90065, 0, 900, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90070, 90070, 0, 900, 'STAFF SATISFACTION SURVEY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90075, 90075, 0, 900, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90500, 90500, 0, 905, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90505, 90505, 0, 905, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90510, 90510, 0, 905, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90515, 90515, 0, 905, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (90520, 90520, 0, 905, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91000, 91000, 0, 910, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91005, 91005, 0, 910, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91010, 91010, 0, 910, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91500, 91500, 0, 915, 'CAB FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91505, 91505, 0, 915, 'FUEL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91510, 91510, 0, 915, 'BUS FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (91515, 91515, 0, 915, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (92000, 92000, 0, 920, 'TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (92005, 92005, 0, 920, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (92505, 92505, 0, 925, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (92510, 92510, 0, 925, 'COURIER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93000, 93000, 0, 930, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93010, 93010, 0, 930, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93500, 93500, 0, 935, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93505, 93505, 0, 935, 'PAPER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93510, 93510, 0, 935, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93515, 93515, 0, 935, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (93520, 93520, 0, 935, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (94010, 94010, 0, 940, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (94015, 94015, 0, 940, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (94500, 94500, 0, 945, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (94505, 94505, 0, 945, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (94510, 94510, 0, 945, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95000, 95000, 0, 950, 'AUDIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95005, 95005, 0, 950, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95010, 95010, 0, 950, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95015, 95015, 0, 950, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95020, 95020, 0, 950, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95025, 95025, 0, 950, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95030, 95030, 0, 950, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95035, 95035, 0, 950, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95040, 95040, 0, 950, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95045, 95045, 0, 950, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95500, 95500, 0, 955, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95502, 95502, 0, 955, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95505, 95505, 0, 955, 'CLEANING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95510, 95510, 0, 955, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95515, 95515, 0, 955, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (95520, 95520, 0, 955, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (96005, 96005, 0, 960, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (96505, 96505, 0, 965, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (96510, 96510, 0, 965, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (97000, 97000, 0, 970, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (97005, 97005, 0, 970, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (97010, 97010, 0, 970, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (97500, 97500, 0, 975, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (97505, 97505, 0, 975, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98000, 98000, 0, 980, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98005, 98005, 0, 980, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98010, 98010, 0, 980, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98015, 98015, 0, 980, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98020, 98020, 0, 980, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98025, 98025, 0, 980, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98030, 98030, 0, 980, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98035, 98035, 0, 980, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98040, 98040, 0, 980, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98500, 98500, 0, 985, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98505, 98505, 0, 985, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98510, 98510, 0, 985, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (98515, 98515, 0, 985, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99000, 99000, 0, 990, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99005, 99005, 0, 990, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99010, 99010, 0, 990, 'BURGLARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99015, 99015, 0, 990, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99500, 99500, 0, 995, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99505, 99505, 0, 995, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99510, 99510, 0, 995, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99515, 99515, 0, 995, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (99999, 99999, 0, 995, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100000, 90075, 1, 1038, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100001, 90070, 1, 1038, 'STAFF SATISFACTION SURVEY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100002, 90065, 1, 1038, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100003, 90060, 1, 1038, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100004, 90058, 1, 1038, 'STAFF WELLFARE: OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100005, 90057, 1, 1038, 'STAFF WELLFARE: TEA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100006, 90056, 1, 1038, 'STAFF WELLFARE: WATER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100007, 90055, 1, 1038, 'WELFARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100008, 90050, 1, 1038, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100009, 90045, 1, 1038, 'BONUSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100010, 90040, 1, 1038, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100011, 90035, 1, 1038, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100012, 90025, 1, 1038, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100013, 90020, 1, 1038, 'ICEA EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100014, 90015, 1, 1038, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100015, 90012, 1, 1038, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100016, 90010, 1, 1038, 'AIRTIME ', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100017, 90005, 1, 1038, 'LEAVE ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100018, 90000, 1, 1038, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100019, 90520, 1, 1037, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100020, 90515, 1, 1037, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100021, 90510, 1, 1037, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100022, 90505, 1, 1037, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100023, 90500, 1, 1037, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100024, 91010, 1, 1036, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100025, 91005, 1, 1036, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100026, 91000, 1, 1036, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100027, 91515, 1, 1035, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100028, 91510, 1, 1035, 'BUS FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100029, 91505, 1, 1035, 'FUEL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100030, 91500, 1, 1035, 'CAB FARE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100031, 92005, 1, 1034, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100032, 92000, 1, 1034, 'TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100033, 92510, 1, 1033, 'COURIER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100034, 92505, 1, 1033, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100035, 93010, 1, 1032, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100036, 93000, 1, 1032, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100037, 93520, 1, 1031, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100038, 93515, 1, 1031, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100039, 93510, 1, 1031, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100040, 93505, 1, 1031, 'PAPER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100041, 93500, 1, 1031, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100042, 94015, 1, 1030, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100043, 94010, 1, 1030, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100044, 94510, 1, 1029, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100045, 94505, 1, 1029, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100046, 94500, 1, 1029, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100047, 95045, 1, 1028, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100048, 95040, 1, 1028, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100049, 95035, 1, 1028, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100050, 95030, 1, 1028, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100051, 95025, 1, 1028, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100052, 95020, 1, 1028, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100053, 95015, 1, 1028, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100054, 95010, 1, 1028, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100055, 95005, 1, 1028, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100056, 95000, 1, 1028, 'AUDIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100057, 95520, 1, 1027, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100058, 95515, 1, 1027, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100059, 95510, 1, 1027, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100060, 95505, 1, 1027, 'CLEANING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100061, 95502, 1, 1027, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100062, 95500, 1, 1027, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100063, 96005, 1, 1026, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100064, 96510, 1, 1025, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100065, 96505, 1, 1025, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100066, 97010, 1, 1024, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100067, 97005, 1, 1024, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100068, 97000, 1, 1024, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100069, 97505, 1, 1023, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100070, 97500, 1, 1023, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100071, 98040, 1, 1022, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100072, 98035, 1, 1022, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100073, 98030, 1, 1022, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100074, 98025, 1, 1022, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100075, 98020, 1, 1022, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100076, 98015, 1, 1022, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100077, 98010, 1, 1022, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100078, 98005, 1, 1022, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100079, 98000, 1, 1022, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100080, 98515, 1, 1021, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100081, 98510, 1, 1021, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100082, 98505, 1, 1021, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100083, 98500, 1, 1021, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100084, 99015, 1, 1020, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100085, 99010, 1, 1020, 'BURGLARY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100086, 99005, 1, 1020, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100087, 99000, 1, 1020, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100088, 99999, 1, 1019, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100089, 99515, 1, 1019, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100090, 99510, 1, 1019, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100091, 99505, 1, 1019, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100092, 99500, 1, 1019, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100093, 80000, 1, 1018, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100094, 70015, 1, 1017, 'SALES DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100095, 70010, 1, 1017, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100096, 70005, 1, 1017, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100097, 71035, 1, 1016, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100098, 71030, 1, 1016, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100099, 71025, 1, 1016, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100100, 71020, 1, 1016, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100101, 71015, 1, 1016, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100102, 71010, 1, 1016, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100103, 71005, 1, 1016, 'DONATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100104, 71000, 1, 1016, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100105, 60010, 1, 1015, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100106, 60005, 1, 1015, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100107, 60000, 1, 1015, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100108, 61010, 1, 1014, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100109, 61005, 1, 1014, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100110, 61000, 1, 1014, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100111, 50000, 1, 1013, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100112, 40050, 1, 1012, 'PENSION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100113, 40045, 1, 1012, 'PAYE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100114, 40040, 1, 1012, 'HELB', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100115, 40035, 1, 1012, 'NHIF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100116, 40030, 1, 1012, 'NSSF', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100117, 40025, 1, 1012, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100118, 40020, 1, 1012, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100119, 40015, 1, 1012, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100120, 40010, 1, 1012, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100121, 40005, 1, 1012, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100122, 40000, 1, 1012, 'CREDITORS- ACCRUALS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100123, 41000, 1, 1011, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100124, 42010, 1, 1010, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100125, 42005, 1, 1010, 'OUTPUT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100126, 42000, 1, 1010, 'INPUT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100127, 43000, 1, 1009, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100128, 30030, 1, 1008, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100129, 30025, 1, 1008, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100130, 30020, 1, 1008, 'INVENTORY', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100131, 30015, 1, 1008, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100132, 30010, 1, 1008, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100133, 30005, 1, 1008, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100134, 30000, 1, 1008, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100135, 31005, 1, 1007, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100136, 32005, 1, 1006, 'MPESA', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100137, 32000, 1, 1006, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100138, 33005, 1, 1005, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100139, 33000, 1, 1005, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100140, 34015, 1, 1004, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100141, 34010, 1, 1004, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100142, 34005, 1, 1004, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100143, 34000, 1, 1004, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100144, 20010, 1, 1003, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100145, 20005, 1, 1003, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100146, 20000, 1, 1003, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100147, 21000, 1, 1002, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100148, 10005, 1, 1001, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100149, 10000, 1, 1001, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100150, 11005, 1, 1000, 'FURNITURE', false, true, NULL);
INSERT INTO accounts (account_id, account_no, org_id, account_type_id, account_name, is_header, is_active, details) VALUES (100151, 11000, 1, 1000, 'COMPUTERS and EQUIPMENT', false, true, NULL);


--
-- Name: accounts_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('accounts_account_id_seq', 100151, true);


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
-- Data for Name: applicants; Type: TABLE DATA; Schema: public; Owner: postgres
--



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
-- Data for Name: borrowing; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: borrowing_borrowing_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('borrowing_borrowing_id_seq', 1, false);


--
-- Data for Name: borrowing_repayment; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: borrowing_repayment_borrowing_repayment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('borrowing_repayment_borrowing_repayment_id_seq', 1, false);


--
-- Data for Name: borrowing_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: borrowing_types_borrowing_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('borrowing_types_borrowing_type_id_seq', 1, false);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Data for Name: contribution_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contribution_defaults_contribution_default_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contribution_defaults_contribution_default_id_seq', 1, false);


--
-- Data for Name: contribution_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contribution_types_contribution_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contribution_types_contribution_type_id_seq', 1, false);


--
-- Data for Name: contributions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contributions_contribution_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contributions_contribution_id_seq', 1, false);


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

INSERT INTO currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) VALUES (0, 1, 0, '2016-07-04', 1);
INSERT INTO currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) VALUES (1, 5, 1, '2016-07-06', 1);


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, true);


--
-- Data for Name: day_ledgers; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: day_ledgers_day_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('day_ledgers_day_ledger_id_seq', 1, false);


--
-- Data for Name: default_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO default_accounts (default_account_id, org_id, account_id, use_key, narrative) VALUES (1, 0, 99999, 1, 'SURPLUS/DEFICIT ACCOUNT');
INSERT INTO default_accounts (default_account_id, org_id, account_id, use_key, narrative) VALUES (2, 0, 61000, 2, 'RETAINED EARNINGS ACCOUNT');


--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('default_accounts_default_account_id_seq', 2, true);


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

INSERT INTO departments (department_id, ln_department_id, org_id, department_name, department_account, function_code, active, petty_cash, description, duties, reports, details) VALUES (0, 0, 0, 'Board of Directors', NULL, NULL, true, false, NULL, NULL, NULL, NULL);


--
-- Name: departments_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('departments_department_id_seq', 1, false);


--
-- Data for Name: drawings; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: drawings_drawing_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('drawings_drawing_id_seq', 1, false);


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

INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (0, 0, 'Users', 'user', 0, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (1, 0, 'Staff', 'staff', 1, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (2, 0, 'Client', 'client', 2, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (3, 0, 'Supplier', 'supplier', 3, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (4, 0, 'Applicant', 'applicant', 4, '10:0', NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (5, 0, 'Subscription', 'subscription', 4, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (6, 1, 'Users', 'user', 0, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (7, 1, 'Staff', 'staff', 1, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (8, 1, 'Client', 'client', 2, NULL, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) VALUES (9, 1, 'Supplier', 'supplier', 3, NULL, NULL, NULL, NULL);


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 9, true);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entitys (entity_id, entity_type_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, attention, account_id) VALUES (0, 0, 0, 'root', 'root', 'root@localhost', NULL, true, true, false, NULL, '2016-07-04 16:26:01.939896', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, NULL);
INSERT INTO entitys (entity_id, entity_type_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, attention, account_id) VALUES (1, 0, 0, 'repository', 'repository', 'repository@localhost', NULL, false, true, false, NULL, '2016-07-04 16:26:01.939896', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, NULL);


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
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: expenses_expense_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('expenses_expense_id_seq', 1, false);


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
-- Data for Name: holidays; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('holidays_holiday_id_seq', 1, false);


--
-- Data for Name: investment_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: investment_types_investment_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('investment_types_investment_type_id_seq', 1, false);


--
-- Data for Name: investments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: investments_investment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('investments_investment_id_seq', 1, false);


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
-- Data for Name: kin_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: kin_types_kin_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('kin_types_kin_type_id_seq', 1, false);


--
-- Data for Name: kins; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: kins_kin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('kins_kin_id_seq', 1, false);


--
-- Data for Name: ledger_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ledger_types_ledger_type_id_seq', 1, false);


--
-- Data for Name: loan_monthly; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: loan_monthly_loan_month_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('loan_monthly_loan_month_id_seq', 1, false);


--
-- Data for Name: loan_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: loan_types_loan_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('loan_types_loan_type_id_seq', 1, false);


--
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: loans_loan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('loans_loan_id_seq', 1, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locations_location_id_seq', 1, false);


--
-- Data for Name: meetings; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('meetings_meeting_id_seq', 1, false);


--
-- Data for Name: member_meeting; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: member_meeting_member_meeting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('member_meeting_member_meeting_id_seq', 1, false);


--
-- Data for Name: members; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: members_member_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('members_member_id_seq', 1, false);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details, cert_number, vat_number, fixed_budget, invoice_footer, member_limit, transaction_limit) VALUES (0, 1, NULL, NULL, 'default', 'dc', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 5, 100);
INSERT INTO orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details, cert_number, vat_number, fixed_budget, invoice_footer, member_limit, transaction_limit) VALUES (1, 5, NULL, NULL, 'Default', 'df', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, 5, 100);


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, true);


--
-- Data for Name: penalty; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: penalty_penalty_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('penalty_penalty_id_seq', 1, false);


--
-- Data for Name: penalty_type; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: penalty_type_penalty_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('penalty_type_penalty_type_id_seq', 1, false);


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
-- Data for Name: productions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: productions_production_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('productions_production_id_seq', 1, false);


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO products (product_id, org_id, product_name, is_montly_bill, montly_cost, is_annual_bill, annual_cost, transaction_limit, details) VALUES (1, 0, 'HCM Hosting', false, 0, true, 0, 5, NULL);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('products_product_id_seq', 1, true);


--
-- Data for Name: quotations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('quotations_quotation_id_seq', 1, false);


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



--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 1, false);


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

INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (1, 0, '2016-07-04 17:02:31.173509', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (2, 0, '2016-07-04 17:03:57.270624', 'joto.dewcis.co.ke/127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (3, 0, '2016-07-04 18:43:46.878716', 'joto.dewcis.co.ke/127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (4, 0, '2016-07-04 18:44:18.434979', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (5, 0, '2016-07-05 07:46:29.773421', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (6, 0, '2016-07-05 11:24:15.007168', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (7, 0, '2016-07-05 11:24:19.082256', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (8, 0, '2016-07-05 11:24:19.92738', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (9, 0, '2016-07-05 11:24:21.158146', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (10, 0, '2016-07-05 11:24:21.912495', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (11, 0, '2016-07-05 11:24:22.648023', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (12, 0, '2016-07-05 11:24:23.380435', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (13, 0, '2016-07-05 11:24:25.617994', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (14, 0, '2016-07-05 11:24:26.254035', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (15, 0, '2016-07-05 11:24:27.787082', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (16, 0, '2016-07-05 11:24:28.654857', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (17, 0, '2016-07-05 11:24:29.33919', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (18, 0, '2016-07-05 11:24:30.129345', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (19, 0, '2016-07-05 11:24:30.848039', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (20, 0, '2016-07-05 11:24:31.565962', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (21, 0, '2016-07-05 11:24:32.805882', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (22, 0, '2016-07-05 11:24:33.49296', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (23, 0, '2016-07-05 11:52:06.359366', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (24, 0, '2016-07-05 11:52:59.179116', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (25, 0, '2016-07-05 14:27:32.542529', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (26, 0, '2016-07-06 08:44:03.05701', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (27, 0, '2016-07-06 08:45:30.687013', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (28, 0, '2016-07-06 08:45:40.007333', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (29, 0, '2016-07-06 08:45:40.881166', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (30, 0, '2016-07-06 08:45:44.059627', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (31, 0, '2016-07-06 08:45:44.811337', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (32, 0, '2016-07-06 08:45:49.044571', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (33, 0, '2016-07-06 08:45:53.70105', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (34, 0, '2016-07-06 08:45:54.419366', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (35, 0, '2016-07-06 08:45:57.055426', '127.0.0.1', NULL);


--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 35, true);


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

INSERT INTO tax_types (tax_type_id, account_id, currency_id, org_id, tax_type_name, tax_type_number, formural, tax_relief, tax_type_order, in_tax, tax_rate, tax_inclusive, linear, percentage, employer, employer_ps, account_number, employer_account, active, use_key, use_type, details) VALUES (1, 90000, 1, 0, 'Exempt', NULL, NULL, 0, 0, false, 0, false, true, true, 0, 0, NULL, NULL, true, 0, 0, NULL);
INSERT INTO tax_types (tax_type_id, account_id, currency_id, org_id, tax_type_name, tax_type_number, formural, tax_relief, tax_type_order, in_tax, tax_rate, tax_inclusive, linear, percentage, employer, employer_ps, account_number, employer_account, active, use_key, use_type, details) VALUES (2, 90000, 1, 0, 'VAT', NULL, NULL, 0, 0, false, 16, false, true, true, 0, 0, NULL, NULL, true, 0, 0, NULL);


--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tax_types_tax_type_id_seq', 2, true);


--
-- Data for Name: transaction_counters; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (1, 16, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (2, 14, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (3, 15, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (4, 1, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (5, 2, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (6, 3, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (7, 4, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (8, 5, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (9, 6, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (10, 7, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (11, 8, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (12, 9, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (13, 10, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (14, 11, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (15, 12, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (16, 17, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (17, 21, 0, 1);
INSERT INTO transaction_counters (transaction_counter_id, transaction_type_id, org_id, document_number) VALUES (18, 22, 0, 1);


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
-- Data for Name: tx_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tx_ledger_tx_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tx_ledger_tx_ledger_id_seq', 1, false);


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



--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 1, false);


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



--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflows_workflow_id_seq', 1, false);


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
-- Name: applicants_applicant_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_applicant_email_key UNIQUE (applicant_email);


--
-- Name: applicants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_pkey PRIMARY KEY (entity_id);


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
-- Name: borrowing_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY borrowing
    ADD CONSTRAINT borrowing_pkey PRIMARY KEY (borrowing_id);


--
-- Name: borrowing_repayment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY borrowing_repayment
    ADD CONSTRAINT borrowing_repayment_pkey PRIMARY KEY (borrowing_repayment_id);


--
-- Name: borrowing_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY borrowing_types
    ADD CONSTRAINT borrowing_types_pkey PRIMARY KEY (borrowing_type_id);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: contribution_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contribution_defaults
    ADD CONSTRAINT contribution_defaults_pkey PRIMARY KEY (contribution_default_id);


--
-- Name: contribution_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contribution_types
    ADD CONSTRAINT contribution_types_pkey PRIMARY KEY (contribution_type_id);


--
-- Name: contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_pkey PRIMARY KEY (contribution_id);


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
-- Name: day_ledgers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_pkey PRIMARY KEY (day_ledger_id);


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
-- Name: drawings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY drawings
    ADD CONSTRAINT drawings_pkey PRIMARY KEY (drawing_id);


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
-- Name: expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (expense_id);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


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
-- Name: holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (holiday_id);


--
-- Name: investment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY investment_types
    ADD CONSTRAINT investment_types_pkey PRIMARY KEY (investment_type_id);


--
-- Name: investments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY investments
    ADD CONSTRAINT investments_pkey PRIMARY KEY (investment_id);


--
-- Name: item_category_item_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_item_category_name_key UNIQUE (item_category_name);


--
-- Name: item_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_pkey PRIMARY KEY (item_category_id);


--
-- Name: item_units_item_unit_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_item_unit_name_key UNIQUE (item_unit_name);


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
-- Name: kin_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY kin_types
    ADD CONSTRAINT kin_types_pkey PRIMARY KEY (kin_type_id);


--
-- Name: kins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY kins
    ADD CONSTRAINT kins_pkey PRIMARY KEY (kin_id);


--
-- Name: ledger_types_ledger_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_ledger_type_name_key UNIQUE (ledger_type_name);


--
-- Name: ledger_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_pkey PRIMARY KEY (ledger_type_id);


--
-- Name: loan_monthly_loan_id_period_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loan_monthly
    ADD CONSTRAINT loan_monthly_loan_id_period_id_key UNIQUE (loan_id, period_id);


--
-- Name: loan_monthly_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loan_monthly
    ADD CONSTRAINT loan_monthly_pkey PRIMARY KEY (loan_month_id);


--
-- Name: loan_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loan_types
    ADD CONSTRAINT loan_types_pkey PRIMARY KEY (loan_type_id);


--
-- Name: loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (loan_id);


--
-- Name: locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- Name: meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (meeting_id);


--
-- Name: member_meeting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY member_meeting
    ADD CONSTRAINT member_meeting_pkey PRIMARY KEY (member_meeting_id);


--
-- Name: members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_pkey PRIMARY KEY (member_id);


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
-- Name: penalty_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_pkey PRIMARY KEY (penalty_id);


--
-- Name: penalty_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY penalty_type
    ADD CONSTRAINT penalty_type_pkey PRIMARY KEY (penalty_type_id);


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
-- Name: productions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY productions
    ADD CONSTRAINT productions_pkey PRIMARY KEY (production_id);


--
-- Name: products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: quotations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_pkey PRIMARY KEY (quotation_id);


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
-- Name: tax_types_tax_type_name_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_tax_type_name_org_id_key UNIQUE (tax_type_name, org_id);


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
-- Name: tx_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_pkey PRIMARY KEY (tx_ledger_id);


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
-- Name: applicants_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applicants_org_id ON applicants USING btree (org_id);


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
-- Name: borrowing_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_bank_account_id ON borrowing USING btree (bank_account_id);


--
-- Name: borrowing_borrowing_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_borrowing_type_id ON borrowing USING btree (borrowing_type_id);


--
-- Name: borrowing_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_currency_id ON borrowing USING btree (currency_id);


--
-- Name: borrowing_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_org_id ON borrowing USING btree (org_id);


--
-- Name: borrowing_repayment_borrowing_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_repayment_borrowing_id ON borrowing_repayment USING btree (borrowing_id);


--
-- Name: borrowing_repayment_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_repayment_org_id ON borrowing_repayment USING btree (org_id);


--
-- Name: borrowing_repayment_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_repayment_period_id ON borrowing_repayment USING btree (period_id);


--
-- Name: borrowing_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX borrowing_types_org_id ON borrowing_types USING btree (org_id);


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
-- Name: contribution_defaults_contributions_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contribution_defaults_contributions_type_id ON contribution_defaults USING btree (contribution_type_id);


--
-- Name: contribution_defaults_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contribution_defaults_entity_id ON contribution_defaults USING btree (entity_id);


--
-- Name: contribution_defaults_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contribution_defaults_org_id ON contribution_defaults USING btree (org_id);


--
-- Name: contribution_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contribution_types_org_id ON contribution_types USING btree (org_id);


--
-- Name: contributions_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contributions_bank_account_id ON contributions USING btree (bank_account_id);


--
-- Name: contributions_contributions_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contributions_contributions_type_id ON contributions USING btree (contribution_type_id);


--
-- Name: contributions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contributions_entity_id ON contributions USING btree (entity_id);


--
-- Name: contributions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contributions_org_id ON contributions USING btree (org_id);


--
-- Name: contributions_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contributions_period_id ON contributions USING btree (period_id);


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
-- Name: day_ledgers_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_bank_account_id ON day_ledgers USING btree (bank_account_id);


--
-- Name: day_ledgers_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_currency_id ON day_ledgers USING btree (currency_id);


--
-- Name: day_ledgers_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_department_id ON day_ledgers USING btree (department_id);


--
-- Name: day_ledgers_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_entity_id ON day_ledgers USING btree (entity_id);


--
-- Name: day_ledgers_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_item_id ON day_ledgers USING btree (item_id);


--
-- Name: day_ledgers_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_journal_id ON day_ledgers USING btree (journal_id);


--
-- Name: day_ledgers_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_org_id ON day_ledgers USING btree (org_id);


--
-- Name: day_ledgers_store_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_store_id ON day_ledgers USING btree (store_id);


--
-- Name: day_ledgers_transaction_status_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_transaction_status_id ON day_ledgers USING btree (transaction_status_id);


--
-- Name: day_ledgers_transaction_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_transaction_type_id ON day_ledgers USING btree (transaction_type_id);


--
-- Name: day_ledgers_workflow_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX day_ledgers_workflow_table_id ON day_ledgers USING btree (workflow_table_id);


--
-- Name: default_accounts_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_account_id ON default_accounts USING btree (account_id);


--
-- Name: default_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_org_id ON default_accounts USING btree (org_id);


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
-- Name: drawings_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX drawings_bank_account_id ON drawings USING btree (bank_account_id);


--
-- Name: drawings_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX drawings_entity_id ON drawings USING btree (entity_id);


--
-- Name: drawings_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX drawings_org_id ON drawings USING btree (org_id);


--
-- Name: drawings_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX drawings_period_id ON drawings USING btree (period_id);


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
-- Name: expenses_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX expenses_bank_account_id ON expenses USING btree (bank_account_id);


--
-- Name: expenses_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX expenses_currency_id ON expenses USING btree (currency_id);


--
-- Name: expenses_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX expenses_entity_id ON expenses USING btree (entity_id);


--
-- Name: expenses_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX expenses_org_id ON expenses USING btree (org_id);


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
-- Name: holidays_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX holidays_org_id ON holidays USING btree (org_id);


--
-- Name: investment_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX investment_types_org_id ON investment_types USING btree (org_id);


--
-- Name: investments_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX investments_bank_account_id ON investments USING btree (bank_account_id);


--
-- Name: investments_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX investments_currency_id ON investments USING btree (currency_id);


--
-- Name: investments_investment_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX investments_investment_type_id ON investments USING btree (investment_type_id);


--
-- Name: investments_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX investments_org_id ON investments USING btree (org_id);


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
-- Name: journals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_org_id ON journals USING btree (org_id);


--
-- Name: journals_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_period_id ON journals USING btree (period_id);


--
-- Name: kin_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kin_types_org_id ON kin_types USING btree (org_id);


--
-- Name: kins_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kins_entity_id ON kins USING btree (entity_id);


--
-- Name: kins_kin_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kins_kin_type_id ON kins USING btree (kin_type_id);


--
-- Name: kins_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kins_org_id ON kins USING btree (org_id);


--
-- Name: ledger_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_account_id ON ledger_types USING btree (account_id);


--
-- Name: ledger_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_org_id ON ledger_types USING btree (org_id);


--
-- Name: loan_monthly_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_monthly_loan_id ON loan_monthly USING btree (loan_id);


--
-- Name: loan_monthly_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_monthly_org_id ON loan_monthly USING btree (org_id);


--
-- Name: loan_monthly_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_monthly_period_id ON loan_monthly USING btree (period_id);


--
-- Name: loan_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_types_org_id ON loan_types USING btree (org_id);


--
-- Name: loans_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_bank_account_id ON loans USING btree (bank_account_id);


--
-- Name: loans_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_entity_id ON loans USING btree (entity_id);


--
-- Name: loans_loan_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_loan_type_id ON loans USING btree (loan_type_id);


--
-- Name: loans_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_org_id ON loans USING btree (org_id);


--
-- Name: meetings_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX meetings_org_id ON meetings USING btree (org_id);


--
-- Name: members_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_bank_account_id ON members USING btree (bank_account_id);


--
-- Name: members_bank_branch_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_bank_branch_id ON members USING btree (bank_branch_id);


--
-- Name: members_bank_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_bank_id ON members USING btree (bank_id);


--
-- Name: members_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_currency_id ON members USING btree (currency_id);


--
-- Name: members_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_entity_id ON members USING btree (entity_id);


--
-- Name: members_location_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_location_id ON members USING btree (location_id);


--
-- Name: members_nation_of_birth; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_nation_of_birth ON members USING btree (nation_of_birth);


--
-- Name: members_nationality; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_nationality ON members USING btree (nationality);


--
-- Name: members_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX members_org_id ON members USING btree (org_id);


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
-- Name: penalty_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_bank_account_id ON penalty USING btree (bank_account_id);


--
-- Name: penalty_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_currency_id ON penalty USING btree (currency_id);


--
-- Name: penalty_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_entity_id ON penalty USING btree (entity_id);


--
-- Name: penalty_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_org_id ON penalty USING btree (org_id);


--
-- Name: penalty_penalty_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_penalty_type_id ON penalty USING btree (penalty_type_id);


--
-- Name: penalty_type_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_type_org_id ON penalty_type USING btree (org_id);


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
-- Name: productions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX productions_org_id ON productions USING btree (org_id);


--
-- Name: productions_product_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX productions_product_id ON productions USING btree (product_id);


--
-- Name: productions_subscription_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX productions_subscription_id ON productions USING btree (subscription_id);


--
-- Name: products_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_org_id ON products USING btree (org_id);


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
-- Name: transactions_investment_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_investment_id ON transactions USING btree (investment_id);


--
-- Name: transactions_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_journal_id ON transactions USING btree (journal_id);


--
-- Name: transactions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_org_id ON transactions USING btree (org_id);


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
-- Name: tx_ledger_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_bank_account_id ON tx_ledger USING btree (bank_account_id);


--
-- Name: tx_ledger_bpartner_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_bpartner_id ON tx_ledger USING btree (bpartner_id);


--
-- Name: tx_ledger_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_currency_id ON tx_ledger USING btree (currency_id);


--
-- Name: tx_ledger_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_entity_id ON tx_ledger USING btree (entity_id);


--
-- Name: tx_ledger_investment_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_investment_id ON tx_ledger USING btree (investment_id);


--
-- Name: tx_ledger_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_journal_id ON tx_ledger USING btree (journal_id);


--
-- Name: tx_ledger_ledger_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_ledger_type_id ON tx_ledger USING btree (ledger_type_id);


--
-- Name: tx_ledger_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_org_id ON tx_ledger USING btree (org_id);


--
-- Name: tx_ledger_workflow_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tx_ledger_workflow_table_id ON tx_ledger USING btree (workflow_table_id);


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
-- Name: ins_address; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_address BEFORE INSERT OR UPDATE ON address FOR EACH ROW EXECUTE PROCEDURE ins_address();


--
-- Name: ins_applicants; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_applicants BEFORE INSERT OR UPDATE ON applicants FOR EACH ROW EXECUTE PROCEDURE ins_applicants();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_borrowing; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_borrowing BEFORE INSERT OR UPDATE ON borrowing FOR EACH ROW EXECUTE PROCEDURE ins_borrowing();


--
-- Name: ins_contrib; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_contrib AFTER INSERT OR UPDATE OF paid ON contributions FOR EACH ROW EXECUTE PROCEDURE ins_contrib();


--
-- Name: ins_contributions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_contributions AFTER INSERT OR UPDATE OF paid ON contributions FOR EACH ROW EXECUTE PROCEDURE ins_contributions();


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
-- Name: ins_fiscal_years; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_fiscal_years AFTER INSERT ON fiscal_years FOR EACH ROW EXECUTE PROCEDURE ins_fiscal_years();


--
-- Name: ins_investment; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_investment BEFORE INSERT OR UPDATE ON investments FOR EACH ROW EXECUTE PROCEDURE ins_investment();


--
-- Name: ins_loans; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_loans BEFORE INSERT OR UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE ins_loans();


--
-- Name: ins_member_limit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_member_limit BEFORE INSERT ON members FOR EACH ROW EXECUTE PROCEDURE ins_member_limit();


--
-- Name: ins_members; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_members BEFORE INSERT ON members FOR EACH ROW EXECUTE PROCEDURE ins_members();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


--
-- Name: ins_periods; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_periods BEFORE INSERT OR UPDATE ON periods FOR EACH ROW EXECUTE PROCEDURE ins_periods();


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
-- Name: ins_transactions_limit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_transactions_limit BEFORE INSERT ON transactions FOR EACH ROW EXECUTE PROCEDURE ins_transactions_limit();


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
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON productions FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON borrowing FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON investments FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON contributions FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON investments FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON borrowing FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON meetings FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON drawings FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_email AFTER INSERT ON penalty FOR EACH ROW EXECUTE PROCEDURE upd_email();


--
-- Name: upd_gls; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_gls BEFORE INSERT OR UPDATE ON gls FOR EACH ROW EXECUTE PROCEDURE upd_gls();


--
-- Name: upd_transaction_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_transaction_details BEFORE INSERT OR UPDATE ON transaction_details FOR EACH ROW EXECUTE PROCEDURE upd_transaction_details();


--
-- Name: upd_transactions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_transactions BEFORE INSERT OR UPDATE ON transactions FOR EACH ROW EXECUTE PROCEDURE upd_transactions();


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
-- Name: applicants_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: applicants_nationality_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_nationality_fkey FOREIGN KEY (nationality) REFERENCES sys_countrys(sys_country_id);


--
-- Name: applicants_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: borrowing_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing
    ADD CONSTRAINT borrowing_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: borrowing_borrowing_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing
    ADD CONSTRAINT borrowing_borrowing_type_id_fkey FOREIGN KEY (borrowing_type_id) REFERENCES borrowing_types(borrowing_type_id);


--
-- Name: borrowing_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing
    ADD CONSTRAINT borrowing_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: borrowing_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing
    ADD CONSTRAINT borrowing_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: borrowing_repayment_borrowing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_repayment
    ADD CONSTRAINT borrowing_repayment_borrowing_id_fkey FOREIGN KEY (borrowing_id) REFERENCES borrowing(borrowing_id);


--
-- Name: borrowing_repayment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_repayment
    ADD CONSTRAINT borrowing_repayment_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: borrowing_repayment_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_repayment
    ADD CONSTRAINT borrowing_repayment_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: borrowing_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY borrowing_types
    ADD CONSTRAINT borrowing_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: contribution_defaults_contribution_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_defaults
    ADD CONSTRAINT contribution_defaults_contribution_type_id_fkey FOREIGN KEY (contribution_type_id) REFERENCES contribution_types(contribution_type_id);


--
-- Name: contribution_defaults_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_defaults
    ADD CONSTRAINT contribution_defaults_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: contribution_defaults_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_defaults
    ADD CONSTRAINT contribution_defaults_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: contribution_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contribution_types
    ADD CONSTRAINT contribution_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: contributions_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: contributions_contribution_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_contribution_type_id_fkey FOREIGN KEY (contribution_type_id) REFERENCES contribution_types(contribution_type_id);


--
-- Name: contributions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: contributions_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_member_id_fkey FOREIGN KEY (member_id) REFERENCES members(member_id);


--
-- Name: contributions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: contributions_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contributions
    ADD CONSTRAINT contributions_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


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
-- Name: day_ledgers_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: day_ledgers_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: day_ledgers_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: day_ledgers_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: day_ledgers_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: day_ledgers_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: day_ledgers_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: day_ledgers_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(store_id);


--
-- Name: day_ledgers_transaction_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_transaction_status_id_fkey FOREIGN KEY (transaction_status_id) REFERENCES transaction_status(transaction_status_id);


--
-- Name: day_ledgers_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY day_ledgers
    ADD CONSTRAINT day_ledgers_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(transaction_type_id);


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
-- Name: drawings_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY drawings
    ADD CONSTRAINT drawings_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: drawings_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY drawings
    ADD CONSTRAINT drawings_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: drawings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY drawings
    ADD CONSTRAINT drawings_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: drawings_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY drawings
    ADD CONSTRAINT drawings_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


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
-- Name: expenses_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY expenses
    ADD CONSTRAINT expenses_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: expenses_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY expenses
    ADD CONSTRAINT expenses_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: expenses_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY expenses
    ADD CONSTRAINT expenses_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: expenses_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY expenses
    ADD CONSTRAINT expenses_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: holidays_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: investment_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investment_types
    ADD CONSTRAINT investment_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: investments_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investments
    ADD CONSTRAINT investments_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: investments_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investments
    ADD CONSTRAINT investments_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: investments_investment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investments
    ADD CONSTRAINT investments_investment_type_id_fkey FOREIGN KEY (investment_type_id) REFERENCES investment_types(investment_type_id);


--
-- Name: investments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY investments
    ADD CONSTRAINT investments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: kin_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kin_types
    ADD CONSTRAINT kin_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: kins_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kins
    ADD CONSTRAINT kins_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: kins_kin_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kins
    ADD CONSTRAINT kins_kin_type_id_fkey FOREIGN KEY (kin_type_id) REFERENCES kin_types(kin_type_id);


--
-- Name: kins_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kins
    ADD CONSTRAINT kins_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: loan_monthly_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_monthly
    ADD CONSTRAINT loan_monthly_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES loans(loan_id);


--
-- Name: loan_monthly_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_monthly
    ADD CONSTRAINT loan_monthly_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: loan_monthly_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_monthly
    ADD CONSTRAINT loan_monthly_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: loan_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_types
    ADD CONSTRAINT loan_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: loans_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: loans_loan_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_loan_type_id_fkey FOREIGN KEY (loan_type_id) REFERENCES loan_types(loan_type_id);


--
-- Name: loans_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: locations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: meetings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY meetings
    ADD CONSTRAINT meetings_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: member_meeting_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY member_meeting
    ADD CONSTRAINT member_meeting_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES meetings(meeting_id);


--
-- Name: member_meeting_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY member_meeting
    ADD CONSTRAINT member_meeting_member_id_fkey FOREIGN KEY (member_id) REFERENCES members(member_id);


--
-- Name: member_meeting_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY member_meeting
    ADD CONSTRAINT member_meeting_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: members_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: members_bank_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_bank_branch_id_fkey FOREIGN KEY (bank_branch_id) REFERENCES bank_branch(bank_branch_id);


--
-- Name: members_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES banks(bank_id);


--
-- Name: members_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: members_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: members_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations(location_id);


--
-- Name: members_nation_of_birth_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_nation_of_birth_fkey FOREIGN KEY (nation_of_birth) REFERENCES sys_countrys(sys_country_id);


--
-- Name: members_nationality_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_nationality_fkey FOREIGN KEY (nationality) REFERENCES sys_countrys(sys_country_id);


--
-- Name: members_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY members
    ADD CONSTRAINT members_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: orgs_parent_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_parent_org_id_fkey FOREIGN KEY (parent_org_id) REFERENCES orgs(org_id);


--
-- Name: penalty_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: penalty_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: penalty_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: penalty_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: penalty_penalty_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty
    ADD CONSTRAINT penalty_penalty_type_id_fkey FOREIGN KEY (penalty_type_id) REFERENCES penalty_type(penalty_type_id);


--
-- Name: penalty_type_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty_type
    ADD CONSTRAINT penalty_type_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: productions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY productions
    ADD CONSTRAINT productions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: productions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY productions
    ADD CONSTRAINT productions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: productions_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY productions
    ADD CONSTRAINT productions_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id);


--
-- Name: productions_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY productions
    ADD CONSTRAINT productions_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id);


--
-- Name: products_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: transactions_investment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_investment_id_fkey FOREIGN KEY (investment_id) REFERENCES investments(investment_id);


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
-- Name: tx_ledger_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: tx_ledger_bpartner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_bpartner_id_fkey FOREIGN KEY (bpartner_id) REFERENCES entitys(entity_id);


--
-- Name: tx_ledger_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: tx_ledger_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: tx_ledger_investment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_investment_id_fkey FOREIGN KEY (investment_id) REFERENCES investments(investment_id);


--
-- Name: tx_ledger_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: tx_ledger_ledger_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_ledger_type_id_fkey FOREIGN KEY (ledger_type_id) REFERENCES ledger_types(ledger_type_id);


--
-- Name: tx_ledger_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tx_ledger
    ADD CONSTRAINT tx_ledger_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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

