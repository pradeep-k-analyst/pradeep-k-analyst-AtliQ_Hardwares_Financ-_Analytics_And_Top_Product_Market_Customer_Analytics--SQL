#Top Customers, Products, Markets:

## Module: Problem Statement and Pre-Invoice Discount Report

### Including Pre-Invoice Deductions in Detailed Reports for Croma

#In this query, we include pre-invoice deductions in the detailed sales report for Croma, considering fiscal year 2021.


-- Query to include pre-invoice deductions in the detailed report for Croma
	SELECT 
		s.date, 
		s.product_code, 
		p.product, 
		p.variant, 
		s.sold_quantity, 
		g.gross_price AS gross_price_per_item,
		ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total,
		pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p ON s.product_code=p.product_code
	JOIN fact_gross_price g ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions AS pre ON pre.customer_code = s.customer_code AND pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
		s.customer_code=90002002 AND 
		get_fiscal_year(s.date)=2021     
	LIMIT 1000000;


#Detailed Report for All Customers
#Similarly, we can generate the same detailed sales report, including pre-invoice deductions, for all customers in fiscal year 2021.


-- Query to include pre-invoice deductions in the detailed report for all customers
	SELECT 
		s.date, 
		s.product_code, 
		p.product, 
		p.variant, 
		s.sold_quantity, 
		g.gross_price AS gross_price_per_item,
		ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total,
		pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_product p ON s.product_code=p.product_code
	JOIN fact_gross_price g ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions AS pre ON pre.customer_code = s.customer_code AND pre.fiscal_year=get_fiscal_year(s.date)
	WHERE 
		get_fiscal_year(s.date)=2021     
	LIMIT 1000000;



#Module: Performance Improvement # 1
#Utilizing Dim_Date to Improve Query Performance
#To reduce query execution time, we create a dimension table dim_date and avoid using the get_fiscal_year() function by joining with this table.

-- Improved query using dim_date to avoid using get_fiscal_year() function
	SELECT 
		s.date, 
		s.customer_code,
		s.product_code, 
		p.product, p.variant, 
		s.sold_quantity, 
		g.gross_price AS gross_price_per_item,
		ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total,
		pre.pre_invoice_discount_pct
	FROM fact_sales_monthly s
	JOIN dim_date dt ON dt.calendar_date = s.date
	JOIN dim_product p ON s.product_code=p.product_code
	JOIN fact_gross_price g ON g.fiscal_year=dt.fiscal_year AND g.product_code=s.product_code
	JOIN fact_pre_invoice_deductions AS pre ON pre.customer_code = s.customer_code AND pre.fiscal_year=dt.fiscal_year
	WHERE 
		dt.fiscal_year=2021     
	LIMIT 1500000;



#Module: Database Views: Introduction
#Utilizing Common Table Expressions (CTEs) to Calculate Net Invoice Sales
#In this query, we use a Common Table Expression (CTE) to calculate the net_invoice_sales amount by subtracting pre-invoice discount percentages from gross price totals.



-- Query using CTEs to calculate net_invoice_sales
	WITH cte1 AS (
		SELECT 
			s.date, 
			s.customer_code,
			s.product_code, 
			p.product, p.variant, 
			s.sold_quantity, 
			g.gross_price AS gross_price_per_item,
			ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total,
			pre.pre_invoice_discount_pct
		FROM fact_sales_monthly s
		JOIN dim_product p ON s.product_code=p.product_code
		JOIN fact_gross_price g ON g.fiscal_year=s.fiscal_year AND g.product_code=s.product_code
		JOIN fact_pre_invoice_deductions AS pre ON pre.customer_code = s.customer_code AND pre.fiscal_year=s.fiscal_year
		WHERE 
			s.fiscal_year=2021) 
	SELECT 
		*, 
		(gross_price_total-pre_invoice_discount_pct*gross_price_total) AS net_invoice_sales
	FROM cte1
	LIMIT 1500000;



#Creating a View for Sales Pre-Invoice Discount
#We create a view named sales_preinv_discount to store the data from the above query as a virtual table.

-- Creating a view for sales pre-invoice discount
		CREATE VIEW `sales_preinv_discount` AS
		SELECT 
			s.date, 
			s.fiscal_year,
			s.customer_code,
			c.market,
			s.product_code, 
			p.product, 
			p.variant, 
			s.sold_quantity, 
			g.gross_price AS gross_price_per_item,
			ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total,
			pre.pre_invoice_discount_pct
		FROM fact_sales_monthly s
		JOIN dim_customer c ON s.customer_code = c.customer_code
		JOIN dim_product p ON s.product_code=p.product_code
		JOIN fact_gross_price g ON g.fiscal_year=s.fiscal_year AND g.product_code=s.product_code
		JOIN fact_pre_invoice_deductions AS pre ON pre.customer_code = s.customer_code AND pre.fiscal_year=s.fiscal_year;




#Module: Database Views: Post-Invoice Discount, Net Sales
#Creating a View for Post-Invoice Deductions
#We create a view named sales_postinv_discount to include post-invoice deductions and calculate net sales.



-- Creating a view for post-invoice deductions and calculating net sales
	CREATE VIEW `sales_postinv_discount` AS
	SELECT 
		s.date, s.fiscal_year,
		s.customer_code, s.market,
		s.product_code, s.product, s.variant,
		s.sold_quantity, s.gross_price_total,
		s.pre_invoice_discount_pct,
		(s.gross_price_total-s.pre_invoice_discount_pct*s.gross_price_total) AS net_invoice_sales,
		(po.discounts_pct+po.other_deductions_pct) AS post_invoice_discount_pct
	FROM sales_preinv_discount s
	JOIN fact_post_invoice_deductions po ON po.customer_code = s.customer_code AND po.product_code = s.product_code AND po.date = s.date;



#Creating a Final View for Net Sales
#Finally, we create a view named net_sales which encapsulates all previous views and provides the final net sales report.


-- Creating a final view for net sales
	CREATE VIEW `net_sales` AS
	SELECT 
		*, 
		net_invoice_sales*(1-post_invoice_discount_pct) AS net_sales
	FROM gdb0041.sales_postinv_discount;



#Module: Top Markets and Customers
#Top 5 Markets by Net Sales
#This query retrieves the top 5 markets by net sales in fiscal year 2021.



-- Query to retrieve top 5 markets by net sales in fiscal year 2021
	SELECT 
		market, 
		ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
	FROM gdb0041.net_sales
	WHERE fiscal_year=2021
	GROUP BY market
	ORDER BY net_sales_mln DESC
	LIMIT 5;



#Stored Procedure to Get Top N Markets by Net Sales
#We create a stored procedure get_top_n_markets_by_net_sales to get the top N markets by net sales for a given year.



-- Stored procedure to get top N markets by net sales for a given year
	CREATE PROCEDURE `get_top_n_markets_by_net_sales`(
		in_fiscal_year INT,
		in_top_n INT
	)
	BEGIN
		SELECT 
			market, 
			ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
		FROM net_sales
		WHERE fiscal_year=in_fiscal_year
		GROUP BY market
		ORDER BY net_sales_mln DESC
		LIMIT in_top_n;
	END


#Stored Procedure to Get Top N Customers by Net Sales
#Similarly, we create a stored procedure get_top_n_customers_by_net_sales to get the top N customers by net sales for a given fiscal year and market.


-- Stored procedure to get top N customers by net sales for a given fiscal year and market
	CREATE PROCEDURE `get_top_n_customers_by_net_sales`(
		in_market VARCHAR(45),
		in_fiscal_year INT,
		in_top_n INT
	)
	BEGIN
		SELECT 
			customer, 
			ROUND(SUM(net_sales)/1000000,2) AS net_sales_mln
		FROM net_sales s
		JOIN dim_customer c ON s.customer_code=c.customer_code
		WHERE 
			s.fiscal_year=in_fiscal_year 
			AND s.market=in_market
		GROUP BY customer
		ORDER BY net_sales_mln DESC
		LIMIT in_top_n;
	END



#Module: Window Functions: OVER Clause
#Percentage of Total Expense
#This query calculates the percentage of total expenses for each category.


-- Query to calculate percentage of total expense for each category
	SELECT 
		*,
		amount*100/SUM(amount) OVER() AS pct
	FROM random_tables.expenses 
	ORDER BY category;

#Percentage of Total Expense per Category
#Similarly, this query calculates the percentage of total expenses for each category individually.



-- Query to calculate percentage of total expense per category
	SELECT 
		*,
		amount*100/SUM(amount) OVER(PARTITION BY category) AS pct
	FROM random_tables.expenses 
	ORDER BY category, pct DESC;



#Module: Window Functions: ROW_NUMBER, RANK, DENSE_RANK
#Top Expenses in Each Category
#This query retrieves the top 2 expenses in each category using the ROW_NUMBER function.


-- Query to retrieve top 2 expenses in each category
	SELECT * FROM 
		(SELECT 
			*, 
			ROW_NUMBER() OVER (PARTITION BY category ORDER BY amount DESC) AS row_num
		FROM random_tables.expenses) x
	WHERE x.row_num < 3;


#Rank and Dense Rank in Student Marks
#This query demonstrates the differences between ROW_NUMBER, RANK, and DENSE_RANK functions using student marks.


-- Query demonstrating ROW_NUMBER, RANK, and DENSE_RANK functions
	SELECT 
		*,
		ROW_NUMBER() OVER (ORDER BY marks DESC) AS row_num,
		RANK() OVER (ORDER BY marks DESC) AS rank_num,
		DENSE_RANK() OVER (ORDER BY marks DESC) AS dense_rank_num
	FROM random_tables.student_marks;


#Top Products in Each Division by Quantity Sold
#This query retrieves the top 3 products from each division by total quantity sold.


-- Query to retrieve top 3 products from each division by quantity sold
	WITH cte1 AS 
		(SELECT
			p.division,
			p.product,
			SUM(sold_quantity) AS total_qty
		FROM fact_sales_monthly s
		JOIN dim_product p ON p.product_code=s.product_code
		WHERE fiscal_year=2021
		GROUP BY p.product),
		cte2 AS 
		(SELECT 
			*,
			DENSE_RANK() OVER (PARTITION BY division ORDER BY total_qty DESC) AS drnk
		FROM cte1)
	SELECT * FROM cte2 WHERE drnk <= 3;


#Stored Procedure for Top N Products per Division by Quantity Sold
#We create a stored procedure get_top_n_products_per_division_by_qty_sold for the above query.




-- Stored procedure for retrieving top N products per division by quantity sold
	CREATE PROCEDURE `get_top_n_products_per_division_by_qty_sold`(
		in_fiscal_year INT,
		in_top_n INT
	)
	BEGIN
		WITH cte1 AS (
			SELECT
				p.division,
				p.product,
				SUM(sold_quantity) AS total_qty
			FROM fact_sales_monthly s
			JOIN dim_product p ON p.product_code=s.product_code
			WHERE fiscal_year=in_fiscal_year
			GROUP BY p.product),
			cte2 AS (
			SELECT 
				*,
				DENSE_RANK() OVER (PARTITION BY division ORDER BY total_qty DESC) AS drnk
			FROM cte1)
		SELECT * FROM cte2 WHERE drnk <= in_top_n;
	END




#This report provides a detailed overview of various SQL operations and techniques applied to analyze sales data, including incorporating discounts, optimizing performance, creating views, and utilizing window functions. Let me know if you need further details or assistance!
