---Project Database File
CREATE TABLE regions (
	region_id				serial primary key,
	region_name				varchar(50) not null unique,
	details					text
);

CREATE TABLE counties (
	county_id				serial primary key,
	region_id				integer references regions,
	county_name				varchar(50) not null unique,
	details					text
);
CREATE INDEX counties_region_id ON counties (region_id);

CREATE TABLE constituency (
	constituency_id			serial primary key,
	county_id				integer references counties,
	constituency_name		varchar(240),
	constituency_code		varchar(12),
	details					text
);
CREATE INDEX constituency_county_id ON constituency (county_id);

CREATE TABLE wards (
	ward_id					serial primary key,
	constituency_id			integer references constituency,
	ward_name				varchar(240),
	ward_code				varchar(12),
	details					text
);
CREATE INDEX wards_constituency_id ON wards (constituency_id);

CREATE TABLE rankings (
	ranking_id				serial primary key,
	ranking_name			varchar(50) not null unique,
	rank_initials			varchar(12),
	cap_amounts				real default 0 not null,
	details					text
);

CREATE TABLE division_types (
	division_type_id		serial primary key,
	division_type_name		varchar(50) not null unique,
	details					text
);

CREATE TABLE court_ranks (
	court_rank_id			serial primary key,
	court_rank_name			varchar(50) not null unique,
	details					text
);

CREATE TABLE court_stations (
	court_station_id		serial primary key,
	court_rank_id			integer references court_ranks,
	county_id				integer references counties,
	org_id					integer references orgs,
	court_station_name		varchar(50),
	court_station_code		varchar(50),
	district				varchar(50),
	Details					text
);
CREATE INDEX court_stations_court_rank_id ON court_stations (court_rank_id);
CREATE INDEX court_stations_county_id ON court_stations (county_id);
CREATE INDEX court_Stations_org_id ON court_Stations (org_id);
SELECT setval('court_stations_court_station_id_seq', 100);

CREATE TABLE court_divisions (
	court_division_id		serial primary key,
	court_station_id		integer references court_stations,
	division_type_id		integer references division_types,
	org_id					integer references orgs,
	court_division_code		varchar(16),
	court_division_num		integer default 1 not null,
	details					text,
	UNIQUE(court_station_id, division_type_id)
);
CREATE INDEX court_divisions_court_station_id ON court_divisions (court_station_id);
CREATE INDEX court_divisions_division_type_id ON court_divisions (division_type_id);
CREATE INDEX court_divisions_org_id ON court_divisions (org_id);

CREATE TABLE police_stations (
	police_station_id		serial primary key,
	court_station_id		integer references court_stations,
	org_id					integer references orgs,
	police_station_name		varchar(50) not null,
	police_station_phone	varchar(50),
	details					text
);
CREATE INDEX police_stations_court_station_id ON police_stations (court_station_id);
CREATE INDEX police_stations_org_id ON police_stations (org_id);

CREATE TABLE hearing_locations (
	hearing_location_id		serial primary key,
	court_station_id		integer references court_stations,
	org_id					integer references orgs,
	hearing_location_name	varchar(50),
	Details					text
);
CREATE INDEX hearing_locations_court_station_id ON hearing_locations (court_station_id);
CREATE INDEX hearing_locations_org_id ON hearing_locations (org_id);

CREATE TABLE file_locations (
	file_location_id		serial primary key,
	court_station_id		integer references court_stations,
	org_id					integer references orgs,
	file_location_name		varchar(50),
	Details					text
);
CREATE INDEX file_locations_court_station_id ON file_locations (court_station_id);
CREATE INDEX file_locations_org_id ON file_locations (org_id);

CREATE TABLE disability (
	disability_id			serial primary key,
	disability_name			varchar(240) not null
);

CREATE TABLE id_types (
	id_type_id				serial primary key,  
	id_type_name			varchar(120) not null
);

ALTER TABLE entitys
ADD disability_id			integer references disability,
ADD	court_station_id		integer references court_stations,
ADD	ranking_id				integer references rankings,
ADD	id_type_id				integer references id_types,
ADD	country_aquired			char(2) references sys_countrys,
ADD	station_judge			boolean default false not null,
ADD	is_available			boolean default true not null,
ADD	identification			varchar(50),
ADD	gender					char(1),
ADD	date_of_birth			date,
ADD	deceased				boolean default false not null,
ADD	date_of_death			date;
CREATE INDEX entitys_disability_id ON entitys (disability_id);
CREATE INDEX entitys_court_station_id ON entitys (court_station_id);
CREATE INDEX entitys_ranking_id ON entitys (ranking_id);
CREATE INDEX entitys_id_type_id ON entitys (id_type_id);
CREATE INDEX entitys_country_aquired ON entitys (country_aquired);

CREATE TABLE entity_idents (
	entity_ident_id			serial primary key,
	entity_id				integer not null references entitys,
	id_type_id				integer not null references id_types,
	org_id					integer not null references orgs,
	id_number				varchar(50) not null,
	details					text
);
CREATE INDEX entity_idents_entity_id ON entity_idents (entity_id);
CREATE INDEX entity_idents_id_type_id ON entity_idents (id_type_id);
CREATE INDEX entity_idents_org_id ON entity_idents (org_id);

CREATE TABLE cal_block_types (
	cal_block_type_id			serial primary key,  
	cal_block_type_name			varchar(120) not null
);

CREATE TABLE cal_holidays (
	cal_holiday_id				serial primary key,
	cal_holiday_name			varchar(50) not null,
	cal_holiday_date			date
);

CREATE TABLE cal_entity_blocks (
	cal_entity_block_id		serial primary key,
	entity_id				integer not null references entitys,
	cal_block_type_id		integer not null references cal_block_types,
	org_id					integer not null references orgs,
	start_date				date,
	start_time				time,
	end_date				date,
	end_time				time,
	reason					varchar(320),
	details					text
);
CREATE INDEX cal_entity_blocks_entity_id ON cal_entity_blocks (entity_id);
CREATE INDEX cal_entity_blocks_cal_block_type_id ON cal_entity_blocks (cal_block_type_id);
CREATE INDEX cal_entity_blocks_org_id ON cal_entity_blocks (org_id);

CREATE VIEW vw_counties AS
	SELECT regions.region_id, regions.region_name, counties.county_id, counties.county_name, counties.details
	FROM counties INNER JOIN regions ON counties.region_id = regions.region_id;

CREATE VIEW vw_constituency AS
	SELECT vw_counties.region_id, vw_counties.region_name, vw_counties.county_id, vw_counties.county_name,
		constituency.constituency_id, constituency.constituency_name, constituency.constituency_code, 
		constituency.details, (vw_counties.county_name || ', ' || constituency.constituency_name) as constituency
	FROM constituency INNER JOIN vw_counties ON constituency.county_id = vw_counties.county_id;

CREATE VIEW vw_wards AS
	SELECT vw_constituency.region_id, vw_constituency.region_name, vw_constituency.county_id, vw_constituency.county_name,
		vw_constituency.constituency_id, vw_constituency.constituency_name, vw_constituency.constituency_code,
		wards.ward_id, wards.ward_name, wards.ward_code, wards.details,
		(vw_constituency.constituency || ', ' || wards.ward_name) as ward
	FROM wards INNER JOIN vw_constituency ON wards.constituency_id = vw_constituency.constituency_id;

CREATE VIEW vw_court_stations AS
	SELECT vw_counties.region_id, vw_counties.region_name, vw_counties.county_id, vw_counties.county_name,
		court_ranks.court_rank_id, court_ranks.court_rank_name, court_stations.court_station_id, court_stations.court_station_name, 
		court_stations.org_id, court_stations.court_station_code, court_stations.details, 
		(court_ranks.court_rank_name || ' : ' || court_stations.court_station_name) as court_station
	FROM court_stations INNER JOIN court_ranks ON court_stations.court_rank_id = court_ranks.court_rank_id
		INNER JOIN vw_counties ON vw_counties.county_id = court_stations.county_id;

CREATE VIEW vw_court_divisions AS
	SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name,
		vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, 
		vw_court_stations.court_station_code, vw_court_stations.court_station,
		division_types.division_type_id, division_types.division_type_name, court_divisions.org_id, 
		court_divisions.court_division_id, court_divisions.court_division_code, court_divisions.court_division_num, 
		court_divisions.details,
		(vw_court_stations.court_station || ' : ' || division_types.division_type_name) as court_division
	FROM court_divisions INNER JOIN vw_court_stations ON court_divisions.court_station_id = vw_court_stations.court_station_id
	INNER JOIN division_types ON court_divisions.division_type_id = division_types.division_type_id;

CREATE VIEW vw_hearing_locations AS
	SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name,
		vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, 
		vw_court_stations.court_station_code, vw_court_stations.court_station,
		hearing_locations.hearing_location_id, hearing_locations.hearing_location_name, hearing_locations.org_id,
		hearing_locations.details,
		(vw_court_stations.court_station || ' : ' || hearing_locations.hearing_location_name) as hearing_location
	FROM hearing_locations INNER JOIN vw_court_stations ON hearing_locations.court_station_id = vw_court_stations.court_station_id;

CREATE VIEW vw_file_locations AS
	SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name,
		vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, 
		vw_court_stations.court_station_code, vw_court_stations.court_station,
		file_locations.file_location_id, file_locations.file_location_name, file_locations.org_id, file_locations.details,
		(vw_court_stations.court_station || ' : ' || file_locations.file_location_name) as file_location
	FROM file_locations INNER JOIN vw_court_stations ON file_locations.court_station_id = vw_court_stations.court_station_id;

CREATE VIEW vw_police_stations AS
	SELECT vw_court_stations.region_id, vw_court_stations.region_name, vw_court_stations.county_id, vw_court_stations.county_name,
		vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id, vw_court_stations.court_station_name, 
		vw_court_stations.court_station_code, vw_court_stations.court_station,
		police_stations.org_id, police_stations.police_station_id, police_stations.police_station_name, 
		police_stations.police_station_phone, police_stations.details
	FROM police_stations INNER JOIN vw_court_stations ON police_stations.court_station_id = vw_court_stations.court_station_id;

DROP VIEW vw_entitys;
CREATE VIEW vw_entitys AS
	SELECT entitys.entity_id, entitys.entity_name, entitys.user_name, entitys.primary_email, entitys.super_user, 
		entitys.entity_leader, entitys.no_org, entitys.function_role, entitys.date_enroled, entitys.is_active, 
		entitys.entity_password, entitys.first_password, entitys.new_password, entitys.start_url, entitys.is_picked, 
		entitys.country_aquired, entitys.station_judge, entitys.identification, entitys.gender, 
		entitys.org_id, entitys.date_of_birth, entitys.deceased, entitys.date_of_death, entitys.details,
		entity_types.entity_type_id, entity_types.entity_type_name,
		vw_court_stations.court_rank_id, vw_court_stations.court_rank_name, vw_court_stations.court_station_id,
		vw_court_stations.court_station_name, vw_court_stations.court_station,
		rankings.ranking_id, rankings.ranking_name,
		sys_countrys.sys_country_id, sys_countrys.sys_country_name,
		id_types.id_type_id, id_types.id_type_name,
		disability.disability_id, disability.disability_name
	FROM entitys INNER JOIN entity_types ON entitys.entity_type_id = entity_types.entity_type_id
		LEFT JOIN vw_court_stations ON entitys.court_station_id = vw_court_stations.court_station_id
		LEFT JOIN rankings ON entitys.ranking_id = rankings.ranking_id
		LEFT JOIN sys_countrys ON entitys.country_aquired = sys_countrys.sys_country_id
		LEFT JOIN disability ON entitys.disability_id = disability.disability_id
		LEFT JOIN id_types ON entitys.id_type_id = id_types.id_type_id;

CREATE VIEW vw_entity_idents AS
	SELECT entitys.entity_id, entitys.entity_name, id_types.id_type_id, id_types.id_type_name, 
		entity_idents.org_id,  entity_idents.entity_ident_id, entity_idents.id_number, entity_idents.details
	FROM entity_idents INNER JOIN entitys ON entity_idents.entity_id = entitys.entity_id
		INNER JOIN id_types ON entity_idents.id_type_id = id_types.id_type_id;

CREATE VIEW vw_cal_entity_blocks AS
	SELECT cal_block_types.cal_block_type_id, cal_block_types.cal_block_type_name, entitys.entity_id, entitys.entity_name,
		cal_entity_blocks.org_id, cal_entity_blocks.cal_entity_block_id, cal_entity_blocks.reason,
		cal_entity_blocks.start_date, cal_entity_blocks.start_time, cal_entity_blocks.end_date, cal_entity_blocks.end_time, 
		cal_entity_blocks.details
	FROM cal_entity_blocks INNER JOIN cal_block_types ON cal_entity_blocks.cal_block_type_id = cal_block_types.cal_block_type_id
		INNER JOIN entitys ON cal_entity_blocks.entity_id = entitys.entity_id;

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

CREATE TRIGGER ins_court_stations BEFORE INSERT OR UPDATE ON court_stations
    FOR EACH ROW EXECUTE PROCEDURE ins_court_stations();

CREATE OR REPLACE FUNCTION aft_court_stations() RETURNS trigger AS $$
BEGIN
	INSERT INTO court_divisions (court_station_id, org_id, division_type_id, court_division_code)
	SELECT NEW.court_station_id, NEW.court_station_id, division_type_id, upper(substr(division_type_name, 1, 2))
	FROM division_types;

	INSERT INTO hearing_locations (court_station_id, org_id, hearing_location_name)
	VALUES (NEW.court_station_id, NEW.org_id, 'Registry');
	INSERT INTO hearing_locations (court_station_id, org_id, hearing_location_name)
	VALUES (NEW.court_station_id, NEW.org_id, 'Room 1');
	INSERT INTO bank_accounts (org_id, bank_account_name, bank_name, branch_name, is_default, is_active)
	VALUES (NEW.org_id, 'Cash', 'Cash', 'Local', true, true);
	
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER aft_court_stations AFTER INSERT ON court_stations
    FOR EACH ROW EXECUTE PROCEDURE aft_court_stations();

CREATE OR REPLACE FUNCTION upd_entitys() RETURNS trigger AS $$
DECLARE
	v_org_id		integer;
BEGIN

	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);

	IF(TG_OP = 'INSERT')THEN
		IF (NEW.court_station_id is not null)THEN
			NEW.org_id := v_org_id;
		END IF;
	ELSIF(TG_OP = 'UPDATE')THEN
		IF (OLD.court_station_id <> NEW.court_station_id)THEN
			NEW.org_id := v_org_id;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER upd_entitys BEFORE INSERT OR UPDATE ON entitys
  FOR EACH ROW EXECUTE PROCEDURE upd_entitys();

CREATE OR REPLACE FUNCTION ins_court_divisions() RETURNS trigger AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_court_divisions BEFORE INSERT OR UPDATE ON court_divisions
    FOR EACH ROW EXECUTE PROCEDURE ins_court_divisions();

CREATE OR REPLACE FUNCTION ins_police_stations() RETURNS trigger AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_police_stations BEFORE INSERT OR UPDATE ON police_stations
    FOR EACH ROW EXECUTE PROCEDURE ins_police_stations();

CREATE OR REPLACE FUNCTION ins_hearing_locations() RETURNS trigger AS $$
DECLARE
	v_org_id		integer;
BEGIN
	SELECT org_id INTO v_org_id
	FROM court_stations
	WHERE (court_station_id = NEW.court_station_id);
	
	NEW.org_id := v_org_id;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_hearing_locations BEFORE INSERT OR UPDATE ON hearing_locations
    FOR EACH ROW EXECUTE PROCEDURE ins_hearing_locations();



