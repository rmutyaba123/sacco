CREATE OR REPLACE FUNCTION getprevquarter(int, varchar(12)) RETURNS varchar(12) AS $$
	SELECT max(qstudents.quarterid)
	FROM qstudents
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid < $2);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getprevcredit(int, varchar(12)) RETURNS float AS $$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getprevgpa(int, varchar(12)) RETURNS float AS $$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) AND (qgrades.repeated = false) 
		AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcurrhours(int) RETURNS float AS $$
	SELECT sum(qgrades.hours)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcurrcredit(int) RETURNS float AS $$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (grades.gpacount = true) AND (qgrades.dropped = false) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcurrgpa(int) RETURNS float AS $$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (grades.gpacount = true) AND (qgrades.dropped = false) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcummcredit(int, varchar(12)) RETURNS float AS $$
	SELECT sum(qgrades.credit)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.approved = true)
		AND (qstudents.quarterid <= $2) AND (qgrades.dropped = false)
		AND (grades.gpacount = true) AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcummgpa(int, varchar(12)) RETURNS float AS $$
	SELECT (CASE sum(qgrades.credit) WHEN 0 THEN 0 ELSE (sum(grades.gradeweight * qgrades.credit)/sum(qgrades.credit)) END)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (qstudents.quarterid <= $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gpacount = true) 
		AND (qgrades.repeated = false) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW');
$$ LANGUAGE SQL;

CREATE VIEW qstudentsummary AS
	SELECT org_id, studentid, studentname, quarterid, approved, studentdegreeid, qstudentid,
		sex, Nationality, MaritalStatus,
		getcurrcredit(qstudentid) as credit, getcurrgpa(qstudentid) as gpa,
		getcummcredit(studentdegreeid, quarterid) as cummcredit,
		getcummgpa(studentdegreeid, quarterid) as cummgpa 
	FROM qstudentdegreeview;

CREATE VIEW studentquarterlist AS
	SELECT religionid, religionname, denominationid, denominationname, schoolid, schoolname, studentid, studentname, address, zipcode,
		town, addresscountry, telno, email,  guardianname, gaddress, gzipcode, gtown, gaddresscountry, gtelno, gemail,
		accountnumber, Nationality, Nationalitycountry, Sex, MaritalStatus, birthdate, firstpass, alumnae, postcontacts,
		onprobation, offcampus, currentcontact, currentemail, currenttel, degreelevelid, degreelevelname,
		freshman, sophomore, junior, senior, levellocationid, levellocationname, sublevelid, sublevelname, specialcharges,
		degreeid, degreename, studentdegreeid, completed, started, cleared, clearedate,
		graduated, graduatedate, dropout, transferin, transferout, mathplacement, englishplacement,
		quarterid, quarteryear, quarter, qstart, qlatereg, qlatechange, qlastdrop,
		qend, active, feesline, resline, 
		residenceid, residencename, capacity, defaultrate, residenceoffcampus, residencesex, residencedean,
		qresidenceid, residenceoption, qstudentid, approved, probation,
		roomnumber, finaceapproval, majorapproval, departapproval, overloadapproval, finalised, printed,
		getcurrhours(qstudentid) as hours,		
		getcurrcredit(qstudentid) as credit, 
		getcurrgpa(qstudentid) as gpa,
		getcummcredit(studentdegreeid, quarterid) as cummcredit,
		getcummgpa(studentdegreeid, quarterid) as cummgpa,
		getprevquarter(studentdegreeid, quarterid) as prevquarter,
		(CASE WHEN (getprevquarter(studentdegreeid, quarterid) is null) THEN true ELSE false END) as newstudent
	FROM qstudentview;

