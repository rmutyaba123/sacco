----Functions
----tenants trigger and functions
CREATE OR REPLACE FUNCTION aft_tenants() RETURNS trigger AS $$
DECLARE
	v_entity_type_id		integer;
	v_entity_id				integer;
	v_user_name				varchar(32);
BEGIN

	IF((TG_OP = 'INSERT'))THEN
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 6);
		v_entity_id := nextval('entitys_entity_id_seq');
		v_user_name := 'OR' || NEW.org_id || 'NT' || v_entity_id;
		
		INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, tenant_id, entity_name, user_name, primary_email, primary_telephone, function_role)
		VALUES (v_entity_id, NEW.org_id, 6, v_entity_type_id, NEW.tenant_id, NEW.tenant_name, v_user_name, lower(trim(NEW.tenant_email)), NEW.telephone_number, 'tenant');
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_tenants AFTER INSERT OR UPDATE ON tenants
	FOR EACH ROW EXECUTE PROCEDURE aft_tenants();
	
	
CREATE OR REPLACE FUNCTION get_tenant_id(integer) RETURNS integer AS $$
	SELECT tenant_id FROM entitys WHERE (entity_id = $1);
$$ LANGUAGE SQL;

----property_owner/landlord/client trigger and functions
CREATE OR REPLACE FUNCTION aft_landlord() RETURNS trigger AS $$
DECLARE
	v_entity_type_id		integer;
	v_entity_id				integer;
	v_user_name				varchar(32);
BEGIN

	IF((TG_OP = 'INSERT'))THEN
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 2);
		v_entity_id := nextval('entitys_entity_id_seq');
		v_user_name := 'OR' || NEW.org_id || 'NL' || v_entity_id;
		
		INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, landlord_id, entity_name, user_name, primary_email, primary_telephone, function_role)
		VALUES (v_entity_id, NEW.org_id, 2, v_entity_type_id, NEW.landlord_id, NEW.landlord_name, v_user_name, lower(trim(NEW.landlord_email)), NEW.telephone_number, 'client');
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_landlord AFTER INSERT OR UPDATE ON landlord
	FOR EACH ROW EXECUTE PROCEDURE aft_landlord();
	
	
CREATE OR REPLACE FUNCTION get_landlord_id(integer) RETURNS integer AS $$
	SELECT landlord_id FROM entitys WHERE (entity_id = $1);
$$ LANGUAGE SQL;


---FUNCTION to generate_rentals
CREATE OR REPLACE FUNCTION generate_rentals(varchar(12), varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	v_total_rent		float;
	myrec				RECORD;
	msg					varchar(120);
BEGIN
	IF ($3 = '1') THEN
	SELECT period_id INTO v_period_id FROM period_rentals WHERE period_id = $1::int AND rental_id = rental_id;
		IF(v_period_id is NULL) THEN
			INSERT INTO period_rentals (period_id, org_id, tenant_id, property_id, rental_id, rental_amount, service_fees, commision, sys_audit_trail_id)
			SELECT $1::int, org_id, tenant_id, property_id,rental_id, rental_value, service_fees, commision_value, $5::int
				FROM rentals 
				WHERE is_active = true;
			msg := 'Rentals generated';
		ELSE 
			msg := 'Rentals exists';
		END IF;		
	END IF;
	return msg;
END;
$$ LANGUAGE plpgsql;


---Update rentals trigger
CREATE OR REPLACE FUNCTION upd_units() RETURNS trigger AS $$
DECLARE
	reca 		RECORD;
BEGIN

	FOR reca IN SELECT unit_id,property_id,org_id,rental_value,service_fees 
	FROM units
	LOOP
		UPDATE rentals SET rental_value = reca.rental_value, service_fees = reca.service_fees
		WHERE unit_id = reca.unit_id;
	END LOOP;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_units AFTER UPDATE ON units
    FOR EACH ROW EXECUTE PROCEDURE upd_units();


---- insert rental trigger
CREATE OR REPLACE FUNCTION ins_rentals() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
BEGIN
	SELECT rental_value, service_fees INTO rec
	FROM units
	WHERE unit_id = NEW.unit_id;

	IF(NEW.rental_value is null)THEN
		NEW.rental_value := rec.rental_value;
	END IF;
	IF(NEW.service_fees is null)THEN
		NEW.service_fees := rec.service_fees;
	END IF;

	UPDATE units SET is_vacant = false WHERE unit_id = NEW.unit_id;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_rentals BEFORE INSERT ON rentals
    FOR EACH ROW EXECUTE PROCEDURE ins_rentals();

---trigger function on insert period rentals
CREATE OR REPLACE FUNCTION ins_period_rentals() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
BEGIN
	SELECT rental_value, service_fees, commision_value INTO rec
	FROM rentals
	WHERE rental_id = NEW.rental_id;

	IF(NEW.rental_amount is null)THEN
		NEW.rental_amount := rec.rental_value;
	END IF;
	IF(NEW.service_fees is null)THEN
		NEW.service_fees := rec.service_fees;
	END IF;
	IF(NEW.commision is null)THEN
		NEW.commision := rec.commision_value;
	END IF;

	IF(NEW.commision is null)THEN NEW.commision := 0; END IF;		

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_period_rentals BEFORE INSERT OR UPDATE ON period_rentals
    FOR EACH ROW EXECUTE PROCEDURE ins_period_rentals();

---Audit period rentals  function trigger   
CREATE OR REPLACE FUNCTION aud_period_rentals() RETURNS trigger AS $$
BEGIN

	INSERT INTO log_period_rentals (period_rental_id, rental_id, period_id, 
		sys_audit_trail_id, org_id, rental_amount, service_fees,
		repair_amount, status, commision, narrative)
	VALUES (OLD.period_rental_id, OLD.rental_id, OLD.period_id, 
		OLD.sys_audit_trail_id, OLD.org_id, OLD.rental_amount, OLD.service_fees,
		OLD.repair_amount, OLD.status, OLD.commision, OLD.narrative);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aud_period_rentals AFTER UPDATE OR DELETE ON period_rentals
    FOR EACH ROW EXECUTE PROCEDURE aud_period_rentals();
	

CREATE OR REPLACE FUNCTION get_total_remit(float) RETURNS float AS $$
    SELECT COALESCE(SUM(rent_to_remit), 0)::float 
	FROM vw_period_rentals
	WHERE (is_active = true) AND (period_id = $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_periodic_remmit(float) RETURNS float AS $$
  SELECT sum(period_rentals.rental_amount + period_rentals.commision)::float
	FROM vw_property 
		INNER JOIN period_rentals ON period_rentals.property_id = vw_property.property_id
			GROUP BY vw_property.property_id,period_rentals.period_id
$$ LANGUAGE SQL;


---Posting Rentals
CREATE OR REPLACE FUNCTION post_period_rentals(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		v_org_id			integer;
		v_use_key_id		integer;
		v_currency_id		integer;
		v_client_id			integer;
		v_status			varchar(50);
		v_total_rent		float;
		v_total_remmit		float;
		myrec				RECORD;
		msg					varchar(120);
	BEGIN
		IF ($3::int = 2) THEN
			SELECT status INTO v_status FROM period_rentals WHERE period_rental_id = $1::int;
			IF (v_status = 'Draft') THEN
				SELECT currency_id INTO v_currency_id FROM orgs WHERE is_active = true;

				FOR myrec IN SELECT org_id,property_id,rental_id,period_id,rental_amount,service_fees,
				repair_amount,commision,status,narrative,sys_audit_trail_id FROM period_rentals
				WHERE status = 'Draft' AND period_rental_id = $1::int

				LOOP
										
					v_total_rent = myrec.rental_amount+myrec.service_fees+myrec.repair_amount;
					v_total_remmit= myrec.rental_amount-myrec.commision;

					---Debit all tenants rental accounts
						INSERT INTO payments (payment_type_id,org_id,property_id,rental_id,period_id,currency_id,
							tx_type,account_credit,account_debit,activity_name)
						VALUES(5,myrec.org_id,myrec.property_id,myrec.rental_id,myrec.period_id,v_currency_id,
							1,0,v_total_rent::float,'Rental Billing');

					---Credit all property owners/Landlord/Clients Property accounts
						INSERT INTO remmitance (payment_type_id,org_id,property_id,rental_id,period_id,currency_id,
							tx_type,account_credit,account_debit,activity_name)
						VALUES(8,myrec.org_id,myrec.property_id,myrec.rental_id,myrec.period_id,v_currency_id,
							-1,v_total_remmit::float,0,'Property Billing');				
						
					UPDATE period_rentals SET status = 'Posted' WHERE period_rental_id = $1::int;
				END LOOP;
					msg := 'Period Rental Posted';
			ELSE
				msg := 'Period Rental Already Posted';
			END IF;
		END IF;
		return msg;
	END;
$$ LANGUAGE plpgsql;

---- Activating entity associated records; Tenants, property, landlord
CREATE OR REPLACE FUNCTION un_archive (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
	BEGIN
		--- Activate Tenants
		IF($3::integer = 1)THEN
			UPDATE tenants SET is_active = true WHERE tenant_id = $1::int;
				msg := 'Tenant Activated...';
		END IF;

		---Activate Property
		IF($3::integer = 2)THEN
			UPDATE property SET is_active = true WHERE property_id = $1::int;
		msg := 'Property Activated';
		END IF;

		---Activate Property Owner/Landlord/Client
		IF($3::integer = 3)THEN
			UPDATE landlord SET is_active = true WHERE landlord_id = $1::int;
			msg := 'Landlord/Client Activated';
		END IF;

		---Activate unit
		IF($3::integer = 4)THEN
			UPDATE units SET is_active = true WHERE unit_id = $1::int;
			msg := 'Unit  Activated';
		END IF;
		
RETURN msg;
END;
$$ LANGUAGE plpgsql;

---- Archiving tenant records
CREATE OR REPLACE FUNCTION archive_tenant (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
		myrec 			RECORD;
		reca			RECORD;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT rental_id, is_active INTO myrec FROM rentals WHERE tenant_id = $1::int;
			IF (myrec.is_active = true) THEN
				msg := 'The Tenant Has an active Rental..';
				RAISE EXCEPTION '%',msg;
			ELSE
				UPDATE tenants SET is_active = false WHERE tenant_id = $1::int;
				msg := 'Tenant Deactivated...';
			END IF;
		END IF;

		---tenancy termination
		IF($3::integer = 2)THEN
			SELECT rental_id, is_active,unit_id,tenant_id INTO reca FROM rentals WHERE rental_id = $1::int;
			UPDATE rentals SET is_active = false WHERE rental_id = $1::int;
			UPDATE units SET is_vacant = true WHERE unit_id = reca.unit_id;
			UPDATE tenants SET is_active = false WHERE tenant_id = reca.tenant_id;
			msg := 'Tenant Terminated Successfully....';
		END IF;
		
RETURN msg;
END;
$$ LANGUAGE plpgsql;

---- Archiving Landlord 
CREATE OR REPLACE FUNCTION archive_landlord (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
		myrec 			RECORD;
		reca			RECORD;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT property_id, is_active INTO myrec FROM property WHERE landlord_id = $1::int;
			IF (myrec.is_active = true) THEN
				msg := 'The Landlord Has an active Property..';
				RAISE EXCEPTION '%',msg;
			ELSE
				UPDATE landlord SET is_active = false WHERE landlord_id = $1::int;
				msg := 'Landlord Deactivated...';
			END IF;
		END IF;
		
RETURN msg;
END;
$$ LANGUAGE plpgsql;

---- Archiving property
CREATE OR REPLACE FUNCTION archive_property (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
		myrec 			RECORD;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT rental_id, is_active INTO myrec FROM rentals WHERE property_id = $1::int;
			IF (myrec.is_active = true) THEN
				msg := 'The Property has active Rentals.. Thus cannot be archived!';
				RAISE EXCEPTION '%',msg;
			ELSE
				UPDATE property SET is_active = false WHERE property_id = $1::int;
				msg := 'Property Deactivated...';
			END IF;
		END IF;
		
RETURN msg;
END;
$$ LANGUAGE plpgsql;

---- Archiving Units 
CREATE OR REPLACE FUNCTION archive_unit (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
		myrec 			RECORD;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT unit_id, is_active,is_vacant INTO myrec FROM units WHERE unit_id = $1::int;
			IF (myrec.is_vacant = false) THEN
				msg := 'The Unit is not vacant thus cannot be archived..';
				RAISE EXCEPTION '%',msg;
			ELSE
				UPDATE units SET is_active = false WHERE unit_id = $1::int;
				msg := 'Unit(s) Deactivated...';
			END IF;
		END IF;
		
RETURN msg;
END;
$$ LANGUAGE plpgsql;

---Rental transfer function
CREATE OR REPLACE FUNCTION rental_transfer (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg				varchar(120);
		myrec 			RECORD;
		reca			RECORD;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT rental_id, is_active,unit_id,tenant_id,org_id INTO myrec FROM rentals WHERE rental_id = $1::int;
			IF (myrec.is_active = true) THEN
				INSERT INTO rental_transfer(tenant_id,org_id,rental_id,from_unit_id) VALUES
							(myrec.tenant_id,myrec.org_id,myrec.rental_id,myrec.unit_id);
				msg := 'The rental transfer recorded...';
			ELSE
				msg := 'The rental is not active...';
				RAISE EXCEPTION '%',msg;
			END IF;
		END IF;

		IF($3::integer = 2)THEN
			SELECT rental_transfer_id, rental_id, unit_id, property_id, from_unit_id INTO reca FROM rental_transfer 
			WHERE rental_transfer_id= $1::int;

			IF ((reca.unit_id is null) AND (reca.property_id is null)) THEN				
				RAISE EXCEPTION 'Tranfer to new unit cannot be null...';
			ELSE
				UPDATE rentals SET unit_id = reca.unit_id, property_id = reca.property_id
				WHERE rental_id = reca.rental_id;

				UPDATE rental_transfer SET transfer_date = current_date, status = 'Completed',
				narrative = 'Tranfer Completed Successfully'
				WHERE rental_transfer_id = reca.rental_transfer_id;

				UPDATE units SET is_vacant = true, is_active = true
				WHERE unit_id = reca.from_unit_id;
				
				UPDATE units SET is_vacant = false
				WHERE unit_id = reca.unit_id;

				msg := 'Tranfer Completed Successfully...';
				
			END IF;
		END IF;			
RETURN msg;
END;
$$ LANGUAGE plpgsql;


---associative functions
CREATE OR REPLACE FUNCTION payment_number()  RETURNS trigger AS $$
DECLARE
	rnd 			integer;
	receipt_no  	varchar(12);
BEGIN
	receipt_no := trunc(random()*1000);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);
	receipt_no := receipt_no || trunc(random()*1000);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);
	rnd := trunc(65+random()*25);
	receipt_no := receipt_no || chr(rnd);

	NEW.payment_number:=receipt_no;
	---RAISE EXCEPTION '%',receipt_no;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-----payment number
 CREATE TRIGGER payment_number BEFORE INSERT ON payments
 FOR EACH ROW
 EXECUTE PROCEDURE payment_number();
----remmitance number
 CREATE TRIGGER payment_number BEFORE INSERT ON remmitance
 FOR EACH ROW
 EXECUTE PROCEDURE payment_number();

---Rent payments insert trigger
CREATE OR REPLACE FUNCTION ins_payments() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
	msg					varchar(120);
	v_status  			varchar(50);
BEGIN
	
	IF((NEW.payment_id is not null) AND (NEW.tx_type = 1))THEN
		SELECT sum(account_credit - account_debit) INTO NEW.balance
		FROM payments
		WHERE (payment_id < NEW.payment_id) AND (rental_id = NEW.rental_id);

	ELSIF((NEW.payment_id is not null) AND (NEW.tx_type = -1))THEN
		SELECT sum(account_debit - account_credit) INTO NEW.balance
		FROM payments
		WHERE (payment_id < NEW.payment_id) AND (NEW.tx_type = -1);
	END IF;

	IF(NEW.balance is null)THEN
		NEW.balance := 0;
	END IF;

	IF((NEW.payment_id is not null) AND (NEW.tx_type = 1))THEN
		NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);

	ELSIF ((NEW.payment_id is not null) AND (NEW.tx_type = -1))THEN
		NEW.balance := NEW.balance + (NEW.account_debit - NEW.account_credit);
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_payments BEFORE INSERT OR UPDATE ON payments
    FOR EACH ROW EXECUTE PROCEDURE ins_payments();

----Remmitance trigger to calculate the balances
CREATE OR REPLACE FUNCTION ins_remmitance() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
	msg					varchar(120);
	v_status  			varchar(50);
BEGIN
	
	IF(NEW.remmitance_id is not null) THEN
		SELECT sum(account_credit - account_debit) INTO NEW.balance
		FROM remmitance
		WHERE (remmitance_id < NEW.remmitance_id) AND (property_id = NEW.property_id);
	END IF;

	IF(NEW.balance is null)THEN
		NEW.balance := 0;
	END IF;

	IF(NEW.remmitance_id is not null)THEN
		NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_remmitance BEFORE INSERT OR UPDATE ON remmitance
    FOR EACH ROW EXECUTE PROCEDURE ins_remmitance();

---- Disable editing records after posting
CREATE OR REPLACE FUNCTION aft_payments() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
	msg					varchar(120);
	v_status  			varchar(50);
BEGIN
	SELECT activity_name INTO v_status FROM payments;
		IF(v_status = 'Rental Billing')THEN
			msg := 'All Billing activity cannot be changed after posting..';
			RAISE EXCEPTION '%',msg;
		END IF;	
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_payments BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE PROCEDURE aft_payments();

----checking the mpesa code whether it exists
CREATE OR REPLACE FUNCTION ins_mpesa_payment() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
	msg					varchar(120);
	v_mpesa_code 		varchar(50);
	v_period_id_a 		integer;
	v_amount 			float;
	v_phone_number		varchar(50);
	v_tenant_id 		integer;
	v_rental_id 		integer;
	v_org_id 			integer;
	v_period_id 		integer;
	v_sent_date 		date;
BEGIN
	IF((TG_OP = 'INSERT'))THEN
		SELECT mpesa_code INTO v_mpesa_code
		FROM mpesa_payment;

		SELECT period_id INTO v_period_id_a
		FROM periods
		WHERE (opened = true) AND (activated = true) AND (closed = false)
		AND (start_date <= current_date) AND (end_date >= current_date);
		---check for the period
		IF(v_period_id_a is null) THEN
			RAISE EXCEPTION 'There is no Open and Active period/Month for the payment date of; %', NEW.sent_date;
		END IF;
		--- check for the mpesa code
		IF(NEW.mpesa_code = v_mpesa_code) THEN			
			msg := 'The Mpesa payment message has already been Sent.. ';
			RAISE EXCEPTION '%', msg;
		END IF;

		---Update the table when phone number matches and draft when no match
		v_sent_date := to_date(right (NEW.sent_date, 8), 'YY MM DD');

		SELECT tenant_id INTO v_tenant_id FROM tenants
		WHERE telephone_number = NEW.phone_number;

		SELECT rental_id, org_id INTO v_rental_id, v_org_id 
		FROM rentals WHERE tenant_id = v_tenant_id;

		SELECT periods.period_id INTO v_period_id
		FROM periods
		WHERE (opened = true) AND (activated = true) AND (closed = false)
		AND (start_date <= v_sent_date) AND (end_date >= v_sent_date)
		AND (org_id = NEW.org_id);

		IF (v_tenant_id is not null) THEN
			NEW.period_id := v_period_id;
			NEW.rental_id := v_rental_id;
			NEW.org_id := v_org_id;
			NEW.status := 'Completed';
			NEW.narrative := 'Tenant details Matched';
		ELSE
			NEW.status := 'Draft';
			NEW.narrative := 'payment phone number does not match any tenant details';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_mpesa_payment BEFORE INSERT OR UPDATE ON mpesa_payment
    FOR EACH ROW EXECUTE PROCEDURE ins_mpesa_payment();

---Posting mpesa message payments
CREATE OR REPLACE FUNCTION mpesa_posting (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
DECLARE	
	v_status			varchar(50);
	myrec				RECORD;
	msg					varchar(120);
	v_currency_id 		integer;
BEGIN
	IF($3::integer = 1)THEN
		--SELECT status INTO v_status FROM mpesa_payment WHERE mpesa_payment_id = $1::int;
		IF (v_status = 'Completed') THEN
			SELECT currency_id INTO v_currency_id FROM orgs WHERE is_active = true;

		FOR myrec IN SELECT currency, amount, phone_number, org_id, period_id, rental_id,status INTO myrec 
			FROM mpesa_payment
			WHERE mpesa_payment_id = $1::int
			LOOP	

				INSERT INTO payments (rental_id, tx_type,payment_type_id,activity_name,currency_id,period_id,payment_date,account_credit,exchange_rate)
					VALUES(myrec.rental_id,1,2,'Rent Payment',v_currency_id,myrec.period_id,current_date,myrec.amount,1);

				msg := 'Payment Posted Successfully...';

				UPDATE mpesa_payment SET status = 'Posted'	WHERE mpesa_payment_id = $1::int;
			END LOOP;
		ELSE 
			msg := 'Uknown Payment....';
		END IF;		
	END IF;
	return msg;
END;
$$ LANGUAGE plpgsql;

---rental review 
CREATE OR REPLACE FUNCTION rent_review (varchar(12), varchar(12), varchar(12),varchar(12)) RETURNS varchar(120) AS $$
	DECLARE
		msg						varchar(120);
		myrec 					RECORD;
		reca					RECORD;
		recb					RECORD;
		v_rental_value 			float;
		v_service_fee 			float;
	BEGIN
		IF($3::integer = 1)THEN
			SELECT property_id,review_date,review_amount,narrative,rental_value,service_fee,status INTO myrec
			FROM rent_review
			WHERE rent_review_id = $1::int;

			SELECT rental_value,service_fees,property_id,org_id INTO reca
			FROM rentals
			WHERE property_id = myrec.property_id;

			IF (myrec.review_date >= current_date) THEN
				RAISE EXCEPTION 'Review Date failed, scheduled on or past % ',myrec.review_date;
			ELSIF ((myrec.rental_value = false) AND (myrec.service_fee = false)) THEN
				RAISE EXCEPTION 'Review must be either be for rental value or service fee...';
			ELSIF ((myrec.rental_value = true) AND (myrec.service_fee = true)) THEN
				RAISE EXCEPTION 'Review both rental value and service fee together...';
			ELSIF (myrec.rental_value = true) THEN
				IF (myrec.status = 'Completed') THEN
					RAISE EXCEPTION 'Rentals Rent review has already been done..';
				ELSE
					v_rental_value = reca.rental_value + myrec.review_amount;
					UPDATE units SET rental_value = v_rental_value WHERE property_id = myrec.property_id;
					msg := 'Rental value review completed...';
					UPDATE rent_review SET status = 'Completed' WHERE rent_review_id = $1::int;
				END IF;
			ELSIF (myrec.service_fee = true) THEN
				IF (myrec.status = 'Completed') THEN
					RAISE EXCEPTION 'Rentals Service fees review has already been done..';
				ELSE
					v_service_fee = reca.service_fees + myrec.review_amount;
					UPDATE units SET service_fees = v_service_fee WHERE property_id = myrec.property_id;
					msg := 'Service Fee value review completed...';
					UPDATE rent_review SET status = 'Completed' WHERE rent_review_id = $1::int;
				END IF;
			END IF;
		END IF;
	RETURN msg;
END;
$$ LANGUAGE plpgsql;

---========== updates for commissions---==========
--- commissions view
CREATE OR REPLACE VIEW vw_commissions AS
SELECT commissions.commission_id, commissions.rental_id, commissions.period_id, commissions.org_id, 
commissions.commission_type_id, commissions.commission, commissions.commission_pct, commissions.narrative, 
commissions.date_created, commissions.details, commission_types.commission_name, 

vw_rentals.landlord_id, vw_rentals.client_name, vw_rentals.property_type_name, vw_rentals.property_name, 
vw_rentals.tenant_id, vw_rentals.tenant_name, vw_rentals.unit_type_name, vw_rentals.hse_no, vw_rentals.is_active, 
vw_rentals.rental_value, 

vw_periods.fiscal_year, vw_periods.start_date, vw_periods.end_date, vw_periods.period_year, 
vw_periods.period_month, vw_periods.period_disp
FROM commissions
  INNER JOIN commission_types ON commission_types.commission_type_id = commissions.commission_type_id
  INNER JOIN vw_periods ON vw_periods.period_id = commissions.period_id
  INNER JOIN vw_rentals ON vw_rentals.rental_id = commissions.rental_id;

---commisions on insert trigger to compute commisions
CREATE OR REPLACE FUNCTION ins_commissions() RETURNS trigger AS $$
DECLARE
	rec						RECORD;
	v_commmission_amount	float;
	v_rental_value			float;
BEGIN
	SELECT rental_value INTO v_rental_value
	FROM rentals
	WHERE rental_id = NEW.rental_id;

	IF((NEW.commission is null) AND (NEW.commission_pct is null)) THEN
		RAISE EXCEPTION 'Both Commission Amount and Commission pct cannot be Zero..';
	END IF;

	IF((NEW.commission is not null) AND (NEW.commission_pct is not null)) THEN
		RAISE EXCEPTION 'Enter Commission Amount OR Commission pct only..';
	END IF;

	IF (NEW.commission_pct is not null) THEN
		v_commmission_amount = v_rental_value*NEW.commission_pct/100;
		NEW.commission := v_commmission_amount;
	END IF;	

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_commissions BEFORE INSERT OR UPDATE ON commissions
    FOR EACH ROW EXECUTE PROCEDURE ins_commissions();