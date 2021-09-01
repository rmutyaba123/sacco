---Project Database File

CREATE TABLE applicants (
	applicant_id			serial  primary key,
	entity_id				integer references entitys,
	org_id					integer references orgs,

	person_title			varchar(7),
	surname					varchar(50) not null,
	first_name				varchar(50) not null,
	middle_name				varchar(50),
	applicant_email			varchar(50) not null unique,
	applicant_phone			varchar(50) not null unique,
	date_of_birth			date,
	gender					varchar(1),
	nationality				char(2) references sys_countrys,
	picture_file			varchar(32),
	first_password			varchar(32),
	
	application_amount		real default 50 not null,
	is_paid					boolean default false not null,
	
	created					timestamp default current_timestamp,
	details					text
);
CREATE INDEX applicants_entity_id ON applicants(entity_id);
CREATE INDEX applicants_org_id ON applicants(org_id);

CREATE TABLE prices (
	price_id				serial primary key,
	org_id					integer references orgs,
	price_name				varchar(50),
	max_range				real default 0 not null,
	price_amount			real default 0 not null,
	details					text
);

CREATE TABLE categorys (
	category_id				serial primary key,
	org_id					integer references orgs,
	category_name			varchar(50),
	question_duration		integer,
	details					text
);

CREATE TABLE questions (
	question_id				serial primary key,
	category_id				integer references categorys,
	org_id					integer references orgs,
	question				text,
	option_a				varchar(512),
	option_b				varchar(512),
	option_c				varchar(512),
	option_d				varchar(512),
	correct_option			char(1)
);

CREATE TABLE games (
	game_id					serial primary key,
	entity_id				integer references entitys,
	category_id				integer references categorys,
	org_id					integer references orgs,
	game_date				timestamp default current_timestamp not null,
	game_charge				real default 100 not null,
	game_results			real default 0 not null,
	price_amount			real default 0 not null
);

CREATE TABLE answers (
	answer_id				serial primary key,
	game_id					integer references games,
	question_id				integer references questions,
	org_id					integer references orgs,
	answer					char(1)
);

CREATE TABLE imp_questions (
	imp_question_id			serial primary key,
	category_id				integer,
	qid						varchar(250),
	question				varchar(1024),
	multiple_choices		varchar(250),
	answer					varchar(250)
);

CREATE VIEW vw_questions AS
	SELECT categorys.category_id, categorys.category_name, 
		orgs.org_id, orgs.org_name, questions.question_id, 
		questions.question, questions.option_a, questions.option_b, questions.option_c, questions.option_d, 
		questions.correct_option
	FROM questions INNER JOIN categorys ON questions.category_id = categorys.category_id
		INNER JOIN orgs ON questions.org_id = orgs.org_id;

CREATE VIEW vw_games AS
	SELECT entitys.entity_id, entitys.entity_name, 
		categorys.category_id, categorys.category_name,
		orgs.org_id, orgs.org_name, 
		games.game_id, games.game_date, games.game_charge, games.game_results, games.price_amount
	FROM games INNER JOIN entitys ON games.entity_id = entitys.entity_id
		INNER JOIN categorys ON games.category_id = categorys.category_id
		INNER JOIN orgs ON games.org_id = orgs.org_id;

CREATE VIEW vw_answers AS
	SELECT vw_games.game_id, vw_games.entity_id, vw_games.entity_name,
		vw_questions.category_id, vw_questions.category_name, 
		vw_questions.question_id, vw_questions.question,
		orgs.org_id, orgs.org_name, 
		answers.answer_id, answers.answer
	FROM answers INNER JOIN vw_games ON answers.game_id = vw_games.game_id
		INNER JOIN vw_questions ON answers.question_id = vw_questions.question_id
		INNER JOIN orgs ON answers.org_id = orgs.org_id;


CREATE OR REPLACE FUNCTION ins_applicants() RETURNS trigger AS $$
DECLARE
	v_org_id				integer;
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_sys_email_id			integer;
	v_applicant_name		varchar(120);
BEGIN

	IF(NEW.Middle_name is null)THEN
		v_applicant_name := NEW.First_name || ' ' || NEW.Surname;
	ELSE
		v_applicant_name := NEW.First_name || ' ' || NEW.Middle_name || ' ' || NEW.Surname;
	END IF;
	
	IF (TG_OP = 'INSERT') THEN
		IF(NEW.entity_id IS NULL) THEN
			SELECT entity_id INTO v_entity_id
			FROM entitys
			WHERE (trim(lower(user_name)) = trim(lower(NEW.applicant_email)));
				
			IF(v_entity_id is null)THEN
				v_org_id := NEW.org_id;
				IF(v_org_id is null)THEN
					SELECT min(org_id) INTO v_org_id
					FROM orgs WHERE (is_default = true);
				END IF;
				
				SELECT entity_type_id INTO v_entity_type_id
				FROM entity_types 
				WHERE (org_id = v_org_id) AND (use_key_id = 4);

				NEW.entity_id := nextval('entitys_entity_id_seq');

				INSERT INTO entitys (entity_id, org_id, entity_type_id, use_key_id,
					entity_name, User_name, primary_email, 
					primary_telephone, function_role, first_password)
				VALUES (NEW.entity_id, v_org_id, v_entity_type_id, 4, 
					v_applicant_name, lower(NEW.applicant_email), lower(NEW.applicant_email), 
					NEW.applicant_phone, 'applicant', NEW.first_password);
			ELSE
				RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
			END IF;
		END IF;
		
		SELECT sys_email_id INTO v_sys_email_id FROM sys_emails
		WHERE (use_type = 1) AND (org_id = NEW.org_id);

		INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name, email_type)
		VALUES (v_sys_email_id, NEW.org_id, NEW.entity_id, 'applicant', 1);
	ELSIF (TG_OP = 'UPDATE') THEN
		UPDATE entitys  SET entity_name = v_applicant_name
		WHERE entity_id = NEW.entity_id;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_applicants BEFORE INSERT OR UPDATE ON applicants
    FOR EACH ROW EXECUTE PROCEDURE ins_applicants();

CREATE FUNCTION aft_games() RETURNS trigger AS $$
DECLARE
	v_random_id				int;
	v_question_id			int;
	i						int;
BEGIN

	FOR i IN 1..10 LOOP
		v_random_id := trunc(random() * 100)::int;
		
		SELECT question_id INTO v_question_id
		FROM questions
		WHERE (category_id = NEW.category_id) AND (question_id = v_random_id);

		IF(v_question_id is not null)THEN
			INSERT INTO answers (game_id, question_id, org_id)
			VALUES (NEW.game_id, v_question_id, NEW.org_id);
		END IF;
	END LOOP;

	RETURN null;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_games AFTER INSERT ON games
	FOR EACH ROW EXECUTE PROCEDURE aft_games();


CREATE FUNCTION copy_question_over() RETURNS varchar(120) AS $$
DECLARE
	myrec 			RECORD;
	v_question		varchar(250);
BEGIN

	v_question := null;
	FOR myrec IN
		SELECT imp_question_id, qid, question, multiple_choices
		FROM imp_questions ORDER BY imp_question_id
    LOOP

		IF(myrec.question is null)THEN
			UPDATE imp_questions SET question = v_question
			WHERE (imp_question_id = myrec.imp_question_id);
		ELSE
			v_question := myrec.question;
		END IF;
	END LOOP;

    RETURN 'Done';
END;
$$ LANGUAGE plpgsql;

imp_questions
INSERT INTO imp_Entertainment (qid,question,multiple_choices,answer) VALUES (?,?,?,?)
Sports
Sports
Sports
INSERT INTO imp_Sports (qid,question,multiple_choices,answer) VALUES (?,?,?,?)
General_Knowledge
General_Knowledge
General_Knowledge
INSERT INTO imp_General_Knowledge (qid,question,multiple_choices,answer) VALUES (?,?,?,?)
Science_Tech
Science_Tech
Science_Tech
INSERT INTO imp_Science_Tech (qid,question,multiple_choices,answer) VALUES (?,?,?,?)
Kenya
Kenya
Kenya
INSERT INTO imp_Kenya (qid,question,multiple_choices,answer) VALUES (?,?,?,?)
People_Places
People_Places
People_Places
INSERT INTO imp_People_Places (qid,question,multiple_choices,answer) VALUES (?,?,?,?)

