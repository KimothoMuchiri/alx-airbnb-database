Partition the large `bookings` table by `start_date` to improve date-range queries via partition pruning.
Think of it using a phonebook analogy. If you only want to find someone who lives in New York, you don't even open the books for any other state. In the same way, when you query a partitioned table, the database is smart enough to "prune" or ignore the partitions that don't contain the data you're looking for.

## Implementation Summary
Tried two methods:
1. Created a new table `bookings_partitioned`, partitioned it then migrated the data from the old `bookings` table to it, and then swapped and cleaned the tables
```sql
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

```
Running `EXPLAIN` on the query showed that the query is now using the partitions

```
'1', 'SIMPLE', 'bp', 'p_2023,p_2024', 'ALL', NULL, NULL, NULL, NULL, '1', '100.00', 'Using where'
```
`p_2023,p_2024 under the partitions column.` This tells you that the database is only looking at two of the partitions to fulfill the request. It has successfully "pruned" the p_2025 and p_future partitions because it knows they can't contain the data you're looking for. This is partition pruning in action!  
The constraint in this is establishing the Freign key in payments again, this is not allowed.


2. Switched `bookings` **PRIMARY KEY** from `(booking_id)` to **`(booking_id, start_date)`** to satisfy MySQL’s rule that **all UNIQUE keys in a partitioned table must include the partition column(s)**.
- Added a **UNIQUE** key on `(booking_id)` to preserve FK compatibility with `payments.booking_id`.
- Recreated the FK `payments → bookings(booking_id)` to point at the unique key.
- Applied **RANGE COLUMNS(start_date)** partitioning by quarter for 2023–2026 + `MAXVALUE`.
- Kept supporting indexes (e.g., `bookings(property_id, start_date, end_date)`) for range-overlap checks.

See `partitioning.sql` for exact DDL and test queries.

## How I Measured
For each query below, I captured **EXPLAIN PARTITIONS** and (where available) **EXPLAIN ANALYZE** *before* and *after* partitioning:

1. **Narrow month slice**
   ```sql
   SELECT b.booking_id, b.user_id, b.property_id, b.start_date
   FROM bookings b
   WHERE b.start_date >= '2025-06-01' AND b.start_date < '2025-07-01';
   ```