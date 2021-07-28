---- Shifts, Time and attendance management
CREATE TABLE shifts (
	shift_id				serial primary key,
	project_id				integer references projects,
	org_id					integer references orgs,
	shift_name				varchar(50),
	shift_hours				real not null default 9,
	break_hours				real not null default 1,
	
	include_holiday 		boolean default false not null,
	paid_lunch_hour			boolean default true not null,

	include_mon				boolean default true not null,
	include_tue				boolean default true not null,
	include_wed				boolean default true not null,
	include_thu				boolean default true not null,
	include_fri				boolean default true not null,
	include_sat				boolean default false not null,
	include_sun				boolean default false not null,

	time_in					time not null,
	time_out				time not null,
	weekend_in				time not null,
	weekend_out				time not null,
	
	details					text
);
CREATE INDEX shifts_project_id ON shifts (project_id);
CREATE INDEX shifts_org_id ON shifts (org_id);

CREATE TABLE shift_schedule (
	shift_schedule_id		serial primary key,
	shift_id				integer references shifts,
	entity_id				integer references entitys,
	org_id					integer references orgs,

	is_active				boolean default true not null,

	details					text,
	UNIQUE(shift_id, entity_id)
);
CREATE INDEX shift_schedule_shift_id ON shift_schedule (shift_id);
CREATE INDEX shift_schedule_entity_id ON shift_schedule (entity_id);
CREATE INDEX shift_schedule_org_id ON shift_schedule (org_id);

CREATE TABLE attendance (
	attendance_id			serial primary key,
	entity_id				integer references entitys,
	shift_id				integer references shifts,
	org_id					integer references orgs,
	attendance_date			date not null,
	time_in					time not null,
	time_out				time not null,
	lunch_in				time,
	lunch_out				time,
	late					real default 0 not null,
	overtime				real default 0 not null,
	narrative				varchar(120),
	details					text
);
CREATE INDEX attendance_entity_id ON attendance (entity_id);
CREATE INDEX attendance_shift_id ON attendance (shift_id);
CREATE INDEX attendance_org_id ON attendance (org_id);
CREATE INDEX attendance_attendance_date ON attendance (attendance_date);

CREATE TABLE access_logs (
	access_log_id			serial primary key,
	entity_id				integer references entitys,
	attendance_id			integer references attendance,
	org_id					integer references orgs,
	log_time				timestamp default current_timestamp not null,
	log_time_out			timestamp,
	log_ip					varchar(32),
	log_location			point,
	log_name				varchar(50),
	log_machine				varchar(50),
	log_access				varchar(50),
	log_id					varchar(50),
	log_area				varchar(50),
	log_in_out				varchar(50),
	log_type				integer,

	is_picked				boolean default false,
	narrative				varchar(240)
);
CREATE INDEX access_logs_entity_id ON access_logs (entity_id);
CREATE INDEX access_logs_attendance_id ON access_logs (attendance_id);
CREATE INDEX access_logs_org_id ON access_logs (org_id);

CREATE TABLE bio_imports1 (
	bio_imports1_id			serial primary key,
	org_id					integer references orgs,
	col1					varchar(50),
	col2					varchar(50),
	col3					varchar(50),
	col4					varchar(50),
	col5					varchar(50),
	col6					varchar(50),
	col7					varchar(50),
	col8					varchar(50),
	col9					varchar(50),
	col10					varchar(50),
	col11					varchar(50),
	is_picked				boolean default false
);
CREATE INDEX bio_imports1_org_id ON bio_imports1 (org_id);

CREATE TABLE bio_imports2 (
	bio_imports2_id			serial primary key,
	org_id					integer references orgs,
	col1					varchar(50),
	col2					varchar(50),
	col3					varchar(50),
	col4					varchar(50),
	col5					varchar(50),
	col6					varchar(50),
	col7					varchar(50),
	is_picked				boolean default false
);
CREATE INDEX bio_imports2_org_id ON bio_imports2 (org_id);


CREATE VIEW vw_shifts AS
	SELECT projects.project_id, projects.project_name, 
		shifts.org_id, shifts.shift_id, shifts.shift_name, shifts.shift_hours, shifts.break_hours, shifts.include_holiday, 
		shifts.include_mon, shifts.include_tue, shifts.include_wed, shifts.include_thu, shifts.include_fri, 
		shifts.include_sat, shifts.include_sun, shifts.time_in, shifts.time_out, shifts.weekend_in, shifts.weekend_out,
		shifts.details
		
	FROM shifts LEFT JOIN projects ON shifts.project_id = projects.project_id;

CREATE VIEW vw_shift_schedule AS
	SELECT vw_shifts.project_id, vw_shifts.project_name, 
		vw_shifts.shift_id, vw_shifts.shift_name, vw_shifts.shift_hours, vw_shifts.include_holiday, 
		vw_shifts.include_mon, vw_shifts.include_tue, vw_shifts.include_wed, vw_shifts.include_thu, vw_shifts.include_fri, 
		vw_shifts.include_sat, vw_shifts.include_sun, vw_shifts.time_in, vw_shifts.time_out, 

		entitys.entity_id, entitys.entity_name, 
		
		shift_schedule.org_id, shift_schedule.shift_schedule_id, shift_schedule.is_active, shift_schedule.details
	
	FROM shift_schedule INNER JOIN vw_shifts ON shift_schedule.shift_id = vw_shifts.shift_id
		INNER JOIN entitys ON shift_schedule.entity_id = entitys.entity_id;

CREATE VIEW vw_attendance_shifts AS
	SELECT entitys.entity_id, entitys.entity_name, 
		shifts.shift_id, shifts.shift_name, shifts.shift_hours,
		shifts.time_in as shift_time_in, shifts.time_out as shift_time_out, 
		shifts.weekend_in as shift_weekend_in, shifts.weekend_out as shift_weekend_out,
		
		attendance.org_id, attendance.attendance_id, attendance.attendance_date, attendance.time_in, 
		attendance.time_out, attendance.late, attendance.overtime, attendance.narrative, attendance.details,
		
		(EXTRACT(epoch FROM (attendance.time_out - attendance.time_in)) / 3600) as worked_hours,
		to_char(attendance.attendance_date, 'YYYYMM') as a_month,
		EXTRACT(WEEK FROM attendance.attendance_date) as a_week,
		EXTRACT(DOW FROM attendance.attendance_date) as a_dow
	FROM attendance INNER JOIN entitys ON attendance.entity_id = entitys.entity_id
		LEFT JOIN shifts ON attendance.shift_id = shifts.shift_id;

CREATE VIEW vw_attendance_schedule AS
	SELECT ss.org_id, ss.period_id, ss.period_day, ss.employee_id, ss.entity_id, ss.employee_name, 
		ss.average_daily_rate, ss.normal_work_hours, ss.overtime_rate, ss.special_time_rate, ss.per_day_earning,
		(CASE WHEN ss.normal_work_hours > 0 THEN ss.average_daily_rate * ss.overtime_rate / ss.normal_work_hours ELSE 0 END) as overtime_hr,
		(CASE WHEN ss.normal_work_hours > 0 THEN ss.average_daily_rate * ss.special_time_rate / ss.normal_work_hours ELSE 0 END) as special_time_hr,
		holidays.holiday_id, holidays.holiday_name,
		sa.shift_id, sa.shift_name, sa.shift_hours,
		sa.shift_time_in, sa.shift_time_out, 
		sa.shift_weekend_in, sa.shift_weekend_out,
		
		sa.attendance_id, sa.attendance_date, sa.time_in, sa.worked_hours, sa.time_out, sa.late, sa.overtime, sa.narrative, 
		sa.a_month, sa.a_week, sa.a_dow
			
	FROM (SELECT employees.org_id, employees.entity_id, employees.employee_id,
		(employees.Surname || ' ' || employees.First_name || ' ' || COALESCE(employees.Middle_name, '')) as employee_name,
		employees.average_daily_rate, employees.normal_work_hours, employees.overtime_rate, employees.special_time_rate, employees.per_day_earning,
		periods.period_id, generate_series(periods.start_date, periods.end_date, '1 day')::date as period_day
		FROM periods, employees WHERE periods.org_id = employees.org_id) as ss
		LEFT JOIN holidays ON (ss.period_day = holidays.holiday_date) AND (ss.org_id = holidays.org_id)
		LEFT JOIN vw_attendance_shifts as sa ON (ss.entity_id = sa.entity_id) AND (ss.period_day = sa.attendance_date);
		
CREATE VIEW vw_attendance_summary AS
	SELECT ats.org_id, ats.period_id, ats.employee_id, ats.entity_id, ats.employee_name, 
		ats.average_daily_rate, ats.normal_work_hours, ats.overtime_rate, ats.special_time_rate, ats.per_day_earning,
		ats.overtime_hr, ats.special_time_hr,
		ats.holiday_id, ats.holiday_name,
		ats.shift_id, ats.shift_name, ats.shift_hours, ats.a_month,
		(CASE WHEN ats.normal_work_hours > 0 THEN ats.average_daily_rate / ats.normal_work_hours ELSE 0 END) as normal_time_hr,
		count(ats.attendance_id) as days_worked,
		sum(ats.worked_hours) as t_worked_hours, sum(ats.late) as t_late, sum(ats.overtime) as t_overtime
	FROM vw_attendance_schedule as ats
	GROUP BY  ats.org_id, ats.period_id, ats.employee_id, ats.entity_id, ats.employee_name,
		ats.average_daily_rate, ats.normal_work_hours, ats.overtime_rate, ats.special_time_rate, ats.per_day_earning,
		ats.overtime_hr, ats.special_time_hr,
		ats.holiday_id, ats.holiday_name,
		ats.shift_id, ats.shift_name, ats.shift_hours, ats.a_month;

CREATE VIEW vw_attendance AS
	SELECT entitys.entity_id, entitys.entity_name, attendance.attendance_id, attendance.attendance_date, 
		attendance.org_id, attendance.time_in, attendance.time_out, attendance.lunch_in, attendance.lunch_out,
		attendance.late, attendance.overtime, attendance.narrative, attendance.details,
		to_char(attendance.attendance_date, 'YYYYMM') as a_month,
		EXTRACT(WEEK FROM attendance.attendance_date) as a_week,
		EXTRACT(DOW FROM attendance.attendance_date) as a_dow
	FROM attendance INNER JOIN entitys ON attendance.entity_id = entitys.entity_id;
	
CREATE VIEW vw_week_attendance AS
	SELECT a.period_id, a.start_date, a.period_year, a.period_month, a.period_code, 
		a.week_start, a.p_week, a.org_id, a.entity_id, a.employee_id, a.employee_name, a.active,
		
		pp1.time_in as mon_time_in, pp1.time_out as mon_time_out, (pp1.time_out - pp1.time_in) as mon_time_diff,
		pp2.time_in as tue_time_in, pp2.time_out as tue_time_out, (pp2.time_out - pp2.time_in) as tue_time_diff,
		pp3.time_in as wed_time_in, pp3.time_out as wed_time_out, (pp3.time_out - pp3.time_in) as wed_time_diff,
		pp4.time_in as thu_time_in, pp4.time_out as thu_time_out, (pp4.time_out - pp4.time_in) as thu_time_diff,
		pp5.time_in as fri_time_in, pp5.time_out as fri_time_out, (pp5.time_out - pp5.time_in) as fri_time_diff,
		
		(CASE WHEN (pp1.time_in is null) or (pp1.time_out is null) THEN 0 ELSE 1 END) mon_count,
		(CASE WHEN (pp2.time_in is null) or (pp2.time_out is null) THEN 0 ELSE 1 END) tue_count,
		(CASE WHEN (pp3.time_in is null) or (pp3.time_out is null) THEN 0 ELSE 1 END) wed_count,
		(CASE WHEN (pp4.time_in is null) or (pp4.time_out is null) THEN 0 ELSE 1 END) thu_count,
		(CASE WHEN (pp5.time_in is null) or (pp5.time_out is null) THEN 0 ELSE 1 END) fri_count
	FROM vw_employee_periods a
		LEFT JOIN (SELECT p1.time_in, p1.time_out, p1.entity_id, p1.a_month, p1.a_week
			FROM vw_attendance p1 WHERE p1.a_dow = 1) pp1 ON
			(a.entity_id = pp1.entity_id) AND (a.period_code = pp1.a_month) AND (a.p_week = pp1.a_week)
		LEFT JOIN (SELECT p2.time_in, p2.time_out, p2.entity_id, p2.a_month, p2.a_week
			FROM vw_attendance p2 WHERE p2.a_dow = 2) pp2 ON
			(a.entity_id = pp2.entity_id) AND (a.period_code = pp2.a_month) AND (a.p_week = pp2.a_week)
		LEFT JOIN (SELECT p3.time_in, p3.time_out, p3.entity_id, p3.a_month, p3.a_week
			FROM vw_attendance p3 WHERE p3.a_dow = 3) pp3 ON
			(a.entity_id = pp3.entity_id) AND (a.period_code = pp3.a_month) AND (a.p_week = pp3.a_week)
		LEFT JOIN (SELECT p4.time_in, p4.time_out, p4.entity_id, p4.a_month, p4.a_week
			FROM vw_attendance p4 WHERE p4.a_dow = 4) pp4 ON
			(a.entity_id = pp4.entity_id) AND (a.period_code = pp4.a_month) AND (a.p_week = pp4.a_week)
		LEFT JOIN (SELECT p5.time_in, p5.time_out, p5.entity_id, p5.a_month, p5.a_week
			FROM vw_attendance p5 WHERE p5.a_dow = 5) pp5 ON
			(a.entity_id = pp5.entity_id) AND (a.period_code = pp5.a_month) AND (a.p_week = pp5.a_week);
					
CREATE OR REPLACE FUNCTION add_shift_staff(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	msg		 				varchar(120);
	v_entity_id				integer;
	v_org_id				integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM shift_schedule WHERE (entity_id = CAST($1 as int)) AND (shift_id = CAST($3 as int));
	
	IF(v_entity_id is null)THEN
		SELECT org_id INTO v_org_id
		FROM shifts WHERE (shift_id = CAST($3 as int));
		
		INSERT INTO  shift_schedule (shift_id, entity_id, org_id)
		VALUES (CAST($3 as int), CAST($1 as int), v_org_id);

		msg := 'Added to shift';
	ELSE
		msg := 'Already added to shift';
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ins_attendance() RETURNS trigger AS $$
DECLARE
	rec					RECORD;
	v_dow				integer;
	v_holiday_name		varchar(50);
BEGIN

	IF (TG_OP = 'INSERT') THEN
		SELECT max(shift_id) INTO NEW.shift_id
		FROM shift_schedule	
		WHERE (is_active = true);
		
		IF(NEW.shift_id is not null)THEN
			SELECT include_holiday, include_mon, include_tue, include_wed, include_thu, 
				include_fri, include_sat, include_sun, time_in, time_out, weekend_in, weekend_out
			INTO rec
			FROM shifts WHERE (shift_id = NEW.shift_id);
			
			SELECT holiday_name INTO v_holiday_name
			FROM holidays WHERE (org_id = NEW.org_id) AND (holiday_date = NEW.attendance_date);
			
			--- lateness and overtime calculation
			v_dow := EXTRACT(DOW FROM NEW.attendance_date);
			IF(v_dow = 6)THEN --- satuday
				IF(rec.include_sat = true)THEN
					NEW.late := EXTRACT(epoch FROM (NEW.time_in - rec.weekend_in)) / 3600;
					NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - rec.weekend_out)) / 3600;
				ELSE
					NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - NEW.time_in)) / 3600;
				END IF;
			ELSIF(v_dow = 0)THEN --- Sunday
				IF(rec.include_sun = true)THEN
					NEW.late := EXTRACT(epoch FROM (NEW.time_in - rec.weekend_in)) / 3600;
					NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - rec.weekend_out)) / 3600;
				ELSE
					NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - NEW.time_in)) / 3600;
				END IF;
			ELSE --- normal days
				NEW.late := EXTRACT(epoch FROM (NEW.time_in - rec.time_in)) / 3600;
				NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - rec.time_out)) / 3600;
			END IF;
			IF((v_holiday_name is not null) AND (rec.include_holiday = false))THEN
				NEW.late := 0;
				NEW.overtime := EXTRACT(epoch FROM (NEW.time_out - NEW.time_in)) / 3600;
				NEW.narrative := v_holiday_name;
			END IF;
			IF(NEW.late < 0)THEN NEW.late := 0; END IF;
			IF(NEW.overtime < 0)THEN NEW.overtime := 0; END IF;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ins_attendance BEFORE INSERT OR UPDATE ON attendance
	FOR EACH ROW EXECUTE PROCEDURE ins_attendance();

CREATE OR REPLACE FUNCTION get_attendance_pay(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	reca 					RECORD;
	v_period_id				integer;
	v_org_id				integer;
	v_entity_id				integer;
	v_start_date			date;
	v_end_date				date;
	v_project_cost			float;
	msg 					varchar(120);
BEGIN

	SELECT period_id, org_id, start_date, end_date INTO v_period_id, v_org_id, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = $1::int);
	
	v_entity_id := $2::int;
	
	--- Computer the work hours
	FOR reca IN SELECT b.employee_month_id, 
		sum(a.t_worked_hours - a.t_overtime) as worked_hours,
		(sum(a.t_worked_hours - a.t_overtime) * a.normal_time_hr) as month_pay
		FROM vw_attendance_summary a INNER JOIN employee_month b ON (a.entity_id = b.entity_id) AND (a.period_id = b.period_id)
		WHERE (a.per_day_earning = true) AND (a.holiday_id is null) AND (a.period_id = v_period_id)
		GROUP BY b.employee_month_id, a.normal_time_hr
	LOOP
		IF(reca.month_pay is not null)THEN
			UPDATE employee_month SET basic_pay = reca.month_pay, 
				hour_pay = reca.month_pay, worked_hours = reca.worked_hours
			WHERE employee_month_id = reca.employee_month_id;
		END IF;
	END LOOP;
	
	DELETE FROM employee_overtime WHERE (auto_computed = true)
	AND (employee_month_id IN (SELECT employee_month_id FROM employee_month WHERE period_id = v_period_id));
	
	--- Insert normal overtime
	INSERT INTO employee_overtime (employee_month_id, org_id, overtime_date, overtime, overtime_rate, auto_computed, approve_status, entity_id)
	SELECT b.employee_month_id, a.org_id, v_end_date, a.t_overtime, a.overtime_hr, true, 'Completed', v_entity_id
	FROM vw_attendance_summary a INNER JOIN employee_month b ON (a.entity_id = b.entity_id) AND (a.period_id = b.period_id)
	WHERE (a.holiday_id is null) AND (a.period_id = v_period_id) AND (a.t_overtime is not null);

	--- Insert special time overtime
	INSERT INTO employee_overtime (employee_month_id, org_id, overtime_date, overtime, overtime_rate, narrative, auto_computed, approve_status, entity_id)
	SELECT b.employee_month_id, a.org_id, v_end_date, a.t_overtime, a.special_time_hr, a.holiday_name, true, 'Completed', v_entity_id
	FROM vw_attendance_summary a INNER JOIN employee_month b ON (a.entity_id = b.entity_id) AND (a.period_id = b.period_id)
	WHERE (a.holiday_id is not null) AND (a.period_id = v_period_id) AND (a.t_overtime is not null);
	
	msg := 'Done';

	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_bio_imports1(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_org_id				integer;
	msg		 				varchar(120);
BEGIN

	SELECT org_id INTO v_org_id FROM entitys
	WHERE entity_id = $2::integer;

	INSERT INTO access_logs (access_log_id, entity_id, org_id, log_time, log_name, log_machine, log_access, log_id, log_area, log_in_out)
	SELECT bio_imports1_id, e.entity_id, v_org_id, to_timestamp(col1, 'MM/DD/YYYY hh:MI:SS pm'), col2, col4, col5, col6, col7, col10
	FROM bio_imports1 LEFT JOIN access_logs ON to_timestamp(bio_imports1.col1, 'MM/DD/YYYY hh:MI:SS pm') = access_logs.log_time
		LEFT JOIN employees as e ON trim(bio_imports1.col6) = trim(e.bio_metric_number)
	WHERE access_logs.access_log_id is null
	ORDER BY to_timestamp(col1, 'MM/DD/YYYY hh:MI:SS pm');

	DELETE FROM bio_imports1;

	INSERT INTO attendance (entity_id, org_id, attendance_date, time_in, time_out)
	SELECT entity_id, org_id, log_time::date, min(log_time::time), max(log_time::time)
	FROM access_logs
	WHERE (is_picked = false) AND (entity_id is not null)
	GROUP BY entity_id, org_id, log_time::date
	ORDER BY entity_id, log_time::date;

	UPDATE access_logs SET is_picked = true
	WHERE (is_picked = false) AND (entity_id is not null);

	msg := 'Uploaded the file';
	
	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_bio_imports2(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	v_org_id				integer;
	msg		 				varchar(120);
BEGIN

	SELECT org_id INTO v_org_id FROM entitys
	WHERE entity_id = $2::integer;
	
	DELETE FROM bio_imports2 WHERE (col2 is null) OR (col3 is null) OR (col4 is null);
	
	INSERT INTO attendance (entity_id, org_id, attendance_date, time_in, time_out)
	SELECT employees.entity_id, employees.org_id, to_date(bio_imports2.col2, 'YYYY/MM/DD'), 
		to_timestamp(bio_imports2.col3, 'HH24:MI')::time, to_timestamp(bio_imports2.col4, 'HH24:MI')::time
	FROM bio_imports2 INNER JOIN employees ON upper(trim(bio_imports2.col1)) = upper(trim(employees.employee_id))
	WHERE employees.org_id = v_org_id;
	
	DELETE FROM bio_imports2;

	msg := 'Uploaded the file';
	
	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_bio_imports3(varchar(12), varchar(12), varchar(12)) RETURNS varchar(120) AS $$
DECLARE
	myrec					RECORD;
	v_org_id				integer;
	msg		 				varchar(120);
BEGIN

	SELECT org_id INTO v_org_id FROM entitys
	WHERE entity_id = $2::integer;

	FOR myrec IN SELECT add_access_logs(employees.entity_id, 12, bio_imports2.col6, bio_imports2.col1, 
		to_timestamp(bio_imports2.col3 || ' ' || bio_imports2.col4, 'DD/MM/YYYY HH24:MI:SS')::timestamp) as logged
		FROM bio_imports2 INNER JOIN employees ON (bio_imports2.col2 = employees.bio_metric_number)
			AND (bio_imports2.org_id = employees.org_id)
		WHERE (bio_imports2.org_id = v_org_id)
	LOOP
	END LOOP;
	
	DELETE FROM bio_imports2;

	msg := 'Uploaded the file';
	
	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sum_attendance_hours(integer, integer) RETURNS interval AS $$
	SELECT sum(COALESCE(mon_time_diff, '00:00:00'::interval) + COALESCE(tue_time_diff, '00:00:00'::interval) +
		COALESCE(wed_time_diff, '00:00:00'::interval) + COALESCE(thu_time_diff, '00:00:00'::interval) +
		COALESCE(fri_time_diff, '00:00:00'::interval) -
		((mon_count + tue_count + wed_count + thu_count + fri_count)::varchar || 'hours')::interval)
	FROM vw_week_attendance
	WHERE (vw_week_attendance.entity_id = $1) AND (vw_week_attendance.period_id = $2)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION add_access_logs(int, int, varchar(32), varchar(32)) RETURNS varchar(16) AS $$
DECLARE
	v_org_id				integer;
	v_access_log_id			integer;
	v_in					integer;
	v_attendance_id			integer;
	v_log_date				date;
	v_log_time				time;
	msg		 				varchar(120);
BEGIN

	SELECT org_id INTO v_org_id
	FROM entitys WHERE entity_id = $1;
	
	SELECT access_log_id, log_time::date, log_time::time INTO v_access_log_id, v_log_date, v_log_time
	FROM access_logs
	WHERE (entity_id = $1) AND (log_type = $2) AND (log_time_out is null);
	
	v_in := 0;
	IF($3 IN ('IN', 'LUNCHIN', 'BREAKIN'))THEN v_in := 1; END IF;

	IF((v_access_log_id is null) AND (v_in = 1))THEN
		INSERT INTO access_logs (entity_id, org_id, log_type, log_in_out, log_ip)
		VALUES ($1, v_org_id, $2, $3, $4);

		msg := '0';
	END IF;
	IF((v_access_log_id is not null) AND (v_in = 0))THEN
		UPDATE access_logs SET log_time_out = current_timestamp
		WHERE access_log_id = v_access_log_id;
		msg := v_access_log_id::varchar(16);
		
		IF($3 = 'OUT')THEN
			SELECT attendance_id INTO v_attendance_id
			FROM attendance
			WHERE (entity_id = $1) AND (attendance_date = v_log_date);
			
			IF(v_attendance_id is null)THEN
				INSERT INTO attendance (entity_id, org_id, attendance_date, time_in, time_out)
				VALUES ($1, v_org_id, v_log_date, v_log_time, current_time);
			ELSE
				UPDATE attendance SET time_out = current_time WHERE attendance_id = v_attendance_id;
			END IF;
		END IF;
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_access_logs(int, int, varchar(32), varchar(32), timestamp) RETURNS varchar(16) AS $$
DECLARE
	v_org_id				integer;
	v_access_log_id			integer;
	v_log_id				varchar(50);
	v_attendance_id			integer;
	v_log_date				date;
	v_log_time				time;
	msg		 				varchar(120);
BEGIN

	SELECT org_id INTO v_org_id
	FROM entitys WHERE entity_id = $1;
	
	SELECT access_log_id, log_time::date, log_time::time INTO v_access_log_id, v_log_date, v_log_time
	FROM access_logs
	WHERE (entity_id = $1) AND (log_type = $2) AND (log_time_out is null);
	
	SELECT log_id INTO v_log_id
	FROM access_logs WHERE (log_id = $4);
	

	IF((v_access_log_id is null) AND ($3 = 'IN') AND (v_log_id is null))THEN
		INSERT INTO access_logs (entity_id, org_id, log_type, log_in_out, log_id, log_time)
		VALUES ($1, v_org_id, $2, $3, $4, $5);

		msg := '0';
	END IF;
	IF((v_access_log_id is not null) AND ($3 = 'OUT'))THEN
		UPDATE access_logs SET log_time_out = $5
		WHERE access_log_id = v_access_log_id;
		msg := v_access_log_id::varchar(16);
		
		IF($3 = 'OUT')THEN
			SELECT attendance_id INTO v_attendance_id
			FROM attendance
			WHERE (entity_id = $1) AND (attendance_date = v_log_date);
			
			IF(v_attendance_id is null)THEN
				INSERT INTO attendance (entity_id, org_id, attendance_date, time_in, time_out)
				VALUES ($1, v_org_id, v_log_date, v_log_time, $5::time);
			ELSE
				UPDATE attendance SET time_out = $5::time WHERE attendance_id = v_attendance_id;
			END IF;
		END IF;
	END IF;
	
	return msg;
END;
$$ LANGUAGE plpgsql;
