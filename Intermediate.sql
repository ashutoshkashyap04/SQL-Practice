-- Phase 01: String Function , Alter , CASE

--1. Categorize customers into High/Medium /Low spenders

SELECT c.customer_id, c.first_name, c.last_name,
	SUM(i.total) AS total_spent,
	CASE
		WHEN SUM(i.total) < 20 THEN 'LOW'
		WHEN SUM(i.total) BETWEEN 20 AND 50 THEN 'MEDIUM'
		ELSE 'HIGH'
	END AS spender_category
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name;

--2. Convert track duration into minutes
SELECT track_id, name, milliseconds / 60000.0 AS minutes
FROM track;

--3. Extract year from invoice date (trend analysis)
SELECT *, EXTRACT(YEAR FROM invoice_date) AS year
FROM invoice;


--4. Mask customer email(privacy)
SELECT *,
	LEFT(email, 2) || '****' || SPLIT_PART(email, '@', 2) AS masked_email
FROM customer;


--5. Identify weekend vs weekday sales
SELECT *,
	CASE 
		WHEN EXTRACT(DOW FROM invoice_date) IN (0,6) THEN 'Weekend'
		ELSE 'Weekday'
	END AS day_type
FROM invoice;


--6. Categorize songs : short/medium/long
SELECT * , 
	CASE 
		WHEN milliseconds > 200000 THEN 'LONG'
		WHEN milliseconds BETWEEN 100000 AND 200000 THEN 'MEDIUM'
		ELSE 'SHORT'
	END AS track_length
FROM track;


--7. Format customer full name
SELECT *, CONCAT(TRIM(first_name),' ',TRIM(last_name)) AS full_name
FROM customer;


--8. Extract domain name from email
SELECT *,
	SPLIT_PART(email, '@', 2) AS email_domain
FROM customer;

--9. Flag invoices above 10 as "High value"
SELECT *,
	CASE 
		WHEN total > 10 THEN 'High Value'
		ELSE 'Normal'
	END AS invoice_flag
FROM invoice;



--10. Convert price to INR
SELECT *, total * 90 AS total_in_inr
FROM invoice; 


--11. Detect international vs domestic customers
SELECT * , 
	CASE
		WHEN country = 'India' THEN 'Domestic'
		ELSE 'International'
	END AS customer_region
FROM customer;

--12. Create age groups for employees
SELECT *,
	CASE 
		WHEN EXTRACT(YEAR FROM AGE(birthdate)) < 30 THEN 'Young'
		WHEN EXTRACT(YEAR FROM AGE(birthdate)) BETWEEN 30 AND 50 THEN 'Mid'
		ELSE 'Senior'
	END AS age_group
FROM employee;



--13. Trim inconsistent string data
SELECT *,
	TRIM(first_name) AS clean_first_name,
	TRIM(last_name) AS clean_last_name
FROM customer;


--14. Replace missing composer with 'Unknown'
SELECT * , 
COALESCE (composer, 'Unknown') AS composer_name
FROM track

-- 15. Rank Songs into price buckets
SELECT *,
	CASE 
		WHEN unit_price < 0.99 THEN 'Cheap'
		WHEN unit_price BETWEEN 0.99 AND 1.49 THEN 'Regular'
		ELSE 'Premium'
	END AS price_category
FROM track;


--Phase 02:  Relationships and Joins


--1. Get customer purchase history
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total)
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY c.customer_id;

--2. Show tracks purchased by each customer
SELECT  c.first_name, c.last_name, t.name
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id;



--3. Find revenue generated per artist
SELECT artist.name, SUM(il.unit_price * il.quantity) AS revenue
FROM artist
JOIN album ON album.artist_id = artist.artist_id
JOIN track ON track.album_id = album.album_id
JOIN invoice_line il ON il.track_id = track.track_id
GROUP BY artist.name;

--4. Identify most popular genre per country
SELECT genre.genre_id, genre.name, i.billing_country
FROM genre
JOIN track ON track.genre_id = genre.genre_id
JOIN invoice_line il ON il.track_id = track.track_id
JOIN invoice i ON i.invoice_id = il.invoice_id
GROUP BY genre.genre_id , genre.name, i.billing_country
ORDER BY SUM(il.unit_price * il.quantity) DESC;




--5. List customers and their support reps
SELECT c.first_name, c.last_name, e.first_name AS represented_by
FROM customer c
JOIN employee e ON CAST(e.employee_id AS INTEGER) = c.support_rep_id;


--6. Find top-selling albums
SELECT album.title
FROM album
JOIN track ON track.album_id = album.album_id
JOIN invoice_line il ON il.track_id = track.track_id
GROUP BY album.title
ORDER BY SUM(il.unit_price * il.quantity) DESC
LIMIT 5;


