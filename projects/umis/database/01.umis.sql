--- Table listing all continents
CREATE TABLE continents (
	continentid		char(2) primary key,
	continentname	varchar(120) unique
);

--- Table listing all countries 
CREATE TABLE countrys (
	countryid		char(2) primary key,
	continentid		char(2) references continents,
	countryname 	varchar(120) unique
);
CREATE INDEX countrys_continentid ON countrys (continentid);

-- Define all religions
CREATE TABLE religions (
	religionid			varchar(12) primary key,
	religionname		varchar(50),
	details				text
);

-- Define the denominations it links religion
CREATE TABLE denominations (
	denominationid		varchar(12) primary key,
	religionid			varchar(12) not null references religions,
	denominationname	varchar(50) not null unique,
	details				text
);
CREATE INDEX denominations_religionid ON denominations (religionid);

--- Define all schools
CREATE TABLE schools (
	schoolid			varchar(12) primary key,
	schoolname			varchar(50) not null,
	philosopy			text,
	vision				text,
	mission				text,
	objectives			text,
	details				text
);

--- Defines departments linked to schools
CREATE TABLE departments (
	departmentid		varchar(12) primary key,
	schoolid			varchar(12) not null references schools,
	departmentname		varchar(120) not null unique,
	philosopy			text,
	vision				text,
	mission				text,
	objectives			text,
	exposures			text,
	oppotunities		text,
	details				text
);
CREATE INDEX departments_schoolid ON departments (schoolid);

--- Define all grades
CREATE TABLE grades (
	gradeid				varchar(2) primary key,
	gradeweight			float default 0 not null,
	minrange			integer,
	maxrange			integer,
	gpacount			boolean default true not null,
	narrative			varchar(240),
	details				text
);

--- Define marks and marks weight used in high school
CREATE TABLE marks (
	markid				integer primary key,
	grade				varchar(2) not null,
	markweight			integer not null default 0,
	narrative			varchar(240)
);

--- Define the subjects used in high school
CREATE TABLE subjects (
	subjectid			integer primary key,
	subjectname			varchar(25) not null,
	narrative			varchar(240)
);

--- Define the degree leves like pre-university, Undergradate, masters, doctrate
CREATE TABLE degreelevels (
	degreelevelid		varchar(12) primary key,
	degreelevelname		varchar(50) not null unique,
	freshman			integer not null default 46,
	sophomore			integer not null default 94,
	junior				integer not null default 142,
	senior				integer not null default 190,
	details				text
);

--- Define all campuses for the university
CREATE TABLE levellocations (
	levellocationid		serial primary key,
	org_id				integer references orgs,
	levellocationname	varchar(50) not null unique,
	details				text
);

--- Define divisions of the degree level on location {nairobi, eldoret} and specialisations like nursing
CREATE TABLE sublevels (
	sublevelid			varchar(12) primary key,
	markid				integer references marks,
	degreelevelid		varchar(12) not null references degreelevels,
	levellocationid		integer not null references levellocations,
	org_id				integer references orgs,
	sublevelname		varchar(50) not null unique,

	unit_charge			float not null default 2500,
	lab_charges			float not null default 2000,
	exam_fees			float not null default 500,
	general_fees		float not null default 7500,

	no_sabath_class		boolean not null default true,

	specialcharges		boolean not null default false,
	details				text
);
CREATE INDEX sublevels_markid ON sublevels (markid);
CREATE INDEX sublevels_degreelevelid ON sublevels (degreelevelid);
CREATE INDEX sublevels_levellocationid ON sublevels (levellocationid);

--- Define the degrees like B.SC, B.TECH, B.ED
CREATE TABLE degrees (
	degreeid			varchar(12) primary key,
	degreelevelid		varchar(12) not null references degreelevels,
	degreename			varchar(50) not null unique,
	details				text
);

-- Define all residences
CREATE TABLE residences (
	residenceid			varchar(12) primary key,
	levellocationid		integer default 1 not null references levellocations,
	org_id				integer references orgs,
	residencename		varchar(50) not null unique,
	capacity			integer default 120 not null,
	roomsize			integer default 4 not null,
	defaultrate			float default 0 not null,
	offcampus			boolean not null default false,
	Sex					varchar(1),
	residencedean		varchar(50),
	details				text
);