CREATE VIEW studentquartersummary AS
	SELECT religionid, religionname, denominationid, denominationname, schoolid, schoolname, studentid, studentname, address, zipcode,
		town, addresscountry, telno, email,  guardianname, gaddress, gzipcode, gtown, gaddresscountry, gtelno, gemail,
		accountnumber, Nationality, Nationalitycountry, Sex, MaritalStatus, birthdate, firstpass, alumnae, postcontacts,
		onprobation, offcampus, currentcontact, currentemail, currenttel, degreelevelid, degreelevelname,
		freshman, sophomore, junior, senior, levellocationid, levellocationname, sublevelid, sublevelname, specialcharges,
		degreeid, degreename, studentdegreeid, completed, started, cleared, clearedate,
		graduated, graduatedate, dropout, transferin, transferout, mathplacement, englishplacement,
		quarterid, quarteryear, quarter, qstart, qlatereg, qlatechange, qlastdrop,
		qend, active, feesline, resline, 
		residenceid, residencename, capacity, defaultrate, residenceoffcampus, residencesex, residencedean,
		qresidenceid, residenceoption, qstudentid, approved, probation,
		roomnumber, finaceapproval, majorapproval, departapproval, overloadapproval, finalised, printed,		
		hours, gpa, credit, cummcredit, cummgpa, prevquarter, newstudent, 
		getprevcredit(studentdegreeid, prevquarter) as prevcredit, 
		getprevgpa(studentdegreeid, prevquarter) as prevgpa
	FROM studentquarterlist;

CREATE VIEW qcoursesummarya AS
	SELECT degreelevelid, degreelevelname, levellocationid, levellocationname, sublevelid, sublevelname,
		crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession,
		count(qgradeid) as enrolment, sum(chargehours) as sumchargehours, sum(unitfees) as sumunitfees, sum(labfees) as sumlabfees,
		sum(extracharge) as sumextracharge
	FROM studentgradeview
	WHERE (finaceapproval = true) AND (dropped = false) AND (gradeid <> 'W') AND (gradeid <> 'AW')
		AND (withdraw = false) AND (ac_withdraw = false)
	GROUP BY degreelevelid, degreelevelname, levellocationid, levellocationname, sublevelid, sublevelname,
		crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession;

CREATE VIEW qcoursesummaryb AS
	SELECT degreelevelid, degreelevelname, crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession,
		count(qgradeid) as enrolment, sum(chargehours) as sumchargehours, sum(unitfees) as sumunitfees, sum(labfees) as sumlabfees,
		sum(extracharge) as sumextracharge
	FROM studentgradeview
	WHERE (finaceapproval = true) AND (dropped = false) AND (gradeid <> 'W') AND (gradeid <> 'AW')
		AND (withdraw = false) AND (ac_withdraw = false)
	GROUP BY degreelevelid, degreelevelname, crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession;
		
CREATE VIEW qcoursesummaryc AS
	SELECT crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname, crs_degreelevelid, crs_degreelevelname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession,
		count(qgradeid) as enrolment, sum(chargehours) as sumchargehours, sum(unitfees) as sumunitfees, sum(labfees) as sumlabfees,
		sum(extracharge) as sumextracharge
	FROM studentgradeview
	WHERE (finaceapproval = true) AND (dropped = false) AND (gradeid <> 'W') AND (gradeid <> 'AW')
		AND (withdraw = false) AND (ac_withdraw = false)
	GROUP BY crs_schoolid, crs_schoolname, crs_departmentid, crs_departmentname, crs_degreelevelid, crs_degreelevelname,
		quarterid, qcourseid, coursetypeid, coursetypename, courseid, credithours, iscurrent, instructorname, coursetitle, classoption,
		intersession;

CREATE VIEW qstudentmajorsummary AS
	SELECT qstudentmajorview.schoolid, qstudentmajorview.schoolname, qstudentmajorview.departmentid, qstudentmajorview.departmentname,
		qstudentmajorview.degreelevelid, qstudentmajorview.degreelevelname, qstudentmajorview.sublevelid, qstudentmajorview.sublevelname,
		qstudentmajorview.majorid, qstudentmajorview.majorname, qstudentmajorview.premajor, qstudentmajorview.major,qstudentmajorview.probation,
		qstudentmajorview.studentdegreeid, qstudentmajorview.primarymajor,
		qstudentmajorview.sex, qstudentmajorview.quarterid, count(qstudentmajorview.studentdegreeid) as studentcount
	FROM qstudentmajorview
	GROUP BY qstudentmajorview.schoolid, qstudentmajorview.schoolname, qstudentmajorview.departmentid, qstudentmajorview.departmentname,
		qstudentmajorview.degreelevelid, qstudentmajorview.degreelevelname, qstudentmajorview.sublevelid, qstudentmajorview.sublevelname,
		qstudentmajorview.majorid, qstudentmajorview.majorname, qstudentmajorview.premajor, qstudentmajorview.major,
		qstudentmajorview.studentdegreeid, qstudentmajorview.primarymajor,qstudentmajorview.probation,
		qstudentmajorview.sex, qstudentmajorview.quarterid;

