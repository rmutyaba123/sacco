---Payments Module
--Payment Frequency
CREATE TABLE payment_frequency (
	activity_frequency_id	integer primary key,
	activity_frequency_name	varchar(50)
);

--- Payment status
CREATE TABLE payment_status (
	activity_status_id		integer primary key,
	activity_status_name	varchar(50)
);

---Payments Types
CREATE TABLE payment_types (
	payment_type_id			serial primary key,
	account_id				integer not null references accounts,
	use_key_id				integer not null references use_keys,
	org_id					integer references orgs,
	payment_type_name		varchar(120) not null,
	is_active				boolean default true not null,
	details					text,
	UNIQUE(org_id, payment_type_name)
);
CREATE INDEX payment_types_account_id ON payment_types(account_id);
CREATE INDEX payment_types_use_key_id ON payment_types(use_key_id);
CREATE INDEX payment_types_org_id ON payment_types(org_id);

--- Commission Types 
CREATE TABLE commission_types (
	commission_type_id 		serial primary key,
	org_id 					integer references orgs,
	commission_name 		varchar(100)
);
CREATE INDEX commission_types_org_id ON commission_types(org_id);

--- Commissions
CREATE TABLE commissions(
	commission_id		serial primary key,
	rental_id 			integer references rentals,
	period_id 			integer references periods,
	org_id 				integer references orgs,

	commission_type_id 	integer references commission_types,

	commission 			real,
	commission_pct 		float,

	narrative 			varchar(100),
	date_created 		timestamp default now(),
	details 			text	
);
CREATE INDEX commissions_rental_id ON commissions(rental_id);
CREATE INDEX commissions_period_id ON commissions(period_id);
CREATE INDEX commissions_commission_type_id ON commissions(commission_type_id);
CREATE INDEX commissions_org_id ON commissions(org_id);


----Mpesa message payment breakdown from mobile app
CREATE TABLE mpesa_payment(
    mpesa_payment_id    serial primary key,

    message             varchar(200) not null, --- mpesa message
    sent_date           varchar(40) not null, --- mpesa payment date
    mpesa_code          varchar(40) not null, ---mpesa payment code
    tenant_name         varchar(100), ---tenant name
    currency            varchar(50), ---- currency e.g Ksh
    amount              float not null,  ---   amount deposited e.g 6000
    phone_number        varchar(13) not null, ---- sender/tenant number e.g 0708067768

    status 				varchar(30) default 'null' not null,

    org_id   			integer references orgs,
    period_id 			integer,
	rental_id 			integer,

    action_date         timestamp default now() not null,
    narrative           varchar(100),
    details             text
);
CREATE INDEX mpesa_payment_org_id ON mpesa_payment(org_id);

--ALTER TABLE mpesa_payment ADD entity_id   integer references entitys;

--CREATE INDEX mpesa_payment_entity_id ON mpesa_payment(entity_id);


CREATE TABLE payments (
	payment_id				serial primary key,

	payment_type_id			integer references payment_types,
	currency_id				integer references currency,

	period_id				integer references periods,
	property_id				integer references property,
	rental_id				integer references rentals,

	org_id					integer references orgs,
	sys_audit_trail_id		integer references sys_audit_trail,

	payment_number			varchar(50),
	payment_date			date default current_date not null,
	tx_type					integer default 1 not null,

	account_credit			real default 0 not null,
	account_debit			real default 0 not null,
	balance					real not null,

	exchange_rate			real default 1 not null,
	activity_name 			varchar(50),
	action_date				timestamp,	
	
	details					text
);
CREATE INDEX payments_payment_type_id ON payments(payment_type_id);
CREATE INDEX payments_currency_id ON payments(currency_id);
CREATE INDEX payments_period_id ON payments(period_id);
CREATE INDEX payments_property_id ON payments(property_id);
CREATE INDEX payments_rental_id ON payments(rental_id);
CREATE INDEX payments_sys_audit_trail_id ON payments(sys_audit_trail_id);
CREATE INDEX payments_org_id ON payments(org_id);

---Remittance table 
CREATE TABLE remmitance (
	remmitance_id			serial primary key,

	payment_type_id			integer references payment_types,
	currency_id				integer references currency,

	period_id				integer references periods,
	property_id				integer references property,
	rental_id				integer,

	org_id					integer references orgs,
	sys_audit_trail_id		integer references sys_audit_trail,

	payment_number			varchar(50),
	payment_date			date default current_date not null,
	tx_type					integer default 1 not null,

	account_credit			real default 0 not null,
	account_debit			real default 0 not null,
	balance					real not null,

	exchange_rate			real default 1 not null,
	activity_name 			varchar(50),
	action_date				timestamp,	
	
	details					text
);
CREATE INDEX remmitance_payment_type_id ON remmitance(payment_type_id);
CREATE INDEX remmitance_currency_id ON remmitance(currency_id);
CREATE INDEX remmitance_period_id ON remmitance(period_id);
CREATE INDEX remmitance_property_id ON remmitance(property_id);
--CREATE INDEX remmitance_rental_id ON remmitance(rental_id);
CREATE INDEX remmitance_sys_audit_trail_id ON remmitance(sys_audit_trail_id);
CREATE INDEX remmitance_org_id ON remmitance(org_id);

CREATE OR REPLACE VIEW vw_tenant_payments AS
SELECT payment_types.account_id, payment_types.use_key_id, payment_types.payment_type_name, payment_types.is_active,
	
	payments.payment_id,payments.payment_type_id, payments.currency_id, payments.period_id, 
	payments.property_id,payments.rental_id, payments.org_id, payments.payment_number, 
	payments.payment_date, payments.tx_type,payments.account_credit, payments.account_debit, payments.balance, 
	payments.exchange_rate, payments.activity_name, payments.action_date,

	currency.currency_name, currency.currency_symbol,

	vw_rentals.property_type_name, vw_rentals.property_name, 
	vw_rentals.estate,vw_rentals.tenant_name,vw_rentals.hse_no,vw_rentals.rental_value,
	
	vw_periods.period_disp, vw_periods.period_month
	
		FROM payments
		INNER JOIN currency ON currency.currency_id = payments.currency_id
		INNER JOIN payment_types ON payment_types.payment_type_id = payments.payment_type_id
		INNER JOIN vw_rentals ON vw_rentals.rental_id = payments.rental_id
		INNER JOIN vw_periods ON vw_periods.period_id = payments.period_id
		WHERE tx_type=1; 

----Remmitance View
CREATE OR REPLACE VIEW vw_remmitance AS
	SELECT remmitance.remmitance_id, remmitance.payment_type_id, remmitance.currency_id, remmitance.period_id, 
	remmitance.property_id, remmitance.rental_id, remmitance.org_id, remmitance.sys_audit_trail_id, 
	remmitance.payment_number, remmitance.payment_date, remmitance.tx_type, remmitance.account_credit, 
	remmitance.account_debit, remmitance.balance, remmitance.exchange_rate, remmitance.activity_name, 
	remmitance.action_date, remmitance.details, currency.currency_name, currency.currency_symbol, 
	property.property_type_id, property.property_trxs_type_id,payment_types.payment_type_name,
	vw_periods.fiscal_year_id, vw_periods.fiscal_year, vw_periods.start_date, vw_periods.end_date, vw_periods.opened, 
	vw_periods.activated, vw_periods.period_year, vw_periods.period_month, vw_periods.period_disp, 
	vw_rentals.property_type_name, vw_rentals.property_name, vw_rentals.unit_type_name, vw_rentals.hse_no, vw_rentals.is_active
		FROM remmitance
		  INNER JOIN  currency ON currency.currency_id = remmitance.currency_id
		  INNER JOIN property ON property.property_id = remmitance.property_id
		  INNER JOIN payment_types ON payment_types.payment_type_id = remmitance.payment_type_id
		  INNER JOIN vw_periods ON vw_periods.period_id = remmitance.period_id
		  INNER JOIN vw_rentals ON vw_rentals.rental_id = remmitance.rental_id;

---- client bill.		  
CREATE OR REPLACE VIEW vw_client_bill AS
	SELECT 
	payment_types.account_id, payment_types.use_key_id, payment_types.payment_type_name, 
	payment_types.is_active,

	remmitance.remmitance_id,remmitance.payment_type_id, remmitance.currency_id, remmitance.period_id,  
	remmitance.rental_id, remmitance.org_id, remmitance.payment_number, 
	remmitance.payment_date, remmitance.tx_type,remmitance.account_credit, remmitance.account_debit, remmitance.balance, 
	remmitance.exchange_rate, remmitance.activity_name, remmitance.action_date,

	currency.currency_name, currency.currency_symbol,

	vw_property.landlord_id, vw_property.client_name,vw_property.property_type_id,vw_property.property_type_name,vw_property.property_id,
	vw_property.property_name,vw_property.estate,vw_property.plot_no,vw_property.property_trxs_name	,

	vw_periods.period_disp, vw_periods.period_month
	
		FROM remmitance
		INNER JOIN currency ON currency.currency_id = remmitance.currency_id
		INNER JOIN vw_periods ON vw_periods.period_id = remmitance.period_id
		INNER JOIN vw_property ON vw_property.property_id = remmitance.period_id
		INNER JOIN payment_types ON payment_types.payment_type_id = remmitance.payment_type_id;	
		

CREATE OR REPLACE FUNCTION amount_in_words(n BIGINT) RETURNS TEXT AS
	$$
	DECLARE
 		 e TEXT;
	BEGIN

 	 WITH Below20(Word, Id) AS
 	 (
  	  VALUES
     	 ('Zero', 0), ('One', 1),( 'Two', 2 ), ( 'Three', 3), ( 'Four', 4 ), ( 'Five', 5 ), ( 'Six', 6 ), ( 'Seven', 7 ),
    	  ( 'Eight', 8), ( 'Nine', 9), ( 'Ten', 10), ( 'Eleven', 11 ),( 'Twelve', 12 ), ( 'Thirteen', 13 ), ( 'Fourteen', 14),
    	  ( 'Fifteen', 15 ), ('Sixteen', 16 ), ( 'Seventeen', 17),
    	  ('Eighteen', 18 ), ( 'Nineteen', 19 )
  	 ),
  		 Below100(Word, Id) AS
  	 (
     	 VALUES
      	 ('Twenty', 2), ('Thirty', 3),('Forty', 4), ('Fifty', 5),
      	 ('Sixty', 6), ('Seventy', 7), ('Eighty', 8), ('Ninety', 9)
  	 )
  		 SELECT
     		CASE
    		  WHEN n = 0 THEN  ''
     		 WHEN n BETWEEN 1 AND 19
       			 THEN (SELECT Word FROM Below20 WHERE ID=n)
    		 WHEN n BETWEEN 20 AND 99
     			  THEN  (SELECT Word FROM Below100 WHERE ID=n/10) ||  '-'  ||
           		  amount_in_words( n % 10)
    		 WHEN n BETWEEN 100 AND 999
      			 THEN  (amount_in_words( n / 100)) || ' Hundred ' ||
          		 amount_in_words( n % 100)
    		 WHEN n BETWEEN 1000 AND 999999
    			   THEN  (amount_in_words( n / 1000)) || ' Thousand ' ||
         			  amount_in_words( n % 1000)
    		 WHEN n BETWEEN 1000000 AND 999999999
     			  THEN  (amount_in_words( n / 1000000)) || ' Million ' ||
         		  amount_in_words( n % 1000000)
   			 WHEN n BETWEEN 1000000000 AND 999999999999
     			  THEN  (amount_in_words( n / 1000000000)) || ' Billion ' ||
           			amount_in_words( n % 1000000000)
    		 WHEN n BETWEEN 1000000000000 AND 999999999999999
      			 THEN  (amount_in_words( n / 1000000000000)) || ' Trillion ' ||
           			amount_in_words( n % 1000000000000)
   			 WHEN n BETWEEN 1000000000000000 AND 999999999999999999
      			 THEN  (amount_in_words( n / 1000000000000000)) || ' Quadrillion ' ||
          			 amount_in_words( n % 1000000000000000)
   			 WHEN n BETWEEN 1000000000000000000 AND 999999999999999999999
       			THEN  (amount_in_words( n / 1000000000000000000)) || ' Quintillion ' ||
          			 amount_in_words( n % 1000000000000000000)
         	 ELSE ' INVALID INPUT' END INTO e;
 			 e := RTRIM(e);
 			 IF RIGHT(e,1)='-' THEN
   			 e := RTRIM(LEFT(e,length(e)-1));
 		 END IF;

 		 RETURN e;
		END;
	$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW vw_receipt AS
	SELECT payment_types.account_id, payment_types.use_key_id, payment_types.payment_type_name, payment_types.is_active,
		
		payments.payment_id,payments.payment_type_id, payments.currency_id, payments.period_id, 
		payments.property_id,payments.rental_id, payments.org_id, payments.payment_number, 
		payments.payment_date, payments.tx_type,payments.account_credit, payments.account_debit, payments.balance, 
		payments.exchange_rate, payments.activity_name, payments.action_date,Amount_in_words(payments.account_credit::int) as amount_paid,

		currency.currency_name, currency.currency_symbol,

		vw_rentals.property_type_name, vw_rentals.property_name, 
		vw_rentals.estate,vw_rentals.tenant_name,vw_rentals.hse_no,vw_rentals.rental_value,(vw_rentals.tenant_id) AS entity_id,
		
		vw_periods.period_disp, vw_periods.period_month,vw_periods.start_date,vw_periods.end_date
		
			FROM payments
			INNER JOIN currency ON currency.currency_id = payments.currency_id
			INNER JOIN payment_types ON payment_types.payment_type_id = payments.payment_type_id
			INNER JOIN vw_rentals ON vw_rentals.rental_id = payments.rental_id
			INNER JOIN vw_periods ON vw_periods.period_id = payments.period_id
			WHERE tx_type=1; 

CREATE OR REPLACE VIEW vw_tenant_statement AS
	SELECT rental_id, tenant_name,(property_name||','||property_type_name||','||estate)AS property_info ,hse_no,

		payment_date,payment_number,(activity_name||','||hse_no||','||period_disp)AS details,
		account_debit as Rent_To_Pay,account_credit as Rent_paid,balance 

			FROM vw_tenant_payments 
					ORDER BY payment_id ASC;



CREATE OR REPLACE VIEW vw_tenant_invoice AS
	SELECT (vw_period_rentals.period_year||'-'||vw_period_rentals.period_month)AS period_disp, 
		(vw_period_rentals.property_name||' '|| vw_period_rentals.property_type_name||' '|| vw_period_rentals.estate)AS property_details, vw_period_rentals.tenant_name, 
		vw_period_rentals.hse_no, vw_period_rentals.rental_amount, vw_period_rentals.service_fees, vw_period_rentals.commision, 
		vw_period_rentals.repair_amount, vw_period_rentals.status, 

		payments.payment_id, payments.payment_type_id,payments.period_id, payments.property_id, 
		payments.rental_id, payments.org_id, payments.payment_number, payments.payment_date, payments.account_debit, payments.exchange_rate, 
		payments.activity_name, 

		currency.currency_name, currency.currency_symbol,
		
		vw_orgs.org_name, vw_orgs.org_full_name
		
		FROM payments 
		INNER JOIN vw_period_rentals ON vw_period_rentals.rental_id = payments.rental_id
		INNER JOIN currency ON currency.currency_id = payments.currency_id
		INNER JOIN vw_orgs ON vw_orgs.org_id = payments.org_id
		where tx_type = 1 and payment_type_id = 5 ;

CREATE OR REPLACE VIEW vw_receipts AS
	SELECT org_id,rental_id,period_id,payment_id,payment_type_id, payment_number,payment_date,account_credit,balance,currency_symbol,
	(property_name||','||property_type_name||','||estate)AS property,(tenant_name||'-'||hse_no)AS tenant_details,period_disp,period_month
		FROM vw_tenant_payments
		WHERE payment_type_id = 2;

CREATE OR REPLACE VIEW vw_mpesa_payment AS
	SELECT mpesa_payment.mpesa_payment_id, mpesa_payment.message, mpesa_payment.sent_date, mpesa_payment.mpesa_code, 
	mpesa_payment.currency, mpesa_payment.amount, mpesa_payment.phone_number, mpesa_payment.org_id, mpesa_payment.status, 
	mpesa_payment.period_id, mpesa_payment.rental_id, mpesa_payment.action_date, mpesa_payment.narrative, mpesa_payment.details, 

	vw_orgs.org_name,  vw_orgs.org_full_name, vw_orgs.currency_id, vw_orgs.currency_name, vw_orgs.currency_symbol,

	vw_periods.fiscal_year_id, vw_periods.fiscal_year, vw_periods.fiscal_year_start, vw_periods.fiscal_year_end, 
	vw_periods.year_opened, vw_periods.year_closed, vw_periods.start_date, vw_periods.end_date, vw_periods.opened, 
	vw_periods.activated, vw_periods.closed, vw_periods.period_year, vw_periods.period_month, vw_periods.period_disp,

	vw_rentals.client_name, vw_rentals.property_type_name, vw_rentals.property_id, vw_rentals.property_name, vw_rentals.tenant_name, 
	vw_rentals.unit_type_name, vw_rentals.hse_no, vw_rentals.start_rent, vw_rentals.is_active, vw_rentals.rental_value, 
	vw_rentals.service_fees, vw_rentals.deposit_fee, vw_rentals.deposit_fee_date, vw_rentals.deposit_refund, 
	vw_rentals.deposit_refund_date
		FROM mpesa_payment
		INNER JOIN vw_periods ON mpesa_payment.period_id = vw_periods.period_id
		INNER JOIN vw_orgs ON mpesa_payment.org_id = vw_orgs.org_id
		INNER JOIN vw_rentals ON mpesa_payment.rental_id = vw_rentals.rental_id;

CREATE OR REPLACE VIEW vw_mpesa_payment_all AS
SELECT mpesa_payment.mpesa_payment_id, mpesa_payment.message, mpesa_payment.sent_date, mpesa_payment.mpesa_code, 
	mpesa_payment.currency, mpesa_payment.amount, mpesa_payment.phone_number, mpesa_payment.org_id, mpesa_payment.status, 
	mpesa_payment.period_id, mpesa_payment.rental_id, mpesa_payment.action_date, mpesa_payment.narrative, mpesa_payment.details, 
	mpesa_payment.tenant_name, 

	vw_orgs.org_name,  vw_orgs.org_full_name, vw_orgs.currency_id, vw_orgs.currency_name, vw_orgs.currency_symbol
	
		FROM mpesa_payment		
		INNER JOIN vw_orgs ON mpesa_payment.org_id = vw_orgs.org_id;

CREATE OR REPLACE VIEW vw_mpesa_payment_draft AS
SELECT mpesa_payment.mpesa_payment_id, mpesa_payment.message, mpesa_payment.sent_date, mpesa_payment.mpesa_code, 
	mpesa_payment.currency, mpesa_payment.amount, mpesa_payment.phone_number, mpesa_payment.org_id, mpesa_payment.status, 
	mpesa_payment.period_id, mpesa_payment.rental_id, mpesa_payment.action_date, mpesa_payment.narrative, mpesa_payment.details, 
	mpesa_payment.tenant_name, 

	vw_orgs.org_name,  vw_orgs.org_full_name, vw_orgs.currency_id, vw_orgs.currency_name, vw_orgs.currency_symbol
	
		FROM mpesa_payment		
		INNER JOIN vw_orgs ON mpesa_payment.org_id = vw_orgs.org_id
			WHERE mpesa_payment.status = 'Draft'

