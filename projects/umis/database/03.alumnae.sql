CREATE TABLE education_class (
	education_class_id		serial primary key,
	education_class_name	varchar(50),
	details					text
);
INSERT INTO education_class (education_class_id, education_class_name) VALUES (1, 'Primary School');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (2, 'Secondary School');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (3, 'High School');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (4, 'Certificate');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (5, 'Diploma');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (6, 'Higher Diploma');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (7, 'Under Graduate');
INSERT INTO education_class (education_class_id, education_class_name) VALUES (8, 'Post Graduate');

CREATE TABLE education (
	education_id			serial primary key,
	entity_id				integer references entitys,
	education_class_id		integer references education_class,
	date_from				date,
	date_to					date,
	name_of_school			varchar(240),
	examination_taken		varchar(240),
	grades_obtained			varchar(50),
	details					text
);
CREATE INDEX education_entity_id ON education (entity_id);
CREATE INDEX education_education_class_id ON education (education_class_id);

CREATE TABLE employment (
	employment_id			serial primary key,
	entity_id				integer references entitys,
	date_from				date,
	date_to					date,
	employers_name			varchar(240),
	position_held			varchar(240),
	details					text
);
CREATE INDEX employment_entity_id ON employment (entity_id);

CREATE TABLE cv_seminars (
	cv_seminar_id			serial primary key,
	entity_id				integer references entitys,
	cv_seminar_name			varchar(240),
	cv_seminar_date			date not null,
	details					text
);
CREATE INDEX cv_seminars_entity_id ON cv_seminars (entity_id);

CREATE TABLE cv_projects (
	cv_projectid			serial primary key,
	entity_id				integer references entitys,
	cv_project_name			varchar(240),
	cv_project_date			date not null,
	details					text
);
CREATE INDEX cv_projects_entity_id ON cv_projects (entity_id);

CREATE TABLE cv_referees (
	cv_referee_id			serial primary key,
	entity_id				integer references entitys,
	cv_referee_name			varchar(50),
	cv_referee_address		text,
	details					text
);
CREATE INDEX cv_referees_entity_id ON cv_referees (entity_id);

CREATE TABLE skill_category (
	skill_category_id		serial primary key,
	skill_category_name		varchar(50) not null,
	details					text
);

CREATE TABLE skill_types (
	skill_type_id			serial primary key,
	skill_category_id		integer references skill_category,
	skill_type_name			varchar(50) not null,
	basic					varchar(50),
	intermediate 			varchar(50),
	advanced				varchar(50),
	details					text
);
CREATE INDEX skill_types_skill_category_id ON skill_types (skill_category_id);

CREATE TABLE skills (
	skill_id				serial primary key,
	entity_id				integer references entitys,
	skill_type_id			integer references skill_types,
	skill_level				integer default 1 not null,
	aquired					boolean default false not null,
	training_date			date,
	trained					boolean default false not null,
	training_institution	varchar(240),
	training_cost			real,
	details					text
);
CREATE INDEX skills_entity_id ON skills (entity_id);
CREATE INDEX skills_skill_type_id ON skills (skill_type_id);

CREATE TABLE offers (
	offer_id				serial primary key,
	entity_id				integer references entitys,
	offer_name				varchar(240),
	opening_date			date not null,
	closing_date			date not null,
	positions				int,
	location				varchar(50),
	details					text
);
CREATE INDEX offers_entity_id ON offers (entity_id);

CREATE TABLE applications (
	application_id			serial primary key,
	offer_id				integer references offers,
	entity_id				integer references entitys,
	application_date		timestamp default now(),
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	action_date				timestamp,
	applicant_comments		text,
	review					text,
	UNIQUE(offer_id, entity_id)
);
CREATE INDEX applications_offer_id ON applications (offer_id);
CREATE INDEX applications_entity_id ON applications (entity_id);

CREATE VIEW vw_education AS
	SELECT education_class.education_class_id, education_class.education_class_name, entitys.entity_id, entitys.entity_name, 
		education.education_id, education.date_from, education.date_to, education.name_of_school, education.examination_taken,
		education.grades_obtained, education.details
	FROM education INNER JOIN education_class ON education.education_class_id = education_class.education_class_id
		INNER JOIN entitys ON education.entity_id = entitys.entity_id;