CREATE VIEW nationalityview AS
	SELECT nationality, nationalitycountry
	FROM studentview
	GROUP BY nationality, nationalitycountry
	ORDER BY nationalitycountry;

CREATE VIEW vwnationality AS
	SELECT nationality, countryname
	FROM students INNER JOIN countrys ON students.Nationality = countrys.countryid
	GROUP BY nationality, countryname
	ORDER BY countryname;

CREATE VIEW vwgradyear AS
	SELECT EXTRACT(YEAR FROM studentdegreeview.graduatedate) as gradyear
	FROM studentdegreeview
	WHERE (studentdegreeview.graduated = true)
	GROUP BY EXTRACT(YEAR FROM studentdegreeview.graduatedate)
	ORDER BY EXTRACT(YEAR FROM studentdegreeview.graduatedate);

CREATE VIEW sexview AS
	(SELECT 'M' as sex) UNION (SELECT 'F' as sex);

CREATE VIEW qsummaryaview AS
	SELECT quarterid, quarteryear, quarter, Sex, count(studentid) as studentcount
	FROM qstudentview
	WHERE (approved = true)
	GROUP BY quarterid, quarteryear, quarter, Sex;
	
CREATE VIEW qsummarybview AS
	SELECT quarterid, quarteryear, quarter, degreelevelname, Sex, count(studentid) as studentcount
	FROM qstudentview
	WHERE (approved = true)
	GROUP BY quarterid, quarteryear, quarter, degreelevelname, Sex;
	
CREATE VIEW qsummarycview AS
	SELECT quarterid, quarteryear, quarter, sublevelname, Sex, count(studentid) as studentcount
	FROM qstudentview
	WHERE (approved = true)
	GROUP BY quarterid, quarteryear, quarter, sublevelname, Sex;

CREATE VIEW qsummarydview AS
	SELECT quarteryear, Sex, count(studentid) as studentcount
	FROM qstudentview
	WHERE (approved = true)
	GROUP BY quarteryear, Sex;

CREATE VIEW schoolsummary AS
	SELECT quarterid, quarteryear, quarter, schoolname, sex, varchar 'School' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, schoolname, sex
	ORDER BY quarterid, quarteryear, quarter, schoolname, sex;

CREATE VIEW levelsummary AS
	SELECT quarterid, quarteryear, quarter, degreelevelname, sex, varchar 'Degree Level' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, degreelevelname, sex
	ORDER BY quarterid, quarteryear, quarter, degreelevelname, sex;

CREATE VIEW sublevelsummary AS
	SELECT quarterid, quarteryear, quarter, sublevelname, sex, varchar 'Sub Level' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, sublevelname, sex
	ORDER BY quarterid, quarteryear, quarter, sublevelname, sex;

CREATE VIEW newstudentssummary AS
	SELECT quarterid, quarteryear, quarter, (CASE WHEN newstudent=true THEN 'New' ELSE 'Continuing' END) as status, sex, varchar 'Student Status' as "defination", count(qstudentid) as studentcount
	FROM studentquartersummary
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, newstudent, sex
	ORDER BY quarterid, quarteryear, quarter, newstudent, sex;

CREATE VIEW religionsummary AS
	SELECT quarterid, quarteryear, quarter, religionname, sex, varchar 'Religion' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, religionname, sex
	ORDER BY quarterid, quarteryear, quarter, religionname, sex;

CREATE VIEW denominationsummary AS
	SELECT quarterid, quarteryear, quarter, denominationname, sex, varchar 'Denomination' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, denominationname, sex
	ORDER BY quarterid, quarteryear, quarter, denominationname, sex;

CREATE VIEW nationalitysummary AS
	SELECT quarterid, quarteryear, quarter, nationalitycountry, sex, varchar 'Nationality' as "defination", count(qstudentid) as studentcount
	FROM qstudentview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, nationalitycountry, sex
	ORDER BY quarterid, quarteryear, quarter, nationalitycountry, sex;

