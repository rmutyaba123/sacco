---Project Database File
----tenants details table
CREATE TABLE tenants (
	tenant_id				serial primary key,
	entity_id 				integer references entitys,
	org_id					integer references orgs,
	
	tenant_name			    varchar(150) not null,
	identification_number	varchar(50),
	identification_type		varchar(50),
	
	tenant_email			varchar(50),
	telephone_number		varchar(20),
	
	address					varchar(50),
	town					varchar(50),
	zip_code				varchar(50),
	
	gender					varchar(1),
	nationality				char(2) references sys_countrys,
	marital_status 			varchar(2),
	picture_file			varchar(32),

	employed				boolean default false not null,
	self_employed			boolean default false not null,
	occupation  			varchar(120),

	is_active				boolean default true not null,
	terminated 				boolean default false not null,
	terminated_date 		date,
	narrative 				varchar(100),

	details					text,
	
	UNIQUE (org_id, identification_number)
);
CREATE INDEX tenants_entity_id ON tenants(entity_id);
CREATE INDEX tenants_org_id ON tenants(org_id);

ALTER TABLE entitys ADD 	tenant_id		integer references tenants;
CREATE INDEX entitys_tenant_id ON entitys(tenant_id);

---- Property owner/landlord/client
CREATE TABLE landlord (
	landlord_id				serial primary key,
	entity_id 				integer references entitys,
	org_id					integer references orgs,

	landlord_name			varchar(150) not null,
	identification_number	varchar(50),
	identification_type		varchar(50),
	
	landlord_email			varchar(50),
	telephone_number		varchar(20),
	
	address					varchar(50),
	town					varchar(50),
	zip_code				varchar(50),
	
	gender					varchar(1),
	nationality				char(2) references sys_countrys,
	marital_status 			varchar(2),
	is_active				boolean default true not null,
	picture_file			varchar(32),

	bank_name				varchar(120),
	bank_branch_name		varchar(120),
	account_number			varchar(50),

	details					text,
	
	UNIQUE (org_id, identification_number)
);
CREATE INDEX landlord_entity_id ON landlord(entity_id);
CREATE INDEX landlord_org_id ON landlord(org_id);

ALTER TABLE entitys ADD 	landlord_id		integer references landlord;
CREATE INDEX entitys_landlord_id ON entitys(landlord_id);

---Property tables
CREATE TABLE property_types (
	property_type_id		serial primary key,
	org_id					integer references orgs,
	property_type_name		varchar(50),
	commercial_property		boolean not null default false,
	details					text
);
CREATE INDEX property_types_org_id ON property_types (org_id);

---property transaction categories
CREATE TABLE property_trxs_types (
	property_trxs_type_id	serial primary key,
	property_trxs_name		varchar(50),
	property_trxs_no		integer,
	details					text
);

---Property table
CREATE TABLE property (
	property_id				serial primary key,
	property_type_id		integer references property_types,
	landlord_id				integer references landlord, --- property owner
	property_trxs_type_id 	integer references property_trxs_types,
	org_id					integer references orgs,

	property_name			varchar(50),
	estate					varchar(50),
	plot_no					varchar(50),
	is_active				boolean not null default true,	

	details					text
);
CREATE INDEX property_property_type_id ON property (property_type_id);
CREATE INDEX property_landlord_id ON property (landlord_id);
CREATE INDEX property_property_trxs_type_id ON property (property_trxs_type_id);
CREATE INDEX property_org_id ON property (org_id);

---Property amenity
CREATE TABLE property_amenity (
	property_amenity_id		serial primary key,
	org_id 					integer references orgs,
	amenity_name			varchar(50) not null,
	narrative 				varchar(50),
	details 				text
);
CREATE INDEX property_amenity_org_id ON property_amenity(org_id);


ALTER TABLE transactions
ADD property_id				integer references property;
CREATE INDEX transactions_property_id ON transactions (property_id);

ALTER TABLE helpdesk
ADD property_id				integer references property;
CREATE INDEX helpdesk_property_id ON helpdesk(property_id);

