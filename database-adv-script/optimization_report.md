The iniitial query thaat retrieves all bookings along with the user details and payments is as follows:
`
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
`
The resulting `Explain` result is : 
```sql
'-> Sort: b.created_at DESC, pay.payment_date DESC\n` 
   `-> Stream results  (cost=1.07 rows=6.67)\n`        
   `-> Left hash join (pay.booking_id = b.booking_id)  (cost=1.07 rows=6.67)\n `
              `-> Nested loop inner join  (cost=2.78 rows=3.33)\n`                
              `-> Nested loop inner join  (cost=1.62 rows=3.33)\n `                   
              `-> Table scan on p  (cost=0.45 rows=2)\n`                    
              `-> Index lookup on b using idx_bookings_property_dates (property_id=p.property_id)  (cost=0.5 rows=1.67)\n`                
              `-> Single-row index lookup on u using PRIMARY (user_id=b.user_id)  (cost=0.28 rows=1)\n`            
              `-> Hash\n`
                              `-> Table scan on pay  (cost=0.139 rows=2)\n'`
```
Existing Bottle necks:
1. `-> Sort: b.created_at DESC, pay.payment_date DESC:` This is a big red flag. A Sort operation means the database has to retrieve all the data first, then sort it in a separate step. For a large number of bookings, this could be very slow and use a lot of memory.

2. `-> Table scan on p and -> Table scan on pay:` These also indicate inefficiencies. A "table scan" means the database is reading every single row from the properties and payments tables to find the rows it needs. While the cost is low in your example, on a large production database with millions of rows, this would be a massive performance bottleneck.

Whats working well :
1. `-> Index lookup on b using idx_bookings_property_dates:` This shows that an index on the bookings table is being used, which is great! The database is efficiently looking up the bookings that match the properties.

2. `-> Single-row index lookup on u using PRIMARY:` This is also good. It means the database is using the primary key on the users table to quickly find user details.

OPtimization Notes:
 - Creating a composite index on `(created_at, booking_id)` for the bookings table and an index on `payment_date` for the payments table would allow the database to use the index for sorting, completely eliminating that costly sort operation.
 - The key to fixing the Table scan is to create an index on the join column. We need to ensure an index exists on the *join keys* in the Properties and Payments tables, as well as the Bookings table. This allows the database to use a much faster index lookup instead of a slow table scan.
 Thus we need to add indexes to the following columns:

 1. `b.created_at` on the bookings table (to optimize the ORDER BY clause).

 2. `p.property_id`on the properties table (to optimize the JOIN).

 3. `pay.payment_id` on the payments table (to optimize the JOIN).

 4. `b. booking_id` & `payment_date` Adds a composite to support ORDER/GROUP by booking then date:

`CREATE INDEX idx_bookings_created_at ON bookings(created_at);`

`CREATE INDEX idx_property_property_id ON properties(property_id);`

`CREATE INDEX idx_payments_payment_id ON payments(payment_id);`

`CREATE INDEX idx_payments_booking_date ON payments(booking_id, payment_date);`

### Results of Refactoring

Results of the EXPLAIN:
```sql
'-> Sort: b.created_at DESC, pay.payment_date DESC\n
    -> Stream results  (cost=1.76 rows=1)\n
            -> Nested loop inner join  (cost=1.76 rows=1)\n
                        -> Nested loop left join  (cost=1.41 rows=1)\n
                                        -> Nested loop inner join  (cost=1.06 rows=1)\n
                                                            -> Index range scan on b using idx_bookings_created_at over (\'2025-12-01 00:00:00\' < created_at), with index condition: (b.created_at > TIMESTAMP\'2025-12-01 00:00:00\')  (cost=0.71 rows=1)\n 
                                                                               -> Single-row index lookup on p using PRIMARY (property_id=b.property_id)  (cost=0.35 rows=1)\n
                                                                                               -> Index lookup on pay using idx_payments_booking_id (booking_id=b.booking_id)  (cost=0.35 rows=1)\n
                                                                                                           -> Single-row index lookup on u using PRIMARY (user_id=b.user_id)  (cost=0.35 rows=1)\n'
```
Let's compare this to the original plan:

|Old Plan (before WHERE clause)	        | New Plan (after WHERE clause)                         | 
|---------------------------------------|-------------------------------------------------------|
|-> Table scan on p	                    | -> Index lookup on p using PRIMARY                    | 
|-> Table scan on pay	                | -> Index lookup on pay using idx_payments_booking_id  |
|-> Sort operation on a larger dataset  |-> Index range scan on b using idx_bookings_created_at |

The new plan is much more efficient. The most important change is that the database is now using an Index range scan on b using idx_bookings_created_at. This means it is no longer scanning the entire bookings table. By adding the WHERE clause, you gave the optimizer a reason to use your new index, drastically reducing the number of rows it had to process and sort. 





