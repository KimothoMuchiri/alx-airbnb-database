-- Target: MySQL 8.0 (InnoDB)
-- Schema: airbnb_demo
-- Purpose: Demonstrate refactoring a complex multi-join booking query for performance.

USE airbnb_demo;

/*****************************************************************************************
SECTION 1 — INITIAL (NAÏVE) QUERY
- Retrieves all bookings joined to users, properties, and payments.
- Joins payments directly -> row explosion when a booking has multiple payments.
- SELECTs many columns -> larger row size.
*****************************************************************************************/

-- EXPLAIN the baseline
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
ORDER BY b.created_at DESC, pay.payment_date DESC;

-- Notes:
-- * Multiplicative rows when there are multiple payments per booking.
-- * ORDER BY includes pay.payment_date -> forces sort of a larger joined set.
-- * If consuming app expects one row per booking, this is inefficient.


/*****************************************************************************************
SECTION 2 — REFACTORED APPROACH (PAYMENT SUMMARY PER BOOKING)
Goal: Keep one row per booking while still returning “payment details” that are useful.
Two common options:
  A) Latest payment per booking (most typical UI need)
  B) Aggregated payments per booking (total paid + latest date)
Below we provide both; pick the one matching your feature.
Indexes used:
  - bookings(user_id), bookings(property_id), bookings(start_date, end_date) [from prior work]
  - payments(booking_id), payments(payment_date) [ensure composite (booking_id, payment_date)]
*****************************************************************************************/

/* 2A. Latest payment per booking using window functions (MySQL 8+)
      Builds a compact derived table with at most one row per booking. */
EXPLAIN FORMAT=TREE
WITH latest_payment AS (
  SELECT booking_id, payment_id, amount, payment_date, payment_method,
         ROW_NUMBER() OVER (PARTITION BY booking_id ORDER BY payment_date DESC, payment_id DESC) AS rn
  FROM payments
)
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
  p.name     AS property_name,
  p.location AS property_location,
  p.pricepernight,
  lp.payment_id     AS latest_payment_id,
  lp.amount         AS latest_payment_amount,
  lp.payment_date   AS latest_payment_date,
  lp.payment_method AS latest_payment_method
FROM bookings AS b
JOIN users AS u
  ON u.user_id = b.user_id
JOIN properties AS p
  ON p.property_id = b.property_id
LEFT JOIN latest_payment AS lp
  ON lp.booking_id = b.booking_id AND lp.rn = 1
ORDER BY b.created_at DESC, lp.payment_date DESC;

/* 2B. Aggregated payments per booking (one row per booking; keeps sums & last date) */
EXPLAIN FORMAT=TREE
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
  p.name     AS property_name,
  p.location AS property_location,
  p.pricepernight,
  ps.total_paid,
  ps.last_payment_date
FROM bookings AS b
JOIN users AS u
  ON u.user_id = b.user_id
JOIN properties AS p
  ON p.property_id = b.property_id
LEFT JOIN (
  SELECT
    booking_id,
    SUM(amount) AS total_paid,
    MAX(payment_date) AS last_payment_date
  FROM payments
  GROUP BY booking_id
) AS ps
  ON ps.booking_id = b.booking_id
ORDER BY b.created_at DESC, ps.last_payment_date DESC;


/*****************************************************************************************
SECTION 3 — HELPFUL INDEXES FOR THESE QUERIES
- Avoid full scans on payments when building latest/aggregate per booking.
- Composite index will accelerate partition lookups and grouping.
*****************************************************************************************/

-- If not present yet:
-- SHOW INDEX FROM payments;
-- Single-column exists: idx_payments_booking_id(booking_id)
-- Add a composite to support ORDER/GROUP by booking then date:
CREATE INDEX idx_payments_booking_date ON payments(booking_id, payment_date);

-- Optional for ref sorting by booking recency
CREATE INDEX idx_bookings_created_at ON bookings(created_at);


/*****************************************************************************************
SECTION 4 — VERIFICATION QUERIES
- Count rows to ensure refactor didn’t change result cardinality (per booking).
*****************************************************************************************/

-- Expect: baseline returns >= number of bookings (due to payment explosion)
SELECT COUNT(*) AS rows_naive
FROM bookings AS b
JOIN users AS u ON u.user_id = b.user_id
JOIN properties AS p ON p.property_id = b.property_id
LEFT JOIN payments AS pay ON pay.booking_id = b.booking_id;

-- Expect: exactly number of bookings (one row per booking)
SELECT COUNT(*) AS rows_window_latest
FROM (
  WITH latest_payment AS (
    SELECT booking_id,
           ROW_NUMBER() OVER (PARTITION BY booking_id ORDER BY payment_date DESC, payment_id DESC) AS rn
    FROM payments
  )
  SELECT b.booking_id
  FROM bookings b
  LEFT JOIN latest_payment lp
    ON lp.booking_id = b.booking_id AND lp.rn = 1
) t;

-- Expect: exactly number of bookings (one row per booking)
SELECT COUNT(*) AS rows_agg_summary
FROM bookings b
LEFT JOIN (
  SELECT booking_id FROM payments GROUP BY booking_id
) ps ON ps.booking_id = b.booking_id;
