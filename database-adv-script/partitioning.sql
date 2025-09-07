-- Target: MySQL 8.0 (InnoDB)
-- Schema: airbnb_demo
-- Goal: Partition bookings by start_date to improve date-range queries.
-- IMPORTANT: In MySQL, every UNIQUE/PRIMARY KEY on a partitioned table must include
-- the partitioning column(s). We refactor the PRIMARY KEY accordingly while preserving
-- a UNIQUE key on booking_id so existing FKs (payments.booking_id) remain valid.

USE airbnb_demo;

-- Safety: inspect existing structure
-- SHOW CREATE TABLE bookings\G
-- SHOW INDEX FROM bookings;
-- SHOW CREATE TABLE payments\G

START TRANSACTION;

--- Method 1
--- I first create a table with yearly partitions
--- since it is `dates` we use RANGE partitioning
--- For RANGE partitioning, your chosen partitioning 
---- column (start_date) must be part of the table's primary key. 
--- It has a similar structure to the original bookings table
---  for partitioned tables 
CREATE TABLE bookings_partitioned (
   booking_id CHAR(36) NOT NULL,
   property_id CHAR(36) NOT NULL,
   user_id CHAR(36) NOT NULL,
   start_date DATE NOT NULL,
   end_date DATE NOT NULL,
   total_price DECIMAL(10,2) NOT NULL,
   status ENUM('pending','confirmed','canceled') NOT NULL,
   created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
   CONSTRAINT pk_bookings PRIMARY KEY (booking_id, start_date),
   CONSTRAINT chk_partitioned_booking_dates CHECK (start_date < end_date)
)
PARTITION BY RANGE (TO_DAYS(start_date)) (
    PARTITION p_2023 VALUES LESS THAN (TO_DAYS('2024-01-01')),
    PARTITION p_2024 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_2025 VALUES LESS THAN (TO_DAYS('2026-01-01')),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);

EXPLAIN SELECT * FROM bookings_partitioned 
as bp WHERE start_date BETWEEN '2024-01-01' AND '2024-12-31';

--- Migrating tables ---
--- 1 create the backup
CREATE TABLE bookings_backup AS SELECT * FROM bookings;

-- make the migration from bookings to bookings partitioned --
INSERT INTO bookings_partitioned SELECT * FROM bookings;

--- now swap the table names
RENAME TABLE bookings TO bookings_old, bookings_partitioned TO bookings;

--- now clean the old bokings table to free up space
--- needs to temporalily drop relationships then recreate them with new table
SET FOREIGN_KEY_CHECKS = 0; -- Temporarily disable foreign key checks
DROP TABLE bookings_old;
SET FOREIGN_KEY_CHECKS = 1; -- Re-enable foreign key checks

--- recreate the relationship
ALTER TABLE payments
ADD CONSTRAINT fk_payments_booking_new
FOREIGN KEY (booking_id) REFERENCES bookings(booking_id);

--- Method 2

-- 1) Drop FK from payments -> bookings to allow PK change
ALTER TABLE payments DROP FOREIGN KEY fk_payments_booking;

-- 2) Ensure a UNIQUE key exists on booking_id alone (for FK target)
ALTER TABLE bookings
  ADD UNIQUE KEY uq_bookings_booking_id (booking_id);

-- 3) Change PRIMARY KEY to include start_date (required for partitioning)
ALTER TABLE bookings
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (booking_id, start_date);

-- 4) (Optional but recommended) Add composite index to support availability checks
--    If created earlier, this will be reused.
-- CREATE INDEX idx_bookings_property_dates ON bookings(property_id, start_date, end_date);

-- 5) Recreate the FK from payments -> bookings(booking_id) pointing to the UNIQUE key
ALTER TABLE payments
  ADD CONSTRAINT fk_payments_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
  ON UPDATE RESTRICT ON DELETE RESTRICT;

COMMIT;

-- === Partition the bookings table ===
-- Strategy: RANGE COLUMNS(start_date) by month (example) or by quarter/year depending on data volume.
-- Below we show QUARTER partitions for 2023-2027 plus MAXVALUE.
-- Adjust ranges to match your data distribution.

ALTER TABLE bookings
PARTITION BY RANGE COLUMNS(start_date) (
  PARTITION p2023q1 VALUES LESS THAN ('2023-04-01'),
  PARTITION p2023q2 VALUES LESS THAN ('2023-07-01'),
  PARTITION p2023q3 VALUES LESS THAN ('2023-10-01'),
  PARTITION p2023q4 VALUES LESS THAN ('2024-01-01'),
  PARTITION p2024q1 VALUES LESS THAN ('2024-04-01'),
  PARTITION p2024q2 VALUES LESS THAN ('2024-07-01'),
  PARTITION p2024q3 VALUES LESS THAN ('2024-10-01'),
  PARTITION p2024q4 VALUES LESS THAN ('2025-01-01'),
  PARTITION p2025q1 VALUES LESS THAN ('2025-04-01'),
  PARTITION p2025q2 VALUES LESS THAN ('2025-07-01'),
  PARTITION p2025q3 VALUES LESS THAN ('2025-10-01'),
  PARTITION p2025q4 VALUES LESS THAN ('2026-01-01'),
  PARTITION p2026 VALUES LESS THAN ('2027-01-01'),
  PARTITION pmax   VALUES LESS THAN (MAXVALUE)
);

-- Maintenance helpers: add/drop/reorganize partitions as time advances
-- Example: add 2026 quarters later
-- ALTER TABLE bookings REORGANIZE PARTITION p2026 INTO (
--   PARTITION p2026q1 VALUES LESS THAN ('2026-04-01'),
--   PARTITION p2026q2 VALUES LESS THAN ('2026-07-01'),
--   PARTITION p2026q3 VALUES LESS THAN ('2026-10-01'),
--   PARTITION p2026q4 VALUES LESS THAN ('2027-01-01')
-- );

-- === Test queries (use EXPLAIN to see partition pruning) ===

-- Show partitions used by a specific date range
EXPLAIN PARTITIONS
SELECT b.booking_id, b.user_id, b.property_id, b.start_date, b.end_date, b.status
FROM bookings b
WHERE b.start_date >= '2025-06-01' AND b.start_date < '2025-07-01';

-- Range overlap check often used for availability searches
EXPLAIN PARTITIONS
SELECT 1
FROM bookings b
WHERE b.property_id = 'PROPERTY-UUID-HERE'
  AND b.start_date < DATE('2025-08-15')
  AND b.end_date   > DATE('2025-08-10')
LIMIT 1;

-- Broader slice across multiple partitions
EXPLAIN PARTITIONS
SELECT COUNT(*)
FROM bookings b
WHERE b.start_date BETWEEN '2024-01-01' AND '2025-12-31';

-- Compare with EXPLAIN ANALYZE (MySQL 8.0.18+)
-- EXPLAIN ANALYZE SELECT ...;
