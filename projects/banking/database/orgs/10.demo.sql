

CREATE OR REPLACE FUNCTION ins_password() RETURNS trigger AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (trim(lower(user_name)) = trim(lower(NEW.user_name)))
		AND entity_id <> NEW.entity_id;
		
	IF(v_entity_id is not null)THEN
		RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
	END IF;

	NEW.first_password := 'baraza';
	NEW.entity_password := md5('baraza');

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;


UPDATE entitys SET first_password = 'baraza';


CREATE OR REPLACE FUNCTION ins_orgs() RETURNS trigger AS $$
BEGIN

	NEW.parent_org_id := 1;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_orgs BEFORE INSERT OR UPDATE ON orgs
  FOR EACH ROW EXECUTE PROCEDURE ins_orgs();
