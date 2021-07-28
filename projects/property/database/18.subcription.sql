
ALTER TABLE orgs ADD expiry_date date;

CREATE TABLE subscription_types(
	subscription_type_id 	serial primary key,
	subscription_type 		varchar(50) not null,
	narrative 				varchar(120)
);

INSERT INTO subscription_types(subscription_type_id,subscription_type) VALUES
			(1, 'Estate Manager'),(2, 'Landlord');

CREATE TABLE subscriptions (
	subscription_id			serial primary key,
	entity_id				integer references entitys,
	account_manager_id		integer references entitys,
	org_id					integer references orgs,

	business_name			varchar(50),
	business_address		varchar(100),
	city					varchar(30),
	subscription_type_id 	integer references subscription_types,
	country_id				char(2) references sys_countrys,
	number_of_employees		integer,
	telephone				varchar(50),
	website					varchar(120),
	
	primary_contact			varchar(120),
	job_title				varchar(120),
	primary_email			varchar(120),
	confirm_email			varchar(120),

	system_key				varchar(64),
	subscribed				boolean,
	subscribed_date			timestamp,
	
	approve_status			varchar(16) default 'Draft' not null,
	workflow_table_id		integer,
	application_date		timestamp default now(),
	action_date				timestamp,
	
	details					text
);
CREATE INDEX subscriptions_entity_id ON subscriptions(entity_id);
CREATE INDEX subscriptions_account_manager_id ON subscriptions(account_manager_id);
CREATE INDEX subscriptions_subscription_type_id ON subscriptions(subscription_type_id);
CREATE INDEX subscriptions_country_id ON subscriptions(country_id);
CREATE INDEX subscriptions_org_id ON subscriptions(org_id);

CREATE VIEW vw_subscriptions AS
	SELECT sys_countrys.sys_country_id, sys_countrys.sys_country_name, entitys.entity_id, entitys.entity_name, 
		account_manager.entity_id as account_manager_id, account_manager.entity_name as account_manager_name,
		orgs.org_id, orgs.org_name, 
		
		subscription_types.subscription_type_id,subscription_types.subscription_type,subscription_types.narrative,

		subscriptions.subscription_id, subscriptions.business_name, 
		subscriptions.business_address, subscriptions.city, subscriptions.country_id, 
		subscriptions.number_of_employees, subscriptions.telephone, subscriptions.website, 
		subscriptions.primary_contact, subscriptions.job_title, subscriptions.primary_email, 
		subscriptions.approve_status, subscriptions.workflow_table_id, subscriptions.application_date, subscriptions.action_date, 
		subscriptions.system_key, subscriptions.subscribed, subscriptions.subscribed_date,
		subscriptions.details
	FROM subscriptions INNER JOIN sys_countrys ON subscriptions.country_id = sys_countrys.sys_country_id
		INNER JOIN subscription_types ON subscription_types.subscription_type_id = subscriptions.subscription_type_id
		LEFT JOIN entitys ON subscriptions.entity_id = entitys.entity_id
		LEFT JOIN entitys as account_manager ON subscriptions.account_manager_id = account_manager.entity_id
		LEFT JOIN orgs ON subscriptions.org_id = orgs.org_id;	
		
CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON subscriptions
    FOR EACH ROW EXECUTE PROCEDURE upd_action();

CREATE OR REPLACE FUNCTION ins_subscriptions() RETURNS trigger AS $$
DECLARE
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_org_id				integer;
	v_currency_id			integer;
	v_department_id			integer;
	v_bank_id				integer;
	v_tax_type_id			integer;
	v_workflow_id			integer;
	v_subscription_type_id	integer;
	v_org_suffix			char(2);
	myrec 					RECORD;
BEGIN

	IF (TG_OP = 'INSERT') THEN
		SELECT entity_id INTO v_entity_id
		FROM entitys WHERE lower(trim(user_name)) = lower(trim(NEW.primary_email));

		IF(v_entity_id is null)THEN
			NEW.entity_id := nextval('entitys_entity_id_seq');
			INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, entity_name, User_name, primary_email,  function_role, first_password)
			VALUES (NEW.entity_id, 0, 5, 5, NEW.primary_contact, lower(trim(NEW.primary_email)), lower(trim(NEW.primary_email)), 'subscription', null);
		
			INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
			VALUES (4, 0, NEW.entity_id, 'subscription');
		
			NEW.approve_status := 'Completed';
		ELSE
			RAISE EXCEPTION 'You already have an account, login and request for services';
		END IF;
	ELSIF(NEW.approve_status = 'Approved')THEN

		NEW.org_id := nextval('orgs_org_id_seq');
		INSERT INTO orgs(org_id, currency_id, org_name, org_sufix, default_country_id, logo)
		VALUES(NEW.org_id, 2, NEW.business_name, NEW.org_id, NEW.country_id, 'logo.png');
		
		INSERT INTO address (address_name, sys_country_id, table_name, table_id, premises, town, phone_number, website, is_default) 
		VALUES (NEW.business_name, NEW.country_id, 'orgs', NEW.org_id, NEW.business_address, NEW.city, NEW.telephone, NEW.website, true);
		
		v_currency_id := nextval('currency_currency_id_seq');
		INSERT INTO currency (org_id, currency_id, currency_name, currency_symbol) VALUES (NEW.org_id, v_currency_id, 'Default Currency', 'DC');
		UPDATE orgs SET currency_id = v_currency_id WHERE org_id = NEW.org_id;
		
		INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (NEW.org_id, v_currency_id, 1);
		
		INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id)
		SELECT NEW.org_id, entity_type_name, entity_role, use_key_id
		FROM entity_types WHERE org_id = 1;
		
		INSERT INTO subscription_levels (org_id, subscription_level_name)
		SELECT NEW.org_id, subscription_level_name
		FROM subscription_levels WHERE org_id = 1;
		
		v_department_id := nextval('departments_department_id_seq');
		INSERT INTO departments (org_id, department_id, department_name) VALUES (NEW.org_id, v_department_id, 'Board of Directors');
		
		v_bank_id := nextval('banks_bank_id_seq');
		INSERT INTO banks (org_id, bank_id, bank_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		INSERT INTO bank_branch (org_id, bank_id, bank_branch_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		
		INSERT INTO transaction_counters(transaction_type_id, org_id, document_number)
		SELECT transaction_type_id, NEW.org_id, 1
		FROM transaction_types;
				
		INSERT INTO accounts_class (org_id, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name)
		SELECT NEW.org_id, accounts_class_no, chat_type_id, chat_type_name, accounts_class_name
		FROM accounts_class
		WHERE org_id = 1;
		
		INSERT INTO account_types (org_id, accounts_class_id, account_type_no, account_type_name)
		SELECT a.org_id, a.accounts_class_id, b.account_type_no, b.account_type_name
		FROM accounts_class a INNER JOIN vw_account_types b ON a.accounts_class_no = b.accounts_class_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO accounts (org_id, account_type_id, account_no, account_name)
		SELECT a.org_id, a.account_type_id, b.account_no, b.account_name
		FROM account_types a INNER JOIN vw_accounts b ON a.account_type_no = b.account_type_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO default_accounts (org_id, use_key_id, account_id)
		SELECT c.org_id, a.use_key_id, c.account_id
		FROM default_accounts a INNER JOIN accounts b ON a.account_id = b.account_id
			INNER JOIN accounts c ON b.account_no = c.account_no
		WHERE (a.org_id = 1) AND (c.org_id = NEW.org_id);
		
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Services');
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Goods');

		INSERT INTO item_units (org_id, item_unit_name) VALUES (NEW.org_id, 'Each');
		
		INSERT INTO stores (org_id, store_name) VALUES (NEW.org_id, 'Main Store');
		
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 0);	

		UPDATE entity_subscriptions SET entity_type_id = v_entity_type_id
		WHERE entity_id = NEW.entity_id;

		SELECT subscription_type_id INTO v_subscription_type_id
		FROM subscriptions;	

		IF (v_subscription_type_id = 1) THEN
			UPDATE entitys SET org_id = NEW.org_id, entity_type_id = v_entity_type_id, function_role='subscription,admin,staff'
			WHERE entity_id = NEW.entity_id;
		ELSIF (v_subscription_type_id = 2) THEN
			UPDATE entitys SET org_id = NEW.org_id, entity_type_id = v_entity_type_id, function_role='subscription,landlord,staff'
			WHERE entity_id = NEW.entity_id;
			----Add subscriptional details to the landlord table
			INSERT INTO landlord(org_id, landlord_name, landlord_email, telephone_number,town, nationality, is_active) VALUES
					(NEW.org_id,NEW.primary_contact,NEW.primary_email,NEW.telephone,NEW.city,NEW.country_id,true);
		END IF;

		---Property types
		INSERT INTO property_types (org_id, property_type_name)
		SELECT NEW.org_id, property_type_name
		FROM property_types
		WHERE org_id = 1;

		---Property amenity
		INSERT INTO property_amenity (org_id, amenity_name)
		SELECT NEW.org_id, amenity_name
		FROM property_amenity
		WHERE org_id = 1;

		---Commission Type
		INSERT INTO commission_types (org_id,commission_name)
		SELECT NEW.org_id, commission_name
		FROM commission_types
		WHERE org_id = 1;

		---Unit Types
		INSERT INTO unit_types (org_id,unit_type_name)
		SELECT NEW.org_id, unit_type_name
		FROM unit_types
		WHERE org_id = 1;
		
		INSERT INTO workflows (link_copy, org_id, source_entity_id, workflow_name, table_name, approve_email, reject_email) 
		SELECT aa.workflow_id, cc.org_id, cc.entity_type_id, aa.workflow_name, aa.table_name, aa.approve_email, aa.reject_email
		FROM workflows aa INNER JOIN entity_types bb ON aa.source_entity_id = bb.entity_type_id
			INNER JOIN entity_types cc ON bb.use_key_id = cc.use_key_id
		WHERE aa.org_id = 1 AND cc.org_id = NEW.org_id
		ORDER BY aa.workflow_id;

		INSERT INTO workflow_phases (org_id, workflow_id, approval_entity_id, approval_level, return_level, 
			escalation_days, escalation_hours, required_approvals, advice, notice, 
			phase_narrative, advice_email, notice_email) 
		SELECT bb.org_id, bb.workflow_id, dd.entity_type_id, aa.approval_level, aa.return_level, 
			aa.escalation_days, aa.escalation_hours, aa.required_approvals, aa.advice, aa.notice, 
			aa.phase_narrative, aa.advice_email, aa.notice_email
		FROM workflow_phases aa INNER JOIN workflows bb ON aa.workflow_id = bb.link_copy
			INNER JOIN entity_types cc ON aa.approval_entity_id = cc.entity_type_id
			INNER JOIN entity_types dd ON cc.use_key_id = dd.use_key_id
		WHERE aa.org_id = 1 AND bb.org_id = NEW.org_id AND dd.org_id = NEW.org_id;
		
		INSERT INTO sys_emails (org_id, use_type, sys_email_name, title, details)
		SELECT NEW.org_id, use_type, sys_email_name, title, details
		FROM sys_emails
		WHERE org_id = 1;

		INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
		VALUES (4, NEW.org_id, NEW.entity_id, 'subscription');
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_subscriptions BEFORE INSERT OR UPDATE ON subscriptions
    FOR EACH ROW EXECUTE PROCEDURE ins_subscriptions();