-- Define all rooms used for study and labs
CREATE TABLE assets (
	assetid				serial primary key,
	org_id				integer references orgs,
	assetname			varchar(50) not null unique,
	building			varchar(50),
	location			varchar(50),
	capacity			integer not null,
	details				text
);

--- Define all instructors
CREATE TABLE instructors (
	instructorid		varchar(12) primary key,
	departmentid		varchar(12) not null references departments,
	org_id				integer references orgs,
	instructorname		varchar(50) not null unique,
	majoradvisor		boolean default false not null,
	department_head		boolean default false not null,
	school_dean			boolean default false not null,
	pgs_dean			boolean default false not null,

	post_office_box			varchar(50),
	postal_code				varchar(12),
	premises				varchar(120),
	street					varchar(120),
	town					varchar(50),
	sys_country_id			char(2) references sys_countrys,
	phone_number			varchar(150),
	mobile					varchar(150),
	email					varchar(120),

	instructorpass		varchar(32) not null default md5('enter'),
	firstpass			varchar(32) not null default 'enter',
	details				text
);
CREATE INDEX instructors_departmentid ON instructors (departmentid);

--- Define all sabath classes
CREATE TABLE sabathclasses (
	sabathclassid		serial primary key,
	org_id				integer references orgs,
	sabathclassoption	varchar(50) not null unique,
	instructor			varchar(50) not null,
	venue				varchar(50),
	capacity			integer not null default 40,
	iscurrent			boolean default true,
	details				text
);

--- Define different course types
CREATE TABLE coursetypes (
	coursetypeid		serial primary key,
	coursetypename		varchar(50),
	details				text
);

--- Define all course listed
CREATE TABLE courses (
	courseid			varchar(12) primary key,
	departmentid		varchar(12) not null references departments,
	degreelevelid		varchar(12) not null references degreelevels,
	coursetypeid		integer not null references coursetypes,
	coursetitle			varchar(120) not null,
	credithours			float not null,
	maxcredit			float not null default 5,
	iscurrent			boolean not null default true,
	nogpa				boolean not null default false,
	norepeats			boolean not null default false,

	labcourse			boolean default false not null,
	examinable			boolean default false not null,
	clinical_fee		float default 0 not null,
	extracharge			float default 0 not null,

	yeartaken			integer not null default 1,
	mathplacement		integer not null default 0,
	englishplacement	integer not null default 0,
	kiswahiliplacement	integer not null default 0,
	details				text
);
CREATE INDEX courses_departmentid ON courses (departmentid);
CREATE INDEX courses_degreelevelid ON courses (degreelevelid);
CREATE INDEX courses_coursetypeid ON courses (coursetypeid);

--- Define different bulletings
CREATE TABLE bulleting (
	bulletingid			serial primary key,
 	bulletingname		varchar(50),
	startingquarter		varchar(12),
	endingquarter		varchar(12),
	iscurrent			boolean not null default true,
	details				text
);

--- Define prerequisites of courses
CREATE TABLE prerequisites (
	prerequisiteid		serial primary key,
	courseid			varchar(12) not null references courses,
	precourseid			varchar(12) not null references courses,
	gradeid				varchar(2) not null references grades,
	bulletingid			integer not null references bulleting,
	optionlevel			integer not null default 1,
	narrative			varchar(120)
);
CREATE INDEX prerequisites_courseid ON prerequisites (courseid);
CREATE INDEX prerequisites_precourseid ON prerequisites (precourseid);
CREATE INDEX prerequisites_gradeid ON prerequisites (gradeid);
CREATE INDEX prerequisites_bulletingid ON prerequisites (bulletingid);

--- Define all majors
CREATE TABLE majors (
	majorid				varchar(12) primary key,
	departmentid		varchar(12) not null references departments,
	majorname			varchar(75) not null unique,
	major				boolean default false not null,
	minor				boolean default false not null,
	fullcredit			integer default 200 not null,
	electivecredit		integer not null,
	minorelectivecredit	integer not null,
	majorminimal		real,
	minorminimum		real,
	coreminimum			real,	
	details				text
);
CREATE INDEX majors_departmentid ON majors (departmentid);

