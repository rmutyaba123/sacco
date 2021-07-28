
CREATE VIEW vw_levellocations AS
	SELECT orgs.org_id, orgs.org_name,
		levellocations.levellocationid, levellocations.levellocationname, levellocations.details
	FROM orgs INNER JOIN levellocations ON orgs.org_id = levellocations.org_id;

CREATE VIEW vw_residences AS
	SELECT levellocations.levellocationid, levellocations.levellocationname, 
		residences.residenceid, residences.residencename, residences.capacity, residences.roomsize,
		residences.defaultrate, residences.offcampus, residences.Sex, residences.residencedean, residences.details
	FROM levellocations INNER JOIN residences ON levellocations.levellocationid = residences.levellocationid;

CREATE VIEW denominationview AS
	SELECT religions.religionid, religions.religionname, religions.details as religiondetails,
		denominations.denominationid, denominations.denominationname, denominations.details as denominationdetails
		FROM religions INNER JOIN denominations ON religions.religionid = denominations.religionid;

CREATE VIEW departmentview AS
	SELECT schools.schoolid, schools.schoolname, departments.departmentid, departments.departmentname,
		departments.philosopy, departments.vision, departments.mission, departments.objectives,
		departments.exposures, departments.oppotunities, departments.details
	FROM schools INNER JOIN departments ON schools.schoolid = departments.schoolid
	ORDER BY departments.schoolid;

CREATE VIEW sublevelview AS
	SELECT degreelevels.degreelevelid, degreelevels.degreelevelname,
		degreelevels.freshman, degreelevels.sophomore, degreelevels.junior, degreelevels.senior,
		levellocations.levellocationid, levellocations.levellocationname,
		sublevels.org_id, sublevels.sublevelid, sublevels.sublevelname, sublevels.specialcharges, 
		sublevels.unit_charge, sublevels.lab_charges, sublevels.exam_fees, sublevels.general_fees,
		sublevels.details
	FROM sublevels INNER JOIN degreelevels ON sublevels.degreelevelid = degreelevels.degreelevelid
		INNER JOIN levellocations ON sublevels.levellocationid = levellocations.levellocationid;
		
CREATE VIEW degreeview AS
	SELECT degreelevels.degreelevelid, degreelevels.degreelevelname, degrees.degreeid, degrees.degreename, degrees.details
	FROM degreelevels INNER JOIN degrees ON degreelevels.degreelevelid = degrees.degreelevelid;

CREATE VIEW instructorview AS
	SELECT departmentview.schoolid, departmentview.schoolname, departmentview.departmentid, departmentview.departmentname,
		instructors.org_id, instructors.instructorid, instructors.instructorname
	FROM departmentview INNER JOIN instructors ON departmentview.departmentid = instructors.departmentid;

CREATE VIEW courseview AS
	SELECT departmentview.schoolid, departmentview.schoolname, departmentview.departmentid, departmentview.departmentname,
		degreelevels.degreelevelid, degreelevels.degreelevelname, coursetypes.coursetypeid, coursetypes.coursetypename,
		courses.courseid, courses.coursetitle, courses.credithours, courses.maxcredit, courses.labcourse, courses.iscurrent,
		courses.nogpa, courses.yeartaken, courses.mathplacement, courses.englishplacement, kiswahiliplacement, courses.details
	FROM ((departmentview INNER JOIN courses ON departmentview.departmentid = courses.departmentid)
		INNER JOIN degreelevels ON courses.degreelevelid = degreelevels.degreelevelid)
		INNER JOIN coursetypes ON courses.coursetypeid = coursetypes.coursetypeid;

CREATE VIEW prereqview AS
	SELECT courses.courseid, courses.coursetitle, prerequisites.prerequisiteid,  prerequisites.precourseid, 
		prerequisites.optionlevel, prerequisites.narrative, grades.gradeid, grades.gradeweight,
		bulleting.bulletingid, bulleting.bulletingname, bulleting.startingquarter, bulleting.endingquarter
	FROM ((courses INNER JOIN prerequisites ON courses.courseid = prerequisites.courseid)
		INNER JOIN grades ON prerequisites.gradeid = grades.gradeid)
		INNER JOIN bulleting ON prerequisites.bulletingid = bulleting.bulletingid;

CREATE VIEW prerequisiteview AS
	SELECT courses.courseid as precourseid, courses.coursetitle as precoursetitle,
		prereqview.courseid, prereqview.coursetitle, prereqview.prerequisiteid,  
		prereqview.optionlevel, prereqview.narrative, prereqview.gradeid, prereqview.gradeweight,
		prereqview.bulletingid, prereqview.bulletingname, prereqview.startingquarter, prereqview.endingquarter
	FROM courses INNER JOIN prereqview ON courses.courseid = prereqview.precourseid
	ORDER BY prereqview.courseid, prereqview.optionlevel;

CREATE VIEW majorview AS
	SELECT departmentview.schoolid, departmentview.schoolname, departmentview.departmentid, departmentview.departmentname,
		majors.majorid, majors.majorname, majors.electivecredit, majors.majorminimal, majors.minorminimum, majors.coreminimum,
		majors.major, majors.minor, majors.details
	FROM departmentview INNER JOIN majors ON departmentview.departmentid = majors.departmentid;

CREATE VIEW vw_majoroptions AS
	SELECT majorview.schoolid, majorview.schoolname, majorview.departmentid, majorview.departmentname,
		majorview.majorid, majorview.majorname, majorview.electivecredit, majorview.majorminimal, 
		majorview.minorminimum, majorview.coreminimum, majorview.major, majorview.minor, majorview.details as major_details,
		majoroptions.majoroptionid, majoroptions.majoroptionname, majoroptions.details
	FROM majorview INNER JOIN majoroptions ON majorview.majorid = majoroptions.majorid;

CREATE VIEW vw_major_bulletings AS
	SELECT majorview.schoolid, majorview.schoolname, majorview.departmentid, majorview.departmentname,
		majorview.majorid, majorview.majorname, majorview.electivecredit, majorview.majorminimal, 
		majorview.minorminimum, majorview.coreminimum, majorview.major, majorview.minor, majorview.details,
		bulleting.bulletingid, bulleting.bulletingname, bulleting.startingquarter,
		bulleting.endingquarter, bulleting.iscurrent
	FROM majorview CROSS JOIN bulleting;

CREATE VIEW vw_majoroption_bulletings AS
	SELECT vw_majoroptions.schoolid, vw_majoroptions.schoolname, vw_majoroptions.departmentid, vw_majoroptions.departmentname,
		vw_majoroptions.majorid, vw_majoroptions.majorname, vw_majoroptions.electivecredit, vw_majoroptions.majorminimal, 
		vw_majoroptions.minorminimum, vw_majoroptions.coreminimum, vw_majoroptions.major, vw_majoroptions.minor, vw_majoroptions.major_details,
		vw_majoroptions.majoroptionid, vw_majoroptions.majoroptionname, vw_majoroptions.details,
		bulleting.bulletingid, bulleting.bulletingname, bulleting.startingquarter,
		bulleting.endingquarter, bulleting.iscurrent
	FROM vw_majoroptions CROSS JOIN bulleting;

CREATE VIEW requirementview AS
	SELECT majorview.schoolid, majorview.departmentid, majorview.departmentname, majorview.majorid, majorview.majorname, 
		subjects.subjectid, subjects.subjectname, marks.markid,	marks.grade, requirements.requirementid, requirements.narrative
	FROM ((majorview INNER JOIN requirements ON majorview.majorid = requirements.majorid)
		INNER JOIN subjects ON requirements.subjectid = subjects.subjectid)
		INNER JOIN marks ON requirements.markid = marks.markid;

CREATE VIEW majorcontentview AS
	SELECT majorview.schoolid, majorview.departmentid, majorview.departmentname, majorview.majorid, majorview.majorname, 
		majorview.electivecredit, courses.courseid, courses.coursetitle, courses.credithours, courses.nogpa, 
		courses.yeartaken, courses.details as course_details,
		contenttypes.contenttypeid, contenttypes.contenttypename, contenttypes.elective, contenttypes.prerequisite,
		contenttypes.premajor, majorcontents.majorcontentid, majorcontents.minor, majorcontents.gradeid, majorcontents.narrative,
		bulleting.bulletingid, bulleting.bulletingname, bulleting.startingquarter, bulleting.endingquarter,
		bulleting.iscurrent
	FROM (((majorview INNER JOIN majorcontents ON majorview.majorid = majorcontents.majorid)
		INNER JOIN courses ON majorcontents.courseid = courses.courseid)
		INNER JOIN contenttypes ON majorcontents.contenttypeid = contenttypes.contenttypeid)
		INNER JOIN bulleting ON majorcontents.bulletingid = bulleting.bulletingid;

CREATE VIEW majoroptcontentview AS
	SELECT majoroptions.majoroptionid, majoroptions.majorid, majoroptions.majoroptionname,
		courses.courseid, courses.coursetitle, courses.credithours, courses.nogpa, 
		courses.yeartaken, courses.details as course_details,
		contenttypes.contenttypeid, contenttypes.contenttypename, contenttypes.elective, contenttypes.prerequisite, contenttypes.premajor,
		majoroptcontents.majoroptcontentid, majoroptcontents.minor, majoroptcontents.gradeid, majoroptcontents.narrative,
		bulleting.bulletingid, bulleting.bulletingname, bulleting.startingquarter, bulleting.endingquarter,
		bulleting.iscurrent
	FROM (((majoroptions INNER JOIN majoroptcontents ON majoroptions.majoroptionid = majoroptcontents.majoroptionid)
		INNER JOIN courses ON majoroptcontents.courseid = courses.courseid)
		INNER JOIN contenttypes ON majoroptcontents.contenttypeid = contenttypes.contenttypeid)
		INNER JOIN bulleting ON majoroptcontents.bulletingid = bulleting.bulletingid;

CREATE VIEW vw_major_prereq AS
	SELECT majorcontentview.schoolid, majorcontentview.departmentid, majorcontentview.departmentname, 
		majorcontentview.majorid, majorcontentview.majorname, majorcontentview.electivecredit, 
		majorcontentview.courseid as precourseid, majorcontentview.coursetitle as precoursetitle,
		majorcontentview.contenttypeid, majorcontentview.contenttypename, majorcontentview.elective, majorcontentview.prerequisite,
		majorcontentview.premajor, majorcontentview.majorcontentid, majorcontentview.minor, 
		majorcontentview.iscurrent,
		prereqview.courseid, prereqview.coursetitle, prereqview.prerequisiteid,  
		prereqview.optionlevel, prereqview.narrative, prereqview.gradeid, prereqview.gradeweight,
		prereqview.bulletingid, prereqview.bulletingname, prereqview.startingquarter, prereqview.endingquarter		
	FROM majorcontentview INNER JOIN prereqview ON majorcontentview.courseid = prereqview.precourseid
	ORDER BY prereqview.courseid, prereqview.optionlevel;

CREATE VIEW studentview AS
	SELECT denominationview.religionid, denominationview.religionname, denominationview.denominationid, denominationview.denominationname,
		residences.residenceid, residences.residencename,
		schools.schoolid, schools.schoolname, c1.countryname as addresscountry, 
		students.org_id, students.studentid, students.studentname, students.address, students.zipcode, students.town,
		students.telno, students.email,  students.guardianname, students.gaddress,
		students.gzipcode, students.gtown, c2.countryname as gaddresscountry, students.gtelno, students.gemail,
		students.accountnumber, students.Nationality, c3.countryname as Nationalitycountry, students.Sex,
		students.MaritalStatus, students.birthdate, students.firstpass, students.alumnae, students.postcontacts, 
		students.onprobation, students.offcampus, students.currentcontact, students.currentemail, students.currenttel,
		students.seeregistrar, students.hallseats, students.staff, students.fullbursary, students.details,
		students.room_number, students.probation_details, students.registrar_details,
		students.gfirstpass, ('G' || students.studentid) as gstudentid
	FROM (((denominationview INNER JOIN students ON denominationview.denominationid = students.denominationid)
		INNER JOIN schools ON students.schoolid = schools.schoolid)
		LEFT JOIN residences ON students.residenceid = residences.residenceid)
		INNER JOIN countrys as c1 ON students.countrycodeid = c1.countryid
		INNER JOIN countrys as c2 ON students.gcountrycodeid = c2.countryid
		INNER JOIN countrys as c3 ON students.Nationality = c3.countryid;

