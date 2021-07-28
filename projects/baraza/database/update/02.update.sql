ALTER TABLE orgs ADD	department_filter		boolean default false not null;

ALTER TABLE entitys ADD 	last_login				timestamp;

CREATE TABLE entity_orgs (
	entity_org_id			serial primary key,
	entity_id				integer not null references entitys,
	org_id					integer references orgs,
	details					text,
	UNIQUE(entity_id, org_id)
);
CREATE INDEX entity_orgs_entity_id ON entity_orgs (entity_id);
CREATE INDEX entity_orgs_org_id ON entity_orgs (org_id);

DROP  TABLE sys_menu_msg;
CREATE TABLE sys_menu_msg (
	sys_menu_msg_id			serial primary key,
	menu_id					varchar(16) not null,
	menu_name				varchar(50) not null,
	xml_file				varchar(50) not null,
	msg						text
);

CREATE VIEW vw_entity_orgs AS
	SELECT entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.super_user, entitys.entity_leader,
		entitys.date_enroled, entitys.is_active, entitys.entity_password, entitys.first_password,
		entitys.function_role, entitys.use_key_id, entitys.primary_email, entitys.primary_telephone,
		orgs.org_id, orgs.org_name, orgs.org_full_name,
		entity_orgs.entity_org_id, entity_orgs.details
	FROM entity_orgs INNER JOIN entitys ON entitys.entity_id = entity_orgs.entity_id
		INNER JOIN orgs ON entity_orgs.org_id = orgs.org_id;
		

ALTER TABLE sys_logins ADD 	phone_serial_number		varchar(50);
ALTER TABLE sys_logins ADD 	correct_login			boolean default true not null;

CREATE TABLE entity_reset (
	entity_reset_id			serial primary key,
	entity_id				integer references entitys,
	org_id					integer references orgs,
	request_email			varchar(320),
	request_time			timestamp default now(),
	login_ip				varchar(64),
	phone_serial_number		varchar(50),
	narrative				varchar(240)
);
CREATE INDEX entity_reset_entity_id ON entity_reset (entity_id);
CREATE INDEX entity_reset_org_id ON entity_reset (org_id);

CREATE OR REPLACE FUNCTION add_sys_login(varchar(120)) RETURNS integer AS $$
DECLARE
	v_sys_login_id			integer;
	v_entity_id				integer;
BEGIN
	SELECT entity_id INTO v_entity_id
	FROM entitys WHERE user_name = $1;

	v_sys_login_id := nextval('sys_logins_sys_login_id_seq');

	INSERT INTO sys_logins (sys_login_id, entity_id)
	VALUES (v_sys_login_id, v_entity_id);

	UPDATE entitys SET last_login = current_timestamp
	WHERE (entity_id = v_entity_id);

	return v_sys_login_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION password_validate(varchar(64), varchar(32), varchar(32), varchar(32)) RETURNS integer AS $$
DECLARE
	v_entity_id			integer;
	v_entity_password	varchar(64);
BEGIN

	SELECT entity_id, entity_password INTO v_entity_id, v_entity_password
	FROM entitys WHERE (user_name = $1);

	IF(v_entity_id is null)THEN
		v_entity_id = -1;
	ELSIF(md5($2) != v_entity_password) THEN
		INSERT INTO sys_logins (entity_id, login_ip, phone_serial_number, correct_login)
		VALUES (v_entity_id, $3, $4, false);
		v_entity_id = -1;
	ELSE
		INSERT INTO sys_logins (entity_id, login_ip, phone_serial_number, correct_login)
		VALUES (v_entity_id, $3, $4, true);
	END IF;

	return v_entity_id;
END;
$$ LANGUAGE plpgsql;


