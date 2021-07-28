CREATE OR REPLACE FUNCTION add_sys_reset(varchar(120), varchar(120), varchar(64)) RETURNS varchar(120) AS $$
DECLARE
	v_entity_id			integer;
	v_org_id			integer;
	v_msg				varchar(120);
BEGIN

	SELECT entity_id, org_id INTO v_entity_id, v_org_id
	FROM entitys
	WHERE (lower(trim(primary_email)) = lower(trim($1)));

	IF(NEW.entity_id is not null) THEN
		v_msg := 'Email not found';
	ELSE
		INSERT INTO sys_reset (entity_id, org_id, request_email, login_ip)
		VALUES (v_entity_id, v_org_id, $1, $3);

		v_msg := 'The password is being reset';
	END IF;

	return v_msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upd_approvals() RETURNS trigger AS $$
DECLARE
	reca			RECORD;
	wfid			integer;
	v_org_id			integer;
	v_notice		boolean;
	v_advice		boolean;
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

