--- INNER JOIN — all bookings with the user who made them
SELECT b.booking_id,
b.property_id,
b.start_date,
b.end_date,
b.total_price,
b.status,
u.status,
u.user_id,
u.first_name,
u.last_name,
u.email,
    FROM bookings as b
    INNER JOIN users AS u
    ON u.user_id = b.user_id;


--- LEFT JOIN — all properties and their reviews
SELECT 
p.property_id,
p.name AS property_name,
p.location,
r.review_id,
r.user_id AS reviewer_user_id,
r.rating,
r.comment,
r.created_at as review_created_at
FROM properties AS p
LEFT JOIN reviews as r
ON r.property_id = p.property_id
ORDER BY p.property_id, r.created_at;

--- FULL OUTER JOIN --all users and all bookings
--- Users with their bookings (including users with no bookings)
SELECT
  u.user_id,
  u.first_name,
  u.last_name,
  u.email,
  b.booking_id,
  b.property_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status
FROM users AS u
LEFT JOIN bookings AS b
  ON b.user_id = u.user_id

UNION ALL

-- Bookings with no matching user (right-only). 

SELECT
  u.user_id,
  u.first_name,
  u.last_name,
  u.email,
  b.booking_id,
  b.property_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status
FROM users AS u
RIGHT JOIN bookings AS b
  ON b.user_id = u.user_id
WHERE u.user_id IS NULL;
