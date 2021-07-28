
CREATE TABLE ptypes (
	ptype_id				serial primary key,
	org_id					integer references orgs,
	ptype_name				varchar(50) not null,
	details					text
);
CREATE INDEX ptypes_org_id ON ptypes(org_id);

CREATE TABLE pdefinitions (
	pdefinition_id			serial primary key,
	ptype_id				integer references ptypes,
	org_id					integer references orgs,
	pdefinition_name		varchar(50)  not null,
	description				text,
	solution				text
);
CREATE INDEX pdefinitions_ptype_id ON pdefinitions(ptype_id);
CREATE INDEX pdefinitions_org_id ON pdefinitions(org_id);

CREATE TABLE plevels (
	plevel_id				serial primary key,
	org_id					integer references orgs,
	plevel_name				varchar(50) not null unique,
	details					text
);
CREATE INDEX plevels_org_id ON plevels(org_id);

CREATE TABLE helpdesk (
	helpdesk_id				serial primary key,
	pdefinition_id			integer references pdefinitions,
	plevel_id				integer references plevels,
	client_id				integer references entitys,
	recorded_by				integer references entitys,
	closed_by				integer references entitys,
	org_id					integer references orgs,
	description				varchar(120) not null,
	reported_by				varchar(50) not null,
	recoded_time			timestamp not null default now(),
	solved_time				timestamp,
	is_solved				boolean not null default false,
	curr_action				varchar(50),
	curr_status				varchar(50),
	problem					text,
	solution				text
);
CREATE INDEX helpdesk_pdefinition_id ON helpdesk(pdefinition_id);
CREATE INDEX helpdesk_plevel_id ON helpdesk(plevel_id);
CREATE INDEX helpdesk_client_id ON helpdesk(client_id);
CREATE INDEX helpdesk_recorded_by ON helpdesk(recorded_by);
CREATE INDEX helpdesk_closed_by ON helpdesk(closed_by);
CREATE INDEX helpdesk_org_id ON helpdesk(org_id);

CREATE VIEW vw_pdefinitions AS
	SELECT ptypes.ptype_id, ptypes.ptype_name, 
		pdefinitions.org_id, pdefinitions.pdefinition_id, pdefinitions.pdefinition_name, 
		pdefinitions.description, pdefinitions.solution
	FROM pdefinitions INNER JOIN ptypes ON pdefinitions.ptype_id = ptypes.ptype_id;
	
CREATE VIEW vw_helpdesk AS
	SELECT vw_pdefinitions.ptype_id, vw_pdefinitions.ptype_name, 
		vw_pdefinitions.pdefinition_id, vw_pdefinitions.pdefinition_name, 
		plevels.plevel_id, plevels.plevel_name,
		helpdesk.client_id, clients.entity_name as client_name, 
		helpdesk.recorded_by, recorder.entity_name as recorder_name, 
		helpdesk.closed_by, closer.entity_name as closer_name, 
		helpdesk.org_id, helpdesk.helpdesk_id, helpdesk.description, helpdesk.reported_by, 
		helpdesk.recoded_time, helpdesk.solved_time, helpdesk.is_solved, helpdesk.curr_action, 
		helpdesk.curr_status, helpdesk.problem, helpdesk.solution
	FROM helpdesk INNER JOIN vw_pdefinitions ON helpdesk.pdefinition_id = vw_pdefinitions.pdefinition_id
		INNER JOIN plevels ON helpdesk.plevel_id = plevels.plevel_id
		INNER JOIN entitys as clients ON helpdesk.client_id = clients.entity_id
		INNER JOIN entitys as recorder ON helpdesk.recorded_by = recorder.entity_id
		LEFT JOIN entitys as closer ON helpdesk.closed_by = closer.entity_id;
	

CREATE OR REPLACE FUNCTION close_issue(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg 					varchar(120);
BEGIN

	msg := null;
	
	IF($3 = '1')THEN
		UPDATE helpdesk SET closed_by = $2::integer, solved_time = current_timestamp, is_solved = true
		WHERE helpdesk_id = $1::integer;
		
		msg := 'Closed the call';
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;

