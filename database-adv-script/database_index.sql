-- database_index.sql
-- Target: MySQL 8.0 (InnoDB)
-- Schema: airbnb_demo
-- NOTE: Run each section after verifying the index name does not already exist.
-- For MySQL, use: SHOW INDEX FROM <table>; to check existing indexes.

USE airbnb_demo;

/*****************************************************************************************
users
*****************************************************************************************/

-- Role filter 
CREATE INDEX idx_users_role ON users(role);

-- Recent users lists, retention cohorts, etc.
CREATE INDEX idx_users_created_at ON users(created_at);

-- Name search/sort (supports WHERE last_name=?, ORDER BY last_name, first_name)
CREATE INDEX idx_users_last_first ON users(last_name, first_name);


/*****************************************************************************************
properties
*****************************************************************************************/

-- Composite to support: WHERE location=? ORDER BY pricepernight
CREATE INDEX idx_properties_location_price ON properties(location, pricepernight);

-- Host views w/ recency: WHERE host_id=? ORDER BY created_at DESC
CREATE INDEX idx_properties_host_created ON properties(host_id, created_at);


/*****************************************************************************************
Bookings
*****************************************************************************************/

-- Availability lookups benefit from leading property_id, then dates
-- Helps queries that filter by property_id and compare date ranges
CREATE INDEX idx_bookings_property_dates ON bookings(property_id, start_date, end_date);

-- User itinerary lists (supports WHERE user_id=? ORDER BY start_date)
CREATE INDEX idx_bookings_user_dates ON bookings(user_id, start_date);

-- Ops dashboards time-slicing by status, then start date range scanning
CREATE INDEX idx_bookings_status_start ON bookings(status, start_date);


/*****************************************************************************************
NICE-TO-HAVE (outside the strict User/Booking/Property scope)
*****************************************************************************************/

/* PAYMENTS */
-- Time-based revenue reporting
CREATE INDEX idx_payments_payment_date ON payments(payment_date);

/* REVIEWS */
-- Latest reviews per property
CREATE INDEX idx_reviews_property_created ON reviews(property_id, created_at);
-- Reviewer history
CREATE INDEX idx_reviews_user_created ON reviews(user_id, created_at);

/* MESSAGES */
-- Inbox: WHERE recipient_id=? ORDER BY sent_at DESC
CREATE INDEX idx_messages_recipient_sent ON messages(recipient_id, sent_at);
-- Sent folder
CREATE INDEX idx_messages_sender_sent ON messages(sender_id, sent_at);


/*****************************************************************************************
MEASURING IMPACT 
*****************************************************************************************/

-- A) Availability check (benefits: idx_bookings_property_dates)
-- BEFORE: EXPLAIN and/or EXPLAIN ANALYZE this query, then AFTER creating the index re-run.
EXPLAIN FORMAT=TREE
SELECT 1
FROM bookings b
WHERE b.status = 'canceled'
  AND b.start_date < DATE('2025-01-10')
  AND b.end_date   > DATE('2025-12-05')
LIMIT 1;

-- B) User itinerary (benefits: idx_bookings_user_dates)
EXPLAIN ANALYZE
SELECT b.booking_id, b.property_id, b.start_date, b.end_date, b.status
FROM bookings b
WHERE b.user_id = 'USER-UUID-HERE'
ORDER BY b.start_date DESC
LIMIT 20;

-- C) Browse properties in a city sorted by price (benefits: idx_properties_location_price)
EXPLAIN ANALYZE
SELECT p.property_id, p.name, p.location, p.pricepernight
FROM properties p
WHERE p.location = 'Nairobi, Kenya'
ORDER BY p.pricepernight ASC
LIMIT 50;

-- D) Host properties by recency (benefits: idx_properties_host_created)
EXPLAIN FORMAT=TREE
SELECT p.property_id, p.name, p.created_at
FROM properties p
WHERE p.host_id = 'HOST-UUID-HERE'
ORDER BY p.created_at DESC
LIMIT 20;

-- E) Role-based user list (benefits: idx_users_role, idx_users_created_at)
EXPLAIN ANALYZE
SELECT u.user_id, u.first_name, u.last_name, u.created_at
FROM users u
WHERE u.role = 'host'
ORDER BY u.created_at DESC
LIMIT 50;

-- To validate usage, inspect 'rows examined', 'cost', and whether the new indexes appear in 'used_columns' / 'possible_keys'.
-- Rollback plan if needed (example):
-- DROP INDEX idx_bookings_property_dates ON bookings;
