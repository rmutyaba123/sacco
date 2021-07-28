
CREATE TABLE aptitude_tests (
	aptitude_test_id		serial primary key,
	org_id					integer references orgs,
	aptitude_test_name		character(50) NOT NULL,
	display					boolean,
	pass_mark				integer,
	test_objectives			text NOT NULL,
	sample_jsp				text NOT NULL,
	sample_js				text,
	sample_css				text,
	sample_sql				text
);
CREATE INDEX aptitude_tests_org_id ON aptitude_tests (org_id);

CREATE TABLE aptitude_grades (
	aptitude_grade_id		serial primary key,
	aptitude_test_id		integer references aptitude_tests,
	user_id					integer references entitys,
	graded_by 				integer references entitys,
	org_id					integer references orgs,
	date_taken 				date,
	date_graded 			date,
	grade 					integer,
	review_comment 			text,
	UNIQUE(aptitude_test_id, user_id)
);
CREATE INDEX aptitude_grades_aptitude_test_id ON aptitude_grades (aptitude_test_id);
CREATE INDEX aptitude_grades_user_id ON aptitude_grades (user_id);
CREATE INDEX aptitude_grades_graded_by ON aptitude_grades (graded_by);
CREATE INDEX aptitude_grades_org_id ON aptitude_grades (org_id);

CREATE TABLE aptitude_ongoing (
	aptitude_ongoing_id		serial primary key,
	aptitude_test_id		integer references aptitude_tests,
	user_id					character(30),
	UNIQUE (aptitude_test_id, user_id)
);

CREATE VIEW vw_aptitude_grades AS 
	SELECT aptitude_tests.aptitude_test_id, aptitude_tests.aptitude_test_name,
		aptitude_tests.pass_mark,
		aptitude_grades.user_id, entitys.user_name, entitys.entity_name,
		aptitude_grades.graded_by, grader_entity.entity_name AS graded_by_name,
		aptitude_grades.aptitude_grade_id, aptitude_grades.grade, 
		aptitude_grades.date_taken, aptitude_grades.date_graded, aptitude_grades.org_id
	FROM aptitude_grades INNER JOIN aptitude_tests ON aptitude_grades.aptitude_test_id = aptitude_tests.aptitude_test_id
		INNER JOIN entitys ON entitys.entity_id = aptitude_grades.user_id
		LEFT JOIN entitys as grader_entity ON grader_entity.entity_id = aptitude_grades.user_id;
		
CREATE VIEW vw_aptitude_ongoing AS 
	SELECT aptitude_ongoing.aptitude_ongoing_id, aptitude_tests.aptitude_test_name AS aptitude_test_id,
		entitys.entity_name AS user_id
	FROM aptitude_ongoing JOIN entitys ON entitys.user_name::bpchar = aptitude_ongoing.user_id
		JOIN aptitude_tests ON aptitude_tests.aptitude_test_id = aptitude_ongoing.aptitude_test_id;

		
CREATE OR REPLACE FUNCTION apt_grade_change() RETURNS trigger AS $$ 
BEGIN

	IF (NEW.grade !=0) THEN
		INSERT INTO sys_emailed(sys_email_id, org_id, table_id, table_name)
		VALUES (3, NEW.org_id, NEW.aptitude_grade_id, 'aptitude_grades' );
	END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;


