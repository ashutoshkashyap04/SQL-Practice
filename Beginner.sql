-- Phase 01 : CRUD  and basic queries

--1. The company wants to view all customers from India to run a regional campaign.
SELECT * FROM customer
WHERE country = 'India'

-- Find all tracks priced above average to identify premium content.
SELECT * FROM track

SELECT track_id, name, unit_price
FROM track
WHERE unit_price > (
	SELECT AVG(unit_price)
	FROM track
)

--2.  Show top 10 longest songs for playlist curation.
SELECT * FROM track
ORDER BY milliseconds DESC
LIMIT 10

--3.  Identify customers who haven’t provided email (data quality issue).
SELECT * FROM customer
WHERE email IS null

--4. List all rock genre tracks to promote in a campaign.
SELECT * FROM track
WHERE genre_id = '1'

--5.  Add a new customer (simulate onboarding system).
SELECT * FROM customer
INSERT INTO customer(customer_id, first_name, last_name, country, email)
VALUES(60, 'Ashutosh', 'Kashyap', 'India', 'ashu@gmail.com')

--6. Update incorrect city name for a customer (data correction).
UPDATE customer 
SET city = 'Mumbai'
WHERE first_name = 'Manoj'


--7. Remove inactive playlist (cleanup operation).
DELETE FROM playlist
WHERE playlist_id NOT IN (
    SELECT DISTINCT playlist_id FROM playlist_track
);



--8. Show employees hired after 2016 (recent workforce analysis).
SELECT * FROM Employee
WHERE hire_date >= '2017-01-01'

--9. Find tracks shorter than 2 minutes (short-form content trend).
SELECT * FROM track
WHERE milliseconds < 2*60*1000

--10. Identify albums with no tracks (data inconsistency).
SELECT * FROM album
WHERE album_id NOT IN(
	SELECT album_id FROM track
)

--11. Show invoices above ₹10 (high-value customers).
SELECT * FROM invoice
WHERE total > 10


--12. Retrieve customers sorted by country (market segmentation).
SELECT first_name , last_name, country 
FROM customer
ORDER BY country


--13. Find duplicate customer names (data issue).
SELECT first_name, COUNT(*) 
FROM customer
GROUP BY first_name
HAVING COUNT(*) > 1;


--14. Count total tracks in database (inventory size).
SELECT * FROM track

SELECT COUNT(track_id) AS total_track
FROM track 



-- Phase02 : Data Types and Constraints

--1. Ensure every customer must have email(identify violations)
SELECT * FROM customer
WHERE email IS null


--2. Find tracks with NULL composer(missing metadata problem)
SELECT * FROM track
WHERE composer IS null


--3. Validate invoices where total<0(data corruption)
SELECT * FROM invoice
WHERE total < 0

--4. Identify customers without country info
SELECT * FROM customer
WHERE country IS null


--5. Check for duplicate primary keys(simulation)
SELECT customer_id , COUNT(*)
FROM customer
GROUP BY customer_id
HAVING COUNT(*) > 1


--6. Enforce unique emails -> find duplicates
SELECT  email, COUNT(*)
FROM customer
GROUP BY email
HAVING COUNT(*) > 1


--7. Find invoices without billing city
SELECT * FROM invoice
WHERE billing_city IS NULL;


--8. Detect tracks with price = 0(free vs error)
SELECT * FROM track
WHERE unit_price = 0


--9. Identify employees without manager(hierarchy gap)
SELECT * FROM employee
WHERE reports_to IS null


--10. Validate phone phone number formats(data cleaning)
SELECT * FROM employee
WHERE phone !~ '^\\+1 \\([0-9]{3}\\) [0-9]{3}-[0-9]{4}$';


--Phase 03 :  Aggregations

--1. Total revenue per country (market performance)
SELECT billing_country, SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country


--2. Top 5 countries by revenue(expansion focus)
SELECT billing_country, SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country
ORDER BY total_revenue DESC
LIMIT 5

--3. Average order value per customer
SELECT customer_id, AVG(total) AS avg_order_value
FROM invoice
GROUP BY customer_id;


--4. Number of tracks per genre(content distribution)
SELECT genre_id, COUNT(track_id) AS track_count
FROM track
GROUP BY genre_id
ORDER BY track_count DESC


--5. Find genres less than 50 tracks(low inventory)
SELECT genre_id, COUNT(track_id) AS track_count
FROM track
GROUP BY genre_id
HAVING COUNT(track_id) < 50


--6. Total sales per employee(performance tracking)
SELECT e.employee_id, e.first_name, e.last_name,
       SUM(i.total) AS total_sales
FROM employee e
JOIN customer c 
  ON CAST(e.employee_id AS INTEGER) = c.support_rep_id
JOIN invoice i 
  ON i.customer_id = c.customer_id
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY total_sales DESC;

--7. Customer who spent more than average
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(i.total) > (
    SELECT AVG(total) FROM invoice
);



--8. Monthly revenue Trend
SELECT DATE_TRUNC('month', invoice_date) AS month,
       SUM(total) AS revenue
FROM invoice
GROUP BY month
ORDER BY month;

--9. Top 3 customers by spending
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 3;

--10. Albums with highest number of tracks
SELECT  album_id , COUNT(track_id)
FROM track
GROUP BY album_id
ORDER BY COUNT(track_id) DESC
LIMIT 1

--11. Genre contributing highest revenue
SELECT g.name, SUM(il.unit_price * il.quantity) AS revenue
FROM invoice_line il
JOIN track t ON t.track_id = il.track_id
JOIN genre g ON g.genre_id = t.genre_id
GROUP BY g.name
ORDER BY revenue DESC
LIMIT 1;



--12. Identify inactive customers(0 purchase)
SELECT first_name, last_name
FROM customer
WHERE customer_id NOT IN(
	SELECT customer_id FROM invoice
)



--13. Average track duration per genre
SELECT genre.name, AVG(track.milliseconds)
FROM track
JOIN genre ON genre.genre_id = track.genre_id
GROUP BY genre.name


--14. Countries with low customer count(<5)
SELECT country, COUNT(customer_id)
FROM customer
GROUP BY country
HAVING COUNT(customer_id) < 5
ORDER BY COUNT(customer_id) DESC


--15. Find repeat customers(multiple invoices)
SELECT  customer.first_name, customer.last_name
FROM customer
JOIN invoice ON invoice.customer_id = customer.customer_id
GROUP BY customer.customer_id
HAVING  COUNT(invoice.customer_id) > 1