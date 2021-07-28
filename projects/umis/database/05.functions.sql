CREATE OR REPLACE FUNCTION sel_campus() RETURNS trigger AS $$
BEGIN

	SELECT org_id INTO NEW.org_id
	FROM levellocations
	WHERE (levellocationid = NEW.levellocationid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_sublevels BEFORE INSERT OR UPDATE ON sublevels
  FOR EACH ROW EXECUTE PROCEDURE sel_campus();

CREATE TRIGGER ins_residences BEFORE INSERT OR UPDATE ON residences
  FOR EACH ROW EXECUTE PROCEDURE sel_campus();

CREATE OR REPLACE FUNCTION ins_quarters() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_quarters AFTER INSERT ON quarters
  FOR EACH ROW EXECUTE PROCEDURE ins_quarters();

CREATE OR REPLACE FUNCTION ins_qresidences() RETURNS trigger AS $$
BEGIN

	SELECT org_id INTO NEW.org_id
	FROM residences
	WHERE (residenceid = NEW.residenceid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_qresidences BEFORE INSERT OR UPDATE ON qresidences
  FOR EACH ROW EXECUTE PROCEDURE ins_qresidences();

CREATE OR REPLACE FUNCTION ins_studentdegrees() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_studentdegrees AFTER INSERT OR UPDATE ON studentdegrees
  FOR EACH ROW EXECUTE PROCEDURE ins_studentdegrees();

CREATE OR REPLACE FUNCTION ins_charges() RETURNS trigger AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM sublevels
	WHERE (sublevelid = NEW.sublevelid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_charges BEFORE INSERT OR UPDATE ON charges
  FOR EACH ROW EXECUTE PROCEDURE ins_charges();

CREATE OR REPLACE FUNCTION ins_qcourses() RETURNS trigger AS $$
BEGIN
	
	SELECT labcourse, examinable, clinical_fee, extracharge, coursetitle
		INTO NEW.labcourse, NEW.examinable, NEW.clinical_fee, NEW.extracharge, NEW.session_title
	FROM courses
	WHERE (courseid = NEW.courseid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_qcourses BEFORE INSERT ON qcourses
  FOR EACH ROW EXECUTE PROCEDURE ins_qcourses();

CREATE OR REPLACE FUNCTION upd_qcourses() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_qcourses BEFORE INSERT OR UPDATE ON qcourses
  FOR EACH ROW EXECUTE PROCEDURE upd_qcourses();

CREATE OR REPLACE FUNCTION ins_qgrades() RETURNS trigger AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM qstudents
	WHERE (qstudentid = NEW.qstudentid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_qgrades BEFORE INSERT OR UPDATE ON qgrades
  FOR EACH ROW EXECUTE PROCEDURE ins_qgrades();

CREATE OR REPLACE FUNCTION ins_qtimetable() RETURNS trigger AS $$
BEGIN
	
	SELECT org_id INTO NEW.org_id
	FROM qcourses
	WHERE (qcourseid = NEW.qcourseid);

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_qtimetable BEFORE INSERT OR UPDATE ON qtimetable
  FOR EACH ROW EXECUTE PROCEDURE ins_qtimetable();

CREATE TRIGGER ins_qtimetable BEFORE INSERT OR UPDATE ON qexamtimetable
  FOR EACH ROW EXECUTE PROCEDURE ins_qtimetable();

CREATE OR REPLACE FUNCTION getstudentdegreeid(varchar(12)) RETURNS integer AS $$
    SELECT max(studentdegreeid) FROM studentdegrees WHERE (studentid=$1) AND (completed=false);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getstudentdegreeid(varchar(12), varchar(12)) RETURNS integer AS $$
	SELECT max(qstudents.studentdegreeid)
	FROM studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid
	WHERE (studentdegrees.studentid = $1) AND (qstudents.quarterid = $2);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcoremajor(integer) RETURNS character varying AS $$
    SELECT max(majors.majorname)
    FROM studentmajors INNER JOIN majors ON studentmajors.majorid = majors.majorid
    WHERE (studentmajors.studentdegreeid = $1) AND (studentmajors.primarymajor = true);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION getqstudentid(varchar(12)) RETURNS int AS $$
	SELECT max(qstudents.qstudentid) 
	FROM (studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid
	WHERE (studentdegrees.studentid = $1) AND (quarters.active = true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcurrqstudentid(varchar(12)) RETURNS int AS $$
	SELECT max(qstudentid) 
	FROM qstudentlist INNER JOIN quarters ON qstudentlist.quarterid = quarters.quarterid 
	WHERE (studentid = $1) AND (quarters.active = true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getstudentid(varchar(12)) RETURNS varchar(12) AS $$
    SELECT max(studentid) FROM students WHERE (studentid = $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getstudentquarter(varchar(12)) RETURNS varchar(12) AS $$
    SELECT quarterid FROM qstudents WHERE (qstudentid = CAST($1 as INT));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcoursequarter(varchar(12)) RETURNS varchar(12) AS $$
    SELECT quarterid FROM qcourses WHERE (qcourseid = CAST($1 as INT));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_qstudent_location_id(varchar(12)) RETURNS int AS $$
	SELECT max(sublevels.levellocationid)
	FROM (studentdegrees INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid
		INNER JOIN charges ON qstudents.charge_id = charges.charge_id
		INNER JOIN sublevels ON sublevels.sublevelid = charges.sublevelid
	WHERE (studentdegrees.studentid = $1) AND (quarters.active = true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getexamtimecount(integer, date, time, time) RETURNS bigint AS $$
	SELECT count(qgradeid) FROM qexamtimetableview
	WHERE (qstudentid = $1) AND (examdate = $2) AND (((starttime, endtime) OVERLAPS ($3, $4))=true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcoursehours(int) RETURNS float AS $$
	SELECT courses.credithours
	FROM courses INNER JOIN qcourses ON courses.courseid = qcourses.courseid
	WHERE (qcourseid=$1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcoursecredits(int) RETURNS float AS $$
	SELECT (CASE courses.nogpa WHEN true THEN 0 ELSE courses.credithours END)
	FROM courses INNER JOIN qcourses ON courses.courseid = qcourses.courseid
	WHERE (qcourseid=$1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION gettimecount(integer, time, time, boolean, boolean, boolean, boolean, boolean, boolean, boolean) RETURNS bigint AS $$
	SELECT count(qtimetableid) FROM studenttimetableview
	WHERE (qstudentid=$1) AND (((starttime, endtime) OVERLAPS ($2, $3))=true) 
	AND ((cmonday and $4) OR (ctuesday and $5) OR (cwednesday and $6) OR (cthursday and $7) OR (cfriday and $8) OR (csaturday and $9) OR (csunday and $10));
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION addacademicyear(varchar(12), int) RETURNS varchar(12) AS $$
	SELECT cast(substring($1 from 1 for 4) as int) + $2 || '/' || cast(substring($1 from 1 for 4) as int) + $2 + 1 || '.3';
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION upd_sun_balance(varchar(12), varchar(64), Float) RETURNS VARCHAR(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insQStudent(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION selQsabathclass(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(50) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insQCourse(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insQSpecialCourse(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dropQCourse(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(50) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calcWithdrawRate() RETURNS real AS $$
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
$$ LANGUAGE plpgsql;

-- update the date a course was withdrawn
CREATE OR REPLACE FUNCTION updqgrades() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER updqgrades BEFORE UPDATE ON qgrades
    FOR EACH ROW EXECUTE PROCEDURE updqgrades();

CREATE OR REPLACE FUNCTION del_qgrades() RETURNS trigger AS $$
BEGIN
	RAISE EXCEPTION 'Cannot delete a grade.';
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER del_qgrades BEFORE DELETE ON qgrades
    FOR EACH ROW EXECUTE PROCEDURE del_qgrades();

CREATE OR REPLACE FUNCTION getoverload(varchar(2), float, float, float, boolean, float) RETURNS boolean AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getprobation(varchar(2), float, float) RETURNS boolean AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getcourserepeat(int, varchar(12)) RETURNS bigint AS $$
	SELECT count(qcourses.qcourseid)
	FROM (qgrades INNER JOIN (qcourses INNER JOIN courses ON qcourses.courseid = courses.courseid) ON qgrades.qcourseid = qcourses.qcourseid)
		INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid
	WHERE (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW') AND (qgrades.gradeid <> 'NG')
		AND (qgrades.dropped = false) AND (qstudents.approved = true) AND (courses.norepeats = false)
		AND (qstudents.studentdegreeid = $1) AND (qcourses.courseid = $2);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getrepeatapprove(int) RETURNS VARCHAR(12) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION insQClose(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(250) AS $$
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
$$ LANGUAGE plpgsql;

-- update the person who finacially approved a student
CREATE OR REPLACE FUNCTION updqstudents() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER updqstudents AFTER UPDATE ON qstudents
    FOR EACH ROW EXECUTE PROCEDURE updqstudents();

CREATE OR REPLACE FUNCTION ins_qstudents() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_qstudents BEFORE INSERT OR UPDATE ON qstudents
    FOR EACH ROW EXECUTE PROCEDURE ins_qstudents();

CREATE OR REPLACE FUNCTION updstudents() RETURNS trigger AS $$
BEGIN
	IF (OLD.fullbursary = false) and (NEW.fullbursary = true) THEN
		INSERT INTO sys_audit_trail (user_id, table_name, record_id, change_type, narrative)
		VALUES (current_user, 'students', NEW.studentid, 'approve', 'Approve full Bursary');
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER updstudents AFTER UPDATE ON students
  FOR EACH ROW EXECUTE PROCEDURE updstudents();

CREATE OR REPLACE FUNCTION updatemajorapproval(varchar(12), varchar(12), varchar(12)) RETURNS varchar AS $$
	UPDATE qstudents SET majorapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate) 
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Major Approval Done' as reply;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION updOverLoadApproval(varchar(12), varchar(12), varchar(12)) RETURNS varchar AS $$
	UPDATE qstudents SET overloadhours = 24, overloadapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate)
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Overload Approval Done' as reply;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION UpdApproveFinance(varchar(12), varchar(12), varchar(12)) RETURNS varchar AS $$
	UPDATE qstudents SET finaceapproval = true WHERE qstudentid = CAST($1 as int);
	INSERT INTO approvallist(qstudentid, approvedby, approvaltype, approvedate)
	VALUES (CAST($1 as int), $2, 'Major', now());
	SELECT varchar 'Finance Approval Done' as reply;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION setConfirmation(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION aft_instructors() RETURNS trigger AS $$
DECLARE
	v_entity_type_id		integer;
	v_role					varchar(240);
	v_no_org				boolean;
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
		SELECT entity_type_id INTO v_entity_type_id FROM entity_types WHERE org_id = NEW.org_id;
		
		INSERT INTO entitys (org_id, entity_type_id, user_name, entity_name, Entity_Leader, Super_User, no_org, primary_email, function_role, use_key_id)
		VALUES (NEW.org_id, v_entity_type_id, NEW.instructorid, NEW.instructorname, false, false, false, NEW.email, v_role, 9);
	ELSE
		UPDATE entitys SET function_role = v_role, no_org = v_no_org WHERE user_name = NEW.instructorid;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_instructors AFTER INSERT OR UPDATE ON instructors
  FOR EACH ROW EXECUTE PROCEDURE aft_instructors();

CREATE OR REPLACE FUNCTION selQResidence(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION selQRoom(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(50) AS $$
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
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION updStudentAdd(varchar(12), varchar(12), varchar(12)) RETURNS VARCHAR(50) AS $$
DECLARE
	mystr VARCHAR(50);
BEGIN

	mystr := updStudentAdd();

	UPDATE students SET countrycodeid = 'KE' WHERE countrycodeid is null;
	UPDATE students SET gcountrycodeid = 'KE' WHERE gcountrycodeid is null;
	
	RETURN mystr;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION updStudentAdd() RETURNS VARCHAR(50) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_students() RETURNS trigger AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (user_name = NEW.studentid);

	IF(v_entity_id is null)THEN
		INSERT INTO entitys (org_id, use_key_id, entity_type_id, entity_name, user_name, primary_email, first_password, entity_password)
		VALUES(0, 8, 8, NEW.studentname, NEW.studentid, NEW.email, NEW.firstpass, NEW.studentpass);

		INSERT INTO entitys (org_id, use_key_id, entity_type_id, entity_name, user_name, primary_email, first_password, entity_password)
		VALUES(0, 10, 10, COALESCE(NEW.guardianname, NEW.studentname), 'G' || NEW.studentid, NEW.gemail, NEW.gfirstpass, NEW.gstudentpass);
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_students AFTER INSERT ON students
  FOR EACH ROW EXECUTE PROCEDURE ins_students();

CREATE OR REPLACE FUNCTION OpenQuarter(varchar(12), varchar(12), varchar(12)) RETURNS varchar(50) AS $$
	UPDATE charges SET session_active = true, session_closed = false 
	WHERE (charges.quarterid = $1);

	UPDATE qcourses SET approved = false WHERE (quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION CloseQuarter(varchar(12), varchar(12), varchar(12)) RETURNS varchar(50) AS $$
	UPDATE charges SET session_active = false, session_closed = true
	WHERE (charges.quarterid = $1);

	UPDATE qcourses SET approved = true WHERE (quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION ExamBalances(varchar(12), varchar(12), varchar(12)) RETURNS varchar(50) AS $$
	UPDATE charges SET exam_balances = true, session_active = true, session_closed = false
	WHERE (charges.quarterid = $1);
	
	SELECT text 'Done' AS mylabel;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION SunPosted(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(50) AS $$
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
$$ LANGUAGE SQL;

-- insert qcoursemarks after adding qcourseitems
CREATE OR REPLACE FUNCTION updqcourseitems() RETURNS trigger AS $$
DECLARE
	myrec RECORD;
BEGIN
	FOR myrec IN SELECT * FROM qgrades WHERE qcourseid = NEW.qcourseid LOOP
		INSERT INTO qcoursemarks (qgradeid, qcourseitemid) VALUES (myrec.qgradeid, NEW.qcourseitemid);
	END LOOP;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER updqcourseitems AFTER INSERT ON qcourseitems
    FOR EACH ROW EXECUTE PROCEDURE updqcourseitems();

CREATE OR REPLACE FUNCTION reset_password(varchar(12), varchar(32), varchar(32)) RETURNS varchar(120) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_instructor_school(varchar(16)) RETURNS varchar(16) AS $$
	SELECT departments.schoolid
	FROM instructors INNER JOIN departments ON instructors.departmentid = departments.departmentid
	WHERE (instructorid = $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_instructor_department(varchar(16)) RETURNS varchar(16) AS $$
	SELECT departmentid
	FROM instructors
	WHERE (instructorid = $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getdbgradeid(integer) RETURNS varchar(2) AS $$
	SELECT CASE WHEN max(gradeid) is null THEN 'NG' ELSE max(gradeid) END
	FROM grades 
	WHERE (minrange <= $1) AND (maxrange > $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION approve_finance(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updComputeGrade(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updqcoursegrade(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updApproveGrade(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION openqcoursedepartment(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
BEGIN
	UPDATE qcourses SET submit_grades = false
	WHERE (qcourseid = CAST($1 as int));
	
	RETURN 'Course opened for lecturer to correct';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grade_updates(varchar(12), varchar(12), varchar(12)) RETURNS varchar(240) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getSchoolID(varchar(12)) RETURNS varchar(12) AS $$
	SELECT schoolid FROM departments WHERE (departmentid = $1);
$$ LANGUAGE SQL;

-- insert qcoursemarks after adding qcourseitems
CREATE OR REPLACE FUNCTION aft_student_payments() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_student_payments AFTER INSERT OR UPDATE ON student_payments
    FOR EACH ROW EXECUTE PROCEDURE aft_student_payments();

    
    
