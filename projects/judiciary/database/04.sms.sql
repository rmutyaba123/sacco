
ALTER TABLE orgs ADD sp_id	varchar(16);
ALTER TABLE orgs ADD service_id	varchar(32);
ALTER TABLE orgs ADD sender_name varchar(16);

ALTER TABLE address ADD CONSTRAINT address_org_id_mobile_key UNIQUE (org_id, mobile);

ALTER TABLE entitys ADD son varchar(6);

CREATE TABLE sms_trans (
	sms_trans_id			serial primary key,
	org_id					integer references orgs,
	message					varchar(2400),
	origin					varchar(50),
	sms_time				timestamp,
	client_id				varchar(50),
	msg_number				varchar(50),
	code					varchar(25),
	amount					real,
	in_words				varchar(240),
	narrative				varchar(240),
	sms_id					integer,
	sms_deleted				boolean default false not null,
	sms_picked				boolean default false not null,
	part_id					integer,
	part_message			varchar(240),
	part_no					integer,
	part_count				integer,
	complete				boolean default false,
	UNIQUE(origin, sms_time)
);
CREATE INDEX sms_trans_org_id ON sms_trans (org_id);

CREATE TABLE address_groups (
	address_group_id		serial primary key,
	org_id					integer references orgs,
	address_group_name		varchar(50),
	details					text
);
CREATE INDEX address_groups_org_id ON address_groups (org_id);

CREATE TABLE address_members (
	address_member_id		serial primary key,
	address_group_id		integer references address_groups,
	address_id				integer references address,
	org_id					integer references orgs,
	is_active				boolean default true,
	narrative				varchar(240),
	UNIQUE(address_group_id, address_id)
);
CREATE INDEX address_members_address_group_id ON address_members (address_group_id);
CREATE INDEX address_members_address_id ON address_members (address_id);
CREATE INDEX address_members_org_id ON address_members (org_id);

CREATE TABLE folders (
	folder_id				serial primary key,
	org_id					integer references orgs,
	folder_name				varchar(25) unique,
	details					text
);
CREATE INDEX folders_org_id ON folders (org_id);
INSERT INTO folders (folder_id, folder_name) VALUES (0, 'Outbox');
INSERT INTO folders (folder_id, folder_name) VALUES (1, 'Draft');
INSERT INTO folders (folder_id, folder_name) VALUES (2, 'Sent');
INSERT INTO folders (folder_id, folder_name) VALUES (3, 'Inbox');
INSERT INTO folders (folder_id, folder_name) VALUES (4, 'Action');

CREATE TABLE sms (
	sms_id					serial primary key,
	folder_id				integer references folders,
	address_group_id		integer references address_groups,
	entity_id				integer references entitys,
	org_id					integer references orgs,
	sms_origin				varchar(25),
	sms_number				varchar(25),
	sms_time				timestamp default now(),
	message_ready			boolean default false,
	sent					boolean default false,
	retries					integer default 0 not null,
	last_retry				timestamp default now(),
	
	senderAddress			varchar(64),
	serviceId				varchar(64), 
	spRevpassword			varchar(64), 
	dateTime				timestamp, 
	correlator				varchar(64), 
	traceUniqueID			varchar(64), 
	linkid					varchar(64), 
	spRevId					varchar(64), 
	spId					varchar(64), 
	smsServiceActivationNumber	varchar(64),

	message					text,
	details					text
);
CREATE INDEX sms_folder_id ON sms (folder_id);
CREATE INDEX sms_address_group_id ON sms (address_group_id);
CREATE INDEX sms_entity_id ON sms (entity_id);
CREATE INDEX sms_org_id ON sms (org_id);

CREATE TABLE sms_address (
	sms_address_id			serial primary key,
	sms_id					integer references sms,
	address_id				integer references address,
	org_id					integer references orgs,
	narrative				varchar(50),
	UNIQUE(sms_id, address_id)
);
CREATE INDEX sms_address_sms_id ON sms_address (sms_id);
CREATE INDEX sms_address_address_id ON sms_address (address_id);
CREATE INDEX sms_address_org_id ON sms_address (org_id);

CREATE VIEW vw_address_members AS
	SELECT address.address_id, address.address_name, address.mobile,
		address_groups.address_group_id, address_groups.address_group_name, 
		address_members.org_id, address_members.address_member_id, address_members.is_active, 
		address_members.narrative
	FROM address_members INNER JOIN address ON address_members.address_id = address.address_id
		INNER JOIN address_groups ON address_members.address_group_id = address_groups.address_group_id;

CREATE VIEW vw_sms AS
	SELECT folders.folder_id, folders.folder_name, sms.sms_id,
		sms.sms_number, sms.message_ready, sms.sent, sms.message, sms.details,
		sms.org_id, vw_address.address_name,	
		address_groups.address_group_id, address_groups.address_group_name
	FROM sms INNER JOIN folders ON sms.folder_id = folders.folder_id
		LEFT JOIN vw_address ON (sms.sms_number = vw_address.mobile) AND (sms.org_id = vw_address.org_id)
		LEFT JOIN address_groups ON sms.address_group_id = address_groups.address_group_id;

CREATE VIEW vw_sms_address AS
	SELECT folders.folder_id, folders.folder_name, sms.sms_id, sms.sms_number, 
		sms.message_ready, sms.sent, sms.message,
		address.address_id, address.address_name, address.mobile,
		sms_address.sms_address_id, sms_address.org_id, sms_address.narrative
	FROM sms INNER JOIN folders ON sms.folder_id = folders.folder_id
		INNER JOIN sms_address ON sms.sms_id = sms_address.sms_id
		INNER JOIN address ON sms_address.address_id = address.address_id;
	
CREATE OR REPLACE FUNCTION ins_sms_trans() RETURNS trigger AS $$
DECLARE
	rec RECORD;
	msg varchar(2400);
BEGIN
	IF(NEW.part_no = NEW.part_count) THEN
		IF(NEW.part_no = 1) THEN
			INSERT INTO sms (folder_id, sms_number, message)
			VALUES(3, NEW.origin, NEW.message);

			NEW.sms_picked = true;
		ELSE
			msg := '';
			FOR rec IN SELECT part_no, message FROM sms_trans WHERE (part_id = NEW.part_id) AND (origin = NEW.origin) AND (sms_picked = false)
			ORDER BY part_no LOOP
				msg := msg || rec.message;
			END LOOP;
			msg := msg || NEW.message;

			INSERT INTO sms (folder_id, sms_number, message)
			VALUES(3, NEW.origin, msg);

			UPDATE sms_trans SET sms_picked = true WHERE (part_id = NEW.part_id) AND (origin = NEW.origin) AND (sms_picked = false);
			NEW.sms_picked = true;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_sms_trans BEFORE INSERT ON sms_trans
    FOR EACH ROW EXECUTE PROCEDURE ins_sms_trans();

CREATE OR REPLACE FUNCTION ins_sms() RETURNS trigger AS $$
BEGIN
	IF(NEW.message is not null) THEN
		IF(upper(substr(NEW.message, 1, 2)) = '.C') THEN
			NEW.folder_id := 4;
		END IF;
		IF (NEW.sms_number is null) AND (NEW.senderAddress is not null) THEN
			NEW.sms_number := '254' || replace(NEW.senderAddress, 'tel:', '');
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_sms BEFORE INSERT ON sms
    FOR EACH ROW EXECUTE PROCEDURE ins_sms();

CREATE OR REPLACE FUNCTION aft_sms() RETURNS trigger AS $$
BEGIN
	IF (NEW.smsServiceActivationNumber = 'tel:20583') THEN
		INSERT INTO sms (org_id, folder_id, sms_origin, sms_number, linkid, message_ready, message)
		VALUES (0, 0, '20583', '254' || replace(NEW.senderAddress, 'tel:', ''), NEW.linkid, true, 'Thank you for contacting the Judiciary Service Desk. Your submission is being attended to. For further assistance call 020 2221221.');

		INSERT INTO sys_emailed (org_id, sys_email_id, table_name, table_id)
		VALUES (0, 1, 'sms', NEW.sms_id);
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_sms AFTER INSERT ON sms
    FOR EACH ROW EXECUTE PROCEDURE aft_sms();

CREATE OR REPLACE FUNCTION ins_member_address(varchar(12), varchar(32), varchar(32)) RETURNS varchar(120) AS $$
DECLARE
	v_address_member_id		integer;
	v_org_id				integer;
	msg 					varchar(120);
BEGIN

	SELECT org_id INTO v_org_id
	FROM address_groups WHERE address_group_id = CAST($3 as int);

	SELECT address_member_id INTO v_address_member_id
	FROM address_members
	WHERE (address_id = CAST($1 as int)) AND (address_group_id = CAST($3 as int));

	IF(v_address_member_id is null)THEN
		INSERT INTO address_members (address_group_id, address_id, org_id, is_active)
		VALUES(CAST($3 as int), CAST($1 as int), v_org_id, true);
		msg := 'Address added';
	ELSE
		msg := 'No duplicates address allowed';
		RAISE EXCEPTION 'No duplicates address allowed';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_sms_address(varchar(12), varchar(32), varchar(32)) RETURNS varchar(120) AS $$
DECLARE
	v_sms_address_id		integer;
	v_org_id				integer;
	msg 					varchar(120);
BEGIN
	SELECT org_id INTO v_org_id
	FROM sms WHERE sms_id = CAST($3 as int);

	SELECT sms_address_id INTO v_sms_address_id
	FROM sms_address
	WHERE (address_id = CAST($1 as int)) AND (sms_id = CAST($3 as int));

	IF(v_sms_address_id is null)THEN
		INSERT INTO sms_address (sms_id, address_id, org_id)
		VALUES(CAST($3 as int), CAST($1 as int), v_org_id);
		msg := 'Address Added';
	ELSE
		msg := 'No duplicates address allowed';
		RAISE EXCEPTION 'No duplicates address allowed';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;