CREATE VIEW vw_students AS
	SELECT denominationview.religionid, denominationview.religionname, denominationview.denominationid, denominationview.denominationname,
		residences.residenceid, residences.residencename,
		schools.schoolid, schools.schoolname, c1.countryname as addresscountry, 
		students.org_id, students.studentid, students.studentname, students.address, students.zipcode, students.town,
		students.telno, students.email,  students.guardianname, students.gaddress,
		students.gzipcode, students.gtown, c2.countryname as gaddresscountry, students.gtelno, students.gemail,
		students.accountnumber, students.Nationality, c3.countryname as Nationalitycountry, students.Sex,
		students.MaritalStatus, students.birthdate, students.firstpass, students.alumnae, students.postcontacts, 
		students.onprobation, students.offcampus, students.currentcontact, students.currentemail, students.currenttel,
		students.seeregistrar, students.hallseats, students.staff, students.fullbursary, students.details,
		students.room_number, students.probation_details, students.registrar_details,
		students.student_edit, students.disability, students.dis_details, students.passport,
		students.national_id, students.identification_no,
		students.gfirstpass, ('G' || students.studentid) as gstudentid
		
	FROM (((denominationview INNER JOIN students ON denominationview.denominationid = students.denominationid)
		INNER JOIN schools ON students.schoolid = schools.schoolid)
		LEFT JOIN residences ON students.residenceid = residences.residenceid)
		INNER JOIN countrys as c1 ON students.countrycodeid = c1.countryid
		INNER JOIN countrys as c2 ON students.gcountrycodeid = c2.countryid
		INNER JOIN countrys as c3 ON students.Nationality = c3.countryid;

CREATE VIEW studentrequestview AS
	SELECT students.studentid, students.studentname, requesttypes.requesttypeid, requesttypes.requesttypename, requesttypes.toapprove,
		requesttypes.details as typedetails, 
		studentrequests.org_id, studentrequests.studentrequestid, studentrequests.narrative, studentrequests.datesent,
		studentrequests.actioned, studentrequests.dateactioned, studentrequests.approved, studentrequests.dateapploved,
		studentrequests.details, studentrequests.reply
	FROM (students INNER JOIN studentrequests ON students.studentid = studentrequests.studentid)
		INNER JOIN requesttypes ON studentrequests.requesttypeid = requesttypes.requesttypeid;

CREATE VIEW studentdegreeview AS
	SELECT studentview.religionid, studentview.religionname, studentview.denominationid, studentview.denominationname,
		studentview.schoolid, studentview.schoolname, studentview.studentid, studentview.studentname, studentview.address, studentview.zipcode,
		studentview.town, studentview.addresscountry, studentview.telno, studentview.email,  studentview.guardianname, studentview.gaddress,
		studentview.gzipcode, studentview.gtown, studentview.gaddresscountry, studentview.gtelno, studentview.gemail,
		studentview.accountnumber, studentview.Nationality, studentview.Nationalitycountry, studentview.Sex,
		studentview.MaritalStatus, studentview.birthdate, studentview.firstpass, studentview.alumnae, studentview.postcontacts,
		studentview.onprobation, studentview.offcampus, studentview.currentcontact, studentview.currentemail, studentview.currenttel,
		studentview.org_id,
		sublevelview.degreelevelid, sublevelview.degreelevelname,
		sublevelview.freshman, sublevelview.sophomore, sublevelview.junior, sublevelview.senior,
		sublevelview.levellocationid, sublevelview.levellocationname,
		sublevelview.sublevelid, sublevelview.sublevelname, sublevelview.specialcharges,
		degrees.degreeid, degrees.degreename,
		studentdegrees.studentdegreeid, studentdegrees.completed, studentdegrees.started, studentdegrees.cleared, studentdegrees.clearedate,
		studentdegrees.graduated, studentdegrees.graduatedate, studentdegrees.dropout, studentdegrees.transferin, studentdegrees.transferout,
		studentdegrees.mathplacement, studentdegrees.englishplacement, studentdegrees.details
	FROM ((studentview INNER JOIN studentdegrees ON studentview.studentid = studentdegrees.studentid)
		INNER JOIN sublevelview ON studentdegrees.sublevelid = sublevelview.sublevelid)
		INNER JOIN degrees ON studentdegrees.degreeid = degrees.degreeid;

CREATE VIEW transcriptprintview AS
	SELECT entitys.entity_id, entitys.entity_name, entitys.user_name, transcriptprint.transcriptprintid, 
		transcriptprint.studentdegreeid, transcriptprint.printdate, transcriptprint.narrative,
		transcriptprint.ip_address, transcriptprint.accepted
	FROM transcriptprint INNER JOIN entitys ON transcriptprint.entity_id = entitys.entity_id; 

CREATE VIEW transferedcreditsview AS
	SELECT studentdegreeview.degreeid, studentdegreeview.degreename, studentdegreeview.sublevelid, studentdegreeview.sublevelname,
		studentdegreeview.studentid, studentdegreeview.studentname, studentdegreeview.studentdegreeid, courses.courseid, courses.coursetitle,
		transferedcredits.transferedcreditid, transferedcredits.credithours, transferedcredits.narrative
	FROM (studentdegreeview INNER JOIN transferedcredits ON studentdegreeview.studentdegreeid = transferedcredits.studentdegreeid)
		INNER JOIN courses ON transferedcredits.courseid = courses.courseid;

CREATE VIEW studentmajorview AS 
	SELECT studentdegreeview.religionid, studentdegreeview.religionname, studentdegreeview.denominationid, studentdegreeview.denominationname,
		studentdegreeview.schoolid as studentschoolid, studentdegreeview.schoolname as studentschoolname, studentdegreeview.studentid,
		studentdegreeview.studentname, studentdegreeview.Nationality, studentdegreeview.Nationalitycountry, studentdegreeview.Sex,
		studentdegreeview.MaritalStatus, studentdegreeview.birthdate, 
		studentdegreeview.degreelevelid, studentdegreeview.degreelevelname,
		studentdegreeview.freshman, studentdegreeview.sophomore, studentdegreeview.junior, studentdegreeview.senior,
		studentdegreeview.levellocationid, studentdegreeview.levellocationname,
		studentdegreeview.sublevelid, studentdegreeview.sublevelname, studentdegreeview.specialcharges,
		studentdegreeview.degreeid, studentdegreeview.degreename,
		studentdegreeview.studentdegreeid, studentdegreeview.completed, studentdegreeview.started, studentdegreeview.cleared, studentdegreeview.clearedate,
		studentdegreeview.graduated, studentdegreeview.graduatedate, studentdegreeview.dropout, studentdegreeview.transferin, studentdegreeview.transferout,
		studentdegreeview.mathplacement, studentdegreeview.englishplacement,
		majorview.schoolid, majorview.schoolname, majorview.departmentid, majorview.departmentname,
		majorview.majorid, majorview.majorname, majorview.major as domajor, majorview.minor as dominor,
		majoroptions.majoroptionid, majoroptions.majoroptionname,
		majorview.electivecredit, majorview.majorminimal, majorview.minorminimum, majorview.coreminimum,
		studentmajors.studentmajorid, studentmajors.major, studentmajors.nondegree, studentmajors.premajor, 
		studentmajors.primarymajor, studentmajors.details
	FROM ((studentdegreeview INNER JOIN studentmajors ON studentdegreeview.studentdegreeid = studentmajors.studentdegreeid)
		INNER JOIN majorview ON studentmajors.majorid = majorview.majorid)
		LEFT JOIN majoroptions ON studentmajors.majoroptionid = majoroptions.majoroptionid;

CREATE VIEW primarymajorview AS
	SELECT schools.schoolid, schools.schoolname, departments.departmentid, departments.departmentname, 
		majors.majorid, majors.majorname, studentmajors.studentdegreeid	
	FROM ((schools INNER JOIN departments ON schools.schoolid = departments.schoolid) 
		INNER JOIN majors ON departments.departmentid = majors.departmentid)
		INNER JOIN studentmajors ON majors.majorid = studentmajors.majorid
	WHERE (studentmajors.major = true) AND (studentmajors.primarymajor = true); 

CREATE VIEW primajorstudentview AS
	SELECT students.org_id, students.studentid, students.studentname, students.accountnumber, students.Nationality, 
		students.sex, students.MaritalStatus, students.birthdate, students.onprobation, students.offcampus,
		studentdegrees.studentdegreeid, studentdegrees.completed, studentdegrees.started, studentdegrees.graduated,
		primarymajorview.schoolid, primarymajorview.schoolname, primarymajorview.departmentid, primarymajorview.departmentname, 
		primarymajorview.majorid, primarymajorview.majorname
	FROM (students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid)
		INNER JOIN primarymajorview ON studentdegrees.studentdegreeid = primarymajorview.studentdegreeid
	WHERE (studentdegrees.completed = false);

CREATE VIEW quarterview AS
	SELECT quarters.quarterid, quarters.qstart, quarters.qlatereg, quarters.qlatechange, quarters.qlastdrop,
		quarters.qend, quarters.active, quarters.chalengerate, quarters.feesline, quarters.resline, 
		quarters.closed, quarters.quarter_name, quarters.minimal_fees, quarters.details,
		substring(quarters.quarterid from 1 for 9)  as quarteryear, 
		trim(substring(quarters.quarterid from 11 for 2)) as quarter
	FROM quarters
	ORDER BY quarterid desc;

CREATE VIEW activequarter AS
	SELECT quarterid, quarteryear, quarter, qstart, qlatereg, qlatechange, closed, quarter_name,
		qlastdrop, qend, active, chalengerate, feesline, resline, minimal_fees, details
	FROM quarterview
	WHERE (active = true);

CREATE VIEW yearview AS
	SELECT quarteryear
	FROM quarterview
	GROUP BY quarteryear
	ORDER BY quarteryear desc;

CREATE VIEW qcalendarview AS
	SELECT sublevelview.degreelevelid, sublevelview.degreelevelname, sublevelview.sublevelid, sublevelview.sublevelname,
		qcalendar.org_id, qcalendar.qcalendarid, qcalendar.quarterid, qcalendar.qdate, qcalendar.event, qcalendar.details
	FROM sublevelview INNER JOIN qcalendar ON sublevelview.sublevelid = qcalendar.sublevelid;

CREATE VIEW qresidenceview AS
	SELECT residences.residenceid, residences.residencename, residences.capacity, residences.defaultrate,
		residences.offcampus, residences.Sex, residences.residencedean,
		quarterview.quarteryear, quarterview.quarter, quarterview.active, quarterview.closed, quarterview.quarter_name,
		qresidences.org_id, qresidences.qresidenceid, qresidences.quarterid, qresidences.residenceoption,
		qresidences.charges, qresidences.details
	FROM (residences INNER JOIN qresidences ON residences.residenceid = qresidences.residenceid)
	INNER JOIN quarterview ON qresidences.quarterid = quarterview.quarterid;

CREATE VIEW vw_charges AS
	SELECT quarterview.quarterid, quarterview.qstart, quarterview.qlatereg, quarterview.qlatechange, quarterview.qlastdrop,
		quarterview.qend, quarterview.active, quarterview.chalengerate, quarterview.feesline, quarterview.resline, 
		quarterview.minimal_fees, quarterview.closed, quarterview.quarter_name, quarterview.quarteryear, quarterview.quarter, 

		degreelevels.degreelevelid, degreelevels.degreelevelname, 
		levellocations.levellocationid, levellocations.levellocationname, 

		sublevels.sublevelid, sublevels.sublevelname, sublevels.specialcharges,

		charges.org_id, charges.charge_id, charges.session_active, charges.session_closed, charges.exam_balances, 
		charges.sun_posted, charges.unit_charge, charges.lab_charges, charges.exam_fees, charges.general_fees, 
		charges.residence_stay, charges.currency, charges.exchange_rate, charges.narrative		
	FROM quarterview INNER JOIN charges ON quarterview.quarterid = charges.quarterid
		INNER JOIN sublevels ON charges.sublevelid = sublevels.sublevelid
		INNER JOIN degreelevels ON sublevels.degreelevelid = degreelevels.degreelevelid
		INNER JOIN levellocations ON sublevels.levellocationid = levellocations.levellocationid;

CREATE VIEW residenceroom AS
	SELECT residenceid, residencename, roomsize, capacity, generate_series(1, capacity+1) as roomnumber
	FROM residences;

CREATE OR REPLACE FUNCTION roomcount(integer, integer) RETURNS bigint AS $$
	SELECT count(qstudentid) FROM qstudents WHERE (qresidenceid = $1) AND (roomnumber = $2);
$$ LANGUAGE SQL;

CREATE VIEW qresidenceroom AS
	SELECT residenceroom.residenceid, residenceroom.residencename, residenceroom.roomsize, residenceroom.capacity, residenceroom.roomnumber, 
		roomcount(qresidences.qresidenceid, residenceroom.roomnumber) as roomcount,
		residenceroom.roomsize - roomcount(qresidences.qresidenceid, residenceroom.roomnumber) as roombalance,
		qresidences.qresidenceid, qresidences.quarterid, qresidences.org_id,
		(qresidences.qresidenceid || 'R' || residenceroom.roomnumber) as roomid
	FROM residenceroom INNER JOIN qresidences ON residenceroom.residenceid = qresidences.residenceid;

CREATE VIEW qstudentresroom AS
	SELECT students.studentid, students.studentname, students.Sex, qstudents.qstudentid,
		qresidenceroom.residenceid, qresidenceroom.residencename, qresidenceroom.roomsize, qresidenceroom.capacity,
		qresidenceroom.roomnumber, qresidenceroom.roomcount, qresidenceroom.roombalance, roomid,
		qresidenceroom.qresidenceid, qresidenceroom.quarterid, qresidenceroom.org_id,
		quarters.closed, quarters.quarter_name
	FROM (((students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid)
		INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)  
		INNER JOIN qresidenceroom ON qstudents.qresidenceid = qresidenceroom.qresidenceid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid
	WHERE (quarters.active = true) AND (qresidenceroom.roombalance > 0);

CREATE VIEW qstudentlist AS
	SELECT students.studentid, students.schoolid, students.studentname, students.Sex, students.Nationality, students.MaritalStatus,
		students.birthdate, students.email, studentdegrees.studentdegreeid, studentdegrees.degreeid, studentdegrees.sublevelid,
		qstudents.qstudentid, qstudents.quarterid, qstudents.charges, qstudents.probation,
		qstudents.roomnumber, qstudents.currbalance, qstudents.finaceapproval,
		qstudents.firstinstalment, qstudents.firstdate, qstudents.secondinstalment, qstudents.seconddate,
		qstudents.financenarrative, qstudents.residencerefund, qstudents.feerefund, qstudents.finalised,
		qstudents.majorapproval, qstudents.chaplainapproval, qstudents.overloadapproval, qstudents.studentdeanapproval,
		qstudents.overloadhours, qstudents.intersession, qstudents.closed, qstudents.printed, qstudents.approved,
		substring(qstudents.quarterid from 1 for 9) as academicyear
	FROM (students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid)
		INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid;

CREATE VIEW qstudentdegreeview AS
	SELECT students.studentid, students.schoolid, students.studentname, students.Sex, students.Nationality, students.MaritalStatus,
		students.birthdate, students.email, studentdegrees.studentdegreeid, studentdegrees.degreeid,
		sublevels.sublevelid, sublevels.degreelevelid, sublevels.levellocationid, sublevels.sublevelname, sublevels.specialcharges,
        qstudents.org_id, qstudents.qstudentid, qstudents.quarterid, qstudents.charges, 
		qstudents.probation, qstudents.roomnumber, qstudents.currbalance, qstudents.applicationtime, qstudents.residencerefund, qstudents.feerefund, 
		qstudents.finalised, qstudents.finaceapproval, qstudents.majorapproval, qstudents.chaplainapproval, qstudents.studentdeanapproval, 
		qstudents.overloadapproval, qstudents.overloadhours, qstudents.intersession, qstudents.closed, qstudents.printed, qstudents.approved, qstudents.noapproval,
		qstudents.exam_clear, qstudents.exam_clear_date, qstudents.exam_clear_balance,
		qresidenceview.residenceid, qresidenceview.residencename, qresidenceview.capacity, qresidenceview.defaultrate,
		qresidenceview.offcampus, qresidenceview.Sex as residencesex, qresidenceview.residencedean, qresidenceview.charges as residencecharges,
		qresidenceview.qresidenceid, qresidenceview.residenceoption, (qresidenceview.qresidenceid || 'R' || qstudents.roomnumber) as roomid,
		qresidenceview.quarter_name, sabathclasses.sabathclassid, sabathclasses.sabathclassoption, sabathclasses.instructor,
		sabathclasses.venue, sabathclasses.capacity as sbcapacity		  
	FROM (((students INNER JOIN (studentdegrees INNER JOIN sublevels ON studentdegrees.sublevelid = sublevels.sublevelid) ON students.studentid = studentdegrees.studentid)
		INNER JOIN qstudents ON studentdegrees.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN qresidenceview ON qstudents.qresidenceid = qresidenceview.qresidenceid)
		INNER JOIN sabathclasses ON qstudents.sabathclassid = sabathclasses.sabathclassid;

CREATE VIEW qcurrstudentdegreeview AS 
	SELECT qstudentdegreeview.org_id, qstudentdegreeview.studentid, qstudentdegreeview.schoolid, qstudentdegreeview.studentname, qstudentdegreeview.sex, 
		qstudentdegreeview.nationality, qstudentdegreeview.maritalstatus, qstudentdegreeview.birthdate, qstudentdegreeview.email, 
		qstudentdegreeview.studentdegreeid, qstudentdegreeview.degreeid, qstudentdegreeview.sublevelid, qstudentdegreeview.qstudentid, 
		qstudentdegreeview.quarterid, qstudentdegreeview.charges, qstudentdegreeview.probation, qstudentdegreeview.roomnumber, 
		qstudentdegreeview.currbalance, qstudentdegreeview.finaceapproval,  
		qstudentdegreeview.residencerefund, qstudentdegreeview.feerefund, qstudentdegreeview.finalised, qstudentdegreeview.majorapproval, 
		qstudentdegreeview.chaplainapproval, qstudentdegreeview.overloadapproval, 
		qstudentdegreeview.studentdeanapproval, qstudentdegreeview.overloadhours, qstudentdegreeview.intersession, 
		qstudentdegreeview.closed, qstudentdegreeview.printed, qstudentdegreeview.approved, qstudentdegreeview.noapproval, 
		qstudentdegreeview.exam_clear, qstudentdegreeview.exam_clear_date, qstudentdegreeview.exam_clear_balance,
		qstudentdegreeview.qresidenceid, qstudentdegreeview.residenceid, qstudentdegreeview.residencename, qstudentdegreeview.roomid,
		qstudentdegreeview.sabathclassid, qstudentdegreeview.sabathclassoption, qstudentdegreeview.instructor,
		qstudentdegreeview.venue, qstudentdegreeview.sbcapacity
	FROM qstudentdegreeview
	JOIN quarters ON qstudentdegreeview.quarterid = quarters.quarterid
	WHERE quarters.active = true;

CREATE VIEW qstudentview AS
	SELECT studentdegreeview.religionid, studentdegreeview.religionname, studentdegreeview.denominationid, studentdegreeview.denominationname,
		studentdegreeview.schoolid, studentdegreeview.schoolname, studentdegreeview.studentid, studentdegreeview.studentname, studentdegreeview.address, studentdegreeview.zipcode,
		studentdegreeview.town, studentdegreeview.addresscountry, studentdegreeview.telno, studentdegreeview.email,  studentdegreeview.guardianname, studentdegreeview.gaddress,
		studentdegreeview.gzipcode, studentdegreeview.gtown, studentdegreeview.gaddresscountry, studentdegreeview.gtelno, studentdegreeview.gemail,
		studentdegreeview.accountnumber, studentdegreeview.Nationality, studentdegreeview.Nationalitycountry, studentdegreeview.Sex,
		studentdegreeview.MaritalStatus, studentdegreeview.birthdate, studentdegreeview.firstpass, studentdegreeview.alumnae, studentdegreeview.postcontacts,
		studentdegreeview.onprobation, studentdegreeview.offcampus, studentdegreeview.currentcontact, studentdegreeview.currentemail, studentdegreeview.currenttel,
		studentdegreeview.freshman, studentdegreeview.sophomore, studentdegreeview.junior, studentdegreeview.senior,

		studentdegreeview.degreeid, studentdegreeview.degreename,
		studentdegreeview.studentdegreeid, studentdegreeview.completed, studentdegreeview.started, studentdegreeview.cleared, studentdegreeview.clearedate,
		studentdegreeview.graduated, studentdegreeview.graduatedate, studentdegreeview.dropout, studentdegreeview.transferin, studentdegreeview.transferout,
		studentdegreeview.mathplacement, studentdegreeview.englishplacement,

		vw_charges.quarterid, vw_charges.qstart, vw_charges.qlatereg, vw_charges.qlatechange, 
		vw_charges.qlastdrop, vw_charges.qend, vw_charges.active, vw_charges.chalengerate, 
		vw_charges.feesline, vw_charges.resline, vw_charges.quarteryear, vw_charges.quarter, 
		vw_charges.closed, vw_charges.quarter_name, vw_charges.degreelevelid, vw_charges.degreelevelname, 
		vw_charges.charge_id, vw_charges.unit_charge, vw_charges.lab_charges, vw_charges.exam_fees, 
		vw_charges.levellocationid, vw_charges.levellocationname, 
		vw_charges.sublevelid, vw_charges.sublevelname,	vw_charges.specialcharges,
		vw_charges.sun_posted, vw_charges.session_active,
		vw_charges.session_closed, vw_charges.general_fees, vw_charges.residence_stay,
		vw_charges.currency, vw_charges.exchange_rate,

		qresidenceview.residenceid, qresidenceview.residencename, qresidenceview.capacity, qresidenceview.defaultrate,
		qresidenceview.offcampus as residenceoffcampus, qresidenceview.Sex as residencesex, qresidenceview.residencedean,
		qresidenceview.qresidenceid, qresidenceview.residenceoption,  
		qstudents.org_id, qstudents.qstudentid, qstudents.charges as additionalcharges, qstudents.approved, qstudents.probation,
		qstudents.roomnumber, qstudents.currbalance, qstudents.finaceapproval, qstudents.majorapproval, qstudents.studentdeanapproval,
		qstudents.intersession, qstudents.exam_clear, qstudents.exam_clear_date, qstudents.exam_clear_balance,
		qstudents.request_withdraw, qstudents.request_withdraw_date, qstudents.withdraw, qstudents.ac_withdraw,
		qstudents.withdraw_date, qstudents.withdraw_rate, 
		qstudents.departapproval, qstudents.overloadapproval, qstudents.finalised, qstudents.printed, qstudents.details,

		vw_charges.unit_charge as ucharge, (vw_charges.residence_stay * qresidenceview.charges / 100) as residencecharge,
		vw_charges.lab_charges as lcharge, vw_charges.general_fees as feescharge
	FROM (((studentdegreeview INNER JOIN qstudents ON studentdegreeview.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN vw_charges ON qstudents.charge_id = vw_charges.charge_id)
		INNER JOIN qresidenceview ON qstudents.qresidenceid = qresidenceview.qresidenceid);

CREATE VIEW printedstudentview AS
	SELECT qstudentview.religionid, qstudentview.religionname, qstudentview.denominationid, qstudentview.denominationname, qstudentview.schoolid,
		qstudentview.schoolname, qstudentview.studentid, qstudentview.studentname, qstudentview.address, qstudentview.zipcode, qstudentview.town,
		qstudentview.addresscountry, qstudentview.telno, qstudentview.email, qstudentview. guardianname, qstudentview.gaddress, qstudentview.gzipcode,
		qstudentview.gtown, qstudentview.gaddresscountry, qstudentview.gtelno, qstudentview.gemail, accountnumber, qstudentview.Nationality,
		qstudentview.Nationalitycountry, qstudentview.Sex, qstudentview.MaritalStatus, qstudentview.birthdate, qstudentview.firstpass, qstudentview.alumnae, 
		qstudentview.postcontacts, qstudentview.onprobation, qstudentview.offcampus, qstudentview.currentcontact, qstudentview.currentemail, qstudentview.currenttel,
		qstudentview.degreelevelid, qstudentview.degreelevelname, qstudentview.freshman, qstudentview.sophomore,
		qstudentview.junior, qstudentview.senior, qstudentview.levellocationid, qstudentview.levellocationname, qstudentview.sublevelid, qstudentview.sublevelname, qstudentview.specialcharges,
		qstudentview.degreeid, qstudentview.degreename, qstudentview.studentdegreeid, qstudentview.completed, qstudentview.started, qstudentview.cleared, qstudentview.clearedate,
		qstudentview.graduated, qstudentview.graduatedate, qstudentview.dropout, qstudentview.transferin, qstudentview.transferout, qstudentview.mathplacement, qstudentview.englishplacement,
		qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.qstart, qstudentview.qlatereg, qstudentview.qlatechange, qstudentview.qlastdrop,
		qstudentview.qend, qstudentview.active, qstudentview.feesline, qstudentview.resline,
		qstudentview.residenceid, qstudentview.residencename, qstudentview.capacity, qstudentview.defaultrate, qstudentview.residenceoffcampus, qstudentview.residencesex, qstudentview.residencedean,
		qstudentview.qresidenceid, qstudentview.residenceoption, qstudentview.qstudentid, qstudentview.approved, qstudentview.probation,
		qstudentview.roomnumber, qstudentview.finaceapproval, qstudentview.majorapproval, qstudentview.departapproval, qstudentview.overloadapproval, qstudentview.finalised, qstudentview.printed,
		qstudentview.org_id, majors.majorname
	FROM (qstudentview LEFT JOIN (studentmajors INNER JOIN majors ON studentmajors.majorid = majors.majorid) ON qstudentview.studentdegreeid = studentmajors.studentdegreeid)
	WHERE (active = true) AND (finalised = true) AND (printed = true);

CREATE VIEW qprimajorstudentview AS
	SELECT primajorstudentview.org_id, primajorstudentview.studentid, primajorstudentview.studentname, primajorstudentview.accountnumber, 
		primajorstudentview.Nationality, primajorstudentview.Sex,
		primajorstudentview.MaritalStatus, primajorstudentview.birthdate, primajorstudentview.onprobation, primajorstudentview.offcampus,
		primajorstudentview.studentdegreeid, primajorstudentview.completed, primajorstudentview.started, primajorstudentview.graduated,
		primajorstudentview.departmentid, primajorstudentview.departmentname, primajorstudentview.majorid, primajorstudentview.majorname,
		primajorstudentview.schoolid, primajorstudentview.schoolname,
		qstudents.qstudentid, qstudents.quarterid, qstudents.majorapproval, qstudents.departapproval, qstudents.noapproval
	FROM primajorstudentview INNER JOIN (qstudents INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid)
		ON primajorstudentview.studentdegreeid = qstudents.studentdegreeid 
	WHERE (quarters.active = true) AND (qstudents.finalised = true) AND (qstudents.majorapproval = false);

CREATE VIEW qstudentmajorview AS 
	SELECT studentmajorview.religionid, studentmajorview.religionname, studentmajorview.denominationid, studentmajorview.denominationname,
		studentmajorview.schoolid as studentschoolid, studentmajorview.schoolname as studentschoolname, studentmajorview.studentid,
		studentmajorview.studentname, studentmajorview.Nationality, studentmajorview.Nationalitycountry, studentmajorview.Sex,
		studentmajorview.MaritalStatus, studentmajorview.birthdate, 
		studentmajorview.degreelevelid, studentmajorview.degreelevelname,
		studentmajorview.freshman, studentmajorview.sophomore, studentmajorview.junior, studentmajorview.senior,
		studentmajorview.levellocationid, studentmajorview.levellocationname,
		studentmajorview.sublevelid, studentmajorview.sublevelname, studentmajorview.specialcharges,
		studentmajorview.degreeid, studentmajorview.degreename,
		studentmajorview.studentdegreeid, studentmajorview.completed, studentmajorview.started, studentmajorview.cleared, studentmajorview.clearedate,
		studentmajorview.graduated, studentmajorview.graduatedate, studentmajorview.dropout, studentmajorview.transferin, studentmajorview.transferout,
		studentmajorview.mathplacement, studentmajorview.englishplacement,
		studentmajorview.schoolid, studentmajorview.schoolname, studentmajorview.departmentid, studentmajorview.departmentname,
		studentmajorview.majorid, studentmajorview.majorname, studentmajorview.electivecredit, studentmajorview.domajor, studentmajorview.dominor,
		studentmajorview.majoroptionid, studentmajorview.majoroptionname, studentmajorview.primarymajor,
		studentmajorview.studentmajorid, studentmajorview.major, studentmajorview.nondegree, studentmajorview.premajor,
		qstudents.org_id, qstudents.qstudentid, qstudents.quarterid, qstudents.charges as additionalcharges, 
		qstudents.approved, qstudents.probation,
		qstudents.roomnumber, qstudents.currbalance, qstudents.finaceapproval, qstudents.majorapproval,
		qstudents.departapproval, qstudents.overloadapproval, qstudents.finalised, qstudents.printed,
		qstudents.noapproval, qstudents.exam_clear, qstudents.exam_clear_date, qstudents.exam_clear_balance,
		quarters.active, quarters.closed
	FROM (studentmajorview INNER JOIN qstudents ON studentmajorview.studentdegreeid = qstudents.studentdegreeid)
		INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid;

CREATE VIEW qcourseview AS
	SELECT courseview.schoolid, courseview.schoolname, courseview.departmentid, courseview.departmentname,
		courseview.degreelevelid, courseview.degreelevelname, courseview.coursetypeid, courseview.coursetypename,
		courseview.courseid, courseview.credithours, courseview.maxcredit, courseview.iscurrent,
		courseview.nogpa, courseview.yeartaken, courseview.mathplacement, courseview.englishplacement,
		courseview.details,
		qcourses.org_id, qcourses.instructorid, qcourses.qcourseid, qcourses.classoption, qcourses.maxclass,
		qcourses.labcourse, qcourses.clinical_fee, qcourses.extracharge, 
		qcourses.approved, qcourses.attendance, qcourses.oldcourseid,
		qcourses.fullattendance, qcourses.attachement, qcourses.submit_grades, qcourses.submit_date,
		qcourses.approved_grades, qcourses.approve_date, qcourses.examsubmited, qcourses.examinable,
		qcourses.departmentchange, qcourses.registrychange, qcourses.gradesubmited, 

		instructors.majoradvisor, instructors.department_head, instructors.school_dean, instructors.pgs_dean,
		(CASE WHEN qcourses.instructorid='0' THEN qcourses.oldinstructor ELSE instructors.instructorname END) as instructorname,
		(CASE WHEN qcourses.instructorid='0' THEN qcourses.oldcoursetitle 
			WHEN qcourses.session_title is not null THEN qcourses.session_title
			ELSE courseview.coursetitle END) as coursetitle,

		quarterview.quarterid, quarterview.qstart, quarterview.qlatereg, quarterview.qlatechange, quarterview.qlastdrop,
		quarterview.qend, quarterview.active, quarterview.chalengerate, quarterview.feesline, quarterview.resline, 
		quarterview.minimal_fees, quarterview.closed, quarterview.quarter_name, quarterview.quarteryear, quarterview.quarter, 

		levellocations.levellocationid, levellocations.levellocationname
	FROM (((courseview INNER JOIN qcourses ON courseview.courseid = qcourses.courseid)
		INNER JOIN instructors ON qcourses.instructorid = instructors.instructorid)
		INNER JOIN quarterview ON qcourses.quarterid = quarterview.quarterid)
		INNER JOIN levellocations ON qcourses.levellocationid = levellocations.levellocationid;

CREATE VIEW vw_course_load AS
	SELECT qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.degreelevelid, qcourseview.degreelevelname, qcourseview.coursetypeid, qcourseview.coursetypename,
		qcourseview.courseid, qcourseview.credithours, qcourseview.maxcredit, qcourseview.iscurrent,
		qcourseview.nogpa, qcourseview.yeartaken, qcourseview.mathplacement, qcourseview.englishplacement,

		qcourseview.org_id, qcourseview.instructorid, qcourseview.qcourseid, qcourseview.classoption, qcourseview.maxclass,
		qcourseview.labcourse, qcourseview.clinical_fee, qcourseview.extracharge, 
		qcourseview.approved, qcourseview.attendance, qcourseview.oldcourseid,
		qcourseview.fullattendance, qcourseview.attachement, qcourseview.submit_grades, qcourseview.submit_date,
		qcourseview.approved_grades, qcourseview.approve_date, qcourseview.examsubmited, qcourseview.examinable,
		qcourseview.departmentchange, qcourseview.registrychange,
		qcourseview.instructorname, qcourseview.coursetitle,

		qcourseview.quarterid, qcourseview.qstart, qcourseview.qlatereg, qcourseview.qlatechange, qcourseview.qlastdrop,
		qcourseview.qend, qcourseview.active, qcourseview.chalengerate, qcourseview.feesline, qcourseview.resline, 
		qcourseview.minimal_fees, qcourseview.closed, qcourseview.quarter_name, qcourseview.quarteryear, qcourseview.quarter, 

		qcourseview.levellocationid, qcourseview.levellocationname,
		a.course_load
	FROM qcourseview INNER JOIN 
		(SELECT qcourseid, count(qgradeid) as course_load FROM qgrades WHERE (dropped = false) GROUP BY qcourseid) as a
		ON qcourseview.qcourseid = a.qcourseid;

CREATE OR REPLACE FUNCTION getqcoursestudents(integer) RETURNS bigint AS $$
	SELECT CASE WHEN count(qgradeid) is null THEN 0 ELSE count(qgradeid) END
	FROM qgrades INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid 
	WHERE (qgrades.dropped = false) AND (qstudents.finalised = true) AND (qcourseid = $1);
$$ LANGUAGE SQL;

CREATE VIEW currqcourseview AS
	SELECT qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.degreelevelid, qcourseview.degreelevelname, qcourseview.coursetypeid, qcourseview.coursetypename,
		qcourseview.org_id, qcourseview.courseid, qcourseview.credithours, qcourseview.maxcredit, qcourseview.iscurrent,
		qcourseview.nogpa, qcourseview.yeartaken, qcourseview.mathplacement, qcourseview.englishplacement,
		qcourseview.instructorid, qcourseview.quarterid, qcourseview.qcourseid, qcourseview.classoption, qcourseview.maxclass,
		qcourseview.labcourse, qcourseview.extracharge, qcourseview.approved, qcourseview.attendance, qcourseview.oldcourseid,
		qcourseview.fullattendance, qcourseview.instructorname, qcourseview.coursetitle,
		qcourseview.levellocationid, qcourseview.levellocationname
	FROM qcourseview
	WHERE (qcourseview.active = true) AND (qcourseview.approved = false);

CREATE VIEW qtimetableview AS
	SELECT assets.assetid, assets.assetname, assets.location, assets.building, assets.capacity, 
		qcourseview.qcourseid, qcourseview.courseid, qcourseview.coursetitle, qcourseview.instructorid,
		qcourseview.instructorname, qcourseview.quarterid, qcourseview.maxclass, qcourseview.classoption,
		optiontimes.optiontimeid, optiontimes.optiontimename,
		qtimetable.org_id, qtimetable.qtimetableid, qtimetable.starttime, qtimetable.endtime, qtimetable.lab,
		qtimetable.details, qtimetable.cmonday, qtimetable.ctuesday, qtimetable.cwednesday, qtimetable.cthursday,
		qtimetable.cfriday, qtimetable.csaturday, qtimetable.csunday 
	FROM ((assets INNER JOIN qtimetable ON assets.assetid = qtimetable.assetid)
		INNER JOIN qcourseview ON qtimetable.qcourseid = qcourseview.qcourseid)
		INNER JOIN optiontimes ON qtimetable.optiontimeid = optiontimes.optiontimeid
	ORDER BY qtimetable.starttime;

CREATE VIEW qetimetableview AS
	SELECT assets.assetid, assets.assetname, assets.location, assets.building, assets.capacity, 
		qcourseview.qcourseid, qcourseview.courseid, qcourseview.coursetitle, qcourseview.instructorid,
		qcourseview.instructorname, qcourseview.quarterid, qcourseview.maxclass, qcourseview.classoption,
		optiontimes.optiontimeid, optiontimes.optiontimename,
		qexamtimetable.org_id, qexamtimetable.qexamtimetableid, qexamtimetable.starttime, qexamtimetable.endtime, 
		qexamtimetable.lab, qexamtimetable.examdate, qexamtimetable.details 
	FROM ((assets INNER JOIN qexamtimetable ON assets.assetid = qexamtimetable.assetid)
		INNER JOIN qcourseview ON qexamtimetable.qcourseid = qcourseview.qcourseid)
		INNER JOIN optiontimes ON qexamtimetable.optiontimeid = optiontimes.optiontimeid
	ORDER BY qexamtimetable.examdate, qexamtimetable.starttime;

CREATE OR REPLACE FUNCTION gettimeassetcount(integer, time, time, boolean, boolean, boolean, boolean, boolean, boolean, boolean, varchar(12)) RETURNS bigint AS $$
	SELECT count(qtimetableid) FROM qtimetableview
	WHERE (assetid = $1) AND (((starttime, endtime) OVERLAPS ($2, $3))=true) 
	AND ((cmonday and $4) OR (ctuesday and $5) OR (cwednesday and $6) OR (cthursday and $7) OR (cfriday and $8) OR (csaturday and $9) OR (csunday and $10))
	AND (quarterid = $11);
$$ LANGUAGE SQL;

CREATE VIEW qassettimetableview AS
	SELECT assetid, assetname, location, building, capacity, qcourseid, courseid, coursetitle, instructorid,
		instructorname, quarterid, maxclass, classoption, optiontimeid, optiontimename,
		qtimetableid, starttime, endtime, lab, details, cmonday, ctuesday, cwednesday, cthursday,
		cfriday, csaturday, csunday,
		gettimeassetcount(assetid, starttime, endtime, cmonday, ctuesday, cwednesday, cthursday, cfriday, csaturday, csunday, quarterid) as timeassetcount 
	FROM qtimetableview
	ORDER BY assetid;

CREATE VIEW currtimetableview AS
	SELECT qtimetableview.assetid, qtimetableview.assetname, qtimetableview.location, qtimetableview.building, qtimetableview.capacity, 
		qtimetableview.qcourseid, qtimetableview.courseid, qtimetableview.coursetitle, qtimetableview.instructorid,
		qtimetableview.instructorname, qtimetableview.quarterid, qtimetableview.maxclass, qtimetableview.classoption,
		qtimetableview.optiontimeid, qtimetableview.optiontimename,
		qtimetableview.org_id, qtimetableview.qtimetableid, qtimetableview.starttime, qtimetableview.endtime, qtimetableview.lab,
		qtimetableview.details, qtimetableview.cmonday, qtimetableview.ctuesday, qtimetableview.cwednesday, qtimetableview.cthursday,
		qtimetableview.cfriday, qtimetableview.csaturday, qtimetableview.csunday
	FROM qtimetableview INNER JOIN quarters ON qtimetableview.quarterid = quarters.quarterid 
	WHERE (quarters.closed = false)
	ORDER BY qtimetableview.starttime;

CREATE VIEW qcourseitemview AS
	SELECT qcourseview.org_id, qcourseview.qcourseid, qcourseview.courseid, qcourseview.coursetitle, 
		qcourseview.instructorname, qcourseview.quarterid,
		qcourseview.classoption, qcourseitems.qcourseitemid, qcourseitems.qcourseitemname, qcourseitems.markratio,
		qcourseitems.totalmarks, qcourseitems.given, qcourseitems.deadline, qcourseitems.details
	FROM qcourseview INNER JOIN qcourseitems ON qcourseview.qcourseid = qcourseitems.qcourseid;

CREATE VIEW vw_qgrades AS
	SELECT qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.degreelevelid, qcourseview.degreelevelname, qcourseview.coursetypeid, qcourseview.coursetypename,
		qcourseview.courseid, qcourseview.credithours, qcourseview.iscurrent,
		qcourseview.nogpa, qcourseview.yeartaken, qcourseview.mathplacement as crs_mathplacement, qcourseview.englishplacement as crs_englishplacement,
		qcourseview.instructorid, qcourseview.quarterid, qcourseview.qcourseid, qcourseview.classoption, qcourseview.maxclass,
		qcourseview.labcourse, qcourseview.extracharge, qcourseview.clinical_fee,
		qcourseview.attendance as crs_attendance, qcourseview.oldcourseid,
		qcourseview.fullattendance, qcourseview.instructorname, qcourseview.coursetitle,
		qcourseview.attachement, qcourseview.examinable,
		qcourseview.submit_grades, qcourseview.submit_date, qcourseview.approved_grades, qcourseview.approve_date,
		qcourseview.departmentchange, qcourseview.registrychange,

		qgrades.org_id, qgrades.qgradeid, qgrades.qstudentid, qgrades.hours, qgrades.credit, qgrades.approved as crs_approved, qgrades.approvedate, qgrades.askdrop,
		qgrades.askdropdate, qgrades.dropped, qgrades.dropdate, qgrades.repeated, qgrades.attendance, qgrades.narrative,
		qgrades.challengecourse, qgrades.nongpacourse, qgrades.lecture_marks, qgrades.lecture_cat_mark, qgrades.lecture_gradeid,
		qgrades.request_drop, qgrades.request_drop_date, qgrades.withdraw_rate as course_withdraw_rate,
		grades.gradeid, grades.gradeweight, grades.minrange, grades.maxrange, grades.gpacount, grades.narrative as gradenarrative,
		(CASE qgrades.repeated WHEN true THEN 0 ELSE (grades.gradeweight * qgrades.credit) END) as gpa,
		(CASE WHEN ((qgrades.gradeid='W') OR (qgrades.gradeid='AW') OR (grades.gpacount = false) OR (qgrades.repeated = true) OR (qgrades.nongpacourse=true)) THEN 0 ELSE qgrades.credit END) as gpahours,
		(CASE WHEN ((qgrades.gradeid='W') OR (qgrades.gradeid='AW')) THEN qgrades.hours * qgrades.withdraw_rate  ELSE qgrades.hours END) as chargehours
	FROM (qcourseview INNER JOIN qgrades ON qcourseview.qcourseid = qgrades.qcourseid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid;

CREATE VIEW qgradeview AS
	SELECT qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.degreelevelid, qcourseview.degreelevelname, qcourseview.coursetypeid, qcourseview.coursetypename,
		qcourseview.courseid, qcourseview.credithours, qcourseview.iscurrent,
		qcourseview.nogpa, qcourseview.yeartaken, qcourseview.mathplacement as crs_mathplacement, qcourseview.englishplacement as crs_englishplacement,
		qcourseview.instructorid, qcourseview.quarterid, qcourseview.qcourseid, qcourseview.classoption, qcourseview.maxclass,
		qcourseview.labcourse, qcourseview.extracharge, qcourseview.clinical_fee,
		qcourseview.attendance as crs_attendance, qcourseview.oldcourseid,
		qcourseview.fullattendance, qcourseview.instructorname, qcourseview.coursetitle,
		qcourseview.attachement, qcourseview.examinable,
		qcourseview.submit_grades, qcourseview.submit_date, qcourseview.approved_grades, qcourseview.approve_date,
		qcourseview.departmentchange, qcourseview.registrychange,

		qgrades.org_id, qgrades.qgradeid, qgrades.qstudentid, qgrades.hours, qgrades.credit, qgrades.approved as crs_approved, qgrades.approvedate, qgrades.askdrop,
		qgrades.askdropdate, qgrades.dropped, qgrades.dropdate, qgrades.repeated, qgrades.attendance, qgrades.narrative,
		qgrades.challengecourse, qgrades.nongpacourse, qgrades.lecture_marks, qgrades.lecture_cat_mark, 
		qgrades.lecture_gradeid,
		qgrades.request_drop, qgrades.request_drop_date, qgrades.withdraw_rate as course_withdraw_rate,
		grades.gradeid, grades.gradeweight, grades.minrange, grades.maxrange, grades.gpacount, 
		grades.narrative as gradenarrative,
		(CASE qgrades.repeated WHEN true THEN 0 ELSE (grades.gradeweight * qgrades.credit) END) as gpa,
		(CASE WHEN ((qgrades.gradeid='W') OR (qgrades.gradeid='AW') OR (grades.gpacount = false) OR (qgrades.repeated = true) OR (qgrades.nongpacourse=true)) THEN 0 ELSE qgrades.credit END) as gpahours,
		(CASE WHEN ((qgrades.gradeid='W') OR (qgrades.gradeid='AW')) THEN qgrades.hours * qgrades.withdraw_rate  ELSE qgrades.hours END) as chargehours
	FROM (qcourseview INNER JOIN qgrades ON qcourseview.qcourseid = qgrades.qcourseid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid
	WHERE (qgrades.dropped = false);

CREATE VIEW studentgradeview AS
	SELECT qstudentview.religionid, qstudentview.religionname, qstudentview.denominationid, qstudentview.denominationname,
		qstudentview.schoolid, qstudentview.schoolname, qstudentview.studentid, qstudentview.studentname, qstudentview.address, qstudentview.zipcode,
		qstudentview.town, qstudentview.addresscountry, qstudentview.telno, qstudentview.email,  qstudentview.guardianname, qstudentview.gaddress,
		qstudentview.gzipcode, qstudentview.gtown, qstudentview.gaddresscountry, qstudentview.gtelno, qstudentview.gemail,
		qstudentview.accountnumber, qstudentview.Nationality, qstudentview.Nationalitycountry, qstudentview.Sex,
		qstudentview.MaritalStatus, qstudentview.birthdate, qstudentview.firstpass, qstudentview.alumnae, qstudentview.postcontacts,
		qstudentview.onprobation, qstudentview.offcampus, qstudentview.currentcontact, qstudentview.currentemail, qstudentview.currenttel,
		qstudentview.degreelevelid, qstudentview.degreelevelname,
		qstudentview.freshman, qstudentview.sophomore, qstudentview.junior, qstudentview.senior,
		qstudentview.levellocationid, qstudentview.levellocationname,
		qstudentview.sublevelid, qstudentview.sublevelname, qstudentview.specialcharges,
		qstudentview.degreeid, qstudentview.degreename,
		qstudentview.studentdegreeid, qstudentview.completed, qstudentview.started, qstudentview.cleared, qstudentview.clearedate,
		qstudentview.graduated, qstudentview.graduatedate, qstudentview.dropout, qstudentview.transferin, qstudentview.transferout,
		qstudentview.mathplacement, qstudentview.englishplacement,
		qstudentview.quarterid, qstudentview.quarteryear, qstudentview.quarter, qstudentview.qstart, qstudentview.qlatereg, qstudentview.qlatechange, qstudentview.qlastdrop,
		qstudentview.qend, qstudentview.active, qstudentview.feesline, qstudentview.resline, 
		qstudentview.residenceid, qstudentview.residencename, qstudentview.capacity, qstudentview.defaultrate,
		qstudentview.residenceoffcampus, qstudentview.residencesex, qstudentview.residencedean,
		qstudentview.qresidenceid, qstudentview.residenceoption, qstudentview.residencecharge,
		qstudentview.org_id, qstudentview.qstudentid, qstudentview.additionalcharges, qstudentview.approved, qstudentview.probation,
		qstudentview.roomnumber, qstudentview.currbalance, qstudentview.finaceapproval, qstudentview.majorapproval,
		qstudentview.departapproval, qstudentview.overloadapproval, qstudentview.finalised, qstudentview.printed,
		qstudentview.ucharge, qstudentview.lcharge, qstudentview.feescharge, qstudentview.intersession, 

		qstudentview.exam_clear, qstudentview.exam_clear_date, qstudentview.exam_clear_balance, qstudentview.exam_fees,
		qstudentview.request_withdraw, qstudentview.request_withdraw_date, qstudentview.withdraw, qstudentview.ac_withdraw,
		qstudentview.withdraw_date, qstudentview.withdraw_rate, qstudentview.currency, qstudentview.exchange_rate,

		qgradeview.schoolid as crs_schoolid, qgradeview.schoolname as crs_schoolname,
		qgradeview.departmentid as crs_departmentid, qgradeview.departmentname as crs_departmentname,
		qgradeview.degreelevelid as crs_degreelevelid, qgradeview.degreelevelname as crs_degreelevelname,
		qgradeview.coursetypeid, qgradeview.coursetypename, qgradeview.courseid, qgradeview.credithours, qgradeview.iscurrent,
		qgradeview.nogpa, qgradeview.yeartaken, qgradeview.crs_mathplacement, qgradeview.crs_englishplacement,
		qgradeview.instructorid, qgradeview.qcourseid, qgradeview.classoption, qgradeview.maxclass,
		qgradeview.labcourse, qgradeview.attendance as crs_attendance, qgradeview.oldcourseid,
		qgradeview.fullattendance, qgradeview.instructorname, qgradeview.coursetitle,
		qgradeview.qgradeid, qgradeview.hours, qgradeview.credit, qgradeview.crs_approved, qgradeview.approvedate, qgradeview.askdrop,	
		qgradeview.askdropdate, qgradeview.dropped, qgradeview.dropdate, qgradeview.repeated, qgradeview.attendance, qgradeview.narrative,
		qgradeview.gradeid, qgradeview.gradeweight, qgradeview.minrange, qgradeview.maxrange, qgradeview.gpacount, qgradeview.gradenarrative,
		qgradeview.gpa, qgradeview.gpahours, qgradeview.chargehours, qgradeview.attachement, qgradeview.lecture_marks, qgradeview.lecture_cat_mark,
		qgradeview.lecture_gradeid, qgradeview.course_withdraw_rate,
		qgradeview.submit_grades, qgradeview.submit_date, qgradeview.approved_grades, qgradeview.approve_date,
		qgradeview.departmentchange, qgradeview.registrychange,

		(CASE WHEN (qgradeview.challengecourse = true) THEN (qstudentview.chalengerate * qgradeview.chargehours * qstudentview.ucharge / 100)
			ELSE (qgradeview.chargehours * qstudentview.ucharge) END) as unitfees,

		(CASE WHEN qgradeview.examinable = true THEN qstudentview.exam_fees ELSE 0 END)  as examfee,

		qgradeview.clinical_fee,

		(CASE WHEN (qgradeview.labcourse = true) THEN qstudentview.lab_charges ELSE 0 END) as labfees,

		qgradeview.extracharge

	FROM qstudentview INNER JOIN qgradeview ON qstudentview.qstudentid = qgradeview.qstudentid;

CREATE VIEW selcourseview AS
	SELECT courses.courseid, courses.coursetitle, courses.credithours, courses.nogpa, courses.yeartaken,
		courses.mathplacement, courses.englishplacement, courses.kiswahiliplacement,
		qcourses.qcourseid, qcourses.quarterid, qcourses.classoption, qcourses.maxclass, qcourses.labcourse,
		instructors.instructorid, instructors.instructorname, getqcoursestudents(qcourses.qcourseid) as qcoursestudents,
		qgrades.qgradeid, qgrades.qstudentid, qgrades.gradeid, qgrades.hours, qgrades.credit, qgrades.approved,
		qgrades.approvedate, qgrades.askdrop, qgrades.askdropdate, qgrades.dropped,	qgrades.dropdate,
		qgrades.repeated, qgrades.withdrawdate, qgrades.attendance, qgrades.optiontimeid, qgrades.narrative
	FROM (((courses INNER JOIN qcourses ON courses.courseid = qcourses.courseid)
		INNER JOIN instructors ON qcourses.instructorid = instructors.instructorid)
		INNER JOIN qgrades ON qgrades.qcourseid = qcourses.qcourseid)
		INNER JOIN quarters ON qcourses.quarterid = quarters.quarterid
	WHERE (quarters.active = true) AND (qgrades.dropped = false);

CREATE OR REPLACE FUNCTION getcoursedone(varchar(12), varchar(12)) RETURNS float AS $$
	SELECT max(grades.gradeweight)
	FROM (((qcourses INNER JOIN qgrades ON qcourses.qcourseid = qgrades.qcourseid)
		INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid)
		INNER JOIN grades ON qgrades.gradeid = grades.gradeid)
		INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (qstudents.approved = true) AND (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW')
	AND (studentdegrees.studentid = $1) AND (qcourses.courseid = $2);		
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getcoursetransfered(varchar(12), varchar(12)) RETURNS float AS $$
	SELECT sum(transferedcredits.credithours)
	FROM transferedcredits INNER JOIN studentdegrees ON transferedcredits.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (studentdegrees.studentid = $1) AND (transferedcredits.courseid = $2);		
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getplacementpassed(int, varchar(12)) RETURNS boolean AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getprereqpassed(varchar(12), varchar(12), integer, boolean) RETURNS boolean AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getprereqpassed(varchar(12), varchar(12), integer) RETURNS boolean AS $$
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
$$ LANGUAGE plpgsql;

CREATE VIEW selectedgradeview AS
	SELECT selcourseview.courseid, selcourseview.coursetitle, selcourseview.credithours, selcourseview.nogpa, selcourseview.yeartaken,
		selcourseview.mathplacement as crs_mathplacement, selcourseview.englishplacement as crs_englishplacement,
		selcourseview.kiswahiliplacement as crs_kiswahiliplacement,
		selcourseview.qcourseid, selcourseview.quarterid, selcourseview.classoption, selcourseview.maxclass, selcourseview.labcourse,
		selcourseview.instructorid, selcourseview.instructorname, selcourseview.qcoursestudents,
		selcourseview.qgradeid, selcourseview.qstudentid, selcourseview.gradeid, selcourseview.hours, selcourseview.credit, selcourseview.approved,
		selcourseview.approvedate, selcourseview.askdrop, selcourseview.askdropdate, selcourseview.dropped,	selcourseview.dropdate,
		selcourseview.repeated, selcourseview.withdrawdate, selcourseview.attendance, selcourseview.optiontimeid, selcourseview.narrative,
		studentdegrees.studentdegreeid, studentdegrees.studentid, students.studentname, students.sex,
		studentdegrees.mathplacement, studentdegrees.englishplacement, studentdegrees.kiswahiliplacement,		 
		getprereqpassed(studentdegrees.studentid, selcourseview.courseid, studentdegrees.bulletingid,
		getplacementpassed(studentdegrees.studentdegreeid, selcourseview.courseid)) as placementpassed,   
		getprereqpassed(studentdegrees.studentid, selcourseview.courseid, studentdegrees.bulletingid) as prereqpassed,
		qstudents.org_id
	FROM ((selcourseview INNER JOIN qstudents ON selcourseview.qstudentid = qstudents.qstudentid)
		INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid)
		INNER JOIN students ON studentdegrees.studentid = students.studentid;

CREATE VIEW studenttimetableview AS
	SELECT assets.assetid, assets.assetname, assets.location, assets.building, assets.capacity, 
		selectedgradeview.courseid, selectedgradeview.coursetitle, selectedgradeview.credithours, selectedgradeview.nogpa, selectedgradeview.yeartaken,
		selectedgradeview.qcourseid, selectedgradeview.quarterid, selectedgradeview.classoption, selectedgradeview.maxclass, selectedgradeview.labcourse,
		selectedgradeview.instructorid, selectedgradeview.instructorname, selectedgradeview.studentdegreeid, selectedgradeview.studentid,
		selectedgradeview.qgradeid, selectedgradeview.qstudentid, selectedgradeview.gradeid, selectedgradeview.hours, selectedgradeview.credit, selectedgradeview.approved,
		selectedgradeview.approvedate, selectedgradeview.askdrop, selectedgradeview.askdropdate, selectedgradeview.dropped,	selectedgradeview.dropdate,
		selectedgradeview.repeated, selectedgradeview.withdrawdate, selectedgradeview.attendance, selectedgradeview.narrative,
		qtimetable.org_id, qtimetable.qtimetableid, qtimetable.starttime, qtimetable.endtime, qtimetable.lab,
		qtimetable.details, qtimetable.cmonday, qtimetable.ctuesday, qtimetable.cwednesday, qtimetable.cthursday,
		qtimetable.cfriday, qtimetable.csaturday, qtimetable.csunday,
		optiontimes.optiontimeid, optiontimes.optiontimename
	FROM (assets INNER JOIN (qtimetable INNER JOIN optiontimes ON qtimetable.optiontimeid = optiontimes.optiontimeid) ON assets.assetid = qtimetable.assetid)
		INNER JOIN selectedgradeview ON (qtimetable.qcourseid = selectedgradeview.qcourseid AND qtimetable.optiontimeid =  selectedgradeview.optiontimeid)
	ORDER BY qtimetable.starttime;

CREATE VIEW vwqexamtimetable AS
	SELECT qcourseview.courseid, qcourseview.coursetitle, 
		qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.instructorid, qcourseview.instructorname,
		qexamtimetable.org_id, qexamtimetable.qexamtimetableid, qexamtimetable.examdate, qexamtimetable.starttime, 
		qexamtimetable.endtime, qexamtimetable.lab,
		quarters.quarterid, quarters.active, quarters.closed
	FROM (qcourseview INNER JOIN qexamtimetable ON qcourseview.qcourseid = qexamtimetable.qcourseid)
		INNER JOIN quarters ON qcourseview.quarterid = quarters.quarterid;

CREATE VIEW qexamtimetableview AS
	SELECT selcourseview.courseid, selcourseview.coursetitle, selcourseview.credithours, selcourseview.nogpa, selcourseview.yeartaken,
		selcourseview.mathplacement as crs_mathplacement, selcourseview.englishplacement as crs_englishplacement,
		selcourseview.kiswahiliplacement as crs_kiswahiliplacement,
		selcourseview.qcourseid, selcourseview.quarterid, selcourseview.classoption, selcourseview.maxclass, selcourseview.labcourse,
		selcourseview.instructorid, selcourseview.instructorname, selcourseview.qcoursestudents,
		selcourseview.qgradeid, selcourseview.qstudentid, selcourseview.gradeid, selcourseview.hours, selcourseview.credit, selcourseview.approved,
		selcourseview.approvedate, selcourseview.askdrop, selcourseview.askdropdate, selcourseview.dropped,	selcourseview.dropdate,
		selcourseview.repeated, selcourseview.withdrawdate, selcourseview.attendance, selcourseview.optiontimeid, selcourseview.narrative,
		studentdegrees.studentdegreeid, studentdegrees.studentid, students.studentname, students.sex,
		studentdegrees.mathplacement, studentdegrees.englishplacement, studentdegrees.kiswahiliplacement,
		qexamtimetable.org_id, qexamtimetable.qexamtimetableid, qexamtimetable.examdate, qexamtimetable.starttime, 
		qexamtimetable.endtime, qexamtimetable.lab
	FROM (((selcourseview INNER JOIN qstudents ON selcourseview.qstudentid = qstudents.qstudentid)
		INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid)
		INNER JOIN students ON studentdegrees.studentid = students.studentid)
		INNER JOIN qexamtimetable ON (qexamtimetable.qcourseid = selcourseview.qcourseid)
	WHERE (qstudents.approved = true) AND (selcourseview.gradeid <> 'W');

CREATE VIEW qcoursemarkview AS
	SELECT studentgradeview.schoolid, studentgradeview.schoolname, studentgradeview.studentid, studentgradeview.studentname, studentgradeview.email,
		studentgradeview.degreelevelid, studentgradeview.degreelevelname, studentgradeview.sublevelid, studentgradeview.sublevelname, 
		studentgradeview.degreeid, studentgradeview.degreename, studentgradeview.studentdegreeid, studentgradeview.completed, studentgradeview.started,
		studentgradeview.cleared, studentgradeview.clearedate, studentgradeview.quarterid,
		studentgradeview.fullattendance, studentgradeview.instructorname, studentgradeview.coursetitle, studentgradeview.classoption,
		studentgradeview.qgradeid, studentgradeview.hours, studentgradeview.credit, studentgradeview.crs_approved,
		studentgradeview.dropped, studentgradeview.gradeid, studentgradeview.gradeweight, studentgradeview.minrange,
		studentgradeview.maxrange, studentgradeview.gpacount,
		studentgradeview.submit_grades, studentgradeview.submit_date, studentgradeview.approved_grades, studentgradeview.approve_date,
		studentgradeview.departmentchange, studentgradeview.registrychange,
		qcoursemarks.qcoursemarkid, qcoursemarks.approved, qcoursemarks.submited, qcoursemarks.markdate, qcoursemarks.marks,
		qcoursemarks.details,
		qcourseitems.qcourseitemid, qcourseitems.qcourseitemname, qcourseitems.markratio, qcourseitems.totalmarks,
		qcourseitems.given, qcourseitems.deadline, qcourseitems.details as itemdetails
	FROM (studentgradeview INNER JOIN qcoursemarks ON studentgradeview.qgradeid = qcoursemarks.qgradeid)
		INNER JOIN qcourseitems ON qcoursemarks.qcourseitemid =  qcourseitems.qcourseitemid;

CREATE VIEW studentquarterview AS
	SELECT studentgradeview.org_id, studentgradeview.religionid, studentgradeview.religionname, studentgradeview.denominationid, studentgradeview.denominationname,
		studentgradeview.schoolid, studentgradeview.schoolname, studentgradeview.studentid, studentgradeview.studentname, studentgradeview.address, studentgradeview.zipcode,
		studentgradeview.town, studentgradeview.addresscountry, studentgradeview.telno, studentgradeview.email,  studentgradeview.guardianname, studentgradeview.gaddress,
		studentgradeview.gzipcode, studentgradeview.gtown, studentgradeview.gaddresscountry, studentgradeview.gtelno, studentgradeview.gemail,
		studentgradeview.accountnumber, studentgradeview.Nationality, studentgradeview.Nationalitycountry, studentgradeview.Sex,
		studentgradeview.MaritalStatus, studentgradeview.birthdate, studentgradeview.firstpass, studentgradeview.alumnae, studentgradeview.postcontacts,
		studentgradeview.onprobation, studentgradeview.offcampus, studentgradeview.currentcontact, studentgradeview.currentemail, studentgradeview.currenttel,
		studentgradeview.degreelevelid, studentgradeview.degreelevelname,
		studentgradeview.freshman, studentgradeview.sophomore, studentgradeview.junior, studentgradeview.senior,
		studentgradeview.levellocationid, studentgradeview.levellocationname,
		studentgradeview.sublevelid, studentgradeview.sublevelname, studentgradeview.specialcharges,
		studentgradeview.degreeid, studentgradeview.degreename,
		studentgradeview.studentdegreeid, studentgradeview.completed, studentgradeview.started, studentgradeview.cleared, studentgradeview.clearedate,
		studentgradeview.graduated, studentgradeview.graduatedate, studentgradeview.dropout, studentgradeview.transferin, studentgradeview.transferout,
		studentgradeview.mathplacement, studentgradeview.englishplacement,
		studentgradeview.quarterid, studentgradeview.quarteryear, studentgradeview.quarter, studentgradeview.qstart, studentgradeview.qlatereg, studentgradeview.qlatechange, studentgradeview.qlastdrop,
		studentgradeview.qend, studentgradeview.active, studentgradeview.feesline, studentgradeview.resline, 
		studentgradeview.residenceid, studentgradeview.residencename, studentgradeview.capacity, studentgradeview.defaultrate,
		studentgradeview.residenceoffcampus, studentgradeview.residencesex, studentgradeview.residencedean,
		studentgradeview.qresidenceid, studentgradeview.residenceoption,
		studentgradeview.qstudentid, studentgradeview.approved, studentgradeview.probation,
		studentgradeview.roomnumber, studentgradeview.finaceapproval, studentgradeview.majorapproval,
		studentgradeview.departapproval, studentgradeview.overloadapproval, studentgradeview.finalised, studentgradeview.printed,
		studentgradeview.intersession, studentgradeview.ucharge, studentgradeview.lcharge, studentgradeview.currbalance, studentgradeview.additionalcharges,

		studentgradeview.exam_clear, studentgradeview.exam_clear_date, studentgradeview.exam_clear_balance, studentgradeview.exam_fees,
		studentgradeview.request_withdraw, studentgradeview.request_withdraw_date, studentgradeview.withdraw, studentgradeview.ac_withdraw,
		studentgradeview.withdraw_date, studentgradeview.withdraw_rate, studentgradeview.currency, studentgradeview.exchange_rate,

		(CASE sum(studentgradeview.gpahours) WHEN 0 THEN 0 ELSE (sum(studentgradeview.gpa)/sum(studentgradeview.gpahours)) END) as gpa,

		sum(studentgradeview.gpahours) as credit, sum(studentgradeview.chargehours) as hours, 
		bool_and(studentgradeview.attachement) as onattachment,

		(CASE bool_and(studentgradeview.attachement) WHEN true THEN 0 ELSE studentgradeview.feescharge END) as feescharge, 

		sum(studentgradeview.unitfees) as unitcharge, sum(studentgradeview.labfees) as labcharge, sum(studentgradeview.clinical_fee) as clinical_charge,
		sum(studentgradeview.examfee) as examfee, sum(studentgradeview.extracharge) as courseextracharge,

		studentgradeview.residencecharge, 

		((CASE bool_and(studentgradeview.attachement) WHEN true THEN 0 ELSE studentgradeview.feescharge END) 
			+ sum(studentgradeview.unitfees) + sum(studentgradeview.examfee) + sum(studentgradeview.labfees) 
			+ sum(studentgradeview.clinical_fee) + sum(studentgradeview.extracharge) 
			+ studentgradeview.residencecharge + studentgradeview.additionalcharges) as totalfees,

		(studentgradeview.currbalance
			+ ((CASE bool_and(studentgradeview.attachement) WHEN true THEN 0 ELSE studentgradeview.feescharge END) 
			+ sum(studentgradeview.unitfees) + sum(studentgradeview.examfee) + sum(studentgradeview.labfees) 
			+ sum(studentgradeview.clinical_fee) + sum(studentgradeview.extracharge) 
			+ studentgradeview.residencecharge + studentgradeview.additionalcharges)) as finalbalance

	FROM studentgradeview
	WHERE (studentgradeview.gradeid <> 'W') AND (studentgradeview.gradeid <> 'AW')
	GROUP BY studentgradeview.org_id, studentgradeview.religionid, studentgradeview.religionname, studentgradeview.denominationid, studentgradeview.denominationname,
		studentgradeview.schoolid, studentgradeview.schoolname, studentgradeview.studentid, studentgradeview.studentname, studentgradeview.address, studentgradeview.zipcode,
		studentgradeview.town, studentgradeview.addresscountry, studentgradeview.telno, studentgradeview.email,  studentgradeview.guardianname, studentgradeview.gaddress,
		studentgradeview.gzipcode, studentgradeview.gtown, studentgradeview.gaddresscountry, studentgradeview.gtelno, studentgradeview.gemail,
		studentgradeview.accountnumber, studentgradeview.Nationality, studentgradeview.Nationalitycountry, studentgradeview.Sex,
		studentgradeview.MaritalStatus, studentgradeview.birthdate, studentgradeview.firstpass, studentgradeview.alumnae, studentgradeview.postcontacts,
		studentgradeview.onprobation, studentgradeview.offcampus, studentgradeview.currentcontact, studentgradeview.currentemail, studentgradeview.currenttel,
		studentgradeview.degreelevelid, studentgradeview.degreelevelname,
		studentgradeview.freshman, studentgradeview.sophomore, studentgradeview.junior, studentgradeview.senior,
		studentgradeview.levellocationid, studentgradeview.levellocationname,
		studentgradeview.sublevelid, studentgradeview.sublevelname, studentgradeview.specialcharges,
		studentgradeview.degreeid, studentgradeview.degreename,
		studentgradeview.studentdegreeid, studentgradeview.completed, studentgradeview.started, studentgradeview.cleared, studentgradeview.clearedate,
		studentgradeview.graduated, studentgradeview.graduatedate, studentgradeview.dropout, studentgradeview.transferin, studentgradeview.transferout,
		studentgradeview.mathplacement, studentgradeview.englishplacement,
		studentgradeview.quarterid, studentgradeview.quarteryear, studentgradeview.quarter, studentgradeview.qstart, studentgradeview.qlatereg, studentgradeview.qlatechange, studentgradeview.qlastdrop,
		studentgradeview.qend, studentgradeview.active, studentgradeview.feesline, studentgradeview.resline, 
		studentgradeview.residenceid, studentgradeview.residencename, studentgradeview.capacity, studentgradeview.defaultrate,
		studentgradeview.residenceoffcampus, studentgradeview.residencesex, studentgradeview.residencedean,
		studentgradeview.qresidenceid, studentgradeview.residenceoption, 
		studentgradeview.qstudentid, studentgradeview.approved, studentgradeview.probation,
		studentgradeview.roomnumber, studentgradeview.finaceapproval, studentgradeview.majorapproval,
		studentgradeview.departapproval, studentgradeview.overloadapproval, studentgradeview.finalised, studentgradeview.printed,
		studentgradeview.intersession,
		studentgradeview.ucharge, studentgradeview.lcharge, studentgradeview.currbalance, studentgradeview.feescharge, studentgradeview.residencecharge, studentgradeview.additionalcharges,
		studentgradeview.exam_clear, studentgradeview.exam_clear_date, studentgradeview.exam_clear_balance, studentgradeview.exam_fees,
		studentgradeview.request_withdraw, studentgradeview.request_withdraw_date, studentgradeview.withdraw, studentgradeview.ac_withdraw,
		studentgradeview.withdraw_date, studentgradeview.withdraw_rate, studentgradeview.currency, studentgradeview.exchange_rate;

CREATE VIEW courseoutline (
	orderid,
	studentid,
	studentdegreeid,
	degreeid,
	description,
	courseid,
	coursetitle,
	minor,
	elective,
	credithours,
	nogpa,
	gradeid,
	gradeweight
) AS
	(SELECT 1, studentdegrees.studentid, studentdegrees.studentdegreeid, studentdegrees.degreeid, majors.majorname, majorcontentview.courseid,
		majorcontentview.coursetitle, majorcontentview.minor, majorcontentview.elective, majorcontentview.credithours,
		majorcontentview.nogpa, majorcontentview.gradeid, grades.gradeweight
	FROM (((majors INNER JOIN majorcontentview ON majors.majorid = majorcontentview.majorid)
		INNER JOIN studentmajors ON majorcontentview.majorid = studentmajors.majorid)
		INNER JOIN studentdegrees ON (studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majorcontentview.bulletingid = studentdegrees.bulletingid))
		INNER JOIN grades ON majorcontentview.gradeid = grades.gradeid
	WHERE ((not studentmajors.premajor and majorcontentview.premajor)=false) AND ((not studentmajors.nondegree and majorcontentview.prerequisite)=false)
		and (studentdegrees.completed=false) and (studentdegrees.dropout=false))
	UNION
	(SELECT 2, studentdegrees.studentid, studentdegrees.studentdegreeid, studentdegrees.degreeid, majoroptions.majoroptionname, majoroptcontentview.courseid,
		majoroptcontentview.coursetitle, majoroptcontentview.minor, majoroptcontentview.elective, majoroptcontentview.credithours,
		majoroptcontentview.nogpa, majoroptcontentview.gradeid, grades.gradeweight
	FROM (((majoroptions INNER JOIN majoroptcontentview ON majoroptions.majoroptionid = majoroptcontentview.majoroptionid)
		INNER JOIN studentmajors ON majoroptcontentview.majoroptionid = studentmajors.majoroptionid)
		INNER JOIN studentdegrees ON (studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majoroptcontentview.bulletingid = studentdegrees.bulletingid))
		INNER JOIN grades ON majoroptcontentview.gradeid = grades.gradeid
	WHERE ((not studentmajors.premajor and majoroptcontentview.premajor)=false) AND ((not studentmajors.nondegree and majoroptcontentview.prerequisite)=false)
		and (studentdegrees.completed=false) and (studentdegrees.dropout=false));

CREATE VIEW corecourseoutline AS 
	(SELECT 1 AS orderid, studentdegrees.studentid, studentdegrees.studentdegreeid, studentdegrees.degreeid, 
		majors.majorname AS description, majorcontentview.contenttypeid, majorcontentview.contenttypename,
		majorcontentview.courseid, majorcontentview.coursetitle, majorcontentview.minor, 
		majorcontentview.elective, majorcontentview.credithours, majorcontentview.nogpa, majorcontentview.gradeid, 
		grades.gradeweight
	FROM majors
		INNER JOIN majorcontentview ON majors.majorid = majorcontentview.majorid
		INNER JOIN studentmajors ON majorcontentview.majorid = studentmajors.majorid
		INNER JOIN studentdegrees ON (studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majorcontentview.bulletingid = studentdegrees.bulletingid)
		INNER JOIN grades ON majorcontentview.gradeid = grades.gradeid
		WHERE (studentmajors.major = true) AND ((NOT studentmajors.premajor AND majorcontentview.premajor) = false) AND ((NOT studentmajors.nondegree AND majorcontentview.prerequisite) = false) AND (studentdegrees.dropout = false))
	UNION 
	(SELECT 2 AS orderid, studentdegrees.studentid, studentdegrees.studentdegreeid, studentdegrees.degreeid, 
		majoroptions.majoroptionname AS description, majoroptcontentview.contenttypeid, majoroptcontentview.contenttypename,
		majoroptcontentview.courseid, majoroptcontentview.coursetitle, 
		majoroptcontentview.minor, majoroptcontentview.elective, majoroptcontentview.credithours, 
		majoroptcontentview.nogpa, majoroptcontentview.gradeid, grades.gradeweight
	FROM majoroptions
		INNER JOIN majoroptcontentview ON majoroptions.majoroptionid = majoroptcontentview.majoroptionid
		INNER JOIN studentmajors ON majoroptcontentview.majoroptionid = studentmajors.majoroptionid
		INNER JOIN studentdegrees ON (studentmajors.studentdegreeid = studentdegrees.studentdegreeid) AND (majoroptcontentview.bulletingid = studentdegrees.bulletingid)
		INNER JOIN grades ON majoroptcontentview.gradeid = grades.gradeid
	WHERE (studentmajors.major = true) AND (NOT studentmajors.premajor AND majoroptcontentview.premajor) = false AND (NOT studentmajors.nondegree AND majoroptcontentview.prerequisite) = false AND (studentdegrees.dropout = false));

CREATE VIEW coursechecklist AS
	SELECT DISTINCT courseoutline.orderid, courseoutline.studentid, courseoutline.studentdegreeid, courseoutline.degreeid, courseoutline.description, courseoutline.courseid,
		courseoutline.coursetitle, courseoutline.minor, courseoutline.elective, courseoutline.credithours, courseoutline.nogpa, courseoutline.gradeid,
		courseoutline.gradeweight, getcoursedone(courseoutline.studentid, courseoutline.courseid) as courseweight,
		(CASE WHEN (getcoursedone(courseoutline.studentid, courseoutline.courseid) >= courseoutline.gradeweight) THEN true ELSE false END) as coursepased,
		getprereqpassed(courseoutline.studentid, courseoutline.courseid, courseoutline.studentdegreeid) as prereqpassed
	FROM courseoutline;

CREATE VIEW studentchecklist AS
	SELECT coursechecklist.orderid, coursechecklist.studentid, coursechecklist.studentdegreeid, coursechecklist.degreeid, coursechecklist.description, coursechecklist.courseid,
		coursechecklist.coursetitle, coursechecklist.minor, coursechecklist.elective, coursechecklist.credithours, coursechecklist.nogpa, coursechecklist.gradeid,
		coursechecklist.courseweight, coursechecklist.coursepased, coursechecklist.prereqpassed,
		students.studentname
	FROM coursechecklist INNER JOIN students ON coursechecklist.studentid = students.studentid;

CREATE VIEW qcoursecheckpass AS
	SELECT coursechecklist.orderid, coursechecklist.studentid, coursechecklist.studentdegreeid, coursechecklist.degreeid, coursechecklist.description,
		coursechecklist.minor, coursechecklist.elective, coursechecklist.gradeid,
		coursechecklist.gradeweight, coursechecklist.courseweight, coursechecklist.coursepased, coursechecklist.prereqpassed,
		qcourseview.org_id, qcourseview.schoolid, qcourseview.schoolname, qcourseview.departmentid, qcourseview.departmentname,
		qcourseview.degreelevelid, qcourseview.degreelevelname, qcourseview.coursetypeid, qcourseview.coursetypename,
		qcourseview.courseid, qcourseview.credithours, qcourseview.maxcredit, qcourseview.iscurrent,
		qcourseview.nogpa, qcourseview.yeartaken, qcourseview.mathplacement, qcourseview.englishplacement,
		qcourseview.instructorid, qcourseview.quarterid, qcourseview.qcourseid, qcourseview.classoption, qcourseview.maxclass,
		qcourseview.labcourse, qcourseview.extracharge, qcourseview.approved, qcourseview.attendance, qcourseview.oldcourseid,
		qcourseview.fullattendance, qcourseview.instructorname, qcourseview.coursetitle,
		qcourseview.levellocationid, qcourseview.levellocationname
	FROM coursechecklist INNER JOIN qcourseview ON coursechecklist.courseid = qcourseview.courseid
	WHERE (qcourseview.active = true) AND (qcourseview.approved = false) 
		AND (coursechecklist.coursepased = false) AND (coursechecklist.prereqpassed = true);

CREATE VIEW coregradeview AS 
	SELECT studentgradeview.schoolid, studentgradeview.schoolname, studentgradeview.studentid, studentgradeview.studentname, studentgradeview.sex,
		studentgradeview.degreeid, studentgradeview.degreename, studentgradeview.studentdegreeid, studentgradeview.quarterid, studentgradeview.quarteryear,
		studentgradeview.quarter, studentgradeview.coursetypeid, studentgradeview.coursetypename, studentgradeview.courseid, studentgradeview.nogpa,
		studentgradeview.instructorid, studentgradeview.qcourseid, studentgradeview.classoption, studentgradeview.labcourse, studentgradeview.instructorname,
		studentgradeview.coursetitle, studentgradeview.qgradeid, studentgradeview.hours, studentgradeview.credit, studentgradeview.gpa, studentgradeview.gradeid,
		studentgradeview.repeated, studentgradeview.gpahours, studentgradeview.chargehours, 
		corecourseoutline.description, corecourseoutline.minor, corecourseoutline.elective,
		corecourseoutline.contenttypeid, corecourseoutline.contenttypename
	FROM corecourseoutline INNER JOIN studentgradeview ON (corecourseoutline.studentdegreeid = studentgradeview.studentdegreeid) AND (corecourseoutline.courseid = studentgradeview.courseid)
	WHERE (studentgradeview.approved = true) AND (corecourseoutline.minor = false);

CREATE VIEW majorgradeview AS
	SELECT studentdegreeview.studentid, studentdegreeview.studentname, studentdegreeview.sex, studentdegreeview.degreelevelid, studentdegreeview.degreelevelname, 
		studentdegreeview.levellocationid, studentdegreeview.levellocationname, studentdegreeview.sublevelid, studentdegreeview.sublevelname, 
		studentdegreeview.degreeid, studentdegreeview.degreename, studentdegreeview.studentdegreeid, 
		studentmajors.studentmajorid, studentmajors.major, studentmajors.nondegree, studentmajors.premajor, 
		majorcontentview.departmentid, majorcontentview.departmentname, majorcontentview.majorid, majorcontentview.majorname, 
		majorcontentview.courseid, majorcontentview.coursetitle, majorcontentview.contenttypeid, majorcontentview.contenttypename,
		majorcontentview.elective, majorcontentview.prerequisite, majorcontentview.majorcontentid,
		majorcontentview.premajor as premajoritem, majorcontentview.minor, majorcontentview.gradeid as mingrade,
		qgradeview.quarterid, qgradeview.qgradeid, qgradeview.qstudentid, qgradeview.gradeid, qgradeview.gpahours, qgradeview.gpa,
		qgradeview.instructorname
	FROM (((studentdegreeview INNER JOIN studentmajors ON studentdegreeview.studentdegreeid = studentmajors.studentdegreeid)
		INNER JOIN majorcontentview ON majorcontentview.majorid = studentmajors.majorid)
		INNER JOIN qstudents ON qstudents.studentdegreeid = studentdegreeview.studentdegreeid)
		INNER JOIN qgradeview ON (qgradeview.courseid = majorcontentview.courseid) and (qgradeview.qstudentid =   qstudents.qstudentid)
	WHERE ((not studentmajors.premajor and majorcontentview.premajor)=false) AND ((not studentmajors.nondegree and majorcontentview.prerequisite)=false);

CREATE OR REPLACE FUNCTION getcurrsabathclass(integer) RETURNS bigint AS $$
    SELECT count(qstudents.qstudentid)
	FROM qstudents INNER JOIN quarters ON qstudents.quarterid = quarters.quarterid  
	WHERE (quarters.active = true) AND (sabathclassid = $1);
$$ LANGUAGE SQL;

CREATE VIEW sabathclassview AS
	SELECT sabathclasses.org_id, sabathclasses.sabathclassid, sabathclasses.sabathclassoption, sabathclasses.instructor, 
		sabathclasses.venue, sabathclasses.capacity, getcurrsabathclass(sabathclasses.sabathclassid) as classcount,
		(sabathclasses.capacity - getcurrsabathclass(sabathclasses.sabathclassid)) as classbalance
	FROM sabathclasses
	WHERE sabathclasses.iscurrent = true;

CREATE VIEW sabathclassavail AS
	SELECT sabathclassview.org_id, sabathclassview.sabathclassid, sabathclassview.sabathclassoption, 
		sabathclassview.instructor, sabathclassview.venue, 
	sabathclassview.capacity, sabathclassview.classcount, sabathclassview.classbalance
	FROM sabathclassview
	WHERE (sabathclassview.classbalance>0);

CREATE OR REPLACE FUNCTION getbankstudentid(varchar(240)) RETURNS varchar(12) AS $$
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
$$ LANGUAGE plpgsql;	

CREATE VIEW gradecountview AS
	SELECT qstudents.studentdegreeid,  qcourses.courseid, count(qcourses.qcourseid) as coursecount
	FROM (qgrades INNER JOIN (qcourses INNER JOIN courses ON qcourses.courseid = courses.courseid) ON qgrades.qcourseid = qcourses.qcourseid)
		INNER JOIN qstudents ON qgrades.qstudentid = qstudents.qstudentid
	WHERE (qgrades.gradeid <> 'W') AND (qgrades.gradeid <> 'AW') AND (qgrades.gradeid <> 'NG') AND (qgrades.dropped = false)
		AND (repeated = false) AND (qstudents.approved = true) AND (courses.norepeats = false)
	GROUP BY qstudents.studentdegreeid,  qcourses.courseid;

CREATE VIEW currentresidenceview AS
	SELECT residences.residenceid, residences.residencename, residences.capacity, residences.defaultrate,
		residences.offcampus, residences.Sex, residences.residencedean,
		qresidences.qresidenceid, qresidences.quarterid, qresidences.residenceoption, qresidences.charges, 
		qresidences.details, qresidences.org_id,
		students.studentid, students.studentname
	FROM ((residences INNER JOIN qresidences ON residences.residenceid = qresidences.residenceid)
	INNER JOIN quarterview ON qresidences.quarterid = quarterview.quarterid)
	INNER JOIN students ON ((residences.Sex = students.Sex) OR (residences.Sex='N')) 
		AND (residences.offcampus = students.offcampus) 
	WHERE (quarterview.active = true);

CREATE OR REPLACE FUNCTION getfirstquarterid(varchar(12)) RETURNS varchar(12) AS $$
	SELECT min(quarterid) 
	FROM qstudents INNER JOIN studentdegrees ON qstudents.studentdegreeid = studentdegrees.studentdegreeid
	WHERE (studentid = $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION getfirstquarterid(integer) RETURNS varchar(12) AS $$
	SELECT min(quarterid)
	FROM qstudents
	WHERE (studentdegreeid = $1);
$$ LANGUAGE SQL;

CREATE VIEW studentfirstquarterview AS
	SELECT students.studentid, students.studentname, students.Nationality, students.Sex, students.MaritalStatus, 
		studentdegrees.studentdegreeid, studentdegrees.completed, studentdegrees.started, studentdegrees.graduated,
		degrees.degreeid, degrees.degreename, getfirstquarterid(students.studentid) as firstquarterid,
		substring(getfirstquarterid(studentdegrees.studentdegreeid) from 1 for 9) as firstyear,
		substring(getfirstquarterid(studentdegrees.studentdegreeid) from 11 for 1) as firstquarter
	FROM (students INNER JOIN studentdegrees ON students.studentid = studentdegrees.studentid)
		INNER JOIN degrees ON studentdegrees.degreeid = degrees.degreeid;

CREATE VIEW vwdualcourselevels AS
	SELECT studentid, studentname, studentdegreeid, degreename, quarterid, crs_degreelevelid, crs_degreelevelname
	FROM studentgradeview
	GROUP BY studentid, studentname, studentdegreeid, degreename, quarterid, crs_degreelevelid, crs_degreelevelname;

CREATE VIEW studentmarkview AS
	SELECT marks.markid, marks.grade, marks.markweight, registrations.existingid,
		getfirstquarterid(registrations.existingid) as firstquarter,
		students.studentname
	FROM (registrations INNER JOIN marks ON registrations.markid = marks.markid)
		INNER JOIN students ON registrations.existingid = students.studentid;
