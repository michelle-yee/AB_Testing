WITH leads AS
(
SELECT ld.*, sfl.email, sfo.review_call_booked_boolean__c
FROM revenue.lead_data ld
LEFT JOIN salesforce.sf_lead sfl
ON ld.id = sfl.id
LEFT JOIN salesforce.sf_opportunity sfo
ON ld.opp_id = sfo.id
WHERE ld.actual_date_created__c >= '2020-01-20' --
),
sample AS
(
SELECT u.user_id , u.id, u._email AS email,
u.xfipcuegtskkmkrzhxfrka AS variation_id --
FROM main_production.users u
WHERE u.xfipcuegtskkmkrzhxfrka IS NOT NULL --
),
people AS
(
SELECT
	sample.*,
	map.id AS person_id,
	map.email AS person_email,
	mac.id AS client_id
FROM sample
LEFT JOIN mainapp_production_v2.person map
	ON sample.id = map.id
LEFT JOIN mainapp_production_v2.client mac
	ON map.id = mac.principalpersonid
),
views AS
(
SELECT pv.user_id, DATE_TRUNC('d',CONVERT_TIMEZONE('PST8PDT',pv.time)) AS view_day, pv.device_type
FROM main_production.pageviews pv
WHERE view_day >= '2020-01-20' --
AND pv.path LIKE '/'
AND pv.user_id IN (SELECT user_id FROM sample)
),
aggregation AS
(
SELECT DISTINCT
	views.user_id,
	people.person_email,
	variation_id,
	FIRST_VALUE (device_type) OVER (PARTITION BY views.user_id ORDER BY views.view_day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as device,
	FIRST_VALUE(leads.id) OVER (PARTITION BY views.user_id) as first_lead_id,
	MAX(won_mrr) OVER (PARTITION BY views.user_id) as max_mrr,
	MAX(CASE WHEN leads.review_call_booked_boolean__c THEN 1 ELSE 0 END) OVER ( PARTITION BY views.user_id) as trial_indicator
FROM views
LEFT JOIN people
	ON views.user_id = people.user_id
LEFT JOIN leads
	ON (client_id = leads.bench_id__c OR person_email ILIKE leads.email OR people.email ILIKE leads.email)
	AND view_day <= actual_date_created__c
WHERE (person_email IS NULL
OR people.email IS NULL
OR person_email NOT LIKE '%bench.co%' AND person_email NOT LIKE '%test%' AND people.email NOT LIKE '%bench.co%' AND people.email NOT LIKE '%test%')
)


SELECT
	variation_id,
	device,
	COUNT(DISTINCT user_id) as viewers,
	COUNT(DISTINCT first_lead_id) as leads,
	SUM(trial_indicator) as trials,
	SUM(CASE WHEN max_mrr IS NOT NULL THEN 1 ELSE 0 END) as clients
FROM aggregation
GROUP BY 1, 2
ORDER BY 1,2;
	