--- Define requirements for acceptance to a major
CREATE TABLE requirements (
	requirementid		serial primary key,
	majorid				varchar(12) not null references majors,
	subjectid			integer not null references subjects,
	markid				integer references marks,
	narrative			varchar(240)
);
CREATE INDEX requirements_majorid ON requirements (majorid);
CREATE INDEX requirements_subjectid ON requirements (subjectid);
CREATE INDEX requirements_markid ON requirements (markid);

--- Define options for majors
CREATE TABLE majoroptions (
	majoroptionid		serial primary key,
	majorid				varchar(12) references majors,
	majoroptionname		varchar(120) not null,
	details				text,
	UNIQUE (majorid, majoroptionname)
);
CREATE INDEX majoroptions_majorid ON majoroptions (majorid);

--- Define different content types like elective, cognates, premajors
CREATE TABLE contenttypes (
	contenttypeid		serial primary key,
	contenttypename		varchar(50) not null,
	elective			boolean default false not null,
	prerequisite		boolean default false not null,
	premajor			boolean default false not null,
	details				text
);

--- Define all major courses
CREATE TABLE majorcontents (
	majorcontentid		serial primary key,
	majorid				varchar(12) not null references majors,
	courseid			varchar(12) not null references courses,
	contenttypeid		integer not null references contenttypes,
	gradeid				varchar(2) not null references grades,
	bulletingid			integer references bulleting,
	minor				boolean default false not null,
	narrative			varchar(240),
	UNIQUE (majorid, courseid, contenttypeid, minor, bulletingid)
);
CREATE INDEX majorcontents_majorid ON majorcontents (majorid);
CREATE INDEX majorcontents_courseid ON majorcontents (courseid);
CREATE INDEX majorcontents_contenttypeid ON majorcontents (contenttypeid);
CREATE INDEX majorcontents_gradeid ON majorcontents (gradeid);
CREATE INDEX majorcontents_bulletingid ON majorcontents (bulletingid);

--- Define major option content
CREATE TABLE majoroptcontents (
	majoroptcontentid	serial primary key,
	majoroptionid		integer not null references majoroptions,
	courseid			varchar(12) not null references courses,
	contenttypeid		integer not null references contenttypes,
	gradeid				varchar(2) not null references grades,
	minor				boolean not null default false not null,
	bulletingid			integer not null references bulleting,
	narrative			varchar(240),
	UNIQUE (majoroptionid, courseid, contenttypeid, minor, bulletingid)
);
CREATE INDEX majoroptcontents_majoroptionid ON majoroptcontents (majoroptionid);
CREATE INDEX majoroptcontents_courseid ON majoroptcontents (courseid);
CREATE INDEX majoroptcontents_contenttypeid ON majoroptcontents (contenttypeid);
CREATE INDEX majoroptcontents_gradeid ON majoroptcontents (gradeid);
CREATE INDEX majoroptcontents_bulletingid ON majoroptcontents (bulletingid);

--- Table for all students it links to school and denomination
CREATE TABLE students (
	studentid			varchar(12) primary key,
	schoolid			varchar(12) not null references schools,
	denominationid		varchar(12) not null references denominations,
	residenceid			varchar(12) references residences,
	org_id				integer references orgs,
	sys_audit_trail_id	integer references sys_audit_trail,
	studentname			varchar(50) not null,
	room_number			integer,
	Sex					varchar(1),
	nationality			varchar(2) not null references countrys,
	maritalstatus		varchar(2),
	birthdate			date not null,
	address				varchar(50),
	zipcode				varchar(50),
	town				varchar(50),
	countrycodeid		char(2) not null references countrys,
	telno				varchar(50),
	email				varchar(240),
	guardianname		varchar(50),
	gaddress			varchar(50),
	gzipcode			varchar(50),
	gtown				varchar(50),
	gcountrycodeid		char(2) not null references countrys,
	gtelno				varchar(50),
	gemail				varchar(240),
	accountnumber		varchar(16),
	firstpass			varchar(32) not null default 'enter',
	studentpass			varchar(32) not null default md5('enter'),
	gfirstpass			varchar(32) not null default 'enter',
	gstudentpass		varchar(32) not null default md5('enter'),
	staff				boolean default false not null,
	alumnae				boolean not null default false,
	postcontacts		boolean not null default false,
	seeregistrar		boolean not null default false,
	onprobation			boolean not null default false,
	offcampus			boolean not null default false,
	hallseats			integer not null default 1,
	fullbursary			boolean default false not null,
	disabled			boolean default false not null,
	
	student_edit		varchar(50) default 'none' not null,
	
	disability			varchar(5),
	dis_details 		text,
	passport			boolean DEFAULT false,
	national_id			boolean DEFAULT false,
	identification_no	varchar(20),
	
	currentcontact		text,
	currentemail		varchar(120),
	currenttel			varchar(120),
	balance_time		timestamp,
	curr_balance		real default 0,
	probation_details	text,
	registrar_details	text,
	details				text
);
CREATE INDEX students_schoolid ON students (schoolid);
CREATE INDEX students_denominationid ON students (denominationid);
CREATE INDEX students_nationality ON students (nationality);
CREATE INDEX students_residenceid ON students (residenceid);
CREATE INDEX students_countrycodeid ON students (countrycodeid);
CREATE INDEX students_gcountrycodeid ON students (gcountrycodeid);
CREATE INDEX students_accountnumber ON students (accountnumber);
CREATE INDEX students_org_id ON students (org_id);
CREATE INDEX students_sys_audit_trail_id ON students (sys_audit_trail_id);

--- Define the degree undertaken by student 
CREATE TABLE studentdegrees (
	studentdegreeid		serial primary key,
	degreeid			varchar(12) not null references degrees,
	sublevelid			varchar(12) not null references sublevels,
	studentid			varchar(12) not null references students,
	bulletingid			integer not null references bulleting,
	completed			boolean not null default false,
	started				date,
	cleared				boolean not null default false,
	clearedate			date,
	graduated			boolean not null default false,
	graduatedate		date,
	dropout				boolean not null default false,
	transferin			boolean not null default false,
	transferout			boolean not null default false,
	mathplacement		integer not null default 0,
	englishplacement	integer not null default 0,
	kiswahiliplacement	integer not null default 0,
	transcripted		boolean not null default false,
	transcript			boolean not null default false,
	transcriptdate		date,
	details				text,
	UNIQUE(degreeid, studentid)
);
CREATE INDEX studentdegrees_degreeid ON studentdegrees (degreeid);
CREATE INDEX studentdegrees_sublevelid ON studentdegrees (sublevelid);
CREATE INDEX studentdegrees_studentid ON studentdegrees (studentid);
CREATE INDEX studentdegrees_bulletingid ON studentdegrees (bulletingid);

--- Keep a log for transcripts printed
CREATE TABLE transcriptprint (
	transcriptprintid	serial primary key,
	studentdegreeid		integer not null references studentdegrees,
	entity_id			integer references entitys,
	ip_address			varchar(64),
	link_key			varchar(64),
	accepted			boolean default false not null,
	userid				integer,
	printdate			timestamp default now(),
	narrative			varchar(240)
);
CREATE INDEX transcriptprint_studentdegreeid ON transcriptprint (studentdegreeid);	
CREATE INDEX transcriptprint_entity_id ON transcriptprint (entity_id);

--- Table for all majors taken by students 
CREATE TABLE studentmajors ( 
	studentmajorid		serial primary key,
	studentdegreeid		integer not null references studentdegrees,
	majorid				varchar(12) not null references majors,
	majoroptionid		integer references majoroptions,
	major				boolean not null default false,
	primarymajor		boolean not null default false,
	nondegree			boolean not null default false,
	premajor			boolean not null default false,
	Details				text,
	UNIQUE(studentdegreeid, majorid)
);
CREATE INDEX studentmajors_studentdegreeid ON studentmajors (studentdegreeid);
CREATE INDEX studentmajors_majorid ON studentmajors (majorid);
CREATE INDEX studentmajors_majoroptionid ON studentmajors (majoroptionid);

