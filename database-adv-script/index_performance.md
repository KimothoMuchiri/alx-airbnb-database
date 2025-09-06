To get the most out of indexes, we need to be strategic about which columns we choose to index. We don't want to just index every column, because as we learned, that can slow down data modifications.

The best candidates for indexing are columns used in one of three key places in my SQL queries:

- `WHERE` clauses: These are the columns you use to filter your results. For example, `SELECT * FROM Users WHERE country = 'Kenya'`. An index on the country column would make it much faster to find all users from Kenya without checking every single row.

- `JOIN` clauses: When you're combining data from two or more tables, you use a JOIN on a specific column. For example, `SELECT * FROM Bookings JOIN Users ON Bookings.user_id = Users.id`. Indexing the user_id column on the Bookings table (which is a foreign key) and the id column on the Users table (primary key) is crucial for making this join fast.

- `ORDER` BY clauses: When you sort your results, an index on the column you're sorting by can speed things up. For example, `SELECT * FROM Properties ORDER BY price DESC`. If there's an index on the price column, the database can use the pre-sorted index to return the results quickly instead of sorting the entire dataset on the fly.

For my database I choose the following columns for indexing:

1. #### USERS
Common patterns:
  - Lookups by role (role-based admin/host dashboards).  
  - Recent users (created_at DESC).  
  - Name searches + ordering (last_name, first_name).  
Existing:  
  - PK on user_id  
  - UNIQUE on email  

2. #### PROPERTIES
Common patterns:  
  - Browse/search by location, then sort/filter by price.  
  - Host dashboards: find properties by host and creation date.  
Existing:  
  - idx_properties_host_id(host_id)  
  - idx_properties_location(location)  
  - idx_properties_pricepernight(pricepernight)  

3. #### BOOKINGS
Common patterns:  
  - Availability check: WHERE property_id=? AND date ranges overlap  
  - User itinerary: WHERE user_id=? ORDER BY start_date  
  - Ops views by status and date: WHERE status='confirmed' AND start_date BETWEEN ...  
Existing:
  - idx_bookings_property_id(property_id)  
  - idx_bookings_user_id(user_id)  
  - idx_bookings_status(status)  
  - idx_bookings_start_end(start_date, end_date)  

4. #### PAYMENTS 
-- Time-based revenue reporting
  - CREATE INDEX idx_payments_payment_date ON payments(payment_date);

5. #### REVIEWS 
-- Latest reviews per property
  - idx_reviews_property_created

6. #### Reviewer history
  - idx_reviews_user_created 

7. #### MESSAGES 
-- Inbox: WHERE recipient_id=? ORDER BY sent_at DESC
  - idx_messages_recipient_sent
-- Sent folder
  - idx_messages_sender_sent 

#### Measuring Impact
the output of running the query when indexed ias as follows:

`-> Index range scan on b using idx_bookings_start_end over (start_date < '2025-01-10'), with index condition: ((b.start_date < <cache>(cast('2025-01-10' as date))) and (b.end_date > <cache>(cast('2025-12-05' as date))))`

- `Index range scan:` It means the database is not performing a full table scan. Instead, it's using an index to narrow down the search range. This is exactly what we want to see.

- `using idx_bookings_start_end:` This confirms that your new index, which you've named `idx_bookings_start_end,` is being used by the query optimizer.

- `with index condition:` This part shows that the database is applying the conditions (start_date < ... and end_date > ...) directly to the index itself, making the filtering incredibly efficient.

The `Filter: (b.status = 'canceled')` line shows that after using the index to find a narrow range of rows, the database then applies the status filter to those few rows, which is a very efficient process.

The rows=1 part of the output means that the optimizer estimated that it only needed to examine a single row to satisfy the LIMIT 1 condition. It's a key indicator of efficiency. Because the index helped the database find the target row so quickly, it didn't have to scan many rows at all. The cost=0.71 also shows that this was a very cheap operation.