CREATE VIEW residencesummary AS
	SELECT quarterid, quarteryear, quarter, residencename, sex, varchar 'Residence' as "defination", count(qstudentid) as studentcount
	FROM studentquarterview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, residencename, sex
	ORDER BY quarterid, quarteryear, quarter, residencename, sex;

CREATE VIEW schoolmajorsummary AS
	SELECT qstudentmajorview.quarterid, substring(quarterid from 1 for 9) as quarteryear, 
		substring(quarterid from 11 for 2) as quarter, majorview.schoolname, qstudentmajorview.sex, 
		varchar 'School' as "defination", count(qstudentid) as studentcount
	FROM qstudentmajorview
	INNER JOIN majorview ON majorview.majorid = qstudentmajorview.majorid
	GROUP BY qstudentmajorview.quarterid, substring(quarterid from 1 for 9), substring(quarterid from 11 for 2),majorview.schoolname,qstudentmajorview.sex
	ORDER BY qstudentmajorview.quarterid, substring(quarterid from 1 for 9), substring(quarterid from 11 for 2),majorview.schoolname,qstudentmajorview.sex;

CREATE VIEW locationsummary AS
	SELECT quarterid, quarteryear, quarter, levellocationname, sex, 'Location'::varchar as "defination", count(qstudentid) as studentcount
	FROM studentquarterview
	WHERE approved=true
	GROUP BY quarterid, quarteryear, quarter, levellocationname, sex
	ORDER BY quarterid, quarteryear, quarter, levellocationname, sex;

CREATE VIEW fullsummary AS
	(SELECT * FROM schoolmajorsummary) UNION
	(SELECT * FROM levelsummary) UNION
	(SELECT * FROM sublevelsummary) UNION
	(SELECT * FROM newstudentssummary) UNION
	(SELECT * FROM religionsummary) UNION
	(SELECT * FROM denominationsummary) UNION
	(SELECT * FROM nationalitysummary) UNION
	(SELECT * FROM residencesummary) UNION
	(SELECT * FROM locationsummary);

CREATE VIEW quarterstats AS
	(SELECT 1 as statid, text 'Opened Applications' AS "narrative", count(qstudentid) AS studentcount, quarterid
	FROM qstudents GROUP BY quarterid)
	UNION
	(SELECT 2, text 'Paid Full Fees' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance >= (-2000)) AND (finaceapproval = true) 
		GROUP BY quarterid)
	UNION
	(SELECT 3, text 'Within Allowed Balance' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance < (-2000)) AND (finalbalance >= ((-1) * feesline)) AND (finaceapproval = true)
		GROUP BY quarterid)
	UNION
	(SELECT 4, text 'Above Allowed Balance' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance >= ((-1) * feesline)) AND (finaceapproval = true)
		GROUP BY quarterid)
	UNION
	(SELECT 5, text 'Below Allowed Balance' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance < ((-1) * feesline))
		GROUP BY quarterid)
	UNION
	(SELECT 6, text 'Financially Approved' AS "narrative", count(qstudentid), quarterid 
		FROM qstudents WHERE (finaceapproval = true)
		GROUP BY quarterid)
	UNION
	(SELECT 7, text 'Approved and Below Allowed Balance' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance < ((-1) * feesline) AND (finaceapproval = true)) 
		GROUP BY quarterid)
	UNION
	(SELECT 8, text 'Not Approved and Above Allowed Balance' AS "narrative", count(qstudentid), quarterid
		FROM studentquarterview WHERE (finalbalance >= ((-1) * feesline) AND (finaceapproval = false)) 
		GROUP BY quarterid)
	UNION
	(SELECT 9, text 'Closed Applications' AS "narrative", count(qstudentid), quarterid 
		FROM qstudents
		WHERE (finalised = true) GROUP BY quarterid)
	UNION
	(SELECT 10, text 'Closed and not Finacially approved' AS "narrative", count(qstudentid), quarterid 
		FROM qstudents WHERE (finalised = true) AND (finaceapproval = false) GROUP BY quarterid)
	UNION
	(SELECT 11, text 'Printed Applications' AS "narrative", count(qstudentid), quarterid 
		FROM qstudents WHERE (printed = true) GROUP BY quarterid)
	UNION
	(SELECT 12, text 'Fully Registered' AS "narrative", count(qstudentid), quarterid
		FROM qstudents WHERE (approved = true) GROUP BY quarterid);

