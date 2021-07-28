--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

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
-- Name: approve_receipt(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION approve_receipt(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	msg varchar(120);
BEGIN
	SELECT org_id, receipt_id, amount, approved, total_paid, balance, case_number, receipt_for INTO rec
	FROM vw_receipts
	WHERE (receipt_id = CAST($1 as integer));

	IF(rec.receipt_id is null) THEN
		msg := 'No transaction of this type found';
	ELSIF(rec.approved = true) THEN
		msg := 'Transaction already approved.';
	ELSIF(rec.balance > 0) THEN
		msg := 'You need to clear the payment before approval';
	ELSE
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
-- Name: audit_cases(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION audit_cases() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log_cases (case_id, case_category_id, court_division_id, file_location_id, case_stage_id, 
		docket_type_id, police_station_id, org_id, phone_number, case_title, File_Number, date_of_arrest, 
		ob_Number, Police_station, warrant_of_arrest, alleged_crime, start_date, end_date, nature_of_claim, 
		value_of_claim, closed, final_decision, change_by, detail)
	VALUES(NEW.case_id, NEW.case_category_id, NEW.court_division_id, NEW.file_location_id, NEW.case_stage_id, 
		NEW.docket_type_id, NEW.police_station_id, NEW.org_id, NEW.phone_number, NEW.case_title, NEW.File_Number, NEW.date_of_arrest, 
		NEW.ob_Number, NEW.Police_station, NEW.warrant_of_arrest, NEW.alleged_crime, NEW.start_date, NEW.end_date, NEW.nature_of_claim, 
		NEW.value_of_claim, NEW.closed, NEW.final_decision, NEW.change_by, NEW.detail);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_cases() OWNER TO root;

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
-- Name: ins_entitys(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION ins_entitys() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN	
	IF(NEW.entity_type_id is not null) THEN
		INSERT INTO Entity_subscriptions (entity_type_id, entity_id, subscription_level_id)
		VALUES (NEW.entity_type_id, NEW.entity_id, 0);
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
-- Name: upd_receipts(); Type: FUNCTION; Schema: public; Owner: root
--

CREATE FUNCTION upd_receipts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

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
    activity_result_name character varying(320),
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

SELECT pg_catalog.setval('activity_results_activity_result_id_seq', 11, true);


--
-- Name: activitys; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE activitys (
    activity_id integer NOT NULL,
    activity_name character varying(320) NOT NULL,
    activity_order integer,
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

SELECT pg_catalog.setval('activitys_activity_id_seq', 1, false);


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
    adjorn_reason_name character varying(320),
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

SELECT pg_catalog.setval('adjorn_reasons_adjorn_reason_id_seq', 6, true);


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
    org_id integer,
    activity_date date,
    activity_time time without time zone,
    duration_minutes integer,
    duration_hours integer,
    duration_days integer,
    shared_hearing boolean DEFAULT false NOT NULL,
    created timestamp without time zone DEFAULT now(),
    created_by integer,
    modified timestamp without time zone DEFAULT now(),
    modified_by integer,
    details text
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
-- Name: case_category; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_category (
    case_category_id integer NOT NULL,
    case_type_id integer,
    case_category_name character varying(320),
    case_category_title character varying(320),
    case_category_no character varying(12),
    act_code character varying(64),
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

SELECT pg_catalog.setval('case_category_case_category_id_seq', 171, true);


--
-- Name: case_contacts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_contacts (
    case_contact_id integer NOT NULL,
    case_id integer NOT NULL,
    entity_id integer NOT NULL,
    contact_type_id integer NOT NULL,
    org_id integer,
    case_contact_no character varying(8),
    change_by integer,
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

SELECT pg_catalog.setval('case_contacts_case_contact_id_seq', 1, true);


--
-- Name: case_counts; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_counts (
    case_count_id integer NOT NULL,
    case_contact_id integer NOT NULL,
    case_category_id integer NOT NULL,
    org_id integer,
    narrative character varying(320),
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
    case_count_id integer,
    decision_type_id integer,
    org_id integer,
    decision_summary character varying(1024),
    judgement text,
    judgement_date date,
    death_sentence boolean DEFAULT false NOT NULL,
    life_sentence boolean DEFAULT false NOT NULL,
    jail_years integer,
    jail_days integer,
    fine_amount real,
    canes integer,
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
    org_id integer,
    file_name character varying(240),
    file_type character varying(50),
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
-- Name: case_orders; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_orders (
    case_order_id integer NOT NULL,
    case_id integer,
    order_type_id integer,
    org_id integer,
    activity_date date,
    activity_time time without time zone,
    created timestamp without time zone DEFAULT now(),
    created_by integer,
    modified timestamp without time zone DEFAULT now(),
    modified_by integer,
    details text
);


ALTER TABLE public.case_orders OWNER TO root;

--
-- Name: case_orders_case_order_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_orders_case_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_orders_case_order_id_seq OWNER TO root;

--
-- Name: case_orders_case_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_orders_case_order_id_seq OWNED BY case_orders.case_order_id;


--
-- Name: case_orders_case_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_orders_case_order_id_seq', 1, false);


--
-- Name: case_stages; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_stages (
    case_stage_id integer NOT NULL,
    case_stage_name character varying(320) NOT NULL,
    details text
);


ALTER TABLE public.case_stages OWNER TO root;

--
-- Name: case_stages_case_stage_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE case_stages_case_stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_stages_case_stage_id_seq OWNER TO root;

--
-- Name: case_stages_case_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE case_stages_case_stage_id_seq OWNED BY case_stages.case_stage_id;


--
-- Name: case_stages_case_stage_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('case_stages_case_stage_id_seq', 1, false);


--
-- Name: case_transfers; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE case_transfers (
    case_transfer_id integer NOT NULL,
    case_id integer,
    court_station_id integer,
    org_id integer,
    judgment_date date,
    presiding_judge character varying(50),
    previous_case_number character varying(25),
    receipt_date date,
    received_by character varying(50)
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

SELECT pg_catalog.setval('case_types_case_type_id_seq', 1, false);


--
-- Name: cases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE cases (
    case_id integer NOT NULL,
    case_category_id integer NOT NULL,
    court_division_id integer NOT NULL,
    file_location_id integer,
    case_stage_id integer,
    docket_type_id integer,
    police_station_id integer,
    org_id integer,
    phone_number character varying(50),
    case_title character varying(320),
    file_number character varying(50),
    date_of_arrest date,
    ob_number character varying(120),
    police_station character varying(120),
    warrant_of_arrest boolean DEFAULT false NOT NULL,
    alleged_crime text,
    start_date date NOT NULL,
    end_date date,
    nature_of_claim character varying(320),
    value_of_claim real,
    closed boolean DEFAULT false NOT NULL,
    final_decision character varying(1024),
    change_by integer,
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

SELECT pg_catalog.setval('cases_case_id_seq', 1, true);


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
-- Name: contact_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE contact_types (
    contact_type_id integer NOT NULL,
    contact_type_name character varying(320),
    bench boolean DEFAULT false NOT NULL,
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

SELECT pg_catalog.setval('contact_types_contact_type_id_seq', 5, true);


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

SELECT pg_catalog.setval('counties_county_id_seq', 1, true);


--
-- Name: court_bankings; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_bankings (
    court_banking_id integer NOT NULL,
    org_id integer,
    bank_ref character varying(50),
    banking_date date,
    amount real,
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
    court_division_num integer DEFAULT 0 NOT NULL,
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

SELECT pg_catalog.setval('court_divisions_court_division_id_seq', 2, true);


--
-- Name: court_payments; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_payments (
    court_payment_id integer NOT NULL,
    receipt_id integer,
    payment_type_id integer,
    org_id integer,
    bank_ref character varying(50),
    payment_date date,
    amount real,
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
-- Name: court_refunds; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE court_refunds (
    court_refund_id integer NOT NULL,
    receipt_id integer,
    org_id integer,
    bank_ref character varying(50),
    refund_date date,
    refund_amount real,
    details text
);


ALTER TABLE public.court_refunds OWNER TO root;

--
-- Name: court_refunds_court_refund_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE court_refunds_court_refund_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.court_refunds_court_refund_id_seq OWNER TO root;

--
-- Name: court_refunds_court_refund_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE court_refunds_court_refund_id_seq OWNED BY court_refunds.court_refund_id;


--
-- Name: court_refunds_court_refund_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('court_refunds_court_refund_id_seq', 1, false);


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

SELECT pg_catalog.setval('court_stations_court_station_id_seq', 1, true);


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
-- Name: decision_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE decision_types (
    decision_type_id integer NOT NULL,
    decision_type_name character varying(320),
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

SELECT pg_catalog.setval('decision_types_decision_type_id_seq', 4, true);


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

SELECT pg_catalog.setval('disability_disability_id_seq', 1, false);


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

SELECT pg_catalog.setval('division_types_division_type_id_seq', 1, false);


--
-- Name: docket_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE docket_types (
    docket_type_id integer NOT NULL,
    docket_type_name character varying(320),
    details text
);


ALTER TABLE public.docket_types OWNER TO root;

--
-- Name: docket_types_docket_type_id_seq; Type: SEQUENCE; Schema: public; Owner: root
--

CREATE SEQUENCE docket_types_docket_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.docket_types_docket_type_id_seq OWNER TO root;

--
-- Name: docket_types_docket_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: root
--

ALTER SEQUENCE docket_types_docket_type_id_seq OWNED BY docket_types.docket_type_id;


--
-- Name: docket_types_docket_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: root
--

SELECT pg_catalog.setval('docket_types_docket_type_id_seq', 1, false);


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

SELECT pg_catalog.setval('entity_subscriptions_entity_subscription_id_seq', 1, true);


--
-- Name: entity_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE entity_types (
    entity_type_id integer NOT NULL,
    org_id integer,
    entity_type_name character varying(50),
    entity_role character varying(240),
    use_key integer DEFAULT 0 NOT NULL,
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

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 5, true);


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

SELECT pg_catalog.setval('entitys_entity_id_seq', 1, true);


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
    question text,
    field_lookup text,
    field_type character varying(25) NOT NULL,
    field_class character varying(25),
    field_bold character(1) DEFAULT '0'::bpchar NOT NULL,
    field_italics character(1) DEFAULT '0'::bpchar NOT NULL,
    field_order integer NOT NULL,
    share_line integer,
    field_size integer DEFAULT 25 NOT NULL,
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar
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

SELECT pg_catalog.setval('fields_field_id_seq', 64, true);


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

SELECT pg_catalog.setval('file_locations_file_location_id_seq', 1, true);


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
    version character varying(25),
    completed character(1) DEFAULT '0'::bpchar NOT NULL,
    is_active character(1) DEFAULT '0'::bpchar NOT NULL,
    form_header text,
    form_footer text,
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

SELECT pg_catalog.setval('forms_form_id_seq', 4, true);


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

SELECT pg_catalog.setval('hearing_locations_hearing_location_id_seq', 2, true);


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

SELECT pg_catalog.setval('id_types_id_type_id_seq', 1, false);


--
-- Name: log_case_activity; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_case_activity (
    log_case_activity_id integer NOT NULL,
    case_id integer NOT NULL,
    hearing_location_id integer,
    case_activity_id integer NOT NULL,
    activity_id integer NOT NULL,
    activity_result_id integer,
    adjorn_reason_id integer,
    org_id integer,
    activity_date date,
    activity_time time without time zone,
    duration_minutes integer,
    duration_hours integer,
    duration_days integer,
    shared_hearing boolean DEFAULT false NOT NULL,
    created timestamp without time zone DEFAULT now(),
    created_by integer,
    modified timestamp without time zone DEFAULT now(),
    modified_by integer,
    details text,
    change_date timestamp without time zone DEFAULT now(),
    change_by integer
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
    case_contact_id integer NOT NULL,
    case_id integer NOT NULL,
    entity_id integer NOT NULL,
    contact_type_id integer NOT NULL,
    org_id integer,
    case_contact_no character varying(8),
    details text,
    change_date timestamp without time zone DEFAULT now(),
    change_by integer
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
-- Name: log_cases; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE log_cases (
    log_case_id integer NOT NULL,
    case_id integer,
    case_category_id integer,
    court_division_id integer,
    file_location_id integer,
    case_stage_id integer,
    docket_type_id integer,
    police_station_id integer,
    org_id integer,
    phone_number character varying(50),
    case_title character varying(320),
    file_number character varying(50),
    date_of_arrest date,
    ob_number character varying(120),
    police_station character varying(120),
    warrant_of_arrest boolean DEFAULT false NOT NULL,
    alleged_crime text,
    start_date date NOT NULL,
    end_date date,
    nature_of_claim character varying(320),
    value_of_claim real,
    closed boolean DEFAULT false NOT NULL,
    final_decision character varying(1024),
    change_by integer,
    detail text,
    change_date timestamp without time zone DEFAULT now()
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

SELECT pg_catalog.setval('log_cases_log_case_id_seq', 1, true);


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
    mpesa_pick_time timestamp without time zone DEFAULT now()
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
    order_type_name character varying(320),
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

SELECT pg_catalog.setval('order_types_order_type_id_seq', 11, true);


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
    details text
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
-- Name: payment_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE payment_types (
    payment_type_id integer NOT NULL,
    payment_type_name character varying(320) NOT NULL,
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

SELECT pg_catalog.setval('payment_types_payment_type_id_seq', 2, true);


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

SELECT pg_catalog.setval('rankings_ranking_id_seq', 9, true);


--
-- Name: receipt_types; Type: TABLE; Schema: public; Owner: root; Tablespace: 
--

CREATE TABLE receipt_types (
    receipt_type_id integer NOT NULL,
    receipt_type_name character varying(320) NOT NULL,
    receipt_type_code character varying(12) NOT NULL,
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

SELECT pg_catalog.setval('receipt_types_receipt_type_id_seq', 2, true);


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
    amount real,
    for_fine boolean DEFAULT false NOT NULL,
    approved boolean DEFAULT false NOT NULL,
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

SELECT pg_catalog.setval('regions_region_id_seq', 1, true);


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

SELECT pg_catalog.setval('sys_audit_trail_sys_audit_trail_id_seq', 15, true);


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
    file_name character varying(240),
    file_type character varying(50),
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

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 82, true);


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
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, case_stages.case_stage_id, case_stages.case_stage_name, docket_types.docket_type_id, docket_types.docket_type_name, file_locations.file_location_id, file_locations.file_location_name, police_stations.police_station_id, police_stations.police_station_name, cases.org_id, cases.case_id, cases.phone_number, cases.case_title, cases.file_number, cases.date_of_arrest, cases.ob_number, cases.police_station, cases.warrant_of_arrest, cases.alleged_crime, cases.start_date, cases.end_date, cases.nature_of_claim, cases.value_of_claim, cases.closed, cases.final_decision, cases.detail FROM ((((((cases JOIN vw_case_category ON ((cases.case_category_id = vw_case_category.case_category_id))) JOIN vw_court_divisions ON ((cases.court_division_id = vw_court_divisions.court_division_id))) JOIN case_stages ON ((cases.case_stage_id = case_stages.case_stage_id))) JOIN docket_types ON ((cases.docket_type_id = docket_types.docket_type_id))) JOIN file_locations ON ((cases.file_location_id = file_locations.file_location_id))) LEFT JOIN police_stations ON ((cases.police_station_id = police_stations.police_station_id)));


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
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location, activitys.activity_id, activitys.activity_name, activity_results.activity_result_id, activity_results.activity_result_name, adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, case_activity.org_id, case_activity.case_activity_id, case_activity.activity_date, case_activity.activity_time, case_activity.duration_minutes, case_activity.duration_hours, case_activity.duration_days, case_activity.shared_hearing, case_activity.created, case_activity.created_by, case_activity.modified, case_activity.modified_by, case_activity.details FROM (((((case_activity JOIN vw_cases ON ((case_activity.case_id = vw_cases.case_id))) JOIN vw_hearing_locations ON ((case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id))) JOIN activitys ON ((case_activity.activity_id = activitys.activity_id))) JOIN activity_results ON ((case_activity.activity_result_id = activity_results.activity_result_id))) JOIN adjorn_reasons ON ((case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id)));


ALTER TABLE public.vw_case_activity OWNER TO root;

--
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_entitys AS
    SELECT entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email, entitys.super_user, entitys.entity_leader, entitys.no_org, entitys.function_role, entitys.date_enroled, entitys.is_active, entitys.entity_password, entitys.first_password, entitys.new_password, entitys.start_url, entitys.is_picked, entitys.country_aquired, entitys.station_judge, entitys.identification, entitys.gender, entitys.org_id, entitys.date_of_birth, entitys.deceased, entitys.date_of_death, entitys.details, entity_types.entity_type_id, entity_types.entity_type_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station, rankings.ranking_id, rankings.ranking_name, sys_countrys.sys_country_id, sys_countrys.sys_country_name, id_types.id_type_id, id_types.id_type_name FROM ((((((entitys JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id))) LEFT JOIN vw_court_stations ON ((entitys.court_station_id = vw_court_stations.court_station_id))) LEFT JOIN rankings ON ((entitys.ranking_id = rankings.ranking_id))) LEFT JOIN sys_countrys ON ((entitys.country_aquired = sys_countrys.sys_country_id))) LEFT JOIN disability ON ((entitys.disability_id = disability.disability_id))) LEFT JOIN id_types ON ((entitys.id_type_id = id_types.id_type_id)));


ALTER TABLE public.vw_entitys OWNER TO root;

--
-- Name: vw_case_contacts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_contacts AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name, contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench, case_contacts.org_id, case_contacts.case_contact_id, case_contacts.case_contact_no, case_contacts.details FROM (((case_contacts JOIN vw_cases ON ((case_contacts.case_id = vw_cases.case_id))) JOIN vw_entitys ON ((case_contacts.entity_id = vw_entitys.entity_id))) JOIN contact_types ON ((case_contacts.contact_type_id = contact_types.contact_type_id)));


ALTER TABLE public.vw_case_contacts OWNER TO root;

--
-- Name: vw_case_counts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_counts AS
    SELECT vw_case_contacts.region_id, vw_case_contacts.region_name, vw_case_contacts.county_id, vw_case_contacts.county_name, vw_case_contacts.court_rank_id, vw_case_contacts.court_rank_name, vw_case_contacts.court_station_id, vw_case_contacts.court_station_name, vw_case_contacts.court_station_code, vw_case_contacts.court_station, vw_case_contacts.division_type_id, vw_case_contacts.division_type_name, vw_case_contacts.court_division_id, vw_case_contacts.court_division_code, vw_case_contacts.court_division_num, vw_case_contacts.court_division, vw_case_contacts.case_stage_id, vw_case_contacts.case_stage_name, vw_case_contacts.docket_type_id, vw_case_contacts.docket_type_name, vw_case_contacts.file_location_id, vw_case_contacts.file_location_name, vw_case_contacts.police_station_id, vw_case_contacts.police_station_name, vw_case_contacts.case_id, vw_case_contacts.phone_number, vw_case_contacts.case_title, vw_case_contacts.file_number, vw_case_contacts.date_of_arrest, vw_case_contacts.ob_number, vw_case_contacts.police_station, vw_case_contacts.warrant_of_arrest, vw_case_contacts.alleged_crime, vw_case_contacts.start_date, vw_case_contacts.end_date, vw_case_contacts.nature_of_claim, vw_case_contacts.value_of_claim, vw_case_contacts.closed, vw_case_contacts.final_decision, vw_case_contacts.entity_id, vw_case_contacts.entity_name, vw_case_contacts.user_name, vw_case_contacts.primary_email, vw_case_contacts.gender, vw_case_contacts.date_of_birth, vw_case_contacts.ranking_id, vw_case_contacts.ranking_name, vw_case_contacts.contact_type_id, vw_case_contacts.contact_type_name, vw_case_contacts.bench, vw_case_contacts.case_contact_id, vw_case_contacts.case_contact_no, vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, case_counts.org_id, case_counts.case_count_id, case_counts.narrative, case_counts.detail FROM ((case_counts JOIN vw_case_contacts ON ((case_counts.case_contact_id = vw_case_contacts.case_contact_id))) JOIN vw_case_category ON ((case_counts.case_category_id = vw_case_category.case_category_id)));


ALTER TABLE public.vw_case_counts OWNER TO root;

--
-- Name: vw_case_count_decisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_count_decisions AS
    SELECT vw_case_counts.region_id, vw_case_counts.region_name, vw_case_counts.county_id, vw_case_counts.county_name, vw_case_counts.court_rank_id, vw_case_counts.court_rank_name, vw_case_counts.court_station_id, vw_case_counts.court_station_name, vw_case_counts.court_station_code, vw_case_counts.court_station, vw_case_counts.division_type_id, vw_case_counts.division_type_name, vw_case_counts.court_division_id, vw_case_counts.court_division_code, vw_case_counts.court_division_num, vw_case_counts.court_division, vw_case_counts.case_stage_id, vw_case_counts.case_stage_name, vw_case_counts.docket_type_id, vw_case_counts.docket_type_name, vw_case_counts.file_location_id, vw_case_counts.file_location_name, vw_case_counts.police_station_id, vw_case_counts.police_station_name, vw_case_counts.case_id, vw_case_counts.phone_number, vw_case_counts.case_title, vw_case_counts.file_number, vw_case_counts.date_of_arrest, vw_case_counts.ob_number, vw_case_counts.police_station, vw_case_counts.warrant_of_arrest, vw_case_counts.alleged_crime, vw_case_counts.start_date, vw_case_counts.end_date, vw_case_counts.nature_of_claim, vw_case_counts.value_of_claim, vw_case_counts.closed, vw_case_counts.final_decision, vw_case_counts.entity_id, vw_case_counts.entity_name, vw_case_counts.user_name, vw_case_counts.primary_email, vw_case_counts.gender, vw_case_counts.date_of_birth, vw_case_counts.contact_type_id, vw_case_counts.contact_type_name, vw_case_counts.case_contact_id, vw_case_counts.case_contact_no, vw_case_counts.case_type_id, vw_case_counts.case_type_name, vw_case_counts.case_category_id, vw_case_counts.case_category_name, vw_case_counts.case_category_title, vw_case_counts.case_category_no, vw_case_counts.act_code, vw_case_counts.case_count_id, vw_case_counts.narrative, decision_types.decision_type_id, decision_types.decision_type_name, case_decisions.org_id, case_decisions.case_decision_id, case_decisions.decision_summary, case_decisions.judgement, case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.canes, case_decisions.detail FROM ((case_decisions JOIN vw_case_counts ON ((case_decisions.case_count_id = vw_case_counts.case_count_id))) JOIN decision_types ON ((case_decisions.decision_type_id = decision_types.decision_type_id)));


ALTER TABLE public.vw_case_count_decisions OWNER TO root;

--
-- Name: vw_case_decisions; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_decisions AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, decision_types.decision_type_id, decision_types.decision_type_name, case_decisions.org_id, case_decisions.case_decision_id, case_decisions.decision_summary, case_decisions.judgement, case_decisions.judgement_date, case_decisions.death_sentence, case_decisions.life_sentence, case_decisions.jail_years, case_decisions.jail_days, case_decisions.fine_amount, case_decisions.canes, case_decisions.detail FROM ((case_decisions JOIN vw_cases ON ((case_decisions.case_id = vw_cases.case_id))) JOIN decision_types ON ((case_decisions.decision_type_id = decision_types.decision_type_id)));


ALTER TABLE public.vw_case_decisions OWNER TO root;

--
-- Name: vw_case_orders; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_orders AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, order_types.order_type_id, order_types.order_type_name, case_orders.org_id, case_orders.case_order_id, case_orders.activity_date, case_orders.activity_time, case_orders.created, case_orders.created_by, case_orders.modified, case_orders.modified_by, case_orders.details FROM ((case_orders JOIN vw_cases ON ((case_orders.case_id = vw_cases.case_id))) JOIN order_types ON ((case_orders.order_type_id = order_types.order_type_id)));


ALTER TABLE public.vw_case_orders OWNER TO root;

--
-- Name: vw_case_transfers; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_case_transfers AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, case_transfers.case_id, case_transfers.org_id, case_transfers.case_transfer_id, case_transfers.judgment_date, case_transfers.presiding_judge, case_transfers.previous_case_number, case_transfers.receipt_date, case_transfers.received_by FROM (case_transfers JOIN vw_court_stations ON ((case_transfers.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_case_transfers OWNER TO root;

--
-- Name: vw_court_payments; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_court_payments AS
    SELECT payment_types.payment_type_id, payment_types.payment_type_name, court_payments.receipt_id, court_payments.org_id, court_payments.court_payment_id, court_payments.bank_ref, court_payments.payment_date, court_payments.amount, court_payments.details FROM (court_payments JOIN payment_types ON ((court_payments.payment_type_id = payment_types.payment_type_id)));


ALTER TABLE public.vw_court_payments OWNER TO root;

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
    SELECT forms.form_id, forms.form_name, fields.field_id, fields.org_id, fields.question, fields.field_lookup, fields.field_type, fields.field_order, fields.share_line, fields.field_size, fields.manditory, fields.field_bold, fields.field_italics FROM (fields JOIN forms ON ((fields.form_id = forms.form_id)));


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
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_hearing_locations.hearing_location_id, vw_hearing_locations.hearing_location_name, vw_hearing_locations.hearing_location, activitys.activity_id, activitys.activity_name, activity_results.activity_result_id, activity_results.activity_result_name, adjorn_reasons.adjorn_reason_id, adjorn_reasons.adjorn_reason_name, log_case_activity.org_id, log_case_activity.case_activity_id, log_case_activity.log_case_activity_id, log_case_activity.activity_date, log_case_activity.activity_time, log_case_activity.duration_minutes, log_case_activity.duration_hours, log_case_activity.duration_days, log_case_activity.shared_hearing, log_case_activity.details, log_case_activity.created, log_case_activity.created_by, log_case_activity.modified, log_case_activity.modified_by, log_case_activity.change_date, log_case_activity.change_by FROM (((((log_case_activity JOIN vw_cases ON ((log_case_activity.case_id = vw_cases.case_id))) JOIN vw_hearing_locations ON ((log_case_activity.hearing_location_id = vw_hearing_locations.hearing_location_id))) JOIN activitys ON ((log_case_activity.activity_id = activitys.activity_id))) JOIN activity_results ON ((log_case_activity.activity_result_id = activity_results.activity_result_id))) JOIN adjorn_reasons ON ((log_case_activity.adjorn_reason_id = adjorn_reasons.adjorn_reason_id)));


ALTER TABLE public.vw_log_case_activity OWNER TO root;

--
-- Name: vw_log_case_contacts; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_case_contacts AS
    SELECT vw_cases.case_type_id, vw_cases.case_type_name, vw_cases.case_category_id, vw_cases.case_category_name, vw_cases.case_category_title, vw_cases.case_category_no, vw_cases.act_code, vw_cases.region_id, vw_cases.region_name, vw_cases.county_id, vw_cases.county_name, vw_cases.court_rank_id, vw_cases.court_rank_name, vw_cases.court_station_id, vw_cases.court_station_name, vw_cases.court_station_code, vw_cases.court_station, vw_cases.division_type_id, vw_cases.division_type_name, vw_cases.court_division_id, vw_cases.court_division_code, vw_cases.court_division_num, vw_cases.court_division, vw_cases.case_stage_id, vw_cases.case_stage_name, vw_cases.docket_type_id, vw_cases.docket_type_name, vw_cases.file_location_id, vw_cases.file_location_name, vw_cases.police_station_id, vw_cases.police_station_name, vw_cases.case_id, vw_cases.phone_number, vw_cases.case_title, vw_cases.file_number, vw_cases.date_of_arrest, vw_cases.ob_number, vw_cases.police_station, vw_cases.warrant_of_arrest, vw_cases.alleged_crime, vw_cases.start_date, vw_cases.end_date, vw_cases.nature_of_claim, vw_cases.value_of_claim, vw_cases.closed, vw_cases.final_decision, vw_entitys.entity_id, vw_entitys.entity_name, vw_entitys.user_name, vw_entitys.primary_email, vw_entitys.gender, vw_entitys.date_of_birth, vw_entitys.ranking_id, vw_entitys.ranking_name, contact_types.contact_type_id, contact_types.contact_type_name, contact_types.bench, log_case_contacts.case_contact_id, log_case_contacts.org_id, log_case_contacts.log_case_contact_id, log_case_contacts.case_contact_no, log_case_contacts.details, log_case_contacts.change_date, log_case_contacts.change_by FROM (((log_case_contacts JOIN vw_cases ON ((log_case_contacts.case_id = vw_cases.case_id))) JOIN vw_entitys ON ((log_case_contacts.entity_id = vw_entitys.entity_id))) JOIN contact_types ON ((log_case_contacts.contact_type_id = contact_types.contact_type_id)));


ALTER TABLE public.vw_log_case_contacts OWNER TO root;

--
-- Name: vw_log_cases; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_log_cases AS
    SELECT vw_case_category.case_type_id, vw_case_category.case_type_name, vw_case_category.case_category_id, vw_case_category.case_category_name, vw_case_category.case_category_title, vw_case_category.case_category_no, vw_case_category.act_code, vw_court_divisions.region_id, vw_court_divisions.region_name, vw_court_divisions.county_id, vw_court_divisions.county_name, vw_court_divisions.court_rank_id, vw_court_divisions.court_rank_name, vw_court_divisions.court_station_id, vw_court_divisions.court_station_name, vw_court_divisions.court_station_code, vw_court_divisions.court_station, vw_court_divisions.division_type_id, vw_court_divisions.division_type_name, vw_court_divisions.court_division_id, vw_court_divisions.court_division_code, vw_court_divisions.court_division_num, vw_court_divisions.court_division, case_stages.case_stage_id, case_stages.case_stage_name, docket_types.docket_type_id, docket_types.docket_type_name, file_locations.file_location_id, file_locations.file_location_name, police_stations.police_station_id, police_stations.police_station_name, log_cases.org_id, log_cases.case_id, log_cases.log_case_id, log_cases.phone_number, log_cases.case_title, log_cases.file_number, log_cases.date_of_arrest, log_cases.ob_number, log_cases.police_station, log_cases.warrant_of_arrest, log_cases.alleged_crime, log_cases.start_date, log_cases.end_date, log_cases.nature_of_claim, log_cases.value_of_claim, log_cases.closed, log_cases.final_decision, log_cases.detail, log_cases.change_date, log_cases.change_by FROM ((((((log_cases JOIN vw_case_category ON ((log_cases.case_category_id = vw_case_category.case_category_id))) JOIN vw_court_divisions ON ((log_cases.court_division_id = vw_court_divisions.court_division_id))) JOIN case_stages ON ((log_cases.case_stage_id = case_stages.case_stage_id))) JOIN docket_types ON ((log_cases.docket_type_id = docket_types.docket_type_id))) JOIN file_locations ON ((log_cases.file_location_id = file_locations.file_location_id))) JOIN police_stations ON ((log_cases.police_station_id = police_stations.police_station_id)));


ALTER TABLE public.vw_log_cases OWNER TO root;

--
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_orgs AS
    SELECT orgs.org_id, orgs.org_name, orgs.is_default, orgs.is_active, orgs.logo, orgs.details, vw_address.sys_country_id, vw_address.sys_country_name, vw_address.address_id, vw_address.table_name, vw_address.post_office_box, vw_address.postal_code, vw_address.premises, vw_address.street, vw_address.town, vw_address.phone_number, vw_address.extension, vw_address.mobile, vw_address.fax, vw_address.email, vw_address.website FROM (orgs LEFT JOIN vw_address ON ((orgs.org_id = vw_address.table_id))) WHERE (((vw_address.table_name)::text = 'orgs'::text) OR (vw_address.table_name IS NULL));


ALTER TABLE public.vw_orgs OWNER TO root;

--
-- Name: vw_police_stations; Type: VIEW; Schema: public; Owner: root
--

CREATE VIEW vw_police_stations AS
    SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name, vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, vw_court_stations.court_station_code, vw_court_stations.court_station, police_stations.org_id, police_stations.police_station_id, police_stations.police_station_name, police_stations.police_station_phone, police_stations.details FROM (police_stations JOIN vw_court_stations ON ((police_stations.court_station_id = vw_court_stations.court_station_id)));


ALTER TABLE public.vw_police_stations OWNER TO root;

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
    SELECT vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, receipt_types.receipt_type_id, receipt_types.receipt_type_name, receipts.org_id, receipts.case_id, receipts.case_decision_id, receipts.receipt_id, receipts.receipt_for, receipts.case_number, receipts.receipt_date, receipts.amount, receipts.approved, receipts.for_fine, receipts.details, vws_court_payments.t_amount, vws_mpesa_trxs.t_mpesa_amt, (COALESCE(vws_court_payments.t_amount, (0)::real) + COALESCE(vws_mpesa_trxs.t_mpesa_amt, (0)::real)) AS total_paid, (receipts.amount - (COALESCE(vws_court_payments.t_amount, (0)::real) + COALESCE(vws_mpesa_trxs.t_mpesa_amt, (0)::real))) AS balance FROM ((((receipts JOIN vw_court_stations ON ((receipts.court_station_id = vw_court_stations.court_station_id))) JOIN receipt_types ON ((receipts.receipt_type_id = receipt_types.receipt_type_id))) LEFT JOIN vws_court_payments ON ((receipts.receipt_id = vws_court_payments.receipt_id))) LEFT JOIN vws_mpesa_trxs ON ((receipts.receipt_id = vws_mpesa_trxs.receipt_id)));


ALTER TABLE public.vw_receipts OWNER TO root;

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
-- Name: case_order_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_orders ALTER COLUMN case_order_id SET DEFAULT nextval('case_orders_case_order_id_seq'::regclass);


--
-- Name: case_stage_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE case_stages ALTER COLUMN case_stage_id SET DEFAULT nextval('case_stages_case_stage_id_seq'::regclass);


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
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


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
-- Name: court_refund_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_refunds ALTER COLUMN court_refund_id SET DEFAULT nextval('court_refunds_court_refund_id_seq'::regclass);


--
-- Name: court_station_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE court_stations ALTER COLUMN court_station_id SET DEFAULT nextval('court_stations_court_station_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


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
-- Name: docket_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE docket_types ALTER COLUMN docket_type_id SET DEFAULT nextval('docket_types_docket_type_id_seq'::regclass);


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
-- Name: log_case_activity_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_activity ALTER COLUMN log_case_activity_id SET DEFAULT nextval('log_case_activity_log_case_activity_id_seq'::regclass);


--
-- Name: log_case_contact_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_case_contacts ALTER COLUMN log_case_contact_id SET DEFAULT nextval('log_case_contacts_log_case_contact_id_seq'::regclass);


--
-- Name: log_case_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE log_cases ALTER COLUMN log_case_id SET DEFAULT nextval('log_cases_log_case_id_seq'::regclass);


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
-- Name: payment_type_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE payment_types ALTER COLUMN payment_type_id SET DEFAULT nextval('payment_types_payment_type_id_seq'::regclass);


--
-- Name: police_station_id; Type: DEFAULT; Schema: public; Owner: root
--

ALTER TABLE police_stations ALTER COLUMN police_station_id SET DEFAULT nextval('police_stations_police_station_id_seq'::regclass);


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

INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (1, 'Undetermined', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (2, 'Dismissed', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (3, 'Allowed', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (4, 'Heard', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (5, 'Adjurned', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (6, 'Judgement Entered', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (7, 'Adjorned Sine Die', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (8, 'Ruling Delivered', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (9, 'Closed Withdrawn', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (10, 'Consent Order filed', NULL);
INSERT INTO activity_results (activity_result_id, activity_result_name, details) VALUES (11, 'Ruling reserved', NULL);


--
-- Data for Name: activitys; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (1, 'Filing of Pleadings', 1, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (2, 'Issuance of Summons', 2, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (3, 'Service of Summons', 3, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (4, 'Return of Service', 4, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (5, 'Appearance of Parties', 5, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (6, 'Mention', 6, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (7, 'Hearing', 7, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (8, 'Admission', 8, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (9, 'Interlocutory Application', 9, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (10, 'Filing of Motion', 10, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (11, 'Ruling', 11, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (12, 'Judgement', 12, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (13, 'Taking of Plea', 13, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (14, 'Bail Pending Trial', 14, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (15, 'Examination-in-Chief', 15, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (16, 'Cross-Examination', 16, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (17, 'Re-Examination', 17, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (18, 'Defence Hearing', 18, 1, 0, NULL);
INSERT INTO activitys (activity_id, activity_name, activity_order, activity_days, activity_hours, details) VALUES (19, 'Sentencing', 19, 1, 0, NULL);


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: address_types; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: adjorn_reasons; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (1, 'Undetermined', NULL);
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (2, 'Party Absent', NULL);
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (3, 'Attorney Absent', NULL);
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (4, 'Witness Absent', NULL);
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (5, 'Interpretor Absent', NULL);
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name, details) VALUES (6, 'Other reasons', NULL);


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: cal_block_types; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: cal_entity_blocks; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: cal_holidays; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_activity; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_category; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (1, 1, 'Murder', 'Murder, Manslaughter and Infanticide', '1.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (2, 1, 'Manslaughter', 'Murder, Manslaughter and Infanticide', '1.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (3, 1, 'Manslaughter (Fatal Accident)', 'Murder, Manslaughter and Infanticide', '1.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (4, 1, 'Suspicious  Death', 'Murder, Manslaughter and Infanticide', '1.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (5, 1, 'Attempted Murder', 'Murder, Manslaughter and Infanticide', '1.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (6, 1, 'Infanticide', 'Murder, Manslaughter and Infanticide', '1.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (7, 1, 'Abduction', 'Other Serious Violent Offences', '2.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (8, 1, 'Act intending to cause GBH', 'Other Serious Violent Offences', '2.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (9, 1, 'Assault on a Police Officer', 'Other Serious Violent Offences', '2.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (10, 1, 'Assaulting a child', 'Other Serious Violent Offences', '2.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (11, 1, 'Grievous Harm', 'Other Serious Violent Offences', '2.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (12, 1, 'Grievous Harm (D.V)', 'Other Serious Violent Offences', '2.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (13, 1, 'Kidnapping', 'Other Serious Violent Offences', '2.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (14, 1, 'Physical abuse', 'Other Serious Violent Offences', '2.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (15, 1, 'Wounding', 'Other Serious Violent Offences', '2.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (16, 1, 'Wounding (D.V)', 'Other Serious Violent Offences', '2.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (17, 1, 'Attempted robbery', 'Robberies', '3.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (18, 1, 'Robbery with violence', 'Robberies', '3.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (19, 1, 'Robbery of mobile phone', 'Robberies', '3.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (20, 1, 'Attempted rape', 'Sexual offences', '4.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (21, 1, 'Rape', 'Sexual offences', '4.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (22, 1, 'Child abuse', 'Sexual offences', '4.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (23, 1, 'Indecent assault', 'Sexual offences', '4.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (24, 1, 'Sexual Abuse', 'Sexual offences', '4.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (25, 1, 'Sexual assault', 'Sexual offences', '4.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (26, 1, 'Sexual interference with a child', 'Sexual offences', '4.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (27, 1, 'A.O.A.B.H', 'Other Offences Against the Person', '5.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (28, 1, 'A.O.A.B.H (D.V)', 'Other Offences Against the Person', '5.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (29, 1, 'Assaulting a child', 'Other Offences Against the Person', '5.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (30, 1, 'Assaulting a child (D.V)', 'Other Offences Against the Person', '5.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (31, 1, 'Child neglect', 'Other Offences Against the Person', '5.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (32, 1, 'Common Assault', 'Other Offences Against the Person', '5.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (33, 1, 'Common Assault (D.V)', 'Other Offences Against the Person', '5.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (34, 1, 'Indecent act', 'Other Offences Against the Person', '5.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (35, 1, 'Obstruction of a Police Officer', 'Other Offences Against the Person', '5.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (36, 1, 'Procuring Abortion', 'Other Offences Against the Person', '5.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (37, 1, 'Resisting arrest', 'Other Offences Against the Person', '5.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (38, 1, 'Seditious offences', 'Other Offences Against the Person', '5.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (39, 1, 'Threatening Violence (D.V)', 'Other Offences Against the Person', '5.13', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (40, 1, 'Threatening Violence ', 'Other Offences Against the Person', '5.14', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (41, 1, 'Attempted breaking', 'Property Offences', '6.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (42, 1, 'Attempted burglary', 'Property Offences', '6.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (43, 1, 'Breaking into a building other than a dwelling', 'Property Offences', '6.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (44, 1, 'Breaking into a building other than a dwelling and stealing', 'Property Offences', '6.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (45, 1, 'Breaking into a building with intent to commit a felony', 'Property Offences', '6.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (46, 1, 'Burglary', 'Property Offences', '6.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (47, 1, 'Burglary and stealing', 'Property Offences', '6.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (48, 1, 'Entering a dwelling house ', 'Property Offences', '6.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (49, 1, 'Entering a dwelling house and stealing', 'Property Offences', '6.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (50, 1, 'Entering a dwelling house with intent to commit a felony', 'Property Offences', '6.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (51, 1, 'Entering a building with intent to commit a felony', 'Property Offences', '6.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (52, 1, 'House breaking ', 'Property Offences', '6.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (53, 1, 'House breaking and stealing', 'Property Offences', '6.13', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (54, 1, 'House breaking with intent to commit a felony', 'Property Offences', '6.14', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (55, 1, 'Stealing by servant', 'Property Offences', '6.15', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (56, 1, 'Stealing from vehicle', 'Property Offences', '6.16', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (57, 1, 'Stealing', 'Property Offences', '6.17', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (58, 1, 'Unlawful use of a vehicle', 'Property Offences', '6.18', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (59, 1, 'Unlawful possession of property', 'Property Offences', '6.19', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (60, 1, 'Unlawful use of boat or vessel', 'Property Offences', '6.20', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (61, 1, 'Attempted stealing', 'Theft', '7.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (62, 1, 'Beach theft', 'Theft', '7.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (63, 1, 'Receiving stolen property', 'Theft', '7.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (64, 1, 'Retaining Stolen Property', 'Theft', '7.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (65, 1, 'Stealing', 'Theft', '7.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (66, 1, 'Stealing by finding', 'Theft', '7.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (67, 1, 'Stealing by servant', 'Theft', '7.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (68, 1, 'Stealing from boat or vessel', 'Theft', '7.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (69, 1, 'Stealing from dwelling house', 'Theft', '7.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (70, 1, 'Stealing from hotel room', 'Theft', '7.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (71, 1, 'Stealing from person', 'Theft', '7.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (72, 1, 'Stealing from vehicle', 'Theft', '7.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (73, 1, 'Unlawful possession of property', 'Theft', '7.13', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (74, 1, 'Unlawful use of a vehicle', 'Theft', '7.14', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (75, 1, 'Unlawful use of boat or vessel', 'Theft', '7.15', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (76, 1, 'Arson', 'Arson and criminal damage', '8.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (77, 1, 'Attempted Arson', 'Arson and criminal damage', '8.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (78, 1, 'Criminal trespass', 'Arson and criminal damage', '8.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (79, 1, 'Damaging government property', 'Arson and criminal damage', '8.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (80, 1, 'Damaging property', 'Arson and criminal damage', '8.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (81, 1, 'Bribery', 'Fraud', '9.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (82, 1, 'Extortion ', 'Fraud', '9.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (83, 1, 'False accounting', 'Fraud', '9.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (84, 1, 'Forgery', 'Fraud', '9.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (85, 1, 'Fraud', 'Fraud', '9.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (86, 1, 'Giving false information to Govt employee', 'Fraud', '9.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (87, 1, 'Importing or purchasing forged notes', 'Fraud', '9.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (88, 1, 'Issuing a cheque without provision', 'Fraud', '9.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (89, 1, 'Misappropriation of money', 'Fraud', '9.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (90, 1, 'Money laundering', 'Fraud', '9.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (91, 1, 'Obtaining credit by false pretence', 'Fraud', '9.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (92, 1, 'Obtaining fares by false pretence', 'Fraud', '9.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (93, 1, 'Obtaining goods by false pretence', 'Fraud', '9.13', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (94, 1, 'Obtaining money by false pretence', 'Fraud', '9.14', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (95, 1, 'Obtaining service by false pretence', 'Fraud', '9.15', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (96, 1, 'Offering a bribe to Govt employee', 'Fraud', '9.16', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (97, 1, 'Perjury', 'Fraud', '9.17', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (98, 1, 'Possession of false/counterfeit currency', 'Fraud', '9.18', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (99, 1, 'Possession of false document', 'Fraud', '9.19', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (100, 1, 'Trading as a contractor without a licence', 'Fraud', '9.20', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (101, 1, 'Trading without a licence', 'Fraud', '9.21', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (102, 1, 'Unlawful possession of forged notes', 'Fraud', '9.22', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (103, 1, 'Uttering false notes', 'Fraud', '9.23', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (104, 1, 'Affray', 'Public Order Offences', '10.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (105, 1, 'Attempt to commit negligent act to cause harm', 'Public Order Offences', '10.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (106, 1, 'Burning rubbish without permit', 'Public Order Offences', '10.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (107, 1, 'Common Nuisance', 'Public Order Offences', '10.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (108, 1, 'Consuming alcohol in a public place', 'Public Order Offences', '10.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (109, 1, 'Cruelty to animals', 'Public Order Offences', '10.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (110, 1, 'Defamation of the President', 'Public Order Offences', '10.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (111, 1, 'Disorderly conduct in a Police building', 'Public Order Offences', '10.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (112, 1, 'Entering a restricted airport attempting to board', 'Public Order Offences', '10.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (113, 1, 'Idle and disorderly (A-i)', 'Public Order Offences', '10.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (114, 1, 'Insulting the modesty of a woman', 'Public Order Offences', '10.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (115, 1, 'Loitering', 'Public Order Offences', '10.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (116, 1, 'Negligent act', 'Public Order Offences', '10.13', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (117, 1, 'Rash and negligent act', 'Public Order Offences', '10.14', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (118, 1, 'Reckless or negligent act', 'Public Order Offences', '10.15', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (119, 1, 'Rogue and vagabond', 'Public Order Offences', '10.16', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (120, 1, 'Unlawful assembly', 'Public Order Offences', '10.17', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (121, 1, 'Throwing litter in a public place', 'Public Order Offences', '10.18', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (122, 1, 'Using obscene and indescent language in public place', 'Public Order Offences', '10.19', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (123, 1, 'Aiding and abetting escape prisoner', 'Offences relating to the administration of justice', '11.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (124, 1, 'Attempted escape', 'Offences relating to the administration of justice', '11.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (125, 1, 'Breach of court order', 'Offences relating to the administration of justice', '11.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (126, 1, 'Contempt of court', 'Offences relating to the administration of justice', '11.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (127, 1, 'Escape from lawful custody', 'Offences relating to the administration of justice', '11.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (128, 1, 'Failing to comply with bail', 'Offences relating to the administration of justice', '11.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (129, 1, 'Refuse to give name', 'Offences relating to the administration of justice', '11.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (130, 1, 'Trafficking in hard drugs', 'Offences relating to the administration of justice', '11.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (131, 1, 'Cultivation of controlled drugs', 'Drugs', '12.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (132, 1, 'Importation of controlled drugs', 'Drugs', '12.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (133, 1, 'Possession of controlled drugs', 'Drugs', '12.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (134, 1, 'Possession of hard drugs', 'Drugs', '12.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (135, 1, 'Poss of syringe for consumption or administration of controlled drugs.', 'Drugs', '12.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (136, 1, 'Presumption of Consumption Of Controlled Drugs', 'Drugs', '12.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (137, 1, 'Refuse to give control samples', 'Drugs', '12.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (138, 1, 'Trafficking controlled drugs', 'Drugs', '12.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (139, 1, 'Trafficking in hard drugs', 'Drugs', '12.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (140, 1, 'Importation of firearm and ammunition', 'Weapons and Ammunition', '13.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (141, 1, 'Possession of explosive(includes Tuna Crackers)', 'Weapons and Ammunition', '13.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (142, 1, 'Possession of offensive weapon', 'Weapons and Ammunition', '13.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (143, 1, 'Possession of spear gun', 'Weapons and Ammunition', '13.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (144, 1, 'Unlawful possession of a firearm', 'Weapons and Ammunition', '13.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (145, 1, 'Catching turtle', 'Environment and Fisheries', '14.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (146, 1, 'Cutting or selling protected trees without a permit', 'Environment and Fisheries', '14.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (147, 1, 'Cutting protected trees without a permit', 'Environment and Fisheries', '14.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (148, 1, 'Dealing in nature nuts', 'Environment and Fisheries', '14.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (149, 1, 'Illegal fishing in Seychelles territoiral waters', 'Environment and Fisheries', '14.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (150, 1, 'Possession of Coco De Mer without a permit', 'Environment and Fisheries', '14.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (151, 1, 'Removal of sand without permit', 'Environment and Fisheries', '14.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (152, 1, 'Selling Protected trees', 'Environment and Fisheries', '14.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (153, 1, 'Stealing protected animals', 'Environment and Fisheries', '14.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (154, 1, 'Taking or processing of sea cucumber without a licence', 'Environment and Fisheries', '14.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (155, 1, 'Unauthorised catching of sea cucumber in Seychelles', 'Environment and Fisheries', '14.11', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (156, 1, 'Unlawful possession of a turtle meat, turtle shell, dolphin and lobster', 'Environment and Fisheries', '14.12', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (157, 1, 'Piracy', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.01', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (158, 1, 'Allowing animals to stray', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.02', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (159, 1, 'Bigamy', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.03', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (160, 1, 'Endangering the safety of an aircraft', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.04', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (161, 1, 'Gamble', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.05', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (162, 1, 'Illegal connection of water', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.06', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (163, 1, 'Killing of an animal with intent to steal', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.07', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (164, 1, 'Possesion of more than 20 litres of baka or lapire without licence', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.08', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (165, 1, 'Possession of pornographic materials', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.09', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (166, 1, 'Prohibited goods', 'Other crimes Not Elsewhere Classified (Miscellaneous)', '15.10', NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (167, 2, 'Divorce', NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (168, 2, 'Civil Ex-Parte', NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (169, 2, 'Civil Suit', NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (170, 2, 'Petition/Application', NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_category (case_category_id, case_type_id, case_category_name, case_category_title, case_category_no, act_code, death_sentence, life_sentence, min_sentence, max_sentence, min_fine, max_fine, min_canes, max_canes, details) VALUES (171, 2, 'Miscellaneous Application', NULL, NULL, NULL, false, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: case_contacts; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO case_contacts (case_contact_id, case_id, entity_id, contact_type_id, org_id, case_contact_no, change_by, details) VALUES (1, 1, 1, 1, 0, '78789789', NULL, NULL);


--
-- Data for Name: case_counts; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_decisions; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_files; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_orders; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_stages; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO case_stages (case_stage_id, case_stage_name, details) VALUES (1, 'Pre-Trial', NULL);
INSERT INTO case_stages (case_stage_id, case_stage_name, details) VALUES (2, 'Trial', NULL);
INSERT INTO case_stages (case_stage_id, case_stage_name, details) VALUES (3, 'Appeal', NULL);
INSERT INTO case_stages (case_stage_id, case_stage_name, details) VALUES (4, 'Re-Trial', NULL);


--
-- Data for Name: case_transfers; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: case_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO case_types (case_type_id, case_type_name, duration_unacceptable, duration_serious, duration_normal, duration_low, activity_unacceptable, activity_serious, activity_normal, activity_low, details) VALUES (1, 'Crimal Cases', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO case_types (case_type_id, case_type_name, duration_unacceptable, duration_serious, duration_normal, duration_low, activity_unacceptable, activity_serious, activity_normal, activity_low, details) VALUES (2, 'Civil Cases', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: cases; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO cases (case_id, case_category_id, court_division_id, file_location_id, case_stage_id, docket_type_id, police_station_id, org_id, phone_number, case_title, file_number, date_of_arrest, ob_number, police_station, warrant_of_arrest, alleged_crime, start_date, end_date, nature_of_claim, value_of_claim, closed, final_decision, change_by, detail) VALUES (1, 167, 1, 1, 3, 0, NULL, 0, NULL, '898989', '898989', NULL, NULL, NULL, false, NULL, '2012-10-04', NULL, NULL, NULL, false, NULL, 0, NULL);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: contact_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO contact_types (contact_type_id, contact_type_name, bench, details) VALUES (1, 'Accused', false, NULL);
INSERT INTO contact_types (contact_type_id, contact_type_name, bench, details) VALUES (2, 'Preceding Judge', false, NULL);
INSERT INTO contact_types (contact_type_id, contact_type_name, bench, details) VALUES (3, 'Prosecutor', false, NULL);
INSERT INTO contact_types (contact_type_id, contact_type_name, bench, details) VALUES (4, 'Witness', false, NULL);
INSERT INTO contact_types (contact_type_id, contact_type_name, bench, details) VALUES (5, 'Plaintive', false, NULL);


--
-- Data for Name: counties; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO counties (county_id, region_id, county_name, details) VALUES (1, 1, 'Nairobi', NULL);


--
-- Data for Name: court_bankings; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: court_divisions; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO court_divisions (court_division_id, court_station_id, division_type_id, org_id, court_division_code, court_division_num, details) VALUES (1, 1, 2, 0, '1', 1, NULL);
INSERT INTO court_divisions (court_division_id, court_station_id, division_type_id, org_id, court_division_code, court_division_num, details) VALUES (2, 1, 1, 0, '1', 1, NULL);


--
-- Data for Name: court_payments; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: court_ranks; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (1, 'Supreme Court', NULL);
INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (2, 'Court of Appeal', NULL);
INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (3, 'Constitutional Court', NULL);
INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (4, 'High Court', NULL);
INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (5, 'Magistrate Court', NULL);
INSERT INTO court_ranks (court_rank_id, court_rank_name, details) VALUES (6, 'Khadhis Court', NULL);


--
-- Data for Name: court_refunds; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: court_stations; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO court_stations (court_station_id, court_rank_id, county_id, org_id, court_station_name, court_station_code, details) VALUES (1, 2, 1, 0, 'Nairobi', '1100', NULL);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (1, 'Kenya Shillings', 'KES');
INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (2, 'US Dolar', 'USD');
INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (3, 'British Pound', 'BPD');
INSERT INTO currency (currency_id, currency_name, currency_symbol) VALUES (4, 'Euro', 'ERO');


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO currency_rates (currency_rate_id, org_id, currency_id, exchange_date, exchange_rate) VALUES (0, 0, 1, '2012-09-17 10:46:55.994866', 1);


--
-- Data for Name: decision_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO decision_types (decision_type_id, decision_type_name, details) VALUES (1, 'Ruling', NULL);
INSERT INTO decision_types (decision_type_id, decision_type_name, details) VALUES (2, 'Judgment', NULL);
INSERT INTO decision_types (decision_type_id, decision_type_name, details) VALUES (3, 'Decree', NULL);
INSERT INTO decision_types (decision_type_id, decision_type_name, details) VALUES (4, 'Sentencing', NULL);


--
-- Data for Name: disability; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO disability (disability_id, disability_name) VALUES (0, 'NOT DISABLED');


--
-- Data for Name: division_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO division_types (division_type_id, division_type_name, details) VALUES (1, 'Crimal', NULL);
INSERT INTO division_types (division_type_id, division_type_name, details) VALUES (2, 'Civil', NULL);
INSERT INTO division_types (division_type_id, division_type_name, details) VALUES (3, 'Family', NULL);
INSERT INTO division_types (division_type_id, division_type_name, details) VALUES (4, 'Constitutional', NULL);
INSERT INTO division_types (division_type_id, division_type_name, details) VALUES (5, 'Land and Environment', NULL);


--
-- Data for Name: docket_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (0, 'Active', NULL);
INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (1, 'Concluded', NULL);
INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (2, 'Warrant of Arrest', NULL);
INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (3, 'Bankruptcy Stay', NULL);
INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (4, 'Interlocutory Appeal', NULL);
INSERT INTO docket_types (docket_type_id, docket_type_name, details) VALUES (5, 'Psychological Evaluation', NULL);


--
-- Data for Name: entity_idents; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: entity_subscriptions; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO entity_subscriptions (entity_subscription_id, org_id, entity_type_id, entity_id, subscription_level_id, details) VALUES (0, 0, 0, 0, 0, NULL);
INSERT INTO entity_subscriptions (entity_subscription_id, org_id, entity_type_id, entity_id, subscription_level_id, details) VALUES (1, NULL, 3, 1, 0, NULL);


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (0, 0, 'Users', 'user', 0, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (1, 0, 'Staff', 'staff', 0, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (2, 0, 'Client', 'client', 0, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (4, 0, 'Judges', 'judge', 0, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (5, 0, 'Lawyer', 'lawyer', 0, NULL, NULL, NULL);
INSERT INTO entity_types (entity_type_id, org_id, entity_type_name, entity_role, use_key, group_email, description, details) VALUES (3, 0, 'Accused', 'accused', 0, NULL, NULL, NULL);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO entitys (entity_id, org_id, entity_type_id, entity_name, user_name, primary_email, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, disability_id, court_station_id, ranking_id, id_type_id, country_aquired, station_judge, identification, gender, date_of_birth, deceased, date_of_death) VALUES (0, 0, 0, 'root', 'root', 'root@localhost', true, true, true, NULL, '2012-09-17 10:46:55.994866', true, 'e2a7106f1cc8bb1e1318df70aa0a3540', 'enter', NULL, NULL, false, NULL, NULL, NULL, NULL, NULL, NULL, false, NULL, NULL, NULL, false, NULL);
INSERT INTO entitys (entity_id, org_id, entity_type_id, entity_name, user_name, primary_email, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, disability_id, court_station_id, ranking_id, id_type_id, country_aquired, station_judge, identification, gender, date_of_birth, deceased, date_of_death) VALUES (1, 0, 3, 'Fancis Okumu', 'fokumu', NULL, false, false, false, NULL, '2012-10-04 18:21:03.75759', true, 'e2a7106f1cc8bb1e1318df70aa0a3540', 'enter', NULL, NULL, false, NULL, 0, NULL, NULL, 1, 'KE', false, '789798798', 'M', '2012-10-04', false, NULL);


--
-- Data for Name: entry_forms; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (1, NULL, 1, 'IN THE', NULL, 'TEXTFIELD', NULL, '0', '0', 10, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (2, NULL, 1, 'COURT AT', NULL, 'TEXTFIELD', NULL, '0', '0', 20, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (3, NULL, 1, 'IN THE DISTRICT OF', NULL, 'TEXTFIELD', NULL, '0', '0', 30, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (4, NULL, 1, 'Monthly return of Criminal Cases for the Month ending', NULL, 'TEXTFIELD', NULL, '0', '0', 40, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (5, NULL, 1, '20', NULL, 'TEXTFIELD', NULL, '0', '0', 50, 40, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (6, NULL, 1, 'Data', NULL, 'SUBGRID', NULL, '0', '0', 100, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (7, NULL, 2, '(S.R.M., R.M, I, II OR III Class District)', NULL, 'TEXTFIELD', NULL, '0', '0', 10, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (8, NULL, 2, 'magistrate''s court at', NULL, 'TEXTFIELD', NULL, '0', '0', 20, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (9, NULL, 2, 'in the', NULL, 'TEXTFIELD', NULL, '0', '0', 30, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (10, NULL, 2, 'District of', NULL, 'TEXTFIELD', NULL, '0', '0', 40, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (11, NULL, 2, 'Province', NULL, 'TEXTFIELD', NULL, '0', '0', 50, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (12, NULL, 2, 'Name and address of the magistrate', NULL, 'TEXTFIELD', NULL, '0', '0', 60, NULL, 50, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (64, NULL, 4, 'Summary', NULL, 'SUBGRID', NULL, '0', '0', 1, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (13, NULL, 2, 'A. Summary of cases for the month of', NULL, 'TEXTFIELD', NULL, '0', '0', 70, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (14, NULL, 2, ', 20', NULL, 'TEXTFIELD', NULL, '0', '0', 80, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (15, NULL, 2, 'case summary', NULL, 'SUBGRID', NULL, '0', '0', 90, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (16, NULL, 2, 'B. Number of persons acquited/discharges', NULL, 'TEXTFIELD', NULL, '0', '0', 100, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (17, NULL, 2, 'Number of perosns fines', NULL, 'TEXTFIELD', NULL, '0', '0', 110, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (18, NULL, 2, 'Value of unpaid files to date', NULL, 'TEXTFIELD', NULL, '0', '0', 120, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (19, NULL, 2, 'Value of fines paid', NULL, 'TEXTFIELD', NULL, '0', '0', 140, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (20, NULL, 2, 'C. Number of persons sent to prison', NULL, 'TEXTFIELD', NULL, '0', '0', 150, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (21, NULL, 2, 'Numer of perons sent to detention', NULL, 'TEXTFIELD', NULL, '0', '0', 160, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (22, NULL, 2, 'Number of persons sent to E.M.P.E', NULL, 'TEXTFIELD', NULL, '0', '0', 170, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (23, NULL, 2, 'Number of adults sentenced to corporal punishment', NULL, 'TEXTFIELD', NULL, '0', '0', 180, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (24, NULL, 2, 'D. Number of Juvenile under 18 years sentenced to corporal punishment', NULL, 'TEXTFIELD', NULL, '0', '0', 200, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (25, NULL, 2, 'E. Probation :', NULL, 'TEXTFIELD', NULL, '0', '0', 210, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (26, NULL, 2, 'Under 18 years', NULL, 'TEXTFIELD', NULL, '0', '0', 220, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (27, NULL, 2, 'F. Number of Juveniles sentenced to', NULL, 'TEXTFIELD', NULL, '0', '0', 230, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (28, NULL, 2, 'Borstal', NULL, 'TEXTFIELD', NULL, '0', '0', 240, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (29, NULL, 2, 'Approved schools', NULL, 'TEXTFIELD', NULL, '0', '0', 250, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (30, NULL, 2, 'Corrective Training Centre', NULL, 'TEXTFIELD', NULL, '0', '0', 260, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (31, NULL, 2, 'Date', NULL, 'TEXTFIELD', NULL, '0', '0', 280, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (32, NULL, 3, 'High court at', NULL, 'TEXTFIELD', NULL, '0', '0', 10, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (33, NULL, 3, 'in the', NULL, 'TEXTFIELD', NULL, '0', '0', 20, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (34, NULL, 3, 'District of', NULL, 'TEXTFIELD', NULL, '0', '0', 30, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (35, NULL, 3, 'Province', NULL, 'TEXTFIELD', NULL, '0', '0', 40, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (36, NULL, 3, 'Name(s) and address of the judges(s)', NULL, 'TEXTFIELD', NULL, '0', '0', 50, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (37, NULL, 3, 'A. Summary of case for the month of', NULL, 'TEXTFIELD', NULL, '0', '0', 60, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (38, NULL, 3, 'Year', NULL, 'TEXTFIELD', NULL, '0', '0', 70, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (39, NULL, 3, 'CRIMINAL CASES', NULL, 'SUBGRID', NULL, '0', '0', 100, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (40, NULL, 3, 'CIVIL CASES', NULL, 'TEXTFIELD', NULL, '0', '0', 200, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (41, NULL, 3, 'Extra detail on criminal cases:', NULL, 'TEXTFIELD', NULL, '1', '0', 300, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (42, NULL, 3, 'B. Number of appeals allowed and perons acquitted/discharged', NULL, 'TEXTFIELD', NULL, '0', '0', 310, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (43, NULL, 3, 'Number of Appeals allowed and sentence reduced', NULL, 'TEXTFIELD', NULL, '0', '0', 320, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (44, NULL, 3, 'Number of Appeals dismissed and sentence upheald', NULL, 'TEXTFIELD', NULL, '0', '0', 330, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (45, NULL, 3, 'Number of Appeals dismissed and sentence enhanced', NULL, 'TEXTFIELD', NULL, '0', '0', 340, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (46, NULL, 3, 'Number of persons fined', NULL, 'TEXTFIELD', NULL, '0', '0', 360, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (47, NULL, 3, 'C. Number of persons fined', NULL, 'TEXTFIELD', NULL, '0', '0', 410, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (48, NULL, 3, 'Number of persons sent to prison', NULL, 'TEXTFIELD', NULL, '0', '0', 420, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (49, NULL, 3, 'Number of persons sent to CSO', NULL, 'TEXTFIELD', NULL, '0', '0', 430, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (50, NULL, 3, 'Number of persons in remand', NULL, 'TEXTFIELD', NULL, '0', '0', 440, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (51, NULL, 3, 'D. Number of persons sentenced to probation (Adults)', NULL, 'TEXTFIELD', NULL, '0', '0', 510, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (52, NULL, 3, 'Number of persons sentenced to probation (Juveniles)', NULL, 'TEXTFIELD', NULL, '0', '0', 520, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (53, NULL, 3, 'Number of persons repatriated', NULL, 'TEXTFIELD', NULL, '0', '0', 530, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (54, NULL, 3, 'E. Number of Juveniles sentenced to Borstal', NULL, 'TEXTFIELD', NULL, '0', '0', 610, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (55, NULL, 3, 'Number of Juveniles sentenced to Approved school', NULL, 'TEXTFIELD', NULL, '0', '0', 620, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (56, NULL, 3, 'Number of Juveniles sentenced to Corrective Training centre', NULL, 'TEXTFIELD', NULL, '0', '0', 630, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (57, NULL, 3, 'F. Revenue collected in the month', NULL, 'TITLE', NULL, '0', '0', 700, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (58, NULL, 3, 'i. Fines and Forfeitures', NULL, 'TEXTFIELD', NULL, '0', '0', 710, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (59, NULL, 3, 'ii. Court fees', NULL, 'TEXTFIELD', NULL, '0', '0', 720, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (60, NULL, 3, 'iii. Legal Deposits', NULL, 'TEXTFIELD', NULL, '0', '0', 730, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (61, NULL, 3, 'iv. Others', NULL, 'TEXTFIELD', NULL, '0', '0', 740, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (62, NULL, 3, 'Date', NULL, 'TEXTFIELD', NULL, '0', '0', 810, NULL, 25, '0', '1');
INSERT INTO fields (field_id, org_id, form_id, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, manditory, show) VALUES (63, NULL, 3, 'Signature, Deputy registrar of high court', NULL, 'TEXTFIELD', NULL, '0', '0', 820, NULL, 25, '0', '1');


--
-- Data for Name: file_locations; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO file_locations (file_location_id, court_station_id, org_id, file_location_name, details) VALUES (1, 1, 0, 'Registry 1', NULL);


--
-- Data for Name: folders; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO folders (folder_id, folder_name, details) VALUES (0, 'Outbox', NULL);
INSERT INTO folders (folder_id, folder_name, details) VALUES (1, 'Draft', NULL);
INSERT INTO folders (folder_id, folder_name, details) VALUES (2, 'Sent', NULL);
INSERT INTO folders (folder_id, folder_name, details) VALUES (3, 'Inbox', NULL);
INSERT INTO folders (folder_id, folder_name, details) VALUES (4, 'Action', NULL);


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO forms (form_id, org_id, form_name, form_number, version, completed, is_active, form_header, form_footer, details) VALUES (2, NULL, 'FORM 2', 'FORM 2', '1', '0', '1', '<h2><u>REPUBLIC OF KENYA</u></h2>
<h3>JUDICUAL DEPARTMENT STATISTICS</h3>', 'NOTE</br>
1. This form, buly completed should accompany the criminal monthly reurn of Form Stat 1.</br>
2. When no ctriminal or civil cases have been decided during the month, it should be completed with the word "NIL" in the column for "Number of Cases".<br>
3. High court and muslim subordinate courts should also use this form with suitable alterations.', NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, version, completed, is_active, form_header, form_footer, details) VALUES (1, NULL, 'FORM 1', 'FORM 1', '1', '0', '1', '<u><h2>REPUBLIC OF KENYA</h2></u>
<u><h3>Please read carefully the explanatory notes before competing this form</h3></u>', NULL, NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, version, completed, is_active, form_header, form_footer, details) VALUES (3, NULL, 'FORM 3', 'FORM 3', '1', '0', '1', '<h2><u>REPUBLIC OF KENYA</u></h2>
<h3>JUDICUAL DEPARTMENT STATISTICS</h3>
<h3>SUMMARY STATISTICAL RETURN OF HIGH COURT</h3>', NULL, NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, version, completed, is_active, form_header, form_footer, details) VALUES (4, NULL, 'FORM 4', 'FORM 4', '1', '0', '1', 'Monthly case Summary', NULL, NULL);


--
-- Data for Name: hearing_locations; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO hearing_locations (hearing_location_id, court_station_id, org_id, hearing_location_name, details) VALUES (1, 1, 0, 'Room 1', NULL);
INSERT INTO hearing_locations (hearing_location_id, court_station_id, org_id, hearing_location_name, details) VALUES (2, 1, 0, 'Room 2', NULL);


--
-- Data for Name: id_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO id_types (id_type_id, id_type_name) VALUES (1, 'National ID');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (2, 'Passport');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (3, 'PIN Number');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (4, 'Company Certificate');


--
-- Data for Name: log_case_activity; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: log_case_contacts; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: log_cases; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO log_cases (log_case_id, case_id, case_category_id, court_division_id, file_location_id, case_stage_id, docket_type_id, police_station_id, org_id, phone_number, case_title, file_number, date_of_arrest, ob_number, police_station, warrant_of_arrest, alleged_crime, start_date, end_date, nature_of_claim, value_of_claim, closed, final_decision, change_by, detail, change_date) VALUES (1, 1, 167, 1, 1, 3, 0, NULL, 0, NULL, '898989', '898989', NULL, NULL, NULL, false, NULL, '2012-10-04', NULL, NULL, NULL, false, NULL, 0, NULL, '2012-10-04 18:14:14.560213');


--
-- Data for Name: mpesa_trxs; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: order_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (1, 'Witness Summons', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (2, 'Warrant of Arrest', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (3, 'Warrant of Commitment to Civil Jail', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (4, 'Language Understood by Accused', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (5, 'Release Order - where cash bail has been paid', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (6, 'Release Order - where surety has signed bond', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (7, 'Release Order', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (8, 'Committal Warrant to Medical Institution/Mathare Mental Hospital', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (9, 'Escort to Hospital for treatment, Age assessment or mental assessment', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (10, 'Judgment Extraction', NULL);
INSERT INTO order_types (order_type_id, order_type_name, details) VALUES (11, 'Particulars of Surety', NULL);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO orgs (org_id, currency_id, org_name, is_default, is_active, logo, pin, details) VALUES (0, 1, 'default', true, true, 'logo.png', NULL, NULL);


--
-- Data for Name: payment_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO payment_types (payment_type_id, payment_type_name, details) VALUES (1, 'KCB Bank Payment', NULL);
INSERT INTO payment_types (payment_type_id, payment_type_name, details) VALUES (2, 'Cash Receipt', NULL);


--
-- Data for Name: police_stations; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: rankings; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (1, 'Chief Justice', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (2, 'Supreme Court Judge', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (3, 'Court of Appeal Judge', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (4, 'High Court Judge', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (5, 'Chief Magistrate', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (6, 'Senior Principal Magistrate', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (7, 'Principal Magistrate', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (8, 'Senior Resident Magistrate', NULL, 0, NULL);
INSERT INTO rankings (ranking_id, ranking_name, rank_initials, cap_amounts, details) VALUES (9, 'Resident Magistrate', NULL, 0, NULL);


--
-- Data for Name: receipt_types; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO receipt_types (receipt_type_id, receipt_type_name, receipt_type_code, details) VALUES (1, 'Traffic Fine', 'TR', NULL);
INSERT INTO receipt_types (receipt_type_id, receipt_type_name, receipt_type_code, details) VALUES (2, 'Criminal Fine', 'CR', NULL);


--
-- Data for Name: receipts; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: regions; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO regions (region_id, region_name, details) VALUES (1, 'Nairobi', NULL);


--
-- Data for Name: sms; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sms_address; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sms_groups; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sms_trans; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (0, 0, 'Basic', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (1, 0, 'Manager', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (2, 0, 'Consumer', NULL);


--
-- Data for Name: sys_audit_details; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_audit_trail; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (1, '0', '192.168.0.254', '2012-10-04 17:58:03.258253', 'regions', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (2, '0', '192.168.0.254', '2012-10-04 17:58:16.186591', 'counties', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (3, '0', '192.168.0.254', '2012-10-04 17:58:36.10122', 'court_stations', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (4, '0', '192.168.0.254', '2012-10-04 17:58:48.579247', 'court_divisions', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (5, '0', '192.168.0.254', '2012-10-04 17:58:59.39341', 'court_divisions', '2', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (6, '0', '192.168.0.254', '2012-10-04 17:59:13.235694', 'hearing_locations', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (7, '0', '192.168.0.254', '2012-10-04 17:59:22.567672', 'hearing_locations', '2', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (8, '0', '192.168.0.254', '2012-10-04 17:59:35.644922', 'file_locations', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (9, '0', '192.168.0.254', '2012-10-04 18:00:26.634468', 'entity_types', '4', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (10, '0', '192.168.0.254', '2012-10-04 18:00:43.429579', 'entity_types', '4', 'EDIT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (11, '0', '192.168.0.254', '2012-10-04 18:01:16.198602', 'entity_types', '5', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (12, '0', '192.168.0.254', '2012-10-04 18:02:41.504134', 'entity_types', '3', 'EDIT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (13, '0', '192.168.0.254', '2012-10-04 18:14:14.580014', 'cases', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (14, '0', '192.168.0.254', '2012-10-04 18:21:03.77331', 'entitys', '1', 'INSERT', NULL);
INSERT INTO sys_audit_trail (sys_audit_trail_id, user_id, user_ip, change_date, table_name, record_id, change_type, narrative) VALUES (15, '0', '192.168.0.254', '2012-10-04 18:21:20.078185', 'case_contacts', '1', 'INSERT', NULL);


--
-- Data for Name: sys_continents; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AF', 'Africa');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AS', 'Asia');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('EU', 'Europe');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('NA', 'North America');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('SA', 'South America');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('OC', 'Oceania');
INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES ('AN', 'Antarctica');


--
-- Data for Name: sys_countrys; Type: TABLE DATA; Schema: public; Owner: root
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
-- Data for Name: sys_dashboard; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_emailed; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_emails; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_errors; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_files; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_logins; Type: TABLE DATA; Schema: public; Owner: root
--

INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (1, 0, '2012-09-24 22:11:17.939785', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (2, 0, '2012-10-02 10:20:02.05209', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (3, 0, '2012-10-04 16:32:29.688974', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (4, 0, '2012-10-04 17:39:48.737428', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (5, 0, '2012-10-04 17:57:37.882631', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (6, 0, '2012-10-04 17:57:45.390197', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (7, 0, '2012-10-04 17:57:47.826133', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (8, 0, '2012-10-04 17:57:49.540011', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (9, 0, '2012-10-04 17:58:03.109391', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (10, 0, '2012-10-04 17:58:05.838618', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (11, 0, '2012-10-04 17:58:09.7157', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (12, 0, '2012-10-04 17:58:16.157003', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (13, 0, '2012-10-04 17:58:19.580743', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (14, 0, '2012-10-04 17:58:21.827172', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (15, 0, '2012-10-04 17:58:23.767059', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (16, 0, '2012-10-04 17:58:36.071692', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (17, 0, '2012-10-04 17:58:39.097724', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (18, 0, '2012-10-04 17:58:41.086042', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (19, 0, '2012-10-04 17:58:48.539014', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (20, 0, '2012-10-04 17:58:51.067519', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (21, 0, '2012-10-04 17:58:59.349487', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (22, 0, '2012-10-04 17:59:04.780634', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (23, 0, '2012-10-04 17:59:06.725582', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (24, 0, '2012-10-04 17:59:13.19037', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (25, 0, '2012-10-04 17:59:15.84935', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (26, 0, '2012-10-04 17:59:22.537383', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (27, 0, '2012-10-04 17:59:24.705295', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (28, 0, '2012-10-04 17:59:26.593591', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (29, 0, '2012-10-04 17:59:35.615202', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (30, 0, '2012-10-04 17:59:40.119338', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (31, 0, '2012-10-04 17:59:43.03115', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (32, 0, '2012-10-04 17:59:47.389168', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (33, 0, '2012-10-04 18:00:05.173239', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (34, 0, '2012-10-04 18:00:08.11697', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (35, 0, '2012-10-04 18:00:10.548066', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (36, 0, '2012-10-04 18:00:14.920265', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (37, 0, '2012-10-04 18:00:18.497745', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (38, 0, '2012-10-04 18:00:23.558744', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (39, 0, '2012-10-04 18:00:26.610028', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (40, 0, '2012-10-04 18:00:29.826975', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (41, 0, '2012-10-04 18:00:32.695741', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (42, 0, '2012-10-04 18:00:43.397534', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (43, 0, '2012-10-04 18:00:55.282163', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (44, 0, '2012-10-04 18:01:16.156592', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (45, 0, '2012-10-04 18:01:44.467371', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (46, 0, '2012-10-04 18:01:46.785398', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (47, 0, '2012-10-04 18:02:41.462983', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (48, 0, '2012-10-04 18:13:38.401522', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (49, 0, '2012-10-04 18:13:41.843962', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (50, 0, '2012-10-04 18:14:14.514977', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (51, 0, '2012-10-04 18:14:18.437575', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (52, 0, '2012-10-04 18:14:21.3459', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (53, 0, '2012-10-04 18:14:23.494393', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (54, 0, '2012-10-04 18:14:26.228702', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (55, 0, '2012-10-04 18:14:29.868739', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (56, 0, '2012-10-04 18:20:32.593962', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (57, 0, '2012-10-04 18:20:35.637727', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (58, 0, '2012-10-04 18:21:03.721287', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (59, 0, '2012-10-04 18:21:20.040868', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (60, 0, '2012-10-04 18:21:25.515892', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (61, 0, '2012-10-04 18:21:28.283254', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (62, 0, '2012-10-04 18:21:31.582428', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (63, 0, '2012-10-04 18:22:10.139492', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (64, 0, '2012-10-04 18:22:14.13774', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (65, 0, '2012-10-04 18:56:34.20868', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (66, 0, '2012-10-04 18:56:46.688493', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (67, 0, '2012-10-04 19:39:23.376779', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (68, 0, '2012-10-04 19:41:27.277393', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (69, 0, '2012-10-04 19:46:01.097554', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (70, 0, '2012-10-04 19:46:07.388692', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (71, 0, '2012-10-04 19:46:10.26813', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (72, 0, '2012-10-04 19:53:05.788717', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (73, 0, '2012-10-04 19:53:10.705093', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (74, 0, '2012-10-04 19:53:18.904491', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (75, 0, '2012-10-04 19:53:34.369051', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (76, 0, '2012-10-04 19:54:35.90045', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (77, 0, '2012-10-04 19:54:37.019543', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (78, 0, '2012-10-04 19:55:26.318888', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (79, 0, '2012-10-04 20:04:06.731776', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (80, 0, '2012-10-04 20:06:14.948515', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (81, 0, '2012-10-04 20:06:17.870521', '192.168.0.254', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (82, 0, '2012-10-04 20:06:20.958677', '192.168.0.254', NULL);


--
-- Data for Name: sys_news; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: sys_queries; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: workflow_phases; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: workflow_sql; Type: TABLE DATA; Schema: public; Owner: root
--



--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: root
--



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
-- Name: case_category_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_category
    ADD CONSTRAINT case_category_pkey PRIMARY KEY (case_category_id);


--
-- Name: case_contacts_case_id_contact_type_id_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_case_id_contact_type_id_key UNIQUE (case_id, contact_type_id);


--
-- Name: case_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_contacts
    ADD CONSTRAINT case_contacts_pkey PRIMARY KEY (case_contact_id);


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
-- Name: case_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_orders
    ADD CONSTRAINT case_orders_pkey PRIMARY KEY (case_order_id);


--
-- Name: case_stages_case_stage_name_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_stages
    ADD CONSTRAINT case_stages_case_stage_name_key UNIQUE (case_stage_name);


--
-- Name: case_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY case_stages
    ADD CONSTRAINT case_stages_pkey PRIMARY KEY (case_stage_id);


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
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: contact_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY contact_types
    ADD CONSTRAINT contact_types_pkey PRIMARY KEY (contact_type_id);


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
-- Name: court_ranks_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_ranks
    ADD CONSTRAINT court_ranks_pkey PRIMARY KEY (court_rank_id);


--
-- Name: court_refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY court_refunds
    ADD CONSTRAINT court_refunds_pkey PRIMARY KEY (court_refund_id);


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
-- Name: division_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY division_types
    ADD CONSTRAINT division_types_pkey PRIMARY KEY (division_type_id);


--
-- Name: docket_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY docket_types
    ADD CONSTRAINT docket_types_pkey PRIMARY KEY (docket_type_id);


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
-- Name: log_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_pkey PRIMARY KEY (log_case_id);


--
-- Name: mpesa_trxs_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_pkey PRIMARY KEY (mpesa_trx_id);


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
-- Name: rankings_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY rankings
    ADD CONSTRAINT rankings_pkey PRIMARY KEY (ranking_id);


--
-- Name: receipt_types_pkey; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY receipt_types
    ADD CONSTRAINT receipt_types_pkey PRIMARY KEY (receipt_type_id);


--
-- Name: receipts_org_id_receipt_type_id_case_number_key; Type: CONSTRAINT; Schema: public; Owner: root; Tablespace: 
--

ALTER TABLE ONLY receipts
    ADD CONSTRAINT receipts_org_id_receipt_type_id_case_number_key UNIQUE (org_id, receipt_type_id, case_number);


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
-- Name: case_activity_hearing_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_hearing_location_id ON case_activity USING btree (hearing_location_id);


--
-- Name: case_activity_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_activity_org_id ON case_activity USING btree (org_id);


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
-- Name: case_decisions_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_decisions_org_id ON case_decisions USING btree (org_id);


--
-- Name: case_files_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_case_id ON case_files USING btree (case_id);


--
-- Name: case_files_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_files_org_id ON case_files USING btree (org_id);


--
-- Name: case_orders_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_orders_case_id ON case_orders USING btree (case_id);


--
-- Name: case_orders_order_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_orders_order_type_id ON case_orders USING btree (order_type_id);


--
-- Name: case_orders_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_orders_org_id ON case_orders USING btree (org_id);


--
-- Name: case_transfers_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_case_id ON case_transfers USING btree (case_id);


--
-- Name: case_transfers_court_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_court_station_id ON case_transfers USING btree (court_station_id);


--
-- Name: case_transfers_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX case_transfers_org_id ON case_transfers USING btree (org_id);


--
-- Name: cases_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_case_category_id ON cases USING btree (case_category_id);


--
-- Name: cases_case_stage_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_case_stage_id ON cases USING btree (case_stage_id);


--
-- Name: cases_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_court_division_id ON cases USING btree (court_division_id);


--
-- Name: cases_docket_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_docket_type_id ON cases USING btree (docket_type_id);


--
-- Name: cases_file_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_file_location_id ON cases USING btree (file_location_id);


--
-- Name: cases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_org_id ON cases USING btree (org_id);


--
-- Name: cases_police_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX cases_police_station_id ON cases USING btree (police_station_id);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: counties_region_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX counties_region_id ON counties USING btree (region_id);


--
-- Name: court_bankings_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_bankings_org_id ON court_bankings USING btree (org_id);


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
-- Name: court_refunds_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_refunds_org_id ON court_refunds USING btree (org_id);


--
-- Name: court_refunds_receipt_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX court_refunds_receipt_id ON court_refunds USING btree (receipt_id);


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
-- Name: log_case_activity_hearing_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_case_activity_hearing_location_id ON log_case_activity USING btree (hearing_location_id);


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
-- Name: log_cases_case_category_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_category_id ON log_cases USING btree (case_category_id);


--
-- Name: log_cases_case_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_id ON log_cases USING btree (case_id);


--
-- Name: log_cases_case_stage_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_case_stage_id ON log_cases USING btree (case_stage_id);


--
-- Name: log_cases_court_division_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_court_division_id ON log_cases USING btree (court_division_id);


--
-- Name: log_cases_docket_type_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_docket_type_id ON log_cases USING btree (docket_type_id);


--
-- Name: log_cases_file_location_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_file_location_id ON log_cases USING btree (file_location_id);


--
-- Name: log_cases_org_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_org_id ON log_cases USING btree (org_id);


--
-- Name: log_cases_police_station_id; Type: INDEX; Schema: public; Owner: root; Tablespace: 
--

CREATE INDEX log_cases_police_station_id ON log_cases USING btree (police_station_id);


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
-- Name: audit_cases; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER audit_cases AFTER INSERT OR UPDATE ON cases FOR EACH ROW EXECUTE PROCEDURE audit_cases();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_entitys; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_entitys AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_entitys();


--
-- Name: ins_fields; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_fields BEFORE INSERT ON fields FOR EACH ROW EXECUTE PROCEDURE ins_fields();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


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
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: root
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


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
-- Name: case_activity_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_activity_hearing_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_hearing_location_id_fkey FOREIGN KEY (hearing_location_id) REFERENCES hearing_locations(hearing_location_id);


--
-- Name: case_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_activity
    ADD CONSTRAINT case_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: case_decisions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_decisions
    ADD CONSTRAINT case_decisions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: case_orders_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_orders
    ADD CONSTRAINT case_orders_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_orders_order_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_orders
    ADD CONSTRAINT case_orders_order_type_id_fkey FOREIGN KEY (order_type_id) REFERENCES order_types(order_type_id);


--
-- Name: case_orders_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_orders
    ADD CONSTRAINT case_orders_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: case_transfers_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: case_transfers_court_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY case_transfers
    ADD CONSTRAINT case_transfers_court_station_id_fkey FOREIGN KEY (court_station_id) REFERENCES court_stations(court_station_id);


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
-- Name: cases_case_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_case_stage_id_fkey FOREIGN KEY (case_stage_id) REFERENCES case_stages(case_stage_id);


--
-- Name: cases_court_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_court_division_id_fkey FOREIGN KEY (court_division_id) REFERENCES court_divisions(court_division_id);


--
-- Name: cases_docket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_docket_type_id_fkey FOREIGN KEY (docket_type_id) REFERENCES docket_types(docket_type_id);


--
-- Name: cases_file_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY cases
    ADD CONSTRAINT cases_file_location_id_fkey FOREIGN KEY (file_location_id) REFERENCES file_locations(file_location_id);


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
-- Name: counties_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY counties
    ADD CONSTRAINT counties_region_id_fkey FOREIGN KEY (region_id) REFERENCES regions(region_id);


--
-- Name: court_bankings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_bankings
    ADD CONSTRAINT court_bankings_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


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
-- Name: court_refunds_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_refunds
    ADD CONSTRAINT court_refunds_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: court_refunds_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY court_refunds
    ADD CONSTRAINT court_refunds_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES receipts(receipt_id);


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
-- Name: log_case_activity_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES activitys(activity_id);


--
-- Name: log_case_activity_activity_result_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_activity_result_id_fkey FOREIGN KEY (activity_result_id) REFERENCES activity_results(activity_result_id);


--
-- Name: log_case_activity_adjorn_reason_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_adjorn_reason_id_fkey FOREIGN KEY (adjorn_reason_id) REFERENCES adjorn_reasons(adjorn_reason_id);


--
-- Name: log_case_activity_case_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_case_activity_id_fkey FOREIGN KEY (case_activity_id) REFERENCES case_activity(case_activity_id);


--
-- Name: log_case_activity_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: log_case_activity_hearing_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_hearing_location_id_fkey FOREIGN KEY (hearing_location_id) REFERENCES hearing_locations(hearing_location_id);


--
-- Name: log_case_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_activity
    ADD CONSTRAINT log_case_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: log_case_contacts_case_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_case_contact_id_fkey FOREIGN KEY (case_contact_id) REFERENCES case_contacts(case_contact_id);


--
-- Name: log_case_contacts_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: log_case_contacts_contact_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_contact_type_id_fkey FOREIGN KEY (contact_type_id) REFERENCES contact_types(contact_type_id);


--
-- Name: log_case_contacts_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: log_case_contacts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_case_contacts
    ADD CONSTRAINT log_case_contacts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: log_cases_case_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_case_category_id_fkey FOREIGN KEY (case_category_id) REFERENCES case_category(case_category_id);


--
-- Name: log_cases_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_case_id_fkey FOREIGN KEY (case_id) REFERENCES cases(case_id);


--
-- Name: log_cases_case_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_case_stage_id_fkey FOREIGN KEY (case_stage_id) REFERENCES case_stages(case_stage_id);


--
-- Name: log_cases_court_division_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_court_division_id_fkey FOREIGN KEY (court_division_id) REFERENCES court_divisions(court_division_id);


--
-- Name: log_cases_docket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_docket_type_id_fkey FOREIGN KEY (docket_type_id) REFERENCES docket_types(docket_type_id);


--
-- Name: log_cases_file_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_file_location_id_fkey FOREIGN KEY (file_location_id) REFERENCES file_locations(file_location_id);


--
-- Name: log_cases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: log_cases_police_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: root
--

ALTER TABLE ONLY log_cases
    ADD CONSTRAINT log_cases_police_station_id_fkey FOREIGN KEY (police_station_id) REFERENCES police_stations(police_station_id);


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

