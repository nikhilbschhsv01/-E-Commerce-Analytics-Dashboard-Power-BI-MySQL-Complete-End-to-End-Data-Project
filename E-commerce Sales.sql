CREATE DATABASE E_COMMERCE;
USE E_COMMERCE;
-- CREATING TABLES FOR THE DATA SETS 

		-- CUSTOMERS TABLES 
        
CREATE TABLE customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

		-- ORDERS TABLES 
        
CREATE TABLE orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

		-- ORDERS_ITEMS 

CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);
			
            -- PAYMENTS 
            
CREATE TABLE payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);

		-- REVIEWS 
        
	CREATE TABLE reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);

		-- PRODUCTS 
        
        CREATE TABLE products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(50),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);


		-- SELLER TABLE
 
 CREATE TABLE sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(5)
);


		-- CATEGORY TRANSLATION  TABLE 
        
   CREATE TABLE category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

SELECT *  FROM category_translation  ;
select count(sellers) from e_commerce;

drop table reviews;



-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- data cleaning 


DELETE FROM orders
WHERE order_id IS NULL OR customer_id IS NULL;

SET AUTOCOMMIT=0;
SET SQL_SAFE_UPDATES=0;

-- replace negative prices

UPDATE order_items
SET price = NULL
WHERE price < 0;


-- delivery status

ALTER TABLE orders ADD COLUMN delivery_status VARCHAR(50);

UPDATE orders
SET delivery_status =
    CASE
        WHEN order_delivered_customer_date IS NULL THEN 'Not Delivered'
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        ELSE 'Delayed'
    END;
    
--  delivery status

ALTER TABLE orders ADD COLUMN delivery_days INT;

UPDATE orders
SET delivery_days = DATEDIFF(order_delivered_customer_date, order_purchase_timestamp);

-- delivery delay days status

ALTER TABLE orders ADD COLUMN delay_days INT;

UPDATE orders
SET delay_days = DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date);

-- payment installment classification

ALTER TABLE payments ADD COLUMN installment_type VARCHAR(20);

UPDATE payments
SET installment_type = 
    CASE
        WHEN payment_installments = 1 THEN 'One-Time'
        WHEN payment_installments BETWEEN 2 AND 5 THEN 'EMI Short'
        WHEN payment_installments > 5 THEN 'EMI Long'
    END;
    
    
-- creating a master table

USE E_COMMERCE;



CREATE TABLE master_sales AS
SELECT
    -- Order level
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.delivery_status,
    o.delivery_days,
    o.delay_days,
    
    -- Item level
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    
    -- Payment info
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    p.installment_type,
    
    -- Product info
    pr.product_category_name,
    ct.product_category_name_english,
    pr.product_name_lenght,
    pr.product_description_lenght,
    pr.product_photos_qty,
    pr.product_weight_g,
    pr.product_length_cm,
    pr.product_height_cm,
    pr.product_width_cm,
    
    -- Customer info
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    
    -- Seller info
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state

FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
LEFT JOIN payments p
    ON o.order_id = p.order_id
LEFT JOIN products pr
    ON oi.product_id = pr.product_id
LEFT JOIN category_translation ct
    ON pr.product_category_name = ct.product_category_name
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id;


    
CREATE INDEX idx_ms_order_id       ON master_sales(order_id);
CREATE INDEX idx_ms_order_date     ON master_sales(order_purchase_timestamp);
CREATE INDEX idx_ms_customer_state ON master_sales(customer_state);
CREATE INDEX idx_ms_product_cat    ON master_sales(product_category_name);
CREATE INDEX idx_ms_payment_type   ON master_sales(payment_type);


DROP TABLE IF EXISTS customer_clv;

CREATE TABLE customer_clv AS
SELECT 
    c.customer_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price + oi.freight_value) AS total_revenue,
    ROUND(
        SUM(oi.price + oi.freight_value) 
        / NULLIF(COUNT(DISTINCT o.order_id), 0), 2
    ) AS avg_order_value
FROM customers c
JOIN orders o 
    ON c.customer_id = o.customer_id
JOIN order_items oi 
    ON o.order_id = oi.order_id
GROUP BY c.customer_id;


ALTER TABLE master_sales 
ADD COLUMN customer_total_orders INT,
ADD COLUMN customer_total_revenue DECIMAL(10,2),
ADD COLUMN customer_avg_order_value DECIMAL(10,2);


UPDATE master_sales ms
LEFT JOIN customer_clv clv
ON ms.customer_id = clv.customer_id
SET 
    ms.customer_total_orders = clv.total_orders,
    ms.customer_total_revenue = clv.total_revenue,
    ms.customer_avg_order_value = clv.avg_order_value;

SET AUTOCOMMIT=0;
SET SQL_SAFE_UPDATES=0;