CREATE VIEW vw_employment AS
	SELECT entitys.entity_id, entitys.entity_name, employment.employment_id, employment.date_from, employment.date_to, 
		employment.employers_name, employment.position_held, employment.details
	FROM employment INNER JOIN entitys ON employment.entity_id = entitys.entity_id;

CREATE VIEW vw_cv_seminars AS
	SELECT entitys.entity_id, entitys.entity_name, cv_seminars.cv_seminar_id, cv_seminars.cv_seminar_name, 
		cv_seminars.cv_seminar_date, cv_seminars.details
	FROM cv_seminars INNER JOIN entitys ON cv_seminars.entity_id = entitys.entity_id;

CREATE VIEW vw_cv_projects AS
	SELECT entitys.entity_id, entitys.entity_name, cv_projects.cv_projectid, cv_projects.cv_project_name, 
		cv_projects.cv_project_date, cv_projects.details
	FROM cv_projects INNER JOIN entitys ON cv_projects.entity_id = entitys.entity_id;

CREATE VIEW vw_cv_referees AS
	SELECT entitys.entity_id, entitys.entity_name, cv_referees.cv_referee_id, cv_referees.cv_referee_name, 
		cv_referees.cv_referee_address, cv_referees.details
	FROM cv_referees INNER JOIN entitys ON cv_referees.entity_id = entitys.entity_id;

CREATE VIEW vw_skill_types AS
	SELECT skill_category.skill_category_id, skill_category.skill_category_name, skill_types.skill_type_id, 
		skill_types.skill_type_name, skill_types.basic, skill_types.intermediate, skill_types.advanced, skill_types.details
	FROM skill_types INNER JOIN skill_category ON skill_types.skill_category_id = skill_category.skill_category_id;

CREATE VIEW vw_skills AS
	SELECT vw_skill_types.skill_category_id, vw_skill_types.skill_category_name, vw_skill_types.skill_type_id, 
		vw_skill_types.skill_type_name, vw_skill_types.basic, vw_skill_types.intermediate, vw_skill_types.advanced, 
		entitys.entity_id, entitys.entity_name, skills.skill_id, skills.skill_level, skills.aquired, skills.training_date, 
		skills.trained, skills.training_institution, skills.training_cost, skills.details,
		(CASE WHEN skill_level = 1 THEN 'Basic' WHEN skill_level = 2 THEN 'Intermediate' 
			WHEN skill_level = 3 THEN 'Advanced' ELSE 'None' END) as skill_level_name,
		(CASE WHEN skill_level = 1 THEN vw_skill_types.Basic WHEN skill_level = 2 THEN vw_skill_types.Intermediate 
			WHEN skill_level = 3 THEN vw_skill_types.Advanced ELSE 'None' END) as skill_level_details
	FROM skills INNER JOIN entitys ON skills.entity_id = entitys.entity_id
		INNER JOIN vw_skill_types ON skills.skill_type_id = vw_skill_types.skill_type_id;

CREATE VIEW vw_offers AS
	SELECT entitys.entity_id as employer_id, entitys.entity_name as employer_name, 
		offers.offer_id, offers.offer_name, offers.opening_date, offers.closing_date, 
		offers.positions, offers.location, offers.details
	FROM offers INNER JOIN entitys ON offers.entity_id = entitys.entity_id;

CREATE VIEW vw_applications AS
	SELECT vw_offers.employer_id, vw_offers.employer_name, 
		vw_offers.offer_id, vw_offers.offer_name, vw_offers.opening_date, vw_offers.closing_date, 
		entitys.entity_id, entitys.entity_name, 
		applications.application_id, applications.application_date, applications.approve_status, 
		applications.workflow_table_id, applications.action_date, applications.applicant_comments, 
		applications.review
	FROM applications INNER JOIN vw_offers ON applications.offer_id = vw_offers.offer_id
		INNER JOIN entitys ON applications.entity_id = entitys.entity_id;
	

