--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
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
-- Name: activity_action(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION activity_action() RETURNS trigger
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
$$;


ALTER FUNCTION public.activity_action() OWNER TO root;

--
-- Name: add_judges(integer); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION add_judges(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.add_judges(integer) OWNER TO root;

--
-- Name: add_transfer(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION add_transfer(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.add_transfer(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: aft_case_contacts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION aft_case_contacts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.aft_case_contacts() OWNER TO root;

--
-- Name: aft_case_decisions(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION aft_case_decisions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.case_count_id is not null) AND (NEW.fine_amount > 0) THEN
		INSERT INTO receipts (case_id, case_decision_id, receipt_type_id, org_id, receipt_date, amount, for_process)
		VALUES (NEW.case_id, NEW.case_decision_id, 2, NEW.org_id, CURRENT_DATE, NEW.fine_amount, true);
	END IF;
	
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_case_decisions() OWNER TO root;

--
-- Name: aft_court_stations(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION aft_court_stations() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO court_divisions (court_station_id, org_id, division_type_id, court_division_code)
	SELECT NEW.court_station_id, NEW.court_station_id, division_type_id, upper(substr(division_type_name, 1, 2))
	FROM division_types;

	INSERT INTO hearing_locations (court_station_id, org_id, hearing_location_name)
	VALUES (NEW.court_station_id, NEW.org_id, 'Registry');
	INSERT INTO hearing_locations (court_station_id, org_id, hearing_location_name)
	VALUES (NEW.court_station_id, NEW.org_id, 'Room 1');
	INSERT INTO bank_accounts (org_id, bank_account_name, bank_name, branch_name, is_default, is_active)
	VALUES (NEW.org_id, 'Cash', 'Cash', 'Local', true, true);
	
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_court_stations() OWNER TO root;

--
-- Name: approve_receipt(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION approve_receipt(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.approve_receipt(character varying, character varying, character varying) OWNER TO root;

--
-- Name: audit_case_activity(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_case_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.audit_case_activity() OWNER TO root;

--
-- Name: audit_case_contacts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_case_contacts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_case_contacts (case_contact_id, case_id, entity_id, contact_type_id, org_id, 
		case_contact_no, is_active, change_date, change_by, details, political_party_id)
	VALUES (NEW.case_contact_id, NEW.case_id, NEW.entity_id, NEW.contact_type_id, NEW.org_id, 
		NEW.case_contact_no, NEW.is_active, NEW.change_date, NEW.change_by, NEW.details, NEW.political_party_id);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_case_contacts() OWNER TO root;

--
-- Name: audit_case_counts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_case_counts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_case_counts(case_count_id, case_contact_id, case_category_id, org_id, narrative, is_active, 
		change_by, change_date, detail)
	VALUES(NEW.case_count_id, NEW.case_contact_id, NEW.case_category_id, NEW.org_id, NEW.narrative, NEW.is_active, 
		NEW.change_by, NEW.change_date, NEW.detail);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_case_counts() OWNER TO root;

--
-- Name: audit_case_decisions(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_case_decisions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_case_decisions(case_decision_id, case_id, case_activity_id, case_count_id, decision_type_id, judgment_status_id,
		org_id, decision_summary, judgement, judgement_date, death_sentence, life_sentence, jail_years, jail_days, fine_amount,
		fine_jail, canes, is_active, change_by, change_date, detail)
	VALUES(	NEW.case_decision_id, NEW.case_id, NEW.case_activity_id, NEW.case_count_id, NEW.decision_type_id, NEW.judgment_status_id, NEW.org_id,
		NEW.decision_summary, NEW.judgement, NEW.judgement_date, NEW.death_sentence, NEW.life_sentence, 
		NEW.fine_jail, NEW.jail_years, NEW.jail_days, NEW.fine_amount, NEW.canes, NEW.is_active, NEW.change_by, NEW.change_date, NEW.detail);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_case_decisions() OWNER TO root;

--
-- Name: audit_case_transfers(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_case_transfers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
		INSERT INTO log_case_transfers(case_transfer_id, case_id, case_category_id, court_division_id, org_id, 
			judgment_date, presiding_judge,previous_case_number,receipt_date,received_by,
			is_active,change_by,change_date,details	)
	    VALUES(NEW.case_transfer_id, NEW.case_id, NEW.case_category_id, NEW.court_division_id, NEW.org_id, 
			NEW.judgment_date, NEW.presiding_judge, NEW.previous_case_number, NEW.receipt_date, NEW.received_by,
			NEW.is_active, NEW.change_by, NEW.change_date, NEW.details);

		RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_case_transfers() OWNER TO root;

--
-- Name: audit_cases(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_cases() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.audit_cases() OWNER TO root;

--
-- Name: audit_court_bankings(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_court_bankings() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_court_bankings(court_banking_id, bank_account_id, source_account_id, org_id, bank_ref, 
		banking_date, amount, change_by, change_date, details)
	VALUES(NEW.court_banking_id, NEW.bank_account_id, NEW.source_account_id, NEW.org_id, NEW.bank_ref, 
		NEW.banking_date, NEW.amount, NEW.change_by, NEW.change_date, NEW.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_court_bankings() OWNER TO root;

--
-- Name: audit_court_payments(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_court_payments() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	INSERT INTO log_court_payments (court_payment_id, receipt_id, payment_type_id, bank_account_id, 
		org_id, bank_ref, payment_date, amount, jail_days, is_active, 
		change_by, change_date, credit_note, refund, details)
	VALUES (NEW.court_payment_id, NEW.receipt_id, NEW.payment_type_id, NEW.bank_account_id,
		NEW.org_id, NEW.bank_ref, NEW.payment_date, NEW.amount, NEW.jail_days, NEW.is_active, 
		NEW.change_by, NEW.change_date, NEW.credit_note, NEW.refund, NEW.details);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_court_payments() OWNER TO root;

--
-- Name: audit_receipts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_receipts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_receipts(receipt_id, case_id, case_decision_id, receipt_type_id, 
		court_station_id, org_id, receipt_for, case_number, receipt_date, amount, for_process, 
		approved, is_active, change_by, change_date, details)
	VALUES(NEW.receipt_id, NEW.case_id, NEW.case_decision_id, NEW.receipt_type_id, 
		NEW.court_station_id, NEW.org_id, NEW.receipt_for, NEW.case_number, NEW.receipt_date, NEW.amount, NEW.for_process, 
		NEW.approved, NEW.is_active, NEW.change_by, NEW.change_date, NEW.details);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_receipts() OWNER TO root;

--
-- Name: change_password(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
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
		passchange := 'Password Changing Error Ensure you have correct details';
	END IF;

	return passchange;
END;
$_$;


ALTER FUNCTION public.change_password(character varying, character varying, character varying) OWNER TO root;

--
-- Name: checkentity(character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION checkentity(character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.checkentity(character varying) OWNER TO root;

--
-- Name: default_currency(character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION default_currency(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT orgs.currency_id
	FROM orgs INNER JOIN entitys ON orgs.org_id = entitys.org_id
	WHERE (entitys.entity_id = CAST($1 as integer));
$_$;


ALTER FUNCTION public.default_currency(character varying) OWNER TO root;

--
-- Name: electrol_area(integer, integer); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION electrol_area(category_id integer, integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.electrol_area(category_id integer, integer) OWNER TO root;

--
-- Name: emailed(integer, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION emailed(integer, character varying) RETURNS void
    LANGUAGE sql
    AS $_$
    UPDATE sys_emailed SET emailed = true WHERE (sys_emailed_id = CAST($2 as int));
$_$;


ALTER FUNCTION public.emailed(integer, character varying) OWNER TO root;

--
-- Name: first_password(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.first_password() OWNER TO root;

--
-- Name: get_parties(integer, integer); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION get_parties(integer, integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.get_parties(integer, integer) OWNER TO root;

--
-- Name: get_phase_email(integer); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.get_phase_email(integer) OWNER TO root;

--
-- Name: get_phase_status(boolean, boolean); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.get_phase_status(boolean, boolean) OWNER TO root;

--
-- Name: ins_approvals(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_approvals() OWNER TO root;

--
-- Name: ins_case_activity(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_case_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	IF (NEW.activity_time > NEW.finish_time) THEN
		RAISE EXCEPTION 'Ending time must be greater than starting time';
	END IF;

	IF ((NEW.activity_date > current_date + 750) OR (NEW.activity_date < current_date - 750)) THEN
		RAISE EXCEPTION 'Date must be within 2 year limit';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_case_activity() OWNER TO root;

--
-- Name: ins_case_contacts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_case_contacts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.ins_case_contacts() OWNER TO root;

--
-- Name: ins_case_decisions(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_case_decisions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.ins_case_decisions() OWNER TO root;

--
-- Name: ins_case_files(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_case_files() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.ins_case_files() OWNER TO root;

--
-- Name: ins_cases(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_cases() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.ins_cases() OWNER TO root;

--
-- Name: ins_court_divisions(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_court_divisions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_court_divisions() OWNER TO root;

--
-- Name: ins_court_stations(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_court_stations() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_name		varchar(320);
BEGIN

	SELECT court_rank_name INTO v_org_name
	FROM court_ranks
	WHERE court_rank_id = NEW.court_rank_id;

	v_org_name := v_org_name || ' ' || NEW.court_station_name;
	
	IF (TG_OP = 'INSERT')THEN
		INSERT INTO orgs (org_id, currency_id, org_name, is_default, logo)
		VALUES (NEW.court_station_id, 1, v_org_name, false, 'logo.png');

		NEW.org_id := NEW.court_station_id;
	END IF;

	IF (TG_OP = 'UPDATE')THEN
		UPDATE orgs SET org_name = v_org_name WHERE org_id = NEW.org_id;
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_court_stations() OWNER TO root;

--
-- Name: ins_entitys(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_entitys() OWNER TO root;

--
-- Name: ins_entry_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_entry_form(character varying, character varying, character varying) OWNER TO root;

--
-- Name: ins_entry_forms(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_entry_forms() OWNER TO root;

--
-- Name: ins_fields(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_fields() OWNER TO root;

--
-- Name: ins_hearing_locations(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_hearing_locations() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_hearing_locations() OWNER TO root;

--
-- Name: ins_password(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.first_password is null) AND (TG_OP = 'INSERT') THEN
		NEW.first_password := first_password();
	END IF;
	IF(TG_OP = 'INSERT') THEN
		IF (NEW.Entity_password is null) THEN
			NEW.Entity_password := md5(NEW.first_password);
		END IF;
	ELSIF(OLD.first_password <> NEW.first_password) THEN
		NEW.Entity_password := md5(NEW.first_password);
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_password() OWNER TO root;

--
-- Name: ins_police_stations(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_police_stations() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_police_stations() OWNER TO root;

--
-- Name: ins_sms(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_sms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.message is not null) THEN
		IF(upper(substr(NEW.message, 1, 2)) = '.C') THEN
			NEW.folder_id := 4;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_sms() OWNER TO root;

--
-- Name: ins_sms_address(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_sms_address(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
	INSERT INTO sms_address (address_id, sms_id)
	VALUES (CAST($1 AS Integer), CAST($3 AS integer));

	return 'Address Added';
END;
$_$;


ALTER FUNCTION public.ins_sms_address(character varying, character varying, character varying) OWNER TO root;

--
-- Name: ins_sms_trans(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_sms_trans() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec RECORD;
	msg varchar(2400);
BEGIN
	IF(NEW.part_no = NEW.part_count) THEN
		IF(NEW.part_no = 1) THEN
			INSERT INTO sms (folder_id, sms_number, message)
			VALUES(3, NEW.origin, NEW.message);

			NEW.sms_picked = true;
		ELSE
			msg := '';
			FOR rec IN SELECT part_no, message FROM sms_trans 
				WHERE (part_id = NEW.part_id) AND (origin = NEW.origin) AND (sms_picked = false)
			ORDER BY part_no LOOP
				msg := msg || rec.message;
			END LOOP;
			msg := msg || NEW.message;

			INSERT INTO sms (org_id, folder_id, sms_number, message)
			VALUES(0, 3, NEW.origin, msg);

			UPDATE sms_trans SET sms_picked = true 
			WHERE (part_id = NEW.part_id) AND (origin = NEW.origin) AND (sms_picked = false);
			NEW.sms_picked = true;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_sms_trans() OWNER TO root;

--
-- Name: ins_sub_fields(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_sub_fields() OWNER TO root;

--
-- Name: ins_sys_reset(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.ins_sys_reset() OWNER TO root;

--
-- Name: manage_appleal(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION manage_appleal(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.manage_appleal(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: manage_case(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION manage_case(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.manage_case(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: manage_mpesa(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION manage_mpesa(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.manage_mpesa(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: manage_qorum(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION manage_qorum(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.manage_qorum(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: manage_transfer(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION manage_transfer(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.manage_transfer(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: merge_entity(integer, integer); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION merge_entity(integer, integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER FUNCTION public.merge_entity(integer, integer) OWNER TO root;

--
-- Name: month_diff(date, date); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION month_diff(date, date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT CAST(((DATE_PART('year', $2) - DATE_PART('year', $1)) * 12) + (DATE_PART('month', $2) - DATE_PART('month', $1)) as integer);
$_$;


ALTER FUNCTION public.month_diff(date, date) OWNER TO root;

--
-- Name: remove_allocation(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION remove_allocation(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	msg varchar(120);
BEGIN

	UPDATE mpesa_trxs SET receipt_id = null
	WHERE (mpesa_trx_id  = CAST($1 as integer));

	msg := 'Receipt approved.';

	return msg;
END;
$_$;


ALTER FUNCTION public.remove_allocation(character varying, character varying, character varying) OWNER TO root;

--
-- Name: upd_action(); Type: FUNCTION; Schema: public; Owner: root
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

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id= NEW.entity_id) LOOP
			iswf := false;
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


ALTER FUNCTION public.upd_action() OWNER TO root;

--
-- Name: upd_approvals(); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.upd_approvals() OWNER TO root;

--
-- Name: upd_approvals(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION upd_approvals(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	app_id		Integer;
	reca 		RECORD;
	recb		RECORD;
	recc		RECORD;
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

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approval_level) INTO min_level
		FROM approvals
		WHERE (table_id = reca.table_id) AND (approve_status = 'Draft');
		
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
		INSERT INTO approvals (org_id, forward_id, workflow_phase_id, table_name, table_id, org_entity_id, app_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, approval_id, workflow_phase_id, table_name, table_id, CAST($2 as int), org_entity_id, escalation_days, escalation_hours, 0, approval_narrative, reca.review_advice, 'Completed'
		FROM vw_approvals
		WHERE (approval_id = reca.approval_id);
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


ALTER FUNCTION public.upd_approvals(character varying, character varying, character varying, character varying) OWNER TO root;

--
-- Name: upd_checklist(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.upd_checklist(character varying, character varying, character varying) OWNER TO root;

--
-- Name: upd_complete_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
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


ALTER FUNCTION public.upd_complete_form(character varying, character varying, character varying) OWNER TO root;

--
-- Name: upd_court_payments(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION upd_court_payments() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	IF(NEW.payment_date < CURRENT_DATE-7)THEN
		RAISE EXCEPTION 'Cannot enter a previous date';
	END IF;

	IF(NEW.r_amount is not null)THEN
		NEW.amount := NEW.r_amount * (-1);
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_court_payments() OWNER TO root;

--
-- Name: upd_entitys(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION upd_entitys() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id		integer;
BEGIN

	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);

	IF(TG_OP = 'INSERT')THEN
		IF (NEW.court_station_id is not null)THEN
			NEW.org_id := v_org_id;
		END IF;
	ELSIF(TG_OP = 'UPDATE')THEN
		IF (OLD.court_station_id <> NEW.court_station_id)THEN
			NEW.org_id := v_org_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_entitys() OWNER TO root;

--
-- Name: upd_receipts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION upd_receipts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.upd_receipts() OWNER TO root;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: activity_results; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE activity_results (
    activity_result_id integer NOT NULL,
    activity_result_name character varying(320) NOT NULL,
    appeal boolean DEFAULT true NOT NULL,
    trial boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.activity_results OWNER TO root;

--
-- Name: activity_results_activity_result_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE activity_results_activity_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.activity_results_activity_result_id_seq OWNER TO root;

--
-- Name: activity_results_activity_result_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE activity_results_activity_result_id_seq OWNED BY activity_results.activity_result_id;


--
-- Name: activity_results_activity_result_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('activity_results_activity_result_id_seq', 16, true);


--
-- Name: activitys; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE activitys (
    activity_id integer NOT NULL,
    activity_name character varying(320) NOT NULL,
    appeal boolean DEFAULT true NOT NULL,
    trial boolean DEFAULT true NOT NULL,
    ep boolean DEFAULT false NOT NULL,
    show_on_diary boolean DEFAULT true NOT NULL,
    activity_days integer DEFAULT 1,
    activity_hours integer DEFAULT 0,
    details text
);


ALTER TABLE public.activitys OWNER TO root;

--
-- Name: activitys_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE activitys_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.activitys_activity_id_seq OWNER TO root;

--
-- Name: activitys_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE activitys_activity_id_seq OWNED BY activitys.activity_id;


--
-- Name: activitys_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('activitys_activity_id_seq', 30, true);


--
-- Name: address; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE address (
    address_id integer NOT NULL,
    org_id integer,
    address_type_id integer,
    sys_country_id character(2),
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


ALTER TABLE public.address OWNER TO root;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_address_id_seq OWNER TO root;

--
-- Name: address_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE address_address_id_seq OWNED BY address.address_id;


--
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('address_address_id_seq', 1, false);


--
-- Name: address_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE address_types (
    address_type_id integer NOT NULL,
    address_type_name character varying(50)
);


ALTER TABLE public.address_types OWNER TO root;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE address_types_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_types_address_type_id_seq OWNER TO root;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE address_types_address_type_id_seq OWNED BY address_types.address_type_id;


--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('address_types_address_type_id_seq', 1, false);


--
-- Name: adjorn_reasons; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE adjorn_reasons (
    adjorn_reason_id integer NOT NULL,
    adjorn_reason_name character varying(320) NOT NULL,
    appeal boolean DEFAULT true NOT NULL,
    trial boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.adjorn_reasons OWNER TO root;

--
-- Name: adjorn_reasons_adjorn_reason_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE adjorn_reasons_adjorn_reason_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.adjorn_reasons_adjorn_reason_id_seq OWNER TO root;

--
-- Name: adjorn_reasons_adjorn_reason_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE adjorn_reasons_adjorn_reason_id_seq OWNED BY adjorn_reasons.adjorn_reason_id;


--
-- Name: adjorn_reasons_adjorn_reason_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('adjorn_reasons_adjorn_reason_id_seq', 7, true);


--
-- Name: approval_checklists; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE approval_checklists (
    approval_checklist_id integer NOT NULL,
    org_id integer,
    approval_id integer NOT NULL,
    checklist_id integer NOT NULL,
    requirement text,
    manditory boolean DEFAULT false NOT NULL,
    done boolean DEFAULT false NOT NULL,
    narrative character varying(320)
);


ALTER TABLE public.approval_checklists OWNER TO root;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE approval_checklists_approval_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approval_checklists_approval_checklist_id_seq OWNER TO root;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE approval_checklists_approval_checklist_id_seq OWNED BY approval_checklists.approval_checklist_id;


--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('approval_checklists_approval_checklist_id_seq', 1, false);


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE approvals (
    approval_id integer NOT NULL,
    org_id integer,
    workflow_phase_id integer NOT NULL,
    org_entity_id integer NOT NULL,
    app_entity_id integer,
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


ALTER TABLE public.approvals OWNER TO root;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE approvals_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approvals_approval_id_seq OWNER TO root;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE approvals_approval_id_seq OWNED BY approvals.approval_id;


--
-- Name: approvals_approval_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('approvals_approval_id_seq', 1, false);


--
-- Name: bank_accounts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE bank_accounts (
    bank_account_id integer NOT NULL,
    org_id integer,
    bank_account_name character varying(120),
    bank_account_number character varying(50),
    bank_name character varying(120),
    branch_name character varying(120),
    narrative character varying(240),
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.bank_accounts OWNER TO root;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE bank_accounts_bank_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bank_accounts_bank_account_id_seq OWNER TO root;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE bank_accounts_bank_account_id_seq OWNED BY bank_accounts.bank_account_id;


--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('bank_accounts_bank_account_id_seq', 1, false);


--
-- Name: bench_subjects; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE bench_subjects (
    bench_subject_id integer NOT NULL,
    entity_id integer NOT NULL,
    case_subject_id integer NOT NULL,
    org_id integer,
    proficiency integer DEFAULT 1,
    details text
);


ALTER TABLE public.bench_subjects OWNER TO root;

--
-- Name: bench_subjects_bench_subject_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE bench_subjects_bench_subject_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bench_subjects_bench_subject_id_seq OWNER TO root;

--
-- Name: bench_subjects_bench_subject_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE bench_subjects_bench_subject_id_seq OWNED BY bench_subjects.bench_subject_id;


--
-- Name: bench_subjects_bench_subject_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('bench_subjects_bench_subject_id_seq', 1, false);


--
-- Name: cal_block_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE cal_block_types (
    cal_block_type_id integer NOT NULL,
    cal_block_type_name character varying(120) NOT NULL
);


ALTER TABLE public.cal_block_types OWNER TO root;

--
-- Name: cal_block_types_cal_block_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE cal_block_types_cal_block_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cal_block_types_cal_block_type_id_seq OWNER TO root;

--
-- Name: cal_block_types_cal_block_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE cal_block_types_cal_block_type_id_seq OWNED BY cal_block_types.cal_block_type_id;


--
-- Name: cal_block_types_cal_block_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('cal_block_types_cal_block_type_id_seq', 1, false);


--
-- Name: cal_entity_blocks; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE cal_entity_blocks (
    cal_entity_block_id integer NOT NULL,
    entity_id integer NOT NULL,
    cal_block_type_id integer NOT NULL,
    org_id integer NOT NULL,
    start_date date,
    start_time time without time zone,
    end_date date,
    end_time time without time zone,
    reason character varying(320),
    details text
);


ALTER TABLE public.cal_entity_blocks OWNER TO root;

--
-- Name: cal_entity_blocks_cal_entity_block_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE cal_entity_blocks_cal_entity_block_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cal_entity_blocks_cal_entity_block_id_seq OWNER TO root;

--
-- Name: cal_entity_blocks_cal_entity_block_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE cal_entity_blocks_cal_entity_block_id_seq OWNED BY cal_entity_blocks.cal_entity_block_id;


--
-- Name: cal_entity_blocks_cal_entity_block_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('cal_entity_blocks_cal_entity_block_id_seq', 1, false);


--
-- Name: cal_holidays; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE cal_holidays (
    cal_holiday_id integer NOT NULL,
    cal_holiday_name character varying(50) NOT NULL,
    cal_holiday_date date
);


ALTER TABLE public.cal_holidays OWNER TO root;

--
-- Name: cal_holidays_cal_holiday_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE cal_holidays_cal_holiday_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cal_holidays_cal_holiday_id_seq OWNER TO root;

--
-- Name: cal_holidays_cal_holiday_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE cal_holidays_cal_holiday_id_seq OWNED BY cal_holidays.cal_holiday_id;


--
-- Name: cal_holidays_cal_holiday_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('cal_holidays_cal_holiday_id_seq', 1, false);


--
-- Name: case_activity; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_activity (
    case_activity_id integer NOT NULL,
    case_id integer NOT NULL,
    activity_id integer NOT NULL,
    hearing_location_id integer,
    activity_result_id integer,
    adjorn_reason_id integer,
    order_type_id integer,
    court_station_id integer,
    appleal_case_id integer,
    org_id integer,
    activity_date date NOT NULL,
    activity_time time without time zone NOT NULL,
    finish_time time without time zone NOT NULL,
    shared_hearing boolean DEFAULT false NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    urgency_certificate character varying(50),
    order_title character varying(320),
    order_narrative character varying(320),
    order_details text,
    appleal_details text,
    result_details text,
    adjorn_details text,
    details text,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Completed'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone
);


ALTER TABLE public.case_activity OWNER TO root;

--
-- Name: case_activity_case_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_activity_case_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_activity_case_activity_id_seq OWNER TO root;

--
-- Name: case_activity_case_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_activity_case_activity_id_seq OWNED BY case_activity.case_activity_id;


--
-- Name: case_activity_case_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_activity_case_activity_id_seq', 1, false);


--
-- Name: case_bookmarks; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_bookmarks (
    case_bookmark_id integer NOT NULL,
    case_id integer NOT NULL,
    entity_id integer NOT NULL,
    org_id integer,
    entry_date timestamp without time zone DEFAULT now(),
    notes text
);


ALTER TABLE public.case_bookmarks OWNER TO root;

--
-- Name: case_bookmarks_case_bookmark_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_bookmarks_case_bookmark_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_bookmarks_case_bookmark_id_seq OWNER TO root;

--
-- Name: case_bookmarks_case_bookmark_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_bookmarks_case_bookmark_id_seq OWNED BY case_bookmarks.case_bookmark_id;


--
-- Name: case_bookmarks_case_bookmark_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_bookmarks_case_bookmark_id_seq', 1, false);


--
-- Name: case_category; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_category (
    case_category_id integer NOT NULL,
    case_type_id integer,
    case_category_name character varying(320) NOT NULL,
    case_category_title character varying(320),
    case_category_no character varying(12),
    act_code character varying(64),
    special_suffix character varying(12),
    death_sentence boolean DEFAULT false NOT NULL,
    life_sentence boolean DEFAULT false NOT NULL,
    min_sentence integer,
    max_sentence integer,
    min_fine real,
    max_fine real,
    min_canes integer,
    max_canes integer,
    details text
);


ALTER TABLE public.case_category OWNER TO root;

--
-- Name: case_category_case_category_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_category_case_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_category_case_category_id_seq OWNER TO root;

--
-- Name: case_category_case_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_category_case_category_id_seq OWNED BY case_category.case_category_id;


--
-- Name: case_category_case_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_category_case_category_id_seq', 1001, true);


--
-- Name: case_contacts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_contacts (
    case_contact_id integer NOT NULL,
    case_id integer NOT NULL,
    entity_id integer NOT NULL,
    contact_type_id integer NOT NULL,
    political_party_id integer,
    org_id integer,
    case_contact_no integer,
    election_winner boolean DEFAULT false NOT NULL,
    is_disqualified boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.case_contacts OWNER TO root;

--
-- Name: case_contacts_case_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_contacts_case_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_contacts_case_contact_id_seq OWNER TO root;

--
-- Name: case_contacts_case_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_contacts_case_contact_id_seq OWNED BY case_contacts.case_contact_id;


--
-- Name: case_contacts_case_contact_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_contacts_case_contact_id_seq', 1, false);


--
-- Name: case_counts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_counts (
    case_count_id integer NOT NULL,
    case_contact_id integer NOT NULL,
    case_category_id integer NOT NULL,
    org_id integer,
    narrative character varying(320),
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.case_counts OWNER TO root;

--
-- Name: case_counts_case_count_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_counts_case_count_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_counts_case_count_id_seq OWNER TO root;

--
-- Name: case_counts_case_count_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_counts_case_count_id_seq OWNED BY case_counts.case_count_id;


--
-- Name: case_counts_case_count_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_counts_case_count_id_seq', 1, false);


--
-- Name: case_decisions; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_decisions (
    case_decision_id integer NOT NULL,
    case_id integer,
    case_activity_id integer,
    case_count_id integer,
    decision_type_id integer,
    judgment_status_id integer,
    org_id integer,
    decision_summary character varying(1024),
    judgement text,
    judgement_date date,
    death_sentence boolean DEFAULT false NOT NULL,
    life_sentence boolean DEFAULT false NOT NULL,
    jail_years integer,
    jail_days integer,
    fine_amount real,
    fine_jail integer,
    canes integer,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.case_decisions OWNER TO root;

--
-- Name: case_decisions_case_decision_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_decisions_case_decision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_decisions_case_decision_id_seq OWNER TO root;

--
-- Name: case_decisions_case_decision_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_decisions_case_decision_id_seq OWNED BY case_decisions.case_decision_id;


--
-- Name: case_decisions_case_decision_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_decisions_case_decision_id_seq', 1, false);


--
-- Name: case_files; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_files (
    case_file_id integer NOT NULL,
    case_id integer,
    case_activity_id integer,
    case_decision_id integer,
    org_id integer,
    file_folder character varying(320),
    file_name character varying(320),
    file_type character varying(320),
    file_size integer,
    narrative character varying(320),
    details text
);


ALTER TABLE public.case_files OWNER TO root;

--
-- Name: case_files_case_file_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_files_case_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_files_case_file_id_seq OWNER TO root;

--
-- Name: case_files_case_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_files_case_file_id_seq OWNED BY case_files.case_file_id;


--
-- Name: case_files_case_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_files_case_file_id_seq', 1, false);


--
-- Name: case_insurance; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_insurance (
    case_insurance_id integer NOT NULL,
    case_id integer NOT NULL,
    org_id integer,
    entry_date timestamp without time zone DEFAULT now(),
    registration_number character varying(320),
    type_of_claim character varying(320),
    value_of_claim real,
    notes text
);


ALTER TABLE public.case_insurance OWNER TO root;

--
-- Name: case_insurance_case_insurance_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_insurance_case_insurance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_insurance_case_insurance_id_seq OWNER TO root;

--
-- Name: case_insurance_case_insurance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_insurance_case_insurance_id_seq OWNED BY case_insurance.case_insurance_id;


--
-- Name: case_insurance_case_insurance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_insurance_case_insurance_id_seq', 1, false);


--
-- Name: case_notes; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_notes (
    case_note_id integer NOT NULL,
    case_activity_id integer,
    entity_id integer NOT NULL,
    org_id integer,
    case_note_title character varying(320),
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.case_notes OWNER TO root;

--
-- Name: case_notes_case_note_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_notes_case_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_notes_case_note_id_seq OWNER TO root;

--
-- Name: case_notes_case_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_notes_case_note_id_seq OWNED BY case_notes.case_note_id;


--
-- Name: case_notes_case_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_notes_case_note_id_seq', 1, false);


--
-- Name: case_quorum; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_quorum (
    case_quorum_id integer NOT NULL,
    case_activity_id integer,
    case_contact_id integer NOT NULL,
    org_id integer,
    narrative character varying(320)
);


ALTER TABLE public.case_quorum OWNER TO root;

--
-- Name: case_quorum_case_quorum_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_quorum_case_quorum_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_quorum_case_quorum_id_seq OWNER TO root;

--
-- Name: case_quorum_case_quorum_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_quorum_case_quorum_id_seq OWNED BY case_quorum.case_quorum_id;


--
-- Name: case_quorum_case_quorum_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_quorum_case_quorum_id_seq', 1, false);


--
-- Name: case_subjects; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_subjects (
    case_subject_id integer NOT NULL,
    case_subject_name character varying(320) NOT NULL,
    ep boolean DEFAULT false NOT NULL,
    criminal boolean DEFAULT false NOT NULL,
    civil boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.case_subjects OWNER TO root;

--
-- Name: case_subjects_case_subject_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_subjects_case_subject_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_subjects_case_subject_id_seq OWNER TO root;

--
-- Name: case_subjects_case_subject_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_subjects_case_subject_id_seq OWNED BY case_subjects.case_subject_id;


--
-- Name: case_subjects_case_subject_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_subjects_case_subject_id_seq', 8, true);


--
-- Name: case_transfers; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_transfers (
    case_transfer_id integer NOT NULL,
    case_id integer,
    case_category_id integer,
    court_division_id integer,
    org_id integer,
    judgment_date date,
    presiding_judge character varying(50),
    previous_case_number character varying(25),
    receipt_date date,
    received_by character varying(50),
    case_transfered boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.case_transfers OWNER TO root;

--
-- Name: case_transfers_case_transfer_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_transfers_case_transfer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_transfers_case_transfer_id_seq OWNER TO root;

--
-- Name: case_transfers_case_transfer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_transfers_case_transfer_id_seq OWNED BY case_transfers.case_transfer_id;


--
-- Name: case_transfers_case_transfer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_transfers_case_transfer_id_seq', 1, false);


--
-- Name: case_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_types (
    case_type_id integer NOT NULL,
    case_type_name character varying(320) NOT NULL,
    duration_unacceptable integer,
    duration_serious integer,
    duration_normal integer,
    duration_low integer,
    activity_unacceptable integer,
    activity_serious integer,
    activity_normal integer,
    activity_low integer,
    details text
);


ALTER TABLE public.case_types OWNER TO root;

--
-- Name: case_types_case_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_types_case_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_types_case_type_id_seq OWNER TO root;

--
-- Name: case_types_case_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_types_case_type_id_seq OWNED BY case_types.case_type_id;


--
-- Name: case_types_case_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_types_case_type_id_seq', 7, true);


--
-- Name: cases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE cases (
    case_id integer NOT NULL,
    case_category_id integer NOT NULL,
    court_division_id integer NOT NULL,
    file_location_id integer,
    case_subject_id integer,
    police_station_id integer,
    new_case_id integer,
    old_case_id integer,
    county_id integer,
    constituency_id integer,
    ward_id integer,
    org_id integer,
    case_title character varying(320) NOT NULL,
    case_number character varying(50),
    file_number character varying(50) NOT NULL,
    date_of_elections date,
    date_of_arrest date,
    ob_number character varying(120),
    holding_prison character varying(120),
    warrant_of_arrest boolean DEFAULT false NOT NULL,
    alleged_crime text,
    start_date date NOT NULL,
    original_case_date date,
    end_date date,
    nature_of_claim character varying(320),
    value_of_claim real,
    closed boolean DEFAULT false NOT NULL,
    case_locked boolean DEFAULT false NOT NULL,
    consolidate_cases boolean DEFAULT false NOT NULL,
    final_decision character varying(1024),
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.cases OWNER TO root;

--
-- Name: cases_case_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE cases_case_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cases_case_id_seq OWNER TO root;

--
-- Name: cases_case_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE cases_case_id_seq OWNED BY cases.case_id;


--
-- Name: cases_case_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('cases_case_id_seq', 1, false);


--
-- Name: category_activitys; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE category_activitys (
    category_activity_id integer NOT NULL,
    case_category_id integer,
    contact_type_id integer,
    activity_id integer,
    from_activity_id integer,
    activity_order integer,
    warning_days integer,
    deadline_days integer,
    mandatory boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.category_activitys OWNER TO root;

--
-- Name: category_activitys_category_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE category_activitys_category_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.category_activitys_category_activity_id_seq OWNER TO root;

--
-- Name: category_activitys_category_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE category_activitys_category_activity_id_seq OWNED BY category_activitys.category_activity_id;


--
-- Name: category_activitys_category_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('category_activitys_category_activity_id_seq', 16, true);


--
-- Name: checklists; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE checklists (
    checklist_id integer NOT NULL,
    org_id integer,
    workflow_phase_id integer NOT NULL,
    checklist_number integer,
    manditory boolean DEFAULT false NOT NULL,
    requirement text,
    details text
);


ALTER TABLE public.checklists OWNER TO root;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE checklists_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.checklists_checklist_id_seq OWNER TO root;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE checklists_checklist_id_seq OWNED BY checklists.checklist_id;


--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Name: constituency; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE constituency (
    constituency_id integer NOT NULL,
    county_id integer,
    constituency_name character varying(240),
    constituency_code character varying(12),
    details text
);


ALTER TABLE public.constituency OWNER TO root;

--
-- Name: constituency_constituency_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE constituency_constituency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.constituency_constituency_id_seq OWNER TO root;

--
-- Name: constituency_constituency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE constituency_constituency_id_seq OWNED BY constituency.constituency_id;


--
-- Name: constituency_constituency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('constituency_constituency_id_seq', 1, false);


--
-- Name: contact_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE contact_types (
    contact_type_id integer NOT NULL,
    contact_type_name character varying(320),
    bench boolean DEFAULT false NOT NULL,
    appeal boolean DEFAULT true NOT NULL,
    trial boolean DEFAULT true NOT NULL,
    ep boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.contact_types OWNER TO root;

--
-- Name: contact_types_contact_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE contact_types_contact_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contact_types_contact_type_id_seq OWNER TO root;

--
-- Name: contact_types_contact_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE contact_types_contact_type_id_seq OWNED BY contact_types.contact_type_id;


--
-- Name: contact_types_contact_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('contact_types_contact_type_id_seq', 18, true);


--
-- Name: counties; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE counties (
    county_id integer NOT NULL,
    region_id integer,
    county_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.counties OWNER TO root;

--
-- Name: counties_county_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE counties_county_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.counties_county_id_seq OWNER TO root;

--
-- Name: counties_county_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE counties_county_id_seq OWNED BY counties.county_id;


--
-- Name: counties_county_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('counties_county_id_seq', 48, true);


--
-- Name: court_bankings; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_bankings (
    court_banking_id integer NOT NULL,
    bank_account_id integer,
    source_account_id integer,
    org_id integer,
    bank_ref character varying(50),
    banking_date date,
    amount real,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.court_bankings OWNER TO root;

--
-- Name: court_bankings_court_banking_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_bankings_court_banking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_bankings_court_banking_id_seq OWNER TO root;

--
-- Name: court_bankings_court_banking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_bankings_court_banking_id_seq OWNED BY court_bankings.court_banking_id;


--
-- Name: court_bankings_court_banking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_bankings_court_banking_id_seq', 1, false);


--
-- Name: court_divisions; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_divisions (
    court_division_id integer NOT NULL,
    court_station_id integer,
    division_type_id integer,
    org_id integer,
    court_division_code character varying(16),
    court_division_num integer DEFAULT 1 NOT NULL,
    details text
);


ALTER TABLE public.court_divisions OWNER TO root;

--
-- Name: court_divisions_court_division_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_divisions_court_division_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_divisions_court_division_id_seq OWNER TO root;

--
-- Name: court_divisions_court_division_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_divisions_court_division_id_seq OWNED BY court_divisions.court_division_id;


--
-- Name: court_divisions_court_division_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_divisions_court_division_id_seq', 1, false);


--
-- Name: court_payments; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_payments (
    court_payment_id integer NOT NULL,
    receipt_id integer,
    payment_type_id integer,
    bank_account_id integer,
    org_id integer,
    bank_ref character varying(50),
    payment_date date,
    amount real,
    r_amount real,
    bank_code character varying(5),
    payee_name character varying(120),
    payee_account character varying(32),
    jail_days integer DEFAULT 0 NOT NULL,
    credit_note boolean DEFAULT false NOT NULL,
    refund boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.court_payments OWNER TO root;

--
-- Name: court_payments_court_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_payments_court_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_payments_court_payment_id_seq OWNER TO root;

--
-- Name: court_payments_court_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_payments_court_payment_id_seq OWNED BY court_payments.court_payment_id;


--
-- Name: court_payments_court_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_payments_court_payment_id_seq', 1, false);


--
-- Name: court_ranks; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_ranks (
    court_rank_id integer NOT NULL,
    court_rank_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.court_ranks OWNER TO root;

--
-- Name: court_ranks_court_rank_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_ranks_court_rank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_ranks_court_rank_id_seq OWNER TO root;

--
-- Name: court_ranks_court_rank_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_ranks_court_rank_id_seq OWNED BY court_ranks.court_rank_id;


--
-- Name: court_ranks_court_rank_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_ranks_court_rank_id_seq', 6, true);


--
-- Name: court_stations; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_stations (
    court_station_id integer NOT NULL,
    court_rank_id integer,
    county_id integer,
    org_id integer,
    court_station_name character varying(50),
    court_station_code character varying(50),
    district character varying(50),
    details text
);


ALTER TABLE public.court_stations OWNER TO root;

--
-- Name: court_stations_court_station_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_stations_court_station_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_stations_court_station_id_seq OWNER TO root;

--
-- Name: court_stations_court_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_stations_court_station_id_seq OWNED BY court_stations.court_station_id;


--
-- Name: court_stations_court_station_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_stations_court_station_id_seq', 100, true);


--
-- Name: currency; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE currency (
    currency_id integer NOT NULL,
    currency_name character varying(50),
    currency_symbol character varying(3)
);


ALTER TABLE public.currency OWNER TO root;

--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE currency_rates (
    currency_rate_id integer NOT NULL,
    org_id integer,
    currency_id integer,
    exchange_date timestamp without time zone DEFAULT now() NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL
);


ALTER TABLE public.currency_rates OWNER TO root;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE currency_rates_currency_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_rates_currency_rate_id_seq OWNER TO root;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE currency_rates_currency_rate_id_seq OWNED BY currency_rates.currency_rate_id;


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, false);


--
-- Name: dc_cases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE dc_cases (
    dc_case_id integer NOT NULL,
    dc_category_id integer,
    dc_judgment_id integer,
    court_division_id integer,
    entity_id integer,
    org_id integer,
    case_title character varying(320) NOT NULL,
    file_number character varying(50) NOT NULL,
    appeal boolean DEFAULT false NOT NULL,
    date_of_arrest date,
    ob_number character varying(120),
    alleged_crime text,
    start_date date NOT NULL,
    mention_date date,
    hearing_date date,
    end_date date,
    value_of_claim real,
    name_of_litigant character varying(320),
    litigant_age integer,
    male_litigants integer,
    female_litigant integer,
    number_of_witnesses integer,
    previous_conviction boolean DEFAULT false NOT NULL,
    legal_representation boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    adjournment_reason text,
    judgment_summary text,
    detail text
);


ALTER TABLE public.dc_cases OWNER TO root;

--
-- Name: dc_cases_dc_case_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE dc_cases_dc_case_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dc_cases_dc_case_id_seq OWNER TO root;

--
-- Name: dc_cases_dc_case_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE dc_cases_dc_case_id_seq OWNED BY dc_cases.dc_case_id;


--
-- Name: dc_cases_dc_case_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('dc_cases_dc_case_id_seq', 1, false);


--
-- Name: dc_category; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE dc_category (
    dc_category_id integer NOT NULL,
    dc_category_name character varying(240),
    category_type integer DEFAULT 1 NOT NULL,
    court_level integer DEFAULT 1 NOT NULL,
    children_category boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.dc_category OWNER TO root;

--
-- Name: dc_category_dc_category_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE dc_category_dc_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dc_category_dc_category_id_seq OWNER TO root;

--
-- Name: dc_category_dc_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE dc_category_dc_category_id_seq OWNED BY dc_category.dc_category_id;


--
-- Name: dc_category_dc_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('dc_category_dc_category_id_seq', 55, true);


--
-- Name: dc_judgments; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE dc_judgments (
    dc_judgment_id integer NOT NULL,
    dc_judgment_name character varying(240),
    details text
);


ALTER TABLE public.dc_judgments OWNER TO root;

--
-- Name: dc_judgments_dc_judgment_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE dc_judgments_dc_judgment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dc_judgments_dc_judgment_id_seq OWNER TO root;

--
-- Name: dc_judgments_dc_judgment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE dc_judgments_dc_judgment_id_seq OWNED BY dc_judgments.dc_judgment_id;


--
-- Name: dc_judgments_dc_judgment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('dc_judgments_dc_judgment_id_seq', 19, true);


--
-- Name: dc_receipts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE dc_receipts (
    dc_receipt_id integer NOT NULL,
    dc_case_id integer,
    receipt_type_id integer,
    org_id integer,
    receipt_for character varying(320),
    receipt_date date,
    amount real NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.dc_receipts OWNER TO root;

--
-- Name: dc_receipts_dc_receipt_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE dc_receipts_dc_receipt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dc_receipts_dc_receipt_id_seq OWNER TO root;

--
-- Name: dc_receipts_dc_receipt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE dc_receipts_dc_receipt_id_seq OWNED BY dc_receipts.dc_receipt_id;


--
-- Name: dc_receipts_dc_receipt_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('dc_receipts_dc_receipt_id_seq', 1, false);


--
-- Name: decision_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE decision_types (
    decision_type_id integer NOT NULL,
    decision_type_name character varying(320) NOT NULL,
    details text
);


ALTER TABLE public.decision_types OWNER TO root;

--
-- Name: decision_types_decision_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE decision_types_decision_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.decision_types_decision_type_id_seq OWNER TO root;

--
-- Name: decision_types_decision_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE decision_types_decision_type_id_seq OWNED BY decision_types.decision_type_id;


--
-- Name: decision_types_decision_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('decision_types_decision_type_id_seq', 6, true);


--
-- Name: disability; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE disability (
    disability_id integer NOT NULL,
    disability_name character varying(240) NOT NULL
);


ALTER TABLE public.disability OWNER TO root;

--
-- Name: disability_disability_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE disability_disability_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.disability_disability_id_seq OWNER TO root;

--
-- Name: disability_disability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE disability_disability_id_seq OWNED BY disability.disability_id;


--
-- Name: disability_disability_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('disability_disability_id_seq', 3, true);


--
-- Name: division_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE division_types (
    division_type_id integer NOT NULL,
    division_type_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.division_types OWNER TO root;

--
-- Name: division_types_division_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE division_types_division_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.division_types_division_type_id_seq OWNER TO root;

--
-- Name: division_types_division_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE division_types_division_type_id_seq OWNED BY division_types.division_type_id;


--
-- Name: division_types_division_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('division_types_division_type_id_seq', 8, true);


--
-- Name: entity_idents; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE entity_idents (
    entity_ident_id integer NOT NULL,
    entity_id integer NOT NULL,
    id_type_id integer NOT NULL,
    org_id integer NOT NULL,
    id_number character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.entity_idents OWNER TO root;

--
-- Name: entity_idents_entity_ident_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE entity_idents_entity_ident_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_idents_entity_ident_id_seq OWNER TO root;

--
-- Name: entity_idents_entity_ident_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE entity_idents_entity_ident_id_seq OWNED BY entity_idents.entity_ident_id;


--
-- Name: entity_idents_entity_ident_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('entity_idents_entity_ident_id_seq', 1, false);


--
-- Name: entity_subscriptions; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE entity_subscriptions (
    entity_subscription_id integer NOT NULL,
    org_id integer,
    entity_type_id integer NOT NULL,
    entity_id integer NOT NULL,
    subscription_level_id integer NOT NULL,
    details text
);


ALTER TABLE public.entity_subscriptions OWNER TO root;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE entity_subscriptions_entity_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_subscriptions_entity_subscription_id_seq OWNER TO root;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE entity_subscriptions_entity_subscription_id_seq OWNED BY entity_subscriptions.entity_subscription_id;


--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('entity_subscriptions_entity_subscription_id_seq', 1, false);


--
-- Name: entity_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE entity_types (
    entity_type_id integer NOT NULL,
    org_id integer,
    entity_type_name character varying(50),
    entity_role character varying(240),
    use_key integer DEFAULT 0 NOT NULL,
    start_view character varying(120),
    group_email character varying(120),
    description text,
    details text
);


ALTER TABLE public.entity_types OWNER TO root;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE entity_types_entity_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_types_entity_type_id_seq OWNER TO root;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE entity_types_entity_type_id_seq OWNED BY entity_types.entity_type_id;


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 1, false);


--
-- Name: entitys; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE entitys (
    entity_id integer NOT NULL,
    org_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    entity_name character varying(120) NOT NULL,
    user_name character varying(120),
    primary_email character varying(120),
    super_user boolean DEFAULT false NOT NULL,
    entity_leader boolean DEFAULT false NOT NULL,
    no_org boolean DEFAULT false NOT NULL,
    function_role character varying(240),
    date_enroled timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    entity_password character varying(64) DEFAULT md5('enter'::text) NOT NULL,
    first_password character varying(64) DEFAULT 'enter'::character varying NOT NULL,
    new_password character varying(64),
    start_url character varying(64),
    is_picked boolean DEFAULT false NOT NULL,
    details text,
    disability_id integer,
    court_station_id integer,
    ranking_id integer,
    id_type_id integer,
    country_aquired character(2),
    station_judge boolean DEFAULT false NOT NULL,
    is_available boolean DEFAULT true NOT NULL,
    identification character varying(50),
    gender character(1),
    date_of_birth date,
    deceased boolean DEFAULT false NOT NULL,
    date_of_death date
);


ALTER TABLE public.entitys OWNER TO root;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE entitys_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entitys_entity_id_seq OWNER TO root;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE entitys_entity_id_seq OWNED BY entitys.entity_id;


--
-- Name: entitys_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('entitys_entity_id_seq', 1, false);


--
-- Name: entry_forms; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.entry_forms OWNER TO root;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE entry_forms_entry_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entry_forms_entry_form_id_seq OWNER TO root;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE entry_forms_entry_form_id_seq OWNED BY entry_forms.entry_form_id;


--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('entry_forms_entry_form_id_seq', 1, false);


--
-- Name: fields; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.fields OWNER TO root;

--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE fields_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fields_field_id_seq OWNER TO root;

--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE fields_field_id_seq OWNED BY fields.field_id;


--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('fields_field_id_seq', 100, true);


--
-- Name: file_locations; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE file_locations (
    file_location_id integer NOT NULL,
    court_station_id integer,
    org_id integer,
    file_location_name character varying(50),
    details text
);


ALTER TABLE public.file_locations OWNER TO root;

--
-- Name: file_locations_file_location_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE file_locations_file_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.file_locations_file_location_id_seq OWNER TO root;

--
-- Name: file_locations_file_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE file_locations_file_location_id_seq OWNED BY file_locations.file_location_id;


--
-- Name: file_locations_file_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('file_locations_file_location_id_seq', 1, false);


--
-- Name: folders; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE folders (
    folder_id integer NOT NULL,
    folder_name character varying(25),
    details text
);


ALTER TABLE public.folders OWNER TO root;

--
-- Name: folders_folder_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE folders_folder_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.folders_folder_id_seq OWNER TO root;

--
-- Name: folders_folder_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE folders_folder_id_seq OWNED BY folders.folder_id;


--
-- Name: folders_folder_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('folders_folder_id_seq', 1, false);


--
-- Name: forms; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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
    default_sub_values text,
    details text
);


ALTER TABLE public.forms OWNER TO root;

--
-- Name: forms_form_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE forms_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.forms_form_id_seq OWNER TO root;

--
-- Name: forms_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE forms_form_id_seq OWNED BY forms.form_id;


--
-- Name: forms_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('forms_form_id_seq', 10, true);


--
-- Name: hearing_locations; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE hearing_locations (
    hearing_location_id integer NOT NULL,
    court_station_id integer,
    org_id integer,
    hearing_location_name character varying(50),
    details text
);


ALTER TABLE public.hearing_locations OWNER TO root;

--
-- Name: hearing_locations_hearing_location_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE hearing_locations_hearing_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hearing_locations_hearing_location_id_seq OWNER TO root;

--
-- Name: hearing_locations_hearing_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE hearing_locations_hearing_location_id_seq OWNED BY hearing_locations.hearing_location_id;


--
-- Name: hearing_locations_hearing_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('hearing_locations_hearing_location_id_seq', 1, false);


--
-- Name: id_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE id_types (
    id_type_id integer NOT NULL,
    id_type_name character varying(120) NOT NULL
);


ALTER TABLE public.id_types OWNER TO root;

--
-- Name: id_types_id_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE id_types_id_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.id_types_id_type_id_seq OWNER TO root;

--
-- Name: id_types_id_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE id_types_id_type_id_seq OWNED BY id_types.id_type_id;


--
-- Name: id_types_id_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('id_types_id_type_id_seq', 2, true);


--
-- Name: judgment_status; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE judgment_status (
    judgment_status_id integer NOT NULL,
    judgment_status_name character varying(320),
    details text
);


ALTER TABLE public.judgment_status OWNER TO root;

--
-- Name: judgment_status_judgment_status_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE judgment_status_judgment_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.judgment_status_judgment_status_id_seq OWNER TO root;

--
-- Name: judgment_status_judgment_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE judgment_status_judgment_status_id_seq OWNED BY judgment_status.judgment_status_id;


--
-- Name: judgment_status_judgment_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('judgment_status_judgment_status_id_seq', 6, true);


--
-- Name: log_case_activity; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_activity (
    log_case_activity_id integer NOT NULL,
    case_activity_id integer,
    case_id integer,
    hearing_location_id integer,
    activity_id integer,
    activity_result_id integer,
    adjorn_reason_id integer,
    order_type_id integer,
    court_station_id integer,
    appleal_case_id integer,
    org_id integer,
    activity_date date,
    activity_time time without time zone,
    finish_time time without time zone,
    shared_hearing boolean DEFAULT false NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    order_narrative character varying(320),
    order_title character varying(320),
    order_details text,
    appleal_details text,
    details text
);


ALTER TABLE public.log_case_activity OWNER TO root;

--
-- Name: log_case_activity_log_case_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_case_activity_log_case_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_case_activity_log_case_activity_id_seq OWNER TO root;

--
-- Name: log_case_activity_log_case_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_case_activity_log_case_activity_id_seq OWNED BY log_case_activity.log_case_activity_id;


--
-- Name: log_case_activity_log_case_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_case_activity_log_case_activity_id_seq', 1, false);


--
-- Name: log_case_contacts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_contacts (
    log_case_contact_id integer NOT NULL,
    case_contact_id integer,
    case_id integer,
    entity_id integer,
    contact_type_id integer,
    political_party_id integer,
    org_id integer,
    case_contact_no integer,
    is_disqualified boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.log_case_contacts OWNER TO root;

--
-- Name: log_case_contacts_log_case_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_case_contacts_log_case_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_case_contacts_log_case_contact_id_seq OWNER TO root;

--
-- Name: log_case_contacts_log_case_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_case_contacts_log_case_contact_id_seq OWNED BY log_case_contacts.log_case_contact_id;


--
-- Name: log_case_contacts_log_case_contact_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_case_contacts_log_case_contact_id_seq', 1, false);


--
-- Name: log_case_counts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_counts (
    log_case_count_id integer NOT NULL,
    case_count_id integer,
    case_contact_id integer,
    case_category_id integer,
    org_id integer,
    narrative character varying(320),
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.log_case_counts OWNER TO root;

--
-- Name: log_case_counts_log_case_count_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_case_counts_log_case_count_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_case_counts_log_case_count_id_seq OWNER TO root;

--
-- Name: log_case_counts_log_case_count_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_case_counts_log_case_count_id_seq OWNED BY log_case_counts.log_case_count_id;


--
-- Name: log_case_counts_log_case_count_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_case_counts_log_case_count_id_seq', 1, false);


--
-- Name: log_case_decisions; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_decisions (
    log_case_decision_id integer NOT NULL,
    case_decision_id integer,
    case_id integer,
    case_activity_id integer,
    case_count_id integer,
    decision_type_id integer,
    judgment_status_id integer,
    org_id integer,
    decision_summary character varying(1024),
    judgement text,
    judgement_date date,
    death_sentence boolean DEFAULT false NOT NULL,
    life_sentence boolean DEFAULT false NOT NULL,
    jail_years integer,
    jail_days integer,
    fine_amount real,
    fine_jail integer,
    canes integer,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.log_case_decisions OWNER TO root;

--
-- Name: log_case_decisions_log_case_decision_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_case_decisions_log_case_decision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_case_decisions_log_case_decision_id_seq OWNER TO root;

--
-- Name: log_case_decisions_log_case_decision_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_case_decisions_log_case_decision_id_seq OWNED BY log_case_decisions.log_case_decision_id;


--
-- Name: log_case_decisions_log_case_decision_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_case_decisions_log_case_decision_id_seq', 1, false);


--
-- Name: log_case_transfers; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_transfers (
    log_case_transfer_id integer NOT NULL,
    case_transfer_id integer,
    case_id integer,
    case_category_id integer,
    court_division_id integer,
    org_id integer,
    judgment_date date,
    presiding_judge character varying(50),
    previous_case_number character varying(25),
    receipt_date date,
    received_by character varying(50),
    case_transfered boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.log_case_transfers OWNER TO root;

--
-- Name: log_case_transfers_log_case_transfer_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_case_transfers_log_case_transfer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_case_transfers_log_case_transfer_id_seq OWNER TO root;

--
-- Name: log_case_transfers_log_case_transfer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_case_transfers_log_case_transfer_id_seq OWNED BY log_case_transfers.log_case_transfer_id;


--
-- Name: log_case_transfers_log_case_transfer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_case_transfers_log_case_transfer_id_seq', 1, false);


--
-- Name: log_cases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_cases (
    log_case_id integer NOT NULL,
    case_id integer,
    case_category_id integer,
    court_division_id integer,
    file_location_id integer,
    case_subject_id integer,
    police_station_id integer,
    new_case_id integer,
    old_case_id integer,
    constituency_id integer,
    ward_id integer,
    org_id integer,
    case_title character varying(320),
    file_number character varying(50),
    date_of_arrest date,
    ob_number character varying(120),
    holding_prison character varying(120),
    warrant_of_arrest boolean DEFAULT false NOT NULL,
    alleged_crime text,
    date_of_elections date,
    start_date date NOT NULL,
    end_date date,
    nature_of_claim character varying(320),
    value_of_claim real,
    closed boolean DEFAULT false NOT NULL,
    case_locked boolean DEFAULT false NOT NULL,
    final_decision character varying(1024),
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    detail text
);


ALTER TABLE public.log_cases OWNER TO root;

--
-- Name: log_cases_log_case_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_cases_log_case_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_cases_log_case_id_seq OWNER TO root;

--
-- Name: log_cases_log_case_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_cases_log_case_id_seq OWNED BY log_cases.log_case_id;


--
-- Name: log_cases_log_case_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_cases_log_case_id_seq', 1, false);


--
-- Name: log_court_bankings; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_court_bankings (
    log_court_banking_id integer NOT NULL,
    court_banking_id integer,
    bank_account_id integer,
    source_account_id integer,
    org_id integer,
    bank_ref character varying(50),
    banking_date date,
    amount real,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.log_court_bankings OWNER TO root;

--
-- Name: log_court_bankings_log_court_banking_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_court_bankings_log_court_banking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_court_bankings_log_court_banking_id_seq OWNER TO root;

--
-- Name: log_court_bankings_log_court_banking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_court_bankings_log_court_banking_id_seq OWNED BY log_court_bankings.log_court_banking_id;


--
-- Name: log_court_bankings_log_court_banking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_court_bankings_log_court_banking_id_seq', 1, false);


--
-- Name: log_court_payments; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_court_payments (
    log_court_payment_id integer NOT NULL,
    court_payment_id integer,
    receipt_id integer,
    payment_type_id integer,
    bank_account_id integer,
    org_id integer,
    bank_ref character varying(50),
    payment_date date,
    amount real,
    jail_days integer DEFAULT 0 NOT NULL,
    credit_note boolean DEFAULT false NOT NULL,
    refund boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.log_court_payments OWNER TO root;

--
-- Name: log_court_payments_log_court_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_court_payments_log_court_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_court_payments_log_court_payment_id_seq OWNER TO root;

--
-- Name: log_court_payments_log_court_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_court_payments_log_court_payment_id_seq OWNED BY log_court_payments.log_court_payment_id;


--
-- Name: log_court_payments_log_court_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_court_payments_log_court_payment_id_seq', 1, false);


--
-- Name: log_receipts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_receipts (
    log_receipt_id integer NOT NULL,
    receipt_id integer,
    case_id integer,
    case_decision_id integer,
    receipt_type_id integer,
    court_station_id integer,
    org_id integer,
    receipt_for character varying(320),
    case_number character varying(50) NOT NULL,
    receipt_date date,
    amount real,
    for_process boolean DEFAULT false NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.log_receipts OWNER TO root;

--
-- Name: log_receipts_log_receipt_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE log_receipts_log_receipt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_receipts_log_receipt_id_seq OWNER TO root;

--
-- Name: log_receipts_log_receipt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE log_receipts_log_receipt_id_seq OWNED BY log_receipts.log_receipt_id;


--
-- Name: log_receipts_log_receipt_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('log_receipts_log_receipt_id_seq', 1, false);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE meetings (
    meeting_id integer NOT NULL,
    org_id integer,
    meeting_name character varying(320) NOT NULL,
    start_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_date date NOT NULL,
    end_time time without time zone NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.meetings OWNER TO root;

--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE meetings_meeting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.meetings_meeting_id_seq OWNER TO root;

--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE meetings_meeting_id_seq OWNED BY meetings.meeting_id;


--
-- Name: meetings_meeting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('meetings_meeting_id_seq', 1, false);


--
-- Name: mpesa_trxs; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE mpesa_trxs (
    mpesa_trx_id integer NOT NULL,
    receipt_id integer,
    org_id integer,
    mpesa_id integer,
    mpesa_orig character varying(50),
    mpesa_dest character varying(50),
    mpesa_tstamp timestamp without time zone,
    mpesa_text character varying(320),
    mpesa_code character varying(50),
    mpesa_acc character varying(50),
    mpesa_msisdn character varying(50),
    mpesa_trx_date date,
    mpesa_trx_time time without time zone,
    mpesa_amt real,
    mpesa_sender character varying(50),
    mpesa_pick_time timestamp without time zone DEFAULT now(),
    voided boolean DEFAULT false NOT NULL,
    voided_by integer,
    voided_date timestamp without time zone
);


ALTER TABLE public.mpesa_trxs OWNER TO root;

--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE mpesa_trxs_mpesa_trx_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mpesa_trxs_mpesa_trx_id_seq OWNER TO root;

--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE mpesa_trxs_mpesa_trx_id_seq OWNED BY mpesa_trxs.mpesa_trx_id;


--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('mpesa_trxs_mpesa_trx_id_seq', 1, false);


--
-- Name: order_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE order_types (
    order_type_id integer NOT NULL,
    order_type_name character varying(320) NOT NULL,
    details text
);


ALTER TABLE public.order_types OWNER TO root;

--
-- Name: order_types_order_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE order_types_order_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.order_types_order_type_id_seq OWNER TO root;

--
-- Name: order_types_order_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE order_types_order_type_id_seq OWNED BY order_types.order_type_id;


--
-- Name: order_types_order_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('order_types_order_type_id_seq', 15, true);


--
-- Name: orgs; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE orgs (
    org_id integer NOT NULL,
    currency_id integer,
    org_name character varying(50),
    is_default boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    logo character varying(50),
    pin character varying(50),
    details text,
    bench_next integer
);


ALTER TABLE public.orgs OWNER TO root;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE orgs_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orgs_org_id_seq OWNER TO root;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE orgs_org_id_seq OWNED BY orgs.org_id;


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, false);


--
-- Name: participants; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE participants (
    participant_id integer NOT NULL,
    meeting_id integer,
    entity_id integer NOT NULL,
    org_id integer,
    meeting_role character varying(50),
    details text
);


ALTER TABLE public.participants OWNER TO root;

--
-- Name: participants_participant_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE participants_participant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.participants_participant_id_seq OWNER TO root;

--
-- Name: participants_participant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE participants_participant_id_seq OWNED BY participants.participant_id;


--
-- Name: participants_participant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('participants_participant_id_seq', 1, false);


--
-- Name: payment_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE payment_types (
    payment_type_id integer NOT NULL,
    payment_type_name character varying(320) NOT NULL,
    cash boolean DEFAULT false NOT NULL,
    non_cash boolean DEFAULT false NOT NULL,
    for_credit_note boolean DEFAULT false NOT NULL,
    for_refund boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.payment_types OWNER TO root;

--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE payment_types_payment_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payment_types_payment_type_id_seq OWNER TO root;

--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE payment_types_payment_type_id_seq OWNED BY payment_types.payment_type_id;


--
-- Name: payment_types_payment_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('payment_types_payment_type_id_seq', 5, true);


--
-- Name: picture_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE picture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.picture_id_seq OWNER TO root;

--
-- Name: picture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('picture_id_seq', 1, false);


--
-- Name: police_stations; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE police_stations (
    police_station_id integer NOT NULL,
    court_station_id integer,
    org_id integer,
    police_station_name character varying(50) NOT NULL,
    police_station_phone character varying(50),
    details text
);


ALTER TABLE public.police_stations OWNER TO root;

--
-- Name: police_stations_police_station_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE police_stations_police_station_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.police_stations_police_station_id_seq OWNER TO root;

--
-- Name: police_stations_police_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE police_stations_police_station_id_seq OWNED BY police_stations.police_station_id;


--
-- Name: police_stations_police_station_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('police_stations_police_station_id_seq', 1, false);


--
-- Name: political_parties; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE political_parties (
    political_party_id integer NOT NULL,
    political_party_name character varying(320),
    details text
);


ALTER TABLE public.political_parties OWNER TO root;

--
-- Name: political_parties_political_party_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE political_parties_political_party_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.political_parties_political_party_id_seq OWNER TO root;

--
-- Name: political_parties_political_party_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE political_parties_political_party_id_seq OWNED BY political_parties.political_party_id;


--
-- Name: political_parties_political_party_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('political_parties_political_party_id_seq', 1, false);


--
-- Name: rankings; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE rankings (
    ranking_id integer NOT NULL,
    ranking_name character varying(50) NOT NULL,
    rank_initials character varying(12),
    cap_amounts real DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.rankings OWNER TO root;

--
-- Name: rankings_ranking_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE rankings_ranking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rankings_ranking_id_seq OWNER TO root;

--
-- Name: rankings_ranking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE rankings_ranking_id_seq OWNED BY rankings.ranking_id;


--
-- Name: rankings_ranking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('rankings_ranking_id_seq', 10, true);


--
-- Name: receipt_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE receipt_types (
    receipt_type_id integer NOT NULL,
    receipt_type_name character varying(320) NOT NULL,
    receipt_type_code character varying(12) NOT NULL,
    require_refund boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.receipt_types OWNER TO root;

--
-- Name: receipt_types_receipt_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE receipt_types_receipt_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.receipt_types_receipt_type_id_seq OWNER TO root;

--
-- Name: receipt_types_receipt_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE receipt_types_receipt_type_id_seq OWNED BY receipt_types.receipt_type_id;


--
-- Name: receipt_types_receipt_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('receipt_types_receipt_type_id_seq', 14, true);


--
-- Name: receipts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE receipts (
    receipt_id integer NOT NULL,
    case_id integer,
    case_decision_id integer,
    receipt_type_id integer NOT NULL,
    court_station_id integer,
    org_id integer,
    receipt_for character varying(320),
    case_number character varying(50) NOT NULL,
    receipt_date date,
    amount real NOT NULL,
    for_process boolean DEFAULT false NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    refund_approved boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.receipts OWNER TO root;

--
-- Name: receipts_receipt_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE receipts_receipt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.receipts_receipt_id_seq OWNER TO root;

--
-- Name: receipts_receipt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE receipts_receipt_id_seq OWNED BY receipts.receipt_id;


--
-- Name: receipts_receipt_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('receipts_receipt_id_seq', 1, false);


--
-- Name: regions; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE regions (
    region_id integer NOT NULL,
    region_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.regions OWNER TO root;

--
-- Name: regions_region_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE regions_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regions_region_id_seq OWNER TO root;

--
-- Name: regions_region_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE regions_region_id_seq OWNED BY regions.region_id;


--
-- Name: regions_region_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('regions_region_id_seq', 9, true);


--
-- Name: sms; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sms (
    sms_id integer NOT NULL,
    folder_id integer,
    org_id integer,
    sms_origin character varying(25),
    sms_number character varying(25),
    sms_time timestamp without time zone DEFAULT now(),
    message_ready boolean DEFAULT false,
    sent boolean DEFAULT false,
    retries integer DEFAULT 0 NOT NULL,
    last_retry timestamp without time zone DEFAULT now(),
    message text,
    details text
);


ALTER TABLE public.sms OWNER TO root;

--
-- Name: sms_address; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sms_address (
    sms_address_id integer NOT NULL,
    sms_id integer,
    address_id integer,
    org_id integer,
    narrative character varying(240)
);


ALTER TABLE public.sms_address OWNER TO root;

--
-- Name: sms_address_sms_address_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sms_address_sms_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sms_address_sms_address_id_seq OWNER TO root;

--
-- Name: sms_address_sms_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sms_address_sms_address_id_seq OWNED BY sms_address.sms_address_id;


--
-- Name: sms_address_sms_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sms_address_sms_address_id_seq', 1, false);


--
-- Name: sms_groups; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sms_groups (
    sms_groups_id integer NOT NULL,
    sms_id integer,
    entity_type_id integer,
    org_id integer,
    narrative character varying(240)
);


ALTER TABLE public.sms_groups OWNER TO root;

--
-- Name: sms_groups_sms_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sms_groups_sms_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sms_groups_sms_groups_id_seq OWNER TO root;

--
-- Name: sms_groups_sms_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sms_groups_sms_groups_id_seq OWNED BY sms_groups.sms_groups_id;


--
-- Name: sms_groups_sms_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sms_groups_sms_groups_id_seq', 1, false);


--
-- Name: sms_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sms_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sms_sms_id_seq OWNER TO root;

--
-- Name: sms_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sms_sms_id_seq OWNED BY sms.sms_id;


--
-- Name: sms_sms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sms_sms_id_seq', 1, false);


--
-- Name: sms_trans; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sms_trans (
    sms_trans_id integer NOT NULL,
    message character varying(2400),
    origin character varying(50),
    sms_time timestamp without time zone,
    client_id character varying(50),
    msg_number character varying(50),
    code character varying(25),
    amount real,
    in_words character varying(240),
    narrative character varying(240),
    sms_id integer,
    sms_deleted boolean DEFAULT false NOT NULL,
    sms_picked boolean DEFAULT false NOT NULL,
    part_id integer,
    part_message character varying(240),
    part_no integer,
    part_count integer,
    complete boolean DEFAULT false
);


ALTER TABLE public.sms_trans OWNER TO root;

--
-- Name: sms_trans_sms_trans_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sms_trans_sms_trans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sms_trans_sms_trans_id_seq OWNER TO root;

--
-- Name: sms_trans_sms_trans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sms_trans_sms_trans_id_seq OWNED BY sms_trans.sms_trans_id;


--
-- Name: sms_trans_sms_trans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sms_trans_sms_trans_id_seq', 1, false);


--
-- Name: sub_fields; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.sub_fields OWNER TO root;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sub_fields_sub_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sub_fields_sub_field_id_seq OWNER TO root;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sub_fields_sub_field_id_seq OWNED BY sub_fields.sub_field_id;


--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sub_fields_sub_field_id_seq', 1, false);


--
-- Name: subscription_levels; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE subscription_levels (
    subscription_level_id integer NOT NULL,
    org_id integer,
    subscription_level_name character varying(50),
    details text
);


ALTER TABLE public.subscription_levels OWNER TO root;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE subscription_levels_subscription_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscription_levels_subscription_level_id_seq OWNER TO root;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE subscription_levels_subscription_level_id_seq OWNED BY subscription_levels.subscription_level_id;


--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('subscription_levels_subscription_level_id_seq', 1, false);


--
-- Name: surerity; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE surerity (
    surerity_id integer NOT NULL,
    receipts_id integer,
    org_id integer,
    surerity_name character varying(120),
    relationship character varying(120),
    id_card_no character varying(120),
    id_issued_at character varying(120),
    district character varying(120),
    location character varying(120),
    sub_location character varying(120),
    village character varying(120),
    residential_address character varying(120),
    street character varying(120),
    road character varying(120),
    avenue character varying(120),
    house_no character varying(120),
    po_box character varying(120),
    house_phone_no character varying(120),
    occupation character varying(120),
    employer character varying(120),
    work_physical_address character varying(120),
    telephone_no character varying(120),
    surerity_income character varying(120),
    other_information text,
    change_by integer,
    change_date timestamp without time zone DEFAULT now(),
    details text
);


ALTER TABLE public.surerity OWNER TO root;

--
-- Name: surerity_surerity_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE surerity_surerity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.surerity_surerity_id_seq OWNER TO root;

--
-- Name: surerity_surerity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE surerity_surerity_id_seq OWNED BY surerity.surerity_id;


--
-- Name: surerity_surerity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('surerity_surerity_id_seq', 1, false);


--
-- Name: sys_audit_details; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_audit_details (
    sys_audit_detail_id integer NOT NULL,
    sys_audit_trail_id integer,
    new_value text
);


ALTER TABLE public.sys_audit_details OWNER TO root;

--
-- Name: sys_audit_details_sys_audit_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_audit_details_sys_audit_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_audit_details_sys_audit_detail_id_seq OWNER TO root;

--
-- Name: sys_audit_details_sys_audit_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_audit_details_sys_audit_detail_id_seq OWNED BY sys_audit_details.sys_audit_detail_id;


--
-- Name: sys_audit_details_sys_audit_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_audit_details_sys_audit_detail_id_seq', 1, false);


--
-- Name: sys_audit_trail; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.sys_audit_trail OWNER TO root;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_audit_trail_sys_audit_trail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_audit_trail_sys_audit_trail_id_seq OWNER TO root;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_audit_trail_sys_audit_trail_id_seq OWNED BY sys_audit_trail.sys_audit_trail_id;


--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_audit_trail_sys_audit_trail_id_seq', 1, false);


--
-- Name: sys_continents; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_continents (
    sys_continent_id character(2) NOT NULL,
    sys_continent_name character varying(120)
);


ALTER TABLE public.sys_continents OWNER TO root;

--
-- Name: sys_countrys; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.sys_countrys OWNER TO root;

--
-- Name: sys_dashboard; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_dashboard (
    sys_dashboard_id integer NOT NULL,
    org_id integer,
    entity_id integer,
    narrative character varying(240),
    details text
);


ALTER TABLE public.sys_dashboard OWNER TO root;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_dashboard_sys_dashboard_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_dashboard_sys_dashboard_id_seq OWNER TO root;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_dashboard_sys_dashboard_id_seq OWNED BY sys_dashboard.sys_dashboard_id;


--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_dashboard_sys_dashboard_id_seq', 1, false);


--
-- Name: sys_emailed; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_emailed (
    sys_emailed_id integer NOT NULL,
    org_id integer,
    sys_email_id integer,
    table_id integer,
    table_name character varying(50),
    email_type integer DEFAULT 1 NOT NULL,
    emailed boolean DEFAULT false NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.sys_emailed OWNER TO root;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_emailed_sys_emailed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emailed_sys_emailed_id_seq OWNER TO root;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_emailed_sys_emailed_id_seq OWNED BY sys_emailed.sys_emailed_id;


--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_emailed_sys_emailed_id_seq', 1, false);


--
-- Name: sys_emails; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_emails (
    sys_email_id integer NOT NULL,
    org_id integer,
    sys_email_name character varying(50),
    title character varying(240) NOT NULL,
    details text
);


ALTER TABLE public.sys_emails OWNER TO root;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_emails_sys_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emails_sys_email_id_seq OWNER TO root;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_emails_sys_email_id_seq OWNED BY sys_emails.sys_email_id;


--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 1, false);


--
-- Name: sys_errors; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_errors (
    sys_error_id integer NOT NULL,
    sys_error character varying(240) NOT NULL,
    error_message text NOT NULL
);


ALTER TABLE public.sys_errors OWNER TO root;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_errors_sys_error_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_errors_sys_error_id_seq OWNER TO root;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_errors_sys_error_id_seq OWNED BY sys_errors.sys_error_id;


--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_errors_sys_error_id_seq', 1, false);


--
-- Name: sys_files; Type: TABLE; Schema: public; Owner: root; Tablespace: 
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


ALTER TABLE public.sys_files OWNER TO root;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_files_sys_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_files_sys_file_id_seq OWNER TO root;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_files_sys_file_id_seq OWNED BY sys_files.sys_file_id;


--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_files_sys_file_id_seq', 1, false);


--
-- Name: sys_logins; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_logins (
    sys_login_id integer NOT NULL,
    entity_id integer,
    login_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_logins OWNER TO root;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_logins_sys_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_logins_sys_login_id_seq OWNER TO root;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_logins_sys_login_id_seq OWNED BY sys_logins.sys_login_id;


--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 1, true);


--
-- Name: sys_news; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_news (
    sys_news_id integer NOT NULL,
    org_id integer,
    sys_news_group integer,
    sys_news_title character varying(240) NOT NULL,
    publish boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.sys_news OWNER TO root;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_news_sys_news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_news_sys_news_id_seq OWNER TO root;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_news_sys_news_id_seq OWNED BY sys_news.sys_news_id;


--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_news_sys_news_id_seq', 1, false);


--
-- Name: sys_queries; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_queries (
    sys_queries_id integer NOT NULL,
    org_id integer,
    sys_query_name character varying(50),
    query_date timestamp without time zone DEFAULT now() NOT NULL,
    query_text text,
    query_params text
);


ALTER TABLE public.sys_queries OWNER TO root;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_queries_sys_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_queries_sys_queries_id_seq OWNER TO root;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_queries_sys_queries_id_seq OWNED BY sys_queries.sys_queries_id;


--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_queries_sys_queries_id_seq', 1, false);


--
-- Name: sys_reset; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE sys_reset (
    sys_login_id integer NOT NULL,
    entity_id integer,
    request_email character varying(320),
    request_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_reset OWNER TO root;

--
-- Name: sys_reset_sys_login_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE sys_reset_sys_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_reset_sys_login_id_seq OWNER TO root;

--
-- Name: sys_reset_sys_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE sys_reset_sys_login_id_seq OWNED BY sys_reset.sys_login_id;


--
-- Name: sys_reset_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('sys_reset_sys_login_id_seq', 1, false);


--
-- Name: tomcat_users; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW tomcat_users AS
    SELECT entitys.user_name, entitys.entity_password, entity_types.entity_role FROM ((entity_subscriptions JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id))) JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id))) WHERE (entitys.is_active = true);


ALTER TABLE public.tomcat_users OWNER TO root;

--
-- Name: vw_address; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_address AS
    SELECT sys_countrys.sys_country_id, sys_countrys.sys_country_name, address.address_id, address.org_id, address.address_name, address.table_name, address.table_id, address.post_office_box, address.postal_code, address.premises, address.street, address.town, address.phone_number, address.extension, address.mobile, address.fax, address.email, address.is_default, address.website, address.details FROM (address JOIN sys_countrys ON ((address.sys_country_id = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_address OWNER TO root;

--
-- Name: workflows; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE workflows (
    workflow_id integer NOT NULL,
    org_id integer,
    source_entity_id integer NOT NULL,
    workflow_name character varying(240) NOT NULL,
    table_name character varying(64),
    table_link_field character varying(64),
    table_link_id integer,
    approve_email text,
    reject_email text,
    approve_file character varying(320),
    reject_file character varying(320),
    details text
);


ALTER TABLE public.workflows OWNER TO root;

--
-- Name: vw_workflows; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_workflows AS
    SELECT entity_types.entity_type_id AS source_entity_id, entity_types.entity_type_name AS source_entity_name, workflows.workflow_id, workflows.org_id, workflows.workflow_name, workflows.table_name, workflows.table_link_field, workflows.table_link_id, workflows.approve_email, workflows.reject_email, workflows.approve_file, workflows.reject_file, workflows.details FROM (workflows JOIN entity_types ON ((workflows.source_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflows OWNER TO root;

--
-- Name: workflow_phases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE workflow_phases (
    workflow_phase_id integer NOT NULL,
    org_id integer,
    workflow_id integer NOT NULL,
    approval_entity_id integer NOT NULL,
    approval_level integer DEFAULT 1 NOT NULL,
    return_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    required_approvals integer DEFAULT 1 NOT NULL,
    advice boolean DEFAULT false NOT NULL,
    notice boolean DEFAULT false NOT NULL,
    phase_narrative character varying(240),
    advice_email text,
    notice_email text,
    advice_file character varying(320),
    notice_file character varying(320),
    details text
);


ALTER TABLE public.workflow_phases OWNER TO root;

--
-- Name: vw_workflow_phases; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_workflow_phases AS
    SELECT vw_workflows.source_entity_id, vw_workflows.source_entity_name, vw_workflows.workflow_id, vw_workflows.workflow_name, vw_workflows.table_name, vw_workflows.table_link_field, vw_workflows.table_link_id, vw_workflows.approve_email, vw_workflows.reject_email, vw_workflows.approve_file, vw_workflows.reject_file, entity_types.entity_type_id AS approval_entity_id, entity_types.entity_type_name AS approval_entity_name, workflow_phases.workflow_phase_id, workflow_phases.org_id, workflow_phases.approval_level, workflow_phases.return_level, workflow_phases.escalation_days, workflow_phases.escalation_hours, workflow_phases.notice, workflow_phases.notice_email, workflow_phases.notice_file, workflow_phases.advice, workflow_phases.advice_email, workflow_phases.advice_file, workflow_phases.required_approvals, workflow_phases.phase_narrative, workflow_phases.details FROM ((workflow_phases JOIN vw_workflows ON ((workflow_phases.workflow_id = vw_workflows.workflow_id))) JOIN entity_types ON ((workflow_phases.approval_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflow_phases OWNER TO root;

--
-- Name: vw_approvals; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_approvals AS
    SELECT vw_workflow_phases.workflow_id, vw_workflow_phases.workflow_name, vw_workflow_phases.approve_email, vw_workflow_phases.reject_email, vw_workflow_phases.source_entity_id, vw_workflow_phases.source_entity_name, vw_workflow_phases.approval_entity_id, vw_workflow_phases.approval_entity_name, vw_workflow_phases.workflow_phase_id, vw_workflow_phases.approval_level, vw_workflow_phases.phase_narrative, vw_workflow_phases.return_level, vw_workflow_phases.required_approvals, vw_workflow_phases.notice, vw_workflow_phases.notice_email, vw_workflow_phases.notice_file, vw_workflow_phases.advice, vw_workflow_phases.advice_email, vw_workflow_phases.advice_file, approvals.approval_id, approvals.org_id, approvals.forward_id, approvals.table_name, approvals.table_id, approvals.completion_date, approvals.escalation_days, approvals.escalation_hours, approvals.escalation_time, approvals.application_date, approvals.approve_status, approvals.action_date, approvals.approval_narrative, approvals.to_be_done, approvals.what_is_done, approvals.review_advice, approvals.details, oe.entity_id AS org_entity_id, oe.entity_name AS org_entity_name, oe.user_name AS org_user_name, oe.primary_email AS org_primary_email, ae.entity_id AS app_entity_id, ae.entity_name AS app_entity_name, ae.user_name AS app_user_name, ae.primary_email AS app_primary_email FROM (((vw_workflow_phases JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id))) JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id))) LEFT JOIN entitys ae ON ((approvals.app_entity_id = ae.entity_id)));


ALTER TABLE public.vw_approvals OWNER TO root;

--
-- Name: vw_approvals_entitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_approvals_entitys AS
    SELECT vw_workflow_phases.workflow_id, vw_workflow_phases.workflow_name, vw_workflow_phases.source_entity_id, vw_workflow_phases.source_entity_name, vw_workflow_phases.approval_entity_id, vw_workflow_phases.approval_entity_name, vw_workflow_phases.workflow_phase_id, vw_workflow_phases.approval_level, vw_workflow_phases.notice, vw_workflow_phases.notice_email, vw_workflow_phases.notice_file, vw_workflow_phases.advice, vw_workflow_phases.advice_email, vw_workflow_phases.advice_file, vw_workflow_phases.return_level, vw_workflow_phases.required_approvals, vw_workflow_phases.phase_narrative, approvals.approval_id, approvals.org_id, approvals.forward_id, approvals.table_name, approvals.table_id, approvals.completion_date, approvals.escalation_days, approvals.escalation_hours, approvals.escalation_time, approvals.application_date, approvals.approve_status, approvals.action_date, approvals.approval_narrative, approvals.to_be_done, approvals.what_is_done, approvals.review_advice, approvals.details, oe.entity_id AS org_entity_id, oe.entity_name AS org_entity_name, oe.user_name AS org_user_name, oe.primary_email AS org_primary_email, entity_subscriptions.entity_subscription_id, entity_subscriptions.subscription_level_id, entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email FROM ((((vw_workflow_phases JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id))) JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id))) JOIN entity_subscriptions ON ((vw_workflow_phases.approval_entity_id = entity_subscriptions.entity_type_id))) JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id))) WHERE (approvals.forward_id IS NULL);


ALTER TABLE public.vw_approvals_entitys OWNER TO root;

--
-- Name: vw_banking_balances; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_banking_balances AS
    (SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 'Payment'::text AS narrative, court_payments.org_id, court_payments.bank_ref, court_payments.payment_date, CASE WHEN (court_payments.refund = false) THEN court_payments.amount ELSE (0)::real END AS debit, CASE WHEN (court_payments.refund = true) THEN court_payments.amount ELSE (0)::real END AS credit FROM (court_payments JOIN bank_accounts ON ((court_payments.bank_account_id = bank_accounts.bank_account_id))) WHERE (court_payments.credit_note = false) UNION SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 'Withdrawal'::text AS narrative, court_bankings.org_id, court_bankings.bank_ref, court_bankings.banking_date AS payment_date, (0)::real AS debit, court_bankings.amount AS credit FROM (court_bankings JOIN bank_accounts ON ((court_bankings.source_account_id = bank_accounts.bank_account_id)))) UNION SELECT bank_accounts.bank_account_id, bank_accounts.bank_account_name, 'Banking'::text AS narrative, court_bankings.org_id, court_bankings.bank_ref, court_bankings.banking_date AS payment_date, court_bankings.amount AS debit, (0)::real AS credit FROM (court_bankings JOIN bank_accounts ON ((court_bankings.bank_account_id = bank_accounts.bank_account_id)));


ALTER TABLE public.vw_banking_balances OWNER TO root;

--
-- Name: vw_bench_subjects; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_bench_subjects AS
    SELECT entitys.entity_id, entitys.entity_name, case_subjects.case_subject_id, case_subjects.case_subject_name, bench_subjects.org_id, bench_subjects.bench_subject_id, bench_subjects.proficiency, bench_subjects.details FROM ((bench_subjects JOIN case_subjects ON ((bench_subjects.case_subject_id = case_subjects.case_subject_id))) JOIN entitys ON ((bench_subjects.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_bench_subjects OWNER TO root;

--
-- Name: vw_cal_entity_blocks; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_cal_entity_blocks AS
    SELECT cal_block_types.cal_block_type_id, cal_block_types.cal_block_type_name, entitys.entity_id, entitys.entity_name, cal_entity_blocks.org_id, cal_entity_blocks.cal_entity_block_id, cal_entity_blocks.reason, cal_entity_blocks.start_date, cal_entity_blocks.start_time, cal_entity_blocks.end_date, cal_entity_blocks.end_time, cal_entity_blocks.details FROM ((cal_entity_blocks JOIN cal_block_types ON ((cal_entity_blocks.cal_block_type_id = cal_block_types.cal_block_type_id))) JOIN entitys ON ((cal_entity_blocks.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_cal_entity_blocks OWNER TO root;

--
-- Name: vw_case_category; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_category AS
    SELECT case_types.case_type_id, case_types.case_type_name, case_types.duration_unacceptable, case_types.duration_serious, case_types.duration_normal, case_types.duration_low, case_types.activity_unacceptable, case_types.activity_serious, case_types.activity_normal, case_types.activity_low, case_category.case_category_id, case_category.case_category_name, case_category.case_category_title, case_category.case_category_no, case_category.act_code, case_category.death_sentence, case_category.life_sentence, case_category.min_sentence, case_category.max_sentence, case_category.min_fine, case_category.max_fine, case_category.min_canes, case_category.max_canes, case_category.details FROM (case_category JOIN case_types ON ((case_category.case_type_id = case_types.case_type_id)));


ALTER TABLE public.vw_case_category OWNER TO root;

--
-- Name: vw_counties; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_counties AS
    SELECT regions.region_id, regions.region_name, counties.county_id, counties.county_name, counties.details FROM (counties JOIN regions ON ((counties.region_id = regions.region_id)));


ALTER TABLE public.vw_counties OWNER TO root;

--
-- Name: vw_court_stations; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_court_stations AS
    SELECT vw_counties.region_id, vw_counties.region_name, vw_counties.county_id, vw_counties.county_name, court_ranks.court_rank_id, court_ranks.court_rank_name, court_stations.court_station_id, court_stations.court_station_name, court_stations.org_id, court_stations.court_station_code, court_stations.details, (((court_ranks.court_rank_name)::text || ' : '::text) || (court_stations.court_station_name)::text) AS court_station FROM ((court_stations JOIN court_ranks ON ((court_stations.court_rank_id = court_ranks.court_rank_id))) JOIN vw_counties ON ((vw_counties.county_id = court_stations.county_id)));


ALTER TABLE public.vw_court_stations OWNER TO root;

--
-- Name: vw_court_divisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_court_divisions AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, division_types.division_type_id, division_types.division_type_name, court_divisions.org_id, court_divisions.court_division_id, court_divisions.court_division_code, court_divisions.court_division_num, court_divisions.details, ((vw_court_stations.court_station || ' : '::text) || (division_types.division_type_name)::text) AS court_division FROM ((court_divisions JOIN vw_court_stations ON ((court_divisions.court_station_id = vw_court_stations.court_station_id))) JOIN division_types ON ((court_divisions.division_type_id = division_types.division_type_id)));


ALTER TABLE public.vw_court_divisions OWNER TO root;

--
-- Name: vw_cases; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_cases AS
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, case_subjects.case_subject_id, case_subjects.case_subject_name, file_locations.file_location_id, file_locations.file_location_name, police_stations.police_station_id, police_stations.police_station_name, cases.org_id, cases.case_id, cases.old_case_id, cases.case_title, cases.file_number, cases.case_number, cases.date_of_arrest, cases.ob_number, cases.holding_prison, cases.warrant_of_arrest, cases.alleged_crime, cases.start_date, cases.date_of_elections, cases.consolidate_cases, cases.new_case_id, cases.end_date, cases.nature_of_claim, cases.value_of_claim, cases.closed, cases.final_decision, cases.detail, CASE WHEN (cases.closed = true) THEN 0 ELSE 1 END AS open_cases, CASE WHEN (cases.closed = true) THEN 1 ELSE 0 END AS closed_cases FROM (((((cases JOIN vw_case_category ON ((cases.case_category_id = vw_case_category.case_category_id))) JOIN vw_court_divisions ON ((cases.court_division_id = vw_court_divisions.court_division_id))) JOIN case_subjects ON ((cases.case_subject_id = case_subjects.case_subject_id))) LEFT JOIN file_locations ON ((cases.file_location_id = file_locations.file_location_id))) LEFT JOIN police_stations ON ((cases.police_station_id = police_stations.police_station_id)));


ALTER TABLE public.vw_cases OWNER TO root;

--
-- Name: vw_hearing_locations; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_hearing_locations AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, hearing_locations.hearing_location_id, hearing_locations.hearing_location_name, hearing_locations.org_id, hearing_locations.details, ((vw_court_stations.court_station || ' : '::text) || (hearing_locations.hearing_location_name)::text) AS hearing_location FROM (hearing_locations JOIN vw_court_stations ON ((hearing_locations.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_hearing_locations OWNER TO root;

--
-- Name: vw_case_activity; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_activity AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.case_number, vw_cases.date_of_arrest, vw_cases.date_of_elections, vw_cases.consolidate_cases, vw_cases.new_case_id, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location, activitys.activity_id, activitys.activity_name, activitys.show_on_diary, activity_results.activity_result_id, activity_results.activity_result_name, adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, order_types.order_type_id, order_types.order_type_name, vw_court_stations.court_station_id AS transfer_station_id, vw_court_stations.court_station_name AS transfer_station_name, vw_court_stations.court_station AS transfer_station, case_activity.org_id, case_activity.case_activity_id, case_activity.appleal_case_id, case_activity.activity_date, case_activity.activity_time, case_activity.finish_time, case_activity.shared_hearing, case_activity.change_by, case_activity.change_date, case_activity.order_title, case_activity.order_narrative, case_activity.order_details, case_activity.appleal_details, case_activity.details, case_activity.application_date, case_activity.approve_status, case_activity.workflow_table_id, case_activity.action_date FROM (((((((case_activity JOIN vw_cases ON ((case_activity.case_id = vw_cases.case_id))) JOIN vw_hearing_locations ON ((case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id))) JOIN activitys ON ((case_activity.activity_id = activitys.activity_id))) JOIN adjorn_reasons ON ((case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id))) LEFT JOIN activity_results ON ((case_activity.activity_result_id = activity_results.activity_result_id))) LEFT JOIN order_types ON ((case_activity.order_type_id = order_types.order_type_id))) LEFT JOIN vw_court_stations ON ((case_activity.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_case_activity OWNER TO root;

--
-- Name: vw_case_bookmarks; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_bookmarks AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.date_of_elections, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email, case_bookmarks.case_bookmark_id, case_bookmarks.org_id, case_bookmarks.entry_date, case_bookmarks.notes FROM ((vw_cases JOIN case_bookmarks ON ((vw_cases.case_id = case_bookmarks.case_id))) JOIN entitys ON ((case_bookmarks.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_case_bookmarks OWNER TO root;

--
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entitys AS
    SELECT entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email, entitys.super_user, entitys.entity_leader, entitys.no_org, entitys.function_role, entitys.date_enroled, entitys.is_active, entitys.entity_password, entitys.first_password, entitys.new_password, entitys.start_url, entitys.is_picked, entitys.country_aquired, entitys.station_judge, entitys.identification, entitys.gender, entitys.org_id, entitys.date_of_birth, entitys.deceased, entitys.date_of_death, entitys.details, entity_types.entity_type_id, entity_types.entity_type_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station, rankings.ranking_id, rankings.ranking_name, sys_countrys.sys_country_id, sys_countrys.sys_country_name, id_types.id_type_id, id_types.id_type_name, disability.disability_id, disability.disability_name FROM ((((((entitys JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id))) LEFT JOIN vw_court_stations ON ((entitys.court_station_id = vw_court_stations.court_station_id))) LEFT JOIN rankings ON ((entitys.ranking_id = rankings.ranking_id))) LEFT JOIN sys_countrys ON ((entitys.country_aquired = sys_countrys.sys_country_id))) LEFT JOIN disability ON ((entitys.disability_id = disability.disability_id))) LEFT JOIN id_types ON ((entitys.id_type_id = id_types.id_type_id)));


ALTER TABLE public.vw_entitys OWNER TO root;

--
-- Name: vw_case_contacts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_contacts AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.date_of_elections, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name, political_parties.political_party_id, political_parties.political_party_name, contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench, case_contacts.org_id, case_contacts.case_contact_id, case_contacts.case_contact_no, case_contacts.is_active, case_contacts.is_disqualified, case_contacts.change_date, case_contacts.change_by, case_contacts.election_winner, case_contacts.details FROM ((((case_contacts JOIN vw_cases ON ((case_contacts.case_id = vw_cases.case_id))) JOIN vw_entitys ON ((case_contacts.entity_id = vw_entitys.entity_id))) JOIN contact_types ON ((case_contacts.contact_type_id = contact_types.contact_type_id))) LEFT JOIN political_parties ON ((case_contacts.political_party_id = political_parties.political_party_id)));


ALTER TABLE public.vw_case_contacts OWNER TO root;

--
-- Name: vw_case_counts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_counts AS
    SELECT vw_case_contacts.region_id, vw_case_contacts.region_name, vw_case_contacts.county_id, vw_case_contacts.county_name, vw_case_contacts.court_rank_id, vw_case_contacts.court_rank_name, vw_case_contacts.court_station_id, vw_case_contacts.court_station_name, vw_case_contacts.court_station_code, vw_case_contacts.court_station, vw_case_contacts.division_type_id, vw_case_contacts.division_type_name, vw_case_contacts.court_division_id, vw_case_contacts.court_division_code, vw_case_contacts.court_division_num, vw_case_contacts.court_division, vw_case_contacts.file_location_id, vw_case_contacts.file_location_name, vw_case_contacts.police_station_id, vw_case_contacts.police_station_name, vw_case_contacts.case_id, vw_case_contacts.case_title, vw_case_contacts.file_number, vw_case_contacts.date_of_arrest, vw_case_contacts.ob_number, vw_case_contacts.holding_prison, vw_case_contacts.warrant_of_arrest, vw_case_contacts.alleged_crime, vw_case_contacts.start_date, vw_case_contacts.end_date, vw_case_contacts.nature_of_claim, vw_case_contacts.value_of_claim, vw_case_contacts.closed, vw_case_contacts.final_decision, vw_case_contacts.entity_id, vw_case_contacts.entity_name, vw_case_contacts.user_name, vw_case_contacts.primary_email, vw_case_contacts.gender, vw_case_contacts.date_of_birth, vw_case_contacts.ranking_id, vw_case_contacts.ranking_name, vw_case_contacts.contact_type_id, vw_case_contacts.contact_type_name, vw_case_contacts.bench, vw_case_contacts.case_contact_id, vw_case_contacts.case_contact_no, vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, case_counts.org_id, case_counts.case_count_id, case_counts.narrative, case_counts.detail FROM ((case_counts JOIN vw_case_contacts ON ((case_counts.case_contact_id = vw_case_contacts.case_contact_id))) JOIN vw_case_category ON ((case_counts.case_category_id = vw_case_category.case_category_id)));


ALTER TABLE public.vw_case_counts OWNER TO root;

--
-- Name: vw_case_count_decisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_count_decisions AS
    SELECT vw_case_counts.region_id, vw_case_counts.region_name, vw_case_counts.county_id, vw_case_counts.county_name, vw_case_counts.court_rank_id, vw_case_counts.court_rank_name, vw_case_counts.court_station_id, vw_case_counts.court_station_name, vw_case_counts.court_station_code, vw_case_counts.court_station, vw_case_counts.division_type_id, vw_case_counts.division_type_name, vw_case_counts.court_division_id, vw_case_counts.court_division_code, vw_case_counts.court_division_num, vw_case_counts.court_division, vw_case_counts.file_location_id, vw_case_counts.file_location_name, vw_case_counts.police_station_id, vw_case_counts.police_station_name, vw_case_counts.case_id, vw_case_counts.case_title, vw_case_counts.file_number, vw_case_counts.date_of_arrest, vw_case_counts.ob_number, vw_case_counts.holding_prison, vw_case_counts.warrant_of_arrest, vw_case_counts.alleged_crime, vw_case_counts.start_date, vw_case_counts.end_date, vw_case_counts.nature_of_claim, vw_case_counts.value_of_claim, vw_case_counts.closed, vw_case_counts.final_decision, vw_case_counts.entity_id, vw_case_counts.entity_name, vw_case_counts.user_name, vw_case_counts.primary_email, vw_case_counts.gender, vw_case_counts.date_of_birth, vw_case_counts.contact_type_id, vw_case_counts.contact_type_name, vw_case_counts.case_contact_id, vw_case_counts.case_contact_no, vw_case_counts.case_type_id, vw_case_counts.case_type_name, vw_case_counts.case_category_id, vw_case_counts.case_category_name, vw_case_counts.case_category_title, vw_case_counts.case_category_no, vw_case_counts.act_code, vw_case_counts.case_count_id, vw_case_counts.narrative, decision_types.decision_type_id, decision_types.decision_type_name, judgment_status.judgment_status_id, judgment_status.judgment_status_name, case_decisions.org_id, case_decisions.case_decision_id, case_decisions.case_activity_id, case_decisions.decision_summary, case_decisions.judgement, case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.canes, case_decisions.detail FROM (((case_decisions JOIN vw_case_counts ON ((case_decisions.case_count_id = vw_case_counts.case_count_id))) JOIN decision_types ON ((case_decisions.decision_type_id = decision_types.decision_type_id))) JOIN judgment_status ON ((case_decisions.judgment_status_id = judgment_status.judgment_status_id)));


ALTER TABLE public.vw_case_count_decisions OWNER TO root;

--
-- Name: vw_case_decisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_decisions AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.date_of_elections, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, decision_types.decision_type_id, decision_types.decision_type_name, judgment_status.judgment_status_id, judgment_status.judgment_status_name, case_decisions.org_id, case_decisions.case_decision_id, case_decisions.case_activity_id, case_decisions.decision_summary, case_decisions.judgement, case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.fine_jail, case_decisions.canes, case_decisions.detail FROM (((case_decisions JOIN vw_cases ON ((case_decisions.case_id = vw_cases.case_id))) JOIN decision_types ON ((case_decisions.decision_type_id = decision_types.decision_type_id))) JOIN judgment_status ON ((case_decisions.judgment_status_id = judgment_status.judgment_status_id)));


ALTER TABLE public.vw_case_decisions OWNER TO root;

--
-- Name: vw_case_entitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_entitys AS
    SELECT vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name, contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench, case_contacts.org_id, case_contacts.case_contact_id, case_contacts.case_id, case_contacts.case_contact_no, case_contacts.is_active, case_contacts.is_disqualified, case_contacts.change_date, case_contacts.change_by FROM ((case_contacts JOIN vw_entitys ON ((case_contacts.entity_id = vw_entitys.entity_id))) JOIN contact_types ON ((case_contacts.contact_type_id = contact_types.contact_type_id)));


ALTER TABLE public.vw_case_entitys OWNER TO root;

--
-- Name: vw_case_quorum; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_quorum AS
    SELECT vw_case_activity.case_type_id, vw_case_activity.case_type_name, vw_case_activity.case_category_id, vw_case_activity.case_category_name, vw_case_activity.case_category_title, vw_case_activity.case_category_no, vw_case_activity.act_code, vw_case_activity.region_id, vw_case_activity.region_name, vw_case_activity.county_id, vw_case_activity.county_name, vw_case_activity.court_rank_id, vw_case_activity.court_rank_name, vw_case_activity.court_station_id, vw_case_activity.court_station_name, vw_case_activity.court_station_code, vw_case_activity.court_station, vw_case_activity.division_type_id, vw_case_activity.division_type_name, vw_case_activity.court_division_id, vw_case_activity.court_division_code, vw_case_activity.court_division_num, vw_case_activity.court_division, vw_case_activity.file_location_id, vw_case_activity.file_location_name, vw_case_activity.police_station_id, vw_case_activity.police_station_name, vw_case_activity.case_id, vw_case_activity.case_title, vw_case_activity.file_number, vw_case_activity.date_of_arrest, vw_case_activity.date_of_elections, vw_case_activity.ob_number, vw_case_activity.holding_prison, vw_case_activity.warrant_of_arrest, vw_case_activity.alleged_crime, vw_case_activity.start_date, vw_case_activity.end_date, vw_case_activity.nature_of_claim, vw_case_activity.value_of_claim, vw_case_activity.closed, vw_case_activity.final_decision, vw_case_activity.hearing_location_id, vw_case_activity.hearing_location_name, vw_case_activity.hearing_location, vw_case_activity.activity_id, vw_case_activity.activity_name, vw_case_activity.show_on_diary, vw_case_activity.activity_result_id, vw_case_activity.activity_result_name, vw_case_activity.adjorn_reason_id, vw_case_activity.adjorn_reason_name, vw_case_activity.order_type_id, vw_case_activity.order_type_name, vw_case_activity.case_activity_id, vw_case_activity.activity_date, vw_case_activity.activity_time, vw_case_activity.finish_time, vw_case_activity.shared_hearing, vw_case_activity.change_by, vw_case_activity.change_date, vw_case_activity.details, vw_case_entitys.entity_id, vw_case_entitys.entity_name, vw_case_entitys.user_name, vw_case_entitys.primary_email, vw_case_entitys.gender, vw_case_entitys.date_of_birth, vw_case_entitys.ranking_id, vw_case_entitys.ranking_name, vw_case_entitys.contact_type_id, vw_case_entitys.contact_type_name, vw_case_entitys.bench, vw_case_entitys.case_contact_id, vw_case_entitys.case_contact_no, vw_case_entitys.is_active, vw_case_entitys.is_disqualified, case_quorum.org_id, case_quorum.case_quorum_id, case_quorum.narrative FROM ((vw_case_activity JOIN case_quorum ON ((vw_case_activity.case_activity_id = case_quorum.case_activity_id))) JOIN vw_case_entitys ON ((case_quorum.case_contact_id = vw_case_entitys.case_contact_id)));


ALTER TABLE public.vw_case_quorum OWNER TO root;

--
-- Name: vw_case_transfers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_transfers AS
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, case_transfers.case_id, case_transfers.org_id, case_transfers.case_transfer_id, case_transfers.judgment_date, case_transfers.presiding_judge, case_transfers.previous_case_number, case_transfers.receipt_date, case_transfers.case_transfered, case_transfers.received_by, case_transfers.change_by, case_transfers.change_date, case_transfers.details FROM ((case_transfers JOIN vw_court_divisions ON ((case_transfers.court_division_id = vw_court_divisions.court_division_id))) JOIN vw_case_category ON ((case_transfers.case_category_id = vw_case_category.case_category_id)));


ALTER TABLE public.vw_case_transfers OWNER TO root;

--
-- Name: vw_category_activitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_category_activitys AS
    SELECT case_types.case_type_id, case_types.case_type_name, case_category.case_category_id, case_category.case_category_name, activitys.activity_id, activitys.activity_name, from_activitys.activity_id AS from_activity_id, from_activitys.activity_name AS from_activity_name, contact_types.contact_type_id, contact_types.contact_type_name, category_activitys.category_activity_id, category_activitys.activity_order, category_activitys.warning_days, category_activitys.deadline_days, category_activitys.mandatory, category_activitys.details FROM (((((category_activitys JOIN case_category ON ((category_activitys.case_category_id = case_category.case_category_id))) JOIN case_types ON ((case_category.case_type_id = case_types.case_type_id))) JOIN activitys ON ((category_activitys.activity_id = activitys.activity_id))) LEFT JOIN activitys from_activitys ON ((category_activitys.from_activity_id = from_activitys.activity_id))) LEFT JOIN contact_types ON ((category_activitys.contact_type_id = contact_types.contact_type_id)));


ALTER TABLE public.vw_category_activitys OWNER TO root;

--
-- Name: vw_constituency; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_constituency AS
    SELECT vw_counties.region_id, vw_counties.region_name, vw_counties.county_id, vw_counties.county_name, constituency.constituency_id, constituency.constituency_name, constituency.constituency_code, constituency.details, (((vw_counties.county_name)::text || ', '::text) || (constituency.constituency_name)::text) AS constituency FROM (constituency JOIN vw_counties ON ((constituency.county_id = vw_counties.county_id)));


ALTER TABLE public.vw_constituency OWNER TO root;

--
-- Name: vw_court_bankings; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_court_bankings AS
    SELECT sb.bank_account_id AS source_account_id, sb.bank_account_name AS source_account_name, db.bank_account_id, db.bank_account_name, court_bankings.org_id, court_bankings.court_banking_id, court_bankings.bank_ref, court_bankings.banking_date, court_bankings.amount, court_bankings.change_by, court_bankings.change_date, court_bankings.details FROM ((court_bankings JOIN bank_accounts sb ON ((court_bankings.source_account_id = sb.bank_account_id))) JOIN bank_accounts db ON ((court_bankings.bank_account_id = db.bank_account_id)));


ALTER TABLE public.vw_court_bankings OWNER TO root;

--
-- Name: vws_court_payments; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vws_court_payments AS
    SELECT court_payments.receipt_id, sum(court_payments.amount) AS t_amount FROM court_payments GROUP BY court_payments.receipt_id;


ALTER TABLE public.vws_court_payments OWNER TO root;

--
-- Name: vws_mpesa_trxs; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vws_mpesa_trxs AS
    SELECT mpesa_trxs.receipt_id, sum(mpesa_trxs.mpesa_amt) AS t_mpesa_amt FROM mpesa_trxs GROUP BY mpesa_trxs.receipt_id;


ALTER TABLE public.vws_mpesa_trxs OWNER TO root;

--
-- Name: vw_receipts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_receipts AS
    SELECT vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, receipt_types.receipt_type_id, receipt_types.receipt_type_name, receipt_types.require_refund, receipts.org_id, receipts.case_id, receipts.case_decision_id, receipts.receipt_id, receipts.receipt_for, receipts.case_number, receipts.receipt_date, receipts.amount, receipts.approved, receipts.for_process, receipts.refund_approved, receipts.details, vws_court_payments.t_amount, vws_mpesa_trxs.t_mpesa_amt, (COALESCE(vws_court_payments.t_amount, (0)::real) + COALESCE(vws_mpesa_trxs.t_mpesa_amt, (0)::real)) AS total_paid, (receipts.amount - (COALESCE(vws_court_payments.t_amount, (0)::real) + COALESCE(vws_mpesa_trxs.t_mpesa_amt, (0)::real))) AS balance FROM ((((receipts JOIN vw_court_stations ON ((receipts.court_station_id = vw_court_stations.court_station_id))) JOIN receipt_types ON ((receipts.receipt_type_id = receipt_types.receipt_type_id))) LEFT JOIN vws_court_payments ON ((receipts.receipt_id = vws_court_payments.receipt_id))) LEFT JOIN vws_mpesa_trxs ON ((receipts.receipt_id = vws_mpesa_trxs.receipt_id)));


ALTER TABLE public.vw_receipts OWNER TO root;

--
-- Name: vw_court_payments; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_court_payments AS
    SELECT vw_receipts.court_rank_id, vw_receipts.court_rank_name, vw_receipts.court_station_id, vw_receipts.court_station_name, vw_receipts.receipt_type_id, vw_receipts.receipt_type_name, vw_receipts.require_refund, vw_receipts.case_id, vw_receipts.case_decision_id, vw_receipts.receipt_id, vw_receipts.receipt_for, vw_receipts.case_number, vw_receipts.receipt_date, vw_receipts.amount AS receipt_amount, vw_receipts.approved, vw_receipts.for_process, vw_receipts.refund_approved, vw_receipts.t_amount, vw_receipts.t_mpesa_amt, vw_receipts.total_paid, vw_receipts.balance, bank_accounts.bank_account_id, bank_accounts.bank_account_name, payment_types.payment_type_id, payment_types.payment_type_name, court_payments.org_id, court_payments.court_payment_id, court_payments.bank_ref, court_payments.payment_date, court_payments.amount, court_payments.r_amount, court_payments.jail_days, court_payments.credit_note, court_payments.refund, court_payments.is_active, court_payments.change_by, court_payments.change_date, court_payments.details FROM (((vw_receipts JOIN court_payments ON ((vw_receipts.receipt_id = court_payments.receipt_id))) JOIN bank_accounts ON ((court_payments.bank_account_id = bank_accounts.bank_account_id))) JOIN payment_types ON ((court_payments.payment_type_id = payment_types.payment_type_id)));


ALTER TABLE public.vw_court_payments OWNER TO root;

--
-- Name: vw_dc_cases; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_dc_cases AS
    SELECT dc_category.dc_category_id, dc_category.dc_category_name, dc_category.category_type, dc_category.court_level, dc_judgments.dc_judgment_id, dc_judgments.dc_judgment_name, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, entitys.entity_id, entitys.entity_name, dc_cases.org_id, dc_cases.dc_case_id, dc_cases.case_title, dc_cases.file_number, dc_cases.date_of_arrest, dc_cases.ob_number, dc_cases.alleged_crime, dc_cases.start_date, dc_cases.mention_date, dc_cases.hearing_date, dc_cases.end_date, dc_cases.value_of_claim, dc_cases.name_of_litigant, dc_cases.litigant_age, dc_cases.male_litigants, dc_cases.female_litigant, dc_cases.number_of_witnesses, dc_cases.previous_conviction, dc_cases.legal_representation, dc_cases.closed, dc_cases.change_by, dc_cases.change_date, dc_cases.adjournment_reason, dc_cases.judgment_summary, dc_cases.appeal, dc_cases.detail FROM ((((dc_cases JOIN dc_category ON ((dc_cases.dc_category_id = dc_category.dc_category_id))) JOIN dc_judgments ON ((dc_cases.dc_judgment_id = dc_judgments.dc_judgment_id))) JOIN vw_court_divisions ON ((dc_cases.court_division_id = vw_court_divisions.court_division_id))) JOIN entitys ON ((dc_cases.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_dc_cases OWNER TO root;

--
-- Name: vw_dc_receipts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_dc_receipts AS
    SELECT vw_dc_cases.dc_category_id, vw_dc_cases.dc_category_name, vw_dc_cases.region_id, vw_dc_cases.region_name, vw_dc_cases.county_id, vw_dc_cases.county_name, vw_dc_cases.court_rank_id, vw_dc_cases.court_rank_name, vw_dc_cases.court_station_id, vw_dc_cases.court_station_name, vw_dc_cases.court_station_code, vw_dc_cases.court_station, vw_dc_cases.division_type_id, vw_dc_cases.division_type_name, vw_dc_cases.court_division_id, vw_dc_cases.court_division_code, vw_dc_cases.court_division_num, vw_dc_cases.court_division, vw_dc_cases.dc_judgment_id, vw_dc_cases.dc_judgment_name, vw_dc_cases.entity_id, vw_dc_cases.entity_name, vw_dc_cases.dc_case_id, vw_dc_cases.case_title, vw_dc_cases.file_number, vw_dc_cases.date_of_arrest, vw_dc_cases.ob_number, vw_dc_cases.alleged_crime, vw_dc_cases.start_date, vw_dc_cases.mention_date, vw_dc_cases.hearing_date, vw_dc_cases.end_date, vw_dc_cases.value_of_claim, vw_dc_cases.name_of_litigant, vw_dc_cases.litigant_age, vw_dc_cases.male_litigants, vw_dc_cases.female_litigant, vw_dc_cases.number_of_witnesses, vw_dc_cases.previous_conviction, vw_dc_cases.legal_representation, vw_dc_cases.closed, vw_dc_cases.adjournment_reason, vw_dc_cases.judgment_summary, receipt_types.receipt_type_id, receipt_types.receipt_type_name, dc_receipts.org_id, dc_receipts.dc_receipt_id, dc_receipts.receipt_for, dc_receipts.receipt_date, dc_receipts.amount, dc_receipts.change_by, dc_receipts.change_date, dc_receipts.details FROM ((dc_receipts JOIN vw_dc_cases ON ((dc_receipts.dc_case_id = vw_dc_cases.dc_case_id))) JOIN receipt_types ON ((dc_receipts.receipt_type_id = receipt_types.receipt_type_id)));


ALTER TABLE public.vw_dc_receipts OWNER TO root;

--
-- Name: vw_entity_address; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entity_address AS
    SELECT orgs.org_id, orgs.org_name, vw_address.address_id, vw_address.address_name, vw_address.sys_country_id, vw_address.sys_country_name, vw_address.table_name, vw_address.is_default, vw_address.post_office_box, vw_address.postal_code, vw_address.premises, vw_address.street, vw_address.town, vw_address.phone_number, vw_address.extension, vw_address.mobile, vw_address.fax, vw_address.email, vw_address.website, entity_types.entity_type_id, entity_types.entity_type_name, entity_types.entity_role, entity_types.group_email, entity_types.use_key, entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.super_user, entitys.entity_leader, entitys.date_enroled, entitys.is_active, entitys.entity_password, entitys.first_password, entitys.primary_email, entitys.function_role, entitys.details FROM (((entitys LEFT JOIN vw_address ON ((entitys.entity_id = vw_address.table_id))) JOIN orgs ON ((entitys.org_id = orgs.org_id))) JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id))) WHERE (((vw_address.table_name)::text = 'entitys'::text) OR (vw_address.table_name IS NULL));


ALTER TABLE public.vw_entity_address OWNER TO root;

--
-- Name: vw_entity_idents; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entity_idents AS
    SELECT entitys.entity_id, entitys.entity_name, id_types.id_type_id, id_types.id_type_name, entity_idents.org_id, entity_idents.entity_ident_id, entity_idents.id_number, entity_idents.details FROM ((entity_idents JOIN entitys ON ((entity_idents.entity_id = entitys.entity_id))) JOIN id_types ON ((entity_idents.id_type_id = id_types.id_type_id)));


ALTER TABLE public.vw_entity_idents OWNER TO root;

--
-- Name: vw_entity_subscriptions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entity_subscriptions AS
    SELECT entity_types.entity_type_id, entity_types.entity_type_name, entitys.entity_id, entitys.entity_name, subscription_levels.subscription_level_id, subscription_levels.subscription_level_name, entity_subscriptions.entity_subscription_id, entity_subscriptions.org_id, entity_subscriptions.details FROM (((entity_subscriptions JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id))) JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id))) JOIN subscription_levels ON ((entity_subscriptions.subscription_level_id = subscription_levels.subscription_level_id)));


ALTER TABLE public.vw_entity_subscriptions OWNER TO root;

--
-- Name: vw_entry_forms; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entry_forms AS
    SELECT entitys.entity_id, entitys.entity_name, forms.form_id, forms.form_name, entry_forms.entry_form_id, entry_forms.org_id, entry_forms.approve_status, entry_forms.application_date, entry_forms.completion_date, entry_forms.action_date, entry_forms.narrative, entry_forms.answer, entry_forms.workflow_table_id, entry_forms.details FROM ((entry_forms JOIN entitys ON ((entry_forms.entity_id = entitys.entity_id))) JOIN forms ON ((entry_forms.form_id = forms.form_id)));


ALTER TABLE public.vw_entry_forms OWNER TO root;

--
-- Name: vw_fields; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_fields AS
    SELECT forms.form_id, forms.form_name, fields.field_id, fields.org_id, fields.question, fields.field_lookup, fields.field_type, fields.field_order, fields.share_line, fields.field_size, fields.field_fnct, fields.manditory, fields.field_bold, fields.field_italics FROM (fields JOIN forms ON ((fields.form_id = forms.form_id)));


ALTER TABLE public.vw_fields OWNER TO root;

--
-- Name: vw_file_locations; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_file_locations AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, file_locations.file_location_id, file_locations.file_location_name, file_locations.org_id, file_locations.details, ((vw_court_stations.court_station || ' : '::text) || (file_locations.file_location_name)::text) AS file_location FROM (file_locations JOIN vw_court_stations ON ((file_locations.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_file_locations OWNER TO root;

--
-- Name: vw_log_case_activity; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_activity AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location, activitys.activity_id, activitys.activity_name, activity_results.activity_result_id, activity_results.activity_result_name, adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, order_types.order_type_id, order_types.order_type_name, log_case_activity.org_id, log_case_activity.case_activity_id, log_case_activity.log_case_activity_id, log_case_activity.activity_date, log_case_activity.activity_time, log_case_activity.finish_time, log_case_activity.shared_hearing, log_case_activity.change_by, log_case_activity.change_date, log_case_activity.details FROM ((((((log_case_activity JOIN vw_cases ON ((log_case_activity.case_id = vw_cases.case_id))) JOIN vw_hearing_locations ON ((log_case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id))) JOIN activitys ON ((log_case_activity.activity_id = activitys.activity_id))) JOIN activity_results ON ((log_case_activity.activity_result_id = activity_results.activity_result_id))) JOIN adjorn_reasons ON ((log_case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id))) LEFT JOIN order_types ON ((log_case_activity.order_type_id = order_types.order_type_id)));


ALTER TABLE public.vw_log_case_activity OWNER TO root;

--
-- Name: vw_log_case_contacts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_contacts AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name, contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench, log_case_contacts.case_contact_id, log_case_contacts.org_id, log_case_contacts.log_case_contact_id, log_case_contacts.case_contact_no, log_case_contacts.is_active, log_case_contacts.is_disqualified, log_case_contacts.change_date, log_case_contacts.change_by, log_case_contacts.details FROM (((log_case_contacts JOIN vw_cases ON ((log_case_contacts.case_id = vw_cases.case_id))) JOIN vw_entitys ON ((log_case_contacts.entity_id = vw_entitys.entity_id))) JOIN contact_types ON ((log_case_contacts.contact_type_id = contact_types.contact_type_id)));


ALTER TABLE public.vw_log_case_contacts OWNER TO root;

--
-- Name: vw_log_case_counts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_counts AS
    SELECT vw_case_contacts.region_id, vw_case_contacts.region_name, vw_case_contacts.county_id, vw_case_contacts.county_name, vw_case_contacts.court_rank_id, vw_case_contacts.court_rank_name, vw_case_contacts.court_station_id, vw_case_contacts.court_station_name, vw_case_contacts.court_station_code, vw_case_contacts.court_station, vw_case_contacts.division_type_id, vw_case_contacts.division_type_name, vw_case_contacts.court_division_id, vw_case_contacts.court_division_code, vw_case_contacts.court_division_num, vw_case_contacts.court_division, vw_case_contacts.file_location_id, vw_case_contacts.file_location_name, vw_case_contacts.police_station_id, vw_case_contacts.police_station_name, vw_case_contacts.case_id, vw_case_contacts.case_title, vw_case_contacts.file_number, vw_case_contacts.date_of_arrest, vw_case_contacts.ob_number, vw_case_contacts.holding_prison, vw_case_contacts.warrant_of_arrest, vw_case_contacts.alleged_crime, vw_case_contacts.start_date, vw_case_contacts.end_date, vw_case_contacts.nature_of_claim, vw_case_contacts.value_of_claim, vw_case_contacts.closed, vw_case_contacts.final_decision, vw_case_contacts.entity_id, vw_case_contacts.entity_name, vw_case_contacts.user_name, vw_case_contacts.primary_email, vw_case_contacts.gender, vw_case_contacts.date_of_birth, vw_case_contacts.ranking_id, vw_case_contacts.ranking_name, vw_case_contacts.contact_type_id, vw_case_contacts.contact_type_name, vw_case_contacts.bench, vw_case_contacts.case_contact_id, vw_case_contacts.case_contact_no, vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, log_case_counts.log_case_count_id, log_case_counts.org_id, log_case_counts.case_count_id, log_case_counts.narrative, log_case_counts.detail FROM ((log_case_counts JOIN vw_case_contacts ON ((log_case_counts.case_contact_id = vw_case_contacts.case_contact_id))) JOIN vw_case_category ON ((log_case_counts.case_category_id = vw_case_category.case_category_id)));


ALTER TABLE public.vw_log_case_counts OWNER TO root;

--
-- Name: vw_log_case_decisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_decisions AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.holding_prison, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, decision_types.decision_type_id, decision_types.decision_type_name, judgment_status.judgment_status_id, judgment_status.judgment_status_name, log_case_decisions.case_activity_id, log_case_decisions.log_case_decision_id, log_case_decisions.org_id, log_case_decisions.case_decision_id, log_case_decisions.decision_summary, log_case_decisions.judgement, log_case_decisions.judgement_date, log_case_decisions.death_sentence, log_case_decisions.life_sentence, log_case_decisions.jail_years, log_case_decisions.jail_days, log_case_decisions.fine_amount, log_case_decisions.canes, log_case_decisions.detail FROM (((log_case_decisions JOIN vw_cases ON ((log_case_decisions.case_id = vw_cases.case_id))) JOIN decision_types ON ((log_case_decisions.decision_type_id = decision_types.decision_type_id))) JOIN judgment_status ON ((log_case_decisions.judgment_status_id = judgment_status.judgment_status_id)));


ALTER TABLE public.vw_log_case_decisions OWNER TO root;

--
-- Name: vw_log_case_transfers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_transfers AS
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, log_case_transfers.log_case_transfer_id, log_case_transfers.case_id, log_case_transfers.org_id, log_case_transfers.case_transfer_id, log_case_transfers.judgment_date, log_case_transfers.presiding_judge, log_case_transfers.previous_case_number, log_case_transfers.receipt_date, log_case_transfers.received_by, log_case_transfers.change_by, log_case_transfers.change_date, log_case_transfers.details FROM ((log_case_transfers JOIN vw_court_divisions ON ((log_case_transfers.court_division_id = vw_court_divisions.court_division_id))) JOIN vw_case_category ON ((log_case_transfers.case_category_id = vw_case_category.case_category_id)));


ALTER TABLE public.vw_log_case_transfers OWNER TO root;

--
-- Name: vw_log_cases; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_cases AS
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, case_subjects.case_subject_id, case_subjects.case_subject_name, file_locations.file_location_id, file_locations.file_location_name, police_stations.police_station_id, police_stations.police_station_name, log_cases.org_id, log_cases.case_id, log_cases.log_case_id, log_cases.case_title, log_cases.file_number, log_cases.date_of_arrest, log_cases.ob_number, log_cases.holding_prison, log_cases.warrant_of_arrest, log_cases.alleged_crime, log_cases.start_date, log_cases.end_date, log_cases.nature_of_claim, log_cases.value_of_claim, log_cases.closed, log_cases.final_decision, log_cases.change_date, log_cases.change_by, log_cases.detail FROM (((((log_cases JOIN vw_case_category ON ((log_cases.case_category_id = vw_case_category.case_category_id))) JOIN vw_court_divisions ON ((log_cases.court_division_id = vw_court_divisions.court_division_id))) JOIN case_subjects ON ((log_cases.case_subject_id = case_subjects.case_subject_id))) LEFT JOIN file_locations ON ((log_cases.file_location_id = file_locations.file_location_id))) LEFT JOIN police_stations ON ((log_cases.police_station_id = police_stations.police_station_id)));


ALTER TABLE public.vw_log_cases OWNER TO root;

--
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_orgs AS
    SELECT orgs.org_id, orgs.org_name, orgs.is_default, orgs.is_active, orgs.logo, orgs.details, vw_address.sys_country_id, vw_address.sys_country_name, vw_address.address_id, vw_address.table_name, vw_address.post_office_box, vw_address.postal_code, vw_address.premises, vw_address.street, vw_address.town, vw_address.phone_number, vw_address.extension, vw_address.mobile, vw_address.fax, vw_address.email, vw_address.website FROM (orgs LEFT JOIN vw_address ON ((orgs.org_id = vw_address.table_id))) WHERE (((vw_address.table_name)::text = 'orgs'::text) OR (vw_address.table_name IS NULL));


ALTER TABLE public.vw_orgs OWNER TO root;

--
-- Name: vw_participants; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_participants AS
    SELECT meetings.meeting_id, meetings.meeting_name, meetings.start_date, meetings.start_time, meetings.end_date, meetings.end_time, meetings.completed, entitys.entity_id, entitys.entity_name, participants.org_id, participants.participant_id, participants.meeting_role, participants.details FROM ((participants JOIN meetings ON ((participants.meeting_id = meetings.meeting_id))) JOIN entitys ON ((participants.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_participants OWNER TO root;

--
-- Name: vw_police_stations; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_police_stations AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, police_stations.org_id, police_stations.police_station_id, police_stations.police_station_name, police_stations.police_station_phone, police_stations.details FROM (police_stations JOIN vw_court_stations ON ((police_stations.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_police_stations OWNER TO root;

--
-- Name: vw_sms; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sms AS
    SELECT folders.folder_id, folders.folder_name, sms.sms_id, sms.sms_number, sms.org_id, sms.message_ready, sms.sent, sms.message, sms.details, vw_entity_address.entity_name, vw_entity_address.mobile FROM ((sms JOIN folders ON ((sms.folder_id = folders.folder_id))) LEFT JOIN vw_entity_address ON (((sms.sms_number)::text = (vw_entity_address.mobile)::text)));


ALTER TABLE public.vw_sms OWNER TO root;

--
-- Name: vw_sms_address; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sms_address AS
    SELECT vw_entity_address.entity_name, vw_entity_address.mobile, sms_address.sms_address_id, sms_address.sms_id, sms_address.org_id, sms_address.narrative FROM (vw_entity_address JOIN sms_address ON ((vw_entity_address.address_id = sms_address.address_id)));


ALTER TABLE public.vw_sms_address OWNER TO root;

--
-- Name: vw_sms_groups; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sms_groups AS
    SELECT entity_types.entity_type_id, entity_types.entity_type_name, sms_groups.sms_groups_id, sms_groups.sms_id, sms_groups.org_id, sms_groups.narrative FROM (entity_types JOIN sms_groups ON ((entity_types.entity_type_id = sms_groups.entity_type_id)));


ALTER TABLE public.vw_sms_groups OWNER TO root;

--
-- Name: vw_sub_fields; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sub_fields AS
    SELECT vw_fields.form_id, vw_fields.form_name, vw_fields.field_id, sub_fields.sub_field_id, sub_fields.org_id, sub_fields.sub_field_order, sub_fields.sub_title_share, sub_fields.sub_field_type, sub_fields.sub_field_lookup, sub_fields.sub_field_size, sub_fields.sub_col_spans, sub_fields.manditory, sub_fields.question FROM (sub_fields JOIN vw_fields ON ((sub_fields.field_id = vw_fields.field_id)));


ALTER TABLE public.vw_sub_fields OWNER TO root;

--
-- Name: vw_sys_countrys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sys_countrys AS
    SELECT sys_continents.sys_continent_id, sys_continents.sys_continent_name, sys_countrys.sys_country_id, sys_countrys.sys_country_code, sys_countrys.sys_country_number, sys_countrys.sys_phone_code, sys_countrys.sys_country_name FROM (sys_continents JOIN sys_countrys ON ((sys_continents.sys_continent_id = sys_countrys.sys_continent_id)));


ALTER TABLE public.vw_sys_countrys OWNER TO root;

--
-- Name: vw_sys_emailed; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_sys_emailed AS
    SELECT sys_emails.sys_email_id, sys_emails.org_id, sys_emails.sys_email_name, sys_emails.title, sys_emails.details, sys_emailed.sys_emailed_id, sys_emailed.table_id, sys_emailed.table_name, sys_emailed.email_type, sys_emailed.emailed, sys_emailed.narrative FROM (sys_emails RIGHT JOIN sys_emailed ON ((sys_emails.sys_email_id = sys_emailed.sys_email_id)));


ALTER TABLE public.vw_sys_emailed OWNER TO root;

--
-- Name: wards; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE wards (
    ward_id integer NOT NULL,
    constituency_id integer,
    ward_name character varying(240),
    ward_code character varying(12),
    details text
);


ALTER TABLE public.wards OWNER TO root;

--
-- Name: vw_wards; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_wards AS
    SELECT vw_constituency.region_id, vw_constituency.region_name, vw_constituency.county_id, vw_constituency.county_name, vw_constituency.constituency_id, vw_constituency.constituency_name, vw_constituency.constituency_code, wards.ward_id, wards.ward_name, wards.ward_code, wards.details, ((vw_constituency.constituency || ', '::text) || (wards.ward_name)::text) AS ward FROM (wards JOIN vw_constituency ON ((wards.constituency_id = vw_constituency.constituency_id)));


ALTER TABLE public.vw_wards OWNER TO root;

--
-- Name: vw_workflow_approvals; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_workflow_approvals AS
    SELECT vw_approvals.workflow_id, vw_approvals.org_id, vw_approvals.workflow_name, vw_approvals.approve_email, vw_approvals.reject_email, vw_approvals.source_entity_id, vw_approvals.source_entity_name, vw_approvals.table_name, vw_approvals.table_id, vw_approvals.org_entity_id, vw_approvals.org_entity_name, vw_approvals.org_user_name, vw_approvals.org_primary_email, rt.rejected_count, CASE WHEN (rt.rejected_count IS NULL) THEN ((vw_approvals.workflow_name)::text || ' Approved'::text) ELSE ((vw_approvals.workflow_name)::text || ' Rejected'::text) END AS workflow_narrative FROM (vw_approvals LEFT JOIN (SELECT approvals.table_id, count(approvals.approval_id) AS rejected_count FROM approvals WHERE (((approvals.approve_status)::text = 'Rejected'::text) AND (approvals.forward_id IS NULL)) GROUP BY approvals.table_id) rt ON ((vw_approvals.table_id = rt.table_id))) GROUP BY vw_approvals.workflow_id, vw_approvals.org_id, vw_approvals.workflow_name, vw_approvals.approve_email, vw_approvals.reject_email, vw_approvals.source_entity_id, vw_approvals.source_entity_name, vw_approvals.table_name, vw_approvals.table_id, vw_approvals.org_entity_id, vw_approvals.org_entity_name, vw_approvals.org_user_name, vw_approvals.org_primary_email, rt.rejected_count;


ALTER TABLE public.vw_workflow_approvals OWNER TO root;

--
-- Name: vw_workflow_entitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_workflow_entitys AS
    SELECT vw_workflow_phases.workflow_id, vw_workflow_phases.org_id, vw_workflow_phases.workflow_name, vw_workflow_phases.table_name, vw_workflow_phases.table_link_id, vw_workflow_phases.source_entity_id, vw_workflow_phases.source_entity_name, vw_workflow_phases.approval_entity_id, vw_workflow_phases.approval_entity_name, vw_workflow_phases.workflow_phase_id, vw_workflow_phases.approval_level, vw_workflow_phases.return_level, vw_workflow_phases.escalation_days, vw_workflow_phases.escalation_hours, vw_workflow_phases.notice, vw_workflow_phases.notice_email, vw_workflow_phases.notice_file, vw_workflow_phases.advice, vw_workflow_phases.advice_email, vw_workflow_phases.advice_file, vw_workflow_phases.required_approvals, vw_workflow_phases.phase_narrative, entity_subscriptions.entity_subscription_id, entity_subscriptions.entity_id, entity_subscriptions.subscription_level_id FROM (vw_workflow_phases JOIN entity_subscriptions ON ((vw_workflow_phases.source_entity_id = entity_subscriptions.entity_type_id)));


ALTER TABLE public.vw_workflow_entitys OWNER TO root;

--
-- Name: wards_ward_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE wards_ward_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.wards_ward_id_seq OWNER TO root;

--
-- Name: wards_ward_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE wards_ward_id_seq OWNED BY wards.ward_id;


--
-- Name: wards_ward_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('wards_ward_id_seq', 1, false);


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE workflow_phases_workflow_phase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_phases_workflow_phase_id_seq OWNER TO root;

--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE workflow_phases_workflow_phase_id_seq OWNED BY workflow_phases.workflow_phase_id;


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 1, false);


--
-- Name: workflow_sql; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE workflow_sql (
    workflow_sql_id integer NOT NULL,
    org_id integer,
    workflow_phase_id integer NOT NULL,
    workflow_sql_name character varying(50),
    is_condition boolean DEFAULT false,
    is_action boolean DEFAULT false,
    message_number character varying(32),
    ca_sql text
);


ALTER TABLE public.workflow_sql OWNER TO root;

--
-- Name: workflow_table_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE workflow_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_table_id_seq OWNER TO root;

--
-- Name: workflow_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('workflow_table_id_seq', 1, false);


--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE workflows_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflows_workflow_id_seq OWNER TO root;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE workflows_workflow_id_seq OWNED BY workflows.workflow_id;


--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('workflows_workflow_id_seq', 1, false);


--
-- Name: activity_result_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE activity_results ALTER COLUMN activity_result_id SET DEFAULT nextval('activity_results_activity_result_id_seq'::regclass);


--
-- Name: activity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE activitys ALTER COLUMN activity_id SET DEFAULT nextval('activitys_activity_id_seq'::regclass);


--
-- Name: address_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE address ALTER COLUMN address_id SET DEFAULT nextval('address_address_id_seq'::regclass);


--
-- Name: address_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE address_types ALTER COLUMN address_type_id SET DEFAULT nextval('address_types_address_type_id_seq'::regclass);


--
-- Name: adjorn_reason_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE adjorn_reasons ALTER COLUMN adjorn_reason_id SET DEFAULT nextval('adjorn_reasons_adjorn_reason_id_seq'::regclass);


--
-- Name: approval_checklist_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE approval_checklists ALTER COLUMN approval_checklist_id SET DEFAULT nextval('approval_checklists_approval_checklist_id_seq'::regclass);


--
-- Name: approval_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE approvals ALTER COLUMN approval_id SET DEFAULT nextval('approvals_approval_id_seq'::regclass);


--
-- Name: bank_account_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE bank_accounts ALTER COLUMN bank_account_id SET DEFAULT nextval('bank_accounts_bank_account_id_seq'::regclass);


--
-- Name: bench_subject_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE bench_subjects ALTER COLUMN bench_subject_id SET DEFAULT nextval('bench_subjects_bench_subject_id_seq'::regclass);


--
-- Name: cal_block_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE cal_block_types ALTER COLUMN cal_block_type_id SET DEFAULT nextval('cal_block_types_cal_block_type_id_seq'::regclass);


--
-- Name: cal_entity_block_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE cal_entity_blocks ALTER COLUMN cal_entity_block_id SET DEFAULT nextval('cal_entity_blocks_cal_entity_block_id_seq'::regclass);


--
-- Name: cal_holiday_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE cal_holidays ALTER COLUMN cal_holiday_id SET DEFAULT nextval('cal_holidays_cal_holiday_id_seq'::regclass);


--
-- Name: case_activity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_activity ALTER COLUMN case_activity_id SET DEFAULT nextval('case_activity_case_activity_id_seq'::regclass);


--
-- Name: case_bookmark_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_bookmarks ALTER COLUMN case_bookmark_id SET DEFAULT nextval('case_bookmarks_case_bookmark_id_seq'::regclass);


--
-- Name: case_category_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_category ALTER COLUMN case_category_id SET DEFAULT nextval('case_category_case_category_id_seq'::regclass);


--
-- Name: case_contact_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_contacts ALTER COLUMN case_contact_id SET DEFAULT nextval('case_contacts_case_contact_id_seq'::regclass);


--
-- Name: case_count_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_counts ALTER COLUMN case_count_id SET DEFAULT nextval('case_counts_case_count_id_seq'::regclass);


--
-- Name: case_decision_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_decisions ALTER COLUMN case_decision_id SET DEFAULT nextval('case_decisions_case_decision_id_seq'::regclass);


--
-- Name: case_file_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_files ALTER COLUMN case_file_id SET DEFAULT nextval('case_files_case_file_id_seq'::regclass);


--
-- Name: case_insurance_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_insurance ALTER COLUMN case_insurance_id SET DEFAULT nextval('case_insurance_case_insurance_id_seq'::regclass);


--
-- Name: case_note_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_notes ALTER COLUMN case_note_id SET DEFAULT nextval('case_notes_case_note_id_seq'::regclass);


--
-- Name: case_quorum_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_quorum ALTER COLUMN case_quorum_id SET DEFAULT nextval('case_quorum_case_quorum_id_seq'::regclass);


--
-- Name: case_subject_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_subjects ALTER COLUMN case_subject_id SET DEFAULT nextval('case_subjects_case_subject_id_seq'::regclass);


--
-- Name: case_transfer_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_transfers ALTER COLUMN case_transfer_id SET DEFAULT nextval('case_transfers_case_transfer_id_seq'::regclass);


--
-- Name: case_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_types ALTER COLUMN case_type_id SET DEFAULT nextval('case_types_case_type_id_seq'::regclass);


--
-- Name: case_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE cases ALTER COLUMN case_id SET DEFAULT nextval('cases_case_id_seq'::regclass);


--
-- Name: category_activity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE category_activitys ALTER COLUMN category_activity_id SET DEFAULT nextval('category_activitys_category_activity_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: constituency_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE constituency ALTER COLUMN constituency_id SET DEFAULT nextval('constituency_constituency_id_seq'::regclass);


--
-- Name: contact_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE contact_types ALTER COLUMN contact_type_id SET DEFAULT nextval('contact_types_contact_type_id_seq'::regclass);


--
-- Name: county_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE counties ALTER COLUMN county_id SET DEFAULT nextval('counties_county_id_seq'::regclass);


--
-- Name: court_banking_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_bankings ALTER COLUMN court_banking_id SET DEFAULT nextval('court_bankings_court_banking_id_seq'::regclass);


--
-- Name: court_division_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_divisions ALTER COLUMN court_division_id SET DEFAULT nextval('court_divisions_court_division_id_seq'::regclass);


--
-- Name: court_payment_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_payments ALTER COLUMN court_payment_id SET DEFAULT nextval('court_payments_court_payment_id_seq'::regclass);


--
-- Name: court_rank_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_ranks ALTER COLUMN court_rank_id SET DEFAULT nextval('court_ranks_court_rank_id_seq'::regclass);


--
-- Name: court_station_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_stations ALTER COLUMN court_station_id SET DEFAULT nextval('court_stations_court_station_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: dc_case_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE dc_cases ALTER COLUMN dc_case_id SET DEFAULT nextval('dc_cases_dc_case_id_seq'::regclass);


--
-- Name: dc_category_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE dc_category ALTER COLUMN dc_category_id SET DEFAULT nextval('dc_category_dc_category_id_seq'::regclass);


--
-- Name: dc_judgment_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE dc_judgments ALTER COLUMN dc_judgment_id SET DEFAULT nextval('dc_judgments_dc_judgment_id_seq'::regclass);


--
-- Name: dc_receipt_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE dc_receipts ALTER COLUMN dc_receipt_id SET DEFAULT nextval('dc_receipts_dc_receipt_id_seq'::regclass);


--
-- Name: decision_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE decision_types ALTER COLUMN decision_type_id SET DEFAULT nextval('decision_types_decision_type_id_seq'::regclass);


--
-- Name: disability_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE disability ALTER COLUMN disability_id SET DEFAULT nextval('disability_disability_id_seq'::regclass);


--
-- Name: division_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE division_types ALTER COLUMN division_type_id SET DEFAULT nextval('division_types_division_type_id_seq'::regclass);


--
-- Name: entity_ident_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE entity_idents ALTER COLUMN entity_ident_id SET DEFAULT nextval('entity_idents_entity_ident_id_seq'::regclass);


--
-- Name: entity_subscription_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE entity_subscriptions ALTER COLUMN entity_subscription_id SET DEFAULT nextval('entity_subscriptions_entity_subscription_id_seq'::regclass);


--
-- Name: entity_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE entity_types ALTER COLUMN entity_type_id SET DEFAULT nextval('entity_types_entity_type_id_seq'::regclass);


--
-- Name: entity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE entitys ALTER COLUMN entity_id SET DEFAULT nextval('entitys_entity_id_seq'::regclass);


--
-- Name: entry_form_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE entry_forms ALTER COLUMN entry_form_id SET DEFAULT nextval('entry_forms_entry_form_id_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: file_location_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE file_locations ALTER COLUMN file_location_id SET DEFAULT nextval('file_locations_file_location_id_seq'::regclass);


--
-- Name: folder_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE folders ALTER COLUMN folder_id SET DEFAULT nextval('folders_folder_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: hearing_location_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE hearing_locations ALTER COLUMN hearing_location_id SET DEFAULT nextval('hearing_locations_hearing_location_id_seq'::regclass);


--
-- Name: id_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE id_types ALTER COLUMN id_type_id SET DEFAULT nextval('id_types_id_type_id_seq'::regclass);


--
-- Name: judgment_status_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE judgment_status ALTER COLUMN judgment_status_id SET DEFAULT nextval('judgment_status_judgment_status_id_seq'::regclass);


--
-- Name: log_case_activity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_activity ALTER COLUMN log_case_activity_id SET DEFAULT nextval('log_case_activity_log_case_activity_id_seq'::regclass);


--
-- Name: log_case_contact_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_contacts ALTER COLUMN log_case_contact_id SET DEFAULT nextval('log_case_contacts_log_case_contact_id_seq'::regclass);


--
-- Name: log_case_count_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_counts ALTER COLUMN log_case_count_id SET DEFAULT nextval('log_case_counts_log_case_count_id_seq'::regclass);


--
-- Name: log_case_decision_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_decisions ALTER COLUMN log_case_decision_id SET DEFAULT nextval('log_case_decisions_log_case_decision_id_seq'::regclass);


--
-- Name: log_case_transfer_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_transfers ALTER COLUMN log_case_transfer_id SET DEFAULT nextval('log_case_transfers_log_case_transfer_id_seq'::regclass);


--
-- Name: log_case_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_cases ALTER COLUMN log_case_id SET DEFAULT nextval('log_cases_log_case_id_seq'::regclass);


--
-- Name: log_court_banking_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_court_bankings ALTER COLUMN log_court_banking_id SET DEFAULT nextval('log_court_bankings_log_court_banking_id_seq'::regclass);


--
-- Name: log_court_payment_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_court_payments ALTER COLUMN log_court_payment_id SET DEFAULT nextval('log_court_payments_log_court_payment_id_seq'::regclass);


--
-- Name: log_receipt_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_receipts ALTER COLUMN log_receipt_id SET DEFAULT nextval('log_receipts_log_receipt_id_seq'::regclass);


--
-- Name: meeting_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE meetings ALTER COLUMN meeting_id SET DEFAULT nextval('meetings_meeting_id_seq'::regclass);


--
-- Name: mpesa_trx_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE mpesa_trxs ALTER COLUMN mpesa_trx_id SET DEFAULT nextval('mpesa_trxs_mpesa_trx_id_seq'::regclass);


--
-- Name: order_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE order_types ALTER COLUMN order_type_id SET DEFAULT nextval('order_types_order_type_id_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: participant_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE participants ALTER COLUMN participant_id SET DEFAULT nextval('participants_participant_id_seq'::regclass);


--
-- Name: payment_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE payment_types ALTER COLUMN payment_type_id SET DEFAULT nextval('payment_types_payment_type_id_seq'::regclass);


--
-- Name: police_station_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE police_stations ALTER COLUMN police_station_id SET DEFAULT nextval('police_stations_police_station_id_seq'::regclass);


--
-- Name: political_party_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE political_parties ALTER COLUMN political_party_id SET DEFAULT nextval('political_parties_political_party_id_seq'::regclass);


--
-- Name: ranking_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE rankings ALTER COLUMN ranking_id SET DEFAULT nextval('rankings_ranking_id_seq'::regclass);


--
-- Name: receipt_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE receipt_types ALTER COLUMN receipt_type_id SET DEFAULT nextval('receipt_types_receipt_type_id_seq'::regclass);


--
-- Name: receipt_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE receipts ALTER COLUMN receipt_id SET DEFAULT nextval('receipts_receipt_id_seq'::regclass);


--
-- Name: region_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE regions ALTER COLUMN region_id SET DEFAULT nextval('regions_region_id_seq'::regclass);


--
-- Name: sms_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sms ALTER COLUMN sms_id SET DEFAULT nextval('sms_sms_id_seq'::regclass);


--
-- Name: sms_address_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sms_address ALTER COLUMN sms_address_id SET DEFAULT nextval('sms_address_sms_address_id_seq'::regclass);


--
-- Name: sms_groups_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sms_groups ALTER COLUMN sms_groups_id SET DEFAULT nextval('sms_groups_sms_groups_id_seq'::regclass);


--
-- Name: sms_trans_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sms_trans ALTER COLUMN sms_trans_id SET DEFAULT nextval('sms_trans_sms_trans_id_seq'::regclass);


--
-- Name: sub_field_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sub_fields ALTER COLUMN sub_field_id SET DEFAULT nextval('sub_fields_sub_field_id_seq'::regclass);


--
-- Name: subscription_level_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE subscription_levels ALTER COLUMN subscription_level_id SET DEFAULT nextval('subscription_levels_subscription_level_id_seq'::regclass);


--
-- Name: surerity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE surerity ALTER COLUMN surerity_id SET DEFAULT nextval('surerity_surerity_id_seq'::regclass);


--
-- Name: sys_audit_detail_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_audit_details ALTER COLUMN sys_audit_detail_id SET DEFAULT nextval('sys_audit_details_sys_audit_detail_id_seq'::regclass);


--
-- Name: sys_audit_trail_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_audit_trail ALTER COLUMN sys_audit_trail_id SET DEFAULT nextval('sys_audit_trail_sys_audit_trail_id_seq'::regclass);


--
-- Name: sys_dashboard_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_dashboard ALTER COLUMN sys_dashboard_id SET DEFAULT nextval('sys_dashboard_sys_dashboard_id_seq'::regclass);


--
-- Name: sys_emailed_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_emailed ALTER COLUMN sys_emailed_id SET DEFAULT nextval('sys_emailed_sys_emailed_id_seq'::regclass);


--
-- Name: sys_email_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_emails ALTER COLUMN sys_email_id SET DEFAULT nextval('sys_emails_sys_email_id_seq'::regclass);


--
-- Name: sys_error_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_errors ALTER COLUMN sys_error_id SET DEFAULT nextval('sys_errors_sys_error_id_seq'::regclass);


--
-- Name: sys_file_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_files ALTER COLUMN sys_file_id SET DEFAULT nextval('sys_files_sys_file_id_seq'::regclass);


--
-- Name: sys_login_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_logins ALTER COLUMN sys_login_id SET DEFAULT nextval('sys_logins_sys_login_id_seq'::regclass);


--
-- Name: sys_news_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_news ALTER COLUMN sys_news_id SET DEFAULT nextval('sys_news_sys_news_id_seq'::regclass);


--
-- Name: sys_queries_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_queries ALTER COLUMN sys_queries_id SET DEFAULT nextval('sys_queries_sys_queries_id_seq'::regclass);


--
-- Name: sys_login_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE sys_reset ALTER COLUMN sys_login_id SET DEFAULT nextval('sys_reset_sys_login_id_seq'::regclass);


--
-- Name: ward_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE wards ALTER COLUMN ward_id SET DEFAULT nextval('wards_ward_id_seq'::regclass);


--
-- Name: workflow_phase_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE workflow_phases ALTER COLUMN workflow_phase_id SET DEFAULT nextval('workflow_phases_workflow_phase_id_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE workflows ALTER COLUMN workflow_id SET DEFAULT nextval('workflows_workflow_id_seq'::regclass);


--
-- Data for Name: activity_results; Type: TABLE DATA; Schema: public; Owner: root
--

COPY activity_results (activity_result_id, activity_result_name, appeal, trial, details) FROM stdin;
0	Not Heard	t	t	\N
1	Order	t	t	\N
2	Ruling	t	t	\N
3	Judgement	t	t	\N
4	Adjourned	t	t	\N
5	Adjourned Sine Die	t	t	\N
6	Closed Withdrawn	t	t	\N
7	Consent Order filed	t	t	\N
8	Ruling reserved	t	t	\N
9	Change of Judge	t	t	\N
10	Grant Appleal	t	t	\N
11	Petition Filled	t	t	\N
12	Service returned	t	t	\N
14	Responded to petition	t	t	\N
15	Heard	t	t	\N
16	Petition Withdrawn	t	t	\N
\.


--
-- Data for Name: activitys; Type: TABLE DATA; Schema: public; Owner: root
--

COPY activitys (activity_id, activity_name, appeal, trial, ep, show_on_diary, activity_days, activity_hours, details) FROM stdin;
1	Hearing	t	t	t	t	1	0	\N
2	Application	t	t	f	t	1	0	\N
3	Interlocutory Application	t	t	f	t	1	0	\N
4	Filing a Suite	t	t	f	t	1	0	\N
5	Filing an appleal	t	t	f	t	1	0	\N
6	Ruling	t	t	t	t	1	0	\N
7	Judgement	t	t	t	t	1	0	\N
8	Taking of Plea	t	t	f	t	1	0	\N
9	Bail Pending Trial	t	t	f	t	1	0	\N
10	Examination-in-Chief	t	t	f	t	1	0	\N
11	Cross-Examination	t	t	f	t	1	0	\N
12	Re-Examination	t	t	f	t	1	0	\N
13	Defence Hearing	t	t	f	t	1	0	\N
14	Sentencing	t	t	f	t	1	0	\N
21	Filing an election petition	t	t	t	f	1	0	\N
22	Return of service	t	t	t	f	1	0	\N
23	Response to petition	t	t	t	f	1	0	\N
24	Consolidation of election petitions	t	t	t	f	1	0	\N
25	Pre-trial conferencing	t	t	t	t	1	0	\N
26	Transfer Case	t	t	t	f	1	0	\N
27	Withdraw election petition	t	t	t	f	1	0	\N
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: root
--

COPY address (address_id, org_id, address_type_id, sys_country_id, address_name, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) FROM stdin;
\.


--
-- Data for Name: address_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY address_types (address_type_id, address_type_name) FROM stdin;
\.


--
-- Data for Name: adjorn_reasons; Type: TABLE DATA; Schema: public; Owner: root
--

COPY adjorn_reasons (adjorn_reason_id, adjorn_reason_name, appeal, trial, details) FROM stdin;
0	Not Adjourned	t	t	\N
1	Undetermined	t	t	\N
2	Party Absent	t	t	\N
3	Attorney Absent	t	t	\N
4	Witness Absent	t	t	\N
5	Interpretor Absent	t	t	\N
6	Other reasons	t	t	\N
\.


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: root
--

COPY approval_checklists (approval_checklist_id, org_id, approval_id, checklist_id, requirement, manditory, done, narrative) FROM stdin;
\.


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: root
--

COPY approvals (approval_id, org_id, workflow_phase_id, org_entity_id, app_entity_id, approval_level, escalation_days, escalation_hours, escalation_time, forward_id, table_name, table_id, application_date, completion_date, action_date, approve_status, approval_narrative, to_be_done, what_is_done, review_advice, details) FROM stdin;
\.


--
-- Data for Name: bank_accounts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY bank_accounts (bank_account_id, org_id, bank_account_name, bank_account_number, bank_name, branch_name, narrative, is_default, is_active, details) FROM stdin;
\.


--
-- Data for Name: bench_subjects; Type: TABLE DATA; Schema: public; Owner: root
--

COPY bench_subjects (bench_subject_id, entity_id, case_subject_id, org_id, proficiency, details) FROM stdin;
\.


--
-- Data for Name: cal_block_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY cal_block_types (cal_block_type_id, cal_block_type_name) FROM stdin;
\.


--
-- Data for Name: cal_entity_blocks; Type: TABLE DATA; Schema: public; Owner: root
--

COPY cal_entity_blocks (cal_entity_block_id, entity_id, cal_block_type_id, org_id, start_date, start_time, end_date, end_time, reason, details) FROM stdin;
\.


--
-- Data for Name: cal_holidays; Type: TABLE DATA; Schema: public; Owner: root
--

COPY cal_holidays (cal_holiday_id, cal_holiday_name, cal_holiday_date) FROM stdin;
\.


--
-- Data for Name: case_activity; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_activity (case_activity_id, case_id, activity_id, hearing_location_id, activity_result_id, adjorn_reason_id, order_type_id, court_station_id, appleal_case_id, org_id, activity_date, activity_time, finish_time, shared_hearing, completed, is_active, change_by, change_date, urgency_certificate, order_title, order_narrative, order_details, appleal_details, result_details, adjorn_details, details, application_date, approve_status, workflow_table_id, action_date) FROM stdin;
\.


--
-- Data for Name: case_bookmarks; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_bookmarks (case_bookmark_id, case_id, entity_id, org_id, entry_date, notes) FROM stdin;
\.


--
-- Data for Name: case_category; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, special_suffix, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) FROM stdin;
1	3	Criminal Appleal	Criminal Appleal	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
2	4	Civil Appleal	Civil Appleal	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
3	7	Civil Applications	Clvil Applications	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
4	1	Murder	Murder, Manslaughter and Infanticide	1.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
5	1	Manslaughter	Murder, Manslaughter and Infanticide	1.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
6	1	Manslaughter (Fatal Accident)	Murder, Manslaughter and Infanticide	1.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
7	1	Suspicious  Death	Murder, Manslaughter and Infanticide	1.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
8	1	Attempted Murder	Murder, Manslaughter and Infanticide	1.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
9	1	Infanticide	Murder, Manslaughter and Infanticide	1.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
10	1	Abduction	Other Serious Violent Offences	2.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
11	1	Act intending to cause GBH	Other Serious Violent Offences	2.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
12	1	Assault on a Police Officer	Other Serious Violent Offences	2.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
13	1	Assaulting a child	Other Serious Violent Offences	2.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
14	1	Grievous Harm	Other Serious Violent Offences	2.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
15	1	Grievous Harm (D.V)	Other Serious Violent Offences	2.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
16	1	Kidnapping	Other Serious Violent Offences	2.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
17	1	Physical abuse	Other Serious Violent Offences	2.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
18	1	Wounding	Other Serious Violent Offences	2.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
19	1	Wounding (D.V)	Other Serious Violent Offences	2.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
20	1	Attempted robbery	Robberies	3.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
21	1	Robbery with violence	Robberies	3.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
22	1	Robbery of mobile phone	Robberies	3.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
23	1	Attempted rape	Sexual offences	4.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
24	1	Rape	Sexual offences	4.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
25	1	Child abuse	Sexual offences	4.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
26	1	Indecent assault	Sexual offences	4.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
27	1	Sexual Abuse	Sexual offences	4.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
28	1	Sexual assault	Sexual offences	4.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
29	1	Sexual interference with a child	Sexual offences	4.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
30	1	A.O.A.B.H	Other Offences Against the Person	5.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
31	1	A.O.A.B.H (D.V)	Other Offences Against the Person	5.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
32	1	Assaulting a child	Other Offences Against the Person	5.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
33	1	Assaulting a child (D.V)	Other Offences Against the Person	5.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
34	1	Child neglect	Other Offences Against the Person	5.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
35	1	Common Assault	Other Offences Against the Person	5.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
36	1	Common Assault (D.V)	Other Offences Against the Person	5.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
37	1	Indecent act	Other Offences Against the Person	5.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
38	1	Obstruction of a Police Officer	Other Offences Against the Person	5.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
39	1	Procuring Abortion	Other Offences Against the Person	5.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
40	1	Resisting arrest	Other Offences Against the Person	5.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
41	1	Seditious offences	Other Offences Against the Person	5.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
42	1	Threatening Violence (D.V)	Other Offences Against the Person	5.13	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
43	1	Threatening Violence 	Other Offences Against the Person	5.14	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
44	1	Attempted breaking	Property Offences	6.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
45	1	Attempted burglary	Property Offences	6.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
46	1	Breaking into a building other than a dwelling	Property Offences	6.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
47	1	Breaking into a building other than a dwelling and stealing	Property Offences	6.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
48	1	Breaking into a building with intent to commit a felony	Property Offences	6.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
49	1	Burglary	Property Offences	6.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
50	1	Burglary and stealing	Property Offences	6.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
51	1	Entering a dwelling house 	Property Offences	6.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
52	1	Entering a dwelling house and stealing	Property Offences	6.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
53	1	Entering a dwelling house with intent to commit a felony	Property Offences	6.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
54	1	Entering a building with intent to commit a felony	Property Offences	6.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
55	1	House breaking 	Property Offences	6.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
56	1	House breaking and stealing	Property Offences	6.13	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
57	1	House breaking with intent to commit a felony	Property Offences	6.14	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
58	1	Stealing by servant	Property Offences	6.15	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
59	1	Stealing from vehicle	Property Offences	6.16	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
60	1	Stealing	Property Offences	6.17	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
61	1	Unlawful use of a vehicle	Property Offences	6.18	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
62	1	Unlawful possession of property	Property Offences	6.19	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
63	1	Unlawful use of boat or vessel	Property Offences	6.20	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
64	1	Attempted stealing	Theft	7.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
65	1	Beach theft	Theft	7.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
66	1	Receiving stolen property	Theft	7.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
67	1	Retaining Stolen Property	Theft	7.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
68	1	Stealing	Theft	7.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
69	1	Stealing by finding	Theft	7.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
70	1	Stealing by servant	Theft	7.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
71	1	Stealing from boat or vessel	Theft	7.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
72	1	Stealing from dwelling house	Theft	7.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
73	1	Stealing from hotel room	Theft	7.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
74	1	Stealing from person	Theft	7.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
75	1	Stealing from vehicle	Theft	7.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
76	1	Unlawful possession of property	Theft	7.13	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
77	1	Unlawful use of a vehicle	Theft	7.14	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
78	1	Unlawful use of boat or vessel	Theft	7.15	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
79	1	Arson	Arson and criminal damage	8.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
80	1	Attempted Arson	Arson and criminal damage	8.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
81	1	Criminal trespass	Arson and criminal damage	8.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
82	1	Damaging government property	Arson and criminal damage	8.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
83	1	Damaging property	Arson and criminal damage	8.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
84	1	Bribery	Fraud	9.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
85	1	Extortion 	Fraud	9.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
86	1	False accounting	Fraud	9.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
87	1	Forgery	Fraud	9.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
88	1	Fraud	Fraud	9.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
89	1	Giving false information to Govt employee	Fraud	9.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
90	1	Importing or purchasing forged notes	Fraud	9.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
91	1	Issuing a cheque without provision	Fraud	9.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
92	1	Misappropriation of money	Fraud	9.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
93	1	Money laundering	Fraud	9.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
94	1	Obtaining credit by false pretence	Fraud	9.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
95	1	Obtaining fares by false pretence	Fraud	9.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
96	1	Obtaining goods by false pretence	Fraud	9.13	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
97	1	Obtaining money by false pretence	Fraud	9.14	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
98	1	Obtaining service by false pretence	Fraud	9.15	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
99	1	Offering a bribe to Govt employee	Fraud	9.16	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
100	1	Perjury	Fraud	9.17	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
101	1	Possession of false/counterfeit currency	Fraud	9.18	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
102	1	Possession of false document	Fraud	9.19	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
103	1	Trading as a contractor without a licence	Fraud	9.20	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
104	1	Trading without a licence	Fraud	9.21	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
105	1	Unlawful possession of forged notes	Fraud	9.22	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
106	1	Uttering false notes	Fraud	9.23	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
107	1	Affray	Public Order Offences	10.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
108	1	Attempt to commit negligent act to cause harm	Public Order Offences	10.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
109	1	Burning rubbish without permit	Public Order Offences	10.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
110	1	Common Nuisance	Public Order Offences	10.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
111	1	Consuming alcohol in a public place	Public Order Offences	10.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
112	1	Cruelty to animals	Public Order Offences	10.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
113	1	Defamation of the President	Public Order Offences	10.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
114	1	Disorderly conduct in a Police building	Public Order Offences	10.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
115	1	Entering a restricted airport attempting to board	Public Order Offences	10.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
116	1	Idle and disorderly (A-i)	Public Order Offences	10.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
117	1	Insulting the modesty of a woman	Public Order Offences	10.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
118	1	Loitering	Public Order Offences	10.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
119	1	Negligent act	Public Order Offences	10.13	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
120	1	Rash and negligent act	Public Order Offences	10.14	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
121	1	Reckless or negligent act	Public Order Offences	10.15	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
122	1	Rogue and vagabond	Public Order Offences	10.16	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
123	1	Unlawful assembly	Public Order Offences	10.17	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
124	1	Throwing litter in a public place	Public Order Offences	10.18	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
125	1	Using obscene and indescent language in public place	Public Order Offences	10.19	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
126	1	Aiding and abetting escape prisoner	Offences relating to the administration of justice	11.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
127	1	Attempted escape	Offences relating to the administration of justice	11.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
128	1	Breach of court order	Offences relating to the administration of justice	11.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
129	1	Contempt of court	Offences relating to the administration of justice	11.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
130	1	Escape from lawful custody	Offences relating to the administration of justice	11.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
131	1	Failing to comply with bail	Offences relating to the administration of justice	11.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
132	1	Refuse to give name	Offences relating to the administration of justice	11.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
133	1	Trafficking in hard drugs	Offences relating to the administration of justice	11.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
134	1	Cultivation of controlled drugs	Drugs	12.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
135	1	Importation of controlled drugs	Drugs	12.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
136	1	Possession of controlled drugs	Drugs	12.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
137	1	Possession of hard drugs	Drugs	12.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
138	1	Poss of syringe for consumption or administration of controlled drugs.	Drugs	12.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
139	1	Presumption of Consumption Of Controlled Drugs	Drugs	12.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
140	1	Refuse to give control samples	Drugs	12.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
141	1	Trafficking controlled drugs	Drugs	12.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
142	1	Trafficking in hard drugs	Drugs	12.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
143	1	Importation of firearm and ammunition	Weapons and Ammunition	13.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
144	1	Possession of explosive(includes Tuna Crackers)	Weapons and Ammunition	13.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
145	1	Possession of offensive weapon	Weapons and Ammunition	13.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
146	1	Possession of spear gun	Weapons and Ammunition	13.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
147	1	Unlawful possession of a firearm	Weapons and Ammunition	13.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
148	1	Catching turtle	Environment and Fisheries	14.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
149	1	Cutting or selling protected trees without a permit	Environment and Fisheries	14.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
150	1	Cutting protected trees without a permit	Environment and Fisheries	14.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
151	1	Dealing in nature nuts	Environment and Fisheries	14.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
152	1	Illegal fishing in Seychelles territoiral waters	Environment and Fisheries	14.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
153	1	Possession of Coco De Mer without a permit	Environment and Fisheries	14.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
154	1	Removal of sand without permit	Environment and Fisheries	14.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
155	1	Selling Protected trees	Environment and Fisheries	14.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
156	1	Stealing protected animals	Environment and Fisheries	14.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
157	1	Taking or processing of sea cucumber without a licence	Environment and Fisheries	14.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
158	1	Unauthorised catching of sea cucumber in Seychelles	Environment and Fisheries	14.11	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
159	1	Unlawful possession of a turtle meat, turtle shell, dolphin and lobster	Environment and Fisheries	14.12	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
160	1	Piracy	Other crimes Not Elsewhere Classified (Miscellaneous)	15.01	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
161	1	Allowing animals to stray	Other crimes Not Elsewhere Classified (Miscellaneous)	15.02	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
162	1	Bigamy	Other crimes Not Elsewhere Classified (Miscellaneous)	15.03	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
163	1	Endangering the safety of an aircraft	Other crimes Not Elsewhere Classified (Miscellaneous)	15.04	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
164	1	Gamble	Other crimes Not Elsewhere Classified (Miscellaneous)	15.05	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
165	1	Illegal connection of water	Other crimes Not Elsewhere Classified (Miscellaneous)	15.06	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
166	1	Killing of an animal with intent to steal	Other crimes Not Elsewhere Classified (Miscellaneous)	15.07	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
167	1	Possesion of more than 20 litres of baka or lapire without licence	Other crimes Not Elsewhere Classified (Miscellaneous)	15.08	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
168	1	Possession of pornographic materials	Other crimes Not Elsewhere Classified (Miscellaneous)	15.09	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
169	1	Prohibited goods	Other crimes Not Elsewhere Classified (Miscellaneous)	15.10	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
170	2	Divorce	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
171	2	Civil Ex-Parte	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
172	2	Civil Suit	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
173	2	Petition/Application	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
174	2	Miscellaneous Application	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
400	2	Insurance Claim	\N	\N	\N	\N	f	f	\N	\N	\N	\N	\N	\N	\N
411	5	Presidental	\N	\N	\N	PR	f	f	\N	\N	\N	\N	\N	\N	\N
412	5	Senator	\N	\N	\N	SE	f	f	\N	\N	\N	\N	\N	\N	\N
413	5	Governor	\N	\N	\N	GO	f	f	\N	\N	\N	\N	\N	\N	\N
414	5	Women Representative	\N	\N	\N	WR	f	f	\N	\N	\N	\N	\N	\N	\N
415	5	Parliamentary	\N	\N	\N	MP	f	f	\N	\N	\N	\N	\N	\N	\N
416	5	County Representative	\N	\N	\N	CR	f	f	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: case_contacts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_contacts (case_contact_id, case_id, entity_id, contact_type_id, political_party_id, org_id, case_contact_no, election_winner, is_disqualified, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: case_counts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_counts (case_count_id, case_contact_id, case_category_id, org_id, narrative, is_active, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: case_decisions; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_decisions (case_decision_id, case_id, case_activity_id, case_count_id, decision_type_id, judgment_status_id, org_id, decision_summary, judgement, judgement_date, death_sentence, life_sentence, jail_years, jail_days, fine_amount, fine_jail, canes, is_active, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: case_files; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_files (case_file_id, case_id, case_activity_id, case_decision_id, org_id, file_folder, file_name, file_type, file_size, narrative, details) FROM stdin;
\.


--
-- Data for Name: case_insurance; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_insurance (case_insurance_id, case_id, org_id, entry_date, registration_number, type_of_claim, value_of_claim, notes) FROM stdin;
\.


--
-- Data for Name: case_notes; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_notes (case_note_id, case_activity_id, entity_id, org_id, case_note_title, change_date, details) FROM stdin;
\.


--
-- Data for Name: case_quorum; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_quorum (case_quorum_id, case_activity_id, case_contact_id, org_id, narrative) FROM stdin;
\.


--
-- Data for Name: case_subjects; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_subjects (case_subject_id, case_subject_name, ep, criminal, civil, details) FROM stdin;
1	Commercial	f	f	f	\N
2	Family	f	f	f	\N
3	Insurance	f	f	f	\N
4	Constitution	f	f	f	\N
5	Contract	f	f	f	\N
6	Electoral Disputes	t	f	f	\N
7	Criminal	f	f	f	\N
\.


--
-- Data for Name: case_transfers; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_transfers (case_transfer_id, case_id, case_category_id, court_division_id, org_id, judgment_date, presiding_judge, previous_case_number, receipt_date, received_by, case_transfered, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: case_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY case_types (case_type_id, case_type_name, duration_unacceptable, duration_serious, duration_normal, duration_low, activity_unacceptable, activity_serious, activity_normal, activity_low, details) FROM stdin;
1	Crimal Cases	\N	\N	\N	\N	\N	\N	\N	\N	\N
2	Civil Cases	\N	\N	\N	\N	\N	\N	\N	\N	\N
3	Crimal Appeal	\N	\N	\N	\N	\N	\N	\N	\N	\N
4	Civil Appeal	\N	\N	\N	\N	\N	\N	\N	\N	\N
5	Election Disputes	\N	\N	\N	\N	\N	\N	\N	\N	\N
7	Civil Applications	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: cases; Type: TABLE DATA; Schema: public; Owner: root
--

COPY cases (case_id, case_category_id, court_division_id, file_location_id, case_subject_id, police_station_id, new_case_id, old_case_id, county_id, constituency_id, ward_id, org_id, case_title, case_number, file_number, date_of_elections, date_of_arrest, ob_number, holding_prison, warrant_of_arrest, alleged_crime, start_date, original_case_date, end_date, nature_of_claim, value_of_claim, closed, case_locked, consolidate_cases, final_decision, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: category_activitys; Type: TABLE DATA; Schema: public; Owner: root
--

COPY category_activitys (category_activity_id, case_category_id, contact_type_id, activity_id, from_activity_id, activity_order, warning_days, deadline_days, mandatory, details) FROM stdin;
1	411	10	21	\N	1	5	7	t	\N
2	411	8	22	\N	2	25	28	t	\N
3	411	8	23	\N	3	25	28	f	\N
4	411	\N	24	\N	4	32	35	f	\N
5	411	\N	25	\N	5	39	42	f	\N
6	411	\N	26	\N	6	47	49	f	\N
7	411	\N	1	\N	7	55	60	t	\N
8	411	\N	7	\N	8	65	70	t	\N
9	412	10	21	\N	1	14	21	t	\N
10	412	8	22	\N	2	25	28	t	\N
11	412	8	23	\N	3	25	28	f	\N
12	412	\N	24	\N	4	32	35	f	\N
13	412	\N	25	\N	5	39	42	f	\N
14	412	\N	26	\N	6	47	49	f	\N
15	412	\N	1	\N	7	55	60	t	\N
16	412	\N	7	\N	8	65	70	t	\N
\.


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: root
--

COPY checklists (checklist_id, org_id, workflow_phase_id, checklist_number, manditory, requirement, details) FROM stdin;
\.


--
-- Data for Name: constituency; Type: TABLE DATA; Schema: public; Owner: root
--

COPY constituency (constituency_id, county_id, constituency_name, constituency_code, details) FROM stdin;
\.


--
-- Data for Name: contact_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY contact_types (contact_type_id, contact_type_name, bench, appeal, trial, ep, details) FROM stdin;
1	Presiding Judge	t	t	t	t	\N
2	Prosecutor	f	t	t	f	\N
3	Prosecution Witness	f	t	t	f	\N
4	Accused	f	t	t	f	\N
5	Plaintiff	f	t	t	f	\N
6	Defendant	f	t	t	f	\N
7	Appellant	f	t	t	f	\N
8	Respondent	f	t	t	t	\N
9	Applicant	f	t	t	f	\N
10	Petitioner	f	t	t	t	\N
11	Advocate of the Plaintiff	f	t	t	f	\N
12	Advocate of the Defendant	f	t	t	f	\N
13	Advocate of the Petitioner	f	t	t	t	\N
14	Advocate of the Respondent	f	t	t	t	\N
15	Defence Witness	f	t	t	f	\N
16	Petitioner Witness	f	t	t	t	\N
17	Respondent Witness	f	t	t	t	\N
\.


--
-- Data for Name: counties; Type: TABLE DATA; Schema: public; Owner: root
--

COPY counties (county_id, region_id, county_name, details) FROM stdin;
1	1	Nairobi	\N
2	2	Narok	\N
3	2	Turkana	\N
4	2	Elgeyo Marakwet	\N
5	2	Trans Nzoia	\N
6	2	Uasin Gishu	\N
7	2	Nandi	\N
8	2	Kericho	\N
9	2	Bomet	\N
10	2	Baringo	\N
11	2	Nakuru	\N
12	2	Samburu	\N
13	2	Laikipia	\N
14	2	Kajiado	\N
15	2	West Pokot	\N
16	3	Makueni	\N
17	3	Machakos	\N
18	3	Meru	\N
19	3	Tharaka Nithi	\N
20	3	Embu	\N
21	3	Isiolo	\N
22	3	Marsabit	\N
23	3	Kitui	\N
24	4	Siaya	\N
25	4	Kisii	\N
26	4	Nyamira	\N
27	4	Kisumu	\N
28	4	Homa Bay	\N
29	4	Migori	\N
30	5	Kwale	\N
31	5	Mombasa	\N
32	5	Taita Taveta	\N
33	5	Kilifi	\N
34	5	Lamu	\N
35	5	Tana River	\N
36	6	Kiambu	\N
37	6	Muranga	\N
38	6	Nyandarua	\N
39	6	Nyeri	\N
40	6	Kirinyaga	\N
41	7	Busia	\N
42	7	Bungoma	\N
43	7	Kakamega	\N
44	7	Vihiga	\N
45	8	Garissa	\N
46	8	Mandera	\N
47	8	Wajir	\N
\.


--
-- Data for Name: court_bankings; Type: TABLE DATA; Schema: public; Owner: root
--

COPY court_bankings (court_banking_id, bank_account_id, source_account_id, org_id, bank_ref, banking_date, amount, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: court_divisions; Type: TABLE DATA; Schema: public; Owner: root
--

COPY court_divisions (court_division_id, court_station_id, division_type_id, org_id, court_division_code, court_division_num, details) FROM stdin;
\.


--
-- Data for Name: court_payments; Type: TABLE DATA; Schema: public; Owner: root
--

COPY court_payments (court_payment_id, receipt_id, payment_type_id, bank_account_id, org_id, bank_ref, payment_date, amount, r_amount, bank_code, payee_name, payee_account, jail_days, credit_note, refund, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: court_ranks; Type: TABLE DATA; Schema: public; Owner: root
--

COPY court_ranks (court_rank_id, court_rank_name, details) FROM stdin;
1	Supreme Court	\N
2	Court of Appeal	\N
3	High Court	\N
4	Constitutional Court	\N
5	Magistrate Court	\N
6	Khadhis Court	\N
\.


--
-- Data for Name: court_stations; Type: TABLE DATA; Schema: public; Owner: root
--

COPY court_stations (court_station_id, court_rank_id, county_id, org_id, court_station_name, court_station_code, district, details) FROM stdin;
\.


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: root
--

COPY currency (currency_id, currency_name, currency_symbol) FROM stdin;
1	Kenya Shillings	KES
2	US Dolar	USD
3	British Pound	BPD
4	Euro	ERO
\.


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: root
--

COPY currency_rates (currency_rate_id, org_id, currency_id, exchange_date, exchange_rate) FROM stdin;
0	0	1	2013-08-14 08:41:34.588339	1
\.


--
-- Data for Name: dc_cases; Type: TABLE DATA; Schema: public; Owner: root
--

COPY dc_cases (dc_case_id, dc_category_id, dc_judgment_id, court_division_id, entity_id, org_id, case_title, file_number, appeal, date_of_arrest, ob_number, alleged_crime, start_date, mention_date, hearing_date, end_date, value_of_claim, name_of_litigant, litigant_age, male_litigants, female_litigant, number_of_witnesses, previous_conviction, legal_representation, closed, change_by, change_date, adjournment_reason, judgment_summary, detail) FROM stdin;
\.


--
-- Data for Name: dc_category; Type: TABLE DATA; Schema: public; Owner: root
--

COPY dc_category (dc_category_id, dc_category_name, category_type, court_level, children_category, details) FROM stdin;
1	Murder, manslaughter, attempted murder and suicide, assault with maim, grevious harm and affray	1	2	f	\N
2	Miscellaneous Applications	1	3	f	\N
3	Ordinary Criminal Appeals	1	3	f	\N
4	Capital Appeals	1	3	f	\N
5	Criminal Revisions	1	3	f	\N
6	Robbery	1	1	f	\N
7	Robbery with violence	1	1	f	\N
8	Unlawful assembly and riots	1	1	f	\N
9	Offenses allied to stealing	1	1	f	\N
10	Forgery and impersonation	1	1	f	\N
11	Assault	1	1	f	\N
12	Theft	1	1	f	\N
13	Children in conflict with the law	1	1	f	\N
14	Sexual offenses	1	1	f	\N
15	Offenses against morality e.g conspiracy to defile, to procure an abortion, gender based violance etc.	1	1	f	\N
16	Offenses against marrige and domestic obligations	1	1	f	\N
17	Offenses against Liberty e.g kidnapping, malicious injury to property etc.	1	1	f	\N
18	Other criminal matters filed under Acts of Parliament	1	1	f	\N
19	Tort (Personal injury/ defamation)	2	1	f	\N
20	Negligence and recklessness	2	1	f	\N
21	Disputes from contracts (excluding land)	2	1	f	\N
22	Traffic cases	2	1	f	\N
23	Land (cases not involving title deeds)	2	1	f	\N
24	Succession	2	1	f	\N
25	Matrimonial Cases	2	1	f	\N
26	Children cases : Adoption	2	1	t	\N
27	Children cases : Protection and care	2	1	t	\N
28	Children cases : Child maintenance and custody	2	1	t	\N
29	Children cases : Committal proceedings for abandoned babies	2	1	t	\N
30	Children cases : Miscellaneous applications (including applications not under Childrens Act)	2	1	t	\N
31	Anti corruption and economic crime cases	2	1	f	\N
32	Miscellaneous (Interlocutory applications)	2	1	f	\N
33	P and A	2	3	f	\N
34	Civil Appeals (including succession matters)	2	3	f	\N
35	Miscellaneous Applications	2	3	f	\N
36	Income Tax Appeals	2	3	f	\N
37	Commercial  Cases	2	3	f	\N
38	Winding up cases 	2	3	f	\N
39	Bankruptcy cases 	2	3	f	\N
40	Running Down cases	2	3	f	\N
41	Land and environmental cases	2	3	f	\N
42	Industrial cases	2	3	f	\N
43	Judicial review cases	2	3	f	\N
44	Constitutional reference cases	2	3	f	\N
45	Matrimonial cases	2	3	f	\N
46	Succession cases	2	3	f	\N
47	Adoption cases	2	3	f	\N
48	Taxation of advocates costs cases	2	3	f	\N
49	Ad Litem cases	2	3	f	\N
50	Admiralty cases	2	3	f	\N
51	Other Civil cases	2	3	f	\N
52	Marriage	2	4	f	\N
53	Divorce	2	4	f	\N
54	Succession	2	4	f	\N
55	Other cases	2	4	f	\N
\.


--
-- Data for Name: dc_judgments; Type: TABLE DATA; Schema: public; Owner: root
--

COPY dc_judgments (dc_judgment_id, dc_judgment_name, details) FROM stdin;
1	Not Heard	\N
2	Adjonment	\N
3	Solved on application	\N
4	Bail	\N
5	Appeals allowed and persons acquitted/discharged	\N
6	Appeals allowed and sentence reduced	\N
7	Appeals dismissed and sentence upheld	\N
8	Appeals dismissed and sentence enhanced	\N
9	Rulings/judgments made per Judge	\N
10	Fined	\N
11	Sent to prison	\N
12	Sent to CSO	\N
13	Remand	\N
14	Sentenced to probation (Adults)	\N
15	Sentenced to probation (Children in conflict with the law)	\N
16	Repatriated	\N
17	Juveniles sentenced to Borstal	\N
18	Juveniles sentenced to Approved School	\N
19	Juveniles sentenced to Corrective Training Centre	\N
\.


--
-- Data for Name: dc_receipts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY dc_receipts (dc_receipt_id, dc_case_id, receipt_type_id, org_id, receipt_for, receipt_date, amount, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: decision_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY decision_types (decision_type_id, decision_type_name, details) FROM stdin;
1	Ruling	\N
2	Interlocutory Judgment	\N
3	Final Judgment	\N
4	Sentencing	\N
5	Decree	\N
\.


--
-- Data for Name: disability; Type: TABLE DATA; Schema: public; Owner: root
--

COPY disability (disability_id, disability_name) FROM stdin;
0	None
1	Blind
2	Deaf
\.


--
-- Data for Name: division_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY division_types (division_type_id, division_type_name, details) FROM stdin;
1	Crimal	\N
2	Civil	\N
3	Family	\N
4	Constitutional	\N
5	Land and Environment	\N
7	Election Disputes	\N
\.


--
-- Data for Name: entity_idents; Type: TABLE DATA; Schema: public; Owner: root
--

COPY entity_idents (entity_ident_id, entity_id, id_type_id, org_id, id_number, details) FROM stdin;
\.


--
-- Data for Name: entity_subscriptions; Type: TABLE DATA; Schema: public; Owner: root
--

COPY entity_subscriptions (entity_subscription_id, org_id, entity_type_id, entity_id, subscription_level_id, details) FROM stdin;
0	0	0	0	0	\N
\.


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, start_view, group_email, description, details) FROM stdin;
0	0	Users	user	0	\N	\N	\N	\N
1	0	Staff	staff	0	\N	\N	\N	\N
2	0	Client	client	0	\N	\N	\N	\N
10	0	Lawyer	\N	0	\N	\N	\N	\N
11	0	Insurance Firm	\N	0	\N	\N	\N	\N
\.


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: root
--

COPY entitys (entity_id, org_id, entity_type_id, entity_name, user_name, primary_email, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, disability_id, court_station_id, ranking_id, id_type_id, country_aquired, station_judge, is_available, identification, gender, date_of_birth, deceased, date_of_death) FROM stdin;
0	0	0	root	root	root@localhost	t	t	t	\N	2013-08-14 08:41:34.588339	t	e2a7106f1cc8bb1e1318df70aa0a3540	enter	\N	\N	f	\N	\N	\N	\N	\N	\N	f	t	\N	\N	\N	f	\N
1	0	0	repository	repository	repository@localhost	f	t	t	\N	2013-08-14 08:41:34.588339	t	e2a7106f1cc8bb1e1318df70aa0a3540	enter	\N	\N	f	\N	\N	\N	\N	\N	\N	f	t	\N	\N	\N	f	\N
\.


--
-- Data for Name: entry_forms; Type: TABLE DATA; Schema: public; Owner: root
--

COPY entry_forms (entry_form_id, org_id, entity_id, form_id, entered_by_id, application_date, completion_date, approve_status, workflow_table_id, action_date, narrative, answer, sub_answer, details) FROM stdin;
\.


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: root
--

COPY fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) FROM stdin;
90	0	7	\N	Received on the 	\N	TEXTFIELD	\N	0	0	10	10	25	L	\N	0	1	\N	\N
91	0	7	\N	at the Registry of the High /Magistrate Court, a petition concerning the election of	\N	TEXTFIELD	\N	0	0	20	20	25	L	\N	0	1	\N	\N
92	0	7	\N	for	\N	TEXTFIELD	\N	0	0	30	30	25	L	\N	0	1	\N	\N
93	0	7	\N	purporting to be singed by 	\N	TEXTFIELD	\N	0	0	40	30	25	L	\N	0	1	\N	\N
94	0	7	\N	Registrar (or other to whom the petition is delivered)	\N	TEXTFIELD	\N	0	0	50	40	25	L	\N	0	1	\N	\N
\.


--
-- Data for Name: file_locations; Type: TABLE DATA; Schema: public; Owner: root
--

COPY file_locations (file_location_id, court_station_id, org_id, file_location_name, details) FROM stdin;
\.


--
-- Data for Name: folders; Type: TABLE DATA; Schema: public; Owner: root
--

COPY folders (folder_id, folder_name, details) FROM stdin;
0	Outbox	\N
1	Draft	\N
2	Sent	\N
3	Inbox	\N
4	Action	\N
\.


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: root
--

COPY forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, default_sub_values, details) FROM stdin;
7	0	ACKNOWLEDGEMENT OF RECEIPT OF A PETITION	FORM EP 1	\N	1	0	0	0	\N	\N	\N	\N	\N
\.


--
-- Data for Name: hearing_locations; Type: TABLE DATA; Schema: public; Owner: root
--

COPY hearing_locations (hearing_location_id, court_station_id, org_id, hearing_location_name, details) FROM stdin;
\.


--
-- Data for Name: id_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY id_types (id_type_id, id_type_name) FROM stdin;
1	National ID
2	Passport
3	PIN Number
4	Company Certificate
\.


--
-- Data for Name: judgment_status; Type: TABLE DATA; Schema: public; Owner: root
--

COPY judgment_status (judgment_status_id, judgment_status_name, details) FROM stdin;
1	Active	\N
2	Dormant	\N
3	Satisfied	\N
4	Partially satisfied	\N
5	Expired	\N
\.


--
-- Data for Name: log_case_activity; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_case_activity (log_case_activity_id, case_activity_id, case_id, hearing_location_id, activity_id, activity_result_id, adjorn_reason_id, order_type_id, court_station_id, appleal_case_id, org_id, activity_date, activity_time, finish_time, shared_hearing, completed, is_active, change_by, change_date, order_narrative, order_title, order_details, appleal_details, details) FROM stdin;
\.


--
-- Data for Name: log_case_contacts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_case_contacts (log_case_contact_id, case_contact_id, case_id, entity_id, contact_type_id, political_party_id, org_id, case_contact_no, is_disqualified, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: log_case_counts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_case_counts (log_case_count_id, case_count_id, case_contact_id, case_category_id, org_id, narrative, is_active, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: log_case_decisions; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_case_decisions (log_case_decision_id, case_decision_id, case_id, case_activity_id, case_count_id, decision_type_id, judgment_status_id, org_id, decision_summary, judgement, judgement_date, death_sentence, life_sentence, jail_years, jail_days, fine_amount, fine_jail, canes, is_active, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: log_case_transfers; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_case_transfers (log_case_transfer_id, case_transfer_id, case_id, case_category_id, court_division_id, org_id, judgment_date, presiding_judge, previous_case_number, receipt_date, received_by, case_transfered, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: log_cases; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_cases (log_case_id, case_id, case_category_id, court_division_id, file_location_id, case_subject_id, police_station_id, new_case_id, old_case_id, constituency_id, ward_id, org_id, case_title, file_number, date_of_arrest, ob_number, holding_prison, warrant_of_arrest, alleged_crime, date_of_elections, start_date, end_date, nature_of_claim, value_of_claim, closed, case_locked, final_decision, is_active, change_by, change_date, detail) FROM stdin;
\.


--
-- Data for Name: log_court_bankings; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_court_bankings (log_court_banking_id, court_banking_id, bank_account_id, source_account_id, org_id, bank_ref, banking_date, amount, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: log_court_payments; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_court_payments (log_court_payment_id, court_payment_id, receipt_id, payment_type_id, bank_account_id, org_id, bank_ref, payment_date, amount, jail_days, credit_note, refund, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: log_receipts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY log_receipts (log_receipt_id, receipt_id, case_id, case_decision_id, receipt_type_id, court_station_id, org_id, receipt_for, case_number, receipt_date, amount, for_process, approved, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: meetings; Type: TABLE DATA; Schema: public; Owner: root
--

COPY meetings (meeting_id, org_id, meeting_name, start_date, start_time, end_date, end_time, completed, details) FROM stdin;
\.


--
-- Data for Name: mpesa_trxs; Type: TABLE DATA; Schema: public; Owner: root
--

COPY mpesa_trxs (mpesa_trx_id, receipt_id, org_id, mpesa_id, mpesa_orig, mpesa_dest, mpesa_tstamp, mpesa_text, mpesa_code, mpesa_acc, mpesa_msisdn, mpesa_trx_date, mpesa_trx_time, mpesa_amt, mpesa_sender, mpesa_pick_time, voided, voided_by, voided_date) FROM stdin;
\.


--
-- Data for Name: order_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY order_types (order_type_id, order_type_name, details) FROM stdin;
1	Witness Summons	\N
2	Warrant of Arrest	\N
3	Warrant of Commitment to Civil Jail	\N
4	Language Understood by Accused	\N
5	Release Order - where cash bail has been paid	\N
6	Release Order - where surety has signed bond	\N
7	Release Order	\N
8	Committal Warrant to Medical Institution/Mathare Mental Hospital	\N
9	Escort to Hospital for treatment, Age assessment or mental assessment	\N
10	Judgment Extraction	\N
11	Particulars of Surety	\N
12	Others	\N
14	Warrant of commitment on remand	\N
\.


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: root
--

COPY orgs (org_id, currency_id, org_name, is_default, is_active, logo, pin, details, bench_next) FROM stdin;
0	1	default	t	t	logo.png	\N	\N	\N
\.


--
-- Data for Name: participants; Type: TABLE DATA; Schema: public; Owner: root
--

COPY participants (participant_id, meeting_id, entity_id, org_id, meeting_role, details) FROM stdin;
\.


--
-- Data for Name: payment_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY payment_types (payment_type_id, payment_type_name, cash, non_cash, for_credit_note, for_refund, details) FROM stdin;
1	Cash Receipt	t	f	f	f	\N
2	KCB Bank Payment	f	f	f	f	\N
3	Credit Note	f	f	t	f	\N
4	Refund	f	f	f	t	\N
\.


--
-- Data for Name: police_stations; Type: TABLE DATA; Schema: public; Owner: root
--

COPY police_stations (police_station_id, court_station_id, org_id, police_station_name, police_station_phone, details) FROM stdin;
\.


--
-- Data for Name: political_parties; Type: TABLE DATA; Schema: public; Owner: root
--

COPY political_parties (political_party_id, political_party_name, details) FROM stdin;
\.


--
-- Data for Name: rankings; Type: TABLE DATA; Schema: public; Owner: root
--

COPY rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) FROM stdin;
1	Chief Justice	\N	0	\N
2	Supreme Court Judge	\N	0	\N
3	Court of Appeal Judge	\N	0	\N
4	High Court Judge	\N	0	\N
5	Chief Magistrate	\N	0	\N
6	Senior Principal Magistrate	\N	0	\N
7	Principal Magistrate	\N	0	\N
8	Senior Resident Magistrate	\N	0	\N
9	Resident Magistrate	\N	0	\N
\.


--
-- Data for Name: receipt_types; Type: TABLE DATA; Schema: public; Owner: root
--

COPY receipt_types (receipt_type_id, receipt_type_name, receipt_type_code, require_refund, details) FROM stdin;
1	Traffic Fine	TR	f	\N
2	Criminal Fine	CR	f	\N
3	Filing Fee	FF	f	\N
\.


--
-- Data for Name: receipts; Type: TABLE DATA; Schema: public; Owner: root
--

COPY receipts (receipt_id, case_id, case_decision_id, receipt_type_id, court_station_id, org_id, receipt_for, case_number, receipt_date, amount, for_process, approved, refund_approved, is_active, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: regions; Type: TABLE DATA; Schema: public; Owner: root
--

COPY regions (region_id, region_name, details) FROM stdin;
1	Nairobi	\N
2	Rift Valley	\N
3	Eastern	\N
4	Nyanza	\N
5	Coast	\N
6	Central	\N
7	Western	\N
8	North-Eastern	\N
\.


--
-- Data for Name: sms; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sms (sms_id, folder_id, org_id, sms_origin, sms_number, sms_time, message_ready, sent, retries, last_retry, message, details) FROM stdin;
\.


--
-- Data for Name: sms_address; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sms_address (sms_address_id, sms_id, address_id, org_id, narrative) FROM stdin;
\.


--
-- Data for Name: sms_groups; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sms_groups (sms_groups_id, sms_id, entity_type_id, org_id, narrative) FROM stdin;
\.


--
-- Data for Name: sms_trans; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sms_trans (sms_trans_id, message, origin, sms_time, client_id, msg_number, code, amount, in_words, narrative, sms_id, sms_deleted, sms_picked, part_id, part_message, part_no, part_count, complete) FROM stdin;
\.


--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) FROM stdin;
\.


--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: root
--

COPY subscription_levels (subscription_level_id, org_id, subscription_level_name, details) FROM stdin;
0	0	Basic	\N
1	0	Manager	\N
2	0	Consumer	\N
\.


--
-- Data for Name: surerity; Type: TABLE DATA; Schema: public; Owner: root
--

COPY surerity (surerity_id, receipts_id, org_id, surerity_name, relationship, id_card_no, id_issued_at, district, location, sub_location, village, residential_address, street, road, avenue, house_no, po_box, house_phone_no, occupation, employer, work_physical_address, telephone_no, surerity_income, other_information, change_by, change_date, details) FROM stdin;
\.


--
-- Data for Name: sys_audit_details; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_audit_details (sys_audit_detail_id, sys_audit_trail_id, new_value) FROM stdin;
\.


--
-- Data for Name: sys_audit_trail; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) FROM stdin;
\.


--
-- Data for Name: sys_continents; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_continents (sys_continent_id, sys_continent_name) FROM stdin;
AF	Africa
AS	Asia
EU	Europe
NA	North America
SA	South America
OC	Oceania
AN	Antarctica
\.


--
-- Data for Name: sys_countrys; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_number, sys_phone_code, sys_country_name, sys_currency_name, sys_currency_cents, sys_currency_code, sys_currency_exchange) FROM stdin;
AF	AS	AFG	004	\N	Afghanistan	\N	\N	\N	\N
AX	EU	ALA	248	\N	Aland Islands	\N	\N	\N	\N
AL	EU	ALB	008	\N	Albania	\N	\N	\N	\N
DZ	AF	DZA	012	\N	Algeria	\N	\N	\N	\N
AS	OC	ASM	016	\N	American Samoa	\N	\N	\N	\N
AD	EU	AND	020	\N	Andorra	\N	\N	\N	\N
AO	AF	AGO	024	\N	Angola	\N	\N	\N	\N
AI	NA	AIA	660	\N	Anguilla	\N	\N	\N	\N
AQ	AN	ATA	010	\N	Antarctica	\N	\N	\N	\N
AG	NA	ATG	028	\N	Antigua and Barbuda	\N	\N	\N	\N
AR	SA	ARG	032	\N	Argentina	\N	\N	\N	\N
AM	AS	ARM	051	\N	Armenia	\N	\N	\N	\N
AW	NA	ABW	533	\N	Aruba	\N	\N	\N	\N
AU	OC	AUS	036	\N	Australia	\N	\N	\N	\N
AT	EU	AUT	040	\N	Austria	\N	\N	\N	\N
AZ	AS	AZE	031	\N	Azerbaijan	\N	\N	\N	\N
BS	NA	BHS	044	\N	Bahamas	\N	\N	\N	\N
BH	AS	BHR	048	\N	Bahrain	\N	\N	\N	\N
BD	AS	BGD	050	\N	Bangladesh	\N	\N	\N	\N
BB	NA	BRB	052	\N	Barbados	\N	\N	\N	\N
BY	EU	BLR	112	\N	Belarus	\N	\N	\N	\N
BE	EU	BEL	056	\N	Belgium	\N	\N	\N	\N
BZ	NA	BLZ	084	\N	Belize	\N	\N	\N	\N
BJ	AF	BEN	204	\N	Benin	\N	\N	\N	\N
BM	NA	BMU	060	\N	Bermuda	\N	\N	\N	\N
BT	AS	BTN	064	\N	Bhutan	\N	\N	\N	\N
BO	SA	BOL	068	\N	Bolivia	\N	\N	\N	\N
BA	EU	BIH	070	\N	Bosnia and Herzegovina	\N	\N	\N	\N
BW	AF	BWA	072	\N	Botswana	\N	\N	\N	\N
BV	AN	BVT	074	\N	Bouvet Island	\N	\N	\N	\N
BR	SA	BRA	076	\N	Brazil	\N	\N	\N	\N
IO	AS	IOT	086	\N	British Indian Ocean Territory	\N	\N	\N	\N
VG	NA	VGB	092	\N	British Virgin Islands	\N	\N	\N	\N
BN	AS	BRN	096	\N	Brunei Darussalam	\N	\N	\N	\N
BG	EU	BGR	100	\N	Bulgaria	\N	\N	\N	\N
BF	AF	BFA	854	\N	Burkina Faso	\N	\N	\N	\N
BI	AF	BDI	108	\N	Burundi	\N	\N	\N	\N
KH	AS	KHM	116	\N	Cambodia	\N	\N	\N	\N
CM	AF	CMR	120	\N	Cameroon	\N	\N	\N	\N
CA	NA	CAN	124	\N	Canada	\N	\N	\N	\N
CV	AF	CPV	132	\N	Cape Verde	\N	\N	\N	\N
KY	NA	CYM	136	\N	Cayman Islands	\N	\N	\N	\N
CF	AF	CAF	140	\N	Central African Republic	\N	\N	\N	\N
TD	AF	TCD	148	\N	Chad	\N	\N	\N	\N
CL	SA	CHL	152	\N	Chile	\N	\N	\N	\N
CN	AS	CHN	156	\N	China	\N	\N	\N	\N
CX	AS	CXR	162	\N	Christmas Island	\N	\N	\N	\N
CC	AS	CCK	166	\N	Cocos Keeling Islands	\N	\N	\N	\N
CO	SA	COL	170	\N	Colombia	\N	\N	\N	\N
KM	AF	COM	174	\N	Comoros	\N	\N	\N	\N
CD	AF	COD	180	\N	Democratic Republic of Congo	\N	\N	\N	\N
CG	AF	COG	178	\N	Republic of Congo	\N	\N	\N	\N
CK	OC	COK	184	\N	Cook Islands	\N	\N	\N	\N
CR	NA	CRI	188	\N	Costa Rica	\N	\N	\N	\N
CI	AF	CIV	384	\N	Cote d Ivoire	\N	\N	\N	\N
HR	EU	HRV	191	\N	Croatia	\N	\N	\N	\N
CU	NA	CUB	192	\N	Cuba	\N	\N	\N	\N
CY	AS	CYP	196	\N	Cyprus	\N	\N	\N	\N
CZ	EU	CZE	203	\N	Czech Republic	\N	\N	\N	\N
DK	EU	DNK	208	\N	Denmark	\N	\N	\N	\N
DJ	AF	DJI	262	\N	Djibouti	\N	\N	\N	\N
DM	NA	DMA	212	\N	Dominica	\N	\N	\N	\N
DO	NA	DOM	214	\N	Dominican Republic	\N	\N	\N	\N
EC	SA	ECU	218	\N	Ecuador	\N	\N	\N	\N
EG	AF	EGY	818	\N	Egypt	\N	\N	\N	\N
SV	NA	SLV	222	\N	El Salvador	\N	\N	\N	\N
GQ	AF	GNQ	226	\N	Equatorial Guinea	\N	\N	\N	\N
ER	AF	ERI	232	\N	Eritrea	\N	\N	\N	\N
EE	EU	EST	233	\N	Estonia	\N	\N	\N	\N
ET	AF	ETH	231	\N	Ethiopia	\N	\N	\N	\N
FO	EU	FRO	234	\N	Faroe Islands	\N	\N	\N	\N
FK	SA	FLK	238	\N	Falkland Islands	\N	\N	\N	\N
FJ	OC	FJI	242	\N	Fiji	\N	\N	\N	\N
FI	EU	FIN	246	\N	Finland	\N	\N	\N	\N
FR	EU	FRA	250	\N	France	\N	\N	\N	\N
GF	SA	GUF	254	\N	French Guiana	\N	\N	\N	\N
PF	OC	PYF	258	\N	French Polynesia	\N	\N	\N	\N
TF	AN	ATF	260	\N	French Southern Territories	\N	\N	\N	\N
GA	AF	GAB	266	\N	Gabon	\N	\N	\N	\N
GM	AF	GMB	270	\N	Gambia	\N	\N	\N	\N
GE	AS	GEO	268	\N	Georgia	\N	\N	\N	\N
DE	EU	DEU	276	\N	Germany	\N	\N	\N	\N
GH	AF	GHA	288	\N	Ghana	\N	\N	\N	\N
GI	EU	GIB	292	\N	Gibraltar	\N	\N	\N	\N
GR	EU	GRC	300	\N	Greece	\N	\N	\N	\N
GL	NA	GRL	304	\N	Greenland	\N	\N	\N	\N
GD	NA	GRD	308	\N	Grenada	\N	\N	\N	\N
GP	NA	GLP	312	\N	Guadeloupe	\N	\N	\N	\N
GU	OC	GUM	316	\N	Guam	\N	\N	\N	\N
GT	NA	GTM	320	\N	Guatemala	\N	\N	\N	\N
GG	EU	GGY	831	\N	Guernsey	\N	\N	\N	\N
GN	AF	GIN	324	\N	Guinea	\N	\N	\N	\N
GW	AF	GNB	624	\N	Guinea-Bissau	\N	\N	\N	\N
GY	SA	GUY	328	\N	Guyana	\N	\N	\N	\N
HT	NA	HTI	332	\N	Haiti	\N	\N	\N	\N
HM	AN	HMD	334	\N	Heard Island and McDonald Islands	\N	\N	\N	\N
VA	EU	VAT	336	\N	Vatican City State	\N	\N	\N	\N
HN	NA	HND	340	\N	Honduras	\N	\N	\N	\N
HK	AS	HKG	344	\N	Hong Kong	\N	\N	\N	\N
HU	EU	HUN	348	\N	Hungary	\N	\N	\N	\N
IS	EU	ISL	352	\N	Iceland	\N	\N	\N	\N
IN	AS	IND	356	\N	India	\N	\N	\N	\N
ID	AS	IDN	360	\N	Indonesia	\N	\N	\N	\N
IR	AS	IRN	364	\N	Iran	\N	\N	\N	\N
IQ	AS	IRQ	368	\N	Iraq	\N	\N	\N	\N
IE	EU	IRL	372	\N	Ireland	\N	\N	\N	\N
IM	EU	IMN	833	\N	Isle of Man	\N	\N	\N	\N
IL	AS	ISR	376	\N	Israel	\N	\N	\N	\N
IT	EU	ITA	380	\N	Italy	\N	\N	\N	\N
JM	NA	JAM	388	\N	Jamaica	\N	\N	\N	\N
JP	AS	JPN	392	\N	Japan	\N	\N	\N	\N
JE	EU	JEY	832	\N	Bailiwick of Jersey	\N	\N	\N	\N
JO	AS	JOR	400	\N	Jordan	\N	\N	\N	\N
KZ	AS	KAZ	398	\N	Kazakhstan	\N	\N	\N	\N
KE	AF	KEN	404	\N	Kenya	\N	\N	\N	\N
KI	OC	KIR	296	\N	Kiribati	\N	\N	\N	\N
KP	AS	PRK	408	\N	North Korea	\N	\N	\N	\N
KR	AS	KOR	410	\N	South Korea	\N	\N	\N	\N
KW	AS	KWT	414	\N	Kuwait	\N	\N	\N	\N
KG	AS	KGZ	417	\N	Kyrgyz Republic	\N	\N	\N	\N
LA	AS	LAO	418	\N	Lao Peoples Democratic Republic	\N	\N	\N	\N
LV	EU	LVA	428	\N	Latvia	\N	\N	\N	\N
LB	AS	LBN	422	\N	Lebanon	\N	\N	\N	\N
LS	AF	LSO	426	\N	Lesotho	\N	\N	\N	\N
LR	AF	LBR	430	\N	Liberia	\N	\N	\N	\N
LY	AF	LBY	434	\N	Libyan Arab Jamahiriya	\N	\N	\N	\N
LI	EU	LIE	438	\N	Liechtenstein	\N	\N	\N	\N
LT	EU	LTU	440	\N	Lithuania	\N	\N	\N	\N
LU	EU	LUX	442	\N	Luxembourg	\N	\N	\N	\N
MO	AS	MAC	446	\N	Macao	\N	\N	\N	\N
MK	EU	MKD	807	\N	Macedonia	\N	\N	\N	\N
MG	AF	MDG	450	\N	Madagascar	\N	\N	\N	\N
MW	AF	MWI	454	\N	Malawi	\N	\N	\N	\N
MY	AS	MYS	458	\N	Malaysia	\N	\N	\N	\N
MV	AS	MDV	462	\N	Maldives	\N	\N	\N	\N
ML	AF	MLI	466	\N	Mali	\N	\N	\N	\N
MT	EU	MLT	470	\N	Malta	\N	\N	\N	\N
MH	OC	MHL	584	\N	Marshall Islands	\N	\N	\N	\N
MQ	NA	MTQ	474	\N	Martinique	\N	\N	\N	\N
MR	AF	MRT	478	\N	Mauritania	\N	\N	\N	\N
MU	AF	MUS	480	\N	Mauritius	\N	\N	\N	\N
YT	AF	MYT	175	\N	Mayotte	\N	\N	\N	\N
MX	NA	MEX	484	\N	Mexico	\N	\N	\N	\N
FM	OC	FSM	583	\N	Micronesia	\N	\N	\N	\N
MD	EU	MDA	498	\N	Moldova	\N	\N	\N	\N
MC	EU	MCO	492	\N	Monaco	\N	\N	\N	\N
MN	AS	MNG	496	\N	Mongolia	\N	\N	\N	\N
ME	EU	MNE	499	\N	Montenegro	\N	\N	\N	\N
MS	NA	MSR	500	\N	Montserrat	\N	\N	\N	\N
MA	AF	MAR	504	\N	Morocco	\N	\N	\N	\N
MZ	AF	MOZ	508	\N	Mozambique	\N	\N	\N	\N
MM	AS	MMR	104	\N	Myanmar	\N	\N	\N	\N
NA	AF	NAM	516	\N	Namibia	\N	\N	\N	\N
NR	OC	NRU	520	\N	Nauru	\N	\N	\N	\N
NP	AS	NPL	524	\N	Nepal	\N	\N	\N	\N
AN	NA	ANT	530	\N	Netherlands Antilles	\N	\N	\N	\N
NL	EU	NLD	528	\N	Netherlands	\N	\N	\N	\N
NC	OC	NCL	540	\N	New Caledonia	\N	\N	\N	\N
NZ	OC	NZL	554	\N	New Zealand	\N	\N	\N	\N
NI	NA	NIC	558	\N	Nicaragua	\N	\N	\N	\N
NE	AF	NER	562	\N	Niger	\N	\N	\N	\N
NG	AF	NGA	566	\N	Nigeria	\N	\N	\N	\N
NU	OC	NIU	570	\N	Niue	\N	\N	\N	\N
NF	OC	NFK	574	\N	Norfolk Island	\N	\N	\N	\N
MP	OC	MNP	580	\N	Northern Mariana Islands	\N	\N	\N	\N
NO	EU	NOR	578	\N	Norway	\N	\N	\N	\N
OM	AS	OMN	512	\N	Oman	\N	\N	\N	\N
PK	AS	PAK	586	\N	Pakistan	\N	\N	\N	\N
PW	OC	PLW	585	\N	Palau	\N	\N	\N	\N
PS	AS	PSE	275	\N	Palestinian Territory	\N	\N	\N	\N
PA	NA	PAN	591	\N	Panama	\N	\N	\N	\N
PG	OC	PNG	598	\N	Papua New Guinea	\N	\N	\N	\N
PY	SA	PRY	600	\N	Paraguay	\N	\N	\N	\N
PE	SA	PER	604	\N	Peru	\N	\N	\N	\N
PH	AS	PHL	608	\N	Philippines	\N	\N	\N	\N
PN	OC	PCN	612	\N	Pitcairn Islands	\N	\N	\N	\N
PL	EU	POL	616	\N	Poland	\N	\N	\N	\N
PT	EU	PRT	620	\N	Portugal	\N	\N	\N	\N
PR	NA	PRI	630	\N	Puerto Rico	\N	\N	\N	\N
QA	AS	QAT	634	\N	Qatar	\N	\N	\N	\N
RE	AF	REU	638	\N	Reunion	\N	\N	\N	\N
RO	EU	ROU	642	\N	Romania	\N	\N	\N	\N
RU	EU	RUS	643	\N	Russian Federation	\N	\N	\N	\N
RW	AF	RWA	646	\N	Rwanda	\N	\N	\N	\N
BL	NA	BLM	652	\N	Saint Barthelemy	\N	\N	\N	\N
SH	AF	SHN	654	\N	Saint Helena	\N	\N	\N	\N
KN	NA	KNA	659	\N	Saint Kitts and Nevis	\N	\N	\N	\N
LC	NA	LCA	662	\N	Saint Lucia	\N	\N	\N	\N
MF	NA	MAF	663	\N	Saint Martin	\N	\N	\N	\N
PM	NA	SPM	666	\N	Saint Pierre and Miquelon	\N	\N	\N	\N
VC	NA	VCT	670	\N	Saint Vincent and the Grenadines	\N	\N	\N	\N
WS	OC	WSM	882	\N	Samoa	\N	\N	\N	\N
SM	EU	SMR	674	\N	San Marino	\N	\N	\N	\N
ST	AF	STP	678	\N	Sao Tome and Principe	\N	\N	\N	\N
SA	AS	SAU	682	\N	Saudi Arabia	\N	\N	\N	\N
SN	AF	SEN	686	\N	Senegal	\N	\N	\N	\N
RS	EU	SRB	688	\N	Serbia	\N	\N	\N	\N
SC	AF	SYC	690	\N	Seychelles	\N	\N	\N	\N
SL	AF	SLE	694	\N	Sierra Leone	\N	\N	\N	\N
SG	AS	SGP	702	\N	Singapore	\N	\N	\N	\N
SK	EU	SVK	703	\N	Slovakia	\N	\N	\N	\N
SI	EU	SVN	705	\N	Slovenia	\N	\N	\N	\N
SB	OC	SLB	090	\N	Solomon Islands	\N	\N	\N	\N
SO	AF	SOM	706	\N	Somalia	\N	\N	\N	\N
ZA	AF	ZAF	710	\N	South Africa	\N	\N	\N	\N
GS	AN	SGS	239	\N	South Georgia and the South Sandwich Islands	\N	\N	\N	\N
ES	EU	ESP	724	\N	Spain	\N	\N	\N	\N
LK	AS	LKA	144	\N	Sri Lanka	\N	\N	\N	\N
SD	AF	SDN	736	\N	Sudan	\N	\N	\N	\N
SS	AF	SSN	737	\N	South Sudan	\N	\N	\N	\N
SR	SA	SUR	740	\N	Suriname	\N	\N	\N	\N
SJ	EU	SJM	744	\N	Svalbard & Jan Mayen Islands	\N	\N	\N	\N
SZ	AF	SWZ	748	\N	Swaziland	\N	\N	\N	\N
SE	EU	SWE	752	\N	Sweden	\N	\N	\N	\N
CH	EU	CHE	756	\N	Switzerland	\N	\N	\N	\N
SY	AS	SYR	760	\N	Syrian Arab Republic	\N	\N	\N	\N
TW	AS	TWN	158	\N	Taiwan	\N	\N	\N	\N
TJ	AS	TJK	762	\N	Tajikistan	\N	\N	\N	\N
TZ	AF	TZA	834	\N	Tanzania	\N	\N	\N	\N
TH	AS	THA	764	\N	Thailand	\N	\N	\N	\N
TL	AS	TLS	626	\N	Timor-Leste	\N	\N	\N	\N
TG	AF	TGO	768	\N	Togo	\N	\N	\N	\N
TK	OC	TKL	772	\N	Tokelau	\N	\N	\N	\N
TO	OC	TON	776	\N	Tonga	\N	\N	\N	\N
TT	NA	TTO	780	\N	Trinidad and Tobago	\N	\N	\N	\N
TN	AF	TUN	788	\N	Tunisia	\N	\N	\N	\N
TR	AS	TUR	792	\N	Turkey	\N	\N	\N	\N
TM	AS	TKM	795	\N	Turkmenistan	\N	\N	\N	\N
TC	NA	TCA	796	\N	Turks and Caicos Islands	\N	\N	\N	\N
TV	OC	TUV	798	\N	Tuvalu	\N	\N	\N	\N
UG	AF	UGA	800	\N	Uganda	\N	\N	\N	\N
UA	EU	UKR	804	\N	Ukraine	\N	\N	\N	\N
AE	AS	ARE	784	\N	United Arab Emirates	\N	\N	\N	\N
GB	EU	GBR	826	\N	United Kingdom of Great Britain & Northern Ireland	\N	\N	\N	\N
US	NA	USA	840	\N	United States of America	\N	\N	\N	\N
UM	OC	UMI	581	\N	United States Minor Outlying Islands	\N	\N	\N	\N
VI	NA	VIR	850	\N	United States Virgin Islands	\N	\N	\N	\N
UY	SA	URY	858	\N	Uruguay	\N	\N	\N	\N
UZ	AS	UZB	860	\N	Uzbekistan	\N	\N	\N	\N
VU	OC	VUT	548	\N	Vanuatu	\N	\N	\N	\N
VE	SA	VEN	862	\N	Venezuela	\N	\N	\N	\N
VN	AS	VNM	704	\N	Vietnam	\N	\N	\N	\N
WF	OC	WLF	876	\N	Wallis and Futuna	\N	\N	\N	\N
EH	AF	ESH	732	\N	Western Sahara	\N	\N	\N	\N
YE	AS	YEM	887	\N	Yemen	\N	\N	\N	\N
ZM	AF	ZMB	894	\N	Zambia	\N	\N	\N	\N
ZW	AF	ZWE	716	\N	Zimbabwe	\N	\N	\N	\N
\.


--
-- Data for Name: sys_dashboard; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_dashboard (sys_dashboard_id, org_id, entity_id, narrative, details) FROM stdin;
\.


--
-- Data for Name: sys_emailed; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_emailed (sys_emailed_id, org_id, sys_email_id, table_id, table_name, email_type, emailed, narrative) FROM stdin;
\.


--
-- Data for Name: sys_emails; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_emails (sys_email_id, org_id, sys_email_name, title, details) FROM stdin;
\.


--
-- Data for Name: sys_errors; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_errors (sys_error_id, sys_error, error_message) FROM stdin;
\.


--
-- Data for Name: sys_files; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_files (sys_file_id, org_id, table_id, table_name, file_name, file_type, file_size, narrative, details) FROM stdin;
\.


--
-- Data for Name: sys_logins; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) FROM stdin;
1	0	2013-08-14 08:42:08.248249	127.0.0.1	\N
\.


--
-- Data for Name: sys_news; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_news (sys_news_id, org_id, sys_news_group, sys_news_title, publish, details) FROM stdin;
\.


--
-- Data for Name: sys_queries; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_queries (sys_queries_id, org_id, sys_query_name, query_date, query_text, query_params) FROM stdin;
\.


--
-- Data for Name: sys_reset; Type: TABLE DATA; Schema: public; Owner: root
--

COPY sys_reset (sys_login_id, entity_id, request_email, request_time, login_ip, narrative) FROM stdin;
\.


--
-- Data for Name: wards; Type: TABLE DATA; Schema: public; Owner: root
--

COPY wards (ward_id, constituency_id, ward_name, ward_code, details) FROM stdin;
\.


--
-- Data for Name: workflow_phases; Type: TABLE DATA; Schema: public; Owner: root
--

COPY workflow_phases (workflow_phase_id, org_id, workflow_id, approval_entity_id, approval_level, return_level, escalation_days, escalation_hours, required_approvals, advice, notice, phase_narrative, advice_email, notice_email, advice_file, notice_file, details) FROM stdin;
\.


--
-- Data for Name: workflow_sql; Type: TABLE DATA; Schema: public; Owner: root
--

COPY workflow_sql (workflow_sql_id, org_id, workflow_phase_id, workflow_sql_name, is_condition, is_action, message_number, ca_sql) FROM stdin;
\.


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: root
--

COPY workflows (workflow_id, org_id, source_entity_id, workflow_name, table_name, table_link_field, table_link_id, approve_email, reject_email, approve_file, reject_file, details) FROM stdin;
\.


--
-- Name: activity_results_activity_result_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY activity_results
    ADD CONSTRAINT activity_results_activity_result_name_key UNIQUE (activity_result_name);


--
-- Name: activity_results_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY activity_results
    ADD CONSTRAINT activity_results_pkey PRIMARY KEY (activity_result_id);


--
-- Name: activitys_activity_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY activitys
    ADD CONSTRAINT activitys_activity_name_key UNIQUE (activity_name);


--
-- Name: activitys_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY activitys
    ADD CONSTRAINT activitys_pkey PRIMARY KEY (activity_id);


--
-- Name: address_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: address_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (address_type_id);


--
-- Name: adjorn_reasons_adjorn_reason_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY adjorn_reasons
    ADD CONSTRAINT adjorn_reasons_adjorn_reason_name_key UNIQUE (adjorn_reason_name);


--
-- Name: adjorn_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY adjorn_reasons
    ADD CONSTRAINT adjorn_reasons_pkey PRIMARY KEY (adjorn_reason_id);


--
-- Name: approval_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_pkey PRIMARY KEY (approval_checklist_id);


--
-- Name: approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (approval_id);


--
-- Name: bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_pkey PRIMARY KEY (bank_account_id);


--
-- Name: bench_subjects_entity_id_case_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY bench_subjects
    ADD CONSTRAINT bench_subjects_entity_id_case_subject_id_key UNIQUE (entity_id, case_subject_id);


--
-- Name: bench_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY bench_subjects
    ADD CONSTRAINT bench_subjects_pkey PRIMARY KEY (bench_subject_id);


--
-- Name: cal_block_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY cal_block_types
    ADD CONSTRAINT cal_block_types_pkey PRIMARY KEY (cal_block_type_id);


--
-- Name: cal_entity_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY cal_entity_blocks
    ADD CONSTRAINT cal_entity_blocks_pkey PRIMARY KEY (cal_entity_block_id);


--
-- Name: cal_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY cal_holidays
    ADD CONSTRAINT cal_holidays_pkey PRIMARY KEY (cal_holiday_id);


--
-- Name: case_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_pkey PRIMARY KEY (case_activity_id);


--
-- Name: case_bookmarks_case_id_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_bookmarks
    ADD CONSTRAINT case_bookmarks_case_id_entity_id_key UNIQUE (case_id, entity_id);


--
-- Name: case_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_bookmarks
    ADD CONSTRAINT case_bookmarks_pkey PRIMARY KEY (case_bookmark_id);


--
-- Name: case_category_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_category
    ADD CONSTRAINT case_category_pkey PRIMARY KEY (case_category_id);


--
-- Name: case_contacts_case_id_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_case_id_entity_id_key UNIQUE (case_id, entity_id);


--
-- Name: case_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_pkey PRIMARY KEY (case_contact_id);


--
-- Name: case_counts_case_contact_id_case_category_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_counts
    ADD CONSTRAINT case_counts_case_contact_id_case_category_id_key UNIQUE (case_contact_id, case_category_id);


--
-- Name: case_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_counts
    ADD CONSTRAINT case_counts_pkey PRIMARY KEY (case_count_id);


--
-- Name: case_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_pkey PRIMARY KEY (case_decision_id);


--
-- Name: case_files_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_files
    ADD CONSTRAINT case_files_pkey PRIMARY KEY (case_file_id);


--
-- Name: case_insurance_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_insurance
    ADD CONSTRAINT case_insurance_pkey PRIMARY KEY (case_insurance_id);


--
-- Name: case_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_notes
    ADD CONSTRAINT case_notes_pkey PRIMARY KEY (case_note_id);


--
-- Name: case_quorum_case_activity_id_case_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_quorum
    ADD CONSTRAINT case_quorum_case_activity_id_case_contact_id_key UNIQUE (case_activity_id, case_contact_id);


--
-- Name: case_quorum_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_quorum
    ADD CONSTRAINT case_quorum_pkey PRIMARY KEY (case_quorum_id);


--
-- Name: case_subjects_case_subject_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_subjects
    ADD CONSTRAINT case_subjects_case_subject_name_key UNIQUE (case_subject_name);


--
-- Name: case_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_subjects
    ADD CONSTRAINT case_subjects_pkey PRIMARY KEY (case_subject_id);


--
-- Name: case_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_pkey PRIMARY KEY (case_transfer_id);


--
-- Name: case_types_case_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_types
    ADD CONSTRAINT case_types_case_type_name_key UNIQUE (case_type_name);


--
-- Name: case_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_types
    ADD CONSTRAINT case_types_pkey PRIMARY KEY (case_type_id);


--
-- Name: cases_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (case_id);


--
-- Name: category_activitys_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY category_activitys
    ADD CONSTRAINT category_activitys_pkey PRIMARY KEY (category_activity_id);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: constituency_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY constituency
    ADD CONSTRAINT constituency_pkey PRIMARY KEY (constituency_id);


--
-- Name: contact_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY contact_types
    ADD CONSTRAINT contact_types_pkey PRIMARY KEY (contact_type_id);


--
-- Name: counties_county_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY counties
    ADD CONSTRAINT counties_county_name_key UNIQUE (county_name);


--
-- Name: counties_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY counties
    ADD CONSTRAINT counties_pkey PRIMARY KEY (county_id);


--
-- Name: court_bankings_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_bankings
    ADD CONSTRAINT court_bankings_pkey PRIMARY KEY (court_banking_id);


--
-- Name: court_divisions_court_station_id_division_type_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_divisions
    ADD CONSTRAINT court_divisions_court_station_id_division_type_id_key UNIQUE (court_station_id, division_type_id);


--
-- Name: court_divisions_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_divisions
    ADD CONSTRAINT court_divisions_pkey PRIMARY KEY (court_division_id);


--
-- Name: court_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_payments
    ADD CONSTRAINT court_payments_pkey PRIMARY KEY (court_payment_id);


--
-- Name: court_ranks_court_rank_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_ranks
    ADD CONSTRAINT court_ranks_court_rank_name_key UNIQUE (court_rank_name);


--
-- Name: court_ranks_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_ranks
    ADD CONSTRAINT court_ranks_pkey PRIMARY KEY (court_rank_id);


--
-- Name: court_stations_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_stations
    ADD CONSTRAINT court_stations_pkey PRIMARY KEY (court_station_id);


--
-- Name: currency_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (currency_id);


--
-- Name: currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (currency_rate_id);


--
-- Name: dc_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_pkey PRIMARY KEY (dc_case_id);


--
-- Name: dc_category_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY dc_category
    ADD CONSTRAINT dc_category_pkey PRIMARY KEY (dc_category_id);


--
-- Name: dc_judgments_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY dc_judgments
    ADD CONSTRAINT dc_judgments_pkey PRIMARY KEY (dc_judgment_id);


--
-- Name: dc_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY dc_receipts
    ADD CONSTRAINT dc_receipts_pkey PRIMARY KEY (dc_receipt_id);


--
-- Name: decision_types_decision_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY decision_types
    ADD CONSTRAINT decision_types_decision_type_name_key UNIQUE (decision_type_name);


--
-- Name: decision_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY decision_types
    ADD CONSTRAINT decision_types_pkey PRIMARY KEY (decision_type_id);


--
-- Name: disability_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY disability
    ADD CONSTRAINT disability_pkey PRIMARY KEY (disability_id);


--
-- Name: division_types_division_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY division_types
    ADD CONSTRAINT division_types_division_type_name_key UNIQUE (division_type_name);


--
-- Name: division_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY division_types
    ADD CONSTRAINT division_types_pkey PRIMARY KEY (division_type_id);


--
-- Name: entity_idents_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entity_idents
    ADD CONSTRAINT entity_idents_pkey PRIMARY KEY (entity_ident_id);


--
-- Name: entity_subscriptions_entity_id_entity_type_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_entity_type_id_key UNIQUE (entity_id, entity_type_id);


--
-- Name: entity_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_pkey PRIMARY KEY (entity_subscription_id);


--
-- Name: entity_types_entity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_entity_type_name_key UNIQUE (entity_type_name);


--
-- Name: entity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (entity_type_id);


--
-- Name: entitys_org_id_user_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_org_id_user_name_key UNIQUE (org_id, user_name);


--
-- Name: entitys_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_pkey PRIMARY KEY (entity_id);


--
-- Name: entry_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_pkey PRIMARY KEY (entry_form_id);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: file_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY file_locations
    ADD CONSTRAINT file_locations_pkey PRIMARY KEY (file_location_id);


--
-- Name: folders_folder_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY folders
    ADD CONSTRAINT folders_folder_name_key UNIQUE (folder_name);


--
-- Name: folders_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY folders
    ADD CONSTRAINT folders_pkey PRIMARY KEY (folder_id);


--
-- Name: forms_form_name_version_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_form_name_version_key UNIQUE (form_name, version);


--
-- Name: forms_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_pkey PRIMARY KEY (form_id);


--
-- Name: hearing_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY hearing_locations
    ADD CONSTRAINT hearing_locations_pkey PRIMARY KEY (hearing_location_id);


--
-- Name: id_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY id_types
    ADD CONSTRAINT id_types_pkey PRIMARY KEY (id_type_id);


--
-- Name: judgment_status_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY judgment_status
    ADD CONSTRAINT judgment_status_pkey PRIMARY KEY (judgment_status_id);


--
-- Name: log_case_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_pkey PRIMARY KEY (log_case_activity_id);


--
-- Name: log_case_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_pkey PRIMARY KEY (log_case_contact_id);


--
-- Name: log_case_counts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_case_counts
    ADD CONSTRAINT log_case_counts_pkey PRIMARY KEY (log_case_count_id);


--
-- Name: log_case_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_case_decisions
    ADD CONSTRAINT log_case_decisions_pkey PRIMARY KEY (log_case_decision_id);


--
-- Name: log_case_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_case_transfers
    ADD CONSTRAINT log_case_transfers_pkey PRIMARY KEY (log_case_transfer_id);


--
-- Name: log_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_pkey PRIMARY KEY (log_case_id);


--
-- Name: log_court_bankings_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_court_bankings
    ADD CONSTRAINT log_court_bankings_pkey PRIMARY KEY (log_court_banking_id);


--
-- Name: log_court_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_court_payments
    ADD CONSTRAINT log_court_payments_pkey PRIMARY KEY (log_court_payment_id);


--
-- Name: log_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_receipts
    ADD CONSTRAINT log_receipts_pkey PRIMARY KEY (log_receipt_id);


--
-- Name: meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (meeting_id);


--
-- Name: mpesa_trxs_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_pkey PRIMARY KEY (mpesa_trx_id);


--
-- Name: order_types_order_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY order_types
    ADD CONSTRAINT order_types_order_type_name_key UNIQUE (order_type_name);


--
-- Name: order_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY order_types
    ADD CONSTRAINT order_types_pkey PRIMARY KEY (order_type_id);


--
-- Name: orgs_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_pkey PRIMARY KEY (org_id);


--
-- Name: participants_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY participants
    ADD CONSTRAINT participants_pkey PRIMARY KEY (participant_id);


--
-- Name: payment_types_payment_type_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_payment_type_name_key UNIQUE (payment_type_name);


--
-- Name: payment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY payment_types
    ADD CONSTRAINT payment_types_pkey PRIMARY KEY (payment_type_id);


--
-- Name: police_stations_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY police_stations
    ADD CONSTRAINT police_stations_pkey PRIMARY KEY (police_station_id);


--
-- Name: political_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY political_parties
    ADD CONSTRAINT political_parties_pkey PRIMARY KEY (political_party_id);


--
-- Name: rankings_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY rankings
    ADD CONSTRAINT rankings_pkey PRIMARY KEY (ranking_id);


--
-- Name: rankings_ranking_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY rankings
    ADD CONSTRAINT rankings_ranking_name_key UNIQUE (ranking_name);


--
-- Name: receipt_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY receipt_types
    ADD CONSTRAINT receipt_types_pkey PRIMARY KEY (receipt_type_id);


--
-- Name: receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (receipt_id);


--
-- Name: regions_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (region_id);


--
-- Name: regions_region_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY regions
    ADD CONSTRAINT regions_region_name_key UNIQUE (region_name);


--
-- Name: sms_address_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sms_address
    ADD CONSTRAINT sms_address_pkey PRIMARY KEY (sms_address_id);


--
-- Name: sms_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sms_groups
    ADD CONSTRAINT sms_groups_pkey PRIMARY KEY (sms_groups_id);


--
-- Name: sms_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_pkey PRIMARY KEY (sms_id);


--
-- Name: sms_trans_origin_sms_time_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sms_trans
    ADD CONSTRAINT sms_trans_origin_sms_time_key UNIQUE (origin, sms_time);


--
-- Name: sms_trans_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sms_trans
    ADD CONSTRAINT sms_trans_pkey PRIMARY KEY (sms_trans_id);


--
-- Name: sub_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_pkey PRIMARY KEY (sub_field_id);


--
-- Name: subscription_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_pkey PRIMARY KEY (subscription_level_id);


--
-- Name: surerity_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY surerity
    ADD CONSTRAINT surerity_pkey PRIMARY KEY (surerity_id);


--
-- Name: sys_audit_details_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_pkey PRIMARY KEY (sys_audit_detail_id);


--
-- Name: sys_audit_trail_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_audit_trail
    ADD CONSTRAINT sys_audit_trail_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_continents_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_pkey PRIMARY KEY (sys_continent_id);


--
-- Name: sys_continents_sys_continent_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_sys_continent_name_key UNIQUE (sys_continent_name);


--
-- Name: sys_countrys_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_pkey PRIMARY KEY (sys_country_id);


--
-- Name: sys_countrys_sys_country_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_country_name_key UNIQUE (sys_country_name);


--
-- Name: sys_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_pkey PRIMARY KEY (sys_dashboard_id);


--
-- Name: sys_emailed_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_pkey PRIMARY KEY (sys_emailed_id);


--
-- Name: sys_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_pkey PRIMARY KEY (sys_email_id);


--
-- Name: sys_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_errors
    ADD CONSTRAINT sys_errors_pkey PRIMARY KEY (sys_error_id);


--
-- Name: sys_files_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_pkey PRIMARY KEY (sys_file_id);


--
-- Name: sys_logins_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_pkey PRIMARY KEY (sys_login_id);


--
-- Name: sys_news_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_pkey PRIMARY KEY (sys_news_id);


--
-- Name: sys_queries_org_id_sys_query_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_sys_query_name_key UNIQUE (org_id, sys_query_name);


--
-- Name: sys_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_pkey PRIMARY KEY (sys_queries_id);


--
-- Name: sys_reset_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_pkey PRIMARY KEY (sys_login_id);


--
-- Name: wards_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY wards
    ADD CONSTRAINT wards_pkey PRIMARY KEY (ward_id);


--
-- Name: workflow_phases_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_pkey PRIMARY KEY (workflow_phase_id);


--
-- Name: workflow_sql_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_pkey PRIMARY KEY (workflow_sql_id);


--
-- Name: workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (workflow_id);


--
-- Name: address_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX address_org_id ON address USING btree (org_id);


--
-- Name: address_sys_country_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX address_sys_country_id ON address USING btree (sys_country_id);


--
-- Name: address_table_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX address_table_id ON address USING btree (table_id);


--
-- Name: address_table_name; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX address_table_name ON address USING btree (table_name);


--
-- Name: approval_checklists_approval_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approval_checklists_approval_id ON approval_checklists USING btree (approval_id);


--
-- Name: approval_checklists_checklist_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approval_checklists_checklist_id ON approval_checklists USING btree (checklist_id);


--
-- Name: approval_checklists_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approval_checklists_org_id ON approval_checklists USING btree (org_id);


--
-- Name: approvals_app_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_app_entity_id ON approvals USING btree (app_entity_id);


--
-- Name: approvals_approve_status; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_approve_status ON approvals USING btree (approve_status);


--
-- Name: approvals_forward_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_forward_id ON approvals USING btree (forward_id);


--
-- Name: approvals_org_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_org_entity_id ON approvals USING btree (org_entity_id);


--
-- Name: approvals_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_org_id ON approvals USING btree (org_id);


--
-- Name: approvals_table_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_table_id ON approvals USING btree (table_id);


--
-- Name: approvals_workflow_phase_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX approvals_workflow_phase_id ON approvals USING btree (workflow_phase_id);


--
-- Name: bank_accounts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX bank_accounts_org_id ON bank_accounts USING btree (org_id);


--
-- Name: bench_subjects_case_subject_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX bench_subjects_case_subject_id ON bench_subjects USING btree (case_subject_id);


--
-- Name: bench_subjects_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX bench_subjects_entity_id ON bench_subjects USING btree (entity_id);


--
-- Name: bench_subjects_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX bench_subjects_org_id ON bench_subjects USING btree (org_id);


--
-- Name: cal_entity_blocks_cal_block_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cal_entity_blocks_cal_block_type_id ON cal_entity_blocks USING btree (cal_block_type_id);


--
-- Name: cal_entity_blocks_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cal_entity_blocks_entity_id ON cal_entity_blocks USING btree (entity_id);


--
-- Name: cal_entity_blocks_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cal_entity_blocks_org_id ON cal_entity_blocks USING btree (org_id);


--
-- Name: case_activity_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_activity_id ON case_activity USING btree (activity_id);


--
-- Name: case_activity_activity_result_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_activity_result_id ON case_activity USING btree (activity_result_id);


--
-- Name: case_activity_adjorn_reason_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_adjorn_reason_id ON case_activity USING btree (adjorn_reason_id);


--
-- Name: case_activity_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_case_id ON case_activity USING btree (case_id);


--
-- Name: case_activity_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_court_station_id ON case_activity USING btree (court_station_id);


--
-- Name: case_activity_hearing_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_hearing_location_id ON case_activity USING btree (hearing_location_id);


--
-- Name: case_activity_order_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_order_type_id ON case_activity USING btree (order_type_id);


--
-- Name: case_activity_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_org_id ON case_activity USING btree (org_id);


--
-- Name: case_bookmarks_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_bookmarks_case_id ON case_bookmarks USING btree (case_id);


--
-- Name: case_bookmarks_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_bookmarks_entity_id ON case_bookmarks USING btree (entity_id);


--
-- Name: case_bookmarks_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_bookmarks_org_id ON case_bookmarks USING btree (org_id);


--
-- Name: case_category_case_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_category_case_type_id ON case_category USING btree (case_type_id);


--
-- Name: case_contacts_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_contacts_case_id ON case_contacts USING btree (case_id);


--
-- Name: case_contacts_contact_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_contacts_contact_type_id ON case_contacts USING btree (contact_type_id);


--
-- Name: case_contacts_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_contacts_entity_id ON case_contacts USING btree (entity_id);


--
-- Name: case_contacts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_contacts_org_id ON case_contacts USING btree (org_id);


--
-- Name: case_contacts_political_party_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_contacts_political_party_id ON case_contacts USING btree (political_party_id);


--
-- Name: case_counts_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_counts_case_category_id ON case_counts USING btree (case_category_id);


--
-- Name: case_counts_case_contact_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_counts_case_contact_id ON case_counts USING btree (case_contact_id);


--
-- Name: case_counts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_counts_org_id ON case_counts USING btree (org_id);


--
-- Name: case_decisions_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_case_activity_id ON case_decisions USING btree (case_activity_id);


--
-- Name: case_decisions_case_count_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_case_count_id ON case_decisions USING btree (case_count_id);


--
-- Name: case_decisions_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_case_id ON case_decisions USING btree (case_id);


--
-- Name: case_decisions_decision_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_decision_type_id ON case_decisions USING btree (decision_type_id);


--
-- Name: case_decisions_judgment_status_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_judgment_status_id ON case_decisions USING btree (judgment_status_id);


--
-- Name: case_decisions_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_org_id ON case_decisions USING btree (org_id);


--
-- Name: case_files_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_case_activity_id ON case_files USING btree (case_activity_id);


--
-- Name: case_files_case_decision_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_case_decision_id ON case_files USING btree (case_decision_id);


--
-- Name: case_files_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_case_id ON case_files USING btree (case_id);


--
-- Name: case_files_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_org_id ON case_files USING btree (org_id);


--
-- Name: case_insurance_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_insurance_case_id ON case_insurance USING btree (case_id);


--
-- Name: case_insurance_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_insurance_org_id ON case_insurance USING btree (org_id);


--
-- Name: case_notes_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_notes_case_activity_id ON case_notes USING btree (case_activity_id);


--
-- Name: case_notes_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_notes_entity_id ON case_notes USING btree (entity_id);


--
-- Name: case_notes_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_notes_org_id ON case_notes USING btree (org_id);


--
-- Name: case_quorum_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_quorum_case_activity_id ON case_quorum USING btree (case_activity_id);


--
-- Name: case_quorum_case_contact_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_quorum_case_contact_id ON case_quorum USING btree (case_contact_id);


--
-- Name: case_quorum_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_quorum_org_id ON case_quorum USING btree (org_id);


--
-- Name: case_transfers_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_case_category_id ON case_transfers USING btree (case_category_id);


--
-- Name: case_transfers_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_case_id ON case_transfers USING btree (case_id);


--
-- Name: case_transfers_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_court_division_id ON case_transfers USING btree (court_division_id);


--
-- Name: case_transfers_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_org_id ON case_transfers USING btree (org_id);


--
-- Name: cases_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_case_category_id ON cases USING btree (case_category_id);


--
-- Name: cases_case_subject_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_case_subject_id ON cases USING btree (case_subject_id);


--
-- Name: cases_constituency_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_constituency_id ON cases USING btree (constituency_id);


--
-- Name: cases_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_court_division_id ON cases USING btree (court_division_id);


--
-- Name: cases_file_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_file_location_id ON cases USING btree (file_location_id);


--
-- Name: cases_new_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_new_case_id ON cases USING btree (new_case_id);


--
-- Name: cases_old_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_old_case_id ON cases USING btree (old_case_id);


--
-- Name: cases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_org_id ON cases USING btree (org_id);


--
-- Name: cases_police_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_police_station_id ON cases USING btree (police_station_id);


--
-- Name: cases_ward_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_ward_id ON cases USING btree (ward_id);


--
-- Name: category_activitys_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX category_activitys_activity_id ON category_activitys USING btree (activity_id);


--
-- Name: category_activitys_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX category_activitys_case_category_id ON category_activitys USING btree (case_category_id);


--
-- Name: category_activitys_contact_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX category_activitys_contact_type_id ON category_activitys USING btree (contact_type_id);


--
-- Name: category_activitys_from_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX category_activitys_from_activity_id ON category_activitys USING btree (from_activity_id);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: constituency_county_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX constituency_county_id ON constituency USING btree (county_id);


--
-- Name: counties_region_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX counties_region_id ON counties USING btree (region_id);


--
-- Name: court_bankings_bank_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_bankings_bank_account_id ON court_bankings USING btree (bank_account_id);


--
-- Name: court_bankings_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_bankings_org_id ON court_bankings USING btree (org_id);


--
-- Name: court_bankings_source_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_bankings_source_account_id ON court_bankings USING btree (source_account_id);


--
-- Name: court_divisions_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_divisions_court_station_id ON court_divisions USING btree (court_station_id);


--
-- Name: court_divisions_division_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_divisions_division_type_id ON court_divisions USING btree (division_type_id);


--
-- Name: court_divisions_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_divisions_org_id ON court_divisions USING btree (org_id);


--
-- Name: court_payments_bank_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_payments_bank_account_id ON court_payments USING btree (bank_account_id);


--
-- Name: court_payments_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_payments_org_id ON court_payments USING btree (org_id);


--
-- Name: court_payments_payment_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_payments_payment_type_id ON court_payments USING btree (payment_type_id);


--
-- Name: court_payments_receipt_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_payments_receipt_id ON court_payments USING btree (receipt_id);


--
-- Name: court_stations_county_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_stations_county_id ON court_stations USING btree (county_id);


--
-- Name: court_stations_court_rank_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_stations_court_rank_id ON court_stations USING btree (court_rank_id);


--
-- Name: court_stations_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_stations_org_id ON court_stations USING btree (org_id);


--
-- Name: currency_rates_currency_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX currency_rates_currency_id ON currency_rates USING btree (currency_id);


--
-- Name: currency_rates_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX currency_rates_org_id ON currency_rates USING btree (org_id);


--
-- Name: dc_cases_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_cases_court_division_id ON dc_cases USING btree (court_division_id);


--
-- Name: dc_cases_dc_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_cases_dc_category_id ON dc_cases USING btree (dc_category_id);


--
-- Name: dc_cases_dc_judgment_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_cases_dc_judgment_id ON dc_cases USING btree (dc_judgment_id);


--
-- Name: dc_cases_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_cases_entity_id ON dc_cases USING btree (entity_id);


--
-- Name: dc_cases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_cases_org_id ON dc_cases USING btree (org_id);


--
-- Name: dc_receipts_dc_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_receipts_dc_case_id ON dc_receipts USING btree (dc_case_id);


--
-- Name: dc_receipts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_receipts_org_id ON dc_receipts USING btree (org_id);


--
-- Name: dc_receipts_receipt_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX dc_receipts_receipt_type_id ON dc_receipts USING btree (receipt_type_id);


--
-- Name: entity_idents_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_idents_entity_id ON entity_idents USING btree (entity_id);


--
-- Name: entity_idents_id_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_idents_id_type_id ON entity_idents USING btree (id_type_id);


--
-- Name: entity_idents_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_idents_org_id ON entity_idents USING btree (org_id);


--
-- Name: entity_subscriptions_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_id ON entity_subscriptions USING btree (entity_id);


--
-- Name: entity_subscriptions_entity_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_type_id ON entity_subscriptions USING btree (entity_type_id);


--
-- Name: entity_subscriptions_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_subscriptions_org_id ON entity_subscriptions USING btree (org_id);


--
-- Name: entity_subscriptions_subscription_level_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_subscriptions_subscription_level_id ON entity_subscriptions USING btree (subscription_level_id);


--
-- Name: entity_types_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entity_types_org_id ON entity_types USING btree (org_id);


--
-- Name: entitys_country_aquired; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_country_aquired ON entitys USING btree (country_aquired);


--
-- Name: entitys_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_court_station_id ON entitys USING btree (court_station_id);


--
-- Name: entitys_disability_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_disability_id ON entitys USING btree (disability_id);


--
-- Name: entitys_id_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_id_type_id ON entitys USING btree (id_type_id);


--
-- Name: entitys_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_org_id ON entitys USING btree (org_id);


--
-- Name: entitys_ranking_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entitys_ranking_id ON entitys USING btree (ranking_id);


--
-- Name: entry_forms_entered_by_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entry_forms_entered_by_id ON entry_forms USING btree (entered_by_id);


--
-- Name: entry_forms_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entry_forms_entity_id ON entry_forms USING btree (entity_id);


--
-- Name: entry_forms_form_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entry_forms_form_id ON entry_forms USING btree (form_id);


--
-- Name: entry_forms_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX entry_forms_org_id ON entry_forms USING btree (org_id);


--
-- Name: fields_form_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX fields_form_id ON fields USING btree (form_id);


--
-- Name: fields_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX fields_org_id ON fields USING btree (org_id);


--
-- Name: file_locations_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX file_locations_court_station_id ON file_locations USING btree (court_station_id);


--
-- Name: file_locations_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX file_locations_org_id ON file_locations USING btree (org_id);


--
-- Name: forms_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX forms_org_id ON forms USING btree (org_id);


--
-- Name: hearing_locations_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX hearing_locations_court_station_id ON hearing_locations USING btree (court_station_id);


--
-- Name: hearing_locations_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX hearing_locations_org_id ON hearing_locations USING btree (org_id);


--
-- Name: log_case_activity_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_activity_id ON log_case_activity USING btree (activity_id);


--
-- Name: log_case_activity_activity_result_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_activity_result_id ON log_case_activity USING btree (activity_result_id);


--
-- Name: log_case_activity_adjorn_reason_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_adjorn_reason_id ON log_case_activity USING btree (adjorn_reason_id);


--
-- Name: log_case_activity_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_case_activity_id ON log_case_activity USING btree (case_activity_id);


--
-- Name: log_case_activity_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_case_id ON log_case_activity USING btree (case_id);


--
-- Name: log_case_activity_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_court_station_id ON log_case_activity USING btree (court_station_id);


--
-- Name: log_case_activity_hearing_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_hearing_location_id ON log_case_activity USING btree (hearing_location_id);


--
-- Name: log_case_activity_order_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_order_type_id ON log_case_activity USING btree (order_type_id);


--
-- Name: log_case_activity_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_org_id ON log_case_activity USING btree (org_id);


--
-- Name: log_case_contacts_case_contact_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_case_contact_id ON log_case_contacts USING btree (case_contact_id);


--
-- Name: log_case_contacts_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_case_id ON log_case_contacts USING btree (case_id);


--
-- Name: log_case_contacts_contact_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_contact_type_id ON log_case_contacts USING btree (contact_type_id);


--
-- Name: log_case_contacts_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_entity_id ON log_case_contacts USING btree (entity_id);


--
-- Name: log_case_contacts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_org_id ON log_case_contacts USING btree (org_id);


--
-- Name: log_case_contacts_political_party_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_contacts_political_party_id ON case_contacts USING btree (political_party_id);


--
-- Name: log_case_counts_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_counts_case_category_id ON log_case_counts USING btree (case_category_id);


--
-- Name: log_case_counts_case_contact_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_counts_case_contact_id ON log_case_counts USING btree (case_contact_id);


--
-- Name: log_case_counts_case_count_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_counts_case_count_id ON log_case_counts USING btree (case_count_id);


--
-- Name: log_case_counts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_counts_org_id ON log_case_counts USING btree (org_id);


--
-- Name: log_case_decisions_case_activity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_case_activity_id ON log_case_decisions USING btree (case_activity_id);


--
-- Name: log_case_decisions_case_count_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_case_count_id ON log_case_decisions USING btree (case_count_id);


--
-- Name: log_case_decisions_case_decision_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_case_decision_id ON log_case_decisions USING btree (case_decision_id);


--
-- Name: log_case_decisions_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_case_id ON log_case_decisions USING btree (case_id);


--
-- Name: log_case_decisions_decision_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_decision_type_id ON log_case_decisions USING btree (decision_type_id);


--
-- Name: log_case_decisions_judgment_status_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_judgment_status_id ON log_case_decisions USING btree (judgment_status_id);


--
-- Name: log_case_decisions_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_decisions_org_id ON log_case_decisions USING btree (org_id);


--
-- Name: log_case_transfers_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_transfers_case_category_id ON log_case_transfers USING btree (case_category_id);


--
-- Name: log_case_transfers_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_transfers_case_id ON log_case_transfers USING btree (case_id);


--
-- Name: log_case_transfers_case_transfer_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_transfers_case_transfer_id ON log_case_transfers USING btree (case_transfer_id);


--
-- Name: log_case_transfers_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_transfers_court_division_id ON log_case_transfers USING btree (court_division_id);


--
-- Name: log_case_transfers_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_transfers_org_id ON log_case_transfers USING btree (org_id);


--
-- Name: log_cases_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_category_id ON log_cases USING btree (case_category_id);


--
-- Name: log_cases_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_id ON log_cases USING btree (case_id);


--
-- Name: log_cases_case_subject_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_subject_id ON log_cases USING btree (case_subject_id);


--
-- Name: log_cases_constituency_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_constituency_id ON log_cases USING btree (constituency_id);


--
-- Name: log_cases_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_court_division_id ON log_cases USING btree (court_division_id);


--
-- Name: log_cases_file_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_file_location_id ON log_cases USING btree (file_location_id);


--
-- Name: log_cases_new_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_new_case_id ON log_cases USING btree (new_case_id);


--
-- Name: log_cases_old_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_old_case_id ON log_cases USING btree (old_case_id);


--
-- Name: log_cases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_org_id ON log_cases USING btree (org_id);


--
-- Name: log_cases_police_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_police_station_id ON log_cases USING btree (police_station_id);


--
-- Name: log_cases_ward_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_ward_id ON log_cases USING btree (ward_id);


--
-- Name: log_court_bankings_bank_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_bankings_bank_account_id ON log_court_bankings USING btree (bank_account_id);


--
-- Name: log_court_bankings_court_banking_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_bankings_court_banking_id ON log_court_bankings USING btree (court_banking_id);


--
-- Name: log_court_bankings_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_bankings_org_id ON log_court_bankings USING btree (org_id);


--
-- Name: log_court_bankings_source_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_bankings_source_account_id ON log_court_bankings USING btree (source_account_id);


--
-- Name: log_court_payments_bank_account_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_payments_bank_account_id ON log_court_payments USING btree (bank_account_id);


--
-- Name: log_court_payments_court_payment_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_payments_court_payment_id ON log_court_payments USING btree (court_payment_id);


--
-- Name: log_court_payments_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_payments_org_id ON log_court_payments USING btree (org_id);


--
-- Name: log_court_payments_payment_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_payments_payment_type_id ON log_court_payments USING btree (payment_type_id);


--
-- Name: log_court_payments_receipt_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_court_payments_receipt_id ON log_court_payments USING btree (receipt_id);


--
-- Name: log_receipts_case_decision_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_case_decision_id ON log_receipts USING btree (case_decision_id);


--
-- Name: log_receipts_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_case_id ON log_receipts USING btree (case_id);


--
-- Name: log_receipts_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_court_station_id ON log_receipts USING btree (court_station_id);


--
-- Name: log_receipts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_org_id ON log_receipts USING btree (org_id);


--
-- Name: log_receipts_receipt_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_receipt_id ON log_receipts USING btree (receipt_id);


--
-- Name: log_receipts_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_receipts_type_id ON log_receipts USING btree (receipt_type_id);


--
-- Name: meetings_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX meetings_org_id ON meetings USING btree (org_id);


--
-- Name: mpesa_trxs_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX mpesa_trxs_org_id ON mpesa_trxs USING btree (org_id);


--
-- Name: mpesa_trxs_receipt_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX mpesa_trxs_receipt_id ON mpesa_trxs USING btree (receipt_id);


--
-- Name: orgs_currency_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX orgs_currency_id ON orgs USING btree (currency_id);


--
-- Name: participants_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX participants_entity_id ON participants USING btree (entity_id);


--
-- Name: participants_meeting_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX participants_meeting_id ON participants USING btree (meeting_id);


--
-- Name: participants_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX participants_org_id ON participants USING btree (org_id);


--
-- Name: police_stations_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX police_stations_court_station_id ON police_stations USING btree (court_station_id);


--
-- Name: police_stations_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX police_stations_org_id ON police_stations USING btree (org_id);


--
-- Name: receipts_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX receipts_court_station_id ON receipts USING btree (court_station_id);


--
-- Name: receipts_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX receipts_org_id ON receipts USING btree (org_id);


--
-- Name: receipts_receipt_case_decision_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX receipts_receipt_case_decision_id ON receipts USING btree (case_decision_id);


--
-- Name: receipts_receipt_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX receipts_receipt_case_id ON receipts USING btree (case_id);


--
-- Name: receipts_receipt_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX receipts_receipt_type_id ON receipts USING btree (receipt_type_id);


--
-- Name: sms_address_address_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_address_address_id ON sms_address USING btree (address_id);


--
-- Name: sms_address_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_address_org_id ON sms_address USING btree (org_id);


--
-- Name: sms_address_sms_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_address_sms_id ON sms_address USING btree (sms_id);


--
-- Name: sms_folder_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_folder_id ON sms USING btree (folder_id);


--
-- Name: sms_groups_entity_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_groups_entity_type_id ON sms_groups USING btree (entity_type_id);


--
-- Name: sms_groups_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_groups_org_id ON sms_groups USING btree (org_id);


--
-- Name: sms_groups_sms_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_groups_sms_id ON sms_groups USING btree (sms_id);


--
-- Name: sms_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sms_org_id ON sms USING btree (org_id);


--
-- Name: sub_fields_field_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sub_fields_field_id ON sub_fields USING btree (field_id);


--
-- Name: sub_fields_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sub_fields_org_id ON sub_fields USING btree (org_id);


--
-- Name: subscription_levels_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX subscription_levels_org_id ON subscription_levels USING btree (org_id);


--
-- Name: surerity_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX surerity_org_id ON surerity USING btree (org_id);


--
-- Name: surerity_receipts_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX surerity_receipts_id ON surerity USING btree (receipts_id);


--
-- Name: sys_audit_details_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_audit_details_sys_audit_trail_id ON sys_audit_details USING btree (sys_audit_trail_id);


--
-- Name: sys_countrys_sys_continent_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_countrys_sys_continent_id ON sys_countrys USING btree (sys_continent_id);


--
-- Name: sys_dashboard_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_dashboard_entity_id ON sys_dashboard USING btree (entity_id);


--
-- Name: sys_dashboard_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_dashboard_org_id ON sys_dashboard USING btree (org_id);


--
-- Name: sys_emailed_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_emailed_org_id ON sys_emailed USING btree (org_id);


--
-- Name: sys_emailed_sys_email_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_emailed_sys_email_id ON sys_emailed USING btree (sys_email_id);


--
-- Name: sys_emailed_table_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_emailed_table_id ON sys_emailed USING btree (table_id);


--
-- Name: sys_emails_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_emails_org_id ON sys_emails USING btree (org_id);


--
-- Name: sys_files_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_files_org_id ON sys_files USING btree (org_id);


--
-- Name: sys_files_table_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_files_table_id ON sys_files USING btree (table_id);


--
-- Name: sys_logins_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_logins_entity_id ON sys_logins USING btree (entity_id);


--
-- Name: sys_news_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_news_org_id ON sys_news USING btree (org_id);


--
-- Name: sys_queries_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_queries_org_id ON sys_queries USING btree (org_id);


--
-- Name: sys_reset_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX sys_reset_entity_id ON sys_reset USING btree (entity_id);


--
-- Name: wards_constituency_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX wards_constituency_id ON wards USING btree (constituency_id);


--
-- Name: workflow_phases_approval_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflow_phases_approval_entity_id ON workflow_phases USING btree (approval_entity_id);


--
-- Name: workflow_phases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflow_phases_org_id ON workflow_phases USING btree (org_id);


--
-- Name: workflow_phases_workflow_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflow_phases_workflow_id ON workflow_phases USING btree (workflow_id);


--
-- Name: workflow_sql_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflow_sql_org_id ON workflow_sql USING btree (org_id);


--
-- Name: workflows_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflows_org_id ON workflows USING btree (org_id);


--
-- Name: workflows_source_entity_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX workflows_source_entity_id ON workflows USING btree (source_entity_id);


--
-- Name: activity_action; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER activity_action BEFORE INSERT OR UPDATE ON case_activity FOR EACH ROW EXECUTE PROCEDURE activity_action();


--
-- Name: aft_case_contacts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER aft_case_contacts AFTER INSERT ON case_contacts FOR EACH ROW EXECUTE PROCEDURE aft_case_contacts();


--
-- Name: aft_case_decisions; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER aft_case_decisions AFTER INSERT ON case_decisions FOR EACH ROW EXECUTE PROCEDURE aft_case_decisions();


--
-- Name: aft_court_stations; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER aft_court_stations AFTER INSERT ON court_stations FOR EACH ROW EXECUTE PROCEDURE aft_court_stations();


--
-- Name: audit_case_activity; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_case_activity AFTER INSERT OR UPDATE ON case_activity FOR EACH ROW EXECUTE PROCEDURE audit_case_activity();


--
-- Name: audit_case_contacts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_case_contacts AFTER INSERT OR UPDATE ON case_contacts FOR EACH ROW EXECUTE PROCEDURE audit_case_contacts();


--
-- Name: audit_case_counts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_case_counts AFTER INSERT OR UPDATE ON case_counts FOR EACH ROW EXECUTE PROCEDURE audit_case_counts();


--
-- Name: audit_case_decisions; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_case_decisions AFTER INSERT OR UPDATE ON case_decisions FOR EACH ROW EXECUTE PROCEDURE audit_case_decisions();


--
-- Name: audit_case_transfers; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_case_transfers AFTER INSERT OR UPDATE ON log_case_transfers FOR EACH ROW EXECUTE PROCEDURE audit_case_transfers();


--
-- Name: audit_cases; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_cases AFTER INSERT OR UPDATE ON cases FOR EACH ROW EXECUTE PROCEDURE audit_cases();


--
-- Name: audit_court_bankings; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_court_bankings AFTER INSERT OR UPDATE ON court_bankings FOR EACH ROW EXECUTE PROCEDURE audit_court_bankings();


--
-- Name: audit_court_payments; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_court_payments AFTER INSERT OR UPDATE ON court_payments FOR EACH ROW EXECUTE PROCEDURE audit_court_payments();


--
-- Name: audit_receipts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_receipts AFTER INSERT OR UPDATE ON receipts FOR EACH ROW EXECUTE PROCEDURE audit_receipts();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_case_activity; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_case_activity BEFORE INSERT OR UPDATE ON case_activity FOR EACH ROW EXECUTE PROCEDURE ins_case_activity();


--
-- Name: ins_case_contacts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_case_contacts BEFORE INSERT ON case_contacts FOR EACH ROW EXECUTE PROCEDURE ins_case_contacts();


--
-- Name: ins_case_decisions; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_case_decisions BEFORE INSERT ON case_decisions FOR EACH ROW EXECUTE PROCEDURE ins_case_decisions();


--
-- Name: ins_case_files; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_case_files BEFORE INSERT ON case_files FOR EACH ROW EXECUTE PROCEDURE ins_case_files();


--
-- Name: ins_cases; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_cases BEFORE INSERT OR UPDATE ON cases FOR EACH ROW EXECUTE PROCEDURE ins_cases();


--
-- Name: ins_court_divisions; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_court_divisions BEFORE INSERT OR UPDATE ON court_divisions FOR EACH ROW EXECUTE PROCEDURE ins_court_divisions();


--
-- Name: ins_court_stations; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_court_stations BEFORE INSERT OR UPDATE ON court_stations FOR EACH ROW EXECUTE PROCEDURE ins_court_stations();


--
-- Name: ins_entitys; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_entitys AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_entitys();


--
-- Name: ins_entry_forms; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_entry_forms BEFORE INSERT ON entry_forms FOR EACH ROW EXECUTE PROCEDURE ins_entry_forms();


--
-- Name: ins_fields; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_fields BEFORE INSERT ON fields FOR EACH ROW EXECUTE PROCEDURE ins_fields();


--
-- Name: ins_hearing_locations; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_hearing_locations BEFORE INSERT OR UPDATE ON hearing_locations FOR EACH ROW EXECUTE PROCEDURE ins_hearing_locations();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


--
-- Name: ins_police_stations; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_police_stations BEFORE INSERT OR UPDATE ON police_stations FOR EACH ROW EXECUTE PROCEDURE ins_police_stations();


--
-- Name: ins_sms; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_sms BEFORE INSERT ON sms FOR EACH ROW EXECUTE PROCEDURE ins_sms();


--
-- Name: ins_sms_trans; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_sms_trans BEFORE INSERT ON sms_trans FOR EACH ROW EXECUTE PROCEDURE ins_sms_trans();


--
-- Name: ins_sub_fields; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_sub_fields BEFORE INSERT ON sub_fields FOR EACH ROW EXECUTE PROCEDURE ins_sub_fields();


--
-- Name: ins_sys_reset; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_sys_reset AFTER INSERT ON sys_reset FOR EACH ROW EXECUTE PROCEDURE ins_sys_reset();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: upd_court_payments; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_court_payments BEFORE INSERT OR UPDATE ON court_payments FOR EACH ROW EXECUTE PROCEDURE upd_court_payments();


--
-- Name: upd_entitys; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_entitys BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE upd_entitys();


--
-- Name: upd_receipts; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_receipts BEFORE INSERT OR UPDATE ON receipts FOR EACH ROW EXECUTE PROCEDURE upd_receipts();


--
-- Name: address_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES address_types(address_type_id);


--
-- Name: address_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: address_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: approval_checklists_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES approvals(approval_id);


--
-- Name: approval_checklists_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES checklists(checklist_id);


--
-- Name: approval_checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_app_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_app_entity_id_fkey FOREIGN KEY (app_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_entity_id_fkey FOREIGN KEY (org_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: bank_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: bench_subjects_case_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY bench_subjects
    ADD CONSTRAINT bench_subjects_case_subject_id_fkey FOREIGN KEY (case_subject_id) REFERENCES case_subjects(case_subject_id);


--
-- Name: bench_subjects_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY bench_subjects
    ADD CONSTRAINT bench_subjects_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: bench_subjects_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY bench_subjects
    ADD CONSTRAINT bench_subjects_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: cal_entity_blocks_cal_block_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cal_entity_blocks
    ADD CONSTRAINT cal_entity_blocks_cal_block_type_id_fkey FOREIGN KEY (cal_block_type_id) REFERENCES cal_block_types(cal_block_type_id);


--
-- Name: cal_entity_blocks_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cal_entity_blocks
    ADD CONSTRAINT cal_entity_blocks_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: cal_entity_blocks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cal_entity_blocks
    ADD CONSTRAINT cal_entity_blocks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_activity_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activitys(activity_id);


--
-- Name: case_activity_activity_result_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_activity_result_id_fkey FOREIGN KEY (activity_result_id) REFERENCES activity_results(activity_result_id);


--
-- Name: case_activity_adjorn_reason_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_adjorn_reason_id_fkey FOREIGN KEY (adjorn_reason_id) REFERENCES adjorn_reasons(adjorn_reason_id);


--
-- Name: case_activity_appleal_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_appleal_case_id_fkey FOREIGN KEY (appleal_case_id) REFERENCES cases(case_id);


--
-- Name: case_activity_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_activity_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: case_activity_hearing_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_hearing_location_id_fkey FOREIGN KEY (hearing_location_id) REFERENCES hearing_locations(hearing_location_id);


--
-- Name: case_activity_order_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_order_type_id_fkey FOREIGN KEY (order_type_id) REFERENCES order_types(order_type_id);


--
-- Name: case_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_bookmarks_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_bookmarks
    ADD CONSTRAINT case_bookmarks_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_bookmarks_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_bookmarks
    ADD CONSTRAINT case_bookmarks_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: case_bookmarks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_bookmarks
    ADD CONSTRAINT case_bookmarks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_category_case_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_category
    ADD CONSTRAINT case_category_case_type_id_fkey FOREIGN KEY (case_type_id) REFERENCES case_types(case_type_id);


--
-- Name: case_contacts_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_contacts_contact_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_contact_type_id_fkey FOREIGN KEY (contact_type_id) REFERENCES contact_types(contact_type_id);


--
-- Name: case_contacts_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: case_contacts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_contacts_political_party_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_political_party_id_fkey FOREIGN KEY (political_party_id) REFERENCES political_parties(political_party_id);


--
-- Name: case_counts_case_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_counts
    ADD CONSTRAINT case_counts_case_category_id_fkey FOREIGN KEY (case_category_id) REFERENCES case_category(case_category_id);


--
-- Name: case_counts_case_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_counts
    ADD CONSTRAINT case_counts_case_contact_id_fkey FOREIGN KEY (case_contact_id) REFERENCES case_contacts(case_contact_id);


--
-- Name: case_counts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_counts
    ADD CONSTRAINT case_counts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_decisions_case_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_case_activity_id_fkey FOREIGN KEY (case_activity_id) REFERENCES case_activity(case_activity_id);


--
-- Name: case_decisions_case_count_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_case_count_id_fkey FOREIGN KEY (case_count_id) REFERENCES case_counts(case_count_id);


--
-- Name: case_decisions_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_decisions_decision_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_decision_type_id_fkey FOREIGN KEY (decision_type_id) REFERENCES decision_types(decision_type_id);


--
-- Name: case_decisions_judgment_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_judgment_status_id_fkey FOREIGN KEY (judgment_status_id) REFERENCES judgment_status(judgment_status_id);


--
-- Name: case_decisions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_files_case_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_files
    ADD CONSTRAINT case_files_case_activity_id_fkey FOREIGN KEY (case_activity_id) REFERENCES case_activity(case_activity_id);


--
-- Name: case_files_case_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_files
    ADD CONSTRAINT case_files_case_decision_id_fkey FOREIGN KEY (case_decision_id) REFERENCES case_decisions(case_decision_id);


--
-- Name: case_files_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_files
    ADD CONSTRAINT case_files_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_files
    ADD CONSTRAINT case_files_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_insurance_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_insurance
    ADD CONSTRAINT case_insurance_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_insurance_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_insurance
    ADD CONSTRAINT case_insurance_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_notes_case_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_notes
    ADD CONSTRAINT case_notes_case_activity_id_fkey FOREIGN KEY (case_activity_id) REFERENCES case_activity(case_activity_id);


--
-- Name: case_notes_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_notes
    ADD CONSTRAINT case_notes_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: case_notes_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_notes
    ADD CONSTRAINT case_notes_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_quorum_case_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_quorum
    ADD CONSTRAINT case_quorum_case_activity_id_fkey FOREIGN KEY (case_activity_id) REFERENCES case_activity(case_activity_id);


--
-- Name: case_quorum_case_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_quorum
    ADD CONSTRAINT case_quorum_case_contact_id_fkey FOREIGN KEY (case_contact_id) REFERENCES case_contacts(case_contact_id);


--
-- Name: case_quorum_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_quorum
    ADD CONSTRAINT case_quorum_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_transfers_case_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_case_category_id_fkey FOREIGN KEY (case_category_id) REFERENCES case_category(case_category_id);


--
-- Name: case_transfers_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_transfers_court_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_court_division_id_fkey FOREIGN KEY (court_division_id) REFERENCES court_divisions(court_division_id);


--
-- Name: case_transfers_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: cases_case_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_case_category_id_fkey FOREIGN KEY (case_category_id) REFERENCES case_category(case_category_id);


--
-- Name: cases_case_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_case_subject_id_fkey FOREIGN KEY (case_subject_id) REFERENCES case_subjects(case_subject_id);


--
-- Name: cases_constituency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_constituency_id_fkey FOREIGN KEY (constituency_id) REFERENCES constituency(constituency_id);


--
-- Name: cases_county_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_county_id_fkey FOREIGN KEY (county_id) REFERENCES counties(county_id);


--
-- Name: cases_court_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_court_division_id_fkey FOREIGN KEY (court_division_id) REFERENCES court_divisions(court_division_id);


--
-- Name: cases_file_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_file_location_id_fkey FOREIGN KEY (file_location_id) REFERENCES file_locations(file_location_id);


--
-- Name: cases_new_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_new_case_id_fkey FOREIGN KEY (new_case_id) REFERENCES cases(case_id);


--
-- Name: cases_old_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_old_case_id_fkey FOREIGN KEY (old_case_id) REFERENCES cases(case_id);


--
-- Name: cases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: cases_police_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_police_station_id_fkey FOREIGN KEY (police_station_id) REFERENCES police_stations(police_station_id);


--
-- Name: cases_ward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_ward_id_fkey FOREIGN KEY (ward_id) REFERENCES wards(ward_id);


--
-- Name: category_activitys_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY category_activitys
    ADD CONSTRAINT category_activitys_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activitys(activity_id);


--
-- Name: category_activitys_case_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY category_activitys
    ADD CONSTRAINT category_activitys_case_category_id_fkey FOREIGN KEY (case_category_id) REFERENCES case_category(case_category_id);


--
-- Name: category_activitys_contact_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY category_activitys
    ADD CONSTRAINT category_activitys_contact_type_id_fkey FOREIGN KEY (contact_type_id) REFERENCES contact_types(contact_type_id);


--
-- Name: category_activitys_from_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY category_activitys
    ADD CONSTRAINT category_activitys_from_activity_id_fkey FOREIGN KEY (from_activity_id) REFERENCES activitys(activity_id);


--
-- Name: checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: checklists_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: constituency_county_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY constituency
    ADD CONSTRAINT constituency_county_id_fkey FOREIGN KEY (county_id) REFERENCES counties(county_id);


--
-- Name: counties_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY counties
    ADD CONSTRAINT counties_region_id_fkey FOREIGN KEY (region_id) REFERENCES regions(region_id);


--
-- Name: court_bankings_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_bankings
    ADD CONSTRAINT court_bankings_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: court_bankings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_bankings
    ADD CONSTRAINT court_bankings_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: court_bankings_source_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_bankings
    ADD CONSTRAINT court_bankings_source_account_id_fkey FOREIGN KEY (source_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: court_divisions_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_divisions
    ADD CONSTRAINT court_divisions_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: court_divisions_division_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_divisions
    ADD CONSTRAINT court_divisions_division_type_id_fkey FOREIGN KEY (division_type_id) REFERENCES division_types(division_type_id);


--
-- Name: court_divisions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_divisions
    ADD CONSTRAINT court_divisions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: court_payments_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_payments
    ADD CONSTRAINT court_payments_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: court_payments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_payments
    ADD CONSTRAINT court_payments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: court_payments_payment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_payments
    ADD CONSTRAINT court_payments_payment_type_id_fkey FOREIGN KEY (payment_type_id) REFERENCES payment_types(payment_type_id);


--
-- Name: court_payments_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_payments
    ADD CONSTRAINT court_payments_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES receipts(receipt_id);


--
-- Name: court_stations_county_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_stations
    ADD CONSTRAINT court_stations_county_id_fkey FOREIGN KEY (county_id) REFERENCES counties(county_id);


--
-- Name: court_stations_court_rank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_stations
    ADD CONSTRAINT court_stations_court_rank_id_fkey FOREIGN KEY (court_rank_id) REFERENCES court_ranks(court_rank_id);


--
-- Name: court_stations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_stations
    ADD CONSTRAINT court_stations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: currency_rates_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: currency_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: dc_cases_court_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_court_division_id_fkey FOREIGN KEY (court_division_id) REFERENCES court_divisions(court_division_id);


--
-- Name: dc_cases_dc_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_dc_category_id_fkey FOREIGN KEY (dc_category_id) REFERENCES dc_category(dc_category_id);


--
-- Name: dc_cases_dc_judgment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_dc_judgment_id_fkey FOREIGN KEY (dc_judgment_id) REFERENCES dc_judgments(dc_judgment_id);


--
-- Name: dc_cases_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: dc_cases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_cases
    ADD CONSTRAINT dc_cases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: dc_receipts_dc_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_receipts
    ADD CONSTRAINT dc_receipts_dc_case_id_fkey FOREIGN KEY (dc_case_id) REFERENCES dc_cases(dc_case_id);


--
-- Name: dc_receipts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_receipts
    ADD CONSTRAINT dc_receipts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: dc_receipts_receipt_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY dc_receipts
    ADD CONSTRAINT dc_receipts_receipt_type_id_fkey FOREIGN KEY (receipt_type_id) REFERENCES receipt_types(receipt_type_id);


--
-- Name: entity_idents_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_idents
    ADD CONSTRAINT entity_idents_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_idents_id_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_idents
    ADD CONSTRAINT entity_idents_id_type_id_fkey FOREIGN KEY (id_type_id) REFERENCES id_types(id_type_id);


--
-- Name: entity_idents_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_idents
    ADD CONSTRAINT entity_idents_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_subscriptions_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entity_subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_subscription_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_subscription_level_id_fkey FOREIGN KEY (subscription_level_id) REFERENCES subscription_levels(subscription_level_id);


--
-- Name: entity_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_country_aquired_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_country_aquired_fkey FOREIGN KEY (country_aquired) REFERENCES sys_countrys(sys_country_id);


--
-- Name: entitys_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: entitys_disability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_disability_id_fkey FOREIGN KEY (disability_id) REFERENCES disability(disability_id);


--
-- Name: entitys_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entitys_id_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_id_type_id_fkey FOREIGN KEY (id_type_id) REFERENCES id_types(id_type_id);


--
-- Name: entitys_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_ranking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_ranking_id_fkey FOREIGN KEY (ranking_id) REFERENCES rankings(ranking_id);


--
-- Name: entry_forms_entered_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entered_by_id_fkey FOREIGN KEY (entered_by_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: entry_forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fields_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: file_locations_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY file_locations
    ADD CONSTRAINT file_locations_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: file_locations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY file_locations
    ADD CONSTRAINT file_locations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: hearing_locations_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY hearing_locations
    ADD CONSTRAINT hearing_locations_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: hearing_locations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY hearing_locations
    ADD CONSTRAINT hearing_locations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: meetings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY meetings
    ADD CONSTRAINT meetings_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: mpesa_trxs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: mpesa_trxs_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES receipts(receipt_id);


--
-- Name: orgs_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: participants_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY participants
    ADD CONSTRAINT participants_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: participants_meeting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY participants
    ADD CONSTRAINT participants_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES meetings(meeting_id);


--
-- Name: participants_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY participants
    ADD CONSTRAINT participants_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: police_stations_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY police_stations
    ADD CONSTRAINT police_stations_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: police_stations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY police_stations
    ADD CONSTRAINT police_stations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: receipts_case_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_case_decision_id_fkey FOREIGN KEY (case_decision_id) REFERENCES case_decisions(case_decision_id);


--
-- Name: receipts_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: receipts_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


--
-- Name: receipts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: receipts_receipt_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_receipt_type_id_fkey FOREIGN KEY (receipt_type_id) REFERENCES receipt_types(receipt_type_id);


--
-- Name: sms_address_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_address
    ADD CONSTRAINT sms_address_address_id_fkey FOREIGN KEY (address_id) REFERENCES address(address_id);


--
-- Name: sms_address_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_address
    ADD CONSTRAINT sms_address_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sms_address_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_address
    ADD CONSTRAINT sms_address_sms_id_fkey FOREIGN KEY (sms_id) REFERENCES sms(sms_id);


--
-- Name: sms_folder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_folder_id_fkey FOREIGN KEY (folder_id) REFERENCES folders(folder_id);


--
-- Name: sms_groups_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_groups
    ADD CONSTRAINT sms_groups_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: sms_groups_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_groups
    ADD CONSTRAINT sms_groups_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sms_groups_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms_groups
    ADD CONSTRAINT sms_groups_sms_id_fkey FOREIGN KEY (sms_id) REFERENCES sms(sms_id);


--
-- Name: sms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sub_fields_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_field_id_fkey FOREIGN KEY (field_id) REFERENCES fields(field_id);


--
-- Name: sub_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscription_levels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: surerity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY surerity
    ADD CONSTRAINT surerity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: surerity_receipts_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY surerity
    ADD CONSTRAINT surerity_receipts_id_fkey FOREIGN KEY (receipts_id) REFERENCES receipts(receipt_id);


--
-- Name: sys_audit_details_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: sys_countrys_sys_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_continent_id_fkey FOREIGN KEY (sys_continent_id) REFERENCES sys_continents(sys_continent_id);


--
-- Name: sys_dashboard_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_dashboard_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_sys_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_sys_email_id_fkey FOREIGN KEY (sys_email_id) REFERENCES sys_emails(sys_email_id);


--
-- Name: sys_emails_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_logins_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_news_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_queries_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_reset_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: wards_constituency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY wards
    ADD CONSTRAINT wards_constituency_id_fkey FOREIGN KEY (constituency_id) REFERENCES constituency(constituency_id);


--
-- Name: workflow_phases_approval_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_approval_entity_id_fkey FOREIGN KEY (approval_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: workflow_phases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id);


--
-- Name: workflow_sql_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_sql_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflows_source_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
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