CREATE OR REPLACE FUNCTION getqstudentid(int, varchar(12)) RETURNS int AS $$
	SELECT max(qstudents.qstudentid)
	FROM qstudents
	WHERE (studentdegreeid = $1) AND (quarterid = $2);
$$ LANGUAGE SQL;

CREATE VIEW studentsyearlist AS
	SELECT qstudentlist.studentid, qstudentlist.studentname, qstudentlist.Sex, qstudentlist.Nationality, qstudentlist.MaritalStatus,
		qstudentlist.birthdate, qstudentlist.studentdegreeid, qstudentlist.degreeid, qstudentlist.sublevelid,
		academicyear, count(qstudentlist.qstudentid) as quartersdone,
		getqstudentid(qstudentlist.studentdegreeid, academicyear || '.1') as qstudent1, 
		getqstudentid(qstudentlist.studentdegreeid, academicyear || '.2') as qstudent2,
		getqstudentid(qstudentlist.studentdegreeid, academicyear || '.3') as qstudent3,
		getqstudentid(qstudentlist.studentdegreeid, academicyear || '.4') as qstudent4
	FROM qstudentlist 
	WHERE (qstudentlist.approved = true) AND (getcurrcredit(qstudentlist.qstudentid) >= 12)
	GROUP BY qstudentlist.studentid, qstudentlist.studentname, qstudentlist.Sex, qstudentlist.Nationality, qstudentlist.MaritalStatus,
		qstudentlist.birthdate, qstudentlist.studentdegreeid, qstudentlist.degreeid, qstudentlist.sublevelid, academicyear;

CREATE OR REPLACE FUNCTION checkincomplete(int) RETURNS bigint AS $$
	SELECT count(qgrades.qgradeid)
	FROM qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true)
		AND (qgrades.gradeid = 'IW') AND (qgrades.dropped = false);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION checkgrade(int, float) RETURNS bigint AS $$
	SELECT count(qgrades.qgradeid)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.qstudentid = $1) AND (qstudents.approved = true) AND (qgrades.dropped = false)
		AND (grades.gradeweight < $2) AND (grades.gpacount = true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION checkgrade(int, varchar(10), float) RETURNS bigint AS $$
	SELECT count(qgrades.qgradeid)
	FROM (qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
	INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qstudents.studentdegreeid = $1) AND (substring(qstudents.quarterid from 1 for 9) = $2) AND (qstudents.approved = true)
		AND (qgrades.dropped = false) AND (grades.gradeweight < $3) AND (grades.gpacount = true);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION checkhonors(float, float, float, float) RETURNS int AS $$
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
$$ LANGUAGE plpgsql;

CREATE VIEW honorslist AS
	SELECT studentid, studentname, Sex, Nationality, MaritalStatus, birthdate, studentdegreeid, degreeid, sublevelid,
		academicyear, quartersdone, qstudent1, qstudent2, qstudent3, qstudent4,
		getcurrgpa(qstudent1) as gpa1, getcurrgpa(qstudent2) as gpa2, getcurrgpa(qstudent3) as gpa3, getcurrgpa(qstudent4) as gpa4,
		getcummgpa(studentdegreeid, academicyear || '.1') as cummgpa1, getcummgpa(studentdegreeid, academicyear || '.2') as cummgpa2,
		getcummgpa(studentdegreeid, academicyear || '.3') as cummgpa3, getcummgpa(studentdegreeid, academicyear || '.4') as cummgpa4
	FROM studentsyearlist 
	WHERE (quartersdone >  1) AND (checkgrade(studentdegreeid, academicyear, 2.67) = 0);

CREATE VIEW honorsview AS
	SELECT studentid, studentname, Sex, Nationality, MaritalStatus, birthdate, studentdegreeid, degreeid, sublevelid,
		academicyear, quartersdone, qstudent1, qstudent2, qstudent3, qstudent4,
		gpa1, gpa2, gpa3, gpa4, cummgpa1, cummgpa2, cummgpa3, cummgpa4,
		checkhonors(gpa1, gpa2, gpa3, gpa4) as gpahonors,
		checkhonors(cummgpa1, cummgpa2, cummgpa3, cummgpa4) as cummgpahonours
	FROM honorslist;


