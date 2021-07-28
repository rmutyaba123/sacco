SELECT *
FROM sms_queue
WHERE (send_results = 'SVC0901')
ORDER BY sms_queue_id


UPDATE sms SET folder_id = 0, sent = false
WHERE (sms_id IN 
(SELECT sms_id
FROM sms_queue
WHERE (send_results = 'SVC0901')
ORDER BY sms_queue_id));


DELETE FROM sms_queue
WHERE (send_results = 'SVC0901');



------------ checking sms count

SELECT orgs.sender_name, max(org_name)
FROM orgs LEFT JOIN 
(SELECT org_id FROM sms WHERE sms.sms_time > '2016-01-01'::date) aa
ON orgs.org_id = aa.org_id
WHERE aa.org_id is null
GROUP BY orgs.sender_name
ORDER BY orgs.sender_name

SELECT *
FROM orgs 
WHERE orgs.sender_name = '707007'


--- SMS usage
SELECT orgs.sender_name, max(org_name), sum(sms_count)
FROM orgs INNER JOIN 
(SELECT org_id, count(sms_id) as sms_count FROM sms WHERE sms.sms_time > '2017-01-01'::date GROUP BY org_id) aa
ON orgs.org_id = aa.org_id
GROUP BY orgs.sender_name
ORDER BY orgs.sender_name