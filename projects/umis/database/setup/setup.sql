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
-- Name: addacademicyear(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION addacademicyear(character varying, integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT cast(substring($1 from 1 for 4) as int) + $2 || '/' || cast(substring($1 from 1 for 4) as int) + $2 + 1 || '.3';
$_$;


ALTER FUNCTION public.addacademicyear(character varying, integer) OWNER TO postgres;

--
-- Name: aft_instructors(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION aft_instructors() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_role		varchar(240);
	v_no_org	boolean;
BEGIN

	v_role := 'lecturer';
	v_no_org := false;
	IF(NEW.majoradvisor = true)THEN
		v_role := 'lecturer,major_advisor';
	END IF;
	IF(NEW.department_head = true)THEN
		v_role := 'lecturer,major_advisor,department_head';
		v_no_org := true;
	END IF;
	IF(NEW.school_dean = true)THEN
		v_role := 'lecturer,major_advisor,school_dean';
		v_no_org := true;
	END IF;
	IF(NEW.pgs_dean = true)THEN
		v_role := v_role || ',pgs_dean';
		v_no_org := true;
	END IF;

	IF(TG_OP = 'INSERT')THEN
		INSERT INTO entitys (org_id, entity_type_id, user_name, entity_name, Entity_Leader, Super_User, no_org, primary_email, function_role)
		VALUES (NEW.org_id, 11, NEW.instructorid, NEW.instructorname, false, false, false, NEW.email, v_role);
	ELSE
		UPDATE entitys SET function_role = v_role, no_org = v_no_org WHERE user_name = NEW.instructorid;
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_instructors() OWNER TO postgres;

--
-- Name: aft_student_payments(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION aft_student_payments() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_curr_bal			real;
BEGIN

	SELECT sum(TransactionAmount) INTO v_curr_bal
	FROM student_payments
	WHERE qstudentid = NEW.qstudentid;
	v_curr_bal := v_curr_bal * -1;

	UPDATE qstudents SET balance_time = now(), currbalance = v_curr_bal WHERE qstudentid = NEW.qstudentid;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_student_payments() OWNER TO postgres;

--
-- Name: approve_finance(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION approve_finance(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_user_name			varchar(50);
	reca				RECORD;
BEGIN
	
	SELECT qstudentid, finaceapproval, exam_clear INTO reca
	FROM qstudents WHERE (qstudentid = CAST($1 as int));

	SELECT user_name INTO v_user_name
	FROM entitys WHERE (entity_id = CAST($2 as int));

	IF($3 = '1') AND (reca.finaceapproval = false) THEN
		UPDATE qstudents SET finaceapproval = true
		WHERE (qstudentid = CAST($1 as int));

		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (CAST($1 as int), v_user_name, 'Finance Approval', now(), cast(inet_client_addr() as varchar));
	END IF;

	IF($3 = '2') AND (reca.finaceapproval = true) THEN
		UPDATE qstudents SET finaceapproval = false
		WHERE (qstudentid = CAST($1 as int));

		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (CAST($1 as int), v_user_name, 'Finance Opening', now(), cast(inet_client_addr() as varchar));
	END IF;

	IF($3 = '3') AND (reca.exam_clear = false) THEN
		UPDATE qstudents SET exam_clear = true, exam_clear_date = now()
		WHERE (qstudentid = CAST($1 as int));

		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (CAST($1 as int), v_user_name, 'Exam Clearance', now(), cast(inet_client_addr() as varchar));
	END IF;

	RETURN 'Approved';
END;
$_$;


ALTER FUNCTION public.approve_finance(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: calcwithdrawrate(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION calcwithdrawrate() RETURNS real
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec RECORD;
	wRate real;
BEGIN
	SELECT (current_date - max(qstart)) / 7 as sem_weeks INTO myrec
	FROM quarters
	WHERE (closed = false);

	wRate := 1.0;

	IF(myrec.sem_weeks is null) THEN
		wRate := 1.0;
	ELSIF(myrec.sem_weeks <= 2) THEN
		wRate := 0.15;
	ELSIF(myrec.sem_weeks <= 3) THEN
		wRate := 0.25;
	ELSIF(myrec.sem_weeks <= 4) THEN
		wRate := 0.35;
	ELSIF(myrec.sem_weeks <= 5) THEN
		wRate := 0.45;
	ELSIF(myrec.sem_weeks <= 6) THEN
		wRate := 0.55;
	ELSIF(myrec.sem_weeks <= 7) THEN
		wRate := 0.65;
	ELSIF(myrec.sem_weeks <= 8) THEN
		wRate := 0.75;
	END IF;

	RETURN wRate;
END;
$$;


ALTER FUNCTION public.calcwithdrawrate() OWNER TO postgres;

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
-- Name: checkgrade(integer, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION checkgrade(integer, double precision) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qgrades.qgradeid)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true) AND (qgrades.dropped = false)
		AND (grades.gradeweight < $2) AND (grades.gpacount = true);
$_$;


ALTER FUNCTION public.checkgrade(integer, double precision) OWNER TO postgres;

--
-- Name: checkgrade(integer, character varying, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION checkgrade(integer, character varying, double precision) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qgrades.qgradeid)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (substring(qstudents.quarterid from 1 for 9) = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gradeweight < $3) AND (grades.gpacount = true);
$_$;


ALTER FUNCTION public.checkgrade(integer, character varying, double precision) OWNER TO postgres;

--
-- Name: checkhonors(double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION checkhonors(double precision, double precision, double precision, double precision) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myhonors int;
	gpa float;
	pgpa float;
	i int;
BEGIN
	myhonors := 0;

	pgpa := 0;
	FOR i IN 1..4 LOOP
		if(i = 1) then gpa := $1; end if;
		if(i = 2) then gpa := $2; end if;
		if(i = 3) then gpa := $3; end if;
		if(i = 4) then gpa := $4; end if;

		IF (gpa IS NOT NULL) THEN
    		IF ((gpa >= 3.5) AND (pgpa >= 3.5)) THEN
				myhonors := myhonors + 1;
			END IF;
			pgpa := gpa; 
		END IF;
	END LOOP;

    RETURN myhonors;
END;
$_$;


ALTER FUNCTION public.checkhonors(double precision, double precision, double precision, double precision) OWNER TO postgres;

--
-- Name: checkincomplete(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION checkincomplete(integer) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qgrades.qgradeid)
	FROM qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (qgrades.gradeid = 'IW') AND (qgrades.dropped = false);
$_$;


ALTER FUNCTION public.checkincomplete(integer) OWNER TO postgres;

--
-- Name: closequarter(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION closequarter(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE charges SET session_active = false, session_closed = true
	WHERE (charges.quarterid = $1);

	UPDATE qcourses SET approved = true WHERE (quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$_$;


ALTER FUNCTION public.closequarter(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: del_qgrades(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION del_qgrades() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	RAISE EXCEPTION 'Cannot delete a grade.';
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.del_qgrades() OWNER TO postgres;

--
-- Name: dropqcourse(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION dropqcourse(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myrec 		RECORD;
	mysrec 		RECORD;
	mystr 		VARCHAR(50);
	mycurrqs 	int;
BEGIN
	mycurrqs := getcurrqstudentid($2);

	SELECT qstudentid, finalised INTO mysrec
	FROM qstudents
	WHERE (qstudentid = mycurrqs);

	SELECT qgrades.qgradeid, qgrades.dropped, qgrades.approved, qcourses.courseid INTO myrec
	FROM qgrades INNER JOIN qcourses ON qgrades.qcourseid = qcourses.qcourseid
	WHERE (qgrades.qgradeid = CAST($1 as int));

	IF (mysrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for quarter and select residence first.';
	ELSIF (mysrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSIF (myrec.qgradeid IS NULL) THEN
		RAISE EXCEPTION 'You have not selected the course.';
	ELSE
		UPDATE qgrades SET askdrop = true, askdropdate = current_timestamp WHERE qgradeid = CAST($1 as int);
		UPDATE qgrades SET dropped = true, dropdate = current_date WHERE qgradeid = CAST($1 as int);
		mystr := myrec.courseid || ' Dropped';
	END IF;
	
    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.dropqcourse(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: exambalances(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION exambalances(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE charges SET exam_balances = true, session_active = true, session_closed = false
	WHERE (charges.quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$_$;


ALTER FUNCTION public.exambalances(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: get_instructor_department(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_instructor_department(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT departmentid
	FROM instructors
	WHERE (instructorid = $1);
$_$;


ALTER FUNCTION public.get_instructor_department(character varying) OWNER TO postgres;

--
-- Name: get_instructor_school(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_instructor_school(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT departments.schoolid
	FROM instructors INNER JOIN departments ON instructors.departmentid = departments.departmentid
	WHERE (instructorid = $1);
$_$;


ALTER FUNCTION public.get_instructor_school(character varying) OWNER TO postgres;

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
-- Name: get_qstudent_location_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_qstudent_location_id(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT max(sublevels.levellocationid)
	FROM (studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid
		INNER JOIN charges ON qstudents.charge_id = charges.charge_id
		INNER JOIN sublevels ON sublevels.sublevelid = charges.sublevelid
	WHERE (studentdegrees.studentid = $1) AND (quarters.active = true);
$_$;


ALTER FUNCTION public.get_qstudent_location_id(character varying) OWNER TO postgres;

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
-- Name: getbankstudentid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getbankstudentid(character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mystudentid varchar(12);
	mycheckid varchar(240);
	mybankref varchar(240);
	myrec RECORD;
	myaccrec RECORD;
	i int;
BEGIN
	mystudentid := '';
	mybankref := $1;

	FOR i IN 1..20 LOOP
		mycheckid := trim(upper(split_part(mybankref, ' ', i)));
		IF char_length(mycheckid) >  6 THEN
			SELECT INTO myrec studentid FROM students WHERE studentid = mycheckid;
			IF myrec.studentid is not null THEN
				mystudentid := myrec.studentid;
			ELSE
				SELECT INTO myaccrec studentid FROM students WHERE accountnumber = mycheckid;
				IF myaccrec.studentid is not null THEN
					mystudentid := myaccrec.studentid;
				END IF;
			END IF;
		END IF; 
	END LOOP;

    RETURN mystudentid;
END;
$_$;


ALTER FUNCTION public.getbankstudentid(character varying) OWNER TO postgres;

--
-- Name: getcoremajor(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoremajor(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
    SELECT max(majors.majorname)
    FROM studentmajors INNER JOIN majors ON studentmajors.majorid = majors.majorid
    WHERE (studentmajors.studentdegreeid = $1) AND (studentmajors.primarymajor = true);
$_$;


ALTER FUNCTION public.getcoremajor(integer) OWNER TO postgres;

--
-- Name: getcoursecredits(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoursecredits(integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT (CASE courses.nogpa WHEN true THEN 0 ELSE courses.credithours END)
	FROM courses INNER JOIN qcourses ON courses.courseid = qcourses.courseid
	WHERE (qcourseid=$1);
$_$;


ALTER FUNCTION public.getcoursecredits(integer) OWNER TO postgres;

--
-- Name: getcoursedone(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoursedone(character varying, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT max(grades.gradeweight)
	FROM (((qcourses INNER JOIN qgrades ON qcourses.qcourseid = qgrades.qcourseid)
		INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid)
		INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (qstudents.approved = true) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW')
	AND (studentdegrees.studentid = $1) AND (qcourses.courseid = $2);		
$_$;


ALTER FUNCTION public.getcoursedone(character varying, character varying) OWNER TO postgres;

--
-- Name: getcoursehours(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoursehours(integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT courses.credithours
	FROM courses INNER JOIN qcourses ON courses.courseid = qcourses.courseid
	WHERE (qcourseid=$1);
$_$;


ALTER FUNCTION public.getcoursehours(integer) OWNER TO postgres;

--
-- Name: getcoursequarter(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoursequarter(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
    SELECT quarterid FROM qcourses WHERE (qcourseid = CAST($1 as INT));
$_$;


ALTER FUNCTION public.getcoursequarter(character varying) OWNER TO postgres;

--
-- Name: getcourserepeat(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcourserepeat(integer, character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qcourses.qcourseid)
	FROM (qgrades INNER JOIN (qcourses INNER JOIN courses ON qcourses.courseid = courses.courseid) ON qgrades.qcourseid = qcourses.qcourseid)
		INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid
	WHERE (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW') AND (qgrades.gradeid <> 'NG')
		AND (qgrades.dropped = false) AND (qstudents.approved = true) AND (courses.norepeats = false)
		AND (qstudents.studentdegreeid = $1) AND (qcourses.courseid = $2);
$_$;


ALTER FUNCTION public.getcourserepeat(integer, character varying) OWNER TO postgres;

--
-- Name: getcoursetransfered(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcoursetransfered(character varying, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(transferedcredits.credithours)
	FROM transferedcredits INNER JOIN studentdegrees ON transferedcredits.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (studentdegrees.studentid = $1) AND (transferedcredits.courseid = $2);		
$_$;


ALTER FUNCTION public.getcoursetransfered(character varying, character varying) OWNER TO postgres;

--
-- Name: getcummcredit(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcummcredit(integer, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.approved = true)
		AND (qstudents.quarterid <= $2) AND (qgrades.dropped = false)
		AND (grades.gpacount = true) AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getcummcredit(integer, character varying) OWNER TO postgres;

--
-- Name: getcummgpa(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcummgpa(integer, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid <= $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getcummgpa(integer, character varying) OWNER TO postgres;

--
-- Name: getcurrcredit(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcurrcredit(integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (grades.gpacount = true) AND (qgrades.dropped = false) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getcurrcredit(integer) OWNER TO postgres;

--
-- Name: getcurrgpa(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcurrgpa(integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (grades.gpacount = true) AND (qgrades.dropped = false) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getcurrgpa(integer) OWNER TO postgres;

--
-- Name: getcurrhours(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcurrhours(integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(qgrades.hours)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getcurrhours(integer) OWNER TO postgres;

--
-- Name: getcurrqstudentid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcurrqstudentid(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT max(qstudentid) 
	FROM qstudentlist INNER JOIN quarters ON qstudentlist.quarterid = quarters.quarterid 
	WHERE (studentid = $1) AND (quarters.active = true);
$_$;


ALTER FUNCTION public.getcurrqstudentid(character varying) OWNER TO postgres;

--
-- Name: getcurrsabathclass(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getcurrsabathclass(integer) RETURNS bigint
    LANGUAGE sql
    AS $_$
    SELECT count(qstudents.qstudentid)
	FROM qstudents INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid  
	WHERE (quarters.active = true) AND (sabathclassid = $1);
$_$;


ALTER FUNCTION public.getcurrsabathclass(integer) OWNER TO postgres;

--
-- Name: getdbgradeid(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getdbgradeid(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN max(gradeid) is null THEN 'NG' ELSE max(gradeid) END
	FROM grades 
	WHERE (minrange <= $1) AND (maxrange > $1);
$_$;


ALTER FUNCTION public.getdbgradeid(integer) OWNER TO postgres;

--
-- Name: getexamtimecount(integer, date, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getexamtimecount(integer, date, time without time zone, time without time zone) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qgradeid) FROM qexamtimetableview
	WHERE (qstudentid = $1) AND (examdate = $2) AND (((starttime, endtime) OVERLAPS ($3, $4))=true);
$_$;


ALTER FUNCTION public.getexamtimecount(integer, date, time without time zone, time without time zone) OWNER TO postgres;

--
-- Name: getfirstquarterid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getfirstquarterid(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT min(quarterid) 
	FROM qstudents INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (studentid = $1);
$_$;


ALTER FUNCTION public.getfirstquarterid(character varying) OWNER TO postgres;

--
-- Name: getfirstquarterid(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getfirstquarterid(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT min(quarterid)
	FROM qstudents
	WHERE (studentdegreeid = $1);
$_$;


ALTER FUNCTION public.getfirstquarterid(integer) OWNER TO postgres;

--
-- Name: getoverload(character varying, double precision, double precision, double precision, boolean, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getoverload(character varying, double precision, double precision, double precision, boolean, double precision) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myoverload boolean;
BEGIN
	myoverload := false;

	IF ($1='I') THEN
		IF ($3 is null) AND ($2 > 9) THEN
			myoverload := true;
		ELSIF (($4>=100) AND ($3>=2.67) AND ($2<=11)) THEN
			myoverload := false;
		ELSIF (($3<1.99) AND ($2>6)) THEN
			myoverload := true;
		ELSIF (($3<2.99) AND ($2>11)) THEN
			myoverload := true;
		ELSIF (($3<3.5) AND ($2>12)) THEN
			myoverload := true;
		ELSIF ($2>9) THEN
			myoverload := true;
		END IF;
	ELSIF (($3<1.99) AND ($2<>9)) THEN
		myoverload := true;
	ELSIF ($3 is null) AND ($2 > 14) THEN
		myoverload := true;
	ELSIF (($4>=109) AND ($3>=2.67) AND ($2<=17)) THEN
		myoverload := false;
	ELSE
		IF (($3<3) AND ($2>14)) THEN
			myoverload := true;
		ELSIF (($3<3.5) AND ($2>15)) THEN
			myoverload := true;
		ELSIF ($2>16) THEN
			myoverload := true;
		END IF;
	END IF;

	IF (myoverload = true) THEN
		IF ($5 = true) AND ($2 <= $6) THEN
			myoverload := false;
		END IF;
	END IF;

    RETURN myoverload;
END;
$_$;


ALTER FUNCTION public.getoverload(character varying, double precision, double precision, double precision, boolean, double precision) OWNER TO postgres;

--
-- Name: getplacementpassed(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getplacementpassed(integer, character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	passed boolean;
	studentrec RECORD;
	courserec RECORD;
BEGIN
	passed := true;

	SELECT mathplacement, englishplacement, kiswahiliplacement INTO studentrec
	FROM studentdegrees WHERE (studentdegreeid = $1);
	SELECT mathplacement, englishplacement, kiswahiliplacement INTO courserec
	FROM courses WHERE (courseid = $2);

	IF (studentrec.mathplacement < courserec.mathplacement) THEN
		passed := false;		
	END IF;
	IF (studentrec.englishplacement < courserec.englishplacement) THEN
		passed := false;		
	END IF;
	IF (studentrec.kiswahiliplacement < courserec.kiswahiliplacement) THEN
		passed := false;		
	END IF;

    RETURN passed;
END;
$_$;


ALTER FUNCTION public.getplacementpassed(integer, character varying) OWNER TO postgres;

--
-- Name: getprereqpassed(character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprereqpassed(character varying, character varying, integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	passed boolean;
	hasprereq boolean;
	myrec RECORD;
	orderid int;
BEGIN
	passed := false;
	hasprereq := false;
	orderid := 1;
	
	FOR myrec IN SELECT optionlevel, precourseid, gradeweight 
		FROM prereqview 
		WHERE (prereqview.courseid = $2) AND (prereqview.optionlevel > 0) AND (prereqview.bulletingid = $3)
	ORDER BY prereqview.optionlevel LOOP
		hasprereq :=  true;
		IF(orderid <> myrec.optionlevel) THEN
			orderid := myrec.optionlevel;
			passed := false;
		END IF;

		IF (getcoursedone($1, myrec.precourseid) >= myrec.gradeweight) THEN
			passed := true;
		END IF;
		IF (getcoursetransfered($1, myrec.precourseid) is not null) THEN
			passed := true;
		END IF;
	END LOOP;

	IF (hasprereq = false) THEN
		passed := true;
	END IF;

    RETURN passed;
END;
$_$;


ALTER FUNCTION public.getprereqpassed(character varying, character varying, integer) OWNER TO postgres;

--
-- Name: getprereqpassed(character varying, character varying, integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprereqpassed(character varying, character varying, integer, boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	passed boolean;
	myrec RECORD;
BEGIN
	passed := false;
	
	FOR myrec IN SELECT optionlevel, precourseid, gradeweight 
		FROM prereqview 
		WHERE (prereqview.courseid = $2) AND (prereqview.optionlevel = 0) AND (prereqview.bulletingid = $3)
	ORDER BY prereqview.optionlevel LOOP
		IF (getcoursedone($1, myrec.precourseid) >= myrec.gradeweight) THEN
			passed := true;
		END IF;
		IF (getcoursetransfered($1, myrec.precourseid) is not null) THEN
			passed := true;
		END IF;
	END LOOP;

	IF ($4 = true) THEN
		passed := true;
	END IF;

    RETURN passed;
END;
$_$;


ALTER FUNCTION public.getprereqpassed(character varying, character varying, integer, boolean) OWNER TO postgres;

--
-- Name: getprevcredit(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprevcredit(integer, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getprevcredit(integer, character varying) OWNER TO postgres;

--
-- Name: getprevgpa(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprevgpa(integer, character varying) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) AND (qgrades.repeated = false) 
		AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$_$;


ALTER FUNCTION public.getprevgpa(integer, character varying) OWNER TO postgres;

--
-- Name: getprevquarter(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprevquarter(integer, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT max(qstudents.quarterid)
	FROM qstudents
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid < $2);
$_$;


ALTER FUNCTION public.getprevquarter(integer, character varying) OWNER TO postgres;

--
-- Name: getprobation(character varying, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getprobation(character varying, double precision, double precision) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myprobation boolean;
BEGIN
	myprobation := false;

	IF ($2 < 1.99) THEN
		IF ($1 = 'I') THEN
			IF ($3 > 6) THEN 
				myprobation := true;
			END IF;
		ELSE
			IF ($3 <> 9) THEN
				myprobation := true;
			END IF;
		END IF;
	END IF;

    RETURN myprobation;
END;
$_$;


ALTER FUNCTION public.getprobation(character varying, double precision, double precision) OWNER TO postgres;

--
-- Name: getqcoursestudents(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getqcoursestudents(integer) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN count(qgradeid) is null THEN 0 ELSE count(qgradeid) END
	FROM qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid 
	WHERE (qgrades.dropped = false) AND (qstudents.finalised = true) AND (qcourseid = $1);
$_$;


ALTER FUNCTION public.getqcoursestudents(integer) OWNER TO postgres;

--
-- Name: getqstudentid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getqstudentid(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT max(qstudents.qstudentid) 
	FROM (studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid
	WHERE (studentdegrees.studentid = $1) AND (quarters.active = true);
$_$;


ALTER FUNCTION public.getqstudentid(character varying) OWNER TO postgres;

--
-- Name: getqstudentid(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getqstudentid(integer, character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT max(qstudents.qstudentid)
	FROM qstudents
	WHERE (studentdegreeid = $1) AND (quarterid = $2);
$_$;


ALTER FUNCTION public.getqstudentid(integer, character varying) OWNER TO postgres;

--
-- Name: getrepeatapprove(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getrepeatapprove(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myrec RECORD;
	mystr VARCHAR(12);
BEGIN
	mystr := null;
	FOR myrec IN SELECT courseid, getcourserepeat(studentdegreeid, courseid), crs_approved, getcoursedone(studentid, courseid)
		FROM studentgradeview 
		WHERE (qstudentid = $1) AND (getcourserepeat(studentdegreeid, courseid) > 0) 
		AND (crs_approved = false) AND (dropped = false) LOOP
	
		IF (myrec.getcoursedone > 1.67) THEN
			mystr := myrec.courseid;
		END IF;
		IF (myrec.getcourserepeat > 1) THEN
			mystr := myrec.courseid;
		END IF;
	END LOOP;
	
    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.getrepeatapprove(integer) OWNER TO postgres;

--
-- Name: getschoolid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getschoolid(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT schoolid FROM departments WHERE (departmentid = $1);
$_$;


ALTER FUNCTION public.getschoolid(character varying) OWNER TO postgres;

--
-- Name: getstudentdegreeid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getstudentdegreeid(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
    SELECT max(studentdegreeid) FROM studentdegrees WHERE (studentid=$1) AND (completed=false);
$_$;


ALTER FUNCTION public.getstudentdegreeid(character varying) OWNER TO postgres;

--
-- Name: getstudentdegreeid(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getstudentdegreeid(character varying, character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT max(qstudents.studentdegreeid)
	FROM studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid
	WHERE (studentdegrees.studentid = $1) AND (qstudents.quarterid = $2);
$_$;


ALTER FUNCTION public.getstudentdegreeid(character varying, character varying) OWNER TO postgres;

--
-- Name: getstudentid(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getstudentid(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
    SELECT max(studentid) FROM students WHERE (studentid = $1);
$_$;


ALTER FUNCTION public.getstudentid(character varying) OWNER TO postgres;

--
-- Name: getstudentquarter(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION getstudentquarter(character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
    SELECT quarterid FROM qstudents WHERE (qstudentid = CAST($1 as INT));
$_$;


ALTER FUNCTION public.getstudentquarter(character varying) OWNER TO postgres;

--
-- Name: gettimeassetcount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION gettimeassetcount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean, character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qtimetableid) FROM qtimetableview
	WHERE (assetid = $1) AND (((starttime, endtime) OVERLAPS ($2, $3))=true) 
	AND ((cmonday and $4) OR (ctuesday and $5) OR (cwednesday and $6) OR (cthursday and $7) OR (cfriday and $8) OR (csaturday and $9) OR (csunday and $10))
	AND (quarterid = $11);
$_$;


ALTER FUNCTION public.gettimeassetcount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean, character varying) OWNER TO postgres;

--
-- Name: gettimecount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION gettimecount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qtimetableid) FROM studenttimetableview
	WHERE (qstudentid=$1) AND (((starttime, endtime) OVERLAPS ($2, $3))=true) 
	AND ((cmonday and $4) OR (ctuesday and $5) OR (cwednesday and $6) OR (cthursday and $7) OR (cfriday and $8) OR (csaturday and $9) OR (csunday and $10));
$_$;


ALTER FUNCTION public.gettimecount(integer, time without time zone, time without time zone, boolean, boolean, boolean, boolean, boolean, boolean, boolean) OWNER TO postgres;

--
-- Name: grade_updates(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION grade_updates(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
	IF($3 = '1')THEN
		UPDATE qgrades SET gradeid = 'F'
		FROM qstudents WHERE (qgrades.qstudentid = qstudents.qstudentid) 
			AND (qgrades.dropped = false) AND (gradeid = 'NG')
			AND (qstudents.quarterid = $1);
	END IF;

	IF($3 = '2')THEN
		UPDATE qgrades SET gradeid = 'AW'
		FROM qstudents WHERE (qgrades.qstudentid = qstudents.qstudentid) 
			AND (qgrades.dropped = false) AND (gradeid = 'DG')
			AND (qstudents.quarterid = $1);
	END IF;

	RETURN 'Grade updates';
END;
$_$;


ALTER FUNCTION public.grade_updates(character varying, character varying, character varying) OWNER TO postgres;

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
-- Name: ins_application(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_application() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN	
	IF(NEW.selection_id is not null) THEN
		INSERT INTO entry_forms (org_id, entity_id, entered_by_id, form_id)
		VALUES(NEW.org_id, NEW.entity_id, NEW.entity_id, NEW.selection_id);
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_application() OWNER TO postgres;

--
-- Name: ins_application_forms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_application_forms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	INSERT INTO registrations(markid, entity_id, degreeid, majorid, sublevelid, 
		county_id, org_id, entry_form_id, session_id, email, entrypass, 
		firstpass, existingid, scheduledate, applicationdate, accepted, 
		premajor, submitapplication, submitdate, isaccepted, isreported,
		isdeferred, isrejected, evaluationdate, accepteddate, reported, 
		reporteddate, denominationid, mname, fname, fdenominationid, 
		mdenominationid, foccupation, fnationalityid, moccupation, mnationalityid, 
		parentchurch, parentemployer, birthdate, baptismdate, lastname, 
		firstname, middlename, sex, maritalstatus, nationalityid, citizenshipid, 
		residenceid, firstlanguage, otherlanguages, churchname, churcharea, 
		churchaddress, handicap, personalhealth, smoke, drink, drugs, 
		hsmoke, hdrink, hdrugs, attendedprimary, attendedsecondary, expelled, 
		previousrecord, workexperience, employername, postion, attendedueab, 
		attendeddate, dateemployed, campusresidence, details)
	VALUES(NEW.markid, NEW.entity_id, NEW.degreeid, NEW.majorid, NEW.sublevelid, 
		NEW.county_id, NEW.org_id, NEW.entry_form_id, NEW.session_id, NEW.email, NEW.entrypass, 
		NEW.firstpass, NEW.existingid, NEW.scheduledate, NEW.applicationdate, NEW.accepted, 
		NEW.premajor, NEW.submitapplication, NEW.submitdate, NEW.isaccepted, NEW.isreported,
		NEW.isdeferred, NEW.isrejected, NEW.evaluationdate, NEW.accepteddate, NEW.reported,
		NEW.reporteddate, NEW.denominationid, NEW.mname, NEW.fname, NEW.fdenominationid, 
		NEW.mdenominationid, NEW.foccupation, NEW.fnationalityid, NEW.moccupation, NEW.mnationalityid, 
		NEW.parentchurch, NEW.parentemployer, NEW.birthdate, NEW.baptismdate, NEW.lastname,
		NEW.firstname, NEW.middlename, substring(NEW.sex from 1 for 1), substring(NEW.maritalstatus from 1 for 1), 
		NEW.nationalityid, NEW.citizenshipid, 
		NEW.residenceid, NEW.firstlanguage, NEW.otherlanguages, NEW.churchname, NEW.churcharea, 
		NEW.churchaddress, NEW.handicap, NEW.personalhealth, NEW.smoke, NEW.drink, NEW.drugs, 
		NEW.hsmoke, NEW.hdrink, NEW.hdrugs, NEW.attendedprimary, NEW.attendedsecondary, NEW.expelled, 
		NEW.previousrecord, NEW.workexperience, NEW.employername, NEW.postion, NEW.attendedueab, 
		NEW.attendeddate, NEW.dateemployed, NEW.campusresidence, NEW.details);

	RETURN null;
END;
$$;


ALTER FUNCTION public.ins_application_forms() OWNER TO postgres;

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
-- Name: ins_charges(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_charges() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM sublevels
	WHERE (sublevelid = NEW.sublevelid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_charges() OWNER TO postgres;

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
-- Name: ins_qcourses(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_qcourses() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	SELECT labcourse, examinable, clinical_fee, extracharge, coursetitle
		INTO NEW.labcourse, NEW.examinable, NEW.clinical_fee, NEW.extracharge, NEW.session_title
	FROM courses
	WHERE (courseid = NEW.courseid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_qcourses() OWNER TO postgres;

--
-- Name: ins_qgrades(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_qgrades() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM qstudents
	WHERE (qstudentid = NEW.qstudentid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_qgrades() OWNER TO postgres;

--
-- Name: ins_qresidences(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_qresidences() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	SELECT org_id INTO NEW.org_id
	FROM residences
	WHERE (residenceid = NEW.residenceid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_qresidences() OWNER TO postgres;

--
-- Name: ins_qstudents(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_qstudents() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec RECORD;
	mystr VARCHAR(120);
BEGIN
	SELECT org_id INTO NEW.org_id
	FROM charges
	WHERE (charge_id = NEW.charge_id);

	IF(TG_OP = 'UPDATE')THEN
		IF (OLD.approved = false) AND (NEW.approved = true) THEN
			IF (NEW.finaceapproval = false) THEN
				RAISE EXCEPTION 'You cannot close without financial approval';
			END IF;
		END IF;

		IF (OLD.finaceapproval = true) AND (NEW.finaceapproval = false) THEN
			NEW.finalised := false;
			NEW.printed := false;
			NEW.approved := false;
		END IF;
		
		IF (OLD.finalised = true) AND (NEW.finalised = false) THEN
			NEW.finaceapproval := false;
			NEW.printed := false;
			NEW.approved := false;
			NEW.majorapproval := false;		
		END IF;

		IF (OLD.withdraw = false) AND (NEW.withdraw = true) THEN
			NEW.withdraw_date := current_date;
			NEW.withdraw_rate := calcWithdrawRate();
		END IF;

		IF (OLD.ac_withdraw = false) AND (NEW.ac_withdraw = true) THEN
			NEW.withdraw_date := current_date;
			NEW.withdraw_rate := calcWithdrawRate();
		END IF;

		IF(OLD.approve_late_fee = false) AND (NEW.approve_late_fee = true) THEN
			NEW.late_fee_date := current_date;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_qstudents() OWNER TO postgres;

--
-- Name: ins_qtimetable(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_qtimetable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM qcourses
	WHERE (qcourseid = NEW.qcourseid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_qtimetable() OWNER TO postgres;

--
-- Name: ins_quarters(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_quarters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	INSERT INTO qresidences (quarterid, residenceid, org_id, charges)
	SELECT NEW.quarterid, residenceid, org_id, defaultrate
	FROM residences
	ORDER BY residenceid;

	INSERT INTO charges (quarterid, last_reg_date, sublevelid, org_id, 
		unit_charge, lab_charges, exam_fees, general_fees, exchange_rate)
	SELECT NEW.quarterid, NEW.qlatereg, sublevelid, org_id, 
		unit_charge, lab_charges, exam_fees, general_fees, 1
	FROM sublevels;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_quarters() OWNER TO postgres;

--
-- Name: ins_registrations(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_registrations() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id			INTEGER;	
	v_entity_id			INTEGER;
	v_email				varchar(120);
BEGIN
	
	SELECT org_id, entity_id INTO v_org_id, v_entity_id
	FROM entry_forms
	WHERE (entry_form_id = NEW.entry_form_id);

	SELECT user_name INTO v_email
	FROM entitys
	WHERE (entity_id = v_entity_id);

	IF(v_org_id is null)THEN
		v_org_id := 0;
	END IF;
	
	NEW.entity_id := v_entity_id;
	NEW.org_id := v_org_id;
	NEW.email := v_email;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_registrations() OWNER TO postgres;

--
-- Name: ins_studentdegrees(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_studentdegrees() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_org_id		integer;
BEGIN

	SELECT org_id INTO v_org_id
	FROM sublevels
	WHERE (sublevelid = NEW.sublevelid);
	
	UPDATE students SET org_id = v_org_id WHERE studentid = NEW.studentid;
	UPDATE entitys SET org_id = v_org_id WHERE user_name = NEW.studentid;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_studentdegrees() OWNER TO postgres;

--
-- Name: ins_students(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_students() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (user_name = NEW.studentid);

	IF(v_entity_id is null)THEN
		INSERT INTO entitys (org_id, entity_type_id, entity_name, user_name, primary_email, first_password, entity_password)
		VALUES(0, 9, NEW.studentname, NEW.studentid, NEW.email, NEW.firstpass, NEW.studentpass);

		INSERT INTO entitys (org_id, entity_type_id, entity_name, user_name, primary_email, first_password, entity_password)
		VALUES(0, 10, COALESCE(NEW.guardianname, NEW.studentname), 'G' || NEW.studentid, NEW.gemail, NEW.gfirstpass, NEW.gstudentpass);
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_students() OWNER TO postgres;

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
-- Name: insnewstudent(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insnewstudent(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reg_check		RECORD;
	myrec 			RECORD;
	priadd 			RECORD;
	gudadd 			RECORD;
	idcount 		RECORD;
	myqtr 			RECORD;

	rtn				varchar(50);
	v_org_id		integer;
	reg_id			integer;
	baseid 			VARCHAR(12);
	newid 			VARCHAR(12);
	fullname 		VARCHAR(50);
	genfirstpass 	VARCHAR(32);
	gfirstpass 		VARCHAR(32);
	genstudentpass 	VARCHAR(32);
BEGIN
	
	reg_id := CAST($1 as integer);

	SELECT denominationid, majorid, degreeid, sublevelid, residenceid, nationalityid, citizenshipid
		INTO reg_check
	FROM registrations
	WHERE (registrationid = reg_id);

	SELECT departments.schoolid, registrations.org_id, registrations.registrationid,
		registrations.denominationid, registrations.lastname, registrations.middlename, registrations.firstname,
		registrations.sex, registrations.nationalityid, registrations.maritalstatus,
		registrations.birthdate, registrations.existingid, registrations.degreeid, registrations.sublevelid,
		registrations.majorid, registrations.premajor
		INTO myrec
	FROM (departments INNER JOIN majors ON departments.departmentid = majors.departmentid)
	INNER JOIN registrations ON majors.majorid = registrations.majorid
	WHERE (registrations.registrationid = reg_id);

	SELECT regcontacts.regcontactid, regcontacts.address, regcontacts.zipcode, regcontacts.town, 
		regcontacts.countrycodeid, regcontacts.telephone, regcontacts.email
		INTO priadd
	FROM contacttypes INNER JOIN regcontacts ON contacttypes.contacttypeid = regcontacts.contacttypeid
	WHERE (contacttypes.primarycontact = true) AND (regcontacts.registrationid = reg_id);

	SELECT regcontacts.regcontactid, regcontacts.regcontactname, regcontacts.address, regcontacts.zipcode, 
		regcontacts.town, regcontacts.countrycodeid, regcontacts.telephone, regcontacts.email
		INTO gudadd
	FROM regcontacts
	WHERE (regcontacts.guardiancontact = true) AND (regcontacts.registrationid = reg_id);

	SELECT quarterid INTO myqtr
	FROM quarters WHERE active = true;

	baseid := upper('S' || substring(trim(myrec.lastname) from 1 for 3) || substring(trim(myrec.firstname) from 1 for 2) || substring(myqtr.quarterid from 8 for 2) || substring(myqtr.quarterid from 11 for 1));

	SELECT INTO idcount count(studentid) as baseidcount
	FROM students
	WHERE substring(studentid from 1 for 9) = baseid;

	newid := baseid || (idcount.baseidcount + 1);

	IF (myrec.middlename IS NULL) THEN
		fullname := upper(trim(myrec.lastname)) || ', ' || upper(trim(myrec.firstname));
	ELSE
		fullname := upper(trim(myrec.lastname)) || ', ' || upper(trim(myrec.middlename)) || ' ' || upper(trim(myrec.firstname));
	END IF;
	
	genfirstpass := first_password();
	gfirstpass := first_password();
	genstudentpass := md5(genfirstpass);

	IF(reg_check.denominationid is null)THEN
		rtn := 'You need to add denomination';
	ELSIF(reg_check.majorid is null)THEN
		rtn := 'You need to add major';
	ELSIF(reg_check.degreeid is null)THEN
		rtn := 'You need to add major';
	ELSIF(reg_check.sublevelid is null)THEN
		rtn := 'You need to add degree level';
	ELSIF(reg_check.residenceid is null)THEN
		rtn := 'You need to add country';
	ELSIF(reg_check.nationalityid is null)THEN
		rtn := 'You need to add nationality';
	ELSIF(reg_check.citizenshipid is null)THEN
		rtn := 'You need to add citizenship';
	ELSIF (myrec.existingid is null) THEN

		v_org_id := myrec.org_id;
		IF(v_org_id is null)THEN
			SELECT org_id INTO v_org_id
			FROM sublevels
			WHERE (sublevelid = reg_check.sublevelid);
		END IF;

		INSERT INTO students (org_id, studentid, accountnumber, studentname, schoolid, denominationid, Sex, Nationality,
			MaritalStatus, birthdate, firstpass, studentpass, address, zipcode, town, countrycodeid, telno, email,
			guardianname, gaddress, gzipcode, gtown, gcountrycodeid, gtelno, gemail, gfirstpass, gstudentpass,
			balance_time, curr_balance)
		VALUES (v_org_id, newid, newid, fullname, myrec.schoolid, myrec.denominationid, myrec.Sex, myrec.Nationalityid,
			myrec.MaritalStatus, myrec.birthdate, genfirstpass, genstudentpass,
			priadd.address, priadd.zipcode, priadd.town, myrec.Nationalityid, priadd.telephone, priadd.email,
			gudadd.regcontactname, gudadd.address, gudadd.zipcode, gudadd.town, myrec.Nationalityid, gudadd.telephone, gudadd.email,
			gfirstpass, md5(gfirstpass), now(), 0);

		INSERT INTO studentdegrees (degreeid, sublevelid, studentid, started, bulletingid)
		VALUES (myrec.degreeid,  myrec.sublevelid, newid, current_date, 0);

		INSERT INTO studentmajors (studentdegreeid, majorid, major, nondegree, premajor, primarymajor)
		VALUES (getstudentdegreeid(newid), myrec.majorid, true, false, myrec.premajor, true);

		UPDATE registrations SET existingid = newid, accepted=true, accepteddate=current_date, firstpass=genfirstpass  
		WHERE (registrations.registrationid = reg_id);

		rtn := newid;
	ELSE
		rtn := myrec.existingid;
	END IF;

    RETURN rtn;
END;
$_$;


ALTER FUNCTION public.insnewstudent(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: insqclose(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insqclose(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	myrec 			RECORD;
	myqrec 			RECORD;
	ttb 			RECORD;
	fnar 			RECORD;
	courserec 		RECORD;
	placerec 		RECORD;
	prererec 		RECORD;
	studentrec 		RECORD;
	mystr 			varchar(250);
	myrepeatapprove	varchar(12);
	mydegreeid 		int;
	myoverload 		boolean;
	myprobation 	boolean;
	mysabathclass	boolean;
	v_last_reg		boolean;
	myfeesline 		real;
BEGIN
	mydegreeid := getstudentdegreeid($2);

	SELECT qstudentid, finalised, finaceapproval, totalfees, finalbalance, gpa, hours, quarterid, quarter, feesline, 
		resline, offcampus, residenceoffcampus, overloadapproval,
		degreelevelid, getcummcredit(studentdegreeid, quarterid) as cummcredit, 
		getcummgpa(studentdegreeid, quarterid) as cummgpa 
		INTO myrec
	FROM studentquarterview
	WHERE (studentdegreeid = mydegreeid) AND (quarterid = $1);

	SELECT studentdegrees.sublevelid, students.fullbursary, students.seeregistrar, students.onprobation, 
		students.details as probationdetail, students.gaddress, students.address 
		INTO studentrec
	FROM students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid  
	WHERE (studentdegrees.studentdegreeid = mydegreeid);

	SELECT qstudents.roomnumber, qstudents.qresidenceid, qstudents.sabathclassid, qstudents.overloadapproval, 
		qstudents.overloadhours, qstudents.financenarrative, qstudents.firstinstalment, 
		qstudents.firstdate, qstudents.secondinstalment, qstudents.seconddate, qstudents.registrarapproval, 
		qstudents.approve_late_fee, qstudents.late_fee_date,
		charges.last_reg_date
		INTO myqrec
	FROM qstudents INNER JOIN charges ON qstudents.charge_id = charges.charge_id
	WHERE qstudents.qstudentid = myrec.qstudentid;

	SELECT courseid, coursetitle INTO courserec
	FROM selcourseview WHERE (qstudentid = myrec.qstudentid) AND (maxclass < qcoursestudents);

	SELECT courseid, coursetitle, placementpassed, prereqpassed INTO prererec
	FROM selectedgradeview 
	WHERE (qstudentid = myrec.qstudentid) AND ((prereqpassed = false) OR (placementpassed = false));

	myoverload := getoverload(myrec.quarter, myrec.hours, myrec.cummgpa, myrec.cummcredit, myqrec.overloadapproval, myqrec.overloadhours);

	SELECT coursetitle INTO ttb 
	FROM studenttimetableview WHERE (qstudentid = myrec.qstudentid)
	AND (gettimecount(qstudentid, starttime, endtime, cmonday, ctuesday, cwednesday, cthursday, cfriday, csaturday, csunday) >1);

	myrepeatapprove := getrepeatapprove(myrec.qstudentid);

	IF (myrec.offcampus = TRUE) THEN
		myfeesline := myrec.totalfees * (100 - myrec.feesline) /100;
		mysabathclass := false;
	ELSE
		myfeesline := myrec.totalfees * (100 - myrec.resline) / 100;
		IF (myqrec.sabathclassid is null) THEN
			mysabathclass := true;
		ELSIF (myqrec.sabathclassid = 0) THEN
			mysabathclass := true;
		ELSE
			mysabathclass := false;
		END IF;
	END IF;
	
	myprobation := false;
	IF (myrec.cummgpa is not null) THEN
		IF (((myrec.degreelevelid = 'MAS') OR (upper(myrec.degreelevelid) = 'PHD')) AND (myrec.cummgpa < 2.99)) THEN
			myprobation := true;
		END IF;
		IF (myrec.cummgpa < 1.99) THEN
			myprobation := true;
		END IF;
	END IF;
	IF (myqrec.registrarapproval = true) THEN
		myprobation := false;
	END IF;

	v_last_reg := false;
	IF(myqrec.late_fee_date <= current_date) THEN
		IF(myqrec.approve_late_fee = false)THEN
			v_last_reg := true;
		END IF;
	END IF;

	mystr := '';
	IF (studentrec.onprobation = true) THEN
		IF(studentrec.probationdetail != null) THEN
			mystr := '<br/>' || studentrec.probationdetail;
		END IF;
		RAISE EXCEPTION 'Student on Probation, See the Dean of Students % ', mystr;
	ELSIF (studentrec.seeregistrar = true) THEN
		IF(studentrec.probationdetail != null) THEN
			mystr := '<br/>' || studentrec.probationdetail;
		END IF;
		RAISE EXCEPTION 'Cannot Proceed, See Registars office  % ', mystr;
	ELSIF (myrec.qstudentid IS NULL) THEN 
		RAISE EXCEPTION 'Please register for the quarter, residence first before closing';
	ELSIF (myrec.finalised = true) THEN
		RAISE EXCEPTION 'Quarter is closed for registration';
    ELSIF (studentrec.gaddress IS NULL) THEN
		RAISE EXCEPTION 'Cannot Proceed, See Records office, Wrong Guardian Address';
	ELSIF (studentrec.address IS NULL) THEN
		RAISE EXCEPTION 'Cannot Proceed, See Records office, Wrong Student Address';
	ELSIF (myrec.finalised = true) THEN
		RAISE EXCEPTION 'Quarter is closed for registration';
	ELSIF (myprobation = true) THEN
		RAISE EXCEPTION 'Your Cumm. GPA is below the required level, you need to see the registrar for apporval.';
	ELSIF (v_last_reg = true) THEN
		RAISE EXCEPTION 'You need to clear for late registration with the Registars office';
	ELSIF (myqrec.qresidenceid is null) THEN
		RAISE EXCEPTION 'You have to select your residence first';
	ELSIF (myrec.offcampus = false) AND (myqrec.roomnumber is null) THEN
		RAISE EXCEPTION 'You have to select your residence room first';
	ELSIF (myrepeatapprove IS NOT NULL) THEN
		RAISE EXCEPTION 'You need repeat approval for % from the registrar', myrepeatapprove;
	ELSIF (ttb.coursetitle IS NOT NULL) THEN
		RAISE EXCEPTION 'You have an timetable clashing for % ', ttb.coursetitle;
	ELSIF (courserec.courseid IS NOT NULL) THEN
		RAISE EXCEPTION 'The class %, % is full', courserec.courseid, courserec.coursetitle;
	ELSIF (prererec.courseid IS NOT NULL) THEN
		RAISE EXCEPTION 'You need to complete the prerequisites or placement for course %, % ', prererec.courseid, prererec.coursetitle;
	ELSIF (getprobation(myrec.quarter, myrec.cummgpa, myrec.hours) = true) THEN
		RAISE EXCEPTION 'You are under accedemic probation and must take 12 units only or 10 for 4th quarter.';
	ELSIF (myoverload = true) THEN
		RAISE EXCEPTION 'You have an overload';
	ELSIF (myrec.offcampus = false) and (myrec.residenceoffcampus = true) THEN
		RAISE EXCEPTION 'You have no clearence to be off campus';
	ELSIF (studentrec.fullbursary = true) THEN
		UPDATE qstudents SET finalised = true, finaceapproval = true WHERE qstudentid = myrec.qstudentid;
		UPDATE qstudents SET firstclosetime = now() WHERE (firstclosetime is null) AND (qstudentid = myrec.qstudentid); 
		mystr := 'Quarter Closed based on bursary status';
	ELSIF (myrec.finaceapproval = true) THEN
		UPDATE qstudents SET finalised = true WHERE qstudentid = myrec.qstudentid;
		UPDATE qstudents SET firstclosetime = now() WHERE (firstclosetime is null) AND (qstudentid = myrec.qstudentid);
		mystr := 'Quarter Closed based on financial approval';		
	ELSIF (myrec.finalbalance IS NULL) THEN
		RAISE EXCEPTION 'Financial balance not updated, make payments, then check your statement.';
	ELSIF (myrec.finalbalance > myfeesline) THEN
		RAISE EXCEPTION 'Not Enough financial credit, make payments, then check your statement.';
	ELSIF (myrec.finalbalance < 2000) THEN
		UPDATE qstudents SET finalised = true, finaceapproval = true WHERE qstudentid = myrec.qstudentid;
		UPDATE qstudents SET firstclosetime = now() WHERE (firstclosetime is null) AND (qstudentid = myrec.qstudentid);
		mystr := 'Quarter Closed based on financial promise';
	ELSE
		UPDATE qstudents SET finalised = true, finaceapproval = true WHERE qstudentid = myrec.qstudentid;
		UPDATE qstudents SET firstclosetime = now() WHERE (firstclosetime is null) AND (qstudentid = myrec.qstudentid);
		mystr := 'Quarter Closed, awaiting approvals';
	END IF;

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.insqclose(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: insqcourse(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insqcourse(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mysrec 		RECORD;
	myrec 		RECORD;
	mystr 		varchar(120);
	v_courseid	varchar(12);
	mycurrqs 	int;
BEGIN
	mycurrqs := getcurrqstudentid($2);

	SELECT org_id, qstudentid, finalised, approved INTO mysrec 
	FROM qstudents
	WHERE (qstudentid = mycurrqs);

	SELECT courseid INTO v_courseid
	FROM qcourses WHERE (qcourses.qcourseid = CAST($1 as int));

	SELECT qgrades.qgradeid, qgrades.dropped, qgrades.approved, qcourses.courseid INTO myrec
	FROM qgrades INNER JOIN qcourses ON qgrades.qcourseid = qcourses.qcourseid
	WHERE (qgrades.qstudentid = mycurrqs) AND (qcourses.qcourseid = CAST($1 as int));
	
	IF (mysrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for quarter and select residence first.';
	ELSIF (mysrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSIF (myrec.qgradeid IS NULL) THEN
		INSERT INTO qgrades(org_id, qstudentid, qcourseid, hours, credit, approved) 
		VALUES (mysrec.org_id, mycurrqs, CAST($1 AS integer), getcoursehours(CAST($1 AS integer)), getcoursecredits(CAST($1 AS integer)), true);
		mystr := v_courseid || 'Course registered awaiting approval';
	ELSIF (myrec.dropped = true) THEN
		UPDATE qgrades SET dropped = false, askdrop = false, approved = false, hours = getcoursehours(CAST($1 AS integer)), 
			credit = getcoursecredits(CAST($1 AS integer)) WHERE qgradeid = myrec.qgradeid;
		mystr := v_courseid || ' registered awaiting approval';
	ELSE
		mystr := v_courseid || ' already registered';
	END IF;

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.insqcourse(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: insqspecialcourse(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insqspecialcourse(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mysrec 		RECORD;
	myrec 		RECORD;
	mystr 		varchar(120);
	v_courseid	varchar(12);
	mycurrqs 	int;
BEGIN
	mycurrqs := getcurrqstudentid($2);

	SELECT org_id, qstudentid, finalised, approved INTO mysrec
	FROM qstudents
	WHERE (qstudentid = mycurrqs);

	SELECT courseid INTO v_courseid
	FROM qcourses WHERE (qcourses.qcourseid = CAST($1 as int));

	SELECT qgrades.qgradeid, qgrades.dropped, qgrades.approved, qcourses.courseid INTO myrec
	FROM qgrades INNER JOIN qcourses ON qgrades.qcourseid = qcourses.qcourseid
	WHERE (qgrades.qstudentid = mycurrqs) AND (qcourses.qcourseid = CAST($1 as int));
	
	IF (mysrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for quarter and select residence first.';
	ELSIF (mysrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSIF (myrec.qgradeid IS NULL) THEN
		INSERT INTO qgrades(org_id, qstudentid, qcourseid, hours, credit, approved) 
		VALUES (mysrec.org_id, mycurrqs, CAST($1 AS integer), getcoursehours(CAST($1 AS integer)), getcoursecredits(CAST($1 AS integer)), false);
		mystr := v_courseid || ' registered awaiting approval';
	ELSIF (myrec.dropped = true) THEN
		UPDATE qgrades SET dropped = false, askdrop = false, approved = false, hours = getcoursehours(CAST($1 AS integer)), 
			credit = getcoursecredits(CAST($1 AS integer)) 
		WHERE qgradeid = myrec.qgradeid;
		mystr := v_courseid || ' registered awaiting approval';
	ELSE
		mystr := v_courseid || ' already registered';
	END IF;

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.insqspecialcourse(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: insqstudent(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insqstudent(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	srec			RECORD;
	qrec			RECORD;
	qsrec			RECORD;
	qqrec			RECORD;
	v_minimal_fees	real;
	resid			VARCHAR(12);
	sclassid		INTEGER;
	qresid			INTEGER;
	mystr			VARCHAR(120);
BEGIN
	SELECT students.onprobation, students.seeregistrar, students.probation_details, students.registrar_details,
		students.balance_time, CAST(students.balance_time as date) as balance_date, students.curr_balance,
		students.offcampus, students.residenceid, students.room_number, students.org_id,
		students.fullbursary, students.staff,
		studentdegrees.studentdegreeid, studentdegrees.degreeid, studentdegrees.sublevelid
	INTO srec
	FROM students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid
	WHERE (studentdegrees.completed = false) AND (students.studentid = $2);

	SELECT quarterid, levellocationid, active, closed, charge_id, session_active, session_closed, minimal_fees
	INTO qrec
	FROM vw_charges
	WHERE (quarterid = $1) AND (sublevelid = srec.sublevelid);

	SELECT qstudentid INTO qsrec
	FROM qstudents WHERE (studentdegreeid = srec.studentdegreeid) AND (charge_id = qrec.charge_id);
	SELECT qstudentid INTO qqrec
	FROM qstudents WHERE (studentdegreeid = srec.studentdegreeid) AND (quarterid = $1); 

	SELECT max(qresidenceid) INTO qresid
	FROM qresidences
	WHERE (quarterid = qrec.quarterid);

	v_minimal_fees := -1 * qrec.minimal_fees;
	IF (srec.fullbursary = true) THEN
		v_minimal_fees := 1000000;
	ELSIF (srec.staff = true) THEN
		v_minimal_fees := 1000000;
	END IF;

	mystr := '';
	IF (qsrec.qstudentid IS NOT NULL) THEN
		RAISE EXCEPTION 'Semester already registered';
	ELSIF (qrec.active = false) OR (qrec.closed = true) THEN
		RAISE EXCEPTION 'The semester is closed for application';
	ELSIF (qrec.session_active = false) OR (qrec.session_closed = true) THEN
		RAISE EXCEPTION 'The semester session is closed for application';
	ELSIF (srec.studentdegreeid IS NULL) THEN
		RAISE EXCEPTION 'No Degree Indicated contact Registrars Office';
	ELSIF (srec.onprobation = true) THEN
		IF(srec.probation_details != null) THEN
			mystr := '<br/>' || srec.probation_details;
		END IF;
		RAISE EXCEPTION 'You are on Probation, See the Dean of Students. % ', mystr;
	ELSIF (srec.seeregistrar = true) THEN
		IF(srec.registrar_details != null) THEN
			mystr := '<br/>' ||srec.registrar_details;
		END IF;
		RAISE EXCEPTION 'Cannot Proceed, See Registars office. % ', mystr;
	ELSE
		sclassid := null;
		IF(qrec.levellocationid = 1)THEN
			sclassid := 0;
		END IF;

		IF(qqrec.qstudentid IS NULL) THEN
			INSERT INTO qstudents(org_id, quarterid, charge_id, studentdegreeid, chaplainapproval, qresidenceid, roomnumber, sabathclassid, currbalance)
			VALUES (srec.org_id, qrec.quarterid, qrec.charge_id, srec.studentdegreeid, true, qresid, srec.room_number, sclassid, srec.curr_balance);
			mystr := 'Quarter registered. Select courses and submit.';
		ELSE
			UPDATE qstudents SET charge_id = qrec.charge_id WHERE qstudentid = qqrec.qstudentid;
			mystr := 'Quarter registered. Select courses and submit.';
		END IF;
	END IF;

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.insqstudent(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: openqcoursedepartment(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION openqcoursedepartment(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
	UPDATE qcourses SET submit_grades = false
	WHERE (qcourseid = CAST($1 as int));
	
	RETURN 'Course opened for lecturer to correct';
END;
$_$;


ALTER FUNCTION public.openqcoursedepartment(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: openquarter(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION openquarter(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE charges SET session_active = true, session_closed = false 
	WHERE (charges.quarterid = $1);

	UPDATE qcourses SET approved = false WHERE (quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$_$;


ALTER FUNCTION public.openquarter(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: reset_password(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION reset_password(character varying, character varying, character varying) RETURNS character varying
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
	
	passchange := first_password();
	UPDATE entitys SET first_password = passchange, Entity_password = md5(passchange) WHERE (entity_id = entityID);
	passchange := 'Password Changed to ' || passchange;

	return passchange;
END;
$_$;


ALTER FUNCTION public.reset_password(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: roomcount(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION roomcount(integer, integer) RETURNS bigint
    LANGUAGE sql
    AS $_$
	SELECT count(qstudentid) FROM qstudents WHERE (qresidenceid = $1) AND (roomnumber = $2);
$_$;


ALTER FUNCTION public.roomcount(integer, integer) OWNER TO postgres;

--
-- Name: sel_campus(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION sel_campus() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	SELECT org_id INTO NEW.org_id
	FROM levellocations
	WHERE (levellocationid = NEW.levellocationid);

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.sel_campus() OWNER TO postgres;

--
-- Name: selqresidence(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION selqresidence(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mystr			VARCHAR(120);
	myrec			RECORD;
	v_offcampus		boolean;
	myqstud			int;
	myres			int;
BEGIN
	myqstud := getcurrqstudentid($2);
	myres := CAST($1 AS integer);

	SELECT qstudentid, finalised INTO myrec
	FROM qstudents WHERE (qstudentid = myqstud);

	SELECT offcampus INTO v_offcampus
	FROM residences INNER JOIN qresidences ON residences.residenceid = qresidences.residenceid
	WHERE (qresidences.qresidenceid =  myres);

	IF (myrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for the quarter first.';
	ELSIF (myrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSE
		UPDATE qstudents SET qresidenceid = myres, roomnumber = null WHERE (qstudentid = myqstud);
		IF(v_offcampus = true)THEN
			mystr := 'Residence registered, register courses';
		ELSE
			mystr := 'Residence registered, select room, then courses';
		END IF;
	END IF;

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.selqresidence(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: selqroom(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION selqroom(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mystr 			VARCHAR(120);
	myrec 			RECORD;
	myqstud 		int;
	v_qresidenceid	int;
	myroom 			int;
BEGIN
	myqstud := getcurrqstudentid($2);

	SELECT qresidenceid, roomnumber INTO v_qresidenceid, myroom
	FROM qresidenceroom
	WHERE (roomid = $1);

	SELECT qstudentid, finalised, qresidenceid INTO myrec
	FROM qstudents
	WHERE (qstudentid = myqstud);

	IF (myrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for the quarter first.';
	ELSIF (myrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSIF (v_qresidenceid <> myrec.qresidenceid) THEN
		RAISE EXCEPTION 'Select a room for the residence selected';
	ELSE
		UPDATE qstudents SET roomnumber = myroom WHERE qstudentid = myqstud;
		mystr := 'Room Selected';
	END IF;

	RETURN mystr; 
END;
$_$;


ALTER FUNCTION public.selqroom(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: selqsabathclass(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION selqsabathclass(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	mystr VARCHAR(120);
	myrec RECORD;
	myqstud int;
	myclass int;
BEGIN
	myqstud := getcurrqstudentid($2);
	myclass := CAST($1 AS integer);

	SELECT INTO myrec qstudentid, finalised FROM qstudents
	WHERE (qstudentid = myqstud);

	IF (myrec.qstudentid IS NULL) THEN
		RAISE EXCEPTION 'Please register for the quarter first.';
	ELSIF (myrec.finalised = true) THEN
		RAISE EXCEPTION 'You have closed the selection.';
	ELSE
		UPDATE qstudents SET sabathclassid = myclass, chaplainapproval = true WHERE qstudentid = myqstud;
		mystr := 'Sabath Class Selected';
	END IF;

	RETURN mystr; 
END;
$_$;


ALTER FUNCTION public.selqsabathclass(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: setconfirmation(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION setconfirmation(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_qstudentid	integer;
	msg				varchar(240);
BEGIN

	SELECT qstudentid INTO v_qstudentid
	FROM qstudents
	WHERE (qstudentid = CAST($1 as int)) AND (finalised = true) AND (studentdeanapproval = true) AND (finaceapproval = true) AND (majorapproval = true);
	
	IF(v_qstudentid is null)THEN
		RAISE EXCEPTION 'You have not gotten all approvals check on your status.';
	ELSE
		UPDATE qstudents SET approved = true
		WHERE (qstudentid = CAST($1 as int)) AND (finalised = true) AND (studentdeanapproval = true) AND (finaceapproval = true) AND (majorapproval = true);
		msg := 'You are now fully registered<br>You can save or print your registration form';
	END IF;

 RETURN msg;

END;
$_$;


ALTER FUNCTION public.setconfirmation(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: sunposted(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION sunposted(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	INSERT INTO qposting_logs (sys_audit_trail_id, posted_type_id, qstudentid, narrative,
			phours, punitcharge, plabcharge, pclinical_charge, pexamfee, pcourseextracharge, 
			pfeescharge, presidencecharge, ptotalfees)
		SELECT CAST($4 as int), 1, qstudents.qstudentid, 
		(studentquarterview.sublevelid || ',' || studentquarterview.residenceid), 
		studentquarterview.hours, studentquarterview.unitcharge, 
		studentquarterview.labcharge, studentquarterview.clinical_charge, studentquarterview.examfee, 
		studentquarterview.courseextracharge, studentquarterview.feescharge, studentquarterview.residencecharge, 
		studentquarterview.totalfees
	FROM studentquarterview INNER JOIN qstudents ON studentquarterview.qstudentid = qstudents.qstudentid
	WHERE (charge_id = CAST($1 as int)) AND (qstudents.finaceapproval = true) AND (qstudents.record_posted = false)
	ORDER BY qstudents.qstudentid;

	UPDATE qstudents SET record_posted = true 
	WHERE (charge_id = CAST($1 as int)) AND (finaceapproval = true) AND (record_posted = false);

	UPDATE charges SET sun_posted = true
	WHERE (charge_id = CAST($1 as int));
	
	SELECT text 'Done' AS mylabel;
$_$;


ALTER FUNCTION public.sunposted(character varying, character varying, character varying, character varying) OWNER TO postgres;

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
	min_level	Integer;
	mysql		varchar(240);
	msg 		varchar(120);
BEGIN
	app_id := CAST($1 as int);
	SELECT approvals.org_id, approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id, 
		approvals.approval_level, approvals.review_advice,
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

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false) AND (workflow_phases.notice = false);

		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved')
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;

			INSERT INTO sys_emailed (org_id, table_id, table_name, email_type)
			VALUES (reca.org_id, reca.table_id, 'vw_workflow_approvals', 1);

			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level >= reca.approval_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level <= min_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
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
-- Name: upd_qcourses(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_qcourses() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM levellocations
	WHERE (levellocationid = NEW.levellocationid);

	IF(TG_OP = 'UPDATE')THEN
		IF(OLD.gradesubmited = false) AND (NEW.gradesubmited = true)THEN
			NEW.submit_grades := true;
			NEW.approved_grades := true;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_qcourses() OWNER TO postgres;

--
-- Name: upd_sun_balance(character varying, character varying, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_sun_balance(character varying, character varying, double precision) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	srec RECORD;
	examBalance real;
	mystr VARCHAR(120);
BEGIN
	
	SELECT qstudents.qstudentid, qstudents.quarterid, qstudents.exam_clear, 
		charges.session_active, charges.session_closed, charges.exam_balances, charges.sun_posted
	INTO srec
	FROM studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid
		INNER JOIN charges ON qstudents.charge_id = charges.charge_id
	WHERE (studentdegrees.completed = false) AND (studentdegrees.studentid = $1) 
		AND (charges.session_active = true);

	IF (srec.qstudentid is null) THEN
		UPDATE students SET balance_time = now(), curr_balance = $3
		WHERE (studentid = $1);

		INSERT INTO sun_audits (studentid, update_type, update_time, sun_balance, user_ip)
		VALUES ($1, 'student', now(), $3, $2);
	ELSIF (srec.session_closed = false) THEN
		IF (srec.exam_balances = true) THEN
			SELECT exam_line INTO examBalance
			FROM quarters
			WHERE (quarterid = srec.quarterid);

			IF(examBalance is null) THEN
				examBalance := 0;
			END IF;

			--- Evaluate the exam balance and approve for exam balance
			IF (srec.exam_clear = false) AND ($3 <= examBalance) THEN
				UPDATE qstudents SET exam_clear = true, exam_clear_date = now(), exam_clear_balance = $3
				WHERE (qstudentid = srec.qstudentid);

				INSERT INTO sun_audits (studentid, update_type, update_time, sun_balance, user_ip)
				VALUES ($1, 'exam', now(), $3, $2);
			END IF;
		ELSE
			UPDATE qstudents SET balance_time = now(), currbalance = $3
			WHERE (qstudentid = srec.qstudentid);
			UPDATE students SET balance_time = now(), curr_balance = $3
			WHERE (studentid = $1);

			INSERT INTO sun_audits (studentid, update_type, update_time, sun_balance, user_ip)
			VALUES ($1, 'balance', now(), $3, $2);
		END IF;
	END IF;

	mystr := 'Balance updated';

    RETURN mystr;
END;
$_$;


ALTER FUNCTION public.upd_sun_balance(character varying, character varying, double precision) OWNER TO postgres;

--
-- Name: updapprovefinance(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updapprovefinance(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE qstudents SET finaceapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate)
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Finance Approval Done' as reply;
$_$;


ALTER FUNCTION public.updapprovefinance(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updapprovegrade(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updapprovegrade(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_qgradeid		integer;
	msg				varchar(240);
BEGIN
	SELECT qgradeid INTO v_qgradeid
	FROM qgrades
	WHERE (qcourseid = CAST($1 as int)) AND ((lecture_marks + lecture_cat_mark) > 100);

	IF(v_qgradeid is null)THEN
		UPDATE qgrades SET final_marks = lecture_marks + lecture_cat_mark, gradeid = lecture_gradeid,
			sys_audit_trail_id = CAST($4 as int)
		WHERE (qcourseid = CAST($1 as int));

		UPDATE qcourses SET approved_grades = true, approve_date = now(), gradesubmited = true
		WHERE (qcourseid = CAST($1 as int));

		msg := 'Grade Submitted to Registry Correctly';
	ELSE
		msg := 'Some marks add up to more than 100';
		RAISE EXCEPTION 'Some marks add up to more than 100';
	END IF;
	
	RETURN msg;
END;
$_$;


ALTER FUNCTION public.updapprovegrade(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updatemajorapproval(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updatemajorapproval(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE qstudents SET majorapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate) 
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Major Approval Done' as reply;
$_$;


ALTER FUNCTION public.updatemajorapproval(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updcomputegrade(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updcomputegrade(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_qgradeid		integer;
	msg				varchar(240);
BEGIN
	SELECT qgradeid INTO v_qgradeid
	FROM qgrades
	WHERE (qcourseid = CAST($1 as int)) AND ((lecture_marks + lecture_cat_mark) > 100);

	IF(v_qgradeid is null)THEN
		UPDATE qgrades SET lecture_gradeid = getdbgradeid(round((lecture_marks + lecture_cat_mark)::double precision)::integer)
		WHERE (qcourseid = CAST($1 as int));

		msg := 'Lecturer Grade Computed Correctly';
	ELSE
		msg := 'Some marks add up to more than 100';
		RAISE EXCEPTION 'Some marks add up to more than 100';
	END IF;
	
	RETURN msg;
END;
$_$;


ALTER FUNCTION public.updcomputegrade(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updoverloadapproval(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updoverloadapproval(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE sql
    AS $_$
	UPDATE qstudents SET overloadhours = 24, overloadapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate)
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Overload Approval Done' as reply;
$_$;


ALTER FUNCTION public.updoverloadapproval(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updqcoursegrade(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updqcoursegrade(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_qgradeid		integer;
	msg				varchar(240);
BEGIN
	SELECT qgradeid INTO v_qgradeid
	FROM qgrades
	WHERE (qcourseid = CAST($1 as int)) AND ((lecture_marks + lecture_cat_mark) > 100);

	IF(v_qgradeid is null)THEN
		UPDATE qcourses SET submit_grades = true, submit_date = now()
		WHERE (qcourseid = CAST($1 as int));

		msg := 'Grade Submitted to Department Correctly';
	ELSE
		msg := 'Some marks add up to more than 100';
		RAISE EXCEPTION 'Some marks add up to more than 100';
	END IF;
	
	RETURN msg;
END;
$_$;


ALTER FUNCTION public.updqcoursegrade(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updqcourseitems(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updqcourseitems() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec RECORD;
BEGIN
	FOR myrec IN SELECT * FROM qgrades WHERE qcourseid = NEW.qcourseid LOOP
		INSERT INTO qcoursemarks (qgradeid, qcourseitemid) VALUES (myrec.qgradeid, NEW.qcourseitemid);
	END LOOP;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.updqcourseitems() OWNER TO postgres;

--
-- Name: updqgrades(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updqgrades() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id			integer;
	v_entity_name 		varchar(50);
	wRate 				real;
BEGIN

	IF (OLD.gradeid = 'NG') and (OLD.gradeid <> 'W') and (NEW.gradeid = 'W') THEN
		RAISE EXCEPTION 'Cannot withdraw a course that is already graded.';
	END IF;

	IF (OLD.gradeid = 'NG') and (OLD.gradeid <> 'AW') and (NEW.gradeid = 'AW') THEN
		RAISE EXCEPTION 'Cannot withdraw a course that is already graded.';
	END IF;

	IF (OLD.gradeid <> 'NG') and (NEW.gradeid = 'NG') THEN
		RAISE EXCEPTION 'Cannot revrese a grade.';
	END IF;

	IF (OLD.gradeid = 'NG') and (OLD.gradeid <> 'W') and (NEW.gradeid = 'W') THEN
		NEW.withdrawdate := current_date;
		NEW.withdraw_rate := calcWithdrawRate();
	END IF;

	IF (OLD.gradeid = 'NG') and (OLD.gradeid <> 'AW') and (NEW.gradeid = 'AW') THEN
		NEW.withdrawdate := current_date;
		NEW.withdraw_rate := calcWithdrawRate();
	END IF;

	IF (OLD.gradeid <> NEW.gradeid) THEN
		SELECT entitys.entity_id, entitys.entity_name INTO v_entity_id, v_entity_name
		FROM sys_audit_trail INNER JOIN entitys ON trim(upper(sys_audit_trail.user_id)) = CAST(entitys.entity_id as varchar)
		WHERE (sys_audit_trail.sys_audit_trail_id = NEW.sys_audit_trail_id);

		IF(v_entity_id is null) THEN
			SELECT entitys.entity_id, entitys.entity_name INTO v_entity_id, v_entity_name
			FROM sys_audit_trail INNER JOIN entitys ON trim(upper(sys_audit_trail.user_id)) = trim(upper(entitys.user_name))
			WHERE (sys_audit_trail.sys_audit_trail_id = NEW.sys_audit_trail_id);
		END IF;

		INSERT INTO gradechangelist (qgradeid, changedby, entity_id, oldgrade, newgrade, changedate, clientip) 
		VALUES (NEW.qgradeid, v_entity_name, v_entity_id, OLD.gradeid, NEW.gradeid, now(), CAST(inet_client_addr() as varchar));
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.updqgrades() OWNER TO postgres;

--
-- Name: updqstudents(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updqstudents() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec RECORD;
	mystr VARCHAR(120);
BEGIN

	IF (OLD.finaceapproval = false) AND (NEW.finaceapproval = true) THEN
		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (NEW.qstudentid, current_user, 'Finance', now(), cast(inet_client_addr() as varchar));
	END IF;
	
	IF (OLD.exam_clear = false) AND (NEW.exam_clear = true) THEN
		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (NEW.qstudentid, current_user, 'Exam Clear', now(), cast(inet_client_addr() as varchar));
	END IF;

	IF (OLD.finaceapproval = true) AND (NEW.finaceapproval = false) THEN
		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (NEW.qstudentid, current_user, 'Finance Open', now(), cast(inet_client_addr() as varchar));
	END IF;
	
	IF (OLD.studentdeanapproval = false) AND (NEW.studentdeanapproval = true) THEN
		INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate, clientid) 
		VALUES (NEW.qstudentid, current_user, 'Dean', now(), cast(inet_client_addr() as varchar));
	END IF;

	IF (OLD.withdraw = false) AND (NEW.withdraw = true) THEN
		UPDATE qgrades SET gradeid = 'W' WHERE qstudentID = NEW.qstudentID;
	END IF;

	IF (OLD.ac_withdraw = false) AND (NEW.ac_withdraw = true) THEN
		UPDATE qgrades SET gradeid = 'AW' WHERE qstudentID = NEW.qstudentID;
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.updqstudents() OWNER TO postgres;

--
-- Name: updstudentadd(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updstudentadd() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec 	RECORD;
	priadd 	RECORD;
	gudadd 	RECORD;
BEGIN
	FOR myrec IN SELECT registrations.registrationid, registrations.existingid FROM registrations 
	WHERE (registrations.existingid is not null) LOOP

		SELECT INTO priadd regcontacts.address, regcontacts.zipcode, regcontacts.town, regcontacts.countrycodeid,
			regcontacts.telephone, regcontacts.email
		FROM contacttypes INNER JOIN regcontacts ON contacttypes.contacttypeid = regcontacts.contacttypeid
		WHERE (contacttypes.primarycontact = true) AND (regcontacts.registrationid = myrec.registrationid);
	
		IF (priadd.address is not null) THEN
			UPDATE students SET address = priadd.address, zipcode = priadd.zipcode, town = priadd.town, 
				countrycodeid = priadd.countrycodeid, telno = priadd.telephone, email = priadd.email
			WHERE (address is null) AND (studentid = myrec.existingid);
		END IF;
	
		SELECT INTO gudadd regcontacts.regcontactname, regcontacts.address, regcontacts.zipcode, regcontacts.town,
			regcontacts.countrycodeid, regcontacts.telephone, regcontacts.email
		FROM regcontacts
		WHERE (regcontacts.guardiancontact = true) AND (regcontacts.registrationid = myrec.registrationid);
	
		IF (gudadd.regcontactname is not null) THEN
			UPDATE students SET guardianname = gudadd.regcontactname, gaddress = gudadd.address,
				gzipcode = gudadd.zipcode, gtown = gudadd.town, gcountrycodeid = gudadd.countrycodeid,
				gtelno = gudadd.telephone, gemail = gudadd.email
			WHERE (guardianname is null) AND (studentid = myrec.existingid);
		END IF;
		
	END LOOP;

	 RETURN 'Done';
END;
$$;


ALTER FUNCTION public.updstudentadd() OWNER TO postgres;

--
-- Name: updstudentadd(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updstudentadd(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	mystr VARCHAR(50);
BEGIN

	mystr := updStudentAdd();

	UPDATE students SET countrycodeid = 'KE' WHERE countrycodeid is null;
	UPDATE students SET gcountrycodeid = 'KE' WHERE gcountrycodeid is null;
	
	RETURN mystr;
END;
$$;


ALTER FUNCTION public.updstudentadd(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: updstudents(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION updstudents() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (OLD.fullbursary = false) and (NEW.fullbursary = true) THEN
		INSERT INTO sys_audit_trail (user_id, table_name, record_id, change_type, narrative)
		VALUES (current_user, 'students', NEW.studentid, 'approve', 'Approve full Bursary');
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.updstudents() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: quarters; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE quarters (
    quarterid character varying(12) NOT NULL,
    qstart date NOT NULL,
    qlatereg date DEFAULT ('now'::text)::date NOT NULL,
    qlastdrop date NOT NULL,
    qend date NOT NULL,
    active boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    quarter_name character varying(32),
    qlatechange double precision DEFAULT 0 NOT NULL,
    chalengerate double precision DEFAULT 75 NOT NULL,
    feesline double precision DEFAULT 70 NOT NULL,
    resline double precision DEFAULT 70 NOT NULL,
    minimal_fees double precision DEFAULT 10000 NOT NULL,
    exam_line double precision DEFAULT 10000 NOT NULL,
    details text
);


ALTER TABLE public.quarters OWNER TO postgres;

--
-- Name: quarterview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW quarterview AS
 SELECT quarters.quarterid,
    quarters.qstart,
    quarters.qlatereg,
    quarters.qlatechange,
    quarters.qlastdrop,
    quarters.qend,
    quarters.active,
    quarters.chalengerate,
    quarters.feesline,
    quarters.resline,
    quarters.closed,
    quarters.quarter_name,
    quarters.minimal_fees,
    quarters.details,
    "substring"((quarters.quarterid)::text, 1, 9) AS quarteryear,
    btrim("substring"((quarters.quarterid)::text, 11, 2)) AS quarter
   FROM quarters
  ORDER BY quarters.quarterid DESC;


ALTER TABLE public.quarterview OWNER TO postgres;

--
-- Name: activequarter; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW activequarter AS
 SELECT quarterview.quarterid,
    quarterview.quarteryear,
    quarterview.quarter,
    quarterview.qstart,
    quarterview.qlatereg,
    quarterview.qlatechange,
    quarterview.closed,
    quarterview.quarter_name,
    quarterview.qlastdrop,
    quarterview.qend,
    quarterview.active,
    quarterview.chalengerate,
    quarterview.feesline,
    quarterview.resline,
    quarterview.minimal_fees,
    quarterview.details
   FROM quarterview
  WHERE (quarterview.active = true);


ALTER TABLE public.activequarter OWNER TO postgres;

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
-- Name: application_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE application_forms (
    application_form_id integer NOT NULL,
    markid integer,
    entity_id integer,
    degreeid character varying(12),
    majorid character varying(12),
    sublevelid character varying(12),
    county_id integer,
    org_id integer,
    entry_form_id integer,
    session_id character varying(12),
    email character varying(120),
    entrypass character varying(32) DEFAULT md5('enter'::text) NOT NULL,
    firstpass character varying(32) DEFAULT first_password() NOT NULL,
    existingid character varying(12),
    scheduledate date DEFAULT ('now'::text)::date NOT NULL,
    applicationdate date DEFAULT ('now'::text)::date NOT NULL,
    accepted boolean DEFAULT false NOT NULL,
    premajor boolean DEFAULT false NOT NULL,
    homeaddress character varying(120),
    phonenumber character varying(50),
    apply_trimester character varying(32),
    reported boolean DEFAULT false NOT NULL,
    reporteddate date,
    denominationid character varying(12),
    mname character varying(50),
    fname character varying(50),
    fdenominationid character varying(12),
    mdenominationid character varying(12),
    foccupation character varying(50),
    fnationalityid character(2),
    moccupation character varying(50),
    mnationalityid character(2),
    parentchurch boolean,
    parentemployer character varying(120),
    birthdate date NOT NULL,
    baptismdate date,
    lastname character varying(50) NOT NULL,
    firstname character varying(50) NOT NULL,
    middlename character varying(50),
    sex character varying(12),
    maritalstatus character varying(12),
    nationalityid character(2),
    citizenshipid character(2),
    residenceid character(2),
    firstlanguage character varying(50),
    otherlanguages character varying(120),
    churchname character varying(50),
    churcharea character varying(50),
    churchaddress text,
    handicap character varying(120),
    personalhealth character varying(50),
    smoke boolean,
    drink boolean,
    drugs boolean,
    hsmoke boolean,
    hdrink boolean,
    hdrugs boolean,
    attendedprimary character varying(50),
    attendedsecondary character varying(50),
    expelled boolean,
    previousrecord character varying(50),
    workexperience character varying(50),
    employername character varying(50),
    postion character varying(50),
    attendedueab boolean DEFAULT false NOT NULL,
    attendeddate date,
    dateemployed date,
    campusresidence character varying(50),
    details text
);


ALTER TABLE public.application_forms OWNER TO postgres;

--
-- Name: application_forms_application_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE application_forms_application_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.application_forms_application_form_id_seq OWNER TO postgres;

--
-- Name: application_forms_application_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE application_forms_application_form_id_seq OWNED BY application_forms.application_form_id;


--
-- Name: applications; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE applications (
    application_id integer NOT NULL,
    offer_id integer,
    entity_id integer,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    applicant_comments text,
    review text
);


ALTER TABLE public.applications OWNER TO postgres;

--
-- Name: applications_application_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE applications_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.applications_application_id_seq OWNER TO postgres;

--
-- Name: applications_application_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE applications_application_id_seq OWNED BY applications.application_id;


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
-- Name: approvallist; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approvallist (
    approvalid integer NOT NULL,
    qstudentid integer NOT NULL,
    approvedby character varying(50),
    approvaltype character varying(25),
    approvedate timestamp without time zone DEFAULT now(),
    clientid character varying(25)
);


ALTER TABLE public.approvallist OWNER TO postgres;

--
-- Name: approvallist_approvalid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approvallist_approvalid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approvallist_approvalid_seq OWNER TO postgres;

--
-- Name: approvallist_approvalid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approvallist_approvalid_seq OWNED BY approvallist.approvalid;


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
-- Name: assets; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE assets (
    assetid integer NOT NULL,
    org_id integer,
    assetname character varying(50) NOT NULL,
    building character varying(50),
    location character varying(50),
    capacity integer NOT NULL,
    details text
);


ALTER TABLE public.assets OWNER TO postgres;

--
-- Name: assets_assetid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE assets_assetid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.assets_assetid_seq OWNER TO postgres;

--
-- Name: assets_assetid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE assets_assetid_seq OWNED BY assets.assetid;


--
-- Name: bulleting; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bulleting (
    bulletingid integer NOT NULL,
    bulletingname character varying(50),
    startingquarter character varying(12),
    endingquarter character varying(12),
    iscurrent boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.bulleting OWNER TO postgres;

--
-- Name: bulleting_bulletingid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bulleting_bulletingid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bulleting_bulletingid_seq OWNER TO postgres;

--
-- Name: bulleting_bulletingid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bulleting_bulletingid_seq OWNED BY bulleting.bulletingid;


--
-- Name: charges; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE charges (
    charge_id integer NOT NULL,
    quarterid character varying(12) NOT NULL,
    sublevelid character varying(12) NOT NULL,
    org_id integer,
    session_active boolean DEFAULT false NOT NULL,
    session_closed boolean DEFAULT false NOT NULL,
    exam_balances boolean DEFAULT false NOT NULL,
    sun_posted boolean DEFAULT false NOT NULL,
    late_fee_date date NOT NULL,
    unit_charge double precision DEFAULT 2500 NOT NULL,
    lab_charges double precision DEFAULT 2000 NOT NULL,
    exam_fees double precision DEFAULT 500 NOT NULL,
    general_fees double precision DEFAULT 7500 NOT NULL,
    residence_stay double precision DEFAULT 100 NOT NULL,
    currency character varying(32) DEFAULT 'KES'::character varying NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL,
    narrative character varying(120)
);


ALTER TABLE public.charges OWNER TO postgres;

--
-- Name: charges_charge_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE charges_charge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.charges_charge_id_seq OWNER TO postgres;

--
-- Name: charges_charge_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE charges_charge_id_seq OWNED BY charges.charge_id;


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
-- Name: contacttypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contacttypes (
    contacttypeid integer NOT NULL,
    contacttypename character varying(50),
    primarycontact boolean DEFAULT false NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.contacttypes OWNER TO postgres;

--
-- Name: contacttypes_contacttypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contacttypes_contacttypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacttypes_contacttypeid_seq OWNER TO postgres;

--
-- Name: contacttypes_contacttypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contacttypes_contacttypeid_seq OWNED BY contacttypes.contacttypeid;


--
-- Name: contenttypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contenttypes (
    contenttypeid integer NOT NULL,
    contenttypename character varying(50) NOT NULL,
    elective boolean DEFAULT false NOT NULL,
    prerequisite boolean DEFAULT false NOT NULL,
    premajor boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.contenttypes OWNER TO postgres;

--
-- Name: contenttypes_contenttypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contenttypes_contenttypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contenttypes_contenttypeid_seq OWNER TO postgres;

--
-- Name: contenttypes_contenttypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contenttypes_contenttypeid_seq OWNED BY contenttypes.contenttypeid;


--
-- Name: continents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE continents (
    continentid character(2) NOT NULL,
    continentname character varying(120)
);


ALTER TABLE public.continents OWNER TO postgres;

--
-- Name: courses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE courses (
    courseid character varying(12) NOT NULL,
    departmentid character varying(12) NOT NULL,
    degreelevelid character varying(12) NOT NULL,
    coursetypeid integer NOT NULL,
    coursetitle character varying(120) NOT NULL,
    credithours double precision NOT NULL,
    maxcredit double precision DEFAULT 5 NOT NULL,
    iscurrent boolean DEFAULT true NOT NULL,
    nogpa boolean DEFAULT false NOT NULL,
    norepeats boolean DEFAULT false NOT NULL,
    labcourse boolean DEFAULT false NOT NULL,
    examinable boolean DEFAULT false NOT NULL,
    clinical_fee double precision DEFAULT 0 NOT NULL,
    extracharge double precision DEFAULT 0 NOT NULL,
    yeartaken integer DEFAULT 1 NOT NULL,
    mathplacement integer DEFAULT 0 NOT NULL,
    englishplacement integer DEFAULT 0 NOT NULL,
    kiswahiliplacement integer DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.courses OWNER TO postgres;

--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE departments (
    departmentid character varying(12) NOT NULL,
    schoolid character varying(12) NOT NULL,
    departmentname character varying(120) NOT NULL,
    philosopy text,
    vision text,
    mission text,
    objectives text,
    exposures text,
    oppotunities text,
    details text
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: schools; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE schools (
    schoolid character varying(12) NOT NULL,
    schoolname character varying(50) NOT NULL,
    philosopy text,
    vision text,
    mission text,
    objectives text,
    details text
);


ALTER TABLE public.schools OWNER TO postgres;

--
-- Name: departmentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW departmentview AS
 SELECT schools.schoolid,
    schools.schoolname,
    departments.departmentid,
    departments.departmentname,
    departments.philosopy,
    departments.vision,
    departments.mission,
    departments.objectives,
    departments.exposures,
    departments.oppotunities,
    departments.details
   FROM (schools
     JOIN departments ON (((schools.schoolid)::text = (departments.schoolid)::text)))
  ORDER BY departments.schoolid;


ALTER TABLE public.departmentview OWNER TO postgres;

--
-- Name: grades; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE grades (
    gradeid character varying(2) NOT NULL,
    gradeweight double precision DEFAULT 0 NOT NULL,
    minrange integer,
    maxrange integer,
    gpacount boolean DEFAULT true NOT NULL,
    narrative character varying(240),
    details text
);


ALTER TABLE public.grades OWNER TO postgres;

--
-- Name: majorcontents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE majorcontents (
    majorcontentid integer NOT NULL,
    majorid character varying(12) NOT NULL,
    courseid character varying(12) NOT NULL,
    contenttypeid integer NOT NULL,
    gradeid character varying(2) NOT NULL,
    bulletingid integer,
    minor boolean DEFAULT false NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.majorcontents OWNER TO postgres;

--
-- Name: majors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE majors (
    majorid character varying(12) NOT NULL,
    departmentid character varying(12) NOT NULL,
    majorname character varying(75) NOT NULL,
    major boolean DEFAULT false NOT NULL,
    minor boolean DEFAULT false NOT NULL,
    fullcredit integer DEFAULT 200 NOT NULL,
    electivecredit integer NOT NULL,
    minorelectivecredit integer NOT NULL,
    majorminimal real,
    minorminimum real,
    coreminimum real,
    details text
);


ALTER TABLE public.majors OWNER TO postgres;

--
-- Name: majorview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW majorview AS
 SELECT departmentview.schoolid,
    departmentview.schoolname,
    departmentview.departmentid,
    departmentview.departmentname,
    majors.majorid,
    majors.majorname,
    majors.electivecredit,
    majors.majorminimal,
    majors.minorminimum,
    majors.coreminimum,
    majors.major,
    majors.minor,
    majors.details
   FROM (departmentview
     JOIN majors ON (((departmentview.departmentid)::text = (majors.departmentid)::text)));


ALTER TABLE public.majorview OWNER TO postgres;

--
-- Name: majorcontentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW majorcontentview AS
 SELECT majorview.schoolid,
    majorview.departmentid,
    majorview.departmentname,
    majorview.majorid,
    majorview.majorname,
    majorview.electivecredit,
    courses.courseid,
    courses.coursetitle,
    courses.credithours,
    courses.nogpa,
    courses.yeartaken,
    courses.details AS course_details,
    contenttypes.contenttypeid,
    contenttypes.contenttypename,
    contenttypes.elective,
    contenttypes.prerequisite,
    contenttypes.premajor,
    majorcontents.majorcontentid,
    majorcontents.minor,
    majorcontents.gradeid,
    majorcontents.narrative,
    bulleting.bulletingid,
    bulleting.bulletingname,
    bulleting.startingquarter,
    bulleting.endingquarter,
    bulleting.iscurrent
   FROM ((((majorview
     JOIN majorcontents ON (((majorview.majorid)::text = (majorcontents.majorid)::text)))
     JOIN courses ON (((majorcontents.courseid)::text = (courses.courseid)::text)))
     JOIN contenttypes ON ((majorcontents.contenttypeid = contenttypes.contenttypeid)))
     JOIN bulleting ON ((majorcontents.bulletingid = bulleting.bulletingid)));


ALTER TABLE public.majorcontentview OWNER TO postgres;

--
-- Name: majoroptcontents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE majoroptcontents (
    majoroptcontentid integer NOT NULL,
    majoroptionid integer NOT NULL,
    courseid character varying(12) NOT NULL,
    contenttypeid integer NOT NULL,
    gradeid character varying(2) NOT NULL,
    minor boolean DEFAULT false NOT NULL,
    bulletingid integer NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.majoroptcontents OWNER TO postgres;

--
-- Name: majoroptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE majoroptions (
    majoroptionid integer NOT NULL,
    majorid character varying(12),
    majoroptionname character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.majoroptions OWNER TO postgres;

--
-- Name: majoroptcontentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW majoroptcontentview AS
 SELECT majoroptions.majoroptionid,
    majoroptions.majorid,
    majoroptions.majoroptionname,
    courses.courseid,
    courses.coursetitle,
    courses.credithours,
    courses.nogpa,
    courses.yeartaken,
    courses.details AS course_details,
    contenttypes.contenttypeid,
    contenttypes.contenttypename,
    contenttypes.elective,
    contenttypes.prerequisite,
    contenttypes.premajor,
    majoroptcontents.majoroptcontentid,
    majoroptcontents.minor,
    majoroptcontents.gradeid,
    majoroptcontents.narrative,
    bulleting.bulletingid,
    bulleting.bulletingname,
    bulleting.startingquarter,
    bulleting.endingquarter,
    bulleting.iscurrent
   FROM ((((majoroptions
     JOIN majoroptcontents ON ((majoroptions.majoroptionid = majoroptcontents.majoroptionid)))
     JOIN courses ON (((majoroptcontents.courseid)::text = (courses.courseid)::text)))
     JOIN contenttypes ON ((majoroptcontents.contenttypeid = contenttypes.contenttypeid)))
     JOIN bulleting ON ((majoroptcontents.bulletingid = bulleting.bulletingid)));


ALTER TABLE public.majoroptcontentview OWNER TO postgres;

--
-- Name: studentdegrees; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE studentdegrees (
    studentdegreeid integer NOT NULL,
    degreeid character varying(12) NOT NULL,
    sublevelid character varying(12) NOT NULL,
    studentid character varying(12) NOT NULL,
    bulletingid integer NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    started date,
    cleared boolean DEFAULT false NOT NULL,
    clearedate date,
    graduated boolean DEFAULT false NOT NULL,
    graduatedate date,
    dropout boolean DEFAULT false NOT NULL,
    transferin boolean DEFAULT false NOT NULL,
    transferout boolean DEFAULT false NOT NULL,
    mathplacement integer DEFAULT 0 NOT NULL,
    englishplacement integer DEFAULT 0 NOT NULL,
    kiswahiliplacement integer DEFAULT 0 NOT NULL,
    transcripted boolean DEFAULT false NOT NULL,
    transcript boolean DEFAULT false NOT NULL,
    transcriptdate date,
    details text
);


ALTER TABLE public.studentdegrees OWNER TO postgres;

--
-- Name: studentmajors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE studentmajors (
    studentmajorid integer NOT NULL,
    studentdegreeid integer NOT NULL,
    majorid character varying(12) NOT NULL,
    majoroptionid integer,
    major boolean DEFAULT false NOT NULL,
    primarymajor boolean DEFAULT false NOT NULL,
    nondegree boolean DEFAULT false NOT NULL,
    premajor boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.studentmajors OWNER TO postgres;

--
-- Name: corecourseoutline; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW corecourseoutline AS
 SELECT 1 AS orderid,
    studentdegrees.studentid,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    majors.majorname AS description,
    majorcontentview.contenttypeid,
    majorcontentview.contenttypename,
    majorcontentview.courseid,
    majorcontentview.coursetitle,
    majorcontentview.minor,
    majorcontentview.elective,
    majorcontentview.credithours,
    majorcontentview.nogpa,
    majorcontentview.gradeid,
    grades.gradeweight
   FROM ((((majors
     JOIN majorcontentview ON (((majors.majorid)::text = (majorcontentview.majorid)::text)))
     JOIN studentmajors ON (((majorcontentview.majorid)::text = (studentmajors.majorid)::text)))
     JOIN studentdegrees ON (((studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majorcontentview.bulletingid = studentdegrees.bulletingid))))
     JOIN grades ON (((majorcontentview.gradeid)::text = (grades.gradeid)::text)))
  WHERE ((((studentmajors.major = true) AND (((NOT studentmajors.premajor) AND majorcontentview.premajor) = false)) AND (((NOT studentmajors.nondegree) AND majorcontentview.prerequisite) = false)) AND (studentdegrees.dropout = false))
UNION
 SELECT 2 AS orderid,
    studentdegrees.studentid,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    majoroptions.majoroptionname AS description,
    majoroptcontentview.contenttypeid,
    majoroptcontentview.contenttypename,
    majoroptcontentview.courseid,
    majoroptcontentview.coursetitle,
    majoroptcontentview.minor,
    majoroptcontentview.elective,
    majoroptcontentview.credithours,
    majoroptcontentview.nogpa,
    majoroptcontentview.gradeid,
    grades.gradeweight
   FROM ((((majoroptions
     JOIN majoroptcontentview ON ((majoroptions.majoroptionid = majoroptcontentview.majoroptionid)))
     JOIN studentmajors ON ((majoroptcontentview.majoroptionid = studentmajors.majoroptionid)))
     JOIN studentdegrees ON (((studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majoroptcontentview.bulletingid = studentdegrees.bulletingid))))
     JOIN grades ON (((majoroptcontentview.gradeid)::text = (grades.gradeid)::text)))
  WHERE ((((studentmajors.major = true) AND (((NOT studentmajors.premajor) AND majoroptcontentview.premajor) = false)) AND (((NOT studentmajors.nondegree) AND majoroptcontentview.prerequisite) = false)) AND (studentdegrees.dropout = false));


ALTER TABLE public.corecourseoutline OWNER TO postgres;

--
-- Name: countrys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE countrys (
    countryid character(2) NOT NULL,
    continentid character(2),
    countryname character varying(120)
);


ALTER TABLE public.countrys OWNER TO postgres;

--
-- Name: coursetypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE coursetypes (
    coursetypeid integer NOT NULL,
    coursetypename character varying(50),
    details text
);


ALTER TABLE public.coursetypes OWNER TO postgres;

--
-- Name: degreelevels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE degreelevels (
    degreelevelid character varying(12) NOT NULL,
    degreelevelname character varying(50) NOT NULL,
    freshman integer DEFAULT 46 NOT NULL,
    sophomore integer DEFAULT 94 NOT NULL,
    junior integer DEFAULT 142 NOT NULL,
    senior integer DEFAULT 190 NOT NULL,
    details text
);


ALTER TABLE public.degreelevels OWNER TO postgres;

--
-- Name: courseview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW courseview AS
 SELECT departmentview.schoolid,
    departmentview.schoolname,
    departmentview.departmentid,
    departmentview.departmentname,
    degreelevels.degreelevelid,
    degreelevels.degreelevelname,
    coursetypes.coursetypeid,
    coursetypes.coursetypename,
    courses.courseid,
    courses.coursetitle,
    courses.credithours,
    courses.maxcredit,
    courses.labcourse,
    courses.iscurrent,
    courses.nogpa,
    courses.yeartaken,
    courses.mathplacement,
    courses.englishplacement,
    courses.kiswahiliplacement,
    courses.details
   FROM (((departmentview
     JOIN courses ON (((departmentview.departmentid)::text = (courses.departmentid)::text)))
     JOIN degreelevels ON (((courses.degreelevelid)::text = (degreelevels.degreelevelid)::text)))
     JOIN coursetypes ON ((courses.coursetypeid = coursetypes.coursetypeid)));


ALTER TABLE public.courseview OWNER TO postgres;

--
-- Name: degrees; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE degrees (
    degreeid character varying(12) NOT NULL,
    degreelevelid character varying(12) NOT NULL,
    degreename character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.degrees OWNER TO postgres;

--
-- Name: denominations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE denominations (
    denominationid character varying(12) NOT NULL,
    religionid character varying(12) NOT NULL,
    denominationname character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.denominations OWNER TO postgres;

--
-- Name: religions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE religions (
    religionid character varying(12) NOT NULL,
    religionname character varying(50),
    details text
);


ALTER TABLE public.religions OWNER TO postgres;

--
-- Name: denominationview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW denominationview AS
 SELECT religions.religionid,
    religions.religionname,
    religions.details AS religiondetails,
    denominations.denominationid,
    denominations.denominationname,
    denominations.details AS denominationdetails
   FROM (religions
     JOIN denominations ON (((religions.religionid)::text = (denominations.religionid)::text)));


ALTER TABLE public.denominationview OWNER TO postgres;

--
-- Name: instructors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE instructors (
    instructorid character varying(12) NOT NULL,
    departmentid character varying(12) NOT NULL,
    org_id integer,
    instructorname character varying(50) NOT NULL,
    majoradvisor boolean DEFAULT false NOT NULL,
    department_head boolean DEFAULT false NOT NULL,
    school_dean boolean DEFAULT false NOT NULL,
    pgs_dean boolean DEFAULT false NOT NULL,
    post_office_box character varying(50),
    postal_code character varying(12),
    premises character varying(120),
    street character varying(120),
    town character varying(50),
    sys_country_id character(2),
    phone_number character varying(150),
    mobile character varying(150),
    email character varying(120),
    instructorpass character varying(32) DEFAULT md5('enter'::text) NOT NULL,
    firstpass character varying(32) DEFAULT 'enter'::character varying NOT NULL,
    details text
);


ALTER TABLE public.instructors OWNER TO postgres;

--
-- Name: levellocations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE levellocations (
    levellocationid integer NOT NULL,
    org_id integer,
    levellocationname character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.levellocations OWNER TO postgres;

--
-- Name: qcourses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qcourses (
    qcourseid integer NOT NULL,
    quarterid character varying(12) NOT NULL,
    instructorid character varying(12) NOT NULL,
    courseid character varying(12) NOT NULL,
    levellocationid integer,
    org_id integer,
    classoption character varying(50) DEFAULT 'Main'::character varying NOT NULL,
    maxclass integer NOT NULL,
    session_title character varying(120),
    labcourse boolean DEFAULT false NOT NULL,
    examinable boolean DEFAULT false NOT NULL,
    clinical_fee double precision DEFAULT 0 NOT NULL,
    extracharge double precision DEFAULT 0 NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    intersession boolean DEFAULT false NOT NULL,
    attachement boolean DEFAULT false NOT NULL,
    examsubmited boolean DEFAULT false NOT NULL,
    gradesubmited boolean DEFAULT false NOT NULL,
    submit_grades boolean DEFAULT false NOT NULL,
    submit_date timestamp without time zone,
    approved_grades boolean DEFAULT false NOT NULL,
    approve_date timestamp without time zone,
    departmentchange character varying(240),
    registrychange character varying(240),
    attendance integer,
    oldcourseid character varying(12),
    oldinstructor character varying(50),
    oldcoursetitle character varying(50),
    fullattendance integer,
    details text
);


ALTER TABLE public.qcourses OWNER TO postgres;

--
-- Name: qcourseview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcourseview AS
 SELECT courseview.schoolid,
    courseview.schoolname,
    courseview.departmentid,
    courseview.departmentname,
    courseview.degreelevelid,
    courseview.degreelevelname,
    courseview.coursetypeid,
    courseview.coursetypename,
    courseview.courseid,
    courseview.credithours,
    courseview.maxcredit,
    courseview.iscurrent,
    courseview.nogpa,
    courseview.yeartaken,
    courseview.mathplacement,
    courseview.englishplacement,
    courseview.details,
    qcourses.org_id,
    qcourses.instructorid,
    qcourses.qcourseid,
    qcourses.classoption,
    qcourses.maxclass,
    qcourses.labcourse,
    qcourses.clinical_fee,
    qcourses.extracharge,
    qcourses.approved,
    qcourses.attendance,
    qcourses.oldcourseid,
    qcourses.fullattendance,
    qcourses.attachement,
    qcourses.submit_grades,
    qcourses.submit_date,
    qcourses.approved_grades,
    qcourses.approve_date,
    qcourses.examsubmited,
    qcourses.examinable,
    qcourses.departmentchange,
    qcourses.registrychange,
    qcourses.gradesubmited,
    instructors.majoradvisor,
    instructors.department_head,
    instructors.school_dean,
    instructors.pgs_dean,
        CASE
            WHEN ((qcourses.instructorid)::text = '0'::text) THEN qcourses.oldinstructor
            ELSE instructors.instructorname
        END AS instructorname,
        CASE
            WHEN ((qcourses.instructorid)::text = '0'::text) THEN qcourses.oldcoursetitle
            WHEN (qcourses.session_title IS NOT NULL) THEN qcourses.session_title
            ELSE courseview.coursetitle
        END AS coursetitle,
    quarterview.quarterid,
    quarterview.qstart,
    quarterview.qlatereg,
    quarterview.qlatechange,
    quarterview.qlastdrop,
    quarterview.qend,
    quarterview.active,
    quarterview.chalengerate,
    quarterview.feesline,
    quarterview.resline,
    quarterview.minimal_fees,
    quarterview.closed,
    quarterview.quarter_name,
    quarterview.quarteryear,
    quarterview.quarter,
    levellocations.levellocationid,
    levellocations.levellocationname
   FROM ((((courseview
     JOIN qcourses ON (((courseview.courseid)::text = (qcourses.courseid)::text)))
     JOIN instructors ON (((qcourses.instructorid)::text = (instructors.instructorid)::text)))
     JOIN quarterview ON (((qcourses.quarterid)::text = (quarterview.quarterid)::text)))
     JOIN levellocations ON ((qcourses.levellocationid = levellocations.levellocationid)));


ALTER TABLE public.qcourseview OWNER TO postgres;

--
-- Name: qgrades; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qgrades (
    qgradeid integer NOT NULL,
    qstudentid integer NOT NULL,
    qcourseid integer NOT NULL,
    gradeid character varying(2) DEFAULT 'NG'::character varying NOT NULL,
    optiontimeid integer DEFAULT 0,
    org_id integer,
    sys_audit_trail_id integer,
    hours double precision NOT NULL,
    credit double precision NOT NULL,
    final_marks real,
    selectiondate timestamp without time zone DEFAULT now(),
    approved boolean DEFAULT false NOT NULL,
    approvedate timestamp without time zone,
    askdrop boolean DEFAULT false NOT NULL,
    askdropdate timestamp without time zone,
    dropped boolean DEFAULT false NOT NULL,
    dropdate date,
    repeated boolean DEFAULT false NOT NULL,
    nongpacourse boolean DEFAULT false NOT NULL,
    challengecourse boolean DEFAULT false NOT NULL,
    repeatapproval boolean DEFAULT false NOT NULL,
    request_drop boolean DEFAULT false NOT NULL,
    request_drop_date timestamp without time zone,
    lecture_marks real,
    lecture_cat_mark real DEFAULT 0 NOT NULL,
    lecture_gradeid character varying(2) DEFAULT 'NG'::character varying,
    withdrawdate date,
    withdraw_rate real,
    attendance integer,
    narrative character varying(240),
    record_posted boolean DEFAULT false NOT NULL,
    post_changed boolean DEFAULT false NOT NULL,
    changed_by integer
);


ALTER TABLE public.qgrades OWNER TO postgres;

--
-- Name: qgradeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qgradeview AS
 SELECT qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.degreelevelid,
    qcourseview.degreelevelname,
    qcourseview.coursetypeid,
    qcourseview.coursetypename,
    qcourseview.courseid,
    qcourseview.credithours,
    qcourseview.iscurrent,
    qcourseview.nogpa,
    qcourseview.yeartaken,
    qcourseview.mathplacement AS crs_mathplacement,
    qcourseview.englishplacement AS crs_englishplacement,
    qcourseview.instructorid,
    qcourseview.quarterid,
    qcourseview.qcourseid,
    qcourseview.classoption,
    qcourseview.maxclass,
    qcourseview.labcourse,
    qcourseview.extracharge,
    qcourseview.clinical_fee,
    qcourseview.attendance AS crs_attendance,
    qcourseview.oldcourseid,
    qcourseview.fullattendance,
    qcourseview.instructorname,
    qcourseview.coursetitle,
    qcourseview.attachement,
    qcourseview.examinable,
    qcourseview.submit_grades,
    qcourseview.submit_date,
    qcourseview.approved_grades,
    qcourseview.approve_date,
    qcourseview.departmentchange,
    qcourseview.registrychange,
    qgrades.org_id,
    qgrades.qgradeid,
    qgrades.qstudentid,
    qgrades.hours,
    qgrades.credit,
    qgrades.approved AS crs_approved,
    qgrades.approvedate,
    qgrades.askdrop,
    qgrades.askdropdate,
    qgrades.dropped,
    qgrades.dropdate,
    qgrades.repeated,
    qgrades.attendance,
    qgrades.narrative,
    qgrades.challengecourse,
    qgrades.nongpacourse,
    qgrades.lecture_marks,
    qgrades.lecture_cat_mark,
    qgrades.lecture_gradeid,
    qgrades.request_drop,
    qgrades.request_drop_date,
    qgrades.withdraw_rate AS course_withdraw_rate,
    grades.gradeid,
    grades.gradeweight,
    grades.minrange,
    grades.maxrange,
    grades.gpacount,
    grades.narrative AS gradenarrative,
        CASE qgrades.repeated
            WHEN true THEN (0)::double precision
            ELSE (grades.gradeweight * qgrades.credit)
        END AS gpa,
        CASE
            WHEN ((((((qgrades.gradeid)::text = 'W'::text) OR ((qgrades.gradeid)::text = 'AW'::text)) OR (grades.gpacount = false)) OR (qgrades.repeated = true)) OR (qgrades.nongpacourse = true)) THEN (0)::double precision
            ELSE qgrades.credit
        END AS gpahours,
        CASE
            WHEN (((qgrades.gradeid)::text = 'W'::text) OR ((qgrades.gradeid)::text = 'AW'::text)) THEN (qgrades.hours * qgrades.withdraw_rate)
            ELSE qgrades.hours
        END AS chargehours
   FROM ((qcourseview
     JOIN qgrades ON ((qcourseview.qcourseid = qgrades.qcourseid)))
     JOIN grades ON (((qgrades.gradeid)::text = (grades.gradeid)::text)))
  WHERE (qgrades.dropped = false);


ALTER TABLE public.qgradeview OWNER TO postgres;

--
-- Name: qresidences; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qresidences (
    qresidenceid integer NOT NULL,
    quarterid character varying(12) NOT NULL,
    residenceid character varying(12) NOT NULL,
    org_id integer,
    residenceoption character varying(50) DEFAULT 'Full'::character varying NOT NULL,
    charges double precision NOT NULL,
    active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.qresidences OWNER TO postgres;

--
-- Name: residences; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE residences (
    residenceid character varying(12) NOT NULL,
    levellocationid integer DEFAULT 1 NOT NULL,
    org_id integer,
    residencename character varying(50) NOT NULL,
    capacity integer DEFAULT 120 NOT NULL,
    roomsize integer DEFAULT 4 NOT NULL,
    defaultrate double precision DEFAULT 0 NOT NULL,
    offcampus boolean DEFAULT false NOT NULL,
    sex character varying(1),
    residencedean character varying(50),
    details text
);


ALTER TABLE public.residences OWNER TO postgres;

--
-- Name: qresidenceview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qresidenceview AS
 SELECT residences.residenceid,
    residences.residencename,
    residences.capacity,
    residences.defaultrate,
    residences.offcampus,
    residences.sex,
    residences.residencedean,
    quarterview.quarteryear,
    quarterview.quarter,
    quarterview.active,
    quarterview.closed,
    quarterview.quarter_name,
    qresidences.org_id,
    qresidences.qresidenceid,
    qresidences.quarterid,
    qresidences.residenceoption,
    qresidences.charges,
    qresidences.details
   FROM ((residences
     JOIN qresidences ON (((residences.residenceid)::text = (qresidences.residenceid)::text)))
     JOIN quarterview ON (((qresidences.quarterid)::text = (quarterview.quarterid)::text)));


ALTER TABLE public.qresidenceview OWNER TO postgres;

--
-- Name: qstudents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qstudents (
    qstudentid integer NOT NULL,
    quarterid character varying(12) NOT NULL,
    charge_id integer,
    studentdegreeid integer NOT NULL,
    qresidenceid integer NOT NULL,
    sabathclassid integer,
    org_id integer,
    sys_audit_trail_id integer,
    charges double precision DEFAULT 0 NOT NULL,
    probation boolean DEFAULT false NOT NULL,
    roomnumber integer,
    currbalance real,
    balance_time timestamp without time zone,
    applicationtime timestamp without time zone DEFAULT now() NOT NULL,
    residencerefund double precision DEFAULT 0 NOT NULL,
    feerefund double precision DEFAULT 0 NOT NULL,
    finalised boolean DEFAULT false NOT NULL,
    finaceapproval boolean DEFAULT false NOT NULL,
    majorapproval boolean DEFAULT false NOT NULL,
    chaplainapproval boolean DEFAULT false NOT NULL,
    studentdeanapproval boolean DEFAULT false NOT NULL,
    overloadapproval boolean DEFAULT false NOT NULL,
    departapproval boolean DEFAULT false NOT NULL,
    registrarapproval boolean DEFAULT false NOT NULL,
    overloadhours double precision,
    intersession boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    printed boolean DEFAULT false NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    firstclosetime timestamp without time zone,
    approve_late_fee boolean DEFAULT false NOT NULL,
    late_fee_amount real,
    late_fee_date date,
    record_posted boolean DEFAULT false NOT NULL,
    post_changed boolean DEFAULT false NOT NULL,
    withdraw boolean DEFAULT false NOT NULL,
    ac_withdraw boolean DEFAULT false NOT NULL,
    request_withdraw boolean DEFAULT false NOT NULL,
    request_withdraw_date timestamp without time zone,
    withdraw_date date,
    withdraw_rate real,
    exam_clear boolean DEFAULT false NOT NULL,
    exam_clear_date timestamp without time zone,
    exam_clear_balance real,
    firstinstalment real,
    firstdate date,
    secondinstalment real,
    seconddate date,
    changed_by integer,
    financenarrative text,
    noapproval text,
    details text
);


ALTER TABLE public.qstudents OWNER TO postgres;

--
-- Name: students; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE students (
    studentid character varying(12) NOT NULL,
    schoolid character varying(12) NOT NULL,
    denominationid character varying(12) NOT NULL,
    residenceid character varying(12),
    org_id integer,
    studentname character varying(50) NOT NULL,
    room_number integer,
    sex character varying(1),
    nationality character varying(2) NOT NULL,
    maritalstatus character varying(2),
    birthdate date NOT NULL,
    address character varying(50),
    zipcode character varying(50),
    town character varying(50),
    countrycodeid character(2) NOT NULL,
    telno character varying(50),
    email character varying(240),
    guardianname character varying(50),
    gaddress character varying(50),
    gzipcode character varying(50),
    gtown character varying(50),
    gcountrycodeid character(2) NOT NULL,
    gtelno character varying(50),
    gemail character varying(240),
    accountnumber character varying(16),
    firstpass character varying(32) DEFAULT 'enter'::character varying NOT NULL,
    studentpass character varying(32) DEFAULT md5('enter'::text) NOT NULL,
    gfirstpass character varying(32) DEFAULT 'enter'::character varying NOT NULL,
    gstudentpass character varying(32) DEFAULT md5('enter'::text) NOT NULL,
    staff boolean DEFAULT false NOT NULL,
    alumnae boolean DEFAULT false NOT NULL,
    postcontacts boolean DEFAULT false NOT NULL,
    seeregistrar boolean DEFAULT false NOT NULL,
    onprobation boolean DEFAULT false NOT NULL,
    offcampus boolean DEFAULT false NOT NULL,
    hallseats integer DEFAULT 1 NOT NULL,
    fullbursary boolean DEFAULT false NOT NULL,
    currentcontact text,
    currentemail character varying(120),
    currenttel character varying(120),
    balance_time timestamp without time zone,
    curr_balance real DEFAULT 0,
    probation_details text,
    registrar_details text,
    details text
);


ALTER TABLE public.students OWNER TO postgres;

--
-- Name: studentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentview AS
 SELECT denominationview.religionid,
    denominationview.religionname,
    denominationview.denominationid,
    denominationview.denominationname,
    residences.residenceid,
    residences.residencename,
    schools.schoolid,
    schools.schoolname,
    c1.countryname AS addresscountry,
    students.org_id,
    students.studentid,
    students.studentname,
    students.address,
    students.zipcode,
    students.town,
    students.telno,
    students.email,
    students.guardianname,
    students.gaddress,
    students.gzipcode,
    students.gtown,
    c2.countryname AS gaddresscountry,
    students.gtelno,
    students.gemail,
    students.accountnumber,
    students.nationality,
    c3.countryname AS nationalitycountry,
    students.sex,
    students.maritalstatus,
    students.birthdate,
    students.firstpass,
    students.alumnae,
    students.postcontacts,
    students.onprobation,
    students.offcampus,
    students.currentcontact,
    students.currentemail,
    students.currenttel,
    students.seeregistrar,
    students.hallseats,
    students.staff,
    students.fullbursary,
    students.details,
    students.room_number,
    students.probation_details,
    students.registrar_details,
    students.gfirstpass,
    ('G'::text || (students.studentid)::text) AS gstudentid
   FROM ((((((denominationview
     JOIN students ON (((denominationview.denominationid)::text = (students.denominationid)::text)))
     JOIN schools ON (((students.schoolid)::text = (schools.schoolid)::text)))
     LEFT JOIN residences ON (((students.residenceid)::text = (residences.residenceid)::text)))
     JOIN countrys c1 ON ((students.countrycodeid = c1.countryid)))
     JOIN countrys c2 ON ((students.gcountrycodeid = c2.countryid)))
     JOIN countrys c3 ON (((students.nationality)::bpchar = c3.countryid)));


ALTER TABLE public.studentview OWNER TO postgres;

--
-- Name: sublevels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sublevels (
    sublevelid character varying(12) NOT NULL,
    markid integer,
    degreelevelid character varying(12) NOT NULL,
    levellocationid integer NOT NULL,
    org_id integer,
    sublevelname character varying(50) NOT NULL,
    unit_charge double precision DEFAULT 2500 NOT NULL,
    lab_charges double precision DEFAULT 2000 NOT NULL,
    exam_fees double precision DEFAULT 500 NOT NULL,
    general_fees double precision DEFAULT 7500 NOT NULL,
    no_sabath_class boolean DEFAULT true NOT NULL,
    specialcharges boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.sublevels OWNER TO postgres;

--
-- Name: sublevelview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sublevelview AS
 SELECT degreelevels.degreelevelid,
    degreelevels.degreelevelname,
    degreelevels.freshman,
    degreelevels.sophomore,
    degreelevels.junior,
    degreelevels.senior,
    levellocations.levellocationid,
    levellocations.levellocationname,
    sublevels.org_id,
    sublevels.sublevelid,
    sublevels.sublevelname,
    sublevels.specialcharges,
    sublevels.unit_charge,
    sublevels.lab_charges,
    sublevels.exam_fees,
    sublevels.general_fees,
    sublevels.details
   FROM ((sublevels
     JOIN degreelevels ON (((sublevels.degreelevelid)::text = (degreelevels.degreelevelid)::text)))
     JOIN levellocations ON ((sublevels.levellocationid = levellocations.levellocationid)));


ALTER TABLE public.sublevelview OWNER TO postgres;

--
-- Name: studentdegreeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentdegreeview AS
 SELECT studentview.religionid,
    studentview.religionname,
    studentview.denominationid,
    studentview.denominationname,
    studentview.schoolid,
    studentview.schoolname,
    studentview.studentid,
    studentview.studentname,
    studentview.address,
    studentview.zipcode,
    studentview.town,
    studentview.addresscountry,
    studentview.telno,
    studentview.email,
    studentview.guardianname,
    studentview.gaddress,
    studentview.gzipcode,
    studentview.gtown,
    studentview.gaddresscountry,
    studentview.gtelno,
    studentview.gemail,
    studentview.accountnumber,
    studentview.nationality,
    studentview.nationalitycountry,
    studentview.sex,
    studentview.maritalstatus,
    studentview.birthdate,
    studentview.firstpass,
    studentview.alumnae,
    studentview.postcontacts,
    studentview.onprobation,
    studentview.offcampus,
    studentview.currentcontact,
    studentview.currentemail,
    studentview.currenttel,
    studentview.org_id,
    sublevelview.degreelevelid,
    sublevelview.degreelevelname,
    sublevelview.freshman,
    sublevelview.sophomore,
    sublevelview.junior,
    sublevelview.senior,
    sublevelview.levellocationid,
    sublevelview.levellocationname,
    sublevelview.sublevelid,
    sublevelview.sublevelname,
    sublevelview.specialcharges,
    degrees.degreeid,
    degrees.degreename,
    studentdegrees.studentdegreeid,
    studentdegrees.completed,
    studentdegrees.started,
    studentdegrees.cleared,
    studentdegrees.clearedate,
    studentdegrees.graduated,
    studentdegrees.graduatedate,
    studentdegrees.dropout,
    studentdegrees.transferin,
    studentdegrees.transferout,
    studentdegrees.mathplacement,
    studentdegrees.englishplacement,
    studentdegrees.details
   FROM (((studentview
     JOIN studentdegrees ON (((studentview.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN sublevelview ON (((studentdegrees.sublevelid)::text = (sublevelview.sublevelid)::text)))
     JOIN degrees ON (((studentdegrees.degreeid)::text = (degrees.degreeid)::text)));


ALTER TABLE public.studentdegreeview OWNER TO postgres;

--
-- Name: vw_charges; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_charges AS
 SELECT quarterview.quarterid,
    quarterview.qstart,
    quarterview.qlatereg,
    quarterview.qlatechange,
    quarterview.qlastdrop,
    quarterview.qend,
    quarterview.active,
    quarterview.chalengerate,
    quarterview.feesline,
    quarterview.resline,
    quarterview.minimal_fees,
    quarterview.closed,
    quarterview.quarter_name,
    quarterview.quarteryear,
    quarterview.quarter,
    degreelevels.degreelevelid,
    degreelevels.degreelevelname,
    levellocations.levellocationid,
    levellocations.levellocationname,
    sublevels.sublevelid,
    sublevels.sublevelname,
    sublevels.specialcharges,
    charges.org_id,
    charges.charge_id,
    charges.session_active,
    charges.session_closed,
    charges.exam_balances,
    charges.sun_posted,
    charges.unit_charge,
    charges.lab_charges,
    charges.exam_fees,
    charges.general_fees,
    charges.residence_stay,
    charges.currency,
    charges.exchange_rate,
    charges.narrative
   FROM ((((quarterview
     JOIN charges ON (((quarterview.quarterid)::text = (charges.quarterid)::text)))
     JOIN sublevels ON (((charges.sublevelid)::text = (sublevels.sublevelid)::text)))
     JOIN degreelevels ON (((sublevels.degreelevelid)::text = (degreelevels.degreelevelid)::text)))
     JOIN levellocations ON ((sublevels.levellocationid = levellocations.levellocationid)));


ALTER TABLE public.vw_charges OWNER TO postgres;

--
-- Name: qstudentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentview AS
 SELECT studentdegreeview.religionid,
    studentdegreeview.religionname,
    studentdegreeview.denominationid,
    studentdegreeview.denominationname,
    studentdegreeview.schoolid,
    studentdegreeview.schoolname,
    studentdegreeview.studentid,
    studentdegreeview.studentname,
    studentdegreeview.address,
    studentdegreeview.zipcode,
    studentdegreeview.town,
    studentdegreeview.addresscountry,
    studentdegreeview.telno,
    studentdegreeview.email,
    studentdegreeview.guardianname,
    studentdegreeview.gaddress,
    studentdegreeview.gzipcode,
    studentdegreeview.gtown,
    studentdegreeview.gaddresscountry,
    studentdegreeview.gtelno,
    studentdegreeview.gemail,
    studentdegreeview.accountnumber,
    studentdegreeview.nationality,
    studentdegreeview.nationalitycountry,
    studentdegreeview.sex,
    studentdegreeview.maritalstatus,
    studentdegreeview.birthdate,
    studentdegreeview.firstpass,
    studentdegreeview.alumnae,
    studentdegreeview.postcontacts,
    studentdegreeview.onprobation,
    studentdegreeview.offcampus,
    studentdegreeview.currentcontact,
    studentdegreeview.currentemail,
    studentdegreeview.currenttel,
    studentdegreeview.freshman,
    studentdegreeview.sophomore,
    studentdegreeview.junior,
    studentdegreeview.senior,
    studentdegreeview.degreeid,
    studentdegreeview.degreename,
    studentdegreeview.studentdegreeid,
    studentdegreeview.completed,
    studentdegreeview.started,
    studentdegreeview.cleared,
    studentdegreeview.clearedate,
    studentdegreeview.graduated,
    studentdegreeview.graduatedate,
    studentdegreeview.dropout,
    studentdegreeview.transferin,
    studentdegreeview.transferout,
    studentdegreeview.mathplacement,
    studentdegreeview.englishplacement,
    vw_charges.quarterid,
    vw_charges.qstart,
    vw_charges.qlatereg,
    vw_charges.qlatechange,
    vw_charges.qlastdrop,
    vw_charges.qend,
    vw_charges.active,
    vw_charges.chalengerate,
    vw_charges.feesline,
    vw_charges.resline,
    vw_charges.quarteryear,
    vw_charges.quarter,
    vw_charges.closed,
    vw_charges.quarter_name,
    vw_charges.degreelevelid,
    vw_charges.degreelevelname,
    vw_charges.charge_id,
    vw_charges.unit_charge,
    vw_charges.lab_charges,
    vw_charges.exam_fees,
    vw_charges.levellocationid,
    vw_charges.levellocationname,
    vw_charges.sublevelid,
    vw_charges.sublevelname,
    vw_charges.specialcharges,
    vw_charges.sun_posted,
    vw_charges.session_active,
    vw_charges.session_closed,
    vw_charges.general_fees,
    vw_charges.residence_stay,
    vw_charges.currency,
    vw_charges.exchange_rate,
    qresidenceview.residenceid,
    qresidenceview.residencename,
    qresidenceview.capacity,
    qresidenceview.defaultrate,
    qresidenceview.offcampus AS residenceoffcampus,
    qresidenceview.sex AS residencesex,
    qresidenceview.residencedean,
    qresidenceview.qresidenceid,
    qresidenceview.residenceoption,
    qstudents.org_id,
    qstudents.qstudentid,
    qstudents.charges AS additionalcharges,
    qstudents.approved,
    qstudents.probation,
    qstudents.roomnumber,
    qstudents.currbalance,
    qstudents.finaceapproval,
    qstudents.majorapproval,
    qstudents.studentdeanapproval,
    qstudents.intersession,
    qstudents.exam_clear,
    qstudents.exam_clear_date,
    qstudents.exam_clear_balance,
    qstudents.request_withdraw,
    qstudents.request_withdraw_date,
    qstudents.withdraw,
    qstudents.ac_withdraw,
    qstudents.withdraw_date,
    qstudents.withdraw_rate,
    qstudents.departapproval,
    qstudents.overloadapproval,
    qstudents.finalised,
    qstudents.printed,
    qstudents.details,
    vw_charges.unit_charge AS ucharge,
    ((vw_charges.residence_stay * qresidenceview.charges) / (100)::double precision) AS residencecharge,
    vw_charges.lab_charges AS lcharge,
    vw_charges.general_fees AS feescharge
   FROM (((studentdegreeview
     JOIN qstudents ON ((studentdegreeview.studentdegreeid = qstudents.studentdegreeid)))
     JOIN vw_charges ON ((qstudents.charge_id = vw_charges.charge_id)))
     JOIN qresidenceview ON ((qstudents.qresidenceid = qresidenceview.qresidenceid)));


ALTER TABLE public.qstudentview OWNER TO postgres;

--
-- Name: studentgradeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentgradeview AS
 SELECT qstudentview.religionid,
    qstudentview.religionname,
    qstudentview.denominationid,
    qstudentview.denominationname,
    qstudentview.schoolid,
    qstudentview.schoolname,
    qstudentview.studentid,
    qstudentview.studentname,
    qstudentview.address,
    qstudentview.zipcode,
    qstudentview.town,
    qstudentview.addresscountry,
    qstudentview.telno,
    qstudentview.email,
    qstudentview.guardianname,
    qstudentview.gaddress,
    qstudentview.gzipcode,
    qstudentview.gtown,
    qstudentview.gaddresscountry,
    qstudentview.gtelno,
    qstudentview.gemail,
    qstudentview.accountnumber,
    qstudentview.nationality,
    qstudentview.nationalitycountry,
    qstudentview.sex,
    qstudentview.maritalstatus,
    qstudentview.birthdate,
    qstudentview.firstpass,
    qstudentview.alumnae,
    qstudentview.postcontacts,
    qstudentview.onprobation,
    qstudentview.offcampus,
    qstudentview.currentcontact,
    qstudentview.currentemail,
    qstudentview.currenttel,
    qstudentview.degreelevelid,
    qstudentview.degreelevelname,
    qstudentview.freshman,
    qstudentview.sophomore,
    qstudentview.junior,
    qstudentview.senior,
    qstudentview.levellocationid,
    qstudentview.levellocationname,
    qstudentview.sublevelid,
    qstudentview.sublevelname,
    qstudentview.specialcharges,
    qstudentview.degreeid,
    qstudentview.degreename,
    qstudentview.studentdegreeid,
    qstudentview.completed,
    qstudentview.started,
    qstudentview.cleared,
    qstudentview.clearedate,
    qstudentview.graduated,
    qstudentview.graduatedate,
    qstudentview.dropout,
    qstudentview.transferin,
    qstudentview.transferout,
    qstudentview.mathplacement,
    qstudentview.englishplacement,
    qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.qstart,
    qstudentview.qlatereg,
    qstudentview.qlatechange,
    qstudentview.qlastdrop,
    qstudentview.qend,
    qstudentview.active,
    qstudentview.feesline,
    qstudentview.resline,
    qstudentview.residenceid,
    qstudentview.residencename,
    qstudentview.capacity,
    qstudentview.defaultrate,
    qstudentview.residenceoffcampus,
    qstudentview.residencesex,
    qstudentview.residencedean,
    qstudentview.qresidenceid,
    qstudentview.residenceoption,
    qstudentview.residencecharge,
    qstudentview.org_id,
    qstudentview.qstudentid,
    qstudentview.additionalcharges,
    qstudentview.approved,
    qstudentview.probation,
    qstudentview.roomnumber,
    qstudentview.currbalance,
    qstudentview.finaceapproval,
    qstudentview.majorapproval,
    qstudentview.departapproval,
    qstudentview.overloadapproval,
    qstudentview.finalised,
    qstudentview.printed,
    qstudentview.ucharge,
    qstudentview.lcharge,
    qstudentview.feescharge,
    qstudentview.intersession,
    qstudentview.exam_clear,
    qstudentview.exam_clear_date,
    qstudentview.exam_clear_balance,
    qstudentview.exam_fees,
    qstudentview.request_withdraw,
    qstudentview.request_withdraw_date,
    qstudentview.withdraw,
    qstudentview.ac_withdraw,
    qstudentview.withdraw_date,
    qstudentview.withdraw_rate,
    qstudentview.currency,
    qstudentview.exchange_rate,
    qgradeview.schoolid AS crs_schoolid,
    qgradeview.schoolname AS crs_schoolname,
    qgradeview.departmentid AS crs_departmentid,
    qgradeview.departmentname AS crs_departmentname,
    qgradeview.degreelevelid AS crs_degreelevelid,
    qgradeview.degreelevelname AS crs_degreelevelname,
    qgradeview.coursetypeid,
    qgradeview.coursetypename,
    qgradeview.courseid,
    qgradeview.credithours,
    qgradeview.iscurrent,
    qgradeview.nogpa,
    qgradeview.yeartaken,
    qgradeview.crs_mathplacement,
    qgradeview.crs_englishplacement,
    qgradeview.instructorid,
    qgradeview.qcourseid,
    qgradeview.classoption,
    qgradeview.maxclass,
    qgradeview.labcourse,
    qgradeview.attendance AS crs_attendance,
    qgradeview.oldcourseid,
    qgradeview.fullattendance,
    qgradeview.instructorname,
    qgradeview.coursetitle,
    qgradeview.qgradeid,
    qgradeview.hours,
    qgradeview.credit,
    qgradeview.crs_approved,
    qgradeview.approvedate,
    qgradeview.askdrop,
    qgradeview.askdropdate,
    qgradeview.dropped,
    qgradeview.dropdate,
    qgradeview.repeated,
    qgradeview.attendance,
    qgradeview.narrative,
    qgradeview.gradeid,
    qgradeview.gradeweight,
    qgradeview.minrange,
    qgradeview.maxrange,
    qgradeview.gpacount,
    qgradeview.gradenarrative,
    qgradeview.gpa,
    qgradeview.gpahours,
    qgradeview.chargehours,
    qgradeview.attachement,
    qgradeview.lecture_marks,
    qgradeview.lecture_cat_mark,
    qgradeview.lecture_gradeid,
    qgradeview.course_withdraw_rate,
    qgradeview.submit_grades,
    qgradeview.submit_date,
    qgradeview.approved_grades,
    qgradeview.approve_date,
    qgradeview.departmentchange,
    qgradeview.registrychange,
        CASE
            WHEN (qgradeview.challengecourse = true) THEN (((qstudentview.chalengerate * qgradeview.chargehours) * qstudentview.ucharge) / (100)::double precision)
            ELSE (qgradeview.chargehours * qstudentview.ucharge)
        END AS unitfees,
        CASE
            WHEN (qgradeview.examinable = true) THEN qstudentview.exam_fees
            ELSE (0)::double precision
        END AS examfee,
    qgradeview.clinical_fee,
        CASE
            WHEN (qgradeview.labcourse = true) THEN qstudentview.lab_charges
            ELSE (0)::double precision
        END AS labfees,
    qgradeview.extracharge
   FROM (qstudentview
     JOIN qgradeview ON ((qstudentview.qstudentid = qgradeview.qstudentid)));


ALTER TABLE public.studentgradeview OWNER TO postgres;

--
-- Name: coregradeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW coregradeview AS
 SELECT studentgradeview.schoolid,
    studentgradeview.schoolname,
    studentgradeview.studentid,
    studentgradeview.studentname,
    studentgradeview.sex,
    studentgradeview.degreeid,
    studentgradeview.degreename,
    studentgradeview.studentdegreeid,
    studentgradeview.quarterid,
    studentgradeview.quarteryear,
    studentgradeview.quarter,
    studentgradeview.coursetypeid,
    studentgradeview.coursetypename,
    studentgradeview.courseid,
    studentgradeview.nogpa,
    studentgradeview.instructorid,
    studentgradeview.qcourseid,
    studentgradeview.classoption,
    studentgradeview.labcourse,
    studentgradeview.instructorname,
    studentgradeview.coursetitle,
    studentgradeview.qgradeid,
    studentgradeview.hours,
    studentgradeview.credit,
    studentgradeview.gpa,
    studentgradeview.gradeid,
    studentgradeview.repeated,
    studentgradeview.gpahours,
    studentgradeview.chargehours,
    corecourseoutline.description,
    corecourseoutline.minor,
    corecourseoutline.elective,
    corecourseoutline.contenttypeid,
    corecourseoutline.contenttypename
   FROM (corecourseoutline
     JOIN studentgradeview ON (((corecourseoutline.studentdegreeid = studentgradeview.studentdegreeid) AND ((corecourseoutline.courseid)::text = (studentgradeview.courseid)::text))))
  WHERE ((studentgradeview.approved = true) AND (corecourseoutline.minor = false));


ALTER TABLE public.coregradeview OWNER TO postgres;

--
-- Name: counties; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE counties (
    county_id integer NOT NULL,
    county_name character varying(50)
);


ALTER TABLE public.counties OWNER TO postgres;

--
-- Name: counties_county_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE counties_county_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.counties_county_id_seq OWNER TO postgres;

--
-- Name: counties_county_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE counties_county_id_seq OWNED BY counties.county_id;


--
-- Name: courseoutline; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW courseoutline AS
 SELECT 1 AS orderid,
    studentdegrees.studentid,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    majors.majorname AS description,
    majorcontentview.courseid,
    majorcontentview.coursetitle,
    majorcontentview.minor,
    majorcontentview.elective,
    majorcontentview.credithours,
    majorcontentview.nogpa,
    majorcontentview.gradeid,
    grades.gradeweight
   FROM ((((majors
     JOIN majorcontentview ON (((majors.majorid)::text = (majorcontentview.majorid)::text)))
     JOIN studentmajors ON (((majorcontentview.majorid)::text = (studentmajors.majorid)::text)))
     JOIN studentdegrees ON (((studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majorcontentview.bulletingid = studentdegrees.bulletingid))))
     JOIN grades ON (((majorcontentview.gradeid)::text = (grades.gradeid)::text)))
  WHERE ((((((NOT studentmajors.premajor) AND majorcontentview.premajor) = false) AND (((NOT studentmajors.nondegree) AND majorcontentview.prerequisite) = false)) AND (studentdegrees.completed = false)) AND (studentdegrees.dropout = false))
UNION
 SELECT 2 AS orderid,
    studentdegrees.studentid,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    majoroptions.majoroptionname AS description,
    majoroptcontentview.courseid,
    majoroptcontentview.coursetitle,
    majoroptcontentview.minor,
    majoroptcontentview.elective,
    majoroptcontentview.credithours,
    majoroptcontentview.nogpa,
    majoroptcontentview.gradeid,
    grades.gradeweight
   FROM ((((majoroptions
     JOIN majoroptcontentview ON ((majoroptions.majoroptionid = majoroptcontentview.majoroptionid)))
     JOIN studentmajors ON ((majoroptcontentview.majoroptionid = studentmajors.majoroptionid)))
     JOIN studentdegrees ON (((studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majoroptcontentview.bulletingid = studentdegrees.bulletingid))))
     JOIN grades ON (((majoroptcontentview.gradeid)::text = (grades.gradeid)::text)))
  WHERE ((((((NOT studentmajors.premajor) AND majoroptcontentview.premajor) = false) AND (((NOT studentmajors.nondegree) AND majoroptcontentview.prerequisite) = false)) AND (studentdegrees.completed = false)) AND (studentdegrees.dropout = false));


ALTER TABLE public.courseoutline OWNER TO postgres;

--
-- Name: coursechecklist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW coursechecklist AS
 SELECT DISTINCT courseoutline.orderid,
    courseoutline.studentid,
    courseoutline.studentdegreeid,
    courseoutline.degreeid,
    courseoutline.description,
    courseoutline.courseid,
    courseoutline.coursetitle,
    courseoutline.minor,
    courseoutline.elective,
    courseoutline.credithours,
    courseoutline.nogpa,
    courseoutline.gradeid,
    courseoutline.gradeweight,
    getcoursedone(courseoutline.studentid, courseoutline.courseid) AS courseweight,
        CASE
            WHEN (getcoursedone(courseoutline.studentid, courseoutline.courseid) >= courseoutline.gradeweight) THEN true
            ELSE false
        END AS coursepased,
    getprereqpassed(courseoutline.studentid, courseoutline.courseid, courseoutline.studentdegreeid) AS prereqpassed
   FROM courseoutline;


ALTER TABLE public.coursechecklist OWNER TO postgres;

--
-- Name: coursetypes_coursetypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE coursetypes_coursetypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.coursetypes_coursetypeid_seq OWNER TO postgres;

--
-- Name: coursetypes_coursetypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE coursetypes_coursetypeid_seq OWNED BY coursetypes.coursetypeid;


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
-- Name: currentresidenceview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW currentresidenceview AS
 SELECT residences.residenceid,
    residences.residencename,
    residences.capacity,
    residences.defaultrate,
    residences.offcampus,
    residences.sex,
    residences.residencedean,
    qresidences.qresidenceid,
    qresidences.quarterid,
    qresidences.residenceoption,
    qresidences.charges,
    qresidences.details,
    qresidences.org_id,
    students.studentid,
    students.studentname
   FROM (((residences
     JOIN qresidences ON (((residences.residenceid)::text = (qresidences.residenceid)::text)))
     JOIN quarterview ON (((qresidences.quarterid)::text = (quarterview.quarterid)::text)))
     JOIN students ON (((((residences.sex)::text = (students.sex)::text) OR ((residences.sex)::text = 'N'::text)) AND (residences.offcampus = students.offcampus))))
  WHERE (quarterview.active = true);


ALTER TABLE public.currentresidenceview OWNER TO postgres;

--
-- Name: currqcourseview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW currqcourseview AS
 SELECT qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.degreelevelid,
    qcourseview.degreelevelname,
    qcourseview.coursetypeid,
    qcourseview.coursetypename,
    qcourseview.org_id,
    qcourseview.courseid,
    qcourseview.credithours,
    qcourseview.maxcredit,
    qcourseview.iscurrent,
    qcourseview.nogpa,
    qcourseview.yeartaken,
    qcourseview.mathplacement,
    qcourseview.englishplacement,
    qcourseview.instructorid,
    qcourseview.quarterid,
    qcourseview.qcourseid,
    qcourseview.classoption,
    qcourseview.maxclass,
    qcourseview.labcourse,
    qcourseview.extracharge,
    qcourseview.approved,
    qcourseview.attendance,
    qcourseview.oldcourseid,
    qcourseview.fullattendance,
    qcourseview.instructorname,
    qcourseview.coursetitle,
    qcourseview.levellocationid,
    qcourseview.levellocationname
   FROM qcourseview
  WHERE ((qcourseview.active = true) AND (qcourseview.approved = false));


ALTER TABLE public.currqcourseview OWNER TO postgres;

--
-- Name: optiontimes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE optiontimes (
    optiontimeid integer NOT NULL,
    optiontimename character varying(50),
    details text
);


ALTER TABLE public.optiontimes OWNER TO postgres;

--
-- Name: qtimetable; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qtimetable (
    qtimetableid integer NOT NULL,
    assetid integer NOT NULL,
    qcourseid integer NOT NULL,
    optiontimeid integer DEFAULT 0 NOT NULL,
    org_id integer,
    cmonday boolean DEFAULT false NOT NULL,
    ctuesday boolean DEFAULT false NOT NULL,
    cwednesday boolean DEFAULT false NOT NULL,
    cthursday boolean DEFAULT false NOT NULL,
    cfriday boolean DEFAULT false NOT NULL,
    csaturday boolean DEFAULT false NOT NULL,
    csunday boolean DEFAULT false NOT NULL,
    starttime time without time zone NOT NULL,
    endtime time without time zone NOT NULL,
    lab boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.qtimetable OWNER TO postgres;

--
-- Name: qtimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qtimetableview AS
 SELECT assets.assetid,
    assets.assetname,
    assets.location,
    assets.building,
    assets.capacity,
    qcourseview.qcourseid,
    qcourseview.courseid,
    qcourseview.coursetitle,
    qcourseview.instructorid,
    qcourseview.instructorname,
    qcourseview.quarterid,
    qcourseview.maxclass,
    qcourseview.classoption,
    optiontimes.optiontimeid,
    optiontimes.optiontimename,
    qtimetable.org_id,
    qtimetable.qtimetableid,
    qtimetable.starttime,
    qtimetable.endtime,
    qtimetable.lab,
    qtimetable.details,
    qtimetable.cmonday,
    qtimetable.ctuesday,
    qtimetable.cwednesday,
    qtimetable.cthursday,
    qtimetable.cfriday,
    qtimetable.csaturday,
    qtimetable.csunday
   FROM (((assets
     JOIN qtimetable ON ((assets.assetid = qtimetable.assetid)))
     JOIN qcourseview ON ((qtimetable.qcourseid = qcourseview.qcourseid)))
     JOIN optiontimes ON ((qtimetable.optiontimeid = optiontimes.optiontimeid)))
  ORDER BY qtimetable.starttime;


ALTER TABLE public.qtimetableview OWNER TO postgres;

--
-- Name: currtimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW currtimetableview AS
 SELECT qtimetableview.assetid,
    qtimetableview.assetname,
    qtimetableview.location,
    qtimetableview.building,
    qtimetableview.capacity,
    qtimetableview.qcourseid,
    qtimetableview.courseid,
    qtimetableview.coursetitle,
    qtimetableview.instructorid,
    qtimetableview.instructorname,
    qtimetableview.quarterid,
    qtimetableview.maxclass,
    qtimetableview.classoption,
    qtimetableview.optiontimeid,
    qtimetableview.optiontimename,
    qtimetableview.org_id,
    qtimetableview.qtimetableid,
    qtimetableview.starttime,
    qtimetableview.endtime,
    qtimetableview.lab,
    qtimetableview.details,
    qtimetableview.cmonday,
    qtimetableview.ctuesday,
    qtimetableview.cwednesday,
    qtimetableview.cthursday,
    qtimetableview.cfriday,
    qtimetableview.csaturday,
    qtimetableview.csunday
   FROM (qtimetableview
     JOIN quarters ON (((qtimetableview.quarterid)::text = (quarters.quarterid)::text)))
  WHERE (quarters.closed = false)
  ORDER BY qtimetableview.starttime;


ALTER TABLE public.currtimetableview OWNER TO postgres;

--
-- Name: cv_projects; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE cv_projects (
    cv_projectid integer NOT NULL,
    entity_id integer,
    cv_project_name character varying(240),
    cv_project_date date NOT NULL,
    details text
);


ALTER TABLE public.cv_projects OWNER TO postgres;

--
-- Name: cv_projects_cv_projectid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cv_projects_cv_projectid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cv_projects_cv_projectid_seq OWNER TO postgres;

--
-- Name: cv_projects_cv_projectid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cv_projects_cv_projectid_seq OWNED BY cv_projects.cv_projectid;


--
-- Name: cv_referees; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE cv_referees (
    cv_referee_id integer NOT NULL,
    entity_id integer,
    cv_referee_name character varying(50),
    cv_referee_address text,
    details text
);


ALTER TABLE public.cv_referees OWNER TO postgres;

--
-- Name: cv_referees_cv_referee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cv_referees_cv_referee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cv_referees_cv_referee_id_seq OWNER TO postgres;

--
-- Name: cv_referees_cv_referee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cv_referees_cv_referee_id_seq OWNED BY cv_referees.cv_referee_id;


--
-- Name: cv_seminars; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE cv_seminars (
    cv_seminar_id integer NOT NULL,
    entity_id integer,
    cv_seminar_name character varying(240),
    cv_seminar_date date NOT NULL,
    details text
);


ALTER TABLE public.cv_seminars OWNER TO postgres;

--
-- Name: cv_seminars_cv_seminar_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE cv_seminars_cv_seminar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cv_seminars_cv_seminar_id_seq OWNER TO postgres;

--
-- Name: cv_seminars_cv_seminar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE cv_seminars_cv_seminar_id_seq OWNED BY cv_seminars.cv_seminar_id;


--
-- Name: degreeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW degreeview AS
 SELECT degreelevels.degreelevelid,
    degreelevels.degreelevelname,
    degrees.degreeid,
    degrees.degreename,
    degrees.details
   FROM (degreelevels
     JOIN degrees ON (((degreelevels.degreelevelid)::text = (degrees.degreelevelid)::text)));


ALTER TABLE public.degreeview OWNER TO postgres;

--
-- Name: denominationsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW denominationsummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.denominationname,
    qstudentview.sex,
    'Denomination'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.denominationname, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.denominationname, qstudentview.sex;


ALTER TABLE public.denominationsummary OWNER TO postgres;

--
-- Name: education; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE education (
    education_id integer NOT NULL,
    entity_id integer,
    education_class_id integer,
    date_from date,
    date_to date,
    name_of_school character varying(240),
    examination_taken character varying(240),
    grades_obtained character varying(50),
    details text
);


ALTER TABLE public.education OWNER TO postgres;

--
-- Name: education_class; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE education_class (
    education_class_id integer NOT NULL,
    education_class_name character varying(50),
    details text
);


ALTER TABLE public.education_class OWNER TO postgres;

--
-- Name: education_class_education_class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE education_class_education_class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.education_class_education_class_id_seq OWNER TO postgres;

--
-- Name: education_class_education_class_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE education_class_education_class_id_seq OWNED BY education_class.education_class_id;


--
-- Name: education_education_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE education_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.education_education_id_seq OWNER TO postgres;

--
-- Name: education_education_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE education_education_id_seq OWNED BY education.education_id;


--
-- Name: employment; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE employment (
    employment_id integer NOT NULL,
    entity_id integer,
    date_from date,
    date_to date,
    employers_name character varying(240),
    position_held character varying(240),
    details text
);


ALTER TABLE public.employment OWNER TO postgres;

--
-- Name: employment_employment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE employment_employment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.employment_employment_id_seq OWNER TO postgres;

--
-- Name: employment_employment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE employment_employment_id_seq OWNED BY employment.employment_id;


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
    selection_id integer,
    admision_payment real DEFAULT 2000,
    admision_paid boolean DEFAULT false NOT NULL
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
-- Name: evaluation; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE evaluation (
    evaluationid integer NOT NULL,
    registrationid integer,
    respondentname character varying(50),
    organisationname character varying(50),
    respondentpostion character varying(50),
    address character varying(50),
    evaldate date,
    influence character varying(50),
    honesty character varying(50),
    reliabilty character varying(50),
    coperation character varying(50),
    punctuality character varying(50),
    appearance character varying(50),
    moralstandards character varying(50),
    religiouscommitment character varying(50),
    churchactivities character varying(50),
    overal character varying(50),
    smoke boolean,
    drink boolean,
    drugs boolean,
    hsmoke boolean,
    hdrink boolean,
    hdrugs boolean,
    arrested boolean,
    schooldismissal character varying(50),
    recomendation character varying(50),
    details text
);


ALTER TABLE public.evaluation OWNER TO postgres;

--
-- Name: evaluation_evaluationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE evaluation_evaluationid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.evaluation_evaluationid_seq OWNER TO postgres;

--
-- Name: evaluation_evaluationid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE evaluation_evaluationid_seq OWNED BY evaluation.evaluationid;


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
-- Name: levelsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW levelsummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.degreelevelname,
    qstudentview.sex,
    'Degree Level'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.degreelevelname, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.degreelevelname, qstudentview.sex;


ALTER TABLE public.levelsummary OWNER TO postgres;

--
-- Name: studentquarterview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentquarterview AS
 SELECT studentgradeview.org_id,
    studentgradeview.religionid,
    studentgradeview.religionname,
    studentgradeview.denominationid,
    studentgradeview.denominationname,
    studentgradeview.schoolid,
    studentgradeview.schoolname,
    studentgradeview.studentid,
    studentgradeview.studentname,
    studentgradeview.address,
    studentgradeview.zipcode,
    studentgradeview.town,
    studentgradeview.addresscountry,
    studentgradeview.telno,
    studentgradeview.email,
    studentgradeview.guardianname,
    studentgradeview.gaddress,
    studentgradeview.gzipcode,
    studentgradeview.gtown,
    studentgradeview.gaddresscountry,
    studentgradeview.gtelno,
    studentgradeview.gemail,
    studentgradeview.accountnumber,
    studentgradeview.nationality,
    studentgradeview.nationalitycountry,
    studentgradeview.sex,
    studentgradeview.maritalstatus,
    studentgradeview.birthdate,
    studentgradeview.firstpass,
    studentgradeview.alumnae,
    studentgradeview.postcontacts,
    studentgradeview.onprobation,
    studentgradeview.offcampus,
    studentgradeview.currentcontact,
    studentgradeview.currentemail,
    studentgradeview.currenttel,
    studentgradeview.degreelevelid,
    studentgradeview.degreelevelname,
    studentgradeview.freshman,
    studentgradeview.sophomore,
    studentgradeview.junior,
    studentgradeview.senior,
    studentgradeview.levellocationid,
    studentgradeview.levellocationname,
    studentgradeview.sublevelid,
    studentgradeview.sublevelname,
    studentgradeview.specialcharges,
    studentgradeview.degreeid,
    studentgradeview.degreename,
    studentgradeview.studentdegreeid,
    studentgradeview.completed,
    studentgradeview.started,
    studentgradeview.cleared,
    studentgradeview.clearedate,
    studentgradeview.graduated,
    studentgradeview.graduatedate,
    studentgradeview.dropout,
    studentgradeview.transferin,
    studentgradeview.transferout,
    studentgradeview.mathplacement,
    studentgradeview.englishplacement,
    studentgradeview.quarterid,
    studentgradeview.quarteryear,
    studentgradeview.quarter,
    studentgradeview.qstart,
    studentgradeview.qlatereg,
    studentgradeview.qlatechange,
    studentgradeview.qlastdrop,
    studentgradeview.qend,
    studentgradeview.active,
    studentgradeview.feesline,
    studentgradeview.resline,
    studentgradeview.residenceid,
    studentgradeview.residencename,
    studentgradeview.capacity,
    studentgradeview.defaultrate,
    studentgradeview.residenceoffcampus,
    studentgradeview.residencesex,
    studentgradeview.residencedean,
    studentgradeview.qresidenceid,
    studentgradeview.residenceoption,
    studentgradeview.qstudentid,
    studentgradeview.approved,
    studentgradeview.probation,
    studentgradeview.roomnumber,
    studentgradeview.finaceapproval,
    studentgradeview.majorapproval,
    studentgradeview.departapproval,
    studentgradeview.overloadapproval,
    studentgradeview.finalised,
    studentgradeview.printed,
    studentgradeview.intersession,
    studentgradeview.ucharge,
    studentgradeview.lcharge,
    studentgradeview.currbalance,
    studentgradeview.additionalcharges,
    studentgradeview.exam_clear,
    studentgradeview.exam_clear_date,
    studentgradeview.exam_clear_balance,
    studentgradeview.exam_fees,
    studentgradeview.request_withdraw,
    studentgradeview.request_withdraw_date,
    studentgradeview.withdraw,
    studentgradeview.ac_withdraw,
    studentgradeview.withdraw_date,
    studentgradeview.withdraw_rate,
    studentgradeview.currency,
    studentgradeview.exchange_rate,
        CASE sum(studentgradeview.gpahours)
            WHEN 0 THEN (0)::double precision
            ELSE (sum(studentgradeview.gpa) / sum(studentgradeview.gpahours))
        END AS gpa,
    sum(studentgradeview.gpahours) AS credit,
    sum(studentgradeview.chargehours) AS hours,
    bool_and(studentgradeview.attachement) AS onattachment,
        CASE bool_and(studentgradeview.attachement)
            WHEN true THEN (0)::double precision
            ELSE studentgradeview.feescharge
        END AS feescharge,
    sum(studentgradeview.unitfees) AS unitcharge,
    sum(studentgradeview.labfees) AS labcharge,
    sum(studentgradeview.clinical_fee) AS clinical_charge,
    sum(studentgradeview.examfee) AS examfee,
    sum(studentgradeview.extracharge) AS courseextracharge,
    studentgradeview.residencecharge,
    (((((((
        CASE bool_and(studentgradeview.attachement)
            WHEN true THEN (0)::double precision
            ELSE studentgradeview.feescharge
        END + sum(studentgradeview.unitfees)) + sum(studentgradeview.examfee)) + sum(studentgradeview.labfees)) + sum(studentgradeview.clinical_fee)) + sum(studentgradeview.extracharge)) + studentgradeview.residencecharge) + studentgradeview.additionalcharges) AS totalfees,
    (studentgradeview.currbalance + (((((((
        CASE bool_and(studentgradeview.attachement)
            WHEN true THEN (0)::double precision
            ELSE studentgradeview.feescharge
        END + sum(studentgradeview.unitfees)) + sum(studentgradeview.examfee)) + sum(studentgradeview.labfees)) + sum(studentgradeview.clinical_fee)) + sum(studentgradeview.extracharge)) + studentgradeview.residencecharge) + studentgradeview.additionalcharges)) AS finalbalance
   FROM studentgradeview
  WHERE (((studentgradeview.gradeid)::text <> 'W'::text) AND ((studentgradeview.gradeid)::text <> 'AW'::text))
  GROUP BY studentgradeview.org_id, studentgradeview.religionid, studentgradeview.religionname, studentgradeview.denominationid, studentgradeview.denominationname, studentgradeview.schoolid, studentgradeview.schoolname, studentgradeview.studentid, studentgradeview.studentname, studentgradeview.address, studentgradeview.zipcode, studentgradeview.town, studentgradeview.addresscountry, studentgradeview.telno, studentgradeview.email, studentgradeview.guardianname, studentgradeview.gaddress, studentgradeview.gzipcode, studentgradeview.gtown, studentgradeview.gaddresscountry, studentgradeview.gtelno, studentgradeview.gemail, studentgradeview.accountnumber, studentgradeview.nationality, studentgradeview.nationalitycountry, studentgradeview.sex, studentgradeview.maritalstatus, studentgradeview.birthdate, studentgradeview.firstpass, studentgradeview.alumnae, studentgradeview.postcontacts, studentgradeview.onprobation, studentgradeview.offcampus, studentgradeview.currentcontact, studentgradeview.currentemail, studentgradeview.currenttel, studentgradeview.degreelevelid, studentgradeview.degreelevelname, studentgradeview.freshman, studentgradeview.sophomore, studentgradeview.junior, studentgradeview.senior, studentgradeview.levellocationid, studentgradeview.levellocationname, studentgradeview.sublevelid, studentgradeview.sublevelname, studentgradeview.specialcharges, studentgradeview.degreeid, studentgradeview.degreename, studentgradeview.studentdegreeid, studentgradeview.completed, studentgradeview.started, studentgradeview.cleared, studentgradeview.clearedate, studentgradeview.graduated, studentgradeview.graduatedate, studentgradeview.dropout, studentgradeview.transferin, studentgradeview.transferout, studentgradeview.mathplacement, studentgradeview.englishplacement, studentgradeview.quarterid, studentgradeview.quarteryear, studentgradeview.quarter, studentgradeview.qstart, studentgradeview.qlatereg, studentgradeview.qlatechange, studentgradeview.qlastdrop, studentgradeview.qend, studentgradeview.active, studentgradeview.feesline, studentgradeview.resline, studentgradeview.residenceid, studentgradeview.residencename, studentgradeview.capacity, studentgradeview.defaultrate, studentgradeview.residenceoffcampus, studentgradeview.residencesex, studentgradeview.residencedean, studentgradeview.qresidenceid, studentgradeview.residenceoption, studentgradeview.qstudentid, studentgradeview.approved, studentgradeview.probation, studentgradeview.roomnumber, studentgradeview.finaceapproval, studentgradeview.majorapproval, studentgradeview.departapproval, studentgradeview.overloadapproval, studentgradeview.finalised, studentgradeview.printed, studentgradeview.intersession, studentgradeview.ucharge, studentgradeview.lcharge, studentgradeview.currbalance, studentgradeview.feescharge, studentgradeview.residencecharge, studentgradeview.additionalcharges, studentgradeview.exam_clear, studentgradeview.exam_clear_date, studentgradeview.exam_clear_balance, studentgradeview.exam_fees, studentgradeview.request_withdraw, studentgradeview.request_withdraw_date, studentgradeview.withdraw, studentgradeview.ac_withdraw, studentgradeview.withdraw_date, studentgradeview.withdraw_rate, studentgradeview.currency, studentgradeview.exchange_rate;


ALTER TABLE public.studentquarterview OWNER TO postgres;

--
-- Name: locationsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW locationsummary AS
 SELECT studentquarterview.quarterid,
    studentquarterview.quarteryear,
    studentquarterview.quarter,
    studentquarterview.levellocationname,
    studentquarterview.sex,
    'Location'::character varying AS defination,
    count(studentquarterview.qstudentid) AS studentcount
   FROM studentquarterview
  WHERE (studentquarterview.approved = true)
  GROUP BY studentquarterview.quarterid, studentquarterview.quarteryear, studentquarterview.quarter, studentquarterview.levellocationname, studentquarterview.sex
  ORDER BY studentquarterview.quarterid, studentquarterview.quarteryear, studentquarterview.quarter, studentquarterview.levellocationname, studentquarterview.sex;


ALTER TABLE public.locationsummary OWNER TO postgres;

--
-- Name: nationalitysummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW nationalitysummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.nationalitycountry,
    qstudentview.sex,
    'Nationality'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.nationalitycountry, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.nationalitycountry, qstudentview.sex;


ALTER TABLE public.nationalitysummary OWNER TO postgres;

--
-- Name: studentquarterlist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentquarterlist AS
 SELECT qstudentview.religionid,
    qstudentview.religionname,
    qstudentview.denominationid,
    qstudentview.denominationname,
    qstudentview.schoolid,
    qstudentview.schoolname,
    qstudentview.studentid,
    qstudentview.studentname,
    qstudentview.address,
    qstudentview.zipcode,
    qstudentview.town,
    qstudentview.addresscountry,
    qstudentview.telno,
    qstudentview.email,
    qstudentview.guardianname,
    qstudentview.gaddress,
    qstudentview.gzipcode,
    qstudentview.gtown,
    qstudentview.gaddresscountry,
    qstudentview.gtelno,
    qstudentview.gemail,
    qstudentview.accountnumber,
    qstudentview.nationality,
    qstudentview.nationalitycountry,
    qstudentview.sex,
    qstudentview.maritalstatus,
    qstudentview.birthdate,
    qstudentview.firstpass,
    qstudentview.alumnae,
    qstudentview.postcontacts,
    qstudentview.onprobation,
    qstudentview.offcampus,
    qstudentview.currentcontact,
    qstudentview.currentemail,
    qstudentview.currenttel,
    qstudentview.degreelevelid,
    qstudentview.degreelevelname,
    qstudentview.freshman,
    qstudentview.sophomore,
    qstudentview.junior,
    qstudentview.senior,
    qstudentview.levellocationid,
    qstudentview.levellocationname,
    qstudentview.sublevelid,
    qstudentview.sublevelname,
    qstudentview.specialcharges,
    qstudentview.degreeid,
    qstudentview.degreename,
    qstudentview.studentdegreeid,
    qstudentview.completed,
    qstudentview.started,
    qstudentview.cleared,
    qstudentview.clearedate,
    qstudentview.graduated,
    qstudentview.graduatedate,
    qstudentview.dropout,
    qstudentview.transferin,
    qstudentview.transferout,
    qstudentview.mathplacement,
    qstudentview.englishplacement,
    qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.qstart,
    qstudentview.qlatereg,
    qstudentview.qlatechange,
    qstudentview.qlastdrop,
    qstudentview.qend,
    qstudentview.active,
    qstudentview.feesline,
    qstudentview.resline,
    qstudentview.residenceid,
    qstudentview.residencename,
    qstudentview.capacity,
    qstudentview.defaultrate,
    qstudentview.residenceoffcampus,
    qstudentview.residencesex,
    qstudentview.residencedean,
    qstudentview.qresidenceid,
    qstudentview.residenceoption,
    qstudentview.qstudentid,
    qstudentview.approved,
    qstudentview.probation,
    qstudentview.roomnumber,
    qstudentview.finaceapproval,
    qstudentview.majorapproval,
    qstudentview.departapproval,
    qstudentview.overloadapproval,
    qstudentview.finalised,
    qstudentview.printed,
    getcurrhours(qstudentview.qstudentid) AS hours,
    getcurrcredit(qstudentview.qstudentid) AS credit,
    getcurrgpa(qstudentview.qstudentid) AS gpa,
    getcummcredit(qstudentview.studentdegreeid, qstudentview.quarterid) AS cummcredit,
    getcummgpa(qstudentview.studentdegreeid, qstudentview.quarterid) AS cummgpa,
    getprevquarter(qstudentview.studentdegreeid, qstudentview.quarterid) AS prevquarter,
        CASE
            WHEN (getprevquarter(qstudentview.studentdegreeid, qstudentview.quarterid) IS NULL) THEN true
            ELSE false
        END AS newstudent
   FROM qstudentview;


ALTER TABLE public.studentquarterlist OWNER TO postgres;

--
-- Name: studentquartersummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentquartersummary AS
 SELECT studentquarterlist.religionid,
    studentquarterlist.religionname,
    studentquarterlist.denominationid,
    studentquarterlist.denominationname,
    studentquarterlist.schoolid,
    studentquarterlist.schoolname,
    studentquarterlist.studentid,
    studentquarterlist.studentname,
    studentquarterlist.address,
    studentquarterlist.zipcode,
    studentquarterlist.town,
    studentquarterlist.addresscountry,
    studentquarterlist.telno,
    studentquarterlist.email,
    studentquarterlist.guardianname,
    studentquarterlist.gaddress,
    studentquarterlist.gzipcode,
    studentquarterlist.gtown,
    studentquarterlist.gaddresscountry,
    studentquarterlist.gtelno,
    studentquarterlist.gemail,
    studentquarterlist.accountnumber,
    studentquarterlist.nationality,
    studentquarterlist.nationalitycountry,
    studentquarterlist.sex,
    studentquarterlist.maritalstatus,
    studentquarterlist.birthdate,
    studentquarterlist.firstpass,
    studentquarterlist.alumnae,
    studentquarterlist.postcontacts,
    studentquarterlist.onprobation,
    studentquarterlist.offcampus,
    studentquarterlist.currentcontact,
    studentquarterlist.currentemail,
    studentquarterlist.currenttel,
    studentquarterlist.degreelevelid,
    studentquarterlist.degreelevelname,
    studentquarterlist.freshman,
    studentquarterlist.sophomore,
    studentquarterlist.junior,
    studentquarterlist.senior,
    studentquarterlist.levellocationid,
    studentquarterlist.levellocationname,
    studentquarterlist.sublevelid,
    studentquarterlist.sublevelname,
    studentquarterlist.specialcharges,
    studentquarterlist.degreeid,
    studentquarterlist.degreename,
    studentquarterlist.studentdegreeid,
    studentquarterlist.completed,
    studentquarterlist.started,
    studentquarterlist.cleared,
    studentquarterlist.clearedate,
    studentquarterlist.graduated,
    studentquarterlist.graduatedate,
    studentquarterlist.dropout,
    studentquarterlist.transferin,
    studentquarterlist.transferout,
    studentquarterlist.mathplacement,
    studentquarterlist.englishplacement,
    studentquarterlist.quarterid,
    studentquarterlist.quarteryear,
    studentquarterlist.quarter,
    studentquarterlist.qstart,
    studentquarterlist.qlatereg,
    studentquarterlist.qlatechange,
    studentquarterlist.qlastdrop,
    studentquarterlist.qend,
    studentquarterlist.active,
    studentquarterlist.feesline,
    studentquarterlist.resline,
    studentquarterlist.residenceid,
    studentquarterlist.residencename,
    studentquarterlist.capacity,
    studentquarterlist.defaultrate,
    studentquarterlist.residenceoffcampus,
    studentquarterlist.residencesex,
    studentquarterlist.residencedean,
    studentquarterlist.qresidenceid,
    studentquarterlist.residenceoption,
    studentquarterlist.qstudentid,
    studentquarterlist.approved,
    studentquarterlist.probation,
    studentquarterlist.roomnumber,
    studentquarterlist.finaceapproval,
    studentquarterlist.majorapproval,
    studentquarterlist.departapproval,
    studentquarterlist.overloadapproval,
    studentquarterlist.finalised,
    studentquarterlist.printed,
    studentquarterlist.hours,
    studentquarterlist.gpa,
    studentquarterlist.credit,
    studentquarterlist.cummcredit,
    studentquarterlist.cummgpa,
    studentquarterlist.prevquarter,
    studentquarterlist.newstudent,
    getprevcredit(studentquarterlist.studentdegreeid, studentquarterlist.prevquarter) AS prevcredit,
    getprevgpa(studentquarterlist.studentdegreeid, studentquarterlist.prevquarter) AS prevgpa
   FROM studentquarterlist;


ALTER TABLE public.studentquartersummary OWNER TO postgres;

--
-- Name: newstudentssummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW newstudentssummary AS
 SELECT studentquartersummary.quarterid,
    studentquartersummary.quarteryear,
    studentquartersummary.quarter,
        CASE
            WHEN (studentquartersummary.newstudent = true) THEN 'New'::text
            ELSE 'Continuing'::text
        END AS status,
    studentquartersummary.sex,
    'Student Status'::character varying AS defination,
    count(studentquartersummary.qstudentid) AS studentcount
   FROM studentquartersummary
  WHERE (studentquartersummary.approved = true)
  GROUP BY studentquartersummary.quarterid, studentquartersummary.quarteryear, studentquartersummary.quarter, studentquartersummary.newstudent, studentquartersummary.sex
  ORDER BY studentquartersummary.quarterid, studentquartersummary.quarteryear, studentquartersummary.quarter, studentquartersummary.newstudent, studentquartersummary.sex;


ALTER TABLE public.newstudentssummary OWNER TO postgres;

--
-- Name: studentmajorview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentmajorview AS
 SELECT studentdegreeview.religionid,
    studentdegreeview.religionname,
    studentdegreeview.denominationid,
    studentdegreeview.denominationname,
    studentdegreeview.schoolid AS studentschoolid,
    studentdegreeview.schoolname AS studentschoolname,
    studentdegreeview.studentid,
    studentdegreeview.studentname,
    studentdegreeview.nationality,
    studentdegreeview.nationalitycountry,
    studentdegreeview.sex,
    studentdegreeview.maritalstatus,
    studentdegreeview.birthdate,
    studentdegreeview.degreelevelid,
    studentdegreeview.degreelevelname,
    studentdegreeview.freshman,
    studentdegreeview.sophomore,
    studentdegreeview.junior,
    studentdegreeview.senior,
    studentdegreeview.levellocationid,
    studentdegreeview.levellocationname,
    studentdegreeview.sublevelid,
    studentdegreeview.sublevelname,
    studentdegreeview.specialcharges,
    studentdegreeview.degreeid,
    studentdegreeview.degreename,
    studentdegreeview.studentdegreeid,
    studentdegreeview.completed,
    studentdegreeview.started,
    studentdegreeview.cleared,
    studentdegreeview.clearedate,
    studentdegreeview.graduated,
    studentdegreeview.graduatedate,
    studentdegreeview.dropout,
    studentdegreeview.transferin,
    studentdegreeview.transferout,
    studentdegreeview.mathplacement,
    studentdegreeview.englishplacement,
    majorview.schoolid,
    majorview.schoolname,
    majorview.departmentid,
    majorview.departmentname,
    majorview.majorid,
    majorview.majorname,
    majorview.major AS domajor,
    majorview.minor AS dominor,
    majoroptions.majoroptionid,
    majoroptions.majoroptionname,
    majorview.electivecredit,
    majorview.majorminimal,
    majorview.minorminimum,
    majorview.coreminimum,
    studentmajors.studentmajorid,
    studentmajors.major,
    studentmajors.nondegree,
    studentmajors.premajor,
    studentmajors.primarymajor,
    studentmajors.details
   FROM (((studentdegreeview
     JOIN studentmajors ON ((studentdegreeview.studentdegreeid = studentmajors.studentdegreeid)))
     JOIN majorview ON (((studentmajors.majorid)::text = (majorview.majorid)::text)))
     LEFT JOIN majoroptions ON ((studentmajors.majoroptionid = majoroptions.majoroptionid)));


ALTER TABLE public.studentmajorview OWNER TO postgres;

--
-- Name: qstudentmajorview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentmajorview AS
 SELECT studentmajorview.religionid,
    studentmajorview.religionname,
    studentmajorview.denominationid,
    studentmajorview.denominationname,
    studentmajorview.schoolid AS studentschoolid,
    studentmajorview.schoolname AS studentschoolname,
    studentmajorview.studentid,
    studentmajorview.studentname,
    studentmajorview.nationality,
    studentmajorview.nationalitycountry,
    studentmajorview.sex,
    studentmajorview.maritalstatus,
    studentmajorview.birthdate,
    studentmajorview.degreelevelid,
    studentmajorview.degreelevelname,
    studentmajorview.freshman,
    studentmajorview.sophomore,
    studentmajorview.junior,
    studentmajorview.senior,
    studentmajorview.levellocationid,
    studentmajorview.levellocationname,
    studentmajorview.sublevelid,
    studentmajorview.sublevelname,
    studentmajorview.specialcharges,
    studentmajorview.degreeid,
    studentmajorview.degreename,
    studentmajorview.studentdegreeid,
    studentmajorview.completed,
    studentmajorview.started,
    studentmajorview.cleared,
    studentmajorview.clearedate,
    studentmajorview.graduated,
    studentmajorview.graduatedate,
    studentmajorview.dropout,
    studentmajorview.transferin,
    studentmajorview.transferout,
    studentmajorview.mathplacement,
    studentmajorview.englishplacement,
    studentmajorview.schoolid,
    studentmajorview.schoolname,
    studentmajorview.departmentid,
    studentmajorview.departmentname,
    studentmajorview.majorid,
    studentmajorview.majorname,
    studentmajorview.electivecredit,
    studentmajorview.domajor,
    studentmajorview.dominor,
    studentmajorview.majoroptionid,
    studentmajorview.majoroptionname,
    studentmajorview.primarymajor,
    studentmajorview.studentmajorid,
    studentmajorview.major,
    studentmajorview.nondegree,
    studentmajorview.premajor,
    qstudents.org_id,
    qstudents.qstudentid,
    qstudents.quarterid,
    qstudents.charges AS additionalcharges,
    qstudents.approved,
    qstudents.probation,
    qstudents.roomnumber,
    qstudents.currbalance,
    qstudents.finaceapproval,
    qstudents.majorapproval,
    qstudents.departapproval,
    qstudents.overloadapproval,
    qstudents.finalised,
    qstudents.printed,
    qstudents.noapproval,
    qstudents.exam_clear,
    qstudents.exam_clear_date,
    qstudents.exam_clear_balance,
    quarters.active,
    quarters.closed
   FROM ((studentmajorview
     JOIN qstudents ON ((studentmajorview.studentdegreeid = qstudents.studentdegreeid)))
     JOIN quarters ON (((qstudents.quarterid)::text = (quarters.quarterid)::text)));


ALTER TABLE public.qstudentmajorview OWNER TO postgres;

--
-- Name: religionsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW religionsummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.religionname,
    qstudentview.sex,
    'Religion'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.religionname, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.religionname, qstudentview.sex;


ALTER TABLE public.religionsummary OWNER TO postgres;

--
-- Name: residencesummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW residencesummary AS
 SELECT studentquarterview.quarterid,
    studentquarterview.quarteryear,
    studentquarterview.quarter,
    studentquarterview.residencename,
    studentquarterview.sex,
    'Residence'::character varying AS defination,
    count(studentquarterview.qstudentid) AS studentcount
   FROM studentquarterview
  WHERE (studentquarterview.approved = true)
  GROUP BY studentquarterview.quarterid, studentquarterview.quarteryear, studentquarterview.quarter, studentquarterview.residencename, studentquarterview.sex
  ORDER BY studentquarterview.quarterid, studentquarterview.quarteryear, studentquarterview.quarter, studentquarterview.residencename, studentquarterview.sex;


ALTER TABLE public.residencesummary OWNER TO postgres;

--
-- Name: schoolmajorsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW schoolmajorsummary AS
 SELECT qstudentmajorview.quarterid,
    "substring"((qstudentmajorview.quarterid)::text, 1, 9) AS quarteryear,
    "substring"((qstudentmajorview.quarterid)::text, 11, 2) AS quarter,
    majorview.schoolname,
    qstudentmajorview.sex,
    'School'::character varying AS defination,
    count(qstudentmajorview.qstudentid) AS studentcount
   FROM (qstudentmajorview
     JOIN majorview ON (((majorview.majorid)::text = (qstudentmajorview.majorid)::text)))
  GROUP BY qstudentmajorview.quarterid, "substring"((qstudentmajorview.quarterid)::text, 1, 9), "substring"((qstudentmajorview.quarterid)::text, 11, 2), majorview.schoolname, qstudentmajorview.sex
  ORDER BY qstudentmajorview.quarterid, "substring"((qstudentmajorview.quarterid)::text, 1, 9), "substring"((qstudentmajorview.quarterid)::text, 11, 2), majorview.schoolname, qstudentmajorview.sex;


ALTER TABLE public.schoolmajorsummary OWNER TO postgres;

--
-- Name: sublevelsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sublevelsummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.sublevelname,
    qstudentview.sex,
    'Sub Level'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.sublevelname, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.sublevelname, qstudentview.sex;


ALTER TABLE public.sublevelsummary OWNER TO postgres;

--
-- Name: fullsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW fullsummary AS
 SELECT schoolmajorsummary.quarterid,
    schoolmajorsummary.quarteryear,
    schoolmajorsummary.quarter,
    schoolmajorsummary.schoolname,
    schoolmajorsummary.sex,
    schoolmajorsummary.defination,
    schoolmajorsummary.studentcount
   FROM schoolmajorsummary
UNION
 SELECT levelsummary.quarterid,
    levelsummary.quarteryear,
    levelsummary.quarter,
    levelsummary.degreelevelname AS schoolname,
    levelsummary.sex,
    levelsummary.defination,
    levelsummary.studentcount
   FROM levelsummary
UNION
 SELECT sublevelsummary.quarterid,
    sublevelsummary.quarteryear,
    sublevelsummary.quarter,
    sublevelsummary.sublevelname AS schoolname,
    sublevelsummary.sex,
    sublevelsummary.defination,
    sublevelsummary.studentcount
   FROM sublevelsummary
UNION
 SELECT newstudentssummary.quarterid,
    newstudentssummary.quarteryear,
    newstudentssummary.quarter,
    newstudentssummary.status AS schoolname,
    newstudentssummary.sex,
    newstudentssummary.defination,
    newstudentssummary.studentcount
   FROM newstudentssummary
UNION
 SELECT religionsummary.quarterid,
    religionsummary.quarteryear,
    religionsummary.quarter,
    religionsummary.religionname AS schoolname,
    religionsummary.sex,
    religionsummary.defination,
    religionsummary.studentcount
   FROM religionsummary
UNION
 SELECT denominationsummary.quarterid,
    denominationsummary.quarteryear,
    denominationsummary.quarter,
    denominationsummary.denominationname AS schoolname,
    denominationsummary.sex,
    denominationsummary.defination,
    denominationsummary.studentcount
   FROM denominationsummary
UNION
 SELECT nationalitysummary.quarterid,
    nationalitysummary.quarteryear,
    nationalitysummary.quarter,
    nationalitysummary.nationalitycountry AS schoolname,
    nationalitysummary.sex,
    nationalitysummary.defination,
    nationalitysummary.studentcount
   FROM nationalitysummary
UNION
 SELECT residencesummary.quarterid,
    residencesummary.quarteryear,
    residencesummary.quarter,
    residencesummary.residencename AS schoolname,
    residencesummary.sex,
    residencesummary.defination,
    residencesummary.studentcount
   FROM residencesummary
UNION
 SELECT locationsummary.quarterid,
    locationsummary.quarteryear,
    locationsummary.quarter,
    locationsummary.levellocationname AS schoolname,
    locationsummary.sex,
    locationsummary.defination,
    locationsummary.studentcount
   FROM locationsummary;


ALTER TABLE public.fullsummary OWNER TO postgres;

--
-- Name: gradechangelist; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE gradechangelist (
    gradechangeid integer NOT NULL,
    qgradeid integer NOT NULL,
    entity_id integer,
    changedby character varying(50),
    oldgrade character varying(2),
    newgrade character varying(2),
    changedate timestamp without time zone DEFAULT now(),
    clientip character varying(25)
);


ALTER TABLE public.gradechangelist OWNER TO postgres;

--
-- Name: gradechangelist_gradechangeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE gradechangelist_gradechangeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.gradechangelist_gradechangeid_seq OWNER TO postgres;

--
-- Name: gradechangelist_gradechangeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE gradechangelist_gradechangeid_seq OWNED BY gradechangelist.gradechangeid;


--
-- Name: gradecountview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW gradecountview AS
 SELECT qstudents.studentdegreeid,
    qcourses.courseid,
    count(qcourses.qcourseid) AS coursecount
   FROM ((qgrades
     JOIN (qcourses
     JOIN courses ON (((qcourses.courseid)::text = (courses.courseid)::text))) ON ((qgrades.qcourseid = qcourses.qcourseid)))
     JOIN qstudents ON ((qgrades.qstudentid = qstudents.qstudentid)))
  WHERE ((((((((qgrades.gradeid)::text <> 'W'::text) AND ((qgrades.gradeid)::text <> 'AW'::text)) AND ((qgrades.gradeid)::text <> 'NG'::text)) AND (qgrades.dropped = false)) AND (qgrades.repeated = false)) AND (qstudents.approved = true)) AND (courses.norepeats = false))
  GROUP BY qstudents.studentdegreeid, qcourses.courseid;


ALTER TABLE public.gradecountview OWNER TO postgres;

--
-- Name: healthitems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE healthitems (
    healthitemid integer NOT NULL,
    healthitemname character varying(50),
    narrative character varying(240)
);


ALTER TABLE public.healthitems OWNER TO postgres;

--
-- Name: healthitems_healthitemid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE healthitems_healthitemid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.healthitems_healthitemid_seq OWNER TO postgres;

--
-- Name: healthitems_healthitemid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE healthitems_healthitemid_seq OWNED BY healthitems.healthitemid;


--
-- Name: qstudentlist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentlist AS
 SELECT students.studentid,
    students.schoolid,
    students.studentname,
    students.sex,
    students.nationality,
    students.maritalstatus,
    students.birthdate,
    students.email,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    studentdegrees.sublevelid,
    qstudents.qstudentid,
    qstudents.quarterid,
    qstudents.charges,
    qstudents.probation,
    qstudents.roomnumber,
    qstudents.currbalance,
    qstudents.finaceapproval,
    qstudents.firstinstalment,
    qstudents.firstdate,
    qstudents.secondinstalment,
    qstudents.seconddate,
    qstudents.financenarrative,
    qstudents.residencerefund,
    qstudents.feerefund,
    qstudents.finalised,
    qstudents.majorapproval,
    qstudents.chaplainapproval,
    qstudents.overloadapproval,
    qstudents.studentdeanapproval,
    qstudents.overloadhours,
    qstudents.intersession,
    qstudents.closed,
    qstudents.printed,
    qstudents.approved,
    "substring"((qstudents.quarterid)::text, 1, 9) AS academicyear
   FROM ((students
     JOIN studentdegrees ON (((students.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN qstudents ON ((studentdegrees.studentdegreeid = qstudents.studentdegreeid)));


ALTER TABLE public.qstudentlist OWNER TO postgres;

--
-- Name: studentsyearlist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentsyearlist AS
 SELECT qstudentlist.studentid,
    qstudentlist.studentname,
    qstudentlist.sex,
    qstudentlist.nationality,
    qstudentlist.maritalstatus,
    qstudentlist.birthdate,
    qstudentlist.studentdegreeid,
    qstudentlist.degreeid,
    qstudentlist.sublevelid,
    qstudentlist.academicyear,
    count(qstudentlist.qstudentid) AS quartersdone,
    getqstudentid(qstudentlist.studentdegreeid, ((qstudentlist.academicyear || '.1'::text))::character varying) AS qstudent1,
    getqstudentid(qstudentlist.studentdegreeid, ((qstudentlist.academicyear || '.2'::text))::character varying) AS qstudent2,
    getqstudentid(qstudentlist.studentdegreeid, ((qstudentlist.academicyear || '.3'::text))::character varying) AS qstudent3,
    getqstudentid(qstudentlist.studentdegreeid, ((qstudentlist.academicyear || '.4'::text))::character varying) AS qstudent4
   FROM qstudentlist
  WHERE ((qstudentlist.approved = true) AND (getcurrcredit(qstudentlist.qstudentid) >= (12)::double precision))
  GROUP BY qstudentlist.studentid, qstudentlist.studentname, qstudentlist.sex, qstudentlist.nationality, qstudentlist.maritalstatus, qstudentlist.birthdate, qstudentlist.studentdegreeid, qstudentlist.degreeid, qstudentlist.sublevelid, qstudentlist.academicyear;


ALTER TABLE public.studentsyearlist OWNER TO postgres;

--
-- Name: honorslist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW honorslist AS
 SELECT studentsyearlist.studentid,
    studentsyearlist.studentname,
    studentsyearlist.sex,
    studentsyearlist.nationality,
    studentsyearlist.maritalstatus,
    studentsyearlist.birthdate,
    studentsyearlist.studentdegreeid,
    studentsyearlist.degreeid,
    studentsyearlist.sublevelid,
    studentsyearlist.academicyear,
    studentsyearlist.quartersdone,
    studentsyearlist.qstudent1,
    studentsyearlist.qstudent2,
    studentsyearlist.qstudent3,
    studentsyearlist.qstudent4,
    getcurrgpa(studentsyearlist.qstudent1) AS gpa1,
    getcurrgpa(studentsyearlist.qstudent2) AS gpa2,
    getcurrgpa(studentsyearlist.qstudent3) AS gpa3,
    getcurrgpa(studentsyearlist.qstudent4) AS gpa4,
    getcummgpa(studentsyearlist.studentdegreeid, ((studentsyearlist.academicyear || '.1'::text))::character varying) AS cummgpa1,
    getcummgpa(studentsyearlist.studentdegreeid, ((studentsyearlist.academicyear || '.2'::text))::character varying) AS cummgpa2,
    getcummgpa(studentsyearlist.studentdegreeid, ((studentsyearlist.academicyear || '.3'::text))::character varying) AS cummgpa3,
    getcummgpa(studentsyearlist.studentdegreeid, ((studentsyearlist.academicyear || '.4'::text))::character varying) AS cummgpa4
   FROM studentsyearlist
  WHERE ((studentsyearlist.quartersdone > 1) AND (checkgrade(studentsyearlist.studentdegreeid, (studentsyearlist.academicyear)::character varying, (2.67)::double precision) = 0));


ALTER TABLE public.honorslist OWNER TO postgres;

--
-- Name: honorsview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW honorsview AS
 SELECT honorslist.studentid,
    honorslist.studentname,
    honorslist.sex,
    honorslist.nationality,
    honorslist.maritalstatus,
    honorslist.birthdate,
    honorslist.studentdegreeid,
    honorslist.degreeid,
    honorslist.sublevelid,
    honorslist.academicyear,
    honorslist.quartersdone,
    honorslist.qstudent1,
    honorslist.qstudent2,
    honorslist.qstudent3,
    honorslist.qstudent4,
    honorslist.gpa1,
    honorslist.gpa2,
    honorslist.gpa3,
    honorslist.gpa4,
    honorslist.cummgpa1,
    honorslist.cummgpa2,
    honorslist.cummgpa3,
    honorslist.cummgpa4,
    checkhonors(honorslist.gpa1, honorslist.gpa2, honorslist.gpa3, honorslist.gpa4) AS gpahonors,
    checkhonors(honorslist.cummgpa1, honorslist.cummgpa2, honorslist.cummgpa3, honorslist.cummgpa4) AS cummgpahonours
   FROM honorslist;


ALTER TABLE public.honorsview OWNER TO postgres;

--
-- Name: instructorview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW instructorview AS
 SELECT departmentview.schoolid,
    departmentview.schoolname,
    departmentview.departmentid,
    departmentview.departmentname,
    instructors.org_id,
    instructors.instructorid,
    instructors.instructorname
   FROM (departmentview
     JOIN instructors ON (((departmentview.departmentid)::text = (instructors.departmentid)::text)));


ALTER TABLE public.instructorview OWNER TO postgres;

--
-- Name: levellocations_levellocationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE levellocations_levellocationid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.levellocations_levellocationid_seq OWNER TO postgres;

--
-- Name: levellocations_levellocationid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE levellocations_levellocationid_seq OWNED BY levellocations.levellocationid;


--
-- Name: majorcontents_majorcontentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE majorcontents_majorcontentid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.majorcontents_majorcontentid_seq OWNER TO postgres;

--
-- Name: majorcontents_majorcontentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE majorcontents_majorcontentid_seq OWNED BY majorcontents.majorcontentid;


--
-- Name: majorgradeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW majorgradeview AS
 SELECT studentdegreeview.studentid,
    studentdegreeview.studentname,
    studentdegreeview.sex,
    studentdegreeview.degreelevelid,
    studentdegreeview.degreelevelname,
    studentdegreeview.levellocationid,
    studentdegreeview.levellocationname,
    studentdegreeview.sublevelid,
    studentdegreeview.sublevelname,
    studentdegreeview.degreeid,
    studentdegreeview.degreename,
    studentdegreeview.studentdegreeid,
    studentmajors.studentmajorid,
    studentmajors.major,
    studentmajors.nondegree,
    studentmajors.premajor,
    majorcontentview.departmentid,
    majorcontentview.departmentname,
    majorcontentview.majorid,
    majorcontentview.majorname,
    majorcontentview.courseid,
    majorcontentview.coursetitle,
    majorcontentview.contenttypeid,
    majorcontentview.contenttypename,
    majorcontentview.elective,
    majorcontentview.prerequisite,
    majorcontentview.majorcontentid,
    majorcontentview.premajor AS premajoritem,
    majorcontentview.minor,
    majorcontentview.gradeid AS mingrade,
    qgradeview.quarterid,
    qgradeview.qgradeid,
    qgradeview.qstudentid,
    qgradeview.gradeid,
    qgradeview.gpahours,
    qgradeview.gpa,
    qgradeview.instructorname
   FROM ((((studentdegreeview
     JOIN studentmajors ON ((studentdegreeview.studentdegreeid = studentmajors.studentdegreeid)))
     JOIN majorcontentview ON (((majorcontentview.majorid)::text = (studentmajors.majorid)::text)))
     JOIN qstudents ON ((qstudents.studentdegreeid = studentdegreeview.studentdegreeid)))
     JOIN qgradeview ON ((((qgradeview.courseid)::text = (majorcontentview.courseid)::text) AND (qgradeview.qstudentid = qstudents.qstudentid))))
  WHERE ((((NOT studentmajors.premajor) AND majorcontentview.premajor) = false) AND (((NOT studentmajors.nondegree) AND majorcontentview.prerequisite) = false));


ALTER TABLE public.majorgradeview OWNER TO postgres;

--
-- Name: majoroptcontents_majoroptcontentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE majoroptcontents_majoroptcontentid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.majoroptcontents_majoroptcontentid_seq OWNER TO postgres;

--
-- Name: majoroptcontents_majoroptcontentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE majoroptcontents_majoroptcontentid_seq OWNED BY majoroptcontents.majoroptcontentid;


--
-- Name: majoroptions_majoroptionid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE majoroptions_majoroptionid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.majoroptions_majoroptionid_seq OWNER TO postgres;

--
-- Name: majoroptions_majoroptionid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE majoroptions_majoroptionid_seq OWNED BY majoroptions.majoroptionid;


--
-- Name: marks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE marks (
    markid integer NOT NULL,
    grade character varying(2) NOT NULL,
    markweight integer DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.marks OWNER TO postgres;

--
-- Name: nationalityview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW nationalityview AS
 SELECT studentview.nationality,
    studentview.nationalitycountry
   FROM studentview
  GROUP BY studentview.nationality, studentview.nationalitycountry
  ORDER BY studentview.nationalitycountry;


ALTER TABLE public.nationalityview OWNER TO postgres;

--
-- Name: offers; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE offers (
    offer_id integer NOT NULL,
    entity_id integer,
    offer_name character varying(240),
    opening_date date NOT NULL,
    closing_date date NOT NULL,
    positions integer,
    location character varying(50),
    details text
);


ALTER TABLE public.offers OWNER TO postgres;

--
-- Name: offers_offer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE offers_offer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.offers_offer_id_seq OWNER TO postgres;

--
-- Name: offers_offer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE offers_offer_id_seq OWNED BY offers.offer_id;


--
-- Name: optiontimes_optiontimeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE optiontimes_optiontimeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.optiontimes_optiontimeid_seq OWNER TO postgres;

--
-- Name: optiontimes_optiontimeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE optiontimes_optiontimeid_seq OWNED BY optiontimes.optiontimeid;


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
    details text
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
-- Name: registrations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE registrations (
    registrationid integer NOT NULL,
    markid integer,
    entity_id integer,
    degreeid character varying(12),
    majorid character varying(12),
    sublevelid character varying(12),
    county_id integer,
    org_id integer,
    entry_form_id integer,
    session_id character varying(12),
    email character varying(120),
    entrypass character varying(32) DEFAULT md5('enter'::text) NOT NULL,
    firstpass character varying(32) DEFAULT first_password() NOT NULL,
    existingid character varying(12),
    scheduledate date DEFAULT ('now'::text)::date NOT NULL,
    applicationdate date DEFAULT ('now'::text)::date NOT NULL,
    accepted boolean DEFAULT false NOT NULL,
    premajor boolean DEFAULT false NOT NULL,
    submitapplication boolean DEFAULT false NOT NULL,
    submitdate timestamp without time zone,
    isaccepted boolean DEFAULT false NOT NULL,
    isreported boolean DEFAULT false NOT NULL,
    isdeferred boolean DEFAULT false NOT NULL,
    isrejected boolean DEFAULT false NOT NULL,
    evaluationdate date,
    accepteddate date,
    reported boolean DEFAULT false NOT NULL,
    reporteddate date,
    denominationid character varying(12),
    mname character varying(50),
    fname character varying(50),
    fdenominationid character varying(12),
    mdenominationid character varying(12),
    foccupation character varying(50),
    fnationalityid character(2),
    moccupation character varying(50),
    mnationalityid character(2),
    parentchurch boolean,
    parentemployer character varying(120),
    birthdate date NOT NULL,
    baptismdate date,
    lastname character varying(50) NOT NULL,
    firstname character varying(50) NOT NULL,
    middlename character varying(50),
    sex character varying(1),
    maritalstatus character varying(2),
    nationalityid character(2),
    citizenshipid character(2),
    residenceid character(2),
    firstlanguage character varying(50),
    otherlanguages character varying(120),
    churchname character varying(50),
    churcharea character varying(50),
    churchaddress text,
    handicap character varying(120),
    personalhealth character varying(50),
    smoke boolean,
    drink boolean,
    drugs boolean,
    hsmoke boolean,
    hdrink boolean,
    hdrugs boolean,
    attendedprimary character varying(50),
    attendedsecondary character varying(50),
    expelled boolean,
    previousrecord character varying(50),
    workexperience character varying(50),
    employername character varying(50),
    postion character varying(50),
    attendedueab boolean DEFAULT false NOT NULL,
    attendeddate date,
    dateemployed date,
    campusresidence character varying(50),
    details text
);


ALTER TABLE public.registrations OWNER TO postgres;

--
-- Name: parentsview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW parentsview AS
 SELECT registrations.fname,
    registrations.mname,
    registrations.fdenominationid,
    registrations.mdenominationid,
    registrations.registrationid
   FROM registrations;


ALTER TABLE public.parentsview OWNER TO postgres;

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
-- Name: prerequisites; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE prerequisites (
    prerequisiteid integer NOT NULL,
    courseid character varying(12) NOT NULL,
    precourseid character varying(12) NOT NULL,
    gradeid character varying(2) NOT NULL,
    bulletingid integer NOT NULL,
    optionlevel integer DEFAULT 1 NOT NULL,
    narrative character varying(120)
);


ALTER TABLE public.prerequisites OWNER TO postgres;

--
-- Name: prerequisites_prerequisiteid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE prerequisites_prerequisiteid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.prerequisites_prerequisiteid_seq OWNER TO postgres;

--
-- Name: prerequisites_prerequisiteid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE prerequisites_prerequisiteid_seq OWNED BY prerequisites.prerequisiteid;


--
-- Name: prereqview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW prereqview AS
 SELECT courses.courseid,
    courses.coursetitle,
    prerequisites.prerequisiteid,
    prerequisites.precourseid,
    prerequisites.optionlevel,
    prerequisites.narrative,
    grades.gradeid,
    grades.gradeweight,
    bulleting.bulletingid,
    bulleting.bulletingname,
    bulleting.startingquarter,
    bulleting.endingquarter
   FROM (((courses
     JOIN prerequisites ON (((courses.courseid)::text = (prerequisites.courseid)::text)))
     JOIN grades ON (((prerequisites.gradeid)::text = (grades.gradeid)::text)))
     JOIN bulleting ON ((prerequisites.bulletingid = bulleting.bulletingid)));


ALTER TABLE public.prereqview OWNER TO postgres;

--
-- Name: prerequisiteview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW prerequisiteview AS
 SELECT courses.courseid AS precourseid,
    courses.coursetitle AS precoursetitle,
    prereqview.courseid,
    prereqview.coursetitle,
    prereqview.prerequisiteid,
    prereqview.optionlevel,
    prereqview.narrative,
    prereqview.gradeid,
    prereqview.gradeweight,
    prereqview.bulletingid,
    prereqview.bulletingname,
    prereqview.startingquarter,
    prereqview.endingquarter
   FROM (courses
     JOIN prereqview ON (((courses.courseid)::text = (prereqview.precourseid)::text)))
  ORDER BY prereqview.courseid, prereqview.optionlevel;


ALTER TABLE public.prerequisiteview OWNER TO postgres;

--
-- Name: primarymajorview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW primarymajorview AS
 SELECT schools.schoolid,
    schools.schoolname,
    departments.departmentid,
    departments.departmentname,
    majors.majorid,
    majors.majorname,
    studentmajors.studentdegreeid
   FROM (((schools
     JOIN departments ON (((schools.schoolid)::text = (departments.schoolid)::text)))
     JOIN majors ON (((departments.departmentid)::text = (majors.departmentid)::text)))
     JOIN studentmajors ON (((majors.majorid)::text = (studentmajors.majorid)::text)))
  WHERE ((studentmajors.major = true) AND (studentmajors.primarymajor = true));


ALTER TABLE public.primarymajorview OWNER TO postgres;

--
-- Name: primajorstudentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW primajorstudentview AS
 SELECT students.org_id,
    students.studentid,
    students.studentname,
    students.accountnumber,
    students.nationality,
    students.sex,
    students.maritalstatus,
    students.birthdate,
    students.onprobation,
    students.offcampus,
    studentdegrees.studentdegreeid,
    studentdegrees.completed,
    studentdegrees.started,
    studentdegrees.graduated,
    primarymajorview.schoolid,
    primarymajorview.schoolname,
    primarymajorview.departmentid,
    primarymajorview.departmentname,
    primarymajorview.majorid,
    primarymajorview.majorname
   FROM ((students
     JOIN studentdegrees ON (((students.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN primarymajorview ON ((studentdegrees.studentdegreeid = primarymajorview.studentdegreeid)))
  WHERE (studentdegrees.completed = false);


ALTER TABLE public.primajorstudentview OWNER TO postgres;

--
-- Name: printedstudentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW printedstudentview AS
 SELECT qstudentview.religionid,
    qstudentview.religionname,
    qstudentview.denominationid,
    qstudentview.denominationname,
    qstudentview.schoolid,
    qstudentview.schoolname,
    qstudentview.studentid,
    qstudentview.studentname,
    qstudentview.address,
    qstudentview.zipcode,
    qstudentview.town,
    qstudentview.addresscountry,
    qstudentview.telno,
    qstudentview.email,
    qstudentview.guardianname,
    qstudentview.gaddress,
    qstudentview.gzipcode,
    qstudentview.gtown,
    qstudentview.gaddresscountry,
    qstudentview.gtelno,
    qstudentview.gemail,
    qstudentview.accountnumber,
    qstudentview.nationality,
    qstudentview.nationalitycountry,
    qstudentview.sex,
    qstudentview.maritalstatus,
    qstudentview.birthdate,
    qstudentview.firstpass,
    qstudentview.alumnae,
    qstudentview.postcontacts,
    qstudentview.onprobation,
    qstudentview.offcampus,
    qstudentview.currentcontact,
    qstudentview.currentemail,
    qstudentview.currenttel,
    qstudentview.degreelevelid,
    qstudentview.degreelevelname,
    qstudentview.freshman,
    qstudentview.sophomore,
    qstudentview.junior,
    qstudentview.senior,
    qstudentview.levellocationid,
    qstudentview.levellocationname,
    qstudentview.sublevelid,
    qstudentview.sublevelname,
    qstudentview.specialcharges,
    qstudentview.degreeid,
    qstudentview.degreename,
    qstudentview.studentdegreeid,
    qstudentview.completed,
    qstudentview.started,
    qstudentview.cleared,
    qstudentview.clearedate,
    qstudentview.graduated,
    qstudentview.graduatedate,
    qstudentview.dropout,
    qstudentview.transferin,
    qstudentview.transferout,
    qstudentview.mathplacement,
    qstudentview.englishplacement,
    qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.qstart,
    qstudentview.qlatereg,
    qstudentview.qlatechange,
    qstudentview.qlastdrop,
    qstudentview.qend,
    qstudentview.active,
    qstudentview.feesline,
    qstudentview.resline,
    qstudentview.residenceid,
    qstudentview.residencename,
    qstudentview.capacity,
    qstudentview.defaultrate,
    qstudentview.residenceoffcampus,
    qstudentview.residencesex,
    qstudentview.residencedean,
    qstudentview.qresidenceid,
    qstudentview.residenceoption,
    qstudentview.qstudentid,
    qstudentview.approved,
    qstudentview.probation,
    qstudentview.roomnumber,
    qstudentview.finaceapproval,
    qstudentview.majorapproval,
    qstudentview.departapproval,
    qstudentview.overloadapproval,
    qstudentview.finalised,
    qstudentview.printed,
    qstudentview.org_id,
    majors.majorname
   FROM (qstudentview
     LEFT JOIN (studentmajors
     JOIN majors ON (((studentmajors.majorid)::text = (majors.majorid)::text))) ON ((qstudentview.studentdegreeid = studentmajors.studentdegreeid)))
  WHERE (((qstudentview.active = true) AND (qstudentview.finalised = true)) AND (qstudentview.printed = true));


ALTER TABLE public.printedstudentview OWNER TO postgres;

--
-- Name: qassettimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qassettimetableview AS
 SELECT qtimetableview.assetid,
    qtimetableview.assetname,
    qtimetableview.location,
    qtimetableview.building,
    qtimetableview.capacity,
    qtimetableview.qcourseid,
    qtimetableview.courseid,
    qtimetableview.coursetitle,
    qtimetableview.instructorid,
    qtimetableview.instructorname,
    qtimetableview.quarterid,
    qtimetableview.maxclass,
    qtimetableview.classoption,
    qtimetableview.optiontimeid,
    qtimetableview.optiontimename,
    qtimetableview.qtimetableid,
    qtimetableview.starttime,
    qtimetableview.endtime,
    qtimetableview.lab,
    qtimetableview.details,
    qtimetableview.cmonday,
    qtimetableview.ctuesday,
    qtimetableview.cwednesday,
    qtimetableview.cthursday,
    qtimetableview.cfriday,
    qtimetableview.csaturday,
    qtimetableview.csunday,
    gettimeassetcount(qtimetableview.assetid, qtimetableview.starttime, qtimetableview.endtime, qtimetableview.cmonday, qtimetableview.ctuesday, qtimetableview.cwednesday, qtimetableview.cthursday, qtimetableview.cfriday, qtimetableview.csaturday, qtimetableview.csunday, qtimetableview.quarterid) AS timeassetcount
   FROM qtimetableview
  ORDER BY qtimetableview.assetid;


ALTER TABLE public.qassettimetableview OWNER TO postgres;

--
-- Name: qcalendar; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qcalendar (
    qcalendarid integer NOT NULL,
    quarterid character varying(12) NOT NULL,
    sublevelid character varying(12) NOT NULL,
    org_id integer,
    qdate date NOT NULL,
    event character varying(120),
    details text
);


ALTER TABLE public.qcalendar OWNER TO postgres;

--
-- Name: qcalendar_qcalendarid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qcalendar_qcalendarid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qcalendar_qcalendarid_seq OWNER TO postgres;

--
-- Name: qcalendar_qcalendarid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qcalendar_qcalendarid_seq OWNED BY qcalendar.qcalendarid;


--
-- Name: qcalendarview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcalendarview AS
 SELECT sublevelview.degreelevelid,
    sublevelview.degreelevelname,
    sublevelview.sublevelid,
    sublevelview.sublevelname,
    qcalendar.org_id,
    qcalendar.qcalendarid,
    qcalendar.quarterid,
    qcalendar.qdate,
    qcalendar.event,
    qcalendar.details
   FROM (sublevelview
     JOIN qcalendar ON (((sublevelview.sublevelid)::text = (qcalendar.sublevelid)::text)));


ALTER TABLE public.qcalendarview OWNER TO postgres;

--
-- Name: qcoursecheckpass; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcoursecheckpass AS
 SELECT coursechecklist.orderid,
    coursechecklist.studentid,
    coursechecklist.studentdegreeid,
    coursechecklist.degreeid,
    coursechecklist.description,
    coursechecklist.minor,
    coursechecklist.elective,
    coursechecklist.gradeid,
    coursechecklist.gradeweight,
    coursechecklist.courseweight,
    coursechecklist.coursepased,
    coursechecklist.prereqpassed,
    qcourseview.org_id,
    qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.degreelevelid,
    qcourseview.degreelevelname,
    qcourseview.coursetypeid,
    qcourseview.coursetypename,
    qcourseview.courseid,
    qcourseview.credithours,
    qcourseview.maxcredit,
    qcourseview.iscurrent,
    qcourseview.nogpa,
    qcourseview.yeartaken,
    qcourseview.mathplacement,
    qcourseview.englishplacement,
    qcourseview.instructorid,
    qcourseview.quarterid,
    qcourseview.qcourseid,
    qcourseview.classoption,
    qcourseview.maxclass,
    qcourseview.labcourse,
    qcourseview.extracharge,
    qcourseview.approved,
    qcourseview.attendance,
    qcourseview.oldcourseid,
    qcourseview.fullattendance,
    qcourseview.instructorname,
    qcourseview.coursetitle,
    qcourseview.levellocationid,
    qcourseview.levellocationname
   FROM (coursechecklist
     JOIN qcourseview ON (((coursechecklist.courseid)::text = (qcourseview.courseid)::text)))
  WHERE ((((qcourseview.active = true) AND (qcourseview.approved = false)) AND (coursechecklist.coursepased = false)) AND (coursechecklist.prereqpassed = true));


ALTER TABLE public.qcoursecheckpass OWNER TO postgres;

--
-- Name: qcourseitems; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qcourseitems (
    qcourseitemid integer NOT NULL,
    qcourseid integer NOT NULL,
    org_id integer,
    qcourseitemname character varying(50),
    markratio double precision NOT NULL,
    totalmarks integer NOT NULL,
    given date,
    deadline date,
    details text
);


ALTER TABLE public.qcourseitems OWNER TO postgres;

--
-- Name: qcourseitems_qcourseitemid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qcourseitems_qcourseitemid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qcourseitems_qcourseitemid_seq OWNER TO postgres;

--
-- Name: qcourseitems_qcourseitemid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qcourseitems_qcourseitemid_seq OWNED BY qcourseitems.qcourseitemid;


--
-- Name: qcourseitemview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcourseitemview AS
 SELECT qcourseview.org_id,
    qcourseview.qcourseid,
    qcourseview.courseid,
    qcourseview.coursetitle,
    qcourseview.instructorname,
    qcourseview.quarterid,
    qcourseview.classoption,
    qcourseitems.qcourseitemid,
    qcourseitems.qcourseitemname,
    qcourseitems.markratio,
    qcourseitems.totalmarks,
    qcourseitems.given,
    qcourseitems.deadline,
    qcourseitems.details
   FROM (qcourseview
     JOIN qcourseitems ON ((qcourseview.qcourseid = qcourseitems.qcourseid)));


ALTER TABLE public.qcourseitemview OWNER TO postgres;

--
-- Name: qcoursemarks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qcoursemarks (
    qcoursemarkid integer NOT NULL,
    qgradeid integer NOT NULL,
    qcourseitemid integer NOT NULL,
    org_id integer,
    approved boolean DEFAULT false NOT NULL,
    submited date,
    markdate date,
    marks double precision DEFAULT 0 NOT NULL,
    details text
);


ALTER TABLE public.qcoursemarks OWNER TO postgres;

--
-- Name: qcoursemarks_qcoursemarkid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qcoursemarks_qcoursemarkid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qcoursemarks_qcoursemarkid_seq OWNER TO postgres;

--
-- Name: qcoursemarks_qcoursemarkid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qcoursemarks_qcoursemarkid_seq OWNED BY qcoursemarks.qcoursemarkid;


--
-- Name: qcoursemarkview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcoursemarkview AS
 SELECT studentgradeview.schoolid,
    studentgradeview.schoolname,
    studentgradeview.studentid,
    studentgradeview.studentname,
    studentgradeview.email,
    studentgradeview.degreelevelid,
    studentgradeview.degreelevelname,
    studentgradeview.sublevelid,
    studentgradeview.sublevelname,
    studentgradeview.degreeid,
    studentgradeview.degreename,
    studentgradeview.studentdegreeid,
    studentgradeview.completed,
    studentgradeview.started,
    studentgradeview.cleared,
    studentgradeview.clearedate,
    studentgradeview.quarterid,
    studentgradeview.fullattendance,
    studentgradeview.instructorname,
    studentgradeview.coursetitle,
    studentgradeview.classoption,
    studentgradeview.qgradeid,
    studentgradeview.hours,
    studentgradeview.credit,
    studentgradeview.crs_approved,
    studentgradeview.dropped,
    studentgradeview.gradeid,
    studentgradeview.gradeweight,
    studentgradeview.minrange,
    studentgradeview.maxrange,
    studentgradeview.gpacount,
    studentgradeview.submit_grades,
    studentgradeview.submit_date,
    studentgradeview.approved_grades,
    studentgradeview.approve_date,
    studentgradeview.departmentchange,
    studentgradeview.registrychange,
    qcoursemarks.qcoursemarkid,
    qcoursemarks.approved,
    qcoursemarks.submited,
    qcoursemarks.markdate,
    qcoursemarks.marks,
    qcoursemarks.details,
    qcourseitems.qcourseitemid,
    qcourseitems.qcourseitemname,
    qcourseitems.markratio,
    qcourseitems.totalmarks,
    qcourseitems.given,
    qcourseitems.deadline,
    qcourseitems.details AS itemdetails
   FROM ((studentgradeview
     JOIN qcoursemarks ON ((studentgradeview.qgradeid = qcoursemarks.qgradeid)))
     JOIN qcourseitems ON ((qcoursemarks.qcourseitemid = qcourseitems.qcourseitemid)));


ALTER TABLE public.qcoursemarkview OWNER TO postgres;

--
-- Name: qcourses_qcourseid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qcourses_qcourseid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qcourses_qcourseid_seq OWNER TO postgres;

--
-- Name: qcourses_qcourseid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qcourses_qcourseid_seq OWNED BY qcourses.qcourseid;


--
-- Name: qcoursesummarya; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcoursesummarya AS
 SELECT studentgradeview.degreelevelid,
    studentgradeview.degreelevelname,
    studentgradeview.levellocationid,
    studentgradeview.levellocationname,
    studentgradeview.sublevelid,
    studentgradeview.sublevelname,
    studentgradeview.crs_schoolid,
    studentgradeview.crs_schoolname,
    studentgradeview.crs_departmentid,
    studentgradeview.crs_departmentname,
    studentgradeview.quarterid,
    studentgradeview.qcourseid,
    studentgradeview.coursetypeid,
    studentgradeview.coursetypename,
    studentgradeview.courseid,
    studentgradeview.credithours,
    studentgradeview.iscurrent,
    studentgradeview.instructorname,
    studentgradeview.coursetitle,
    studentgradeview.classoption,
    studentgradeview.intersession,
    count(studentgradeview.qgradeid) AS enrolment,
    sum(studentgradeview.chargehours) AS sumchargehours,
    sum(studentgradeview.unitfees) AS sumunitfees,
    sum(studentgradeview.labfees) AS sumlabfees,
    sum(studentgradeview.extracharge) AS sumextracharge
   FROM studentgradeview
  WHERE ((((((studentgradeview.finaceapproval = true) AND (studentgradeview.dropped = false)) AND ((studentgradeview.gradeid)::text <> 'W'::text)) AND ((studentgradeview.gradeid)::text <> 'AW'::text)) AND (studentgradeview.withdraw = false)) AND (studentgradeview.ac_withdraw = false))
  GROUP BY studentgradeview.degreelevelid, studentgradeview.degreelevelname, studentgradeview.levellocationid, studentgradeview.levellocationname, studentgradeview.sublevelid, studentgradeview.sublevelname, studentgradeview.crs_schoolid, studentgradeview.crs_schoolname, studentgradeview.crs_departmentid, studentgradeview.crs_departmentname, studentgradeview.quarterid, studentgradeview.qcourseid, studentgradeview.coursetypeid, studentgradeview.coursetypename, studentgradeview.courseid, studentgradeview.credithours, studentgradeview.iscurrent, studentgradeview.instructorname, studentgradeview.coursetitle, studentgradeview.classoption, studentgradeview.intersession;


ALTER TABLE public.qcoursesummarya OWNER TO postgres;

--
-- Name: qcoursesummaryb; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcoursesummaryb AS
 SELECT studentgradeview.degreelevelid,
    studentgradeview.degreelevelname,
    studentgradeview.crs_schoolid,
    studentgradeview.crs_schoolname,
    studentgradeview.crs_departmentid,
    studentgradeview.crs_departmentname,
    studentgradeview.quarterid,
    studentgradeview.qcourseid,
    studentgradeview.coursetypeid,
    studentgradeview.coursetypename,
    studentgradeview.courseid,
    studentgradeview.credithours,
    studentgradeview.iscurrent,
    studentgradeview.instructorname,
    studentgradeview.coursetitle,
    studentgradeview.classoption,
    studentgradeview.intersession,
    count(studentgradeview.qgradeid) AS enrolment,
    sum(studentgradeview.chargehours) AS sumchargehours,
    sum(studentgradeview.unitfees) AS sumunitfees,
    sum(studentgradeview.labfees) AS sumlabfees,
    sum(studentgradeview.extracharge) AS sumextracharge
   FROM studentgradeview
  WHERE ((((((studentgradeview.finaceapproval = true) AND (studentgradeview.dropped = false)) AND ((studentgradeview.gradeid)::text <> 'W'::text)) AND ((studentgradeview.gradeid)::text <> 'AW'::text)) AND (studentgradeview.withdraw = false)) AND (studentgradeview.ac_withdraw = false))
  GROUP BY studentgradeview.degreelevelid, studentgradeview.degreelevelname, studentgradeview.crs_schoolid, studentgradeview.crs_schoolname, studentgradeview.crs_departmentid, studentgradeview.crs_departmentname, studentgradeview.quarterid, studentgradeview.qcourseid, studentgradeview.coursetypeid, studentgradeview.coursetypename, studentgradeview.courseid, studentgradeview.credithours, studentgradeview.iscurrent, studentgradeview.instructorname, studentgradeview.coursetitle, studentgradeview.classoption, studentgradeview.intersession;


ALTER TABLE public.qcoursesummaryb OWNER TO postgres;

--
-- Name: qcoursesummaryc; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcoursesummaryc AS
 SELECT studentgradeview.crs_schoolid,
    studentgradeview.crs_schoolname,
    studentgradeview.crs_departmentid,
    studentgradeview.crs_departmentname,
    studentgradeview.crs_degreelevelid,
    studentgradeview.crs_degreelevelname,
    studentgradeview.quarterid,
    studentgradeview.qcourseid,
    studentgradeview.coursetypeid,
    studentgradeview.coursetypename,
    studentgradeview.courseid,
    studentgradeview.credithours,
    studentgradeview.iscurrent,
    studentgradeview.instructorname,
    studentgradeview.coursetitle,
    studentgradeview.classoption,
    studentgradeview.intersession,
    count(studentgradeview.qgradeid) AS enrolment,
    sum(studentgradeview.chargehours) AS sumchargehours,
    sum(studentgradeview.unitfees) AS sumunitfees,
    sum(studentgradeview.labfees) AS sumlabfees,
    sum(studentgradeview.extracharge) AS sumextracharge
   FROM studentgradeview
  WHERE ((((((studentgradeview.finaceapproval = true) AND (studentgradeview.dropped = false)) AND ((studentgradeview.gradeid)::text <> 'W'::text)) AND ((studentgradeview.gradeid)::text <> 'AW'::text)) AND (studentgradeview.withdraw = false)) AND (studentgradeview.ac_withdraw = false))
  GROUP BY studentgradeview.crs_schoolid, studentgradeview.crs_schoolname, studentgradeview.crs_departmentid, studentgradeview.crs_departmentname, studentgradeview.crs_degreelevelid, studentgradeview.crs_degreelevelname, studentgradeview.quarterid, studentgradeview.qcourseid, studentgradeview.coursetypeid, studentgradeview.coursetypename, studentgradeview.courseid, studentgradeview.credithours, studentgradeview.iscurrent, studentgradeview.instructorname, studentgradeview.coursetitle, studentgradeview.classoption, studentgradeview.intersession;


ALTER TABLE public.qcoursesummaryc OWNER TO postgres;

--
-- Name: sabathclasses; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sabathclasses (
    sabathclassid integer NOT NULL,
    org_id integer,
    sabathclassoption character varying(50) NOT NULL,
    instructor character varying(50) NOT NULL,
    venue character varying(50),
    capacity integer DEFAULT 40 NOT NULL,
    iscurrent boolean DEFAULT true,
    details text
);


ALTER TABLE public.sabathclasses OWNER TO postgres;

--
-- Name: qstudentdegreeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentdegreeview AS
 SELECT students.studentid,
    students.schoolid,
    students.studentname,
    students.sex,
    students.nationality,
    students.maritalstatus,
    students.birthdate,
    students.email,
    studentdegrees.studentdegreeid,
    studentdegrees.degreeid,
    sublevels.sublevelid,
    sublevels.degreelevelid,
    sublevels.levellocationid,
    sublevels.sublevelname,
    sublevels.specialcharges,
    qstudents.org_id,
    qstudents.qstudentid,
    qstudents.quarterid,
    qstudents.charges,
    qstudents.probation,
    qstudents.roomnumber,
    qstudents.currbalance,
    qstudents.applicationtime,
    qstudents.residencerefund,
    qstudents.feerefund,
    qstudents.finalised,
    qstudents.finaceapproval,
    qstudents.majorapproval,
    qstudents.chaplainapproval,
    qstudents.studentdeanapproval,
    qstudents.overloadapproval,
    qstudents.overloadhours,
    qstudents.intersession,
    qstudents.closed,
    qstudents.printed,
    qstudents.approved,
    qstudents.noapproval,
    qstudents.exam_clear,
    qstudents.exam_clear_date,
    qstudents.exam_clear_balance,
    qresidenceview.residenceid,
    qresidenceview.residencename,
    qresidenceview.capacity,
    qresidenceview.defaultrate,
    qresidenceview.offcampus,
    qresidenceview.sex AS residencesex,
    qresidenceview.residencedean,
    qresidenceview.charges AS residencecharges,
    qresidenceview.qresidenceid,
    qresidenceview.residenceoption,
    ((qresidenceview.qresidenceid || 'R'::text) || qstudents.roomnumber) AS roomid,
    qresidenceview.quarter_name,
    sabathclasses.sabathclassid,
    sabathclasses.sabathclassoption,
    sabathclasses.instructor,
    sabathclasses.venue,
    sabathclasses.capacity AS sbcapacity
   FROM ((((students
     JOIN (studentdegrees
     JOIN sublevels ON (((studentdegrees.sublevelid)::text = (sublevels.sublevelid)::text))) ON (((students.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN qstudents ON ((studentdegrees.studentdegreeid = qstudents.studentdegreeid)))
     JOIN qresidenceview ON ((qstudents.qresidenceid = qresidenceview.qresidenceid)))
     JOIN sabathclasses ON ((qstudents.sabathclassid = sabathclasses.sabathclassid)));


ALTER TABLE public.qstudentdegreeview OWNER TO postgres;

--
-- Name: qcurrstudentdegreeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qcurrstudentdegreeview AS
 SELECT qstudentdegreeview.org_id,
    qstudentdegreeview.studentid,
    qstudentdegreeview.schoolid,
    qstudentdegreeview.studentname,
    qstudentdegreeview.sex,
    qstudentdegreeview.nationality,
    qstudentdegreeview.maritalstatus,
    qstudentdegreeview.birthdate,
    qstudentdegreeview.email,
    qstudentdegreeview.studentdegreeid,
    qstudentdegreeview.degreeid,
    qstudentdegreeview.sublevelid,
    qstudentdegreeview.qstudentid,
    qstudentdegreeview.quarterid,
    qstudentdegreeview.charges,
    qstudentdegreeview.probation,
    qstudentdegreeview.roomnumber,
    qstudentdegreeview.currbalance,
    qstudentdegreeview.finaceapproval,
    qstudentdegreeview.residencerefund,
    qstudentdegreeview.feerefund,
    qstudentdegreeview.finalised,
    qstudentdegreeview.majorapproval,
    qstudentdegreeview.chaplainapproval,
    qstudentdegreeview.overloadapproval,
    qstudentdegreeview.studentdeanapproval,
    qstudentdegreeview.overloadhours,
    qstudentdegreeview.intersession,
    qstudentdegreeview.closed,
    qstudentdegreeview.printed,
    qstudentdegreeview.approved,
    qstudentdegreeview.noapproval,
    qstudentdegreeview.exam_clear,
    qstudentdegreeview.exam_clear_date,
    qstudentdegreeview.exam_clear_balance,
    qstudentdegreeview.qresidenceid,
    qstudentdegreeview.residenceid,
    qstudentdegreeview.residencename,
    qstudentdegreeview.roomid,
    qstudentdegreeview.sabathclassid,
    qstudentdegreeview.sabathclassoption,
    qstudentdegreeview.instructor,
    qstudentdegreeview.venue,
    qstudentdegreeview.sbcapacity
   FROM (qstudentdegreeview
     JOIN quarters ON (((qstudentdegreeview.quarterid)::text = (quarters.quarterid)::text)))
  WHERE (quarters.active = true);


ALTER TABLE public.qcurrstudentdegreeview OWNER TO postgres;

--
-- Name: qexamtimetable; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qexamtimetable (
    qexamtimetableid integer NOT NULL,
    assetid integer NOT NULL,
    qcourseid integer NOT NULL,
    optiontimeid integer DEFAULT 0 NOT NULL,
    org_id integer,
    examdate date,
    starttime time without time zone NOT NULL,
    endtime time without time zone NOT NULL,
    lab boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.qexamtimetable OWNER TO postgres;

--
-- Name: qetimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qetimetableview AS
 SELECT assets.assetid,
    assets.assetname,
    assets.location,
    assets.building,
    assets.capacity,
    qcourseview.qcourseid,
    qcourseview.courseid,
    qcourseview.coursetitle,
    qcourseview.instructorid,
    qcourseview.instructorname,
    qcourseview.quarterid,
    qcourseview.maxclass,
    qcourseview.classoption,
    optiontimes.optiontimeid,
    optiontimes.optiontimename,
    qexamtimetable.org_id,
    qexamtimetable.qexamtimetableid,
    qexamtimetable.starttime,
    qexamtimetable.endtime,
    qexamtimetable.lab,
    qexamtimetable.examdate,
    qexamtimetable.details
   FROM (((assets
     JOIN qexamtimetable ON ((assets.assetid = qexamtimetable.assetid)))
     JOIN qcourseview ON ((qexamtimetable.qcourseid = qcourseview.qcourseid)))
     JOIN optiontimes ON ((qexamtimetable.optiontimeid = optiontimes.optiontimeid)))
  ORDER BY qexamtimetable.examdate, qexamtimetable.starttime;


ALTER TABLE public.qetimetableview OWNER TO postgres;

--
-- Name: qexamtimetable_qexamtimetableid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qexamtimetable_qexamtimetableid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qexamtimetable_qexamtimetableid_seq OWNER TO postgres;

--
-- Name: qexamtimetable_qexamtimetableid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qexamtimetable_qexamtimetableid_seq OWNED BY qexamtimetable.qexamtimetableid;


--
-- Name: selcourseview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW selcourseview AS
 SELECT courses.courseid,
    courses.coursetitle,
    courses.credithours,
    courses.nogpa,
    courses.yeartaken,
    courses.mathplacement,
    courses.englishplacement,
    courses.kiswahiliplacement,
    qcourses.qcourseid,
    qcourses.quarterid,
    qcourses.classoption,
    qcourses.maxclass,
    qcourses.labcourse,
    instructors.instructorid,
    instructors.instructorname,
    getqcoursestudents(qcourses.qcourseid) AS qcoursestudents,
    qgrades.qgradeid,
    qgrades.qstudentid,
    qgrades.gradeid,
    qgrades.hours,
    qgrades.credit,
    qgrades.approved,
    qgrades.approvedate,
    qgrades.askdrop,
    qgrades.askdropdate,
    qgrades.dropped,
    qgrades.dropdate,
    qgrades.repeated,
    qgrades.withdrawdate,
    qgrades.attendance,
    qgrades.optiontimeid,
    qgrades.narrative
   FROM ((((courses
     JOIN qcourses ON (((courses.courseid)::text = (qcourses.courseid)::text)))
     JOIN instructors ON (((qcourses.instructorid)::text = (instructors.instructorid)::text)))
     JOIN qgrades ON ((qgrades.qcourseid = qcourses.qcourseid)))
     JOIN quarters ON (((qcourses.quarterid)::text = (quarters.quarterid)::text)))
  WHERE ((quarters.active = true) AND (qgrades.dropped = false));


ALTER TABLE public.selcourseview OWNER TO postgres;

--
-- Name: qexamtimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qexamtimetableview AS
 SELECT selcourseview.courseid,
    selcourseview.coursetitle,
    selcourseview.credithours,
    selcourseview.nogpa,
    selcourseview.yeartaken,
    selcourseview.mathplacement AS crs_mathplacement,
    selcourseview.englishplacement AS crs_englishplacement,
    selcourseview.kiswahiliplacement AS crs_kiswahiliplacement,
    selcourseview.qcourseid,
    selcourseview.quarterid,
    selcourseview.classoption,
    selcourseview.maxclass,
    selcourseview.labcourse,
    selcourseview.instructorid,
    selcourseview.instructorname,
    selcourseview.qcoursestudents,
    selcourseview.qgradeid,
    selcourseview.qstudentid,
    selcourseview.gradeid,
    selcourseview.hours,
    selcourseview.credit,
    selcourseview.approved,
    selcourseview.approvedate,
    selcourseview.askdrop,
    selcourseview.askdropdate,
    selcourseview.dropped,
    selcourseview.dropdate,
    selcourseview.repeated,
    selcourseview.withdrawdate,
    selcourseview.attendance,
    selcourseview.optiontimeid,
    selcourseview.narrative,
    studentdegrees.studentdegreeid,
    studentdegrees.studentid,
    students.studentname,
    students.sex,
    studentdegrees.mathplacement,
    studentdegrees.englishplacement,
    studentdegrees.kiswahiliplacement,
    qexamtimetable.org_id,
    qexamtimetable.qexamtimetableid,
    qexamtimetable.examdate,
    qexamtimetable.starttime,
    qexamtimetable.endtime,
    qexamtimetable.lab
   FROM ((((selcourseview
     JOIN qstudents ON ((selcourseview.qstudentid = qstudents.qstudentid)))
     JOIN studentdegrees ON ((qstudents.studentdegreeid = studentdegrees.studentdegreeid)))
     JOIN students ON (((studentdegrees.studentid)::text = (students.studentid)::text)))
     JOIN qexamtimetable ON ((qexamtimetable.qcourseid = selcourseview.qcourseid)))
  WHERE ((qstudents.approved = true) AND ((selcourseview.gradeid)::text <> 'W'::text));


ALTER TABLE public.qexamtimetableview OWNER TO postgres;

--
-- Name: qgrades_qgradeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qgrades_qgradeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qgrades_qgradeid_seq OWNER TO postgres;

--
-- Name: qgrades_qgradeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qgrades_qgradeid_seq OWNED BY qgrades.qgradeid;


--
-- Name: qposting_logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE qposting_logs (
    qposting_log_id integer NOT NULL,
    qstudentid integer,
    sys_audit_trail_id integer,
    posted_type_id integer DEFAULT 1 NOT NULL,
    posted_date timestamp without time zone DEFAULT now() NOT NULL,
    psublevelid character varying(12),
    presidenceid character varying(12),
    phours real,
    punitcharge real,
    plabcharge real,
    pclinical_charge real,
    pexamfee real,
    pcourseextracharge real,
    pfeescharge real,
    presidencecharge real,
    ptotalfees real,
    narrative character varying(120)
);


ALTER TABLE public.qposting_logs OWNER TO postgres;

--
-- Name: qposting_logs_qposting_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qposting_logs_qposting_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qposting_logs_qposting_log_id_seq OWNER TO postgres;

--
-- Name: qposting_logs_qposting_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qposting_logs_qposting_log_id_seq OWNED BY qposting_logs.qposting_log_id;


--
-- Name: qprimajorstudentview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qprimajorstudentview AS
 SELECT primajorstudentview.org_id,
    primajorstudentview.studentid,
    primajorstudentview.studentname,
    primajorstudentview.accountnumber,
    primajorstudentview.nationality,
    primajorstudentview.sex,
    primajorstudentview.maritalstatus,
    primajorstudentview.birthdate,
    primajorstudentview.onprobation,
    primajorstudentview.offcampus,
    primajorstudentview.studentdegreeid,
    primajorstudentview.completed,
    primajorstudentview.started,
    primajorstudentview.graduated,
    primajorstudentview.departmentid,
    primajorstudentview.departmentname,
    primajorstudentview.majorid,
    primajorstudentview.majorname,
    primajorstudentview.schoolid,
    primajorstudentview.schoolname,
    qstudents.qstudentid,
    qstudents.quarterid,
    qstudents.majorapproval,
    qstudents.departapproval,
    qstudents.noapproval
   FROM (primajorstudentview
     JOIN (qstudents
     JOIN quarters ON (((qstudents.quarterid)::text = (quarters.quarterid)::text))) ON ((primajorstudentview.studentdegreeid = qstudents.studentdegreeid)))
  WHERE (((quarters.active = true) AND (qstudents.finalised = true)) AND (qstudents.majorapproval = false));


ALTER TABLE public.qprimajorstudentview OWNER TO postgres;

--
-- Name: residenceroom; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW residenceroom AS
 SELECT residences.residenceid,
    residences.residencename,
    residences.roomsize,
    residences.capacity,
    generate_series(1, (residences.capacity + 1)) AS roomnumber
   FROM residences;


ALTER TABLE public.residenceroom OWNER TO postgres;

--
-- Name: qresidenceroom; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qresidenceroom AS
 SELECT residenceroom.residenceid,
    residenceroom.residencename,
    residenceroom.roomsize,
    residenceroom.capacity,
    residenceroom.roomnumber,
    roomcount(qresidences.qresidenceid, residenceroom.roomnumber) AS roomcount,
    (residenceroom.roomsize - roomcount(qresidences.qresidenceid, residenceroom.roomnumber)) AS roombalance,
    qresidences.qresidenceid,
    qresidences.quarterid,
    qresidences.org_id,
    ((qresidences.qresidenceid || 'R'::text) || residenceroom.roomnumber) AS roomid
   FROM (residenceroom
     JOIN qresidences ON (((residenceroom.residenceid)::text = (qresidences.residenceid)::text)));


ALTER TABLE public.qresidenceroom OWNER TO postgres;

--
-- Name: qresidences_qresidenceid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qresidences_qresidenceid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qresidences_qresidenceid_seq OWNER TO postgres;

--
-- Name: qresidences_qresidenceid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qresidences_qresidenceid_seq OWNED BY qresidences.qresidenceid;


--
-- Name: qstudentmajorsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentmajorsummary AS
 SELECT qstudentmajorview.schoolid,
    qstudentmajorview.schoolname,
    qstudentmajorview.departmentid,
    qstudentmajorview.departmentname,
    qstudentmajorview.degreelevelid,
    qstudentmajorview.degreelevelname,
    qstudentmajorview.sublevelid,
    qstudentmajorview.sublevelname,
    qstudentmajorview.majorid,
    qstudentmajorview.majorname,
    qstudentmajorview.premajor,
    qstudentmajorview.major,
    qstudentmajorview.probation,
    qstudentmajorview.studentdegreeid,
    qstudentmajorview.primarymajor,
    qstudentmajorview.sex,
    qstudentmajorview.quarterid,
    count(qstudentmajorview.studentdegreeid) AS studentcount
   FROM qstudentmajorview
  GROUP BY qstudentmajorview.schoolid, qstudentmajorview.schoolname, qstudentmajorview.departmentid, qstudentmajorview.departmentname, qstudentmajorview.degreelevelid, qstudentmajorview.degreelevelname, qstudentmajorview.sublevelid, qstudentmajorview.sublevelname, qstudentmajorview.majorid, qstudentmajorview.majorname, qstudentmajorview.premajor, qstudentmajorview.major, qstudentmajorview.studentdegreeid, qstudentmajorview.primarymajor, qstudentmajorview.probation, qstudentmajorview.sex, qstudentmajorview.quarterid;


ALTER TABLE public.qstudentmajorsummary OWNER TO postgres;

--
-- Name: qstudentresroom; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentresroom AS
 SELECT students.studentid,
    students.studentname,
    students.sex,
    qstudents.qstudentid,
    qresidenceroom.residenceid,
    qresidenceroom.residencename,
    qresidenceroom.roomsize,
    qresidenceroom.capacity,
    qresidenceroom.roomnumber,
    qresidenceroom.roomcount,
    qresidenceroom.roombalance,
    qresidenceroom.roomid,
    qresidenceroom.qresidenceid,
    qresidenceroom.quarterid,
    qresidenceroom.org_id,
    quarters.closed,
    quarters.quarter_name
   FROM ((((students
     JOIN studentdegrees ON (((students.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN qstudents ON ((studentdegrees.studentdegreeid = qstudents.studentdegreeid)))
     JOIN qresidenceroom ON ((qstudents.qresidenceid = qresidenceroom.qresidenceid)))
     JOIN quarters ON (((qstudents.quarterid)::text = (quarters.quarterid)::text)))
  WHERE ((quarters.active = true) AND (qresidenceroom.roombalance > 0));


ALTER TABLE public.qstudentresroom OWNER TO postgres;

--
-- Name: qstudents_qstudentid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qstudents_qstudentid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qstudents_qstudentid_seq OWNER TO postgres;

--
-- Name: qstudents_qstudentid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qstudents_qstudentid_seq OWNED BY qstudents.qstudentid;


--
-- Name: qstudentsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qstudentsummary AS
 SELECT qstudentdegreeview.org_id,
    qstudentdegreeview.studentid,
    qstudentdegreeview.studentname,
    qstudentdegreeview.quarterid,
    qstudentdegreeview.approved,
    qstudentdegreeview.studentdegreeid,
    qstudentdegreeview.qstudentid,
    qstudentdegreeview.sex,
    qstudentdegreeview.nationality,
    qstudentdegreeview.maritalstatus,
    getcurrcredit(qstudentdegreeview.qstudentid) AS credit,
    getcurrgpa(qstudentdegreeview.qstudentid) AS gpa,
    getcummcredit(qstudentdegreeview.studentdegreeid, qstudentdegreeview.quarterid) AS cummcredit,
    getcummgpa(qstudentdegreeview.studentdegreeid, qstudentdegreeview.quarterid) AS cummgpa
   FROM qstudentdegreeview;


ALTER TABLE public.qstudentsummary OWNER TO postgres;

--
-- Name: qsummaryaview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qsummaryaview AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.sex,
    count(qstudentview.studentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.sex;


ALTER TABLE public.qsummaryaview OWNER TO postgres;

--
-- Name: qsummarybview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qsummarybview AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.degreelevelname,
    qstudentview.sex,
    count(qstudentview.studentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.degreelevelname, qstudentview.sex;


ALTER TABLE public.qsummarybview OWNER TO postgres;

--
-- Name: qsummarycview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qsummarycview AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.sublevelname,
    qstudentview.sex,
    count(qstudentview.studentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.sublevelname, qstudentview.sex;


ALTER TABLE public.qsummarycview OWNER TO postgres;

--
-- Name: qsummarydview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW qsummarydview AS
 SELECT qstudentview.quarteryear,
    qstudentview.sex,
    count(qstudentview.studentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarteryear, qstudentview.sex;


ALTER TABLE public.qsummarydview OWNER TO postgres;

--
-- Name: qtimetable_qtimetableid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE qtimetable_qtimetableid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.qtimetable_qtimetableid_seq OWNER TO postgres;

--
-- Name: qtimetable_qtimetableid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE qtimetable_qtimetableid_seq OWNED BY qtimetable.qtimetableid;


--
-- Name: quarterstats; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW quarterstats AS
 SELECT 1 AS statid,
    'Opened Applications'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  GROUP BY qstudents.quarterid
UNION
 SELECT 2 AS statid,
    'Paid Full Fees'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE ((studentquarterview.finalbalance >= ((-2000))::double precision) AND (studentquarterview.finaceapproval = true))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 3 AS statid,
    'Within Allowed Balance'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE (((studentquarterview.finalbalance < ((-2000))::double precision) AND (studentquarterview.finalbalance >= (((-1))::double precision * studentquarterview.feesline))) AND (studentquarterview.finaceapproval = true))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 4 AS statid,
    'Above Allowed Balance'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE ((studentquarterview.finalbalance >= (((-1))::double precision * studentquarterview.feesline)) AND (studentquarterview.finaceapproval = true))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 5 AS statid,
    'Below Allowed Balance'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE (studentquarterview.finalbalance < (((-1))::double precision * studentquarterview.feesline))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 6 AS statid,
    'Financially Approved'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  WHERE (qstudents.finaceapproval = true)
  GROUP BY qstudents.quarterid
UNION
 SELECT 7 AS statid,
    'Approved and Below Allowed Balance'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE ((studentquarterview.finalbalance < (((-1))::double precision * studentquarterview.feesline)) AND (studentquarterview.finaceapproval = true))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 8 AS statid,
    'Not Approved and Above Allowed Balance'::text AS narrative,
    count(studentquarterview.qstudentid) AS studentcount,
    studentquarterview.quarterid
   FROM studentquarterview
  WHERE ((studentquarterview.finalbalance >= (((-1))::double precision * studentquarterview.feesline)) AND (studentquarterview.finaceapproval = false))
  GROUP BY studentquarterview.quarterid
UNION
 SELECT 9 AS statid,
    'Closed Applications'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  WHERE (qstudents.finalised = true)
  GROUP BY qstudents.quarterid
UNION
 SELECT 10 AS statid,
    'Closed and not Finacially approved'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  WHERE ((qstudents.finalised = true) AND (qstudents.finaceapproval = false))
  GROUP BY qstudents.quarterid
UNION
 SELECT 11 AS statid,
    'Printed Applications'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  WHERE (qstudents.printed = true)
  GROUP BY qstudents.quarterid
UNION
 SELECT 12 AS statid,
    'Fully Registered'::text AS narrative,
    count(qstudents.qstudentid) AS studentcount,
    qstudents.quarterid
   FROM qstudents
  WHERE (qstudents.approved = true)
  GROUP BY qstudents.quarterid;


ALTER TABLE public.quarterstats OWNER TO postgres;

--
-- Name: regcontacts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE regcontacts (
    regcontactid integer NOT NULL,
    registrationid integer,
    contacttypeid integer,
    guardiancontact boolean DEFAULT false NOT NULL,
    regcontactname character varying(50),
    telephone character varying(50),
    fax character varying(50),
    address character varying(50),
    zipcode character varying(50),
    town character varying(50),
    countrycodeid character varying(2),
    email character varying(240),
    details text
);


ALTER TABLE public.regcontacts OWNER TO postgres;

--
-- Name: regcontacts_regcontactid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE regcontacts_regcontactid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.regcontacts_regcontactid_seq OWNER TO postgres;

--
-- Name: regcontacts_regcontactid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE regcontacts_regcontactid_seq OWNED BY regcontacts.regcontactid;


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
-- Name: regcontactview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW regcontactview AS
 SELECT contacttypes.contacttypeid,
    contacttypes.contacttypename,
    contacttypes.primarycontact,
    regcontacts.registrationid,
    regcontacts.regcontactid,
    regcontacts.guardiancontact,
    regcontacts.regcontactname,
    regcontacts.telephone,
    regcontacts.fax,
    regcontacts.address,
    regcontacts.zipcode,
    regcontacts.town,
    sys_countrys.sys_country_name AS countryname,
    regcontacts.email
   FROM ((contacttypes
     JOIN regcontacts ON ((contacttypes.contacttypeid = regcontacts.contacttypeid)))
     JOIN sys_countrys ON (((regcontacts.countrycodeid)::bpchar = sys_countrys.sys_country_id)));


ALTER TABLE public.regcontactview OWNER TO postgres;

--
-- Name: reghealth; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE reghealth (
    reghealthid integer NOT NULL,
    registrationid integer,
    healthitemid integer,
    narrative character varying(240)
);


ALTER TABLE public.reghealth OWNER TO postgres;

--
-- Name: reghealth_reghealthid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reghealth_reghealthid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reghealth_reghealthid_seq OWNER TO postgres;

--
-- Name: reghealth_reghealthid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reghealth_reghealthid_seq OWNED BY reghealth.reghealthid;


--
-- Name: reghealthview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW reghealthview AS
 SELECT healthitems.healthitemid,
    healthitems.healthitemname,
    reghealth.reghealthid,
    reghealth.registrationid,
    reghealth.narrative
   FROM (healthitems
     JOIN reghealth ON ((healthitems.healthitemid = reghealth.healthitemid)));


ALTER TABLE public.reghealthview OWNER TO postgres;

--
-- Name: registrations_registrationid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE registrations_registrationid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registrations_registrationid_seq OWNER TO postgres;

--
-- Name: registrations_registrationid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE registrations_registrationid_seq OWNED BY registrations.registrationid;


--
-- Name: registrationview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW registrationview AS
 SELECT registrations.registrationid,
    registrations.email,
    registrations.entrypass,
    registrations.firstpass,
    registrations.applicationdate,
    sys_countrys.sys_country_name AS nationality,
    registrations.sex,
    registrations.lastname,
    registrations.firstname,
    registrations.middlename,
    (((((registrations.lastname)::text || ', '::text) || (registrations.firstname)::text) || ' '::text) || (registrations.middlename)::text) AS fullname,
    registrations.existingid
   FROM (registrations
     JOIN sys_countrys ON ((registrations.nationalityid = sys_countrys.sys_country_id)));


ALTER TABLE public.registrationview OWNER TO postgres;

--
-- Name: registrymarks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE registrymarks (
    registrymarkid integer NOT NULL,
    registrationid integer NOT NULL,
    subjectid integer NOT NULL,
    markid integer NOT NULL,
    org_id integer,
    narrative character varying(240)
);


ALTER TABLE public.registrymarks OWNER TO postgres;

--
-- Name: registrymarks_registrymarkid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE registrymarks_registrymarkid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registrymarks_registrymarkid_seq OWNER TO postgres;

--
-- Name: registrymarks_registrymarkid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE registrymarks_registrymarkid_seq OWNED BY registrymarks.registrymarkid;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subjects (
    subjectid integer NOT NULL,
    subjectname character varying(25) NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.subjects OWNER TO postgres;

--
-- Name: registrymarkview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW registrymarkview AS
 SELECT registrationview.registrationid,
    registrationview.fullname,
    subjects.subjectid,
    subjects.subjectname,
    marks.markid,
    marks.grade,
    registrymarks.registrymarkid,
    registrymarks.narrative
   FROM (((registrationview
     JOIN registrymarks ON ((registrationview.registrationid = registrymarks.registrationid)))
     JOIN subjects ON ((registrymarks.subjectid = subjects.subjectid)))
     JOIN marks ON ((registrymarks.markid = marks.markid)));


ALTER TABLE public.registrymarkview OWNER TO postgres;

--
-- Name: registryschools; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE registryschools (
    registryschoolid integer NOT NULL,
    registrationid integer,
    org_id integer,
    primaryschool boolean,
    olevelschool boolean,
    schoolname character varying(50),
    address text,
    sdate date,
    edate date,
    narrative character varying(240)
);


ALTER TABLE public.registryschools OWNER TO postgres;

--
-- Name: registryschools_registryschoolid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE registryschools_registryschoolid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.registryschools_registryschoolid_seq OWNER TO postgres;

--
-- Name: registryschools_registryschoolid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE registryschools_registryschoolid_seq OWNED BY registryschools.registryschoolid;


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
-- Name: requesttypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requesttypes (
    requesttypeid integer NOT NULL,
    requesttypename character varying(50) NOT NULL,
    request_email character varying(240),
    toapprove boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.requesttypes OWNER TO postgres;

--
-- Name: requesttypes_requesttypeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requesttypes_requesttypeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requesttypes_requesttypeid_seq OWNER TO postgres;

--
-- Name: requesttypes_requesttypeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requesttypes_requesttypeid_seq OWNED BY requesttypes.requesttypeid;


--
-- Name: requirements; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE requirements (
    requirementid integer NOT NULL,
    majorid character varying(12) NOT NULL,
    subjectid integer NOT NULL,
    markid integer,
    narrative character varying(240)
);


ALTER TABLE public.requirements OWNER TO postgres;

--
-- Name: requirements_requirementid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE requirements_requirementid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.requirements_requirementid_seq OWNER TO postgres;

--
-- Name: requirements_requirementid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE requirements_requirementid_seq OWNED BY requirements.requirementid;


--
-- Name: requirementview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW requirementview AS
 SELECT majorview.schoolid,
    majorview.departmentid,
    majorview.departmentname,
    majorview.majorid,
    majorview.majorname,
    subjects.subjectid,
    subjects.subjectname,
    marks.markid,
    marks.grade,
    requirements.requirementid,
    requirements.narrative
   FROM (((majorview
     JOIN requirements ON (((majorview.majorid)::text = (requirements.majorid)::text)))
     JOIN subjects ON ((requirements.subjectid = subjects.subjectid)))
     JOIN marks ON ((requirements.markid = marks.markid)));


ALTER TABLE public.requirementview OWNER TO postgres;

--
-- Name: sabathclassview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sabathclassview AS
 SELECT sabathclasses.org_id,
    sabathclasses.sabathclassid,
    sabathclasses.sabathclassoption,
    sabathclasses.instructor,
    sabathclasses.venue,
    sabathclasses.capacity,
    getcurrsabathclass(sabathclasses.sabathclassid) AS classcount,
    (sabathclasses.capacity - getcurrsabathclass(sabathclasses.sabathclassid)) AS classbalance
   FROM sabathclasses
  WHERE (sabathclasses.iscurrent = true);


ALTER TABLE public.sabathclassview OWNER TO postgres;

--
-- Name: sabathclassavail; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sabathclassavail AS
 SELECT sabathclassview.org_id,
    sabathclassview.sabathclassid,
    sabathclassview.sabathclassoption,
    sabathclassview.instructor,
    sabathclassview.venue,
    sabathclassview.capacity,
    sabathclassview.classcount,
    sabathclassview.classbalance
   FROM sabathclassview
  WHERE (sabathclassview.classbalance > 0);


ALTER TABLE public.sabathclassavail OWNER TO postgres;

--
-- Name: sabathclasses_sabathclassid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sabathclasses_sabathclassid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sabathclasses_sabathclassid_seq OWNER TO postgres;

--
-- Name: sabathclasses_sabathclassid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sabathclasses_sabathclassid_seq OWNED BY sabathclasses.sabathclassid;


--
-- Name: schoolsummary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW schoolsummary AS
 SELECT qstudentview.quarterid,
    qstudentview.quarteryear,
    qstudentview.quarter,
    qstudentview.schoolname,
    qstudentview.sex,
    'School'::character varying AS defination,
    count(qstudentview.qstudentid) AS studentcount
   FROM qstudentview
  WHERE (qstudentview.approved = true)
  GROUP BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.schoolname, qstudentview.sex
  ORDER BY qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.schoolname, qstudentview.sex;


ALTER TABLE public.schoolsummary OWNER TO postgres;

--
-- Name: selectedgradeview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW selectedgradeview AS
 SELECT selcourseview.courseid,
    selcourseview.coursetitle,
    selcourseview.credithours,
    selcourseview.nogpa,
    selcourseview.yeartaken,
    selcourseview.mathplacement AS crs_mathplacement,
    selcourseview.englishplacement AS crs_englishplacement,
    selcourseview.kiswahiliplacement AS crs_kiswahiliplacement,
    selcourseview.qcourseid,
    selcourseview.quarterid,
    selcourseview.classoption,
    selcourseview.maxclass,
    selcourseview.labcourse,
    selcourseview.instructorid,
    selcourseview.instructorname,
    selcourseview.qcoursestudents,
    selcourseview.qgradeid,
    selcourseview.qstudentid,
    selcourseview.gradeid,
    selcourseview.hours,
    selcourseview.credit,
    selcourseview.approved,
    selcourseview.approvedate,
    selcourseview.askdrop,
    selcourseview.askdropdate,
    selcourseview.dropped,
    selcourseview.dropdate,
    selcourseview.repeated,
    selcourseview.withdrawdate,
    selcourseview.attendance,
    selcourseview.optiontimeid,
    selcourseview.narrative,
    studentdegrees.studentdegreeid,
    studentdegrees.studentid,
    students.studentname,
    students.sex,
    studentdegrees.mathplacement,
    studentdegrees.englishplacement,
    studentdegrees.kiswahiliplacement,
    getprereqpassed(studentdegrees.studentid, selcourseview.courseid, studentdegrees.bulletingid, getplacementpassed(studentdegrees.studentdegreeid, selcourseview.courseid)) AS placementpassed,
    getprereqpassed(studentdegrees.studentid, selcourseview.courseid, studentdegrees.bulletingid) AS prereqpassed,
    qstudents.org_id
   FROM (((selcourseview
     JOIN qstudents ON ((selcourseview.qstudentid = qstudents.qstudentid)))
     JOIN studentdegrees ON ((qstudents.studentdegreeid = studentdegrees.studentdegreeid)))
     JOIN students ON (((studentdegrees.studentid)::text = (students.studentid)::text)));


ALTER TABLE public.selectedgradeview OWNER TO postgres;

--
-- Name: sexview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sexview AS
 SELECT 'M'::text AS sex
UNION
 SELECT 'F'::text AS sex;


ALTER TABLE public.sexview OWNER TO postgres;

--
-- Name: skill_category; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE skill_category (
    skill_category_id integer NOT NULL,
    skill_category_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.skill_category OWNER TO postgres;

--
-- Name: skill_category_skill_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE skill_category_skill_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.skill_category_skill_category_id_seq OWNER TO postgres;

--
-- Name: skill_category_skill_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE skill_category_skill_category_id_seq OWNED BY skill_category.skill_category_id;


--
-- Name: skill_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE skill_types (
    skill_type_id integer NOT NULL,
    skill_category_id integer,
    skill_type_name character varying(50) NOT NULL,
    basic character varying(50),
    intermediate character varying(50),
    advanced character varying(50),
    details text
);


ALTER TABLE public.skill_types OWNER TO postgres;

--
-- Name: skill_types_skill_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE skill_types_skill_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.skill_types_skill_type_id_seq OWNER TO postgres;

--
-- Name: skill_types_skill_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE skill_types_skill_type_id_seq OWNED BY skill_types.skill_type_id;


--
-- Name: skills; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE skills (
    skill_id integer NOT NULL,
    entity_id integer,
    skill_type_id integer,
    skill_level integer DEFAULT 1 NOT NULL,
    aquired boolean DEFAULT false NOT NULL,
    training_date date,
    trained boolean DEFAULT false NOT NULL,
    training_institution character varying(240),
    training_cost real,
    details text
);


ALTER TABLE public.skills OWNER TO postgres;

--
-- Name: skills_skill_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE skills_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.skills_skill_id_seq OWNER TO postgres;

--
-- Name: skills_skill_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE skills_skill_id_seq OWNED BY skills.skill_id;


--
-- Name: student_payments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE student_payments (
    student_payment_id integer NOT NULL,
    qstudentid integer NOT NULL,
    org_id integer,
    entrydate timestamp without time zone DEFAULT now() NOT NULL,
    customerreference character varying(25) NOT NULL,
    transactiondate date NOT NULL,
    valuedate date,
    transactionamount real NOT NULL,
    drcrflag character varying(5),
    transactiondetail character varying(240),
    transactiontype integer,
    suspence boolean DEFAULT false NOT NULL,
    picked boolean DEFAULT false NOT NULL,
    pickeddate timestamp without time zone
);


ALTER TABLE public.student_payments OWNER TO postgres;

--
-- Name: student_payments_student_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE student_payments_student_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.student_payments_student_payment_id_seq OWNER TO postgres;

--
-- Name: student_payments_student_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE student_payments_student_payment_id_seq OWNED BY student_payments.student_payment_id;


--
-- Name: studentchecklist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentchecklist AS
 SELECT coursechecklist.orderid,
    coursechecklist.studentid,
    coursechecklist.studentdegreeid,
    coursechecklist.degreeid,
    coursechecklist.description,
    coursechecklist.courseid,
    coursechecklist.coursetitle,
    coursechecklist.minor,
    coursechecklist.elective,
    coursechecklist.credithours,
    coursechecklist.nogpa,
    coursechecklist.gradeid,
    coursechecklist.courseweight,
    coursechecklist.coursepased,
    coursechecklist.prereqpassed,
    students.studentname
   FROM (coursechecklist
     JOIN students ON (((coursechecklist.studentid)::text = (students.studentid)::text)));


ALTER TABLE public.studentchecklist OWNER TO postgres;

--
-- Name: studentdegrees_studentdegreeid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE studentdegrees_studentdegreeid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.studentdegrees_studentdegreeid_seq OWNER TO postgres;

--
-- Name: studentdegrees_studentdegreeid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE studentdegrees_studentdegreeid_seq OWNED BY studentdegrees.studentdegreeid;


--
-- Name: studentfirstquarterview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentfirstquarterview AS
 SELECT students.studentid,
    students.studentname,
    students.nationality,
    students.sex,
    students.maritalstatus,
    studentdegrees.studentdegreeid,
    studentdegrees.completed,
    studentdegrees.started,
    studentdegrees.graduated,
    degrees.degreeid,
    degrees.degreename,
    getfirstquarterid(students.studentid) AS firstquarterid,
    "substring"((getfirstquarterid(studentdegrees.studentdegreeid))::text, 1, 9) AS firstyear,
    "substring"((getfirstquarterid(studentdegrees.studentdegreeid))::text, 11, 1) AS firstquarter
   FROM ((students
     JOIN studentdegrees ON (((students.studentid)::text = (studentdegrees.studentid)::text)))
     JOIN degrees ON (((studentdegrees.degreeid)::text = (degrees.degreeid)::text)));


ALTER TABLE public.studentfirstquarterview OWNER TO postgres;

--
-- Name: studentmajors_studentmajorid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE studentmajors_studentmajorid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.studentmajors_studentmajorid_seq OWNER TO postgres;

--
-- Name: studentmajors_studentmajorid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE studentmajors_studentmajorid_seq OWNED BY studentmajors.studentmajorid;


--
-- Name: studentmarkview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentmarkview AS
 SELECT marks.markid,
    marks.grade,
    marks.markweight,
    registrations.existingid,
    getfirstquarterid(registrations.existingid) AS firstquarter,
    students.studentname
   FROM ((registrations
     JOIN marks ON ((registrations.markid = marks.markid)))
     JOIN students ON (((registrations.existingid)::text = (students.studentid)::text)));


ALTER TABLE public.studentmarkview OWNER TO postgres;

--
-- Name: studentrequests; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE studentrequests (
    studentrequestid integer NOT NULL,
    studentid character varying(12),
    requesttypeid integer,
    org_id integer,
    narrative character varying(240) NOT NULL,
    datesent timestamp without time zone DEFAULT now() NOT NULL,
    actioned boolean DEFAULT false NOT NULL,
    dateactioned timestamp without time zone,
    approved boolean DEFAULT false NOT NULL,
    dateapploved timestamp without time zone,
    details text,
    reply text
);


ALTER TABLE public.studentrequests OWNER TO postgres;

--
-- Name: studentrequests_studentrequestid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE studentrequests_studentrequestid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.studentrequests_studentrequestid_seq OWNER TO postgres;

--
-- Name: studentrequests_studentrequestid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE studentrequests_studentrequestid_seq OWNED BY studentrequests.studentrequestid;


--
-- Name: studentrequestview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studentrequestview AS
 SELECT students.studentid,
    students.studentname,
    requesttypes.requesttypeid,
    requesttypes.requesttypename,
    requesttypes.toapprove,
    requesttypes.details AS typedetails,
    studentrequests.org_id,
    studentrequests.studentrequestid,
    studentrequests.narrative,
    studentrequests.datesent,
    studentrequests.actioned,
    studentrequests.dateactioned,
    studentrequests.approved,
    studentrequests.dateapploved,
    studentrequests.details,
    studentrequests.reply
   FROM ((students
     JOIN studentrequests ON (((students.studentid)::text = (studentrequests.studentid)::text)))
     JOIN requesttypes ON ((studentrequests.requesttypeid = requesttypes.requesttypeid)));


ALTER TABLE public.studentrequestview OWNER TO postgres;

--
-- Name: studenttimetableview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW studenttimetableview AS
 SELECT assets.assetid,
    assets.assetname,
    assets.location,
    assets.building,
    assets.capacity,
    selectedgradeview.courseid,
    selectedgradeview.coursetitle,
    selectedgradeview.credithours,
    selectedgradeview.nogpa,
    selectedgradeview.yeartaken,
    selectedgradeview.qcourseid,
    selectedgradeview.quarterid,
    selectedgradeview.classoption,
    selectedgradeview.maxclass,
    selectedgradeview.labcourse,
    selectedgradeview.instructorid,
    selectedgradeview.instructorname,
    selectedgradeview.studentdegreeid,
    selectedgradeview.studentid,
    selectedgradeview.qgradeid,
    selectedgradeview.qstudentid,
    selectedgradeview.gradeid,
    selectedgradeview.hours,
    selectedgradeview.credit,
    selectedgradeview.approved,
    selectedgradeview.approvedate,
    selectedgradeview.askdrop,
    selectedgradeview.askdropdate,
    selectedgradeview.dropped,
    selectedgradeview.dropdate,
    selectedgradeview.repeated,
    selectedgradeview.withdrawdate,
    selectedgradeview.attendance,
    selectedgradeview.narrative,
    qtimetable.org_id,
    qtimetable.qtimetableid,
    qtimetable.starttime,
    qtimetable.endtime,
    qtimetable.lab,
    qtimetable.details,
    qtimetable.cmonday,
    qtimetable.ctuesday,
    qtimetable.cwednesday,
    qtimetable.cthursday,
    qtimetable.cfriday,
    qtimetable.csaturday,
    qtimetable.csunday,
    optiontimes.optiontimeid,
    optiontimes.optiontimename
   FROM ((assets
     JOIN (qtimetable
     JOIN optiontimes ON ((qtimetable.optiontimeid = optiontimes.optiontimeid))) ON ((assets.assetid = qtimetable.assetid)))
     JOIN selectedgradeview ON (((qtimetable.qcourseid = selectedgradeview.qcourseid) AND (qtimetable.optiontimeid = selectedgradeview.optiontimeid))))
  ORDER BY qtimetable.starttime;


ALTER TABLE public.studenttimetableview OWNER TO postgres;

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
-- Name: sun_audits; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sun_audits (
    sun_audit_id integer NOT NULL,
    studentid character varying(12),
    update_type character varying(25),
    update_time timestamp without time zone DEFAULT now(),
    sun_balance real,
    user_ip character varying(64)
);


ALTER TABLE public.sun_audits OWNER TO postgres;

--
-- Name: sun_audits_sun_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sun_audits_sun_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sun_audits_sun_audit_id_seq OWNER TO postgres;

--
-- Name: sun_audits_sun_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sun_audits_sun_audit_id_seq OWNED BY sun_audits.sun_audit_id;


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
-- Name: transcriptprint; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transcriptprint (
    transcriptprintid integer NOT NULL,
    studentdegreeid integer NOT NULL,
    entity_id integer,
    ip_address character varying(64),
    link_key character varying(64),
    accepted boolean DEFAULT false NOT NULL,
    userid integer,
    printdate timestamp without time zone DEFAULT now(),
    narrative character varying(240)
);


ALTER TABLE public.transcriptprint OWNER TO postgres;

--
-- Name: transcriptprint_transcriptprintid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transcriptprint_transcriptprintid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transcriptprint_transcriptprintid_seq OWNER TO postgres;

--
-- Name: transcriptprint_transcriptprintid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transcriptprint_transcriptprintid_seq OWNED BY transcriptprint.transcriptprintid;


--
-- Name: transcriptprintview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW transcriptprintview AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    transcriptprint.transcriptprintid,
    transcriptprint.studentdegreeid,
    transcriptprint.printdate,
    transcriptprint.narrative,
    transcriptprint.ip_address,
    transcriptprint.accepted
   FROM (transcriptprint
     JOIN entitys ON ((transcriptprint.entity_id = entitys.entity_id)));


ALTER TABLE public.transcriptprintview OWNER TO postgres;

--
-- Name: transferedcredits; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transferedcredits (
    transferedcreditid integer NOT NULL,
    studentdegreeid integer NOT NULL,
    courseid character varying(12) NOT NULL,
    credithours double precision DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.transferedcredits OWNER TO postgres;

--
-- Name: transferedcredits_transferedcreditid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transferedcredits_transferedcreditid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transferedcredits_transferedcreditid_seq OWNER TO postgres;

--
-- Name: transferedcredits_transferedcreditid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transferedcredits_transferedcreditid_seq OWNED BY transferedcredits.transferedcreditid;


--
-- Name: transferedcreditsview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW transferedcreditsview AS
 SELECT studentdegreeview.degreeid,
    studentdegreeview.degreename,
    studentdegreeview.sublevelid,
    studentdegreeview.sublevelname,
    studentdegreeview.studentid,
    studentdegreeview.studentname,
    studentdegreeview.studentdegreeid,
    courses.courseid,
    courses.coursetitle,
    transferedcredits.transferedcreditid,
    transferedcredits.credithours,
    transferedcredits.narrative
   FROM ((studentdegreeview
     JOIN transferedcredits ON ((studentdegreeview.studentdegreeid = transferedcredits.studentdegreeid)))
     JOIN courses ON (((transferedcredits.courseid)::text = (courses.courseid)::text)));


ALTER TABLE public.transferedcreditsview OWNER TO postgres;

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
-- Name: vw_adm_semesters; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_adm_semesters AS
 SELECT adm_semesters.semester_id
   FROM ( SELECT ((((s.a)::text || '/'::text) || ((s.a + 1))::text) || '.1'::text) AS semester_id
           FROM generate_series(((date_part('year'::text, ('now'::text)::date))::integer - 7), ((date_part('year'::text, ('now'::text)::date))::integer + 2)) s(a)
        UNION
         SELECT ((((s.a)::text || '/'::text) || ((s.a + 1))::text) || '.2'::text) AS semester_id
           FROM generate_series(((date_part('year'::text, ('now'::text)::date))::integer - 7), ((date_part('year'::text, ('now'::text)::date))::integer + 2)) s(a)) adm_semesters
  ORDER BY adm_semesters.semester_id;


ALTER TABLE public.vw_adm_semesters OWNER TO postgres;

--
-- Name: vw_offers; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_offers AS
 SELECT entitys.entity_id AS employer_id,
    entitys.entity_name AS employer_name,
    offers.offer_id,
    offers.offer_name,
    offers.opening_date,
    offers.closing_date,
    offers.positions,
    offers.location,
    offers.details
   FROM (offers
     JOIN entitys ON ((offers.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_offers OWNER TO postgres;

--
-- Name: vw_applications; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_applications AS
 SELECT vw_offers.employer_id,
    vw_offers.employer_name,
    vw_offers.offer_id,
    vw_offers.offer_name,
    vw_offers.opening_date,
    vw_offers.closing_date,
    entitys.entity_id,
    entitys.entity_name,
    applications.application_id,
    applications.application_date,
    applications.approve_status,
    applications.workflow_table_id,
    applications.action_date,
    applications.applicant_comments,
    applications.review
   FROM ((applications
     JOIN vw_offers ON ((applications.offer_id = vw_offers.offer_id)))
     JOIN entitys ON ((applications.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_applications OWNER TO postgres;

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
-- Name: vw_course_load; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_course_load AS
 SELECT qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.degreelevelid,
    qcourseview.degreelevelname,
    qcourseview.coursetypeid,
    qcourseview.coursetypename,
    qcourseview.courseid,
    qcourseview.credithours,
    qcourseview.maxcredit,
    qcourseview.iscurrent,
    qcourseview.nogpa,
    qcourseview.yeartaken,
    qcourseview.mathplacement,
    qcourseview.englishplacement,
    qcourseview.org_id,
    qcourseview.instructorid,
    qcourseview.qcourseid,
    qcourseview.classoption,
    qcourseview.maxclass,
    qcourseview.labcourse,
    qcourseview.clinical_fee,
    qcourseview.extracharge,
    qcourseview.approved,
    qcourseview.attendance,
    qcourseview.oldcourseid,
    qcourseview.fullattendance,
    qcourseview.attachement,
    qcourseview.submit_grades,
    qcourseview.submit_date,
    qcourseview.approved_grades,
    qcourseview.approve_date,
    qcourseview.examsubmited,
    qcourseview.examinable,
    qcourseview.departmentchange,
    qcourseview.registrychange,
    qcourseview.instructorname,
    qcourseview.coursetitle,
    qcourseview.quarterid,
    qcourseview.qstart,
    qcourseview.qlatereg,
    qcourseview.qlatechange,
    qcourseview.qlastdrop,
    qcourseview.qend,
    qcourseview.active,
    qcourseview.chalengerate,
    qcourseview.feesline,
    qcourseview.resline,
    qcourseview.minimal_fees,
    qcourseview.closed,
    qcourseview.quarter_name,
    qcourseview.quarteryear,
    qcourseview.quarter,
    qcourseview.levellocationid,
    qcourseview.levellocationname,
    a.course_load
   FROM (qcourseview
     JOIN ( SELECT qgrades.qcourseid,
            count(qgrades.qgradeid) AS course_load
           FROM qgrades
          WHERE (qgrades.dropped = false)
          GROUP BY qgrades.qcourseid) a ON ((qcourseview.qcourseid = a.qcourseid)));


ALTER TABLE public.vw_course_load OWNER TO postgres;

--
-- Name: vw_cv_projects; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_cv_projects AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    cv_projects.cv_projectid,
    cv_projects.cv_project_name,
    cv_projects.cv_project_date,
    cv_projects.details
   FROM (cv_projects
     JOIN entitys ON ((cv_projects.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_cv_projects OWNER TO postgres;

--
-- Name: vw_cv_referees; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_cv_referees AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    cv_referees.cv_referee_id,
    cv_referees.cv_referee_name,
    cv_referees.cv_referee_address,
    cv_referees.details
   FROM (cv_referees
     JOIN entitys ON ((cv_referees.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_cv_referees OWNER TO postgres;

--
-- Name: vw_cv_seminars; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_cv_seminars AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    cv_seminars.cv_seminar_id,
    cv_seminars.cv_seminar_name,
    cv_seminars.cv_seminar_date,
    cv_seminars.details
   FROM (cv_seminars
     JOIN entitys ON ((cv_seminars.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_cv_seminars OWNER TO postgres;

--
-- Name: vw_education; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_education AS
 SELECT education_class.education_class_id,
    education_class.education_class_name,
    entitys.entity_id,
    entitys.entity_name,
    education.education_id,
    education.date_from,
    education.date_to,
    education.name_of_school,
    education.examination_taken,
    education.grades_obtained,
    education.details
   FROM ((education
     JOIN education_class ON ((education.education_class_id = education_class.education_class_id)))
     JOIN entitys ON ((education.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_education OWNER TO postgres;

--
-- Name: vw_employment; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_employment AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    employment.employment_id,
    employment.date_from,
    employment.date_to,
    employment.employers_name,
    employment.position_held,
    employment.details
   FROM (employment
     JOIN entitys ON ((employment.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_employment OWNER TO postgres;

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
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entitys AS
 SELECT orgs.org_id,
    orgs.org_name,
    entity_types.entity_type_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entity_types.group_email,
    entity_types.use_key_id,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.super_user,
    entitys.entity_leader,
    entitys.date_enroled,
    entitys.is_active,
    entitys.entity_password,
    entitys.first_password,
    entitys.primary_email,
    entitys.function_role,
    entitys.selection_id,
    entitys.admision_payment,
    entitys.admision_paid,
    entitys.details
   FROM ((entitys
     JOIN orgs ON ((entitys.org_id = orgs.org_id)))
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
-- Name: vw_levellocations; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_levellocations AS
 SELECT orgs.org_id,
    orgs.org_name,
    levellocations.levellocationid,
    levellocations.levellocationname,
    levellocations.details
   FROM (orgs
     JOIN levellocations ON ((orgs.org_id = levellocations.org_id)));


ALTER TABLE public.vw_levellocations OWNER TO postgres;

--
-- Name: vw_major_bulletings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_major_bulletings AS
 SELECT majorview.schoolid,
    majorview.schoolname,
    majorview.departmentid,
    majorview.departmentname,
    majorview.majorid,
    majorview.majorname,
    majorview.electivecredit,
    majorview.majorminimal,
    majorview.minorminimum,
    majorview.coreminimum,
    majorview.major,
    majorview.minor,
    majorview.details,
    bulleting.bulletingid,
    bulleting.bulletingname,
    bulleting.startingquarter,
    bulleting.endingquarter,
    bulleting.iscurrent
   FROM (majorview
     CROSS JOIN bulleting);


ALTER TABLE public.vw_major_bulletings OWNER TO postgres;

--
-- Name: vw_major_prereq; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_major_prereq AS
 SELECT majorcontentview.schoolid,
    majorcontentview.departmentid,
    majorcontentview.departmentname,
    majorcontentview.majorid,
    majorcontentview.majorname,
    majorcontentview.electivecredit,
    majorcontentview.courseid AS precourseid,
    majorcontentview.coursetitle AS precoursetitle,
    majorcontentview.contenttypeid,
    majorcontentview.contenttypename,
    majorcontentview.elective,
    majorcontentview.prerequisite,
    majorcontentview.premajor,
    majorcontentview.majorcontentid,
    majorcontentview.minor,
    majorcontentview.iscurrent,
    prereqview.courseid,
    prereqview.coursetitle,
    prereqview.prerequisiteid,
    prereqview.optionlevel,
    prereqview.narrative,
    prereqview.gradeid,
    prereqview.gradeweight,
    prereqview.bulletingid,
    prereqview.bulletingname,
    prereqview.startingquarter,
    prereqview.endingquarter
   FROM (majorcontentview
     JOIN prereqview ON (((majorcontentview.courseid)::text = (prereqview.precourseid)::text)))
  ORDER BY prereqview.courseid, prereqview.optionlevel;


ALTER TABLE public.vw_major_prereq OWNER TO postgres;

--
-- Name: vw_majoroptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_majoroptions AS
 SELECT majorview.schoolid,
    majorview.schoolname,
    majorview.departmentid,
    majorview.departmentname,
    majorview.majorid,
    majorview.majorname,
    majorview.electivecredit,
    majorview.majorminimal,
    majorview.minorminimum,
    majorview.coreminimum,
    majorview.major,
    majorview.minor,
    majorview.details AS major_details,
    majoroptions.majoroptionid,
    majoroptions.majoroptionname,
    majoroptions.details
   FROM (majorview
     JOIN majoroptions ON (((majorview.majorid)::text = (majoroptions.majorid)::text)));


ALTER TABLE public.vw_majoroptions OWNER TO postgres;

--
-- Name: vw_majoroption_bulletings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_majoroption_bulletings AS
 SELECT vw_majoroptions.schoolid,
    vw_majoroptions.schoolname,
    vw_majoroptions.departmentid,
    vw_majoroptions.departmentname,
    vw_majoroptions.majorid,
    vw_majoroptions.majorname,
    vw_majoroptions.electivecredit,
    vw_majoroptions.majorminimal,
    vw_majoroptions.minorminimum,
    vw_majoroptions.coreminimum,
    vw_majoroptions.major,
    vw_majoroptions.minor,
    vw_majoroptions.major_details,
    vw_majoroptions.majoroptionid,
    vw_majoroptions.majoroptionname,
    vw_majoroptions.details,
    bulleting.bulletingid,
    bulleting.bulletingname,
    bulleting.startingquarter,
    bulleting.endingquarter,
    bulleting.iscurrent
   FROM (vw_majoroptions
     CROSS JOIN bulleting);


ALTER TABLE public.vw_majoroption_bulletings OWNER TO postgres;

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
-- Name: vw_qgrades; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_qgrades AS
 SELECT qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.degreelevelid,
    qcourseview.degreelevelname,
    qcourseview.coursetypeid,
    qcourseview.coursetypename,
    qcourseview.courseid,
    qcourseview.credithours,
    qcourseview.iscurrent,
    qcourseview.nogpa,
    qcourseview.yeartaken,
    qcourseview.mathplacement AS crs_mathplacement,
    qcourseview.englishplacement AS crs_englishplacement,
    qcourseview.instructorid,
    qcourseview.quarterid,
    qcourseview.qcourseid,
    qcourseview.classoption,
    qcourseview.maxclass,
    qcourseview.labcourse,
    qcourseview.extracharge,
    qcourseview.clinical_fee,
    qcourseview.attendance AS crs_attendance,
    qcourseview.oldcourseid,
    qcourseview.fullattendance,
    qcourseview.instructorname,
    qcourseview.coursetitle,
    qcourseview.attachement,
    qcourseview.examinable,
    qcourseview.submit_grades,
    qcourseview.submit_date,
    qcourseview.approved_grades,
    qcourseview.approve_date,
    qcourseview.departmentchange,
    qcourseview.registrychange,
    qgrades.org_id,
    qgrades.qgradeid,
    qgrades.qstudentid,
    qgrades.hours,
    qgrades.credit,
    qgrades.approved AS crs_approved,
    qgrades.approvedate,
    qgrades.askdrop,
    qgrades.askdropdate,
    qgrades.dropped,
    qgrades.dropdate,
    qgrades.repeated,
    qgrades.attendance,
    qgrades.narrative,
    qgrades.challengecourse,
    qgrades.nongpacourse,
    qgrades.lecture_marks,
    qgrades.lecture_cat_mark,
    qgrades.lecture_gradeid,
    qgrades.request_drop,
    qgrades.request_drop_date,
    qgrades.withdraw_rate AS course_withdraw_rate,
    grades.gradeid,
    grades.gradeweight,
    grades.minrange,
    grades.maxrange,
    grades.gpacount,
    grades.narrative AS gradenarrative,
        CASE qgrades.repeated
            WHEN true THEN (0)::double precision
            ELSE (grades.gradeweight * qgrades.credit)
        END AS gpa,
        CASE
            WHEN ((((((qgrades.gradeid)::text = 'W'::text) OR ((qgrades.gradeid)::text = 'AW'::text)) OR (grades.gpacount = false)) OR (qgrades.repeated = true)) OR (qgrades.nongpacourse = true)) THEN (0)::double precision
            ELSE qgrades.credit
        END AS gpahours,
        CASE
            WHEN (((qgrades.gradeid)::text = 'W'::text) OR ((qgrades.gradeid)::text = 'AW'::text)) THEN (qgrades.hours * qgrades.withdraw_rate)
            ELSE qgrades.hours
        END AS chargehours
   FROM ((qcourseview
     JOIN qgrades ON ((qcourseview.qcourseid = qgrades.qcourseid)))
     JOIN grades ON (((qgrades.gradeid)::text = (grades.gradeid)::text)));


ALTER TABLE public.vw_qgrades OWNER TO postgres;

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
-- Name: vw_residences; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_residences AS
 SELECT levellocations.levellocationid,
    levellocations.levellocationname,
    residences.residenceid,
    residences.residencename,
    residences.capacity,
    residences.roomsize,
    residences.defaultrate,
    residences.offcampus,
    residences.sex,
    residences.residencedean,
    residences.details
   FROM (levellocations
     JOIN residences ON ((levellocations.levellocationid = residences.levellocationid)));


ALTER TABLE public.vw_residences OWNER TO postgres;

--
-- Name: vw_skill_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_skill_types AS
 SELECT skill_category.skill_category_id,
    skill_category.skill_category_name,
    skill_types.skill_type_id,
    skill_types.skill_type_name,
    skill_types.basic,
    skill_types.intermediate,
    skill_types.advanced,
    skill_types.details
   FROM (skill_types
     JOIN skill_category ON ((skill_types.skill_category_id = skill_category.skill_category_id)));


ALTER TABLE public.vw_skill_types OWNER TO postgres;

--
-- Name: vw_skills; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_skills AS
 SELECT vw_skill_types.skill_category_id,
    vw_skill_types.skill_category_name,
    vw_skill_types.skill_type_id,
    vw_skill_types.skill_type_name,
    vw_skill_types.basic,
    vw_skill_types.intermediate,
    vw_skill_types.advanced,
    entitys.entity_id,
    entitys.entity_name,
    skills.skill_id,
    skills.skill_level,
    skills.aquired,
    skills.training_date,
    skills.trained,
    skills.training_institution,
    skills.training_cost,
    skills.details,
        CASE
            WHEN (skills.skill_level = 1) THEN 'Basic'::text
            WHEN (skills.skill_level = 2) THEN 'Intermediate'::text
            WHEN (skills.skill_level = 3) THEN 'Advanced'::text
            ELSE 'None'::text
        END AS skill_level_name,
        CASE
            WHEN (skills.skill_level = 1) THEN vw_skill_types.basic
            WHEN (skills.skill_level = 2) THEN vw_skill_types.intermediate
            WHEN (skills.skill_level = 3) THEN vw_skill_types.advanced
            ELSE 'None'::character varying
        END AS skill_level_details
   FROM ((skills
     JOIN entitys ON ((skills.entity_id = entitys.entity_id)))
     JOIN vw_skill_types ON ((skills.skill_type_id = vw_skill_types.skill_type_id)));


ALTER TABLE public.vw_skills OWNER TO postgres;

--
-- Name: vw_students; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_students AS
 SELECT denominationview.religionid,
    denominationview.religionname,
    denominationview.denominationid,
    denominationview.denominationname,
    residences.residenceid,
    residences.residencename,
    schools.schoolid,
    schools.schoolname,
    c1.countryname AS addresscountry,
    students.org_id,
    students.studentid,
    students.studentname,
    students.address,
    students.zipcode,
    students.town,
    students.telno,
    students.email,
    students.guardianname,
    students.gaddress,
    students.gzipcode,
    students.gtown,
    c2.countryname AS gaddresscountry,
    students.gtelno,
    students.gemail,
    students.accountnumber,
    students.nationality,
    c3.countryname AS nationalitycountry,
    students.sex,
    students.maritalstatus,
    students.birthdate,
    students.firstpass,
    students.alumnae,
    students.postcontacts,
    students.onprobation,
    students.offcampus,
    students.currentcontact,
    students.currentemail,
    students.currenttel,
    students.seeregistrar,
    students.hallseats,
    students.staff,
    students.fullbursary,
    students.details,
    students.room_number,
    students.probation_details,
    students.registrar_details,
    students.gfirstpass,
    ('G'::text || (students.studentid)::text) AS gstudentid,
    (('<a href="a_statement_acct.jsp?view=1:0&accountno='::text || (students.accountnumber)::text) || '" target="_blank">View Accounts</a>'::text) AS view_statement
   FROM ((((((denominationview
     JOIN students ON (((denominationview.denominationid)::text = (students.denominationid)::text)))
     JOIN schools ON (((students.schoolid)::text = (schools.schoolid)::text)))
     LEFT JOIN residences ON (((students.residenceid)::text = (residences.residenceid)::text)))
     JOIN countrys c1 ON ((students.countrycodeid = c1.countryid)))
     JOIN countrys c2 ON ((students.gcountrycodeid = c2.countryid)))
     JOIN countrys c3 ON (((students.nationality)::bpchar = c3.countryid)));


ALTER TABLE public.vw_students OWNER TO postgres;

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
-- Name: vwdualcourselevels; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vwdualcourselevels AS
 SELECT studentgradeview.studentid,
    studentgradeview.studentname,
    studentgradeview.studentdegreeid,
    studentgradeview.degreename,
    studentgradeview.quarterid,
    studentgradeview.crs_degreelevelid,
    studentgradeview.crs_degreelevelname
   FROM studentgradeview
  GROUP BY studentgradeview.studentid, studentgradeview.studentname, studentgradeview.studentdegreeid, studentgradeview.degreename, studentgradeview.quarterid, studentgradeview.crs_degreelevelid, studentgradeview.crs_degreelevelname;


ALTER TABLE public.vwdualcourselevels OWNER TO postgres;

--
-- Name: vwgradyear; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vwgradyear AS
 SELECT date_part('year'::text, studentdegreeview.graduatedate) AS gradyear
   FROM studentdegreeview
  WHERE (studentdegreeview.graduated = true)
  GROUP BY date_part('year'::text, studentdegreeview.graduatedate)
  ORDER BY date_part('year'::text, studentdegreeview.graduatedate);


ALTER TABLE public.vwgradyear OWNER TO postgres;

--
-- Name: vwnationality; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vwnationality AS
 SELECT students.nationality,
    countrys.countryname
   FROM (students
     JOIN countrys ON (((students.nationality)::bpchar = countrys.countryid)))
  GROUP BY students.nationality, countrys.countryname
  ORDER BY countrys.countryname;


ALTER TABLE public.vwnationality OWNER TO postgres;

--
-- Name: vwqexamtimetable; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vwqexamtimetable AS
 SELECT qcourseview.courseid,
    qcourseview.coursetitle,
    qcourseview.schoolid,
    qcourseview.schoolname,
    qcourseview.departmentid,
    qcourseview.departmentname,
    qcourseview.instructorid,
    qcourseview.instructorname,
    qexamtimetable.org_id,
    qexamtimetable.qexamtimetableid,
    qexamtimetable.examdate,
    qexamtimetable.starttime,
    qexamtimetable.endtime,
    qexamtimetable.lab,
    quarters.quarterid,
    quarters.active,
    quarters.closed
   FROM ((qcourseview
     JOIN qexamtimetable ON ((qcourseview.qcourseid = qexamtimetable.qcourseid)))
     JOIN quarters ON (((qcourseview.quarterid)::text = (quarters.quarterid)::text)));


ALTER TABLE public.vwqexamtimetable OWNER TO postgres;

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
-- Name: yearview; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW yearview AS
 SELECT quarterview.quarteryear
   FROM quarterview
  GROUP BY quarterview.quarteryear
  ORDER BY quarterview.quarteryear DESC;


ALTER TABLE public.yearview OWNER TO postgres;

--
-- Name: address_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address ALTER COLUMN address_id SET DEFAULT nextval('address_address_id_seq'::regclass);


--
-- Name: address_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types ALTER COLUMN address_type_id SET DEFAULT nextval('address_types_address_type_id_seq'::regclass);


--
-- Name: application_form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms ALTER COLUMN application_form_id SET DEFAULT nextval('application_forms_application_form_id_seq'::regclass);


--
-- Name: application_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applications ALTER COLUMN application_id SET DEFAULT nextval('applications_application_id_seq'::regclass);


--
-- Name: approval_checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists ALTER COLUMN approval_checklist_id SET DEFAULT nextval('approval_checklists_approval_checklist_id_seq'::regclass);


--
-- Name: approvalid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvallist ALTER COLUMN approvalid SET DEFAULT nextval('approvallist_approvalid_seq'::regclass);


--
-- Name: approval_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals ALTER COLUMN approval_id SET DEFAULT nextval('approvals_approval_id_seq'::regclass);


--
-- Name: assetid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assets ALTER COLUMN assetid SET DEFAULT nextval('assets_assetid_seq'::regclass);


--
-- Name: bulletingid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bulleting ALTER COLUMN bulletingid SET DEFAULT nextval('bulleting_bulletingid_seq'::regclass);


--
-- Name: charge_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY charges ALTER COLUMN charge_id SET DEFAULT nextval('charges_charge_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: contacttypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contacttypes ALTER COLUMN contacttypeid SET DEFAULT nextval('contacttypes_contacttypeid_seq'::regclass);


--
-- Name: contenttypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contenttypes ALTER COLUMN contenttypeid SET DEFAULT nextval('contenttypes_contenttypeid_seq'::regclass);


--
-- Name: county_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY counties ALTER COLUMN county_id SET DEFAULT nextval('counties_county_id_seq'::regclass);


--
-- Name: coursetypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY coursetypes ALTER COLUMN coursetypeid SET DEFAULT nextval('coursetypes_coursetypeid_seq'::regclass);


--
-- Name: currency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency ALTER COLUMN currency_id SET DEFAULT nextval('currency_currency_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: cv_projectid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_projects ALTER COLUMN cv_projectid SET DEFAULT nextval('cv_projects_cv_projectid_seq'::regclass);


--
-- Name: cv_referee_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_referees ALTER COLUMN cv_referee_id SET DEFAULT nextval('cv_referees_cv_referee_id_seq'::regclass);


--
-- Name: cv_seminar_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_seminars ALTER COLUMN cv_seminar_id SET DEFAULT nextval('cv_seminars_cv_seminar_id_seq'::regclass);


--
-- Name: education_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY education ALTER COLUMN education_id SET DEFAULT nextval('education_education_id_seq'::regclass);


--
-- Name: education_class_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY education_class ALTER COLUMN education_class_id SET DEFAULT nextval('education_class_education_class_id_seq'::regclass);


--
-- Name: employment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY employment ALTER COLUMN employment_id SET DEFAULT nextval('employment_employment_id_seq'::regclass);


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
-- Name: evaluationid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY evaluation ALTER COLUMN evaluationid SET DEFAULT nextval('evaluation_evaluationid_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: gradechangeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gradechangelist ALTER COLUMN gradechangeid SET DEFAULT nextval('gradechangelist_gradechangeid_seq'::regclass);


--
-- Name: healthitemid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY healthitems ALTER COLUMN healthitemid SET DEFAULT nextval('healthitems_healthitemid_seq'::regclass);


--
-- Name: levellocationid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY levellocations ALTER COLUMN levellocationid SET DEFAULT nextval('levellocations_levellocationid_seq'::regclass);


--
-- Name: majorcontentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents ALTER COLUMN majorcontentid SET DEFAULT nextval('majorcontents_majorcontentid_seq'::regclass);


--
-- Name: majoroptcontentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents ALTER COLUMN majoroptcontentid SET DEFAULT nextval('majoroptcontents_majoroptcontentid_seq'::regclass);


--
-- Name: majoroptionid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptions ALTER COLUMN majoroptionid SET DEFAULT nextval('majoroptions_majoroptionid_seq'::regclass);


--
-- Name: offer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY offers ALTER COLUMN offer_id SET DEFAULT nextval('offers_offer_id_seq'::regclass);


--
-- Name: optiontimeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY optiontimes ALTER COLUMN optiontimeid SET DEFAULT nextval('optiontimes_optiontimeid_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: prerequisiteid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prerequisites ALTER COLUMN prerequisiteid SET DEFAULT nextval('prerequisites_prerequisiteid_seq'::regclass);


--
-- Name: qcalendarid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcalendar ALTER COLUMN qcalendarid SET DEFAULT nextval('qcalendar_qcalendarid_seq'::regclass);


--
-- Name: qcourseitemid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourseitems ALTER COLUMN qcourseitemid SET DEFAULT nextval('qcourseitems_qcourseitemid_seq'::regclass);


--
-- Name: qcoursemarkid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcoursemarks ALTER COLUMN qcoursemarkid SET DEFAULT nextval('qcoursemarks_qcoursemarkid_seq'::regclass);


--
-- Name: qcourseid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses ALTER COLUMN qcourseid SET DEFAULT nextval('qcourses_qcourseid_seq'::regclass);


--
-- Name: qexamtimetableid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qexamtimetable ALTER COLUMN qexamtimetableid SET DEFAULT nextval('qexamtimetable_qexamtimetableid_seq'::regclass);


--
-- Name: qgradeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades ALTER COLUMN qgradeid SET DEFAULT nextval('qgrades_qgradeid_seq'::regclass);


--
-- Name: qposting_log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qposting_logs ALTER COLUMN qposting_log_id SET DEFAULT nextval('qposting_logs_qposting_log_id_seq'::regclass);


--
-- Name: qresidenceid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qresidences ALTER COLUMN qresidenceid SET DEFAULT nextval('qresidences_qresidenceid_seq'::regclass);


--
-- Name: qstudentid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents ALTER COLUMN qstudentid SET DEFAULT nextval('qstudents_qstudentid_seq'::regclass);


--
-- Name: qtimetableid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qtimetable ALTER COLUMN qtimetableid SET DEFAULT nextval('qtimetable_qtimetableid_seq'::regclass);


--
-- Name: regcontactid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regcontacts ALTER COLUMN regcontactid SET DEFAULT nextval('regcontacts_regcontactid_seq'::regclass);


--
-- Name: reghealthid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reghealth ALTER COLUMN reghealthid SET DEFAULT nextval('reghealth_reghealthid_seq'::regclass);


--
-- Name: registrationid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations ALTER COLUMN registrationid SET DEFAULT nextval('registrations_registrationid_seq'::regclass);


--
-- Name: registrymarkid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrymarks ALTER COLUMN registrymarkid SET DEFAULT nextval('registrymarks_registrymarkid_seq'::regclass);


--
-- Name: registryschoolid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registryschools ALTER COLUMN registryschoolid SET DEFAULT nextval('registryschools_registryschoolid_seq'::regclass);


--
-- Name: reporting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting ALTER COLUMN reporting_id SET DEFAULT nextval('reporting_reporting_id_seq'::regclass);


--
-- Name: requesttypeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requesttypes ALTER COLUMN requesttypeid SET DEFAULT nextval('requesttypes_requesttypeid_seq'::regclass);


--
-- Name: requirementid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requirements ALTER COLUMN requirementid SET DEFAULT nextval('requirements_requirementid_seq'::regclass);


--
-- Name: sabathclassid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sabathclasses ALTER COLUMN sabathclassid SET DEFAULT nextval('sabathclasses_sabathclassid_seq'::regclass);


--
-- Name: skill_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skill_category ALTER COLUMN skill_category_id SET DEFAULT nextval('skill_category_skill_category_id_seq'::regclass);


--
-- Name: skill_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skill_types ALTER COLUMN skill_type_id SET DEFAULT nextval('skill_types_skill_type_id_seq'::regclass);


--
-- Name: skill_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skills ALTER COLUMN skill_id SET DEFAULT nextval('skills_skill_id_seq'::regclass);


--
-- Name: student_payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY student_payments ALTER COLUMN student_payment_id SET DEFAULT nextval('student_payments_student_payment_id_seq'::regclass);


--
-- Name: studentdegreeid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentdegrees ALTER COLUMN studentdegreeid SET DEFAULT nextval('studentdegrees_studentdegreeid_seq'::regclass);


--
-- Name: studentmajorid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentmajors ALTER COLUMN studentmajorid SET DEFAULT nextval('studentmajors_studentmajorid_seq'::regclass);


--
-- Name: studentrequestid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentrequests ALTER COLUMN studentrequestid SET DEFAULT nextval('studentrequests_studentrequestid_seq'::regclass);


--
-- Name: sub_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields ALTER COLUMN sub_field_id SET DEFAULT nextval('sub_fields_sub_field_id_seq'::regclass);


--
-- Name: subscription_level_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels ALTER COLUMN subscription_level_id SET DEFAULT nextval('subscription_levels_subscription_level_id_seq'::regclass);


--
-- Name: sun_audit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sun_audits ALTER COLUMN sun_audit_id SET DEFAULT nextval('sun_audits_sun_audit_id_seq'::regclass);


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
-- Name: transcriptprintid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transcriptprint ALTER COLUMN transcriptprintid SET DEFAULT nextval('transcriptprint_transcriptprintid_seq'::regclass);


--
-- Name: transferedcreditid; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transferedcredits ALTER COLUMN transferedcreditid SET DEFAULT nextval('transferedcredits_transferedcreditid_seq'::regclass);


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
-- Data for Name: application_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: application_forms_application_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('application_forms_application_form_id_seq', 1, false);


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: applications_application_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('applications_application_id_seq', 1, false);


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approval_checklists_approval_checklist_id_seq', 1, false);


--
-- Data for Name: approvallist; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approvallist_approvalid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approvallist_approvalid_seq', 1, false);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approvals_approval_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approvals_approval_id_seq', 1, false);


--
-- Data for Name: assets; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: assets_assetid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('assets_assetid_seq', 1, false);


--
-- Data for Name: bulleting; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: bulleting_bulletingid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bulleting_bulletingid_seq', 1, false);


--
-- Data for Name: charges; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: charges_charge_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('charges_charge_id_seq', 1, false);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Data for Name: contacttypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contacttypes_contacttypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contacttypes_contacttypeid_seq', 1, false);


--
-- Data for Name: contenttypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contenttypes_contenttypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contenttypes_contenttypeid_seq', 1, false);


--
-- Data for Name: continents; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: counties; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: counties_county_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('counties_county_id_seq', 1, false);


--
-- Data for Name: countrys; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: coursetypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: coursetypes_coursetypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('coursetypes_coursetypeid_seq', 1, false);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (1, 'Kenya Shillings', 'KES', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (2, 'US Dollar', 'USD', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (3, 'British Pound', 'BPD', 0);
INSERT INTO currency (currency_id, currency_name, currency_symbol, org_id) VALUES (4, 'Euro', 'ERO', 0);


--
-- Name: currency_currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_currency_id_seq', 4, true);


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency_rates (currency_rate_id, currency_id, org_id, exchange_date, exchange_rate) VALUES (0, 1, 0, '2017-03-08', 1);


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, false);


--
-- Data for Name: cv_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: cv_projects_cv_projectid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cv_projects_cv_projectid_seq', 1, false);


--
-- Data for Name: cv_referees; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: cv_referees_cv_referee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cv_referees_cv_referee_id_seq', 1, false);


--
-- Data for Name: cv_seminars; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: cv_seminars_cv_seminar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('cv_seminars_cv_seminar_id_seq', 1, false);


--
-- Data for Name: degreelevels; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: degrees; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: denominations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: education; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: education_class; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (1, 'Primary School', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (2, 'Secondary School', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (3, 'High School', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (4, 'Certificate', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (5, 'Diploma', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (6, 'Higher Diploma', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (7, 'Under Graduate', NULL);
INSERT INTO education_class (education_class_id, education_class_name, details) VALUES (8, 'Post Graduate', NULL);


--
-- Name: education_class_education_class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('education_class_education_class_id_seq', 1, false);


--
-- Name: education_education_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('education_education_id_seq', 1, false);


--
-- Data for Name: employment; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: employment_employment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('employment_employment_id_seq', 1, false);


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


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 5, true);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entitys (entity_id, entity_type_id, use_key_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, selection_id, admision_payment, admision_paid) VALUES (0, 0, 0, 0, 'root', 'root', 'root@localhost', NULL, true, true, false, NULL, '2017-03-08 09:22:03.613706', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 2000, false);
INSERT INTO entitys (entity_id, entity_type_id, use_key_id, org_id, entity_name, user_name, primary_email, primary_telephone, super_user, entity_leader, no_org, function_role, date_enroled, is_active, entity_password, first_password, new_password, start_url, is_picked, details, selection_id, admision_payment, admision_paid) VALUES (1, 0, 0, 0, 'repository', 'repository', 'repository@localhost', NULL, false, true, false, NULL, '2017-03-08 09:22:03.613706', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 2000, false);


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
-- Data for Name: evaluation; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: evaluation_evaluationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('evaluation_evaluationid_seq', 1, false);


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (10, 0, 1, 'MaritalStatus', 'Marital Status', 'Single# Married', 'LIST', NULL, '0', '0', 100, 100, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (89, 0, 1, 'mname', 'Mothers name', NULL, 'TEXTFIELD', NULL, '0', '0', 890, 890, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (727, 0, 1, NULL, '<b>Educational Background. </b>List institutions of learning attended at each level including Primary school:', NULL, 'TEXT', NULL, '0', '0', 312, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (728, 0, 1, NULL, '<b>Work experience:</b> If you held a job, give details about employment (use additional sheet if necessary)', NULL, 'TEXT', NULL, '0', '0', 317, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (709, 0, 1, NULL, 'Address', NULL, 'TEXTFIELD', NULL, '0', '0', 853, 850, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (710, 0, 1, NULL, 'Telephone', NULL, 'TEXTFIELD', NULL, '0', '0', 855, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (711, 0, 1, NULL, 'Email', NULL, 'TEXTFIELD', NULL, '0', '0', 858, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (86, 0, 1, 'fnationalityid', 'Nationality', 'SELECT sys_country_id,sys_country_name FROM sys_countrys;', 'SELECT', NULL, '0', '0', 860, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (712, 0, 1, NULL, 'Address', NULL, 'TEXTFIELD', NULL, '0', '0', 893, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (713, 0, 1, NULL, 'Telephone', NULL, 'TEXTFIELD', NULL, '0', '0', 895, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (714, 0, 1, NULL, 'Email', NULL, 'TEXTFIELD', NULL, '0', '0', 898, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (105, 0, 1, NULL, 'Date', NULL, 'DATE', NULL, '0', '0', 1030, 1020, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (61, 0, 1, 'expelled', 'Have you ever been expelled/dismissed or refused admission to any institution of learning?', 'Yes#No', 'LIST', NULL, '0', '0', 340, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (463, 0, 11, NULL, 'Academic Year', NULL, 'TEXTFIELD', NULL, '0', '0', 110, 80, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (291, 0, 5, NULL, 'Instructions: Have this form completed according to numbered sequence.', NULL, 'TITLE', NULL, '0', '0', 80, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (459, 0, 11, NULL, 'COURSE FOR WHICH THE DEFFERED GRADE IS APPLIED', NULL, 'TITLE', NULL, '0', '0', 70, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (6, 0, 1, NULL, 'Email', NULL, 'TEXTFIELD', NULL, '0', '0', 60, 40, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (22, 0, 1, 'otherlanguages', 'Other languages spoken', NULL, 'TEXTFIELD', NULL, '0', '0', 220, 210, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (469, 0, 11, NULL, 'DEANS/CHAIRPERSONS SIGNATURE', NULL, 'TEXTFIELD', NULL, '0', '0', 170, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (472, 0, 11, NULL, 'NOTE: THE UNIVERSITY OF EASTERN AFRICA, BARATON POLICY WITH RESPECT TO DIFFERED GRADES READS; COURSES FOR WHICH A DG IS USED NORMALLY RUN OVER TWO OR THREE TRIMESTERS, ANY EXTENSION BEYOND THIS NEEDS THE APPROVAL OF THE ACADEMIC STANDARDS COMMITTEE.', NULL, 'TITLE', NULL, '0', '0', 200, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (457, 0, 11, NULL, 'TEACHERS NAME', NULL, 'TEXTFIELD', NULL, '0', '0', 50, 50, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (465, 0, 11, NULL, 'TRIMESTER IN WHICH THE GRADE IS EXPECTED TO BE TURNED IN', NULL, 'TEXTFIELD', NULL, '0', '0', 130, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (454, 0, 11, NULL, 'STUDENT ID NO.', NULL, 'TEXTFIELD', NULL, '0', '0', 20, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (458, 0, 11, NULL, 'SIGNATURE:', NULL, 'TEXTFIELD', NULL, '0', '0', 60, 50, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (455, 0, 11, NULL, 'NAME', NULL, 'TEXTFIELD', NULL, '0', '0', 30, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (456, 0, 11, NULL, 'DATE', NULL, 'TEXTFIELD', NULL, '0', '0', 40, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (467, 0, 11, NULL, 'INSTRUCTORS SIGN', NULL, 'TEXTFIELD', NULL, '0', '0', 150, 140, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (106, 0, 1, NULL, '<b>Parent or Guardians commitment: </b>I agree that the applicant may be a student at the University. I am ready to support the university in its effort to ensure that the applicant abides by the rules and principles of the university and accepts the authority of its administration.', NULL, 'TEXT', NULL, '0', '0', 1010, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (53, 0, 1, NULL, 'How did you know about us (Name of University)?', NULL, 'TEXTFIELD', NULL, '0', '0', 310, -1, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (468, 0, 11, NULL, 'DATE', NULL, 'TEXTFIELD', NULL, '0', '0', 160, 140, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (293, 0, 5, NULL, 'I wish to ADD the following class(es)', NULL, 'TABLE', NULL, '0', '0', 100, NULL, 85, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (708, 0, 1, NULL, 'If yes, Explain', NULL, 'TEXTFIELD', NULL, '0', '0', 370, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (717, 0, 1, NULL, '(Note: There is an inter-semester in January', NULL, 'TEXT', NULL, '0', '0', 268, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (286, 0, 5, NULL, 'DATE', NULL, 'DATE', NULL, '0', '0', 30, 10, 25, NULL, 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (44, 0, 1, 'hsmoke', 'Have you ever smoked?', 'No#Yes', 'LIST', NULL, '0', '0', 440, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (294, 0, 5, NULL, 'Total credits', NULL, 'TEXTFIELD', NULL, '0', '0', 110, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (474, 0, 11, NULL, 'DATE', NULL, 'DATE', NULL, '0', '0', 220, 210, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (619, 0, 17, NULL, 'Date:', NULL, 'DATE', NULL, '0', '0', 10, NULL, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (101, 0, 1, NULL, 'Recommendations: Give names and addresses of two individuals who can give character recommendation. Give the enclosed evaluation/recommendation form to these individuals and ask them to return the forms to you in sealed and rubber-stamped envelopes. One of the recommendations must be from the PRINCIPAL of the school last attended and another one from your CHURCH PASTOR or RELIGIOUS LEADER (if you are a church member)', NULL, 'TEXT', NULL, '0', '0', 1160, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (108, 0, 1, NULL, 'Date', NULL, 'DATE', NULL, '0', '0', 1080, NULL, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (113, 0, 1, NULL, 'Date', NULL, 'DATE', NULL, '0', '0', 1140, NULL, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (16, 0, 1, 'birthdate', 'Birth Date: Day/Month/Year e.g 14/02/2013', NULL, 'DATE', NULL, '0', '0', 160, NULL, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (632, 0, 17, NULL, 'Dear Sir/Madam', NULL, 'TITLE', NULL, '0', '0', 140, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (292, 0, 5, NULL, '1. Advisors signature (to sign first)', NULL, 'TEXTFIELD', NULL, '0', '0', 90, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (640, 0, 17, NULL, '(NAME OF UNIVERSITY)', NULL, 'DATE', NULL, '0', '0', 220, NULL, 25, 'L', 'to_date(''#'', ''DD/MM/YYYY'')', '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (285, 0, 5, 'lastname', 'NAME', NULL, 'TEXTFIELD', NULL, '0', '0', 20, 10, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (298, 0, 5, NULL, '5. My present load in credit hours is', NULL, 'TEXTFIELD', NULL, '0', '0', 150, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (301, 0, 5, NULL, '8. Student Finance clearance (when adding)', NULL, 'TEXTFIELD', NULL, '0', '0', 180, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (297, 0, 5, NULL, '4. Reason for change_', NULL, 'TEXTFIELD', NULL, '0', '0', 140, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (50, 0, 1, 'hdrugs', 'Have you ever used addictive drugs?', 'No#Yes', 'LIST', NULL, '0', '0', 500, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (287, 0, 5, 'majorid', 'MAJOR:', NULL, 'TEXTFIELD', NULL, '0', '0', 40, 40, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (288, 0, 5, 'degreeid', 'DEGREE', NULL, 'TEXTFIELD', NULL, '0', '0', 50, 40, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (8, 0, 1, NULL, 'Permanent Telephone', NULL, 'TEXTFIELD', NULL, '0', '0', 80, 70, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (110, 0, 1, NULL, 'Name and address of person responsible for payment of school fees', NULL, 'TEXTFIELD', NULL, '0', '0', 1050, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (109, 0, 1, NULL, 'Statement of financial responsibility:', NULL, 'TEXT', NULL, '1', '0', 1040, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (114, 0, 1, NULL, 'Do you have an unpaid school account?', 'Yes#No', 'LIST', NULL, '0', '0', 1090, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (117, 0, 1, NULL, 'If Yes, how much?', NULL, 'TEXTFIELD', NULL, '0', '0', 1100, 1170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (118, 0, 1, NULL, 'Where?', NULL, 'TEXTFIELD', NULL, '0', '0', 1110, 1170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (249, 0, 1, NULL, 'If Yes, please explain', NULL, 'TEXTFIELD', NULL, '0', '0', 410, 400, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (20, 0, 1, NULL, 'Passport/ID No', NULL, 'TEXTFIELD', NULL, '0', '0', 200, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (72, 0, 1, 'degreeid', 'Degree desired:', 'B.A#B.Sc#B.B.A#B.T#BEd#BBIT', 'LIST', NULL, '0', '0', 280, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (84, 0, 1, NULL, 'Family Information:', NULL, 'TITLE', NULL, '0', '0', 840, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (2, 0, 1, 'firstname', 'First name', NULL, 'TEXTFIELD', NULL, '0', '0', 20, 10, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (631, 0, 17, NULL, 'FROM: REGISTRAR', NULL, 'TITLE', NULL, '0', '0', 130, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (5, 0, 1, 'phonenumber', 'Present Telephone', NULL, 'TEXTFIELD', NULL, '0', '0', 50, 40, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (85, 0, 1, 'fname', 'Fathers  Name', NULL, 'TEXTFIELD', NULL, '0', '0', 850, 850, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (87, 0, 1, 'foccupation', 'Fathers Occupation', NULL, 'TEXTFIELD', NULL, '0', '0', 870, 870, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (91, 0, 1, 'moccupation', 'Mothers Occupation', NULL, 'TEXTFIELD', NULL, '0', '0', 910, 910, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (31, 0, 1, 'handicap', 'Do you have any physical handicaps?', 'No#Yes', 'LIST', NULL, '0', '0', 400, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (96, 0, 1, NULL, 'Gurdian''s Telephone', NULL, 'TEXTFIELD', NULL, '0', '0', 960, 950, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (248, 0, 1, NULL, '<strong>PART 1:  PERSONAL DETAILS</strong>', NULL, 'TITLE', NULL, '0', '0', 5, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (95, 0, 1, NULL, 'e-mail of Parent(s) or Guardian(s)', NULL, 'TEXTFIELD', NULL, '0', '0', 950, 950, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (107, 0, 1, NULL, 'Signature of parent/guardian', NULL, 'TEXTFIELD', NULL, '0', '0', 1020, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (7, 0, 1, NULL, 'Permanent mailing address', NULL, 'TEXTFIELD', NULL, '0', '0', 70, 70, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (460, 0, 11, NULL, 'Course Code', NULL, 'TEXTFIELD', NULL, '0', '0', 80, 80, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (461, 0, 11, NULL, 'Course Title', NULL, 'TEXTFIELD', NULL, '0', '0', 90, 80, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (462, 0, 11, NULL, 'Credits', NULL, 'TEXTFIELD', NULL, '0', '0', 100, 80, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (466, 0, 11, NULL, 'FINAL GRADE', NULL, 'TEXTFIELD', NULL, '0', '0', 140, 140, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (111, 0, 1, NULL, 'I, the above named, agree to be responsible for the payment of the total school fees of the applicant and to make this payment at the beginning of each semester. I agree to abide by the financial policies of the University.', NULL, 'TEXT', NULL, '0', '0', 1060, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (112, 0, 1, NULL, 'Signature of Parent/Guardian/Sponsor', NULL, 'TEXTFIELD', NULL, '0', '0', 1070, 1120, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (93, 0, 1, NULL, 'Name of legal guardian if not parent(s)', NULL, 'TEXTFIELD', NULL, '0', '0', 930, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (636, 0, 17, NULL, 'ACTION TAKEN BY THE DEAN OF THE SCHOOL', NULL, 'TITLE', NULL, '0', '0', 180, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (90, 0, 1, 'mnationalityid', 'Nationality', 'SELECT sys_country_id,sys_country_name FROM sys_countrys;', 'SELECT', NULL, '0', '0', 900, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (35, 0, 1, 'smoke', 'Do you smoke?', 'No#Yes', 'LIST', NULL, '0', '0', 420, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (250, 0, 1, 'drink', 'Do you Drink alcohol?', 'No#Yes', 'LIST', NULL, '0', '0', 425, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (26, 0, 1, 'personalhealth', 'Personal Health Information:', 'Excellent#Good#Fair#Poor', 'LIST', NULL, '1', '0', 390, -1, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (1, 0, 1, 'lastname', 'Last name (surname)', NULL, 'TEXTFIELD', NULL, '0', '0', 10, 10, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (4, 0, 1, 'homeaddress', 'Present mailing address', NULL, 'TEXTFIELD', NULL, '0', '0', 40, 40, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (17, 0, 1, 'nationalityid', 'Nationality', 'SELECT sys_country_id,sys_country_name FROM sys_countrys;', 'SELECT', NULL, '0', '0', 170, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (18, 0, 1, 'citizenshipid', 'Citizenship', 'SELECT sys_country_id,sys_country_name FROM sys_countrys;', 'SELECT', NULL, '0', '0', 180, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (19, 0, 1, 'residenceid', 'Country of Residence', 'SELECT sys_country_id,sys_country_name FROM sys_countrys;', 'SELECT', NULL, '0', '0', 190, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (21, 0, 1, 'firstlanguage', 'What is your first language?', NULL, 'TEXTFIELD', NULL, '0', '0', 210, 210, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (23, 0, 1, 'denominationid', 'Religious Affiliation', 'SELECT denominationid,denominationname FROM denominations;', 'SELECT', NULL, '0', '0', 230, 230, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (71, 0, 1, 'majorid', 'Course/major field of study for which you are applying', 'SELECT majorid,majorname FROM majors;', 'SELECT', NULL, '0', '0', 270, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (69, 0, 1, 'apply_trimester', 'Trimester for which you are applying', '1st semester August# 2nd semester March', 'LIST', NULL, '0', '0', 260, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (251, 0, 1, 'drugs', 'Do Use addictive drugs?', 'No#Yes', 'LIST', NULL, '0', '0', 430, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (621, 0, 17, NULL, 'FIRST NAME:', NULL, 'TEXTFIELD', NULL, '0', '0', 30, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (464, 0, 11, NULL, 'Trimester', NULL, 'TEXTFIELD', NULL, '0', '0', 120, 80, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (643, 0, 17, NULL, 'ID No.:', NULL, 'TEXTFIELD', NULL, '0', '0', 250, 240, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (706, 0, 1, NULL, 'If yes, Explain', NULL, 'TEXTFIELD', NULL, '0', '0', 350, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (453, 0, 11, NULL, 'DIFERRED GRADE(DG) FORM', NULL, 'TITLE', NULL, '0', '0', 10, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (284, 0, 5, NULL, 'ID NO', NULL, 'TEXTFIELD', NULL, '0', '0', 10, 10, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (633, 0, 17, NULL, 'RE: TRANSFER OF CREDITS', NULL, 'TITLE', NULL, '0', '0', 150, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (634, 0, 17, NULL, 'PLEASE FIND ATTACHED A COPY OF THE ACADEMIC TRANSCRIPT FROM', NULL, 'TEXTFIELD', NULL, '0', '0', 160, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (635, 0, 17, NULL, '(UNIVERSITY/COLLEGE) TOGETHER WITH A COPY OF THE COURSE DESCRIPTION(S) FROM THE SAME INSTITUTION, FOR YOUR USE IN EVALUATING THE ENCLOSED ACADEMIC TRANSCRIPT.', NULL, 'TITLE', NULL, '0', '0', 170, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (642, 0, 17, NULL, 'Name of Dean', NULL, 'TEXTFIELD', NULL, '0', '0', 240, 240, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (290, 0, 5, NULL, 'YEAR', NULL, 'TEXTFIELD', NULL, '0', '0', 70, 40, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (289, 0, 5, NULL, 'SEMESTER', NULL, 'TEXTFIELD', NULL, '0', '0', 60, 40, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (626, 0, 17, NULL, 'TO: THE DEAN', NULL, 'TITLE', NULL, '0', '0', 80, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (60, 0, 1, 'attendeddate', 'Give dates', NULL, 'DATE', NULL, '0', '0', 330, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (13, 0, 1, 'Sex', 'Gender', 'Male# Female', 'LIST', NULL, '0', '0', 130, 130, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (628, 0, 17, NULL, 'NAME OF UNIVERSITY', NULL, 'TITLE', NULL, '0', '0', 100, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (641, 0, 17, NULL, 'P.O BOX 100000 LODWAR', NULL, 'TITLE', NULL, '0', '0', 230, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (645, 0, 17, NULL, 'University/college are transferable to University B.', NULL, 'TITLE', NULL, '0', '0', 270, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (646, 0, 17, NULL, 'UNIVERSITY A TRANSFER CREDIT EVALUATION (OFFICE OF THE REGISTRAR)', NULL, 'TEXTFIELD', NULL, '0', '0', 280, NULL, 85, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (470, 0, 11, NULL, 'DATE', NULL, 'TEXTFIELD', NULL, '0', '0', 180, 170, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (471, 0, 11, NULL, 'Note: The Deans signs only if the Department Chairperson is the instructor or he/she is absent', NULL, 'TITLE', NULL, '0', '0', 190, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (473, 0, 11, NULL, 'REGISTRARS SIGNATURE', NULL, 'TEXTFIELD', NULL, '0', '0', 210, 210, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (715, 0, 1, NULL, '(Note: Any student who does not reside with parents or spouse is expected to live in one of the campus residence halls.)', NULL, 'TEXT', NULL, '1', '0', 305, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (707, 0, 1, NULL, 'Have you been convicted of any crime?', 'Yes#No', 'LIST', NULL, '0', '0', 360, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (302, 0, 5, NULL, '9. Registrar', NULL, 'TEXTFIELD', NULL, '0', '0', 190, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (296, 0, 5, NULL, 'Total credits', NULL, 'TEXTFIELD', NULL, '0', '0', 130, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (104, 0, 1, NULL, 'Signature of Applicant', NULL, 'TEXTFIELD', NULL, '0', '0', 1130, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (47, 0, 1, NULL, 'Have you ever drunk alcohol?', 'No#Yes', 'LIST', NULL, '0', '0', 450, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (624, 0, 17, NULL, 'MINOR:', 'SELECT majorid,majorname FROM majors;', 'SELECT', NULL, '0', '0', 60, 50, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (622, 0, 17, NULL, 'ID NO.', NULL, 'TEXTFIELD', NULL, '0', '0', 40, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (623, 0, 17, NULL, 'MAJOR(S)', 'SELECT majorid,majorname FROM majors;', 'SELECT', NULL, '0', '0', 50, 50, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (627, 0, 17, NULL, 'SCHOOL OF', NULL, 'TEXTFIELD', NULL, '0', '0', 90, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (629, 0, 17, NULL, 'P.O BOX 2500', NULL, 'TITLE', NULL, '0', '0', 110, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (630, 0, 17, NULL, 'ELDORET', NULL, 'TITLE', NULL, '0', '0', 120, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (54, 0, 1, NULL, NULL, NULL, 'SUBGRID', NULL, '0', '0', 315, -1, 85, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (65, 0, 1, NULL, NULL, NULL, 'SUBGRID', NULL, '0', '0', 320, -1, 85, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (57, 0, 1, 'attendedueab', 'Have you ever attended the (Name of University) before?', 'No#Yes', 'LIST', NULL, '0', '0', 325, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (719, 0, 1, NULL, 'What campus will you be attending?', 'Main#Nairobi#Eldoret', 'LIST', NULL, '0', '0', 290, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (295, 0, 5, NULL, '3. I wish to DROP the following class(es)', NULL, 'TABLE', NULL, '0', '0', 120, NULL, 85, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (716, 0, 1, NULL, 'Year', NULL, 'TEXTFIELD', NULL, '0', '0', 265, 690, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (299, 0, 5, NULL, '6. With this change my load credit hours will be', NULL, 'TEXTFIELD', NULL, '0', '0', 160, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (300, 0, 5, NULL, '7. School Deans signature for overload', NULL, 'TEXTFIELD', NULL, '0', '0', 170, NULL, 25, NULL, NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (100, 0, 1, NULL, 'If Yes, give name and address of employer', NULL, 'TEXTFIELD', NULL, '0', '0', 1000, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (94, 0, 1, NULL, 'Address of Parent(s) or Guardian(s)', NULL, 'TEXTFIELD', NULL, '0', '0', 940, NULL, 25, 'L', NULL, '0', '1', 'Family', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (639, 0, 17, NULL, 'FROM: DEAN, SCHOOL OF', NULL, 'TEXTFIELD', NULL, '0', '0', 210, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (625, 0, 17, NULL, 'YEAR OF GRADUATION', NULL, 'TEXTFIELD', NULL, '0', '0', 70, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (638, 0, 17, NULL, 'P.O BOX 10000 LODWAR', NULL, 'TITLE', NULL, '0', '0', 200, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (3, 0, 1, 'middlename', 'Middle name', NULL, 'TEXTFIELD', NULL, '0', '0', 30, 10, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (620, 0, 17, NULL, 'LAST NAME:', NULL, 'TEXTFIELD', NULL, '0', '0', 20, 20, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (718, 0, 1, NULL, 'NOTIFICATION OF ACCEPTANCE: Students are expected to comply with the information given in the admission letter. Please consult the Registrar for clarification. International students must comply with the Kenya Immigration regulations.', NULL, 'TEXT', NULL, '0', '0', 1150, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (79, 0, 1, 'campusresidence', 'Hostel', 'Campus Residence Halls#Off Campus#Faculty/Staff Home', 'LIST', NULL, '0', '0', 300, NULL, 25, 'L', NULL, '0', '1', 'Education', NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (103, 0, 1, NULL, '<b>Applicants commitment:</b> I certify that to the best of my knowledge, the above information is complete and true. I promise that if accepted I will cooperate in following the rules of the University and respect the principles of the institution as they are set forth in the STUDENT HANDBOOK and any other that is communicated by the university.', NULL, 'TEXT', NULL, '0', '0', 1120, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (637, 0, 17, NULL, 'TO: REGISTRAR (NAME OF UNIVERSITY)', NULL, 'TITLE', NULL, '0', '0', 190, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);
INSERT INTO fields (field_id, org_id, form_id, field_name, question, field_lookup, field_type, field_class, field_bold, field_italics, field_order, share_line, field_size, label_position, field_fnct, manditory, show, tab, details) VALUES (644, 0, 17, NULL, 'And I am pleased to state that the credits on the University A transfer form from', NULL, 'TEXTFIELD', NULL, '0', '0', 260, NULL, 25, 'L', NULL, '0', '1', NULL, NULL);


--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fields_field_id_seq', 728, true);


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, details) VALUES (11, 0, 'DIFERRED GRADE(DG) FORM', 'DGF', NULL, '1', '0', '0', 0, '<br><br>', NULL, NULL, NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, details) VALUES (17, 0, 'TRANSFER OF CREDITS REQUEST FORM', 'TOCRF', NULL, '1', '0', '0', 0, 'TRANSFER OF CREDITS REQUEST FORM<br></div><p></p>', NULL, NULL, NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, details) VALUES (5, 0, 'ADD AND DROP FORM', 'ADD AND DROP FORM', NULL, '1', '0', '0', 0, '<p>ADD AND DROP FORM</p>', NULL, NULL, NULL);
INSERT INTO forms (form_id, org_id, form_name, form_number, table_name, version, completed, is_active, use_key, form_header, form_footer, default_values, details) VALUES (1, 0, 'APPLICATION FOR ADMISSION FOR UNDERGRADUATES', 'AAU', 'application_forms', '1', '0', '0', 1, '<p>

Please include the following when returning this form:

<br>a. Certified photocopy(s) of Secondary School Certificate(s)
<br>b. Other certified certificates/diplomas if applicable

<br>c. Application fee of Ksh. 1,500/=/US $ 20 (non-refundable)

<br>d. Two clear, recent passport-size photographs (4.5 sq.cm or 2 in. by 2 in.) Both ears should be clearly seen.

<br>e. Two Application Evaluation/Recommendation in sealed envelopes.
<br>f. Signed affidavit of support by parents/sponsor (for international students).

</p>

', '<p></p><p>NOTIFICATION OF ACCEPTANCE: If admitted,&nbsp; you will be notified in writing. No student should come to the University until he/she receives a formal admission letter. Comply with the information given in the admission letter. Failure to comply with the instructions may lead to cancellation of the admission. International students must also comply with the Kenya Immigration&nbsp; Regulations.</p><br><br><p></p>', NULL, NULL);


--
-- Name: forms_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('forms_form_id_seq', 20, true);


--
-- Data for Name: gradechangelist; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: gradechangelist_gradechangeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('gradechangelist_gradechangeid_seq', 1, false);


--
-- Data for Name: grades; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: healthitems; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: healthitems_healthitemid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('healthitems_healthitemid_seq', 1, false);


--
-- Data for Name: instructors; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: levellocations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: levellocations_levellocationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('levellocations_levellocationid_seq', 1, false);


--
-- Data for Name: majorcontents; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: majorcontents_majorcontentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('majorcontents_majorcontentid_seq', 1, false);


--
-- Data for Name: majoroptcontents; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: majoroptcontents_majoroptcontentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('majoroptcontents_majoroptcontentid_seq', 1, false);


--
-- Data for Name: majoroptions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: majoroptions_majoroptionid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('majoroptions_majoroptionid_seq', 1, false);


--
-- Data for Name: majors; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: marks; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: offers; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: offers_offer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('offers_offer_id_seq', 1, false);


--
-- Data for Name: optiontimes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO optiontimes (optiontimeid, optiontimename, details) VALUES (0, 'Main', NULL);


--
-- Name: optiontimes_optiontimeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('optiontimes_optiontimeid_seq', 1, false);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO orgs (org_id, currency_id, default_country_id, parent_org_id, org_name, org_full_name, org_sufix, is_default, is_active, logo, pin, pcc, system_key, system_identifier, mac_address, public_key, license, details) VALUES (0, 1, NULL, NULL, 'default', NULL, 'dc', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, false);


--
-- Name: picture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('picture_id_seq', 1, false);


--
-- Data for Name: prerequisites; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: prerequisites_prerequisiteid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('prerequisites_prerequisiteid_seq', 1, false);


--
-- Data for Name: qcalendar; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qcalendar_qcalendarid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qcalendar_qcalendarid_seq', 1, false);


--
-- Data for Name: qcourseitems; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qcourseitems_qcourseitemid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qcourseitems_qcourseitemid_seq', 1, false);


--
-- Data for Name: qcoursemarks; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qcoursemarks_qcoursemarkid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qcoursemarks_qcoursemarkid_seq', 1, false);


--
-- Data for Name: qcourses; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qcourses_qcourseid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qcourses_qcourseid_seq', 1, false);


--
-- Data for Name: qexamtimetable; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qexamtimetable_qexamtimetableid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qexamtimetable_qexamtimetableid_seq', 1, false);


--
-- Data for Name: qgrades; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qgrades_qgradeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qgrades_qgradeid_seq', 1, false);


--
-- Data for Name: qposting_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qposting_logs_qposting_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qposting_logs_qposting_log_id_seq', 1, false);


--
-- Data for Name: qresidences; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qresidences_qresidenceid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qresidences_qresidenceid_seq', 1, false);


--
-- Data for Name: qstudents; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qstudents_qstudentid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qstudents_qstudentid_seq', 1, false);


--
-- Data for Name: qtimetable; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: qtimetable_qtimetableid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('qtimetable_qtimetableid_seq', 1, false);


--
-- Data for Name: quarters; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: regcontacts; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: regcontacts_regcontactid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('regcontacts_regcontactid_seq', 1, false);


--
-- Data for Name: reghealth; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: reghealth_reghealthid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reghealth_reghealthid_seq', 1, false);


--
-- Data for Name: registrations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: registrations_registrationid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('registrations_registrationid_seq', 1, false);


--
-- Data for Name: registrymarks; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: registrymarks_registrymarkid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('registrymarks_registrymarkid_seq', 1, false);


--
-- Data for Name: registryschools; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: registryschools_registryschoolid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('registryschools_registryschoolid_seq', 1, false);


--
-- Data for Name: religions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: reporting; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reporting_reporting_id_seq', 1, false);


--
-- Data for Name: requesttypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: requesttypes_requesttypeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requesttypes_requesttypeid_seq', 1, false);


--
-- Data for Name: requirements; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: requirements_requirementid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('requirements_requirementid_seq', 1, false);


--
-- Data for Name: residences; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sabathclasses; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sabathclasses_sabathclassid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sabathclasses_sabathclassid_seq', 1, false);


--
-- Data for Name: schools; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: skill_category; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: skill_category_skill_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('skill_category_skill_category_id_seq', 1, false);


--
-- Data for Name: skill_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: skill_types_skill_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('skill_types_skill_type_id_seq', 1, false);


--
-- Data for Name: skills; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: skills_skill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('skills_skill_id_seq', 1, false);


--
-- Data for Name: student_payments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: student_payments_student_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('student_payments_student_payment_id_seq', 1, false);


--
-- Data for Name: studentdegrees; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: studentdegrees_studentdegreeid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('studentdegrees_studentdegreeid_seq', 1, false);


--
-- Data for Name: studentmajors; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: studentmajors_studentmajorid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('studentmajors_studentmajorid_seq', 1, false);


--
-- Data for Name: studentrequests; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: studentrequests_studentrequestid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('studentrequests_studentrequestid_seq', 1, false);


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (7, 0, 295, 1, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Course Abbr');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (8, 0, 295, 2, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Section');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (9, 0, 295, 3, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Credits');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (10, 0, 295, 4, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Audits');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (11, 0, 295, 5, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Course Title');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (426, 0, 54, 2, NULL, 'LIST', 'Primary School#Secondary School#High School#College#University', 5, 1, '0', '0', 'Level');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (36, 0, 54, 3, NULL, 'DATEFIELD', NULL, 5, 1, '0', '0', 'Dates of Attendance');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (408, 0, 646, 2, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'GRADE');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (409, 0, 646, 3, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'CR.');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (411, 0, 646, 5, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'CR');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (412, 0, 646, 6, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'APPROVED');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (413, 0, 646, 7, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'HOD SIGN');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (407, 0, 646, 1, NULL, 'SELECT', 'SELECT majorid, majorname FROM majors;', 5, 1, '0', '0', '(UNIVERSITY/COLLEGE) COURSE CODE AND TITLE');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (410, 0, 646, 4, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', '(UEAB EQUIVALENT) COURSE CODE AND TITLE');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (39, 0, 65, 3, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Start Date');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (427, 0, 65, 4, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'End Date');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (6, 0, 293, 6, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Instructor''s  Signature');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (12, 0, 295, 6, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Instructor''s  Signature');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (1, 0, 293, 1, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Course Abbr');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (2, 0, 293, 2, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Course');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (3, 0, 293, 3, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Credit');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (4, 0, 293, 4, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Audits');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (5, 0, 293, 5, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Course Title');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (35, 0, 54, 1, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Name of School');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (37, 0, 65, 1, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Employer');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (38, 0, 65, 2, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Position held/type');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (40, 0, 101, 1, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Name');
INSERT INTO sub_fields (sub_field_id, org_id, field_id, sub_field_order, sub_title_share, sub_field_type, sub_field_lookup, sub_field_size, sub_col_spans, manditory, show, question) VALUES (41, 0, 101, 2, NULL, 'TEXTFIELD', NULL, 5, 1, '0', '0', 'Address of Referee');


--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sub_fields_sub_field_id_seq', 429, true);


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sublevels; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (0, 0, 'Basic', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (1, 0, 'Manager', NULL);
INSERT INTO subscription_levels (subscription_level_id, org_id, subscription_level_name, details) VALUES (2, 0, 'Consumer', NULL);


--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscription_levels_subscription_level_id_seq', 3, true);


--
-- Data for Name: sun_audits; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sun_audits_sun_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sun_audits_sun_audit_id_seq', 1, false);


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

INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (1, 0, '2017-03-14 11:17:47.772067', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (2, 0, '2017-03-16 11:14:09.804224', '127.0.0.1', NULL);
INSERT INTO sys_logins (sys_login_id, entity_id, login_time, login_ip, narrative) VALUES (3, 0, '2017-03-21 07:45:45.031496', '127.0.0.1', NULL);


--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 3, true);


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
-- Data for Name: transcriptprint; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transcriptprint_transcriptprintid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transcriptprint_transcriptprintid_seq', 1, false);


--
-- Data for Name: transferedcredits; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transferedcredits_transferedcreditid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transferedcredits_transferedcreditid_seq', 1, false);


--
-- Data for Name: use_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (0, 'Users', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (1, 'Staff', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (2, 'Client', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (3, 'Supplier', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (4, 'Applicant', 0);
INSERT INTO use_keys (use_key_id, use_key_name, use_function) VALUES (5, 'Subscription', 0);


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
-- Name: application_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_pkey PRIMARY KEY (application_form_id);


--
-- Name: applications_offer_id_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT applications_offer_id_entity_id_key UNIQUE (offer_id, entity_id);


--
-- Name: applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (application_id);


--
-- Name: approval_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_pkey PRIMARY KEY (approval_checklist_id);


--
-- Name: approvallist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approvallist
    ADD CONSTRAINT approvallist_pkey PRIMARY KEY (approvalid);


--
-- Name: approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (approval_id);


--
-- Name: assets_assetname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY assets
    ADD CONSTRAINT assets_assetname_key UNIQUE (assetname);


--
-- Name: assets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (assetid);


--
-- Name: bulleting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bulleting
    ADD CONSTRAINT bulleting_pkey PRIMARY KEY (bulletingid);


--
-- Name: charges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (charge_id);


--
-- Name: charges_quarterid_sublevelid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY charges
    ADD CONSTRAINT charges_quarterid_sublevelid_key UNIQUE (quarterid, sublevelid);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: contacttypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contacttypes
    ADD CONSTRAINT contacttypes_pkey PRIMARY KEY (contacttypeid);


--
-- Name: contenttypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contenttypes
    ADD CONSTRAINT contenttypes_pkey PRIMARY KEY (contenttypeid);


--
-- Name: continents_continentname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY continents
    ADD CONSTRAINT continents_continentname_key UNIQUE (continentname);


--
-- Name: continents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY continents
    ADD CONSTRAINT continents_pkey PRIMARY KEY (continentid);


--
-- Name: counties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY counties
    ADD CONSTRAINT counties_pkey PRIMARY KEY (county_id);


--
-- Name: countrys_countryname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY countrys
    ADD CONSTRAINT countrys_countryname_key UNIQUE (countryname);


--
-- Name: countrys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY countrys
    ADD CONSTRAINT countrys_pkey PRIMARY KEY (countryid);


--
-- Name: courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (courseid);


--
-- Name: coursetypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY coursetypes
    ADD CONSTRAINT coursetypes_pkey PRIMARY KEY (coursetypeid);


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
-- Name: cv_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cv_projects
    ADD CONSTRAINT cv_projects_pkey PRIMARY KEY (cv_projectid);


--
-- Name: cv_referees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cv_referees
    ADD CONSTRAINT cv_referees_pkey PRIMARY KEY (cv_referee_id);


--
-- Name: cv_seminars_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cv_seminars
    ADD CONSTRAINT cv_seminars_pkey PRIMARY KEY (cv_seminar_id);


--
-- Name: degreelevels_degreelevelname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY degreelevels
    ADD CONSTRAINT degreelevels_degreelevelname_key UNIQUE (degreelevelname);


--
-- Name: degreelevels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY degreelevels
    ADD CONSTRAINT degreelevels_pkey PRIMARY KEY (degreelevelid);


--
-- Name: degrees_degreename_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY degrees
    ADD CONSTRAINT degrees_degreename_key UNIQUE (degreename);


--
-- Name: degrees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY degrees
    ADD CONSTRAINT degrees_pkey PRIMARY KEY (degreeid);


--
-- Name: denominations_denominationname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY denominations
    ADD CONSTRAINT denominations_denominationname_key UNIQUE (denominationname);


--
-- Name: denominations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY denominations
    ADD CONSTRAINT denominations_pkey PRIMARY KEY (denominationid);


--
-- Name: departments_departmentname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_departmentname_key UNIQUE (departmentname);


--
-- Name: departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (departmentid);


--
-- Name: education_class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY education_class
    ADD CONSTRAINT education_class_pkey PRIMARY KEY (education_class_id);


--
-- Name: education_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY education
    ADD CONSTRAINT education_pkey PRIMARY KEY (education_id);


--
-- Name: employment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY employment
    ADD CONSTRAINT employment_pkey PRIMARY KEY (employment_id);


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
-- Name: evaluation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY evaluation
    ADD CONSTRAINT evaluation_pkey PRIMARY KEY (evaluationid);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


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
-- Name: gradechangelist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY gradechangelist
    ADD CONSTRAINT gradechangelist_pkey PRIMARY KEY (gradechangeid);


--
-- Name: grades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY grades
    ADD CONSTRAINT grades_pkey PRIMARY KEY (gradeid);


--
-- Name: healthitems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY healthitems
    ADD CONSTRAINT healthitems_pkey PRIMARY KEY (healthitemid);


--
-- Name: instructors_instructorname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instructors
    ADD CONSTRAINT instructors_instructorname_key UNIQUE (instructorname);


--
-- Name: instructors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY instructors
    ADD CONSTRAINT instructors_pkey PRIMARY KEY (instructorid);


--
-- Name: levellocations_levellocationname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY levellocations
    ADD CONSTRAINT levellocations_levellocationname_key UNIQUE (levellocationname);


--
-- Name: levellocations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY levellocations
    ADD CONSTRAINT levellocations_pkey PRIMARY KEY (levellocationid);


--
-- Name: majorcontents_majorid_courseid_contenttypeid_minor_bulletin_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_majorid_courseid_contenttypeid_minor_bulletin_key UNIQUE (majorid, courseid, contenttypeid, minor, bulletingid);


--
-- Name: majorcontents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_pkey PRIMARY KEY (majorcontentid);


--
-- Name: majoroptcontents_majoroptionid_courseid_contenttypeid_minor_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_majoroptionid_courseid_contenttypeid_minor_key UNIQUE (majoroptionid, courseid, contenttypeid, minor, bulletingid);


--
-- Name: majoroptcontents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_pkey PRIMARY KEY (majoroptcontentid);


--
-- Name: majoroptions_majorid_majoroptionname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majoroptions
    ADD CONSTRAINT majoroptions_majorid_majoroptionname_key UNIQUE (majorid, majoroptionname);


--
-- Name: majoroptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majoroptions
    ADD CONSTRAINT majoroptions_pkey PRIMARY KEY (majoroptionid);


--
-- Name: majors_majorname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majors
    ADD CONSTRAINT majors_majorname_key UNIQUE (majorname);


--
-- Name: majors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY majors
    ADD CONSTRAINT majors_pkey PRIMARY KEY (majorid);


--
-- Name: marks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY marks
    ADD CONSTRAINT marks_pkey PRIMARY KEY (markid);


--
-- Name: offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (offer_id);


--
-- Name: optiontimes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY optiontimes
    ADD CONSTRAINT optiontimes_pkey PRIMARY KEY (optiontimeid);


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
-- Name: prerequisites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY prerequisites
    ADD CONSTRAINT prerequisites_pkey PRIMARY KEY (prerequisiteid);


--
-- Name: qcalendar_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qcalendar
    ADD CONSTRAINT qcalendar_pkey PRIMARY KEY (qcalendarid);


--
-- Name: qcourseitems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qcourseitems
    ADD CONSTRAINT qcourseitems_pkey PRIMARY KEY (qcourseitemid);


--
-- Name: qcoursemarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qcoursemarks
    ADD CONSTRAINT qcoursemarks_pkey PRIMARY KEY (qcoursemarkid);


--
-- Name: qcourses_instructorid_courseid_quarterid_classoption_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_instructorid_courseid_quarterid_classoption_key UNIQUE (instructorid, courseid, quarterid, classoption);


--
-- Name: qcourses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_pkey PRIMARY KEY (qcourseid);


--
-- Name: qexamtimetable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qexamtimetable
    ADD CONSTRAINT qexamtimetable_pkey PRIMARY KEY (qexamtimetableid);


--
-- Name: qgrades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_pkey PRIMARY KEY (qgradeid);


--
-- Name: qgrades_qstudentid_qcourseid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_qstudentid_qcourseid_key UNIQUE (qstudentid, qcourseid);


--
-- Name: qposting_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qposting_logs
    ADD CONSTRAINT qposting_logs_pkey PRIMARY KEY (qposting_log_id);


--
-- Name: qresidences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qresidences
    ADD CONSTRAINT qresidences_pkey PRIMARY KEY (qresidenceid);


--
-- Name: qresidences_quarterid_residenceid_residenceoption_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qresidences
    ADD CONSTRAINT qresidences_quarterid_residenceid_residenceoption_key UNIQUE (quarterid, residenceid, residenceoption);


--
-- Name: qstudents_charge_id_studentdegreeid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_charge_id_studentdegreeid_key UNIQUE (charge_id, studentdegreeid);


--
-- Name: qstudents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_pkey PRIMARY KEY (qstudentid);


--
-- Name: qtimetable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qtimetable
    ADD CONSTRAINT qtimetable_pkey PRIMARY KEY (qtimetableid);


--
-- Name: quarters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY quarters
    ADD CONSTRAINT quarters_pkey PRIMARY KEY (quarterid);


--
-- Name: regcontacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regcontacts
    ADD CONSTRAINT regcontacts_pkey PRIMARY KEY (regcontactid);


--
-- Name: regcontacts_registrationid_contacttypeid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY regcontacts
    ADD CONSTRAINT regcontacts_registrationid_contacttypeid_key UNIQUE (registrationid, contacttypeid);


--
-- Name: reghealth_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reghealth
    ADD CONSTRAINT reghealth_pkey PRIMARY KEY (reghealthid);


--
-- Name: reghealth_registrationid_healthitemid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reghealth
    ADD CONSTRAINT reghealth_registrationid_healthitemid_key UNIQUE (registrationid, healthitemid);


--
-- Name: registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_pkey PRIMARY KEY (registrationid);


--
-- Name: registrymarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_pkey PRIMARY KEY (registrymarkid);


--
-- Name: registrymarks_registrationid_subjectid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_registrationid_subjectid_key UNIQUE (registrationid, subjectid);


--
-- Name: registryschools_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY registryschools
    ADD CONSTRAINT registryschools_pkey PRIMARY KEY (registryschoolid);


--
-- Name: religions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY religions
    ADD CONSTRAINT religions_pkey PRIMARY KEY (religionid);


--
-- Name: reporting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_pkey PRIMARY KEY (reporting_id);


--
-- Name: requesttypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requesttypes
    ADD CONSTRAINT requesttypes_pkey PRIMARY KEY (requesttypeid);


--
-- Name: requesttypes_requesttypename_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requesttypes
    ADD CONSTRAINT requesttypes_requesttypename_key UNIQUE (requesttypename);


--
-- Name: requirements_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY requirements
    ADD CONSTRAINT requirements_pkey PRIMARY KEY (requirementid);


--
-- Name: residences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY residences
    ADD CONSTRAINT residences_pkey PRIMARY KEY (residenceid);


--
-- Name: residences_residencename_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY residences
    ADD CONSTRAINT residences_residencename_key UNIQUE (residencename);


--
-- Name: sabathclasses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sabathclasses
    ADD CONSTRAINT sabathclasses_pkey PRIMARY KEY (sabathclassid);


--
-- Name: sabathclasses_sabathclassoption_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sabathclasses
    ADD CONSTRAINT sabathclasses_sabathclassoption_key UNIQUE (sabathclassoption);


--
-- Name: schools_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (schoolid);


--
-- Name: skill_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY skill_category
    ADD CONSTRAINT skill_category_pkey PRIMARY KEY (skill_category_id);


--
-- Name: skill_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY skill_types
    ADD CONSTRAINT skill_types_pkey PRIMARY KEY (skill_type_id);


--
-- Name: skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY skills
    ADD CONSTRAINT skills_pkey PRIMARY KEY (skill_id);


--
-- Name: student_payments_customerreference_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY student_payments
    ADD CONSTRAINT student_payments_customerreference_key UNIQUE (customerreference);


--
-- Name: student_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY student_payments
    ADD CONSTRAINT student_payments_pkey PRIMARY KEY (student_payment_id);


--
-- Name: studentdegrees_degreeid_studentid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_degreeid_studentid_key UNIQUE (degreeid, studentid);


--
-- Name: studentdegrees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_pkey PRIMARY KEY (studentdegreeid);


--
-- Name: studentmajors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY studentmajors
    ADD CONSTRAINT studentmajors_pkey PRIMARY KEY (studentmajorid);


--
-- Name: studentmajors_studentdegreeid_majorid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY studentmajors
    ADD CONSTRAINT studentmajors_studentdegreeid_majorid_key UNIQUE (studentdegreeid, majorid);


--
-- Name: studentrequests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY studentrequests
    ADD CONSTRAINT studentrequests_pkey PRIMARY KEY (studentrequestid);


--
-- Name: students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_pkey PRIMARY KEY (studentid);


--
-- Name: sub_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_pkey PRIMARY KEY (sub_field_id);


--
-- Name: subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (subjectid);


--
-- Name: sublevels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_pkey PRIMARY KEY (sublevelid);


--
-- Name: sublevels_sublevelname_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_sublevelname_key UNIQUE (sublevelname);


--
-- Name: subscription_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_pkey PRIMARY KEY (subscription_level_id);


--
-- Name: sun_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sun_audits
    ADD CONSTRAINT sun_audits_pkey PRIMARY KEY (sun_audit_id);


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
-- Name: transcriptprint_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transcriptprint
    ADD CONSTRAINT transcriptprint_pkey PRIMARY KEY (transcriptprintid);


--
-- Name: transferedcredits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transferedcredits
    ADD CONSTRAINT transferedcredits_pkey PRIMARY KEY (transferedcreditid);


--
-- Name: transferedcredits_studentdegreeid_courseid_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transferedcredits
    ADD CONSTRAINT transferedcredits_studentdegreeid_courseid_key UNIQUE (studentdegreeid, courseid);


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
-- Name: applications_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applications_entity_id ON applications USING btree (entity_id);


--
-- Name: applications_offer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applications_offer_id ON applications USING btree (offer_id);


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
-- Name: approvallist_qstudentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvallist_qstudentid ON approvallist USING btree (qstudentid);


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
-- Name: charges_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX charges_org_id ON charges USING btree (org_id);


--
-- Name: charges_sublevelid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX charges_sublevelid ON charges USING btree (sublevelid);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: countrys_continentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX countrys_continentid ON countrys USING btree (continentid);


--
-- Name: courses_coursetypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX courses_coursetypeid ON courses USING btree (coursetypeid);


--
-- Name: courses_degreelevelid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX courses_degreelevelid ON courses USING btree (degreelevelid);


--
-- Name: courses_departmentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX courses_departmentid ON courses USING btree (departmentid);


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
-- Name: cv_projects_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cv_projects_entity_id ON cv_projects USING btree (entity_id);


--
-- Name: cv_referees_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cv_referees_entity_id ON cv_referees USING btree (entity_id);


--
-- Name: cv_seminars_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX cv_seminars_entity_id ON cv_seminars USING btree (entity_id);


--
-- Name: denominations_religionid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX denominations_religionid ON denominations USING btree (religionid);


--
-- Name: departments_schoolid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX departments_schoolid ON departments USING btree (schoolid);


--
-- Name: education_education_class_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX education_education_class_id ON education USING btree (education_class_id);


--
-- Name: education_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX education_entity_id ON education USING btree (entity_id);


--
-- Name: employment_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX employment_entity_id ON employment USING btree (entity_id);


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
-- Name: evaluation_registrationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX evaluation_registrationid ON evaluation USING btree (registrationid);


--
-- Name: fields_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_form_id ON fields USING btree (form_id);


--
-- Name: fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_org_id ON fields USING btree (org_id);


--
-- Name: forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX forms_org_id ON forms USING btree (org_id);


--
-- Name: gradechangelist_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gradechangelist_entity_id ON gradechangelist USING btree (entity_id);


--
-- Name: gradechangelist_qgradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gradechangelist_qgradeid ON gradechangelist USING btree (qgradeid);


--
-- Name: instructors_departmentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX instructors_departmentid ON instructors USING btree (departmentid);


--
-- Name: majorcontents_bulletingid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majorcontents_bulletingid ON majorcontents USING btree (bulletingid);


--
-- Name: majorcontents_contenttypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majorcontents_contenttypeid ON majorcontents USING btree (contenttypeid);


--
-- Name: majorcontents_courseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majorcontents_courseid ON majorcontents USING btree (courseid);


--
-- Name: majorcontents_gradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majorcontents_gradeid ON majorcontents USING btree (gradeid);


--
-- Name: majorcontents_majorid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majorcontents_majorid ON majorcontents USING btree (majorid);


--
-- Name: majoroptcontents_bulletingid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptcontents_bulletingid ON majoroptcontents USING btree (bulletingid);


--
-- Name: majoroptcontents_contenttypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptcontents_contenttypeid ON majoroptcontents USING btree (contenttypeid);


--
-- Name: majoroptcontents_courseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptcontents_courseid ON majoroptcontents USING btree (courseid);


--
-- Name: majoroptcontents_gradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptcontents_gradeid ON majoroptcontents USING btree (gradeid);


--
-- Name: majoroptcontents_majoroptionid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptcontents_majoroptionid ON majoroptcontents USING btree (majoroptionid);


--
-- Name: majoroptions_majorid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majoroptions_majorid ON majoroptions USING btree (majorid);


--
-- Name: majors_departmentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX majors_departmentid ON majors USING btree (departmentid);


--
-- Name: offers_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX offers_entity_id ON offers USING btree (entity_id);


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
-- Name: prerequisites_bulletingid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX prerequisites_bulletingid ON prerequisites USING btree (bulletingid);


--
-- Name: prerequisites_courseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX prerequisites_courseid ON prerequisites USING btree (courseid);


--
-- Name: prerequisites_gradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX prerequisites_gradeid ON prerequisites USING btree (gradeid);


--
-- Name: prerequisites_precourseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX prerequisites_precourseid ON prerequisites USING btree (precourseid);


--
-- Name: qcalendar_quarterid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcalendar_quarterid ON qcalendar USING btree (quarterid);


--
-- Name: qcalendar_sublevelid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcalendar_sublevelid ON qcalendar USING btree (sublevelid);


--
-- Name: qcourseitems_qcourseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcourseitems_qcourseid ON qcourseitems USING btree (qcourseid);


--
-- Name: qcoursemarks_qcourseitemid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcoursemarks_qcourseitemid ON qcoursemarks USING btree (qcourseitemid);


--
-- Name: qcoursemarks_qgradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcoursemarks_qgradeid ON qcoursemarks USING btree (qgradeid);


--
-- Name: qcourses_courseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcourses_courseid ON qcourses USING btree (courseid);


--
-- Name: qcourses_instructorid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcourses_instructorid ON qcourses USING btree (instructorid);


--
-- Name: qcourses_levellocationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcourses_levellocationid ON qcourses USING btree (levellocationid);


--
-- Name: qcourses_quarterid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qcourses_quarterid ON qcourses USING btree (quarterid);


--
-- Name: qexamtimetable_assetid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qexamtimetable_assetid ON qexamtimetable USING btree (assetid);


--
-- Name: qexamtimetable_optiontimeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qexamtimetable_optiontimeid ON qexamtimetable USING btree (optiontimeid);


--
-- Name: qexamtimetable_qcourseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qexamtimetable_qcourseid ON qexamtimetable USING btree (qcourseid);


--
-- Name: qgrades_gradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_gradeid ON qgrades USING btree (gradeid);


--
-- Name: qgrades_lecture_gradeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_lecture_gradeid ON qgrades USING btree (lecture_gradeid);


--
-- Name: qgrades_optiontimeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_optiontimeid ON qgrades USING btree (optiontimeid);


--
-- Name: qgrades_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_org_id ON qgrades USING btree (org_id);


--
-- Name: qgrades_qcourseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_qcourseid ON qgrades USING btree (qcourseid);


--
-- Name: qgrades_qstudentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_qstudentid ON qgrades USING btree (qstudentid);


--
-- Name: qgrades_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qgrades_sys_audit_trail_id ON qgrades USING btree (sys_audit_trail_id);


--
-- Name: qposting_logs_qstudentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qposting_logs_qstudentid ON qposting_logs USING btree (qstudentid);


--
-- Name: qposting_logs_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qposting_logs_sys_audit_trail_id ON qposting_logs USING btree (sys_audit_trail_id);


--
-- Name: qresidences_quarterid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qresidences_quarterid ON qresidences USING btree (quarterid);


--
-- Name: qresidences_residenceid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qresidences_residenceid ON qresidences USING btree (residenceid);


--
-- Name: qstudents_approved; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_approved ON qstudents USING btree (approved);


--
-- Name: qstudents_charge_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_charge_id ON qstudents USING btree (charge_id);


--
-- Name: qstudents_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_org_id ON qstudents USING btree (org_id);


--
-- Name: qstudents_qresidenceid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_qresidenceid ON qstudents USING btree (qresidenceid);


--
-- Name: qstudents_quarterid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_quarterid ON qstudents USING btree (quarterid);


--
-- Name: qstudents_roomnumber; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_roomnumber ON qstudents USING btree (roomnumber);


--
-- Name: qstudents_sabathclassid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_sabathclassid ON qstudents USING btree (sabathclassid);


--
-- Name: qstudents_studentdegreeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_studentdegreeid ON qstudents USING btree (studentdegreeid);


--
-- Name: qstudents_sys_audit_trail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qstudents_sys_audit_trail_id ON qstudents USING btree (sys_audit_trail_id);


--
-- Name: qtimetable_assetid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qtimetable_assetid ON qtimetable USING btree (assetid);


--
-- Name: qtimetable_optiontimeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qtimetable_optiontimeid ON qtimetable USING btree (optiontimeid);


--
-- Name: qtimetable_qcourseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX qtimetable_qcourseid ON qtimetable USING btree (qcourseid);


--
-- Name: quarters_active; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quarters_active ON quarters USING btree (active);


--
-- Name: regcontacts_contacttypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX regcontacts_contacttypeid ON regcontacts USING btree (contacttypeid);


--
-- Name: regcontacts_registrationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX regcontacts_registrationid ON regcontacts USING btree (registrationid);


--
-- Name: reghealth_healthitemid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reghealth_healthitemid ON reghealth USING btree (healthitemid);


--
-- Name: reghealth_registrationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reghealth_registrationid ON reghealth USING btree (registrationid);


--
-- Name: registrations_citizenshipid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_citizenshipid ON registrations USING btree (citizenshipid);


--
-- Name: registrations_county_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_county_id ON registrations USING btree (county_id);


--
-- Name: registrations_denominationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_denominationid ON registrations USING btree (denominationid);


--
-- Name: registrations_fdenominationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_fdenominationid ON registrations USING btree (fdenominationid);


--
-- Name: registrations_mdenominationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_mdenominationid ON registrations USING btree (mdenominationid);


--
-- Name: registrations_nationalityid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_nationalityid ON registrations USING btree (nationalityid);


--
-- Name: registrations_residenceid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrations_residenceid ON registrations USING btree (residenceid);


--
-- Name: registrymarks_markid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrymarks_markid ON registrymarks USING btree (markid);


--
-- Name: registrymarks_registrationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrymarks_registrationid ON registrymarks USING btree (registrationid);


--
-- Name: registrymarks_subjectid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registrymarks_subjectid ON registrymarks USING btree (subjectid);


--
-- Name: registryschools_registrationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX registryschools_registrationid ON registryschools USING btree (registrationid);


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
-- Name: requirements_majorid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX requirements_majorid ON requirements USING btree (majorid);


--
-- Name: requirements_markid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX requirements_markid ON requirements USING btree (markid);


--
-- Name: requirements_subjectid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX requirements_subjectid ON requirements USING btree (subjectid);


--
-- Name: skill_types_skill_category_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX skill_types_skill_category_id ON skill_types USING btree (skill_category_id);


--
-- Name: skills_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX skills_entity_id ON skills USING btree (entity_id);


--
-- Name: skills_skill_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX skills_skill_type_id ON skills USING btree (skill_type_id);


--
-- Name: student_payments_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX student_payments_org_id ON student_payments USING btree (org_id);


--
-- Name: student_payments_qstudentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX student_payments_qstudentid ON student_payments USING btree (qstudentid);


--
-- Name: studentdegrees_bulletingid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentdegrees_bulletingid ON studentdegrees USING btree (bulletingid);


--
-- Name: studentdegrees_degreeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentdegrees_degreeid ON studentdegrees USING btree (degreeid);


--
-- Name: studentdegrees_studentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentdegrees_studentid ON studentdegrees USING btree (studentid);


--
-- Name: studentdegrees_sublevelid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentdegrees_sublevelid ON studentdegrees USING btree (sublevelid);


--
-- Name: studentmajors_majorid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentmajors_majorid ON studentmajors USING btree (majorid);


--
-- Name: studentmajors_majoroptionid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentmajors_majoroptionid ON studentmajors USING btree (majoroptionid);


--
-- Name: studentmajors_studentdegreeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentmajors_studentdegreeid ON studentmajors USING btree (studentdegreeid);


--
-- Name: studentrequests_requesttypeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentrequests_requesttypeid ON studentrequests USING btree (requesttypeid);


--
-- Name: studentrequests_studentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX studentrequests_studentid ON studentrequests USING btree (studentid);


--
-- Name: students_accountnumber; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_accountnumber ON students USING btree (accountnumber);


--
-- Name: students_countrycodeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_countrycodeid ON students USING btree (countrycodeid);


--
-- Name: students_denominationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_denominationid ON students USING btree (denominationid);


--
-- Name: students_gcountrycodeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_gcountrycodeid ON students USING btree (gcountrycodeid);


--
-- Name: students_nationality; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_nationality ON students USING btree (nationality);


--
-- Name: students_residenceid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_residenceid ON students USING btree (residenceid);


--
-- Name: students_schoolid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX students_schoolid ON students USING btree (schoolid);


--
-- Name: sub_fields_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_field_id ON sub_fields USING btree (field_id);


--
-- Name: sub_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_org_id ON sub_fields USING btree (org_id);


--
-- Name: sublevels_degreelevelid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sublevels_degreelevelid ON sublevels USING btree (degreelevelid);


--
-- Name: sublevels_levellocationid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sublevels_levellocationid ON sublevels USING btree (levellocationid);


--
-- Name: sublevels_markid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sublevels_markid ON sublevels USING btree (markid);


--
-- Name: subscription_levels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscription_levels_org_id ON subscription_levels USING btree (org_id);


--
-- Name: sun_audits_studentid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sun_audits_studentid ON sun_audits USING btree (studentid);


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
-- Name: transcriptprint_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transcriptprint_entity_id ON transcriptprint USING btree (entity_id);


--
-- Name: transcriptprint_studentdegreeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transcriptprint_studentdegreeid ON transcriptprint USING btree (studentdegreeid);


--
-- Name: transferedcredits_courseid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transferedcredits_courseid ON transferedcredits USING btree (courseid);


--
-- Name: transferedcredits_studentdegreeid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transferedcredits_studentdegreeid ON transferedcredits USING btree (studentdegreeid);


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
-- Name: aft_instructors; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aft_instructors AFTER INSERT OR UPDATE ON instructors FOR EACH ROW EXECUTE PROCEDURE aft_instructors();


--
-- Name: aft_student_payments; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aft_student_payments AFTER INSERT OR UPDATE ON student_payments FOR EACH ROW EXECUTE PROCEDURE aft_student_payments();


--
-- Name: del_qgrades; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER del_qgrades BEFORE DELETE ON qgrades FOR EACH ROW EXECUTE PROCEDURE del_qgrades();


--
-- Name: ins_address; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_address BEFORE INSERT OR UPDATE ON address FOR EACH ROW EXECUTE PROCEDURE ins_address();


--
-- Name: ins_application; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_application AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_application();


--
-- Name: ins_application_forms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_application_forms AFTER INSERT ON application_forms FOR EACH ROW EXECUTE PROCEDURE ins_application_forms();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_charges; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_charges BEFORE INSERT OR UPDATE ON charges FOR EACH ROW EXECUTE PROCEDURE ins_charges();


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
-- Name: ins_qcourses; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qcourses BEFORE INSERT ON qcourses FOR EACH ROW EXECUTE PROCEDURE ins_qcourses();


--
-- Name: ins_qgrades; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qgrades BEFORE INSERT OR UPDATE ON qgrades FOR EACH ROW EXECUTE PROCEDURE ins_qgrades();


--
-- Name: ins_qresidences; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qresidences BEFORE INSERT OR UPDATE ON qresidences FOR EACH ROW EXECUTE PROCEDURE ins_qresidences();


--
-- Name: ins_qstudents; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qstudents BEFORE INSERT OR UPDATE ON qstudents FOR EACH ROW EXECUTE PROCEDURE ins_qstudents();


--
-- Name: ins_qtimetable; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qtimetable BEFORE INSERT OR UPDATE ON qtimetable FOR EACH ROW EXECUTE PROCEDURE ins_qtimetable();


--
-- Name: ins_qtimetable; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_qtimetable BEFORE INSERT OR UPDATE ON qexamtimetable FOR EACH ROW EXECUTE PROCEDURE ins_qtimetable();


--
-- Name: ins_quarters; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_quarters AFTER INSERT ON quarters FOR EACH ROW EXECUTE PROCEDURE ins_quarters();


--
-- Name: ins_registrations; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_registrations BEFORE INSERT ON registrations FOR EACH ROW EXECUTE PROCEDURE ins_registrations();


--
-- Name: ins_residences; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_residences BEFORE INSERT OR UPDATE ON residences FOR EACH ROW EXECUTE PROCEDURE sel_campus();


--
-- Name: ins_studentdegrees; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_studentdegrees AFTER INSERT OR UPDATE ON studentdegrees FOR EACH ROW EXECUTE PROCEDURE ins_studentdegrees();


--
-- Name: ins_students; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_students AFTER INSERT ON students FOR EACH ROW EXECUTE PROCEDURE ins_students();


--
-- Name: ins_sub_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sub_fields BEFORE INSERT ON sub_fields FOR EACH ROW EXECUTE PROCEDURE ins_sub_fields();


--
-- Name: ins_sublevels; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sublevels BEFORE INSERT OR UPDATE ON sublevels FOR EACH ROW EXECUTE PROCEDURE sel_campus();


--
-- Name: ins_sys_reset; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sys_reset AFTER INSERT ON sys_reset FOR EACH ROW EXECUTE PROCEDURE ins_sys_reset();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: upd_qcourses; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_qcourses BEFORE INSERT OR UPDATE ON qcourses FOR EACH ROW EXECUTE PROCEDURE upd_qcourses();


--
-- Name: updqcourseitems; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER updqcourseitems AFTER INSERT ON qcourseitems FOR EACH ROW EXECUTE PROCEDURE updqcourseitems();


--
-- Name: updqgrades; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER updqgrades BEFORE UPDATE ON qgrades FOR EACH ROW EXECUTE PROCEDURE updqgrades();


--
-- Name: updqstudents; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER updqstudents AFTER UPDATE ON qstudents FOR EACH ROW EXECUTE PROCEDURE updqstudents();


--
-- Name: updstudents; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER updstudents AFTER UPDATE ON students FOR EACH ROW EXECUTE PROCEDURE updstudents();


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
-- Name: application_forms_citizenshipid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_citizenshipid_fkey FOREIGN KEY (citizenshipid) REFERENCES countrys(countryid);


--
-- Name: application_forms_county_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_county_id_fkey FOREIGN KEY (county_id) REFERENCES counties(county_id);


--
-- Name: application_forms_degreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_degreeid_fkey FOREIGN KEY (degreeid) REFERENCES degrees(degreeid);


--
-- Name: application_forms_denominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_denominationid_fkey FOREIGN KEY (denominationid) REFERENCES denominations(denominationid);


--
-- Name: application_forms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: application_forms_entry_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_entry_form_id_fkey FOREIGN KEY (entry_form_id) REFERENCES entry_forms(entry_form_id);


--
-- Name: application_forms_fdenominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_fdenominationid_fkey FOREIGN KEY (fdenominationid) REFERENCES denominations(denominationid);


--
-- Name: application_forms_fnationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_fnationalityid_fkey FOREIGN KEY (fnationalityid) REFERENCES countrys(countryid);


--
-- Name: application_forms_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: application_forms_markid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_markid_fkey FOREIGN KEY (markid) REFERENCES marks(markid);


--
-- Name: application_forms_mdenominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_mdenominationid_fkey FOREIGN KEY (mdenominationid) REFERENCES denominations(denominationid);


--
-- Name: application_forms_mnationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_mnationalityid_fkey FOREIGN KEY (mnationalityid) REFERENCES countrys(countryid);


--
-- Name: application_forms_nationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_nationalityid_fkey FOREIGN KEY (nationalityid) REFERENCES countrys(countryid);


--
-- Name: application_forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: application_forms_residenceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_residenceid_fkey FOREIGN KEY (residenceid) REFERENCES countrys(countryid);


--
-- Name: application_forms_sublevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY application_forms
    ADD CONSTRAINT application_forms_sublevelid_fkey FOREIGN KEY (sublevelid) REFERENCES sublevels(sublevelid);


--
-- Name: applications_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT applications_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: applications_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applications
    ADD CONSTRAINT applications_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES offers(offer_id);


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
-- Name: approvallist_qstudentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvallist
    ADD CONSTRAINT approvallist_qstudentid_fkey FOREIGN KEY (qstudentid) REFERENCES qstudents(qstudentid);


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
-- Name: assets_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assets
    ADD CONSTRAINT assets_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: charges_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY charges
    ADD CONSTRAINT charges_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: charges_quarterid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY charges
    ADD CONSTRAINT charges_quarterid_fkey FOREIGN KEY (quarterid) REFERENCES quarters(quarterid);


--
-- Name: charges_sublevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY charges
    ADD CONSTRAINT charges_sublevelid_fkey FOREIGN KEY (sublevelid) REFERENCES sublevels(sublevelid);


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
-- Name: countrys_continentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY countrys
    ADD CONSTRAINT countrys_continentid_fkey FOREIGN KEY (continentid) REFERENCES continents(continentid);


--
-- Name: courses_coursetypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY courses
    ADD CONSTRAINT courses_coursetypeid_fkey FOREIGN KEY (coursetypeid) REFERENCES coursetypes(coursetypeid);


--
-- Name: courses_degreelevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY courses
    ADD CONSTRAINT courses_degreelevelid_fkey FOREIGN KEY (degreelevelid) REFERENCES degreelevels(degreelevelid);


--
-- Name: courses_departmentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY courses
    ADD CONSTRAINT courses_departmentid_fkey FOREIGN KEY (departmentid) REFERENCES departments(departmentid);


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
-- Name: cv_projects_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_projects
    ADD CONSTRAINT cv_projects_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: cv_referees_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_referees
    ADD CONSTRAINT cv_referees_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: cv_seminars_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY cv_seminars
    ADD CONSTRAINT cv_seminars_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: degrees_degreelevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY degrees
    ADD CONSTRAINT degrees_degreelevelid_fkey FOREIGN KEY (degreelevelid) REFERENCES degreelevels(degreelevelid);


--
-- Name: denominations_religionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY denominations
    ADD CONSTRAINT denominations_religionid_fkey FOREIGN KEY (religionid) REFERENCES religions(religionid);


--
-- Name: departments_schoolid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_schoolid_fkey FOREIGN KEY (schoolid) REFERENCES schools(schoolid);


--
-- Name: education_education_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY education
    ADD CONSTRAINT education_education_class_id_fkey FOREIGN KEY (education_class_id) REFERENCES education_class(education_class_id);


--
-- Name: education_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY education
    ADD CONSTRAINT education_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: employment_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY employment
    ADD CONSTRAINT employment_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


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
-- Name: evaluation_registrationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY evaluation
    ADD CONSTRAINT evaluation_registrationid_fkey FOREIGN KEY (registrationid) REFERENCES registrations(registrationid);


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
-- Name: forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: gradechangelist_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gradechangelist
    ADD CONSTRAINT gradechangelist_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: gradechangelist_qgradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gradechangelist
    ADD CONSTRAINT gradechangelist_qgradeid_fkey FOREIGN KEY (qgradeid) REFERENCES qgrades(qgradeid);


--
-- Name: instructors_departmentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instructors
    ADD CONSTRAINT instructors_departmentid_fkey FOREIGN KEY (departmentid) REFERENCES departments(departmentid);


--
-- Name: instructors_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instructors
    ADD CONSTRAINT instructors_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: instructors_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY instructors
    ADD CONSTRAINT instructors_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: levellocations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY levellocations
    ADD CONSTRAINT levellocations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: majorcontents_bulletingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_bulletingid_fkey FOREIGN KEY (bulletingid) REFERENCES bulleting(bulletingid);


--
-- Name: majorcontents_contenttypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_contenttypeid_fkey FOREIGN KEY (contenttypeid) REFERENCES contenttypes(contenttypeid);


--
-- Name: majorcontents_courseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_courseid_fkey FOREIGN KEY (courseid) REFERENCES courses(courseid);


--
-- Name: majorcontents_gradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_gradeid_fkey FOREIGN KEY (gradeid) REFERENCES grades(gradeid);


--
-- Name: majorcontents_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majorcontents
    ADD CONSTRAINT majorcontents_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: majoroptcontents_bulletingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_bulletingid_fkey FOREIGN KEY (bulletingid) REFERENCES bulleting(bulletingid);


--
-- Name: majoroptcontents_contenttypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_contenttypeid_fkey FOREIGN KEY (contenttypeid) REFERENCES contenttypes(contenttypeid);


--
-- Name: majoroptcontents_courseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_courseid_fkey FOREIGN KEY (courseid) REFERENCES courses(courseid);


--
-- Name: majoroptcontents_gradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_gradeid_fkey FOREIGN KEY (gradeid) REFERENCES grades(gradeid);


--
-- Name: majoroptcontents_majoroptionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptcontents
    ADD CONSTRAINT majoroptcontents_majoroptionid_fkey FOREIGN KEY (majoroptionid) REFERENCES majoroptions(majoroptionid);


--
-- Name: majoroptions_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majoroptions
    ADD CONSTRAINT majoroptions_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: majors_departmentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY majors
    ADD CONSTRAINT majors_departmentid_fkey FOREIGN KEY (departmentid) REFERENCES departments(departmentid);


--
-- Name: offers_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY offers
    ADD CONSTRAINT offers_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


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
-- Name: prerequisites_bulletingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prerequisites
    ADD CONSTRAINT prerequisites_bulletingid_fkey FOREIGN KEY (bulletingid) REFERENCES bulleting(bulletingid);


--
-- Name: prerequisites_courseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prerequisites
    ADD CONSTRAINT prerequisites_courseid_fkey FOREIGN KEY (courseid) REFERENCES courses(courseid);


--
-- Name: prerequisites_gradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prerequisites
    ADD CONSTRAINT prerequisites_gradeid_fkey FOREIGN KEY (gradeid) REFERENCES grades(gradeid);


--
-- Name: prerequisites_precourseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY prerequisites
    ADD CONSTRAINT prerequisites_precourseid_fkey FOREIGN KEY (precourseid) REFERENCES courses(courseid);


--
-- Name: qcalendar_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcalendar
    ADD CONSTRAINT qcalendar_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qcalendar_quarterid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcalendar
    ADD CONSTRAINT qcalendar_quarterid_fkey FOREIGN KEY (quarterid) REFERENCES quarters(quarterid);


--
-- Name: qcalendar_sublevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcalendar
    ADD CONSTRAINT qcalendar_sublevelid_fkey FOREIGN KEY (sublevelid) REFERENCES sublevels(sublevelid);


--
-- Name: qcourseitems_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourseitems
    ADD CONSTRAINT qcourseitems_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qcourseitems_qcourseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourseitems
    ADD CONSTRAINT qcourseitems_qcourseid_fkey FOREIGN KEY (qcourseid) REFERENCES qcourses(qcourseid);


--
-- Name: qcoursemarks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcoursemarks
    ADD CONSTRAINT qcoursemarks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qcoursemarks_qcourseitemid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcoursemarks
    ADD CONSTRAINT qcoursemarks_qcourseitemid_fkey FOREIGN KEY (qcourseitemid) REFERENCES qcourseitems(qcourseitemid);


--
-- Name: qcoursemarks_qgradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcoursemarks
    ADD CONSTRAINT qcoursemarks_qgradeid_fkey FOREIGN KEY (qgradeid) REFERENCES qgrades(qgradeid);


--
-- Name: qcourses_courseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_courseid_fkey FOREIGN KEY (courseid) REFERENCES courses(courseid);


--
-- Name: qcourses_instructorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_instructorid_fkey FOREIGN KEY (instructorid) REFERENCES instructors(instructorid);


--
-- Name: qcourses_levellocationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_levellocationid_fkey FOREIGN KEY (levellocationid) REFERENCES levellocations(levellocationid);


--
-- Name: qcourses_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qcourses_quarterid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qcourses
    ADD CONSTRAINT qcourses_quarterid_fkey FOREIGN KEY (quarterid) REFERENCES quarters(quarterid);


--
-- Name: qexamtimetable_assetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qexamtimetable
    ADD CONSTRAINT qexamtimetable_assetid_fkey FOREIGN KEY (assetid) REFERENCES assets(assetid);


--
-- Name: qexamtimetable_optiontimeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qexamtimetable
    ADD CONSTRAINT qexamtimetable_optiontimeid_fkey FOREIGN KEY (optiontimeid) REFERENCES optiontimes(optiontimeid);


--
-- Name: qexamtimetable_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qexamtimetable
    ADD CONSTRAINT qexamtimetable_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qexamtimetable_qcourseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qexamtimetable
    ADD CONSTRAINT qexamtimetable_qcourseid_fkey FOREIGN KEY (qcourseid) REFERENCES qcourses(qcourseid);


--
-- Name: qgrades_gradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_gradeid_fkey FOREIGN KEY (gradeid) REFERENCES grades(gradeid);


--
-- Name: qgrades_lecture_gradeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_lecture_gradeid_fkey FOREIGN KEY (lecture_gradeid) REFERENCES grades(gradeid);


--
-- Name: qgrades_optiontimeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_optiontimeid_fkey FOREIGN KEY (optiontimeid) REFERENCES optiontimes(optiontimeid);


--
-- Name: qgrades_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qgrades_qcourseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_qcourseid_fkey FOREIGN KEY (qcourseid) REFERENCES qcourses(qcourseid);


--
-- Name: qgrades_qstudentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_qstudentid_fkey FOREIGN KEY (qstudentid) REFERENCES qstudents(qstudentid);


--
-- Name: qgrades_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qgrades
    ADD CONSTRAINT qgrades_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: qposting_logs_qstudentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qposting_logs
    ADD CONSTRAINT qposting_logs_qstudentid_fkey FOREIGN KEY (qstudentid) REFERENCES qstudents(qstudentid);


--
-- Name: qposting_logs_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qposting_logs
    ADD CONSTRAINT qposting_logs_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: qresidences_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qresidences
    ADD CONSTRAINT qresidences_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qresidences_quarterid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qresidences
    ADD CONSTRAINT qresidences_quarterid_fkey FOREIGN KEY (quarterid) REFERENCES quarters(quarterid);


--
-- Name: qresidences_residenceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qresidences
    ADD CONSTRAINT qresidences_residenceid_fkey FOREIGN KEY (residenceid) REFERENCES residences(residenceid);


--
-- Name: qstudents_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_charge_id_fkey FOREIGN KEY (charge_id) REFERENCES charges(charge_id);


--
-- Name: qstudents_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qstudents_qresidenceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_qresidenceid_fkey FOREIGN KEY (qresidenceid) REFERENCES qresidences(qresidenceid);


--
-- Name: qstudents_quarterid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_quarterid_fkey FOREIGN KEY (quarterid) REFERENCES quarters(quarterid);


--
-- Name: qstudents_sabathclassid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_sabathclassid_fkey FOREIGN KEY (sabathclassid) REFERENCES sabathclasses(sabathclassid);


--
-- Name: qstudents_studentdegreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_studentdegreeid_fkey FOREIGN KEY (studentdegreeid) REFERENCES studentdegrees(studentdegreeid);


--
-- Name: qstudents_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qstudents
    ADD CONSTRAINT qstudents_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: qtimetable_assetid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qtimetable
    ADD CONSTRAINT qtimetable_assetid_fkey FOREIGN KEY (assetid) REFERENCES assets(assetid);


--
-- Name: qtimetable_optiontimeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qtimetable
    ADD CONSTRAINT qtimetable_optiontimeid_fkey FOREIGN KEY (optiontimeid) REFERENCES optiontimes(optiontimeid);


--
-- Name: qtimetable_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qtimetable
    ADD CONSTRAINT qtimetable_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: qtimetable_qcourseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY qtimetable
    ADD CONSTRAINT qtimetable_qcourseid_fkey FOREIGN KEY (qcourseid) REFERENCES qcourses(qcourseid);


--
-- Name: regcontacts_contacttypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regcontacts
    ADD CONSTRAINT regcontacts_contacttypeid_fkey FOREIGN KEY (contacttypeid) REFERENCES contacttypes(contacttypeid);


--
-- Name: regcontacts_countrycodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regcontacts
    ADD CONSTRAINT regcontacts_countrycodeid_fkey FOREIGN KEY (countrycodeid) REFERENCES countrys(countryid);


--
-- Name: regcontacts_registrationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY regcontacts
    ADD CONSTRAINT regcontacts_registrationid_fkey FOREIGN KEY (registrationid) REFERENCES registrations(registrationid);


--
-- Name: reghealth_healthitemid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reghealth
    ADD CONSTRAINT reghealth_healthitemid_fkey FOREIGN KEY (healthitemid) REFERENCES healthitems(healthitemid);


--
-- Name: reghealth_registrationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reghealth
    ADD CONSTRAINT reghealth_registrationid_fkey FOREIGN KEY (registrationid) REFERENCES registrations(registrationid);


--
-- Name: registrations_citizenshipid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_citizenshipid_fkey FOREIGN KEY (citizenshipid) REFERENCES countrys(countryid);


--
-- Name: registrations_county_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_county_id_fkey FOREIGN KEY (county_id) REFERENCES counties(county_id);


--
-- Name: registrations_degreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_degreeid_fkey FOREIGN KEY (degreeid) REFERENCES degrees(degreeid);


--
-- Name: registrations_denominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_denominationid_fkey FOREIGN KEY (denominationid) REFERENCES denominations(denominationid);


--
-- Name: registrations_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: registrations_entry_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_entry_form_id_fkey FOREIGN KEY (entry_form_id) REFERENCES entry_forms(entry_form_id);


--
-- Name: registrations_fdenominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_fdenominationid_fkey FOREIGN KEY (fdenominationid) REFERENCES denominations(denominationid);


--
-- Name: registrations_fnationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_fnationalityid_fkey FOREIGN KEY (fnationalityid) REFERENCES countrys(countryid);


--
-- Name: registrations_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: registrations_markid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_markid_fkey FOREIGN KEY (markid) REFERENCES marks(markid);


--
-- Name: registrations_mdenominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_mdenominationid_fkey FOREIGN KEY (mdenominationid) REFERENCES denominations(denominationid);


--
-- Name: registrations_mnationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_mnationalityid_fkey FOREIGN KEY (mnationalityid) REFERENCES countrys(countryid);


--
-- Name: registrations_nationalityid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_nationalityid_fkey FOREIGN KEY (nationalityid) REFERENCES countrys(countryid);


--
-- Name: registrations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: registrations_residenceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_residenceid_fkey FOREIGN KEY (residenceid) REFERENCES countrys(countryid);


--
-- Name: registrations_sublevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrations
    ADD CONSTRAINT registrations_sublevelid_fkey FOREIGN KEY (sublevelid) REFERENCES sublevels(sublevelid);


--
-- Name: registrymarks_markid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_markid_fkey FOREIGN KEY (markid) REFERENCES marks(markid);


--
-- Name: registrymarks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: registrymarks_registrationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_registrationid_fkey FOREIGN KEY (registrationid) REFERENCES registrations(registrationid);


--
-- Name: registrymarks_subjectid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registrymarks
    ADD CONSTRAINT registrymarks_subjectid_fkey FOREIGN KEY (subjectid) REFERENCES subjects(subjectid);


--
-- Name: registryschools_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registryschools
    ADD CONSTRAINT registryschools_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: registryschools_registrationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY registryschools
    ADD CONSTRAINT registryschools_registrationid_fkey FOREIGN KEY (registrationid) REFERENCES registrations(registrationid);


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
-- Name: requirements_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requirements
    ADD CONSTRAINT requirements_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: requirements_markid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requirements
    ADD CONSTRAINT requirements_markid_fkey FOREIGN KEY (markid) REFERENCES marks(markid);


--
-- Name: requirements_subjectid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY requirements
    ADD CONSTRAINT requirements_subjectid_fkey FOREIGN KEY (subjectid) REFERENCES subjects(subjectid);


--
-- Name: residences_levellocationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY residences
    ADD CONSTRAINT residences_levellocationid_fkey FOREIGN KEY (levellocationid) REFERENCES levellocations(levellocationid);


--
-- Name: residences_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY residences
    ADD CONSTRAINT residences_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sabathclasses_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sabathclasses
    ADD CONSTRAINT sabathclasses_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: skill_types_skill_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skill_types
    ADD CONSTRAINT skill_types_skill_category_id_fkey FOREIGN KEY (skill_category_id) REFERENCES skill_category(skill_category_id);


--
-- Name: skills_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skills
    ADD CONSTRAINT skills_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: skills_skill_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY skills
    ADD CONSTRAINT skills_skill_type_id_fkey FOREIGN KEY (skill_type_id) REFERENCES skill_types(skill_type_id);


--
-- Name: student_payments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY student_payments
    ADD CONSTRAINT student_payments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: student_payments_qstudentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY student_payments
    ADD CONSTRAINT student_payments_qstudentid_fkey FOREIGN KEY (qstudentid) REFERENCES qstudents(qstudentid);


--
-- Name: studentdegrees_bulletingid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_bulletingid_fkey FOREIGN KEY (bulletingid) REFERENCES bulleting(bulletingid);


--
-- Name: studentdegrees_degreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_degreeid_fkey FOREIGN KEY (degreeid) REFERENCES degrees(degreeid);


--
-- Name: studentdegrees_studentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_studentid_fkey FOREIGN KEY (studentid) REFERENCES students(studentid);


--
-- Name: studentdegrees_sublevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentdegrees
    ADD CONSTRAINT studentdegrees_sublevelid_fkey FOREIGN KEY (sublevelid) REFERENCES sublevels(sublevelid);


--
-- Name: studentmajors_majorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentmajors
    ADD CONSTRAINT studentmajors_majorid_fkey FOREIGN KEY (majorid) REFERENCES majors(majorid);


--
-- Name: studentmajors_majoroptionid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentmajors
    ADD CONSTRAINT studentmajors_majoroptionid_fkey FOREIGN KEY (majoroptionid) REFERENCES majoroptions(majoroptionid);


--
-- Name: studentmajors_studentdegreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentmajors
    ADD CONSTRAINT studentmajors_studentdegreeid_fkey FOREIGN KEY (studentdegreeid) REFERENCES studentdegrees(studentdegreeid);


--
-- Name: studentrequests_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentrequests
    ADD CONSTRAINT studentrequests_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: studentrequests_requesttypeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentrequests
    ADD CONSTRAINT studentrequests_requesttypeid_fkey FOREIGN KEY (requesttypeid) REFERENCES requesttypes(requesttypeid);


--
-- Name: studentrequests_studentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY studentrequests
    ADD CONSTRAINT studentrequests_studentid_fkey FOREIGN KEY (studentid) REFERENCES students(studentid);


--
-- Name: students_countrycodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_countrycodeid_fkey FOREIGN KEY (countrycodeid) REFERENCES countrys(countryid);


--
-- Name: students_denominationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_denominationid_fkey FOREIGN KEY (denominationid) REFERENCES denominations(denominationid);


--
-- Name: students_gcountrycodeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_gcountrycodeid_fkey FOREIGN KEY (gcountrycodeid) REFERENCES countrys(countryid);


--
-- Name: students_nationality_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_nationality_fkey FOREIGN KEY (nationality) REFERENCES countrys(countryid);


--
-- Name: students_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: students_residenceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_residenceid_fkey FOREIGN KEY (residenceid) REFERENCES residences(residenceid);


--
-- Name: students_schoolid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY students
    ADD CONSTRAINT students_schoolid_fkey FOREIGN KEY (schoolid) REFERENCES schools(schoolid);


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
-- Name: sublevels_degreelevelid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_degreelevelid_fkey FOREIGN KEY (degreelevelid) REFERENCES degreelevels(degreelevelid);


--
-- Name: sublevels_levellocationid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_levellocationid_fkey FOREIGN KEY (levellocationid) REFERENCES levellocations(levellocationid);


--
-- Name: sublevels_markid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_markid_fkey FOREIGN KEY (markid) REFERENCES marks(markid);


--
-- Name: sublevels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sublevels
    ADD CONSTRAINT sublevels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscription_levels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sun_audits_studentid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sun_audits
    ADD CONSTRAINT sun_audits_studentid_fkey FOREIGN KEY (studentid) REFERENCES students(studentid);


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
-- Name: transcriptprint_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transcriptprint
    ADD CONSTRAINT transcriptprint_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: transcriptprint_studentdegreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transcriptprint
    ADD CONSTRAINT transcriptprint_studentdegreeid_fkey FOREIGN KEY (studentdegreeid) REFERENCES studentdegrees(studentdegreeid);


--
-- Name: transferedcredits_courseid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transferedcredits
    ADD CONSTRAINT transferedcredits_courseid_fkey FOREIGN KEY (courseid) REFERENCES courses(courseid);


--
-- Name: transferedcredits_studentdegreeid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transferedcredits
    ADD CONSTRAINT transferedcredits_studentdegreeid_fkey FOREIGN KEY (studentdegreeid) REFERENCES studentdegrees(studentdegreeid);


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

