-- Phase 01: Common Table Expression(CTE)

--1. Revenue breakdown per customer using CTE
WITH revenue AS (
	SELECT c.customer_id, c.first_name, c.last_name , SUM(i.total) as pay
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
	GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT * FROM revenue;


--2. Top customers filtering using CTE
WITH top_customers AS (
	SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS payment
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
	GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT *
FROM top_customers
ORDER BY payment DESC
LIMIT 10; 


--3. Monthly sales trend using CTE
WITH monthly_sales AS (
	SELECT EXTRACT(MONTH FROM invoice_date) AS month,
		   SUM(total) AS total_sales
	FROM invoice
	GROUP BY EXTRACT(MONTH FROM invoice_date)
)
SELECT * 
FROM monthly_sales
ORDER BY month;


--4. Identify churn customers (no recent purchase)
WITH last_purchase AS (
	SELECT customer_id, MAX(invoice_date) AS last_date
	FROM invoice
	GROUP BY customer_id
),
churn_customers AS (
	SELECT c.customer_id, c.first_name, c.last_name
	FROM customer c
	LEFT JOIN last_purchase lp ON c.customer_id = lp.customer_id
	WHERE lp.last_date < CURRENT_DATE - INTERVAL '3  MONTHS'
		OR lp.last_date IS NULL
)
SELECT * FROM churn_customers;


--5. Recursive: employee hierarchy
WITH RECURSIVE emp_hierarchy AS (
	SELECT employee_id, first_name, last_name, reports_to, 1 AS level
	FROM employee
	WHERE reports_to IS NULL

	UNION ALL

	SELECT e.employee_id, e.first_name, e.last_name, e.reports_to , eh.level+1
	FROM employee e
	JOIN emp_hierarchy eh ON eh.employee_id = e.reports_to
)
SELECT * FROM emp_hierarchy;



--6. Revenue growth month over month
WITH monthly_sales AS (
	SELECT EXTRACT(YEAR FROM invoice_date) AS year,
	       EXTRACT(MONTH FROM invoice_date) AS month,
	SUM(total) AS revenue
	FROM invoice
	GROUP BY year, month
),
growth AS (
	SELECT m1.year, m1.month,
		m1.revenue AS current_revenue,
		m2.revenue AS prev_revenue,
		(m1.revenue - m2.revenue) AS growth
	FROM  monthly_sales m1
	LEFT JOIN monthly_sales m2 ON m1.year = m2.year
	AND m1.month = m2.month + 1
)
SELECT * FROM growth;


--7. Segment customers using CTE
WITH customer_spending AS (
	SELECT c.customer_id, c.first_name, c.last_name,
		   SUM(i.total) AS total_spent
	FROM customer c
	JOIN invoice i ON c.customer_id = i.customer_id
	GROUP BY c.customer_id, c.first_name, c.last_name
),
segmented AS (
	SELECT *,
		CASE 
			WHEN total_spent > 100 THEN 'High'
			WHEN total_spent BETWEEN 50 AND 100 THEN 'Medium'
			ELSE 'Low'
		END AS segment
	FROM customer_spending
)
SELECT * FROM segmented;


--8. Top genre per country using CTE
WITH genre_sales AS (
	SELECT c.country, g.name AS genre, SUM(i.total) AS revenue
	FROM customer c
	JOIN invoice i ON c.customer_id = i.customer_id
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN genre g ON t.genre_id = g.genre_id
	GROUP BY c.country, g.name
),
max_genre AS (
	SELECT country, MAX(revenue) AS max_revenue
	FROM genre_sales
	GROUP BY country
)
SELECT gs.country, gs.genre, gs.revenue
FROM genre_sales gs
JOIN max_genre mg 
ON gs.country = mg.country AND gs.revenue = mg.max_revenue;




--9. Running total revenue
WITH daily_sales AS (
	SELECT invoice_date::date AS day, SUM(total) AS revenue
	FROM invoice
	GROUP BY day
)
SELECT d1.day,
	   d1.revenue,
	   (
		   SELECT SUM(d2.revenue)
		   FROM daily_sales d2
		   WHERE d2.day <= d1.day
	   ) AS running_total
FROM daily_sales d1
ORDER BY d1.day;


--10. Filter high-value invoices using layered CTE
WITH invoice_totals AS (
	SELECT invoice_id, customer_id, total
	FROM invoice
),
avg_value AS (
	SELECT AVG(total) AS avg_total
	FROM invoice_totals
),
high_value AS (
	SELECT it.*
	FROM invoice_totals it, avg_value av
	WHERE it.total > av.avg_total
)
SELECT * FROM high_value;



-- Phase 02: Window Functions


--1. Rank customers by spending
WITH customer_spending AS (
    SELECT c.customer_id, c.first_name, c.last_name,
           SUM(i.total) AS total_spent
    FROM customer c
    JOIN invoice i ON i.customer_id = c.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT *,
       DENSE_RANK() OVER (ORDER BY total_spent DESC) AS customer_rank
FROM customer_spending;

--2. Top 3 customers per country
WITH customer_spending AS (
	SELECT c.customer_id, c.first_name , c.last_name, i.billing_country,
		   SUM(i.total) AS total_spent
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
	GROUP BY c.customer_id , c.first_name, c.last_name, i.billing_country
),
ranked_customer AS (
	SELECT *, ROW_NUMBER() OVER (
		PARTITION BY billing_country
		ORDER BY total_spent DESC
	) as rank
	FROM customer_spending
)
SELECT * FROM ranked_customer
WHERE rank <= 3;


--3. Running revenue total
WITH monthly_revenue AS (
	SELECT EXTRACT(YEAR FROM invoice_date) AS year,
		EXTRACT(MONTH FROM invoice_date) AS month,
		SUM(total) AS revenue
	FROM invoice
	GROUP BY year, month
)
SELECT year, month, revenue, SUM(revenue) OVER (
	ORDER BY year, month
	ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS running_revenue
FROM monthly_revenue;




--4. Moving average sales
WITH avg_sales AS (
	SELECT EXTRACT(YEAR FROM invoice_date) AS year,
		EXTRACT(MONTH FROM invoice_date) AS month,
		SUM(total) AS revenue
	FROM invoice
	GROUP BY year, month
)
SELECT year, month, revenue, 
	AVG(revenue) OVER (
		ORDER BY year, month
		ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
	) AS running_avg_revenue
FROM avg_sales;

--5. Rank tracks by playlist popularity
WITH track_popularity AS(
SELECT t.track_id, t.name, 
		COUNT(DISTINCT(pt.playlist_id)) AS track_count
	FROM track t
	JOIN playlist_track pt ON pt.track_id = t.track_id
	GROUP BY t.track_id, t.name
	ORDER BY track_count DESC
)
SELECT track_id, name,
	DENSE_RANK() OVER (
		ORDER BY track_count DESC) AS track_rank
FROM track_popularity;



--6. Dense rank genres by revenue
WITH genre_revenue AS (
	SELECT g.genre_id, g.name, SUM(i.total) AS revenue
	FROM genre g
	JOIN track t ON t.genre_id = g.genre_id
	JOIN invoice_line il ON il.track_id = t.track_id
	JOIN invoice i ON i.invoice_id = il.invoice_id
	GROUP BY g.genre_id, g.name
	ORDER BY revenue DESC
)
SELECT *, DENSE_RANK() OVER (
	ORDER BY revenue DESC) AS genre_rank
FROM genre_revenue;



--7. Percent contribution of each customer
WITH customer_spending AS (
	SELECT c.customer_id , c.first_name, c.last_name, SUM(i.total) AS spending
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
	GROUP BY  c.customer_id, c.first_name, c.last_name
)
SELECT *, ROUND(((spending * 100.0)/SUM(spending) OVER())::NUMERIC, 2)
	AS percentage_contribution
FROM customer_spending
ORDER BY percentage_contribution DESC;



--8. Lag: compare current vs previous purchase
WITH current_revenue AS (
	SELECT EXTRACT(YEAR FROM invoice_date) AS year,
			EXTRACT(MONTH FROM invoice_date) AS month,
			SUM(total) AS revenue
	FROM invoice
	GROUP BY year, month
	ORDER BY year, month
)
SELECT *, LAG(revenue) OVER (ORDER BY year, month) AS previous_revenue
FROM current_revenue;

--9. Lead: predict next purchase
SELECT customer_id , invoice_id, invoice_date,
	LEAD(invoice_date) OVER (
	PARTITION BY customer_id
	ORDER BY invoice_date) AS next_purchase
FROM invoice
ORDER BY customer_id, invoice_date;



--10. Row number for invoices
SELECT *, ROW_NUMBER() OVER 
	(PARTITION  BY DATE(invoice_date)) AS row_num
FROM invoice;


--11. Find first purchase per customer
WITH customer_first_day AS (
	SELECT c.customer_id, c.first_name, c.last_name,i.total, i.invoice_date
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
),
first_day_rank AS (
	SELECT * , 
		ROW_NUMBER() OVER (
			PARTITION BY customer_id ORDER BY invoice_date)
			AS days
	FROM customer_first_day
)
SELECT * FROM first_day_rank
WHERE days = 1;



--12. Repeat purchase gap analysis
SELECT customer_id, invoice_date,
	LAG(invoice_date) OVER (
		PARTITION BY customer_id
		ORDER BY invoice_date
	) AS prev_date,
	invoice_date - LAG(invoice_date) OVER (
		PARTITION BY customer_id
		ORDER BY invoice_date
	) AS gap_days
FROM invoice;


--13. Identify top track per genre
WITH track_count AS (
	SELECT t.track_id, t.name,g.genre_id, g.name, SUM(il.quantity) AS track_quantity
	FROM genre g
	JOIN track t ON t.genre_id = g.genre_id
	JOIN invoice_line il ON il.track_id = t.track_id
	GROUP BY t.track_id, t.name, g.genre_id, g.name
),
ranked_track AS (
	SELECT *,
		DENSE_RANK() OVER (
			PARTITION BY genre_id
			ORDER BY track_quantity DESC
		)AS rnk
		FROM track_count
)
SELECT * FROM ranked_track
WHERE rnk = 1;



--14. Revenue distribution percentile
SELECT total,PERCENT_RANK() OVER (ORDER BY total) AS percentile
FROM invoice;


--15. Customer lifetime value ranking
WITH customer_value AS (
	 SELECT c.customer_id , c.first_name, c.last_name, SUM(i.total) AS revenue
	 FROM customer c
	 JOIN invoice i ON i.customer_id = c.customer_id
	 GROUP BY c.customer_id , c.first_name, c.last_name
)
SELECT *, 
	DENSE_RANK() OVER (ORDER BY revenue DESC) AS rnk
FROM customer_value;


--16. Top album per artist
WITH popular_album AS (
	SELECT al.artist_id, al.album_id, al.title, SUM(il.quantity) AS quantity
	FROM album al
	JOIN artist ar ON ar.artist_id = al.artist_id
	JOIN track t ON t.album_id = al.album_id
	JOIN invoice_line il ON il.track_id = t.track_id
	GROUP BY al.artist_id, al.album_id, al.title
	ORDER BY al.artist_id
),
ranked_album AS (
SELECT *,
	DENSE_RANK() OVER (
		PARTITION BY artist_id
		ORDER BY quantity DESC) AS rnk
FROM popular_album
)
SELECT ra.artist_id, artist.name, ra.title AS most_popular_album
FROM ranked_album ra
JOIN artist ON artist.artist_id = ra.artist_id
WHERE rnk = 1;

--17. Monthly revenue rank
WITH monthly_revenue AS (
	SELECT EXTRACT(MONTH FROM invoice_date) AS month, SUM(total) AS revenue
	FROM invoice
	GROUP BY month
)
SELECT * , DENSE_RANK() OVER (ORDER BY revenue) AS rnk
FROM monthly_revenue;


--18. Compare employee performance
SELECT e.employee_id, e.first_name,
       COUNT(i.invoice_id) AS total_sales
FROM employee e
JOIN customer c ON c.support_rep_id = CAST(e.employee_id AS INTEGER)
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY e.employee_id, e.first_name;




--19. Detect anomalies in sales
WITH sales AS (
	SELECT invoice_date, total,
		AVG(total) OVER() AS avg_sales,
		STDDEV(total) OVER() AS std_sales
	FROM invoice
)
SELECT * FROM sales
WHERE total > avg_sales + 2*std_sales;



--20. Segment customers using NTILE
WITH customer_revenue AS (
SELECT c.customer_id, c.first_name, c.last_name, SUM(i.total) AS revenue
FROM customer c
JOIN invoice i ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT *, NTILE(5) OVER (ORDER BY revenue) AS customer_grade
FROM customer_revenue;




-- Phase 03: Null handling, Index and Transaction


--1. Handle NULL composer fields in reporting
SELECT track_id, name,
	COALESCE(composer, 'Not known') AS composer
FROM track;


--2. Replace NULL billing info
SELECT  invoice_id , COALESCE(total, 0)  AS total_amount
FROM invoice;


--3. Find incomplete invoices
SELECT * FROM invoice
WHERE customer_id IS NULL
	OR billing_address IS NULL
	OR billing_city IS NULL
	OR billing_postal IS NULL
	OR total IS NULL;



--4. Simulate transaction rollback (payment failure)
BEGIN;

UPDATE invoice
SET total = total - total
WHERE customer_id = 1;

SELECT * FROM invoice WHERE customer_id = 1;

ROLLBACK;

SELECT * FROM invoice WHERE customer_id = 1;



--5. Identify slow queries (index thinking) 
SELECT * FROM customer
WHERE first_name = 'Ashutosh'

EXPLAIN ANALYZE
SELECT * FROM customer
WHERE first_name = 'Ashutosh'

CREATE INDEX idx_first_name ON customer(first_name) 

EXPLAIN ANALYZE
SELECT * FROM customer
WHERE first_name = 'Ashutosh';


--6. Add index on frequently queried column (conceptual)
CREATE INDEX idx_customer_email
ON customer(email);

--7. Detect NULL-heavy columns
SELECT 
	COUNT(*) AS total_rows,
	COUNT(phone) AS non_null_phone,
	COUNT(*) - COUNT(phone) AS null_phone
FROM customer;


--8. Data cleaning pipeline - sequence of cleaning steps
 --Remove duplicates
 DELETE FROM customer
 WHERE customer_id NOT IN (
	SELECT MIN(customer_id)
	FROM customer
	GROUP BY email
 );

 --Handle nulls(example : in customer  phone number)
 UPDATE customer
 SET phone = 'Not available'
 WHERE phone IS NULL;

 --Standardize text(eg: Name of customers)
 UPDATE customer
 SET first_name = INITCAP(first_name);


--9. Ensure atomic invoice insertion(atomic = all or nothing)
BEGIN;

INSERT INTO invoice (
    invoice_id, customer_id, invoice_date, billing_address,
    billing_city, billing_state, billing_country,
    billing_postal, total
)
VALUES (
    909,1, NOW(), 'Patna Street',
    'Patna', 'Bihar', 'India',
    '800001', 500.0
)


INSERT INTO invoice_line (
    invoice_line_id, invoice_id, track_id, unit_price, quantity
)
VALUES (
    909,101, 1, 2.0, 3.0
);

COMMIT;


--10. Fix inconsistent customer data
UPDATE customer
SET email = LOWER(email);

UPDATE customer
SET first_name = TRIM(first_name);


SELECT email, COUNT(*)
FROM customer
GROUP BY email
HAVING COUNT(*) > 1;

UPDATE customer
SET city = 'Unknown'
WHERE city IS NULL;



--Phase 04: Views and Procedures

--1. Create view for customer summary
CREATE VIEW customer_summary AS
SELECT customer_id, first_name, last_name
FROM customer;

SELECT * FROM customer_summary;


--2. View for revenue per country
CREATE VIEW country_revenue AS
SELECT billing_country, SUM(total) AS total_revenue
FROM invoice
GROUP BY billing_country;

SELECT * FROM country_revenue;

--3. Stored procedure: add new customer
CREATE OR REPLACE PROCEDURE 
	add_new_customer(p_customer_id INT,
					p_first_name VARCHAR(50),
					p_last_name VARCHAR(50))
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO customer(customer_id, first_name, last_name)
	VALUES (p_customer_id, p_first_name, p_last_name);
END;
$$;





--4. Procedure: generate invoice
CREATE OR REPLACE PROCEDURE
	generate_invoice(p_invoice_id INT, 
	                  p_customer_id INT,
					  p_invoice_date TIMESTAMP,
					  p_total FLOAT)
LANGUAGE plpgsql
AS $$
BEGIN
	INSERT INTO invoice(invoice_id, customer_id, invoice_date, total)
	VALUES (p_invoice_id, p_customer_id, p_invoice_date, p_total);
END;
$$;

--5. View: top selling tracks
CREATE VIEW top_selling_tracks AS
SELECT t.track_id, t.name, 
	   SUM(il.unit_price * il.quantity) AS revenue
FROM track t
JOIN invoice_line il ON il.track_id = t.track_id
GROUP BY t.track_id , t.name
ORDER BY revenue DESC;

--6. Procedure: customer segmentation
CREATE OR REPLACE PROCEDURE customer_segmentation()
LANGUAGE plpgsql
AS $$
BEGIN
	SELECT c.customer_id,
		   SUM(i.total) AS total_spending,
		   CASE 
				WHEN SUM(i.total) > 5000 THEN 'High Spending'
				ELSE 'Low Spending'
		   END AS customer_segment
	FROM customer c
	JOIN invoice i ON i.customer_id = c.customer_id
	GROUP BY c.customer_id;
END;
$$;
	

--7. View: monthly revenue dashboard
CREATE VIEW monthly_revenue_dashboard AS 
SELECT EXTRACT(YEAR FROM invoice_date) AS year,
	EXTRACT(MONTH FROM invoice_date) AS month,
	SUM(total) AS revenue
FROM invoice
GROUP BY year, month
ORDER BY year, month;


--8. Procedure: update pricing
CREATE OR REPLACE PROCEDURE update_pricing(p_invoice_line_id INT, new_price FLOAT)
LANGUAGE plpgsql
AS $$
BEGIN
	UPDATE invoice_line
	SET unit_price = new_price
	WHERE invoice_line_id = p_invoice_line_id;
END;
$$;

--9. View: artist performance
CREATE VIEW artist_performance AS
SELECT a.artist_id,a.name, SUM(i.total)
FROM artist a
JOIN album al ON al.artist_id = a.artist_id
JOIN track t ON t.album_id = al.album_id
JOIN invoice_line il ON il.track_id = t.track_id
JOIN invoice i ON i.invoice_id = il.invoice_id
GROUP BY a.artist_id, a.name;



--10. Procedure: delete inactive users
CREATE OR REPLACE PROCEDURE delete_inactive_customer() 
LANGUAGE plpgsql 
AS $$
BEGIN 
	WITH last_purchase AS (
		SELECT customer_id, 
			   MAX(invoice_date) AS last_purchase_date
		FROM invoice
		GROUP BY customer_id
	)
	DELETE FROM customer
	WHERE customer_id IN (
		SELECT customer_id 
		FROM last_purchase
		WHERE CURRENT_DATE - last_purchase_date > 365
	);

END;
$$;