---property rooms/unit types
CREATE TABLE unit_types (
	unit_type_id			serial primary key,
	org_id					integer references orgs,
	unit_type_name			varchar(50),
	details					text
);
CREATE INDEX unit_types_org_id ON unit_types (org_id);

---property rooms/units
CREATE TABLE units (
	unit_id					serial primary key,
	property_id				integer references property,
	unit_type_id			integer references unit_types, 
	org_id					integer references orgs,

	unit_name			 	varchar(50),

	is_vacant				boolean not null default true,
	is_active				boolean not null default true,
	multiple_tenancy		boolean not null default false,

	rental_value			float default 0 not null,
	service_fees			float default 0 not null,

	narrative 				varchar(50),

	details					text
);
CREATE INDEX units_property_id ON units (property_id);
CREATE INDEX units_unit_type_id ON units (unit_type_id);
CREATE INDEX units_org_id ON units (org_id);

---Property rentals table
CREATE TABLE rentals (
	rental_id				serial primary key,
	property_id				integer references property,
	tenant_id				integer references tenants,		--- Tenant
	org_id					integer references orgs,
	start_rent				date,

	unit_id					integer references units,    ----house no

	elec_no					varchar(50),
	water_no				varchar(50),

	is_active				boolean not null default true,

	rental_value			float not null,
	service_fees			float not null,

	commision_value			float,

	deposit_fee				float,
	deposit_fee_date		date,
	deposit_refund			float,
	deposit_refund_date		date,

	details					text
);
CREATE INDEX rentals_property_id ON rentals (property_id);
CREATE INDEX rentals_tenant_id ON rentals (tenant_id);
CREATE INDEX rentals_org_id ON rentals (org_id);

--- Log Rentals
CREATE TABLE log_rentals (
	log_rentals_id			serial primary key,
	sys_audit_trail_id		integer references sys_audit_trail,
	rental_id				integer,
	property_id				integer,
	tenant_id				integer,
	org_id					integer,
	start_rent				date,
	end_rent				date,
	unit_id					integer,
	elec_no					varchar(50),
	water_no				varchar(50),
	is_active				varchar(50),
	rental_value			float,
	service_fees			float,
	commision_value			float,
	deposit_fee				float,
	deposit_fee_date		date,
	deposit_refund			float,
	deposit_refund_date		date

);
CREATE INDEX log_rentals_rental_id ON log_rentals (rental_id);
CREATE INDEX log_rentals_sys_audit_trail_id ON log_rentals (sys_audit_trail_id);


---Property period rentals 
CREATE TABLE period_rentals (
	period_rental_id		serial primary key,

	rental_id				integer references rentals,
	period_id				integer references periods,
	property_id				integer references property,
	tenant_id				integer references tenants,		--- Tenant

	sys_audit_trail_id		integer references sys_audit_trail,
	org_id					integer references orgs,

	rental_amount			float not null,
	service_fees			float not null,
	repair_amount			float default 0 not null,
	commision				float default 0 not null,
	
	status					varchar(50) default 'Draft' not null,

	narrative				varchar(240),
	details 				text
);
CREATE INDEX period_rentals_rental_id ON period_rentals (rental_id);
CREATE INDEX period_rentals_period_id ON period_rentals (period_id);
CREATE INDEX period_rentals_property_id ON period_rentals (property_id);
CREATE INDEX period_rentals_tenant_id ON period_rentals (tenant_id);
CREATE INDEX period_rentals_sys_audit_trail_id ON period_rentals (sys_audit_trail_id);
CREATE INDEX period_rentals_org_id ON period_rentals (org_id);

--- Log for period rentals
CREATE TABLE log_period_rentals (
	log_period_rental_id	serial primary key,
	sys_audit_trail_id		integer references sys_audit_trail,
	period_rental_id		integer,
	rental_id				integer,
	period_id				integer,
	org_id					integer,

	rental_amount			float,
	service_fees			float,
	repair_amount			float,
	commision				float,

	status					varchar(50),

	narrative				varchar(240)
);
CREATE INDEX log_period_rentals_period_rental_id ON log_period_rentals (period_rental_id);
CREATE INDEX log_period_rentals_sys_audit_trail_id ON log_period_rentals (sys_audit_trail_id);


---Rental transfers
CREATE TABLE rental_transfer (
	rental_transfer_id 		serial primary key,
	tenant_id 				integer, --- tenant id
	org_id 					integer,

	rental_id 				integer, --- current rental 
	from_unit_id 			integer not null, --current unit

	unit_id 				integer references units, --transferred to
	transfer_date 			date,  --- transfer date 
	status 					varchar(50) default 'Pending' not null, ---status after application

	narrative 				varchar(100),
	details 				text
);
CREATE INDEX rental_transfer_tenant_id ON rental_transfer (tenant_id);
CREATE INDEX rental_transfer_org_id ON rental_transfer (org_id);
CREATE INDEX rental_transfer_rental_id ON rental_transfer (rental_id);
CREATE INDEX rental_transfer_unit_id ON rental_transfer (unit_id);

ALTER table rental_transfer ADD property_id  integer references property; --transfer to property
CREATE INDEX rental_transfer_property_id ON rental_transfer (property_id);

---sms table
CREATE TABLE sms (
	sms_id					serial primary key,
	entity_id				integer references entitys,
	org_id					integer references orgs,
	sms_number				varchar(25),
	sms_numbers				text,
	sms_time				timestamp default now(),
	sent					boolean default false not null,

	message					text,
	details					text
);
CREATE INDEX sms_entity_id ON sms (entity_id);
CREATE INDEX sms_org_id ON sms (org_id);

CREATE TABLE mpesa_trxs (
	mpesa_trx_id			serial primary key,
	org_id					integer references orgs,
	mpesa_id				integer,
	mpesa_orig				varchar(50),
	mpesa_dest				varchar(50),
	mpesa_tstamp			timestamp,
	mpesa_text				varchar(320),
	mpesa_code				varchar(50),
	mpesa_acc				varchar(50),
	mpesa_msisdn			varchar(50),
	mpesa_trx_date			date,
	mpesa_trx_time			time,
	mpesa_amt				real,
	mpesa_sender			varchar(50),
	mpesa_pick_time			timestamp default now()
);
CREATE INDEX mpesa_trxs_org_id ON mpesa_trxs (org_id);

CREATE TABLE mpesa_soap (
	mpesa_soap_id			serial primary key,
	org_id					integer references orgs,
	request_id				varchar(32),
	TransID					varchar(32),
	TransAmount				real,
	BillRefNumber			varchar(32),
	TransTime				varchar(32),
	BusinessShortCode		varchar(32),
	TransType				varchar(32),
	FirstName				varchar(32),
	LastName				varchar(32),
	MSISDN					varchar(32),
	OrgAccountBalance		real,
	InvoiceNumber			varchar(32),
	ThirdPartyTransID		varchar(32),
	created					timestamp default current_timestamp not null
);
CREATE INDEX mpesa_soap_org_id ON mpesa_soap (org_id);

---rent review
CREATE TABLE rent_review(
	rent_review_id 		serial primary key,

	property_id 		integer references property,
	org_id 				integer references orgs,

	review_amount 		float,
	review_date 		date,
	narrative 			varchar(50),

	rental_value		boolean default false not null,
	service_fee			boolean default false not null,
	status 				varchar(50) default 'Draft' not null,

	details 			text

);
CREATE INDEX rent_review_property_id ON rent_review(property_id);
CREATE INDEX rent_review_org_id ON rent_review(org_id);

--- Function to count occupied units/rooms
CREATE OR REPLACE FUNCTION get_occupied(integer) RETURNS integer AS $$
    SELECT COALESCE(count(unit_id), 0)::integer
	FROM units
	WHERE (is_vacant = false) AND (is_active = true) AND (property_id = $1);
$$ LANGUAGE SQL;

--- Function to count units/rooms of a property
CREATE OR REPLACE FUNCTION get_units(integer) RETURNS integer AS $$
    SELECT COALESCE(count(unit_id), 0)::integer
	FROM units
	WHERE (property_id = $1);
$$  LANGUAGE SQL;

--- Function to count active units/rooms of a property
CREATE OR REPLACE FUNCTION get_active(integer) RETURNS integer AS $$
    SELECT COALESCE(count(unit_id), 0)::integer
	FROM units
	WHERE (is_active = true) AND (property_id = $1);
$$ LANGUAGE SQL;

--- Function to count active units/rooms of a property
CREATE OR REPLACE FUNCTION get_archived(integer) RETURNS integer AS $$
    SELECT COALESCE(count(unit_id), 0)::integer
	FROM units
	WHERE (is_active = false) AND (property_id = $1);
$$ LANGUAGE SQL;

----Tenants view
CREATE OR REPLACE VIEW vw_tenants AS
	SELECT 
		entitys.entity_id, tenants.tenant_id, tenants.tenant_name, 
		tenants.identification_number, tenants.identification_type, tenants.tenant_email, 
		tenants.telephone_number, tenants.address, tenants.town, 
		tenants.zip_code, entitys.user_name,
		CASE tenants.gender WHEN 'M' THEN 'Male'::text
					    WHEN 'F' THEN 'Female'::text
					    ELSE 'N/A'::text
					    END AS gender, 
		(sys_countrys.sys_country_name) AS nationality,orgs.org_name,orgs.org_id,tenants.is_active,
		CASE tenants.marital_status WHEN 'M' THEN 'Married'::text
					    WHEN 'S' THEN 'Single'::text
					    WHEN 'D' THEN 'Divorced'::text
					    WHEN 'W' THEN 'Widowed'::text
					    WHEN 'X' THEN 'Separated'::text
					    ELSE 'N/A'::text
					    END AS marital_status,
		tenants.picture_file, tenants.details,tenants.employed,tenants.self_employed,tenants.occupation
	FROM tenants
		INNER JOIN entitys ON tenants.tenant_id = entitys.tenant_id
		INNER JOIN orgs ON tenants.org_id = orgs.org_id
		INNER JOIN sys_countrys ON tenants.nationality = sys_countrys.sys_country_id;

----  Property Owners/Landlord view
CREATE OR REPLACE VIEW vw_landlord AS
	SELECT 
	entitys.entity_id, orgs.org_name, landlord.landlord_id, landlord.org_id, 
	landlord.landlord_name, landlord.identification_number, 
	landlord.identification_type, landlord.landlord_email, landlord.telephone_number, 
	landlord.address, landlord.town, landlord.zip_code, entitys.user_name,
	CASE landlord.gender WHEN 'M' THEN 'Male'::text
				    WHEN 'F' THEN 'Female'::text
				    ELSE 'N/A'::text
				    END AS gender, 
	(sys_countrys.sys_country_name) AS nationality,landlord.is_active, 
	CASE landlord.marital_status WHEN 'M' THEN 'Married'::text
					    WHEN 'S' THEN 'Single'::text
					    WHEN 'D' THEN 'Divorced'::text
					    WHEN 'W' THEN 'Widowed'::text
					    WHEN 'X' THEN 'Separated'::text
					    ELSE 'N/A'::text
					    END AS marital_status, 
	landlord.picture_file, landlord.details,landlord.bank_name,landlord.bank_branch_name,
	landlord.account_number	
	FROM landlord
	INNER JOIN entitys ON landlord.landlord_id = entitys.landlord_id
	INNER JOIN orgs ON landlord.org_id = orgs.org_id
	INNER JOIN sys_countrys ON landlord.nationality = sys_countrys.sys_country_id;

---Propertys view 
CREATE OR REPLACE VIEW vw_property AS
	SELECT landlord.landlord_id, landlord.landlord_name as client_name, 
		property_types.property_type_id, property_types.property_type_name,
		property.org_id, property.property_id, property.property_name, property.estate, 
		property.plot_no, property.is_active, property.details,
		get_units(property.property_id) AS units,
		get_occupied(property.property_id) as accupied,
		(get_units(property.property_id) - get_occupied(property.property_id) - get_archived(property.property_id)) AS vacant,
		(get_archived(property.property_id)) as archived,
		
		property_trxs_types.property_trxs_type_id,property_trxs_types.property_trxs_name, property_trxs_types.property_trxs_no
	FROM property 
		INNER JOIN landlord ON property.landlord_id = landlord.landlord_id
		INNER JOIN property_types ON property.property_type_id = property_types.property_type_id
		INNER JOIN property_trxs_types ON property.property_trxs_type_id = property_trxs_types.property_trxs_type_id;
--- Units view
CREATE OR REPLACE VIEW vw_units AS
	SELECT units.unit_id, units.property_id, units.unit_type_id, units.org_id, 
		units.unit_name, units.is_vacant, units.rental_value, units.service_fees, units.details, 
		unit_types.unit_type_name, property.property_name, property.estate, 
		property.plot_no,units.multiple_tenancy,units.is_active,units.narrative
	FROM property 
		INNER JOIN units ON property.property_id = units.property_id
		INNER JOIN unit_types ON unit_types.unit_type_id = units.unit_type_id;

---Rentals View
CREATE OR REPLACE VIEW vw_rentals AS
	SELECT vw_property.landlord_id, vw_property.client_name, vw_property.property_type_id, 
		vw_property.property_type_name,vw_property.property_id, vw_property.property_name, 
		vw_property.estate,vw_property.plot_no,tenants.tenant_id, tenants.tenant_name,
		rentals.org_id, rentals.rental_id, vw_units.unit_id,vw_units.unit_type_name,(vw_units.unit_name) AS hse_no, 
		rentals.start_rent, rentals.elec_no,rentals.water_no, rentals.is_active, rentals.rental_value,
		rentals.service_fees, rentals.deposit_fee, rentals.deposit_fee_date, 
		rentals.deposit_refund, rentals.deposit_refund_date, rentals.details
	FROM vw_property 
		INNER JOIN rentals ON vw_property.property_id = rentals.property_id
		INNER JOIN tenants ON rentals.tenant_id = tenants.tenant_id
		INNER JOIN vw_units ON rentals.unit_id = vw_units.unit_id;

CREATE OR REPLACE VIEW vw_tenant_rental AS
	SELECT 
	tenants.tenant_id, tenants.tenant_name, tenants.telephone_number,tenants.tenant_email,tenants.is_active,
	vw_rentals.start_rent, vw_rentals.hse_no, vw_rentals.unit_id, vw_rentals.rental_id,vw_rentals.org_id,
	vw_rentals.property_name,vw_rentals.property_type_name,vw_rentals.unit_type_name
	FROM tenants
	INNER JOIN vw_rentals ON vw_rentals.tenant_id = tenants.tenant_id;

CREATE OR REPLACE VIEW vw_period_rentals AS
		SELECT vw_rentals.landlord_id, vw_rentals.client_name, vw_rentals.property_type_id, vw_rentals.property_type_name,
		vw_rentals.property_id, vw_rentals.property_name, vw_rentals.estate, 
		vw_rentals.plot_no, vw_rentals.tenant_id, vw_rentals.tenant_name, 
		vw_rentals.rental_id, vw_rentals.start_rent, vw_rentals.hse_no, vw_rentals.elec_no, 
		vw_rentals.water_no, vw_rentals.is_active, vw_rentals.rental_value, 
		vw_rentals.deposit_fee, vw_rentals.deposit_fee_date, 
		vw_rentals.deposit_refund, vw_rentals.deposit_refund_date,

		vw_periods.fiscal_year_id, vw_periods.fiscal_year_start, vw_periods.fiscal_year_end,
		vw_periods.year_opened, vw_periods.year_closed,
		vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, vw_periods.opened, vw_periods.closed, 
		vw_periods.month_id, vw_periods.period_year, vw_periods.period_month, vw_periods.quarter, vw_periods.semister,

		period_rentals.org_id, period_rentals.period_rental_id, period_rentals.rental_amount, period_rentals.service_fees,
		period_rentals.commision, period_rentals.repair_amount, period_rentals.narrative,period_rentals.status,
		(period_rentals.rental_amount - period_rentals.commision) as rent_to_remit,
		(period_rentals.rental_amount + period_rentals.service_fees + period_rentals.repair_amount) as rent_to_pay
	FROM vw_rentals INNER JOIN period_rentals ON vw_rentals.rental_id = period_rentals.rental_id
		INNER JOIN vw_periods ON period_rentals.period_id = vw_periods.period_id;

---view for rentals
CREATE OR REPLACE VIEW vw_rentals_a AS
	SELECT rentals.rental_id, rentals.property_id, rentals.tenant_id, rentals.org_id, rentals.start_rent, 
	rentals.unit_id, rentals.is_active, rentals.rental_value, rentals.service_fees, rentals.deposit_fee, 
	rentals.deposit_fee_date, rentals.deposit_refund, rentals.deposit_refund_date, tenants.tenant_name, 
	tenants.tenant_email, tenants.telephone_number, vw_property.property_type_name, vw_property.property_name, 
	vw_units.unit_name,vw_units.unit_type_name,vw_property.client_name
	FROM rentals  
	  INNER JOIN  tenants ON tenants.tenant_id = rentals.tenant_id
	  INNER JOIN  vw_units ON vw_units.unit_id = rentals.unit_id
	  INNER JOIN  vw_property ON vw_property.property_id = rentals.property_id;


CREATE OR REPLACE VIEW vw_tenant_rentals AS
	SELECT tenants.tenant_id, tenants.tenant_name,entitys.entity_id,
	rentals.org_id, rentals.rental_id, rentals.start_rent, units.unit_id,(units.unit_name) AS hse_no, rentals.elec_no, 
	rentals.water_no, rentals.is_active, rentals.rental_value,
	rentals.service_fees, rentals.deposit_fee, rentals.deposit_fee_date, 
	rentals.deposit_refund, rentals.deposit_refund_date, rentals.details,tenants.telephone_number	
		FROM rentals
		INNER JOIN tenants ON rentals.tenant_id = tenants.tenant_id
		INNER JOIN units ON rentals.unit_id = units.unit_id
		INNER JOIN entitys ON entitys.tenant_id = rentals.tenant_id;


CREATE OR REPLACE VIEW vw_client_property AS
	SELECT landlord.landlord_id, landlord.landlord_name as client_name,	 
		property_types.property_type_id, property_types.property_type_name,
		property.org_id, property.property_id,property.property_name, property.estate,
		property.plot_no, 
		property.is_active, property.details		
		FROM property 
			INNER JOIN landlord ON property.landlord_id = landlord.landlord_id
			INNER JOIN property_types ON property.property_type_id = property_types.property_type_id;

---rental amount review
CREATE OR REPLACE VIEW vw_rental_review AS
	SELECT vw_property.landlord_id, vw_property.client_name, vw_property.property_type_id, 
	vw_property.property_type_name, vw_property.property_name, vw_property.estate, 
	vw_property.plot_no, vw_property.is_active, vw_property.property_trxs_type_id, vw_property.property_trxs_name, 
	vw_property.property_trxs_no, vw_property.units, rent_review.details, rent_review.narrative, 
	rent_review.review_date, rent_review.review_amount, rent_review.org_id, rent_review.property_id, 
	rent_review.rent_review_id, rent_review.rental_value,rent_review.service_fee,rent_review.status
		FROM rent_review
		INNER JOIN vw_property ON vw_property.property_id = rent_review.property_id;

---rental transfers
CREATE OR REPLACE VIEW vw_rental_tranfer AS
	SELECT rental_transfer.rental_transfer_id, rental_transfer.tenant_id, rental_transfer.org_id,
	rental_transfer.rental_id, rental_transfer.from_unit_id, rental_transfer.unit_id, rental_transfer.transfer_date, 
	rental_transfer.status, rental_transfer.narrative, rental_transfer.details, vw_rentals.tenant_name, 
	vw_rentals.hse_no, vw_rentals.rental_value, vw_rentals.service_fees, vw_rentals.property_id, vw_rentals.property_type_id
		FROM rental_transfer
		INNER JOIN vw_rentals ON vw_rentals.unit_id = rental_transfer.from_unit_id;
