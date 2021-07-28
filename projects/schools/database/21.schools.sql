CREATE TABLE subjects (
	subject_id				serial primary key,
	org_id					integer references orgs,
	subject_code			varchar(8) not null UNIQUE,
	subject_name			varchar(50) not null UNIQUE,
	details					text
);
CREATE INDEX subjects_org_id ON subjects (org_id);

CREATE TABLE classes (
	class_id				serial primary key,
	org_id					integer references orgs,
	class_level				integer not null,
	stream					varchar(16) not null,
	max_student				integer,
	details					text
);
CREATE INDEX classes_org_id ON classes (org_id);

CREATE TABLE grades (
	grade_id 				serial primary key,
	org_id					integer references orgs,
	grade					varchar(5) not null,
	grade_range_from		float not null,
	grade_range_to			float not null,
	grade_points			float,
	grade_desc				varchar(50) ,
	details					varchar(150)
);
CREATE INDEX grades_org_id ON grades (org_id);

CREATE TABLE vote_heads (
	vote_head_id			serial primary key,
	org_id					integer references orgs,
	vote_head_name			varchar(100) NOT NULL
);
CREATE INDEX vote_heads_org_id ON vote_heads (org_id);

CREATE TABLE students (
	student_id			serial primary key,
	student_code			varchar(12),
	org_id				integer references orgs,
	sys_audit_trail_id		integer references sys_audit_trail,
	student_name			varchar(120) not null,
	sex					varchar(1),
	nationality			char(2) not null references sys_countrys,
	birth_date			date not null,
	address				varchar(50),
	zip_code			varchar(12),
	town				varchar(50),
	county_id 			char(2) not null references sys_countrys,
	telno				varchar(50),
	email				varchar(240),
	details				text
);
CREATE INDEX students_nationality ON students (nationality);
CREATE INDEX students_county_id ON students (county_id);
CREATE INDEX students_org_id ON students (org_id);
CREATE INDEX students_sys_audit_trail_id ON students (sys_audit_trail_id);

ALTER TABLE students
ADD COLUMN entity_id  integer references entitys;

CREATE INDEX students_entity_id ON students (entity_id);

CREATE TABLE guardians(
	guardian_id			serial primary key,
	student_id			integer references students,
	org_id				integer references orgs,
	nationality			varchar(2) not null references sys_countrys,
	guardian_name			varchar(50),
	g_relationship			varchar(50),
	g_address			varchar(50) not null,
	g_town				varchar(50) not null,
	g_telno				varchar(50) not null,
	g_email				varchar(240) not null,
	details				text
);
CREATE INDEX guardians_org_id ON guardians (org_id);
CREATE INDEX guardians_student_id ON guardians (student_id);

CREATE TABLE medicals(
	medical_id				serial primary key,
	student_id				integer references students,
	org_id					integer references orgs,
	medical_name				varchar(320),
	medical_history				text,
	details					text
);
CREATE INDEX medicals_org_id ON medicals (org_id);
CREATE INDEX medicals_student_id ON medicals (student_id);

CREATE TABLE sessions (
	session_id				serial primary key,
	org_id					integer references orgs,
	academic_year			varchar(8) NOT NULL,
	session_name			varchar(32) NOT NULL,
	session_start_date		date NOT NULL,
	session_end_date		date NOT NULL,
	is_active  				boolean default false not null,
	details					text
);
CREATE INDEX session_org_id ON sessions(org_id);

CREATE TABLE fees_structure (
	fees_structure_id		serial primary key,
	session_id				integer references sessions,
	vote_head_id			integer references vote_heads,
	org_id					integer references orgs,
	
	class_level				integer not null,
	amount					real not null,
	
	details					text
);
CREATE INDEX fees_structure_session_id ON fees_structure(session_id);
CREATE INDEX fees_structure_vote_head_id ON fees_structure(vote_head_id);
CREATE INDEX fees_structure_org_id ON fees_structure(org_id);

CREATE TABLE student_sessions (
	student_session_id		serial primary key,
	session_id				integer references sessions,
	student_id				integer references students,
	class_id				integer references classes,
	org_id					integer references orgs,
	
	total_fees				real default 0 not null,
	
	details					text
);
CREATE INDEX student_sessions_session_id ON student_sessions(session_id);
CREATE INDEX student_sessions_student_id ON student_sessions(student_id);
CREATE INDEX student_sessions_class_id ON student_sessions(class_id);
CREATE INDEX student_sessions_org_id ON student_sessions(org_id);

CREATE TABLE student_payments (
	student_payment_id		serial primary key,
	student_session_id		integer references student_sessions,
	org_id					integer references orgs,
	
	payment_date			date default current_date not null,
	amount					real default 0 not null,
	
	details					text
);
CREATE INDEX student_payments_student_session_id ON student_payments(student_session_id);
CREATE INDEX student_payments_org_id ON student_payments(org_id);

CREATE TABLE student_subjects (
	student_subject_id		serial primary key,
	student_session_id		integer references student_sessions,
	subject_id			integer references subjects,
	grade_id			integer references grades,

	org_id				integer references orgs,

	marks				real,
	details				text
);
CREATE INDEX student_subjects_student_session_id ON student_subjects(student_session_id);
CREATE INDEX student_subjects_subject_id ON student_subjects(subject_id);
CREATE INDEX student_subjects_grade_id ON student_subjects(grade_id);
CREATE INDEX student_subjects_org_id ON student_subjects(org_id);

CREATE TABLE exams(
	exam_id				serial primary key,
	session_id			integer references sessions,
	class_id			integer references classes,

	org_id				integer references orgs,

	exam_name			varchar(50) NOT NULL,
	narrative			varchar(50),
	details				text
);
CREATE INDEX exams_session_id ON exams(session_id);
CREATE INDEX exams_class_id ON exams(class_id);
CREATE INDEX exams_org_id ON exams(org_id);

CREATE TABLE subject_exams(
	subject_exam_id		serial primary key,
	exam_id			integer references exams,
	subject_id		integer references subjects,
	org_id			integer references orgs,

	subject_exam_date	date NOT NULL,
	subject_exam_start	time NOT NULL,
	subject_exam_end	time NOT NULL,
	narrative		varchar(50),
	detail			text
);
CREATE INDEX subject_exams_subject_id ON subject_exams(subject_id);
CREATE INDEX subject_exams_exam_id ON subject_exams(exam_id);
CREATE INDEX subject_exams_org_id ON subject_exams(org_id);

