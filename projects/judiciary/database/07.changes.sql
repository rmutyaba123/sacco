CREATE OR REPLACE FUNCTION ins_court_stations() RETURNS trigger AS $$
DECLARE
	v_org_name		varchar(320);
BEGIN

	SELECT court_rank_name INTO v_org_name
	FROM court_ranks
	WHERE court_rank_id = NEW.court_rank_id;

	v_org_name := v_org_name || ' ' || NEW.court_station_name;
	
	IF (TG_OP = 'INSERT')THEN
		INSERT INTO orgs (org_id, currency_id, org_name, is_default, logo, org_sufix)
		VALUES (NEW.court_station_id, 1, v_org_name, false, 'logo.png', 'CS');

		NEW.org_id := NEW.court_station_id;
	END IF;

	IF (TG_OP = 'UPDATE')THEN
		UPDATE orgs SET org_name = v_org_name WHERE org_id = NEW.org_id;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

