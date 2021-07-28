ALTER TABLE sms ADD addresses				text;

CREATE OR REPLACE FUNCTION ins_sms() RETURNS trigger AS $$
BEGIN
	
	IF(NEW.addresses is not null)THEN
		IF(NEW.sms_numbers is null) THEN
			NEW.sms_numbers := NEW.addresses;
		ELSE
			NEW.sms_numbers := NEW.sms_numbers || ',' || NEW.addresses;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER ins_sms ON sms;
CREATE TRIGGER ins_sms BEFORE INSERT OR UPDATE ON sms
    FOR EACH ROW EXECUTE PROCEDURE ins_sms();