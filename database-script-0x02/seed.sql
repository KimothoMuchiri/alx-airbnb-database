-- USERS
INSERT INTO users (user_id, first_name, last_name, email, password_hash, role)
VALUES
(UUID(), 'Alice', 'Johnson', 'alice@example.com', 'hash1', 'guest'),
(UUID(), 'Bob', 'Smith', 'bob@example.com', 'hash2', 'host'),
(UUID(), 'Charlie', 'Brown', 'charlie@example.com', 'hash3', 'guest'),
(UUID(), 'Dana', 'White', 'dana@example.com', 'hash4', 'host'),
(UUID(), 'Eve', 'Black', 'eve@example.com', 'hash5', 'admin');

-- PROPERTIES
-- Assume Bob and Dana are hosts
INSERT INTO properties (property_id, host_id, name, description, location, pricepernight)
SELECT UUID(), user_id, 'Seaside Cottage', 'Cozy cottage near the ocean', 'Mombasa, Kenya', 120.00
FROM users WHERE email='bob@example.com';

INSERT INTO properties (property_id, host_id, name, description, location, pricepernight)
SELECT UUID(), user_id, 'Mountain Cabin', 'Rustic cabin with stunning views', 'Naivasha, Kenya', 80.00
FROM users WHERE email='dana@example.com';

-- BOOKINGS
-- Alice books Bob’s property
INSERT INTO bookings (booking_id, property_id, user_id, start_date, end_date, total_price, status)
SELECT UUID(), p.property_id, u.user_id, '2025-12-10', '2025-12-15', 600.00, 'confirmed'
FROM properties p, users u
WHERE p.name='Seaside Cottage' AND u.email='alice@example.com';

-- Charlie books Dana’s property
INSERT INTO bookings (booking_id, property_id, user_id, start_date, end_date, total_price, status)
SELECT UUID(), p.property_id, u.user_id, '2025-11-01', '2025-11-03', 160.00, 'pending'
FROM properties p, users u
WHERE p.name='Mountain Cabin' AND u.email='charlie@example.com';

-- PAYMENTS
-- Alice pays for her confirmed booking
INSERT INTO payments (payment_id, booking_id, amount, payment_method)
SELECT UUID(), b.booking_id, b.total_price, 'stripe'
FROM bookings b
JOIN users u ON b.user_id = u.user_id
WHERE u.email='alice@example.com';

-- REVIEWS
-- Alice leaves a review for Seaside Cottage
INSERT INTO reviews (review_id, property_id, user_id, rating, comment)
SELECT UUID(), p.property_id, u.user_id, 5, 'Fantastic stay, very cozy!'
FROM properties p, users u
WHERE p.name='Seaside Cottage' AND u.email='alice@example.com';

-- Charlie leaves a review for Mountain Cabin
INSERT INTO reviews (review_id, property_id, user_id, rating, comment)
SELECT UUID(), p.property_id, u.user_id, 4, 'Great views, rustic but comfortable.'
FROM properties p, users u
WHERE p.name='Mountain Cabin' AND u.email='charlie@example.com';

-- MESSAGES
-- Alice messages Bob (her host)
INSERT INTO messages (message_id, sender_id, recipient_id, message_body)
SELECT UUID(), u1.user_id, u2.user_id, 'Hi Bob, just checking about check-in time.'
FROM users u1, users u2
WHERE u1.email='alice@example.com' AND u2.email='bob@example.com';

-- Bob replies
INSERT INTO messages (message_id, sender_id, recipient_id, message_body)
SELECT UUID(), u1.user_id, u2.user_id, 'Check-in is at 2pm, see you soon!'
FROM users u1, users u2
WHERE u1.email='bob@example.com' AND u2.email='alice@example.com';
