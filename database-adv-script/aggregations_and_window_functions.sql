-- Non-correlated subquery → properties with avg rating > 4.0
-- inner query computes AVG(r.rating) per property.
-- outer query keeps only those properties whose property_id is in that set.
-- this is non-correlated because the inner query doesn’t depend on each row of the outer query.

SELECT 
p.property_id,
p.name,
p.location,
p.pricepernight
FROM properties AS p
WHERE p.property_id IN (
SELECT r.property_id
FROM reviews AS r
GROUP BY r.property_id
HAVING AVG(r.rating) > 4.0
);

-- Correlated subquery → users with > 3 bookings
-- for each user row in the outer query, the subquery counts bookings with 
-- b.user_id = u.user_id.
-- that count is checked against > 3.
-- this is correlated because the inner query depends on the current u.user_id.
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    u.email
FROM users AS u
WHERE (
    SELECT COUNT(*)
    FROM bookings AS b
    WHERE b.user_id = u.user_id
) > 3;
