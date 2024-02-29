# SQL Advanced: Finance Analytics

## Module: User-Defined SQL Functions

### a. Retrieve Customer Codes for Croma India


-- query retrieves customer codes for Croma in India by querying the `dim_customer` table for records containing "croma" in the customer name and belonging to the "india" market.
	SELECT * FROM dim_customer WHERE customer LIKE "%croma%" AND market="india";	


#b. Get Sales Transaction Data for Croma (Customer Code: 90002002) in Fiscal Year 2021


-- query fetches all sales transaction data from the fact_sales_monthly table for the Croma customer with code 90002002 in the fiscal year 2021. It retrieves data ordered by date in ascending order with a limit of 100,000 records.
	SELECT * FROM fact_sales_monthly 
	WHERE 
		customer_code=90002002 AND
		YEAR(DATE_ADD(date, INTERVAL 4 MONTH))=2021 
	ORDER BY date ASC
	LIMIT 100000;


#c. Create a Function 'get_fiscal_year' to Retrieve Fiscal Year by Passing the Date


-- script creates a user-defined function named get_fiscal_year that accepts a calendar date as input and returns the fiscal year. It adds 4 months to the input date and extracts the year.
	CREATE FUNCTION `get_fiscal_year`(calendar_date DATE) 
	RETURNS INT
	DETERMINISTIC
	BEGIN
		DECLARE fiscal_year INT;
		SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));
		RETURN fiscal_year;
	END


#d. Replacing the Function Created in Step b


-- query replaces the direct comparison of fiscal years with the function get_fiscal_year(date) created in step c. It filters sales transaction data for the Croma customer in the fiscal year 2021.
	SELECT * FROM fact_sales_monthly 
	WHERE 
		customer_code=90002002 AND
		get_fiscal_year(date)=2021 
	ORDER BY date ASC
	LIMIT 100000;


#Module: Gross Sales Report: Monthly Product Transactions

#a. Retrieve Product Information with Joins 


-- query joins the fact_sales_monthly and dim_product tables to retrieve product information for sales transactions of the Croma customer in the fiscal year 2021.
	SELECT s.date, s.product_code, p.product, p.variant, s.sold_quantity 
	FROM fact_sales_monthly s
	JOIN dim_product p
	ON s.product_code=p.product_code
	WHERE 
		customer_code=90002002 AND 
		get_fiscal_year(date)=2021     
	LIMIT 1000000;


#b. Joining with 'fact_gross_price' Table and Generating Required Fields


-- query further joins the fact_gross_price table with the previous query and calculates the total gross price for each product transaction.
	SELECT 
		s.date, 
		s.product_code, 
		p.product, 
		p.variant, 
		s.sold_quantity, 
		g.gross_price,
		ROUND(s.sold_quantity*g.gross_price,2) AS gross_price_total
	FROM fact_sales_monthly s
	JOIN dim_product p
	ON s.product_code=p.product_code
	JOIN fact_gross_price g
	ON g.fiscal_year=get_fiscal_year(s.date)
	AND g.product_code=s.product_code
	WHERE 
		customer_code=90002002 AND 
		get_fiscal_year(s.date)=2021     
	LIMIT 1000000;


#Module: Gross Sales Report: Total Sales Amount

#Generate Monthly Gross Sales Report for Croma India for All Years


-- query generates a monthly gross sales report for the Croma customer in India for all years, aggregating the total sales amount for each month.
SELECT 
    s.date, 
    SUM(ROUND(s.sold_quantity*g.gross_price,2)) AS monthly_sales
FROM fact_sales_monthly s
JOIN fact_gross_price g
ON g.fiscal_year=get_fiscal_year(s.date) AND g.product_code=s.product_code
WHERE 
    customer_code=90002002
GROUP BY date;


#Module: Stored Procedures: Monthly Gross Sales Report

#Generate Monthly Gross Sales Report for Any Customer Using Stored Procedure


-- stored procedure get_monthly_gross_sales_for_customer generates a monthly gross sales report for any customer by accepting customer codes as input.
	CREATE PROCEDURE `get_monthly_gross_sales_for_customer`(
        	in_customer_codes TEXT
	)
	BEGIN
        	SELECT 
                    s.date, 
                    SUM(ROUND(s.sold_quantity*g.gross_price,2)) as monthly_sales
        	FROM fact_sales_monthly s
        	JOIN fact_gross_price g
               	    ON g.fiscal_year=get_fiscal_year(s.date)
                    AND g.product_code=s.product_code
        	WHERE 
                    FIND_IN_SET(s.customer_code, in_customer_codes) > 0
        	GROUP BY s.date
        	ORDER BY s.date DESC;
	END



#Module: Stored Procedure: Market Badge

#Write a Stored Procedure to Retrieve Market Badge


-- stored procedure get_market_badge retrieves the market badge (Gold or Silver) based on the total sold quantity for a given market and fiscal year.
### Module: Stored Procedure: Market Badge

	CREATE PROCEDURE `get_market_badge`(
        	IN in_market VARCHAR(45),
        	IN in_fiscal_year YEAR,
        	OUT out_level VARCHAR(45)
	)
	BEGIN
             DECLARE qty INT DEFAULT 0;
    
    	     # Default market is India
    	     IF in_market = "" THEN
                  SET in_market="India";
             END IF;
    
    	     # Retrieve total sold quantity for a given market in a given year
             SELECT 
                  SUM(s.sold_quantity) INTO qty
             FROM fact_sales_monthly s
             JOIN dim_customer c
             ON s.customer_code=c.customer_code
             WHERE 
                  get_fiscal_year(s.date)=in_fiscal_year AND
                  c.market=in_market;
        
             # Determine Gold vs Silver status
             IF qty > 5000000 THEN
                  SET out_level = 'Gold';
             ELSE
                  SET out_level = 'Silver';
             END IF;
	END


# Yearly Gross Sales Report for Croma India


-- query presents the yearly gross sales amounts for Croma India.
	SELECT
		get_fiscal_year(date) AS Fiscal_Year,
		SUM(ROUND(s.sold_quantity * g.gross_price, 2)) AS Total_Gross_Sales_Amount
	FROM
		fact_sales_monthly s
	JOIN
		fact_gross_price g ON g.fiscal_year = get_fiscal_year(s.date)
		AND g.product_code = s.product_code
	WHERE
		customer_code = 90002002
	GROUP BY
		get_fiscal_year(date)
	ORDER BY
		Fiscal_Year;



#This report provides a detailed explanation of each SQL step and its purpose within the project. Let me know if you need further assistance!