--- table to indicate all credit transfres linked to a student
CREATE TABLE transferedcredits (
	transferedcreditid		serial primary key,
	studentdegreeid			integer not null references studentdegrees,
	courseid				varchar(12) not null references courses,
	credithours				float default 0 not null,
	narrative				varchar(240),
	UNIQUE (studentdegreeid, courseid)
);
CREATE INDEX transferedcredits_studentdegreeid ON transferedcredits (studentdegreeid);
CREATE INDEX transferedcredits_courseid ON transferedcredits (courseid);

--- Define different request types a student can send
CREATE TABLE requesttypes (
	requesttypeid		serial primary key,
	requesttypename		varchar(50) not null unique,
	request_email		varchar(240),
	toapprove			boolean not null default false,
	details 			text
);

--- Table listing all request sent by students and the responces
CREATE TABLE studentrequests (
	studentrequestid	serial primary key,
	studentid			varchar(12) references students,
	requesttypeid		integer references requesttypes,
	org_id				integer references orgs,
	narrative			varchar(240) not null,
	datesent			timestamp not null default now(),
	actioned			boolean not null default false,
	dateactioned		timestamp,
	approved			boolean not null default false,
	dateapploved		timestamp,
	details				text,
	reply				text
);
CREATE INDEX studentrequests_studentid ON studentrequests (studentid);
CREATE INDEX studentrequests_requesttypeid ON studentrequests (requesttypeid);

--- Define all academic sessions of the university
CREATE TABLE quarters (
	quarterid			varchar(12) primary key,
	qstart				date not null,
	qlatereg			date not null default current_date,
	qlastdrop			date not null,
	qend				date not null,
	active				boolean default false not null,
	closed				boolean default false not null,
	quarter_name		varchar(32),
	qlatechange			float not null default 0,
	chalengerate		float not null default 75,
	feesline			float not null default 70,
	resline				float not null default 70,
	minimal_fees		float not null default 10000,
	exam_line			float not null default 10000,
	details				text
);
CREATE INDEX quarters_active ON quarters (active);

--- Define the calender for each academic session
CREATE TABLE qcalendar (
	qcalendarid			serial primary key,
	quarterid			varchar(12) not null references quarters,
	sublevelid			varchar(12) not null references sublevels,
	org_id				integer references orgs,
	qdate				date not null,
	event				varchar(120),
	details				text
);
CREATE INDEX qcalendar_quarterid ON qcalendar (quarterid);
CREATE INDEX qcalendar_sublevelid ON qcalendar (sublevelid);

--- Define residence charges per academic session
CREATE TABLE qresidences (
	qresidenceid		serial primary key,
	quarterid			varchar(12) not null references quarters,
	residenceid			varchar(12) not null references residences,
	org_id				integer references orgs,
	residenceoption		varchar(50) not null default 'Full',
	charges				float not null,
	active				boolean not null default true,
	details				text,
	UNIQUE (quarterid, residenceid, residenceoption)
);
CREATE INDEX qresidences_quarterid ON qresidences (quarterid);
CREATE INDEX qresidences_residenceid ON qresidences (residenceid);

--- Define fees and charges 
CREATE TABLE charges (
	charge_id			serial primary key,
	quarterid			varchar(12) not null references quarters,
	sublevelid			varchar(12) not null references sublevels,
	org_id				integer references orgs,
	session_active		boolean default false not null,
	session_closed		boolean default false not null,

	exam_balances		boolean default false not null,
	sun_posted			boolean default false not null, --- addition

	late_fee_date		date not null,

	unit_charge			float not null default 2500,
	lab_charges			float not null default 2000,
	exam_fees			float not null default 500,
	general_fees		float not null default 7500,

	residence_stay		float not null default 100,			--- Give % of stay for group
	currency			varchar(32) default 'KES' not null, --- to implement multi-currency
	exchange_rate		real default 1 not null,
	narrative			varchar(120),
	UNIQUE(quarterid, sublevelid)
);
CREATE INDEX charges_sublevelid ON charges (sublevelid);
CREATE INDEX charges_org_id ON charges (org_id);

--- Table for details of a student per session
CREATE TABLE qstudents (
	qstudentid			serial primary key,
	quarterid			varchar(12) not null references quarters,
	charge_id			integer references charges,
	studentdegreeid		integer not null references studentdegrees,
	qresidenceid		integer not null references qresidences,
	sabathclassid		integer references sabathclasses,
	org_id				integer references orgs,
	sys_audit_trail_id	integer references sys_audit_trail,
	charges				float default 0 not null,
	probation			boolean default false not null,
	roomnumber			integer,
	currbalance			real,
	balance_time		timestamp,

	applicationtime		timestamp not null default now(),
	residencerefund		float not null default 0,
	feerefund			float not null default 0,	
	finalised			boolean default false not null,
	finaceapproval		boolean default false not null,
	majorapproval		boolean default false not null,
	chaplainapproval	boolean default false not null,
	studentdeanapproval	boolean default false not null,
	overloadapproval	boolean default false not null,
	departapproval		boolean default false not null,
	registrarapproval	boolean default false not null,
	overloadhours		float,
	intersession		boolean default false not null,
	closed				boolean default false not null,
	printed				boolean default false not null,
	approved			boolean default false not null,
	firstclosetime		timestamp,

	approve_late_fee	boolean default false not null,
	late_fee_amount		real,
	late_fee_date		date,

	record_posted		boolean default false not null,
	post_changed		boolean default false not null,

	withdraw			boolean default false not null,
	ac_withdraw			boolean default false not null,
	request_withdraw		boolean default false not null,
	request_withdraw_date	timestamp,
	withdraw_date		date,
	withdraw_rate		real,

	exam_clear			boolean default false not null,
	exam_clear_date		timestamp,
	exam_clear_balance	real,

	firstinstalment		real,
	firstdate			date,
	secondinstalment	real,
	seconddate			date,

	changed_by			integer,
	financenarrative	text,
	noapproval			text,
	details				text,
	UNIQUE(charge_id, studentdegreeid)		--- change the constraint
);
CREATE INDEX qstudents_quarterid ON qstudents (quarterid);
CREATE INDEX qstudents_studentdegreeid ON qstudents (studentdegreeid);
CREATE INDEX qstudents_sabathclassid ON qstudents (sabathclassid);
CREATE INDEX qstudents_qresidenceid ON qstudents (qresidenceid);
CREATE INDEX qstudents_roomnumber ON qstudents (roomnumber);
CREATE INDEX qstudents_charge_id ON qstudents (charge_id);  --- add the sub charge clause
CREATE INDEX qstudents_approved ON qstudents (approved);
CREATE INDEX qstudents_org_id ON qstudents (org_id);
CREATE INDEX qstudents_sys_audit_trail_id ON qstudents (sys_audit_trail_id);

--- Audit list of all aproval done for a students sessions application
CREATE TABLE approvallist (
	approvalid			serial primary key,
	qstudentid			integer not null references qstudents,
	approvedby			varchar(50),
	approvaltype		varchar(25),
	approvedate			timestamp default now(),
	clientid			varchar(25)
);
CREATE INDEX approvallist_qstudentid ON approvallist (qstudentid);

--- Audit list of all sun updates
CREATE TABLE sun_audits (
	sun_audit_id		serial primary key,
	studentid			varchar(12) references students,
	update_type			varchar(25),
	update_time			timestamp default now(),
	sun_balance			real,
	user_ip				varchar(64)
);
CREATE INDEX sun_audits_studentid ON sun_audits (studentid);

--- Table for all courses done per in a semester
CREATE TABLE qcourses (
	qcourseid			serial primary key,
	quarterid			varchar(12) not null references quarters,
	instructorid		varchar(12) not null references instructors,
	courseid			varchar(12) not null references courses,
	levellocationid		integer references levellocations, --- addition on course location
	org_id				integer references orgs,
	classoption			varchar(50) default 'Main' not null,
	maxclass			integer not null,

	session_title		varchar(120),

	labcourse			boolean default false not null,
	examinable			boolean default false not null,
	clinical_fee		float default 0 not null,
	extracharge			float default 0 not null,

	approved			boolean default false not null,
	intersession		boolean default false not null,
	attachement			boolean default false not null,

	examsubmited		boolean default false not null,
	gradesubmited 		boolean default false not null,

	submit_grades		boolean default false not null,
	submit_date			timestamp,

	approved_grades		boolean default false not null,
	approve_date		timestamp,

	departmentchange	varchar(240),
	registrychange		varchar(240),

	attendance			integer,
	oldcourseid			varchar(12),
	oldinstructor		varchar(50),
	oldcoursetitle		varchar(50),
	fullattendance		integer,
	details				text,
	UNIQUE (instructorid, courseid, quarterid, classoption)
);
CREATE INDEX qcourses_quarterid ON qcourses (quarterid);
CREATE INDEX qcourses_instructorid ON qcourses (instructorid);
CREATE INDEX qcourses_courseid ON qcourses (courseid);
CREATE INDEX qcourses_levellocationid ON qcourses (levellocationid);  --- addition on qcourse for location index

--- Table for option for time for the time table
CREATE TABLE optiontimes (
	optiontimeid		serial primary key,
	optiontimename		varchar(50),
	details				text
);
INSERT INTO optiontimes (optiontimeid, optiontimename) VALUES (0, 'Main');

--- Table for class timetable for each course in a session
CREATE TABLE qtimetable (
	qtimetableid		serial primary key,
	assetid				integer not null references assets,
	qcourseid			integer not null references qcourses,
	optiontimeid		integer not null references optiontimes default 0,
	org_id				integer references orgs,
	cmonday				boolean not null default false,
	ctuesday			boolean not null default false,
	cwednesday			boolean not null default false,
	cthursday			boolean not null default false,
	cfriday				boolean not null default false,
	csaturday			boolean not null default false,
	csunday				boolean not null default false,
	starttime			time not null,
	endtime				time not null,
	lab					boolean not null default false,
	details				text
);
CREATE INDEX qtimetable_assetid ON qtimetable (assetid);
CREATE INDEX qtimetable_qcourseid ON qtimetable (qcourseid);
CREATE INDEX qtimetable_optiontimeid ON qtimetable (optiontimeid);

--- Table for exam time table
CREATE TABLE qexamtimetable (
	qexamtimetableid	serial primary key,
	assetid				integer not null references assets,
	qcourseid			integer not null references qcourses,
	optiontimeid		integer not null references optiontimes default 0,
	org_id				integer references orgs,
	examdate			date,
	starttime			time not null,
	endtime				time not null,
	lab					boolean not null default false,
	details				text
);
CREATE INDEX qexamtimetable_assetid ON qexamtimetable (assetid);
CREATE INDEX qexamtimetable_qcourseid ON qexamtimetable (qcourseid);
CREATE INDEX qexamtimetable_optiontimeid ON qexamtimetable (optiontimeid);

--- Table that indicate all courses done by student and the grade
CREATE TABLE qgrades (
	qgradeid 			serial primary key,
	qstudentid			integer not null references qstudents,
	qcourseid			integer not null references qcourses,
	gradeid				varchar(2) not null references grades default 'NG',
	optiontimeid		integer references optiontimes default 0,
	org_id				integer references orgs,
	sys_audit_trail_id	integer references sys_audit_trail,
	hours				float not null,
	credit				float not null,

	final_marks			real,
	selectiondate		timestamp default now(),
	approved        	boolean not null default false,
	approvedate			timestamp,
	askdrop				boolean not null default false,	
	askdropdate			timestamp,	
	dropped				boolean not null default false,	
	dropdate			date,
	repeated			boolean not null default false,
	nongpacourse		boolean not null default false,	
	challengecourse		boolean not null default false,
	repeatapproval		boolean default false not null,
	request_drop		boolean not null default false,	
	request_drop_date	timestamp,	

	lecture_marks		real,
	lecture_cat_mark	real default 0 not null,
	lecture_gradeid		varchar(2) references grades default 'NG',

	withdrawdate		date,
	withdraw_rate		real,
	attendance			integer,
	narrative			varchar(240),

	record_posted		boolean default false not null,
	post_changed		boolean default false not null,

	changed_by			integer,
	UNIQUE(qstudentid, qcourseid)
);
CREATE INDEX qgrades_qstudentid ON qgrades (qstudentid);
CREATE INDEX qgrades_qcourseid ON qgrades (qcourseid);
CREATE INDEX qgrades_gradeid ON qgrades (gradeid);
CREATE INDEX qgrades_optiontimeid ON qgrades (optiontimeid);
CREATE INDEX qgrades_lecture_gradeid ON qgrades (lecture_gradeid);
CREATE INDEX qgrades_org_id ON qgrades (org_id);
CREATE INDEX qgrades_sys_audit_trail_id ON qgrades (sys_audit_trail_id);

--- Audit table for any changes made to grade
CREATE TABLE gradechangelist (
	gradechangeid		serial primary key,
	qgradeid			integer not null references qgrades,
	entity_id			integer references entitys,
	changedby			varchar(50),
	oldgrade			varchar(2),
	newgrade			varchar(2),
	changedate			timestamp default now(),
	clientip			varchar(25)
);
CREATE INDEX gradechangelist_qgradeid ON gradechangelist (qgradeid);
CREATE INDEX gradechangelist_entity_id ON gradechangelist (entity_id);

--- Table indicating items for each courses liek cats, tests to help compute the grade
CREATE TABLE qcourseitems (
	qcourseitemid		serial primary key,
	qcourseid			integer not null references qcourses,
	org_id				integer references orgs,
	qcourseitemname		varchar(50),
	markratio			float not null,
	totalmarks			integer not null,
	given				date,
	deadline			date,
	details				text
);
CREATE INDEX qcourseitems_qcourseid ON qcourseitems (qcourseid);

--- Table to list the marks for cats and exams to help compute the course grade
CREATE TABLE qcoursemarks (
	qcoursemarkid		serial primary key,
	qgradeid			integer not null references qgrades,
	qcourseitemid		integer not null references qcourseitems,
	org_id				integer references orgs,
	approved        	boolean not null default false,
	submited			date,
	markdate			date,
	marks				float not null default 0,
	details				text
);
CREATE INDEX qcoursemarks_qgradeid ON qcoursemarks (qgradeid);
CREATE INDEX qcoursemarks_qcourseitemid ON qcoursemarks (qcourseitemid);

--- Posting for all credit to student payments
CREATE TABLE student_payments (
	student_payment_id	serial primary key,
	qstudentid			integer not null references qstudents,
	org_id				integer references orgs,
	entrydate			timestamp not null default now(), 
	CustomerReference	varchar(25) not null unique,
	TransactionDate		date not null,
	ValueDate			date,
	TransactionAmount	real not null, 
	DRCRFlag			varchar(5), 
	TransactionDetail	varchar(240), 
	TransactionType		int,
	Suspence			boolean default false not null,
	Picked				boolean default false not null,
	Pickeddate			timestamp
);
CREATE INDEX student_payments_qstudentid ON student_payments (qstudentid);
CREATE INDEX student_payments_org_id ON student_payments (org_id);

CREATE TABLE qposting_logs (
	qposting_log_id 	serial primary key,
	qstudentid			integer references qstudents,
	sys_audit_trail_id	integer references sys_audit_trail,
	posted_type_id		integer default 1 not null,
	posted_date			timestamp default now() not null,
	psublevelid			varchar(12),
	presidenceid		varchar(12),
	phours				real,
	punitcharge			real,
	plabcharge			real,
	pclinical_charge	real,
	pexamfee			real,
	pcourseextracharge	real,
	pfeescharge			real,
	presidencecharge	real,
	ptotalfees			real,
	narrative			varchar(120)
);
CREATE INDEX qposting_logs_qstudentid ON qposting_logs (qstudentid);
CREATE INDEX qposting_logs_sys_audit_trail_id ON qposting_logs (sys_audit_trail_id);


