--- Extend Entities to accomodate 
ALTER TABLE entitys ADD selection_id integer;
ALTER TABLE entitys ADD admision_payment real default 2000;
ALTER TABLE entitys ADD admision_paid boolean default false not null;

CREATE OR REPLACE FUNCTION ins_application() RETURNS trigger AS $$
BEGIN	
	IF(NEW.selection_id is not null) THEN
		INSERT INTO entry_forms (org_id, entity_id, entered_by_id, form_id)
		VALUES(NEW.org_id, NEW.entity_id, NEW.entity_id, NEW.selection_id);
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_application AFTER INSERT ON entitys
    FOR EACH ROW EXECUTE PROCEDURE ins_application();

DROP VIEW vw_entitys;
CREATE VIEW vw_entitys AS
	SELECT orgs.org_id, orgs.org_name, 
		entity_types.entity_type_id, entity_types.entity_type_name, 
		entity_types.entity_role, entity_types.group_email, entity_types.use_key_id,
		entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.super_user, entitys.entity_leader, 
		entitys.date_enroled, entitys.is_active, entitys.entity_password, entitys.first_password, 
		entitys.primary_email, entitys.function_role, 
		entitys.selection_id, entitys.admision_payment, entitys.admision_paid,
		entitys.details
	FROM entitys INNER JOIN orgs ON entitys.org_id = orgs.org_id
		INNER JOIN entity_types ON entitys.entity_type_id = entity_types.entity_type_id;

--- Table listing all kenya counties
CREATE TABLE counties (
	county_id			serial primary key,
	county_name			varchar(50)
);

CREATE TABLE registrations (
	registrationid		serial primary key,
	markid				integer references marks,
	entity_id			integer references entitys,
	degreeid			varchar(12) references degrees,
	majorid				varchar(12) references majors,
	sublevelid			varchar(12) references sublevels,
	county_id			integer references counties,
	org_id				integer references orgs,
	entry_form_id		integer references entry_forms,
	session_id			varchar(12),
	email				varchar(120),
	entrypass			varchar(32) not null default md5('enter'),
	firstpass			varchar(32) not null default first_password(),
	existingid			varchar(12),
	scheduledate		date not null default current_date,
	applicationdate     date not null default current_date,
	accepted			boolean not null default false,
	premajor			boolean not null default false,

	submitapplication		boolean not null default false,
	submitdate				timestamp,
	isaccepted				boolean not null default false,
	isreported				boolean not null default false,
	isdeferred				boolean not null default false,
	isrejected				boolean not null default false,
	evaluationdate			date,

	accepteddate		date,

	reported			boolean not null default false,
	reporteddate		date,
	denominationid		varchar(12) references denominations,
	mname				varchar(50),
	fname				varchar(50),
	fdenominationid		varchar(12) references denominations,
	mdenominationid		varchar(12) references denominations,
	foccupation         varchar(50),
	fnationalityid      char(2) references countrys,
	moccupation			varchar(50),
	mnationalityid		char(2) references countrys,	
	parentchurch		boolean,
	parentemployer		varchar(120),
	birthdate			date not null,
	baptismdate			date,
	lastname			varchar(50) not null,
	firstname			varchar(50) not null,
	middlename			varchar(50),
	Sex					varchar(1),
	MaritalStatus		varchar(2),
	nationalityid		char(2) references countrys,
	citizenshipid		char(2) references countrys,
	residenceid			char(2) references countrys,
	firstlanguage		varchar(50),
	otherlanguages		varchar(120),
	churchname			varchar(50),
	churcharea			varchar(50),
	churchaddress		text,
	handicap			varchar(120),
	personalhealth		varchar(50),
	smoke				boolean,
	drink				boolean,
	drugs				boolean,
	hsmoke				boolean,
	hdrink				boolean,
	hdrugs				boolean,
	attendedprimary     varchar(50),
	attendedsecondary   varchar(50),
	expelled			boolean,
	previousrecord		varchar(50),
	workexperience	    varchar(50),
	employername        varchar(50),
	postion				varchar(50),
	attendedueab		boolean not null default false,
	attendeddate		date,
	dateemployed        date,
	campusresidence		varchar(50),
	details				text
);
CREATE INDEX registrations_denominationid ON registrations (denominationid);
CREATE INDEX registrations_fdenominationid ON registrations (fdenominationid);
CREATE INDEX registrations_mdenominationid ON registrations (mdenominationid);
CREATE INDEX registrations_nationalityid ON registrations (nationalityid);
CREATE INDEX registrations_citizenshipid ON registrations (citizenshipid);
CREATE INDEX registrations_residenceid ON registrations (residenceid);
CREATE INDEX registrations_county_id ON registrations (county_id);

CREATE TABLE contacttypes (
	contacttypeid		serial primary key,
	contacttypename		varchar(50),
	primarycontact		boolean not null default false,
	narrative			varchar(240)
);

CREATE TABLE regcontacts (
	regcontactid		serial primary key,
	registrationid		integer references registrations,
	contacttypeid		integer references contacttypes,
	guardiancontact		boolean not null default false,
	regcontactname		varchar(50),
	telephone			varchar(50),
	fax					varchar(50),
	address				varchar(50),
	zipcode				varchar(50),
	town				varchar(50),
	countrycodeid		varchar(2)  references countrys,
	email				varchar(240),
	details				text,
	UNIQUE (registrationid, contacttypeid)
);
CREATE INDEX regcontacts_registrationid ON regcontacts (registrationid);
CREATE INDEX regcontacts_contacttypeid ON regcontacts (contacttypeid);

CREATE TABLE healthitems (
	healthitemid		serial primary key,
	healthitemname		varchar(50),
	narrative			varchar(240)
);

CREATE TABLE reghealth (
	reghealthid			serial primary key,
	registrationid		integer references registrations,
	healthitemid		integer references healthitems,
	narrative			varchar(240),
	UNIQUE (registrationid, healthitemid)
);
CREATE INDEX reghealth_registrationid ON reghealth (registrationid);
CREATE INDEX reghealth_healthitemid ON reghealth (healthitemid);

CREATE TABLE evaluation (
	evaluationid		serial primary key,
	registrationid		integer references registrations,
	respondentname      varchar(50),
	organisationname	varchar(50),
	respondentpostion	varchar(50),
	address				varchar(50),
	evaldate    		date,
	influence           varchar(50),
	honesty				varchar(50),
	reliabilty          varchar(50),
	coperation          varchar(50),
	punctuality         varchar(50),
	appearance          varchar(50),
	moralstandards      varchar(50),
	religiouscommitment varchar(50),
	churchactivities    varchar(50),
	overal				varchar(50),
	smoke				boolean,
	drink				boolean,
	drugs				boolean,
	hsmoke				boolean,
	hdrink				boolean,
	hdrugs				boolean,
	arrested			boolean,
	schooldismissal		varchar(50),
	recomendation		varchar(50),
	details				text
);
CREATE INDEX evaluation_registrationid ON evaluation (registrationid);

CREATE TABLE registryschools (
	registryschoolid	serial primary key,
	registrationid		integer references registrations,
	org_id				integer references orgs,
	primaryschool		boolean,
	olevelschool		boolean,
	schoolname			varchar(50),
	address				text,
	sdate				date,
	edate				date,
	narrative			varchar(240)
);
CREATE INDEX registryschools_registrationid ON registryschools (registrationid);

CREATE TABLE registrymarks (
	registrymarkid		serial primary key,
	registrationid		integer not null references registrations,
	subjectid			integer not null references subjects,
	markid				integer not null references marks,
	org_id				integer references orgs,
	narrative			varchar(240),
	UNIQUE (registrationid, subjectid)
);
CREATE INDEX registrymarks_registrationid ON registrymarks (registrationid);
CREATE INDEX registrymarks_markid ON registrymarks (markid);
CREATE INDEX registrymarks_subjectid ON registrymarks (subjectid);

CREATE TABLE application_forms (
	application_form_id	serial primary key,
	markid				integer references marks,
	entity_id			integer references entitys,
	degreeid			varchar(12) references degrees,
	majorid				varchar(12) references majors,
	sublevelid			varchar(12) references sublevels,
	county_id			integer references counties,
	org_id				integer references orgs,
	entry_form_id		integer references entry_forms,
	session_id			varchar(12),
	email				varchar(120),
	entrypass			varchar(32) not null default md5('enter'),
	firstpass			varchar(32) not null default first_password(),
	existingid			varchar(12),
	scheduledate		date not null default current_date,
	applicationdate     date not null default current_date,
	accepted			boolean not null default false,
	premajor			boolean not null default false,
	
	homeaddress			varchar(120),
	phonenumber			varchar(50),

	apply_trimester		varchar(32),

	reported			boolean not null default false,
	reporteddate		date,
	denominationid		varchar(12) references denominations,
	mname				varchar(50),
	fname				varchar(50),
	fdenominationid		varchar(12) references denominations,
	mdenominationid		varchar(12) references denominations,
	foccupation         varchar(50),
	fnationalityid      char(2) references countrys,
	moccupation			varchar(50),
	mnationalityid		char(2) references countrys,	
	parentchurch		boolean,
	parentemployer		varchar(120),
	birthdate			date not null,
	baptismdate			date,
	lastname			varchar(50) not null,
	firstname			varchar(50) not null,
	middlename			varchar(50),
	Sex					varchar(12),
	MaritalStatus		varchar(12),
	nationalityid		char(2) references countrys,
	citizenshipid		char(2) references countrys,
	residenceid			char(2) references countrys,
	firstlanguage		varchar(50),
	otherlanguages		varchar(120),
	churchname			varchar(50),
	churcharea			varchar(50),
	churchaddress		text,
	handicap			varchar(120),
	personalhealth		varchar(50),
	smoke				boolean,
	drink				boolean,
	drugs				boolean,
	hsmoke				boolean,
	hdrink				boolean,
	hdrugs				boolean,
	attendedprimary     varchar(50),
	attendedsecondary   varchar(50),
	expelled			boolean,
	previousrecord		varchar(50),
	workexperience	    varchar(50),
	employername        varchar(50),
	postion				varchar(50),
	attendedueab		boolean not null default false,
	attendeddate		date,
	dateemployed        date,
	campusresidence		varchar(50),
	details				text
);


CREATE VIEW registrationview AS
	SELECT registrations.registrationid, registrations.email, registrations.entrypass, registrations.firstpass,
		registrations.applicationdate, sys_countrys.sys_country_name as nationality, registrations.sex,
		registrations.lastname, registrations.firstname, registrations.middlename, 
		(registrations.lastname || ', ' ||  registrations.firstname || ' ' || registrations.middlename) as fullname,
		registrations.existingid
	FROM registrations INNER JOIN sys_countrys ON  registrations.nationalityid = sys_countrys.sys_country_id;

CREATE VIEW registrymarkview AS
	SELECT registrationview.registrationid, registrationview.fullname, subjects.subjectid, subjects.subjectname, marks.markid, marks.grade,
		registrymarks.registrymarkid, registrymarks.narrative
	FROM ((registrationview INNER JOIN registrymarks ON registrationview.registrationid = registrymarks.registrationid)
		INNER JOIN subjects ON registrymarks.subjectid = subjects.subjectid)
		INNER JOIN marks ON registrymarks.markid =  marks.markid;
	
CREATE VIEW reghealthview AS
	SELECT healthitems.healthitemid, healthitems.healthitemname, reghealth.reghealthid, reghealth.registrationid,
		reghealth.narrative
	FROM healthitems INNER JOIN reghealth ON healthitems.healthitemid = reghealth.healthitemid;

CREATE VIEW parentsview AS 
	SELECT registrations.fname, registrations.mname, registrations.fdenominationid, registrations.mdenominationid,
		registrations.registrationid
	FROM registrations;

CREATE VIEW regcontactview AS
	SELECT contacttypes.contacttypeid, contacttypes.contacttypename, contacttypes.primarycontact,
		regcontacts.registrationid, regcontacts.regcontactid, regcontacts.guardiancontact, regcontacts.regcontactname,
		regcontacts.telephone, regcontacts.fax, regcontacts.address, regcontacts.zipcode,
		regcontacts.town, sys_countrys.sys_country_name	as countryname, regcontacts.email
	FROM contacttypes INNER JOIN regcontacts ON contacttypes.contacttypeid = regcontacts.contacttypeid
		INNER JOIN sys_countrys ON regcontacts.countrycodeid = sys_countrys.sys_country_id;

CREATE OR REPLACE VIEW vw_adm_semesters AS 
	SELECT adm_semesters.semester_id
		FROM (SELECT ((s.a::text || '/'::text) || ((s.a + 1)::text)) || '.1'::text AS semester_id
			FROM generate_series(date_part('year'::text, 'now'::text::date)::integer - 7, date_part('year'::text, 'now'::text::date)::integer + 2) s(a)
        UNION 
			SELECT ((s.a::text || '/'::text) || ((s.a + 1)::text)) || '.2'::text AS semester_id
			FROM generate_series(date_part('year'::text, 'now'::text::date)::integer - 7, date_part('year'::text, 'now'::text::date)::integer + 2) s(a)) adm_semesters
		ORDER BY adm_semesters.semester_id;

CREATE OR REPLACE FUNCTION ins_registrations() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_registrations BEFORE INSERT ON registrations
    FOR EACH ROW EXECUTE PROCEDURE ins_registrations();


CREATE OR REPLACE FUNCTION insnewstudent(varchar, varchar, varchar) RETURNS VARCHAR(50) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_application_forms() RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_application_forms AFTER INSERT ON application_forms
    FOR EACH ROW EXECUTE PROCEDURE ins_application_forms();


