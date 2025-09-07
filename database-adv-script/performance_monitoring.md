###  Monitor and Refine Database Performance

`EXPLAIN` is a blueprint for the query, it shows you what the database plans to do.

`SHOW PROFILE`, on the other hand, is like a stopwatch with a detailed log. It shows you exactly where the query spent its time during its actual execution, from fetching data to sorting to writing to disk. This gives a much more granular view of performance.

To use `SHOW PROFILE` in MySQL, you follow a simple three-step process:

1. **Enable Profiling:** You need to turn on the profiling feature for your current session.

`SET profiling = 1;`

2. **Run Your Queries:** Execute the queries you want to analyze. The database will silently record all the details.

3. **Show the Profile:** You can view the profiles for your recent queries. The SHOW PROFILES command gives you a list of queries with unique IDs.

`SHOW PROFILES;` - To see the full details for a specific query, you use SHOW PROFILE FOR QUERY.

`SHOW PROFILE FOR QUERY [query_id];`

### Results

The query Run is:
```sql
SELECT
  b.booking_id,
  b.property_id,
  b.user_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status,
  u.first_name,
  u.last_name,
  u.email,
  p.name         AS property_name,
  p.location     AS property_location,
  p.pricepernight,
  pay.payment_id,
  pay.amount,
  pay.payment_date,
  pay.payment_method
FROM bookings AS b
JOIN users AS u
  ON u.user_id = b.user_id
JOIN properties AS p
  ON p.property_id = b.property_id
LEFT JOIN payments AS pay
  ON pay.booking_id = b.booking_id
WHERE b.created_at = "2025-12-01"
ORDER BY b.created_at DESC, pay.payment_date DESC;
```
and the result is:
```sql
'starting', '0.000219'
'Executing hook on transaction ', '0.000012'
'starting', '0.000014'
'checking permissions', '0.000006'
'checking permissions', '0.000004'
'checking permissions', '0.000004'
'checking permissions', '0.000005'
'Opening tables', '0.013283'
'init', '0.000017'
'System lock', '0.000019'
'optimizing', '0.000069'
'statistics', '0.000084'
'preparing', '0.000030'
'Creating tmp table', '0.000122'
'executing', '0.000140'
'end', '0.000008'
'query end', '0.000005'
'waiting for handler commit', '0.000028'
'closing tables', '0.000052'
'freeing items', '0.005603'
'cleaning up', '0.000083'
```
From this, to find the bottleneck, you need to look for the stage with the highest duration. The duration is a measure of how long the database spent on that specific task.

Looking at the results, the stage with the highest duration is 'Opening tables' at **0.013283** seconds. This means the database spent most of its time just opening the files for the tables involved in the query. This is a common bottleneck, especially in queries that join many tables (bookings, users, properties, and payments)

To drastically improve the performance of this query, we should make sure that the columns used for your JOIN and WHERE clauses are properly indexed. This will allow the database to use a fast index lookup instead of having to scan and open multiple tables.

From your query, these are the columns that need indexes:

- b.user_id (for the join with the users table)

- b.property_id (for the join with the properties table)

- b.booking_id (for the join with the payments table)

- b.created_at (for the WHERE and ORDER BY clauses)

After creating the indexs that didn't exist, I re-run the query again and here are the results.
```sql
'starting', '0.000201'
'Executing hook on transaction ', '0.000009'
'starting', '0.000011'
'checking permissions', '0.000007'
'checking permissions', '0.000004'
'checking permissions', '0.000003'
'checking permissions', '0.000005'
'Opening tables', '0.002399'
'init', '0.000018'
'System lock', '0.000018'
'optimizing', '0.000037'
'statistics', '0.000101'
'preparing', '0.000089'
'Creating tmp table', '0.000108'
'executing', '0.000191'
'end', '0.000008'
'query end', '0.000005'
'waiting for handler commit', '0.000023'
'closing tables', '0.000021'
'freeing items', '0.000844'
'cleaning up', '0.000039'
```
A comparison:

|Stage	        |Before (Duration)	|After (Duration)	|Improvement |
|---------------|-------------------|-------------------|------------|
|Opening tables	|0.013283 sec	    |0.002399 sec	    |~82%        |

The most significant change is in the **Opening tables stage**. Its duration dropped from **0.013283** seconds to just **0.002399** seconds. This is a massive improvement, demonstrating that your new indexes allowed the database to perform quick lookups for the joined rows instead of having to spend time scanning and opening large table files.