--7. Track → Album → Artist full hierarchy
SELECT * FROM album
JOIN artist USING (artist_id)
JOIN track USING (album_id);



--8. Revenue per employee (joins across 3 tables)
SELECT e.first_name, e.last_name, SUM(i.total) AS revenue_generated
FROM employee e
JOIN customer c ON c.support_rep_id = CAST(e.employee_id AS INTEGER)
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY e.first_name, e.last_name;


--9.  Playlist and tracks inside them
SELECT p.playlist_id, p.name AS playlist_name, t.name AS track_name
FROM playlist p
JOIN playlist_track pt ON pt.playlist_id = p.playlist_id
JOIN track t ON t.track_id = pt.track_id
ORDER BY p.playlist_id;


--10.  Find customers who bought rock music
SELECT c.first_name , c.last_name
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
JOIN track t ON t.track_id = il.track_id
JOIN genre g ON g.genre_id = t.genre_id
WHERE g.name = 'Rock'
GROUP BY c.first_name, c.last_name;


--11. Get invoice details with track names
SELECT *, track.name
FROM invoice
JOIN invoice_line ON invoice_line.invoice_id = invoice.invoice_id
JOIN track ON track.track_id = invoice_line.track_id;


--12. Top artist by revenue
SELECT artist.name, SUM(il.unit_price * il.quantity) AS revenue
FROM artist
JOIN album ON album.artist_id = artist.artist_id
JOIN track ON track.album_id = album.album_id
JOIN invoice_line il ON il.track_id = track.track_id
GROUP BY artist.name
ORDER BY revenue DESC
LIMIT 1;


--13. Find unused playlists (no tracks)
SELECT p.name
FROM playlist p
LEFT JOIN playlist_track pt ON p.playlist_id = pt.playlist_id
WHERE pt.track_id IS NULL;



--14. Identify albums never purchased
SELECT a.title
FROM album a
LEFT JOIN track t ON t.album_id = a.album_id
LEFT JOIN invoice_line il ON il.track_id = t.track_id
WHERE il.track_id IS NULL;



--15. Show genre-wise revenue
SELECT g.name, SUM(il.unit_price * il.quantity) AS revenue
FROM genre g
JOIN track t ON t.genre_id = g.genre_id
JOIN invoice_line il ON il.track_id = t.track_id
GROUP BY g.name
ORDER BY revenue DESC;


--16.  Customers who bought more than 5 songs
SELECT c.first_name, c.last_name, COUNT(il.track_id) AS number_of_songs_purchased
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
GROUP BY c.first_name, c.last_name
HAVING COUNT(il.track_id)  > 5;


--17. Employee handling highest revenue customers
SELECT e.first_name, e.last_name, SUM(i.total) AS revenue_generated
FROM employee e
JOIN customer c ON c.support_rep_id = CAST(e.employee_id AS INTEGER)
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY e.first_name, e.last_name
ORDER BY revenue_generated DESC
LIMIT 1;


--18.  Track popularity (based on purchases)
SELECT t.name, SUM(il.quantity) AS total_purchase
FROM track t
JOIN invoice_line il ON il.track_id = t.track_id
GROUP BY t.name
ORDER BY total_purchase DESC
LIMIT 5;

--19. Compare revenue by media type
SELECT m.name, SUM(il.unit_price * il.quantity) AS revenue
FROM media_type m
JOIN track t ON t.media_type_id = m.media_type_id
JOIN invoice_line il ON il.track_id = t.track_id
GROUP BY m.name
ORDER BY revenue DESC;

--20. Find artists with no sales
SELECT artist.name
FROM artist
LEFT JOIN album ON album.artist_id = artist.artist_id
LEFT JOIN track t ON t.album_id = album.album_id
LEFT JOIN invoice_line il ON il.track_id = t.track_id
WHERE il.track_id IS NULL;


--Phase 03:  Subqueries


--1. Customers who spent more than average
SELECT c.first_name, c.last_name
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(i.total) > (
    SELECT AVG(total_spent)
    FROM (
        SELECT SUM(total) AS total_spent
        FROM invoice
        GROUP BY customer_id
    ) sub                            
);


--2. Most expensive track in each genre
SELECT t.name, g.name AS genre
FROM track t
JOIN genre g ON g.genre_id = t.genre_id
WHERE t.unit_price = (
    SELECT MAX(t2.unit_price)
    FROM track t2
	WHERE t2.genre_id = t.genre_id
    
);


--3. Find customers who never purchased
SELECT first_name, last_name
FROM customer
WHERE customer_id NOT IN (
	SELECT customer_id FROM invoice
);

--4. Albums with more tracks than average
SELECT album.title, COUNT(track.track_id) AS number_of_tracks
FROM album
JOIN track ON track.album_id = album.album_id
GROUP BY album.album_id, album.title
HAVING COUNT(track.track_id) > (
    SELECT AVG(track_count)
    FROM (
        SELECT COUNT(track_id) AS track_count
        FROM track
        GROUP BY album_id
    ) sub
);

 

--5. Employees earning above company avg
SELECT e.first_name, e.last_name, SUM(i.total) AS total_sales
FROM employee e
JOIN customer c ON c.support_rep_id = e.employee_id
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY e.employee_id, e.first_name, e.last_name
HAVING SUM(i.total) > (
    SELECT AVG(emp_total)
    FROM (
        SELECT SUM(i.total) AS emp_total
        FROM employee e
        JOIN customer c ON c.support_rep_id = e.employee_id
        JOIN invoice i ON i.customer_id = c.customer_id
        GROUP BY e.employee_id
    ) sub
);


--6. Top customer per country
SELECT c.first_name, c.last_name, i.billing_country, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, i.billing_country
HAVING SUM(i.total) = (
    SELECT MAX(country_max)
    FROM (
        SELECT SUM(i2.total) AS country_max
        FROM customer c2
        JOIN invoice i2 ON i2.customer_id = c2.customer_id
        WHERE i2.billing_country = i.billing_country
        GROUP BY c2.customer_id
    ) sub
);




--7. Tracks longer than avg duration
SELECT name
FROM track
WHERE milliseconds > (
	SELECT AVG(milliseconds) FROM track
);


--8. Genres with highest revenue
SELECT g.name, SUM(il.unit_price * il.quantity) AS revenue
FROM genre g
JOIN track t ON t.genre_id = g.genre_id
JOIN invoice_line il ON il.track_id = t.track_id
GROUP BY g.genre_id, g.name
HAVING SUM(il.unit_price * il.quantity) = (
    SELECT MAX(total_revenue)
    FROM (
        SELECT SUM(il.unit_price * il.quantity) AS total_revenue
        FROM genre g
        JOIN track t ON t.genre_id = g.genre_id
        JOIN invoice_line il ON il.track_id = t.track_id
        GROUP BY g.genre_id
    ) sub
);

--9. Customers who bought same track multiple times
SELECT c.first_name, c.last_name, il.track_id, COUNT(*) AS times_bought
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
JOIN invoice_line il ON il.invoice_id = i.invoice_id
GROUP BY c.customer_id, c.first_name, c.last_name, il.track_id
HAVING COUNT(*) > 1;

--10. Countries with above avg revenue
SELECT billing_country, SUM(total) AS revenue
FROM invoice
GROUP BY billing_country
HAVING SUM(total) > (
    SELECT AVG(country_total)
    FROM (
        SELECT SUM(total) AS country_total
        FROM invoice
        GROUP BY billing_country
    ) sub
);



--11. Find second highest spender
SELECT c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(i.total) = (
    SELECT MAX(total_spent)
    FROM (
        SELECT SUM(total) AS total_spent
        FROM invoice
        GROUP BY customer_id
    ) sub
    WHERE total_spent < (
        SELECT MAX(total_spent)
        FROM (
            SELECT SUM(total) AS total_spent
            FROM invoice
            GROUP BY customer_id
        ) sub2
    )
);



--12. Most popular playlist
SELECT p.name, COUNT(pt.track_id) AS track_count
FROM playlist p
JOIN playlist_track pt ON pt.playlist_id = p.playlist_id
GROUP BY p.playlist_id, p.name
HAVING COUNT(pt.track_id) = (
    SELECT MAX(track_count)
    FROM (
        SELECT COUNT(track_id) AS track_count
        FROM playlist_track
        GROUP BY playlist_id
    ) sub
);


--13. Tracks not present in any playlist
SELECT t.name
FROM track t
WHERE t.track_id NOT IN (
    SELECT track_id FROM playlist_track
);


--14. Artists with more albums than avg
SELECT a.name
FROM artist a
JOIN album al ON al.artist_id = a.artist_id
GROUP BY a.artist_id, a.name
HAVING COUNT(al.album_id) > (
    SELECT AVG(album_count)
    FROM (
        SELECT COUNT(album_id) AS album_count
        FROM album
        GROUP BY artist_id
    ) sub
);

--15. Customers with max purchases
SELECT c.first_name, c.last_name
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(i.total) = (
    SELECT MAX(total_spent)
    FROM (
        SELECT SUM(total) AS total_spent
        FROM invoice
        GROUP BY customer_id
    ) sub
);

