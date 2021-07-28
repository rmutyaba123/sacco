
ALTER  TABLE orgs ADD 	deployment_filter			boolean default false not null;

CREATE TABLE approval_lists (
	approval_list_id		serial primary key,
	workflow_id				integer not null references workflows,
	entity_id				integer not null references entitys,
	entered_by				integer references entitys,
	org_id					integer references orgs,
	table_name				varchar(64),
	table_id				integer,
	application_date		timestamp default now() not null,
	action_date				timestamp,
	approve_status			varchar(16) default 'Completed' not null
);
CREATE INDEX approval_lists_workflow_id ON approval_lists (workflow_id);
CREATE INDEX approval_lists_entity_id ON approval_lists (entity_id);
CREATE INDEX approval_lists_entered_by ON approval_lists (entered_by);
CREATE INDEX approval_lists_table_id ON approval_lists (table_id);
CREATE INDEX approval_lists_approve_status ON approval_lists (approve_status);

CREATE VIEW vw_approval_lists AS
	SELECT vw_workflows.source_entity_id, vw_workflows.source_entity_name, vw_workflows.workflow_id,
		vw_workflows.workflow_name, vw_workflows.table_link_field, vw_workflows.table_link_id,
		vw_workflows.approve_email, vw_workflows.reject_email, vw_workflows.approve_file, vw_workflows.reject_file,
		en.entity_id, en.entity_name, en.primary_email,
		eb.entity_id as entered_by_id, eb.entity_name as entered_by_name, eb.primary_email as entered_by_email,
		orgs.org_id, orgs.org_name,  
		approval_lists.approval_list_id, approval_lists.table_name, approval_lists.table_id, 
		approval_lists.application_date, approval_lists.action_date, approval_lists.approve_status,
		(vw_workflows.workflow_name || ' ' || approval_lists.approve_status) as workflow_narrative
	FROM approval_lists INNER JOIN vw_workflows ON approval_lists.workflow_id = vw_workflows.workflow_id
		INNER JOIN entitys en ON approval_lists.entity_id = en.entity_id
		INNER JOIN entitys eb ON approval_lists.entered_by = eb.entity_id
		INNER JOIN orgs ON approval_lists.org_id = orgs.org_id;

		
CREATE OR REPLACE FUNCTION upd_action() RETURNS trigger AS $$
DECLARE
	v_column_name			varchar;
	v_workflow_narrative	varchar(240);
	v_entered_by			integer;
	wfid					integer;
	reca					record;
	tbid					integer;
	iswf					boolean;
	add_flow				boolean;
BEGIN
	add_flow := false;
	IF(TG_OP = 'INSERT')THEN
		IF (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	ELSE
		IF(OLD.approve_status = 'Draft') AND (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	END IF;

	IF(add_flow = true)THEN
		wfid := nextval('workflow_table_id_seq');
		NEW.workflow_table_id := wfid;

		SELECT column_name INTO v_column_name
		FROM information_schema.columns
		WHERE table_name = TG_TABLE_NAME AND column_name = 'workflow_narrative';
		IF(v_column_name is not null)THEN v_workflow_narrative := NEW.workflow_narrative; ELSE v_workflow_narrative := ''; END IF;
		
		SELECT column_name INTO v_column_name
		FROM information_schema.columns
		WHERE table_name = TG_TABLE_NAME AND column_name = 'entered_by';
		IF(v_column_name is not null)THEN v_entered_by := NEW.entered_by; ELSE v_entered_by := NEW.entity_id; END IF;

		IF(TG_OP = 'UPDATE')THEN
			IF(OLD.workflow_table_id is not null)THEN
				INSERT INTO workflow_logs (org_id, table_name, table_id, table_old_id)
				VALUES (NEW.org_id, TG_TABLE_NAME, wfid, OLD.workflow_table_id);
			END IF;
		END IF;

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id, workflows.org_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id = NEW.entity_id) LOOP
			iswf := true;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(TG_TABLE_NAME = 'entry_forms')THEN
					tbid := NEW.form_id;
				ELSIF(TG_TABLE_NAME = 'employee_leave')THEN
					tbid := NEW.leave_type_id;
				END IF;
				IF(tbid = reca.table_link_id)THEN
					iswf := true;
				END IF;
			END IF;

			IF(iswf = true)THEN
				INSERT INTO approval_lists (workflow_id, entity_id, entered_by, org_id, table_name, table_id, approve_status)
				VALUES (reca.workflow_id, NEW.entity_id, v_entered_by, reca.org_id, TG_TABLE_NAME, wfid, 'Completed');
				
				INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id,
					escalation_days, escalation_hours, approval_level,
					approval_narrative, to_be_done)
				SELECT org_id, workflow_phase_id, TG_TABLE_NAME, wfid, NEW.entity_id,
					escalation_days, escalation_hours, approval_level,
					(CASE WHEN phase_narrative is null THEN v_workflow_narrative
						ELSE phase_narrative || ' - ' || v_workflow_narrative END),
					'Approve - ' || COALESCE(phase_narrative, '')
				FROM vw_workflow_entitys
				WHERE (table_name = TG_TABLE_NAME) AND (entity_id = NEW.entity_id) AND (workflow_id = reca.workflow_id)
				ORDER BY approval_level, workflow_phase_id;

				UPDATE approvals SET approve_status = 'Completed'
				WHERE (table_id = wfid) AND (approval_level = 1);
			END IF;
		END LOOP;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upd_approvals() RETURNS trigger AS $$
DECLARE
	reca				RECORD;
	wfid				integer;
	v_org_id			integer;
	v_notice			boolean;
	v_advice			boolean;
BEGIN

	SELECT notice, advice, org_id INTO v_notice, v_advice, v_org_id
	FROM workflow_phases
	WHERE (workflow_phase_id = NEW.workflow_phase_id);

	IF(TG_OP = 'INSERT')THEN
		IF (NEW.approve_status = 'Completed') THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 1, v_org_id);
		END IF;
		IF (NEW.approve_status = 'Approved') AND (v_advice = true) AND (NEW.forward_id is null) THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 1, v_org_id);
		END IF;
		IF (NEW.approve_status = 'Approved') AND (v_notice = true) AND (NEW.forward_id is null) THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 2, v_org_id);
		END IF;
	ELSE
		IF (OLD.approve_status = 'Draft') AND (NEW.approve_status = 'Completed') THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 1, v_org_id);
		END IF;
		IF (OLD.approve_status != 'Approved') AND (NEW.approve_status = 'Approved') AND (v_advice = true) AND (NEW.forward_id is null) THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 1, v_org_id);
		END IF;
		IF (OLD.approve_status != 'Approved') AND (NEW.approve_status = 'Approved') AND (v_notice = true) AND (NEW.forward_id is null) THEN
			INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
			VALUES (NEW.approval_id, TG_TABLE_NAME, 2, v_org_id);
		END IF;
	END IF;

	IF(TG_OP = 'INSERT') AND (NEW.forward_id is null) THEN
		INSERT INTO approval_checklists (approval_id, checklist_id, requirement, manditory, org_id)
		SELECT NEW.approval_id, checklist_id, requirement, manditory, org_id
		FROM checklists
		WHERE (workflow_phase_id = NEW.workflow_phase_id)
		ORDER BY checklist_number;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upd_approvals(varchar(12), varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	app_id		Integer;
	reca 		RECORD;
	recb		RECORD;
	recc		RECORD;
	min_level	Integer;
	mysql		varchar(240);
	msg 		varchar(120);
BEGIN
	app_id := CAST($1 as int);
	SELECT approvals.org_id, approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id,
		approvals.approval_level, approvals.review_advice, approvals.org_entity_id,
		workflow_phases.workflow_phase_id, workflow_phases.workflow_id, workflow_phases.return_level INTO reca
	FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
	WHERE (approvals.approval_id = app_id);

	SELECT count(approval_checklist_id) as cl_count INTO recc
	FROM approval_checklists
	WHERE (approval_id = app_id) AND (manditory = true) AND (done = false);

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false) AND (workflow_phases.notice = false);

		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved')
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;
			
			UPDATE approval_lists SET action_date = current_timestamp, approve_status = 'Approved' WHERE table_id = reca.table_id;

			INSERT INTO sys_emailed (org_id, table_id, table_name, email_type)
			VALUES (reca.org_id, reca.table_id, 'vw_workflow_approvals', 1);

			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level >= reca.approval_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level <= min_level) LOOP
				IF (recb.advice = true) or (recb.notice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id)
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				ELSE
					UPDATE approvals SET approve_status = 'Completed', completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id)
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		END IF;
		msg := 'Approved';
	ELSIF ($3 = '3') THEN
		UPDATE approvals SET approve_status = 'Rejected',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Rejected')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;
		
		UPDATE approval_lists SET action_date = current_timestamp, approve_status = 'Rejected' WHERE table_id = reca.table_id;

		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (reca.table_id, 'vw_workflow_approvals', 2, reca.org_id);
		msg := 'Rejected';
	ELSIF ($3 = '4') AND (reca.return_level = 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Draft')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;
		
		UPDATE approval_lists SET action_date = current_timestamp, approve_status = 'Review' WHERE table_id = reca.table_id;

		msg := 'Forwarded to owner for review';
	ELSIF ($3 = '4') AND (reca.return_level <> 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, workflow_phase_id, reca.table_name, reca.table_id, CAST($2 as int), escalation_days, escalation_hours, approval_level, phase_narrative, reca.review_advice, 'Completed'
		FROM vw_workflow_entitys
		WHERE (workflow_id = reca.workflow_id) AND (approval_level = reca.return_level)
			AND (entity_id = reca.org_entity_id)
		ORDER BY workflow_phase_id;

		UPDATE approvals SET approve_status = 'Draft' WHERE approval_id = app_id;

		msg := 'Forwarded for review';
	END IF;

	RETURN msg;
END;
$$ LANGUAGE plpgsql;
