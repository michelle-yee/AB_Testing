WITH leads AS
(
SELECT ld.*, sfl.email, sfo.review_call_booked_boolean__c
FROM revenue.lead_data ld
LEFT JOIN salesforce.sf_lead sfl
ON ld.id = sfl.id
LEFT JOIN salesforce.sf_opportunity sfo
ON ld.opp_id = sfo.id
WHERE ld.actual_date_created__c >= '2019-11-05' --
),

sample AS
(
SELECT u.user_id , u.id, u._email AS email,
u.hxreikcisvado7i_u6hseq AS variation_id --
FROM main_production.users u
WHERE u.hxreikcisvado7i_u6hseq IS NOT NULL --
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
SELECT pv.user_id, DATE_TRUNC('d',pv.time) AS view_day, pv.device_type
FROM main_production.pageviews pv
WHERE pv.time >= '2019-11-05' --
AND pv.path LIKE '/go/smart-bookkeeping-app/'
AND pv.user_id IN (SELECT user_id FROM sample)
),

aggregation AS
(
SELECT DISTINCT views.user_id, people.person_email, device_type, leads.id, variation_id, won_mrr, leads.review_call_booked_boolean__c
FROM views
LEFT JOIN people
	ON views.user_id = people.user_id
LEFT JOIN leads
	ON client_id = leads.bench_id__c OR person_email ILIKE leads.email OR people.email ILIKE leads.email
WHERE person_email IS NULL
OR people.email IS NULL
OR (person_email NOT LIKE '%bench.co%' AND person_email NOT LIKE '%test%' AND people.email NOT LIKE '%bench.co%' AND people.email NOT LIKE '%test%')
)


SELECT
	variation_id,
	device_type,
	COUNT(DISTINCT user_id) as viewers,
	COUNT(DISTINCT id) as leads,
	SUM(CASE WHEN review_call_booked_boolean__c THEN 1 ELSE 0 END) as trials,
	SUM(CASE WHEN won_mrr IS NOT NULL THEN 1 ELSE 0 END) as clients
FROM aggregation
GROUP BY 1,2
ORDER BY 1 ASC; 
