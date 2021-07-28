
CREATE TABLE work_rates (
	work_rate_id			serial primary key,
	org_id					integer references orgs,
	work_rate_name			varchar(50),
	work_rate_code			varchar(50),
	group_rate				boolean default false not null,
	work_rate				real default 0 not null,
	weight_rate				real default 0 not null,
	overtime_rate			real default 0 not null,
	special_rate			real default 0 not null,
	details					text
);
CREATE INDEX work_rates_org_id ON work_rates (org_id);

CREATE TABLE work_rate_changes (
	work_rate_change		serial primary key,
	work_rate_id			integer references work_rates,
	org_id					integer references orgs,
	work_rate_name			varchar(50),
	work_rate_code			varchar(50),
	work_rate				real default 0 not null,
	weight_rate				real default 0 not null,
	overtime_rate			real default 0 not null,
	special_rate			real default 0 not null,
	change_date				timestamp default current_timestamp not null
);
CREATE INDEX work_rate_changes_work_rate_id ON work_rate_changes (work_rate_id);
CREATE INDEX work_rate_changes_org_id ON work_rate_changes (org_id);

CREATE TABLE farm_fields (
	farm_field_id			serial primary key,
	org_id					integer references orgs,
	farm_field_name			varchar(50),
	details					text
);
CREATE INDEX farm_fields_org_id ON farm_fields (org_id);

CREATE TABLE day_works (
	day_work_id				serial primary key,
	period_id				integer references periods not null,
	entity_id				integer references entitys,
	farm_field_id			integer references farm_fields,
	org_id					integer references orgs,
	
	batch_ref				varchar(50),
	work_date				date,
	work_start				time,
	work_end				time,
	
	farm_weight				real,
	factory_weight			real,

	details					text
);
CREATE INDEX day_works_period_id ON day_works (period_id);
CREATE INDEX day_works_entity_id ON day_works (entity_id);
CREATE INDEX day_works_farm_field_id ON day_works (farm_field_id);
CREATE INDEX day_works_org_id ON day_works (org_id);

CREATE TABLE works (
	work_id					serial primary key,
	day_work_id				integer references day_works not null,
	entity_id				integer references entitys not null,
	work_rate_id			integer references work_rates not null,
	org_id					integer references orgs,
	
	work_weight				real default 0 not null,
	work_pay				integer default 0 not null,
	overtime				real default 0  not null,
	special_time			real default 0 not null,
	work_amount				real default 0 not null,
	narrative				varchar(320),
	UNIQUE(day_work_id, entity_id)
);
CREATE INDEX works_day_work_id ON works (day_work_id);
CREATE INDEX works_entity_id ON works (entity_id);
CREATE INDEX works_work_rate_id ON works (work_rate_id);
CREATE INDEX works_org_id ON works (org_id);

CREATE TABLE work_groups (
	work_group_id			serial primary key,
	day_work_id				integer references day_works not null,
	work_rate_id			integer references work_rates not null,
	org_id					integer references orgs,
	
	group_number			integer default 0 not null,
	work_weight				real default 0 not null,
	work_pay				integer default 0 not null,
	overtime				real default 0 not null,
	special_time			real default 0 not null,
	work_amount				real default 0 not null,
	narrative				varchar(320)
);
CREATE INDEX work_groups_day_work_id ON work_groups (day_work_id);
CREATE INDEX work_groups_work_rate_id ON work_groups (work_rate_id);
CREATE INDEX work_groups_org_id ON work_groups (org_id);

CREATE TABLE work_members (
	work_member_id			serial primary key,
	work_group_id			integer references work_groups not null,
	entity_id				integer references entitys not null,
	org_id					integer references orgs,
	narrative				varchar(320)
);
CREATE INDEX work_members_work_group_id ON work_members (work_group_id);
CREATE INDEX work_members_entity_id ON work_members (entity_id);
CREATE INDEX work_members_org_id ON work_members (org_id);

	
CREATE VIEW vw_day_works AS
	SELECT entitys.entity_id as supervisor_id, entitys.entity_name as supervisor_name, 
		farm_fields.farm_field_id, farm_fields.farm_field_name, 
		
		vw_periods.period_id, vw_periods.start_date, vw_periods.end_date, 
		vw_periods.activated, vw_periods.closed, vw_periods.month_id, vw_periods.period_year, 
		vw_periods.period_month, vw_periods.quarter, vw_periods.semister,
		
		day_works.org_id, day_works.day_work_id, day_works.batch_ref, day_works.work_date, day_works.work_start, 
		day_works.work_end, day_works.farm_weight, day_works.factory_weight, day_works.details
	
	FROM day_works INNER JOIN entitys ON day_works.entity_id = entitys.entity_id
		INNER JOIN farm_fields ON day_works.farm_field_id = farm_fields.farm_field_id
		INNER JOIN vw_periods ON day_works.period_id = vw_periods.period_id;
		
CREATE VIEW vw_works AS
	SELECT vw_day_works.supervisor_id, vw_day_works.supervisor_name, 
		vw_day_works.farm_field_id, vw_day_works.farm_field_name, 
		vw_day_works.period_id, vw_day_works.start_date, vw_day_works.end_date, 
		vw_day_works.activated, vw_day_works.closed, vw_day_works.month_id, vw_day_works.period_year, 
		vw_day_works.period_month, vw_day_works.quarter, vw_day_works.semister,		
		vw_day_works.day_work_id, vw_day_works.batch_ref, vw_day_works.work_date, 
		vw_day_works.work_start, vw_day_works.work_end, vw_day_works.farm_weight, vw_day_works.factory_weight,
		
		entitys.entity_id as worker_id, entitys.entity_name as worker_name, 
		
		work_rates.work_rate_id, work_rates.work_rate_name, work_rates.work_rate_code,

		works.org_id, works.work_id, works.work_weight, works.work_pay, works.overtime, works.special_time,
		works.work_amount, works.narrative
	FROM works INNER JOIN vw_day_works ON works.day_work_id = vw_day_works.day_work_id
		INNER JOIN entitys ON works.entity_id = entitys.entity_id
		INNER JOIN work_rates ON works.work_rate_id = work_rates.work_rate_id;

CREATE VIEW vw_work_groups AS
	SELECT vw_day_works.supervisor_id, vw_day_works.supervisor_name, 
		vw_day_works.farm_field_id, vw_day_works.farm_field_name, 
		vw_day_works.period_id, vw_day_works.start_date, vw_day_works.end_date, 
		vw_day_works.activated, vw_day_works.closed, vw_day_works.month_id, vw_day_works.period_year, 
		vw_day_works.period_month, vw_day_works.quarter, vw_day_works.semister,		
		vw_day_works.day_work_id, vw_day_works.batch_ref, vw_day_works.work_date, 
		vw_day_works.work_start, vw_day_works.work_end, vw_day_works.farm_weight, vw_day_works.factory_weight,
		
		work_rates.work_rate_id, work_rates.work_rate_name, work_rates.work_rate_code,
		
		work_groups.org_id, work_groups.work_group_id, work_groups.work_weight, work_groups.work_pay, 
		work_groups.overtime, work_groups.special_time, work_groups.work_amount, 
		work_groups.group_number, work_groups.narrative,
		wm.worker_count, 
		(CASE WHEN wm.worker_count = 0 THEN 0 ELSE (work_groups.work_weight / wm.worker_count) END) as worker_weight,
		(CASE WHEN wm.worker_count = 0 THEN 0 ELSE (work_groups.work_amount / wm.worker_count) END) as worker_amount
	FROM work_groups INNER JOIN vw_day_works ON work_groups.day_work_id = vw_day_works.day_work_id
		INNER JOIN work_rates ON work_groups.work_rate_id = work_rates.work_rate_id
		LEFT JOIN (SELECT work_group_id, count(work_member_id) as worker_count
			FROM work_members GROUP BY work_group_id) wm ON work_groups.work_group_id = wm.work_group_id;
	
CREATE VIEW vw_work_members AS
	SELECT vw_work_groups.supervisor_id, vw_work_groups.supervisor_name, 
		vw_work_groups.farm_field_id, vw_work_groups.farm_field_name, 
		vw_work_groups.period_id, vw_work_groups.start_date, vw_work_groups.end_date, 
		vw_work_groups.activated, vw_work_groups.closed, vw_work_groups.month_id, vw_work_groups.period_year, 
		vw_work_groups.period_month, vw_work_groups.quarter, vw_work_groups.semister,		
		vw_work_groups.day_work_id, vw_work_groups.batch_ref, vw_work_groups.work_date, 
		vw_work_groups.work_start, vw_work_groups.work_end, vw_work_groups.farm_weight, vw_work_groups.factory_weight,
		vw_work_groups.work_rate_id, vw_work_groups.work_rate_name, vw_work_groups.work_rate_code,
		vw_work_groups.work_group_id, vw_work_groups.work_weight, vw_work_groups.work_pay, 
		vw_work_groups.overtime, vw_work_groups.special_time, vw_work_groups.work_amount, 
		vw_work_groups.group_number, vw_work_groups.worker_count, 
		vw_work_groups.worker_weight, vw_work_groups.worker_amount,
		
		entitys.entity_id as worker_id, entitys.entity_name as worker_name, 
		work_members.org_id, work_members.work_member_id, work_members.narrative
	FROM work_members INNER JOIN vw_work_groups ON work_members.work_group_id = vw_work_groups.work_group_id
		INNER JOIN entitys ON work_members.entity_id = entitys.entity_id;
	
	
CREATE OR REPLACE FUNCTION ins_works() RETURNS trigger AS $$
BEGIN

	IF(NEW.work_weight = 0) AND (NEW.work_pay = 0)THEN
		NEW.work_pay = 1;
	END IF;
	
	SELECT (work_rates.weight_rate * NEW.work_weight + work_rates.work_rate * NEW.work_pay +
		work_rates.overtime_rate * NEW.overtime + work_rates.special_rate * NEW.special_time) INTO NEW.work_amount
	
	FROM work_rates 
	WHERE work_rate_id = NEW.work_rate_id;
	

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_works BEFORE INSERT OR UPDATE ON works
    FOR EACH ROW EXECUTE PROCEDURE ins_works();
    
CREATE OR REPLACE FUNCTION ins_work_groups() RETURNS trigger AS $$
BEGIN

	IF(NEW.work_weight = 0) AND (NEW.work_pay = 0)THEN
		NEW.work_pay = 1;
	END IF;
	
	SELECT (work_rates.weight_rate * NEW.work_weight + work_rates.work_rate * NEW.work_pay +
		work_rates.overtime_rate * NEW.overtime + work_rates.special_rate * NEW.special_time) INTO NEW.work_amount
	
	FROM work_rates 
	WHERE work_rate_id = NEW.work_rate_id;
	

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_work_groups BEFORE INSERT OR UPDATE ON work_groups
    FOR EACH ROW EXECUTE PROCEDURE ins_work_groups();
    
CREATE OR REPLACE FUNCTION farm_payroll(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	rec 		RECORD;
	msg 		varchar(120);
BEGIN
	IF ($3 = '1') THEN
		FOR rec IN SELECT works.entity_id, sum(works.work_amount) as sum_amount
			FROM works INNER JOIN day_works ON works.day_work_id = day_works.day_work_id
			WHERE (day_works.period_id = $1::int) 
			GROUP BY works.entity_id
		LOOP
		
			UPDATE employee_month SET basic_pay = rec.sum_amount
			WHERE (entity_id = rec.entity_id) 
				AND (period_id = $1::int);
				
		END LOOP;
		
		FOR rec IN SELECT vw_work_members.entity_id, sum(vw_work_members.work_amount) as sum_amount
			FROM vw_work_members
			WHERE (vw_work_members.period_id = $1::int) 
			GROUP BY vw_work_members.entity_id
		LOOP
		
			UPDATE employee_month SET basic_pay = basic_pay + rec.sum_amount
			WHERE (entity_id = rec.entity_id) 
				AND (period_id = $1::int);
				
		END LOOP;
		
		msg := 'Payroll Processed';
	END IF;

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upd_work_rates() RETURNS trigger AS $$
BEGIN

	INSERT INTO work_rate_changes (work_rate_id, org_id, work_rate_name, work_rate_code, work_rate,
		weight_rate, overtime_rate, special_rate)
	VALUES (NEW.work_rate_id, NEW.org_id, NEW.work_rate_name, NEW.work_rate_code, NEW.work_rate,
		NEW.weight_rate, NEW.overtime_rate, NEW.special_rate);	

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_work_rates AFTER UPDATE ON work_rates
    FOR EACH ROW EXECUTE PROCEDURE upd_work_rates();
    

CREATE OR REPLACE FUNCTION aft_work_groups() RETURNS trigger AS $$
DECLARE
	v_work_group_id			integer;
BEGIN

	SELECT max(work_group_id) INTO v_work_group_id
	FROM work_groups
	WHERE (work_group_id <> NEW.work_group_id) AND (group_number = NEW.group_number)
		AND (org_id = NEW.org_id);
	
	INSERT INTO work_members (work_group_id, entity_id, org_id)
	SELECT NEW.work_group_id, entity_id, org_id
	FROM work_members
	WHERE (work_group_id = v_work_group_id);

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_work_groups AFTER INSERT ON work_groups
    FOR EACH ROW EXECUTE PROCEDURE aft_work_groups();
    
    
