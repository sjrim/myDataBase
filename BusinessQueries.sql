-- ============================================================================
-- Business Queries with Execution Plan Analysis
-- Week 3: Access Structures Determination
-- ============================================================================

USE [2025DBFall_Group_5_DB];
GO

-- ============================================================================
-- BQ01: Monthly Sales Performance by Product Category (READ)
-- User Type: Sales Manager
-- Derived Attributes: Discount_Rate = (List_Price - (Amount_Sold/Quantity_Sold)) * 100 / List_Price
-- ============================================================================

-- Query to generate execution plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- BQ01: Version 1 - Basic query with subquery
SELECT
    p.PROD_CATEGORY,
    YEAR(s.SALE_DATE) AS Sale_Year,
    MONTH(s.SALE_DATE) AS Sale_Month,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,
    AVG((p.PROD_LIST_PRICE - (s.AMOUNT_SOLD / s.QUANTITY_SOLD)) * 100.0 / p.PROD_LIST_PRICE) AS Avg_Discount_Rate,

    -- Previous month comparison
    LAG(SUM(s.AMOUNT_SOLD)) OVER (
        PARTITION BY p.PROD_CATEGORY
        ORDER BY YEAR(s.SALE_DATE), MONTH(s.SALE_DATE)
    ) AS Previous_Month_Revenue,

    -- Revenue change percentage
    CASE
        WHEN LAG(SUM(s.AMOUNT_SOLD)) OVER (
            PARTITION BY p.PROD_CATEGORY
            ORDER BY YEAR(s.SALE_DATE), MONTH(s.SALE_DATE)
        ) IS NOT NULL THEN
            ((SUM(s.AMOUNT_SOLD) - LAG(SUM(s.AMOUNT_SOLD)) OVER (
                PARTITION BY p.PROD_CATEGORY
                ORDER BY YEAR(s.SALE_DATE), MONTH(s.SALE_DATE)
            )) * 100.0 / LAG(SUM(s.AMOUNT_SOLD)) OVER (
                PARTITION BY p.PROD_CATEGORY
                ORDER BY YEAR(s.SALE_DATE), MONTH(s.SALE_DATE)
            ))
        ELSE NULL
    END AS Revenue_Change_Pct
FROM SALES s
INNER JOIN LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
WHERE s.SALE_DATE >= DATEADD(MONTH, -2, GETDATE())  -- Last 2 months for comparison
GROUP BY
    p.PROD_CATEGORY,
    YEAR(s.SALE_DATE),
    MONTH(s.SALE_DATE)
ORDER BY
    p.PROD_CATEGORY,
    Sale_Year DESC,
    Sale_Month DESC;
GO

-- ============================================================================
-- BQ02: Customer Purchase Analysis with Shipping Efficiency (READ)
-- User Type: Sales Manager
-- Derived Attributes: Days_To_Ship = Shipping_Date – Sale_Date; Days_To_Pay = Payment_Date – Sale_Date
-- ============================================================================

-- BQ02: Top 20 Customers by Revenue
SELECT TOP 20
    c.CUST_ID,
    c.CUST_FIRST_NAME + ' ' + c.CUST_LAST_NAME AS Customer_Name,
    c.CUST_EMAIL,
    c.CUST_CREDIT_LIMIT,
    COUNT(DISTINCT s.SALE_ID) AS Total_Transactions,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    AVG(s.AMOUNT_SOLD) AS Avg_Transaction_Value,
    AVG(DATEDIFF(DAY, s.SALE_DATE, s.SHIPPING_DATE)) AS Avg_Days_To_Ship,
    AVG(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE)) AS Avg_Days_To_Pay,

    -- Payment behavior classification
    CASE
        WHEN AVG(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE)) <= 30 THEN 'Excellent'
        WHEN AVG(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE)) <= 60 THEN 'Good'
        WHEN AVG(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE)) <= 90 THEN 'Fair'
        ELSE 'Poor'
    END AS Payment_Behavior
FROM CUSTOMER c
INNER JOIN SALES s ON c.CUST_ID = s.CUST_ID
WHERE s.PAYMENT_DATE IS NOT NULL
  AND s.SHIPPING_DATE IS NOT NULL
GROUP BY
    c.CUST_ID,
    c.CUST_FIRST_NAME,
    c.CUST_LAST_NAME,
    c.CUST_EMAIL,
    c.CUST_CREDIT_LIMIT
ORDER BY
    Total_Revenue DESC;
GO

-- ============================================================================
-- BQ03: Channel Performance with Discount Analysis (READ)
-- User Type: Sales Manager
-- Derived Attributes: Discount = List_Price - (Amount_Sold/Quantity_Sold)
-- ============================================================================

-- BQ03: Channel Performance Summary
SELECT
    ch.CHANNEL_ID,
    ch.CHANNELS_DESC,
    ch.CHANNEL_CLASS,
    COUNT(DISTINCT s.SALE_ID) AS Transaction_Count,
    COUNT(DISTINCT s.CUST_ID) AS Unique_Customers,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    AVG(s.AMOUNT_SOLD) AS Avg_Transaction_Value,
    SUM(s.QUANTITY_SOLD) AS Total_Units_Sold,
    AVG(p.PROD_LIST_PRICE - (s.AMOUNT_SOLD / s.QUANTITY_SOLD)) AS Avg_Discount_Amount,
    AVG((p.PROD_LIST_PRICE - (s.AMOUNT_SOLD / s.QUANTITY_SOLD)) * 100.0 / p.PROD_LIST_PRICE) AS Avg_Discount_Rate,

    -- Revenue contribution percentage
    SUM(s.AMOUNT_SOLD) * 100.0 / (SELECT SUM(AMOUNT_SOLD) FROM SALES) AS Revenue_Contribution_Pct
FROM LL_CHANNELS ch
INNER JOIN SALES s ON ch.CHANNEL_ID = s.CHANNEL_ID
INNER JOIN LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
GROUP BY
    ch.CHANNEL_ID,
    ch.CHANNELS_DESC,
    ch.CHANNEL_CLASS
ORDER BY
    Total_Revenue DESC;
GO

-- ============================================================================
-- BQ05: Revenue Recognition Report by Period (READ)
-- User Type: Accounting/Finance Staff
-- Derived Attributes: Days_To_Pay = Payment_Date – Sale_Date
-- ============================================================================

-- BQ05: Revenue Recognition for Accounting Period
-- Example: Last quarter or specific month
DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2024-03-31';

SELECT
    s.SALE_ID,
    s.SALE_DATE,
    s.PAYMENT_DATE,
    s.SHIPPING_DATE,
    DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) AS Days_To_Pay,
    c.CUST_ID,
    c.CUST_FIRST_NAME + ' ' + c.CUST_LAST_NAME AS Customer_Name,
    p.PROD_ID,
    p.PROD_NAME,
    p.PROD_CATEGORY,
    s.QUANTITY_SOLD,
    p.PROD_LIST_PRICE,
    s.AMOUNT_SOLD,
    (p.PROD_LIST_PRICE * s.QUANTITY_SOLD) - s.AMOUNT_SOLD AS Total_Discount_Amount,
    ch.CHANNELS_DESC AS Sales_Channel
FROM SALES s
INNER JOIN CUSTOMER c ON s.CUST_ID = c.CUST_ID
INNER JOIN LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
INNER JOIN LL_CHANNELS ch ON s.CHANNEL_ID = ch.CHANNEL_ID
WHERE s.SALE_DATE BETWEEN @StartDate AND @EndDate
ORDER BY
    s.SALE_DATE,
    c.CUST_ID,
    p.PROD_CATEGORY;
GO

-- ============================================================================
-- BQ06: Accounts Receivable Aging Analysis (READ)
-- User Type: Accounting/Finance Staff
-- Derived Attributes: Days_To_Pay = Payment_Date – Sale_Date
-- ============================================================================

-- BQ06: AR Aging Buckets
SELECT
    CASE
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 30 THEN '0-30 Days (Current)'
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 60 THEN '31-60 Days'
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 90 THEN '61-90 Days'
        ELSE '90+ Days (Overdue)'
    END AS Aging_Bucket,

    COUNT(DISTINCT s.SALE_ID) AS Transaction_Count,
    COUNT(DISTINCT s.CUST_ID) AS Customer_Count,
    SUM(s.AMOUNT_SOLD) AS Total_Amount,
    AVG(DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE()))) AS Avg_Days_Outstanding,
    MIN(s.SALE_DATE) AS Oldest_Sale_Date,
    MAX(s.SALE_DATE) AS Newest_Sale_Date
FROM SALES s
WHERE s.PAYMENT_DATE IS NULL  -- Outstanding payments
   OR DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) > 0  -- Payments that took time
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 30 THEN '0-30 Days (Current)'
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 60 THEN '31-60 Days'
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 90 THEN '61-90 Days'
        ELSE '90+ Days (Overdue)'
    END
ORDER BY
    CASE
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 30 THEN 1
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 60 THEN 2
        WHEN DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) <= 90 THEN 3
        ELSE 4
    END;
GO

-- Detail view for AR aging
SELECT
    s.SALE_ID,
    s.SALE_DATE,
    s.PAYMENT_DATE,
    DATEDIFF(DAY, s.SALE_DATE, COALESCE(s.PAYMENT_DATE, GETDATE())) AS Days_Outstanding,
    c.CUST_ID,
    c.CUST_FIRST_NAME + ' ' + c.CUST_LAST_NAME AS Customer_Name,
    c.CUST_EMAIL,
    c.CUST_CREDIT_LIMIT,
    s.AMOUNT_SOLD,
    CASE
        WHEN s.PAYMENT_DATE IS NULL THEN 'UNPAID'
        ELSE 'PAID'
    END AS Payment_Status
FROM SALES s
INNER JOIN CUSTOMER c ON s.CUST_ID = c.CUST_ID
WHERE s.PAYMENT_DATE IS NULL
   OR DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) > 30
ORDER BY
    Days_Outstanding DESC,
    s.AMOUNT_SOLD DESC;
GO

-- ============================================================================
-- BQ07: Discount and Margin Analysis (READ)
-- User Type: Accounting/Finance Staff
-- Derived Attributes:
--   Actual_Price = Amount_Sold/Quantity_Sold
--   Discount = List_Price - Actual_Price
--   Discount_Rate = (Discount * 100) / List_Price
-- ============================================================================

-- BQ07: Discount and Margin Analysis by Product and Promotion
SELECT
    p.PROD_ID,
    p.PROD_NAME,
    p.PROD_CATEGORY,
    pr.PROMO_NAME,
    pr.PROMO_CATEGORY,
    COUNT(s.SALE_ID) AS Transaction_Count,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,

    -- Pricing metrics
    p.PROD_LIST_PRICE,
    AVG(s.AMOUNT_SOLD / s.QUANTITY_SOLD) AS Avg_Actual_Price,
    AVG(p.PROD_LIST_PRICE - (s.AMOUNT_SOLD / s.QUANTITY_SOLD)) AS Avg_Discount,
    AVG((p.PROD_LIST_PRICE - (s.AMOUNT_SOLD / s.QUANTITY_SOLD)) * 100.0 / p.PROD_LIST_PRICE) AS Avg_Discount_Rate,

    -- Revenue metrics
    SUM(s.AMOUNT_SOLD) AS Actual_Revenue,
    SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) AS Potential_Revenue_At_List,
    SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) - SUM(s.AMOUNT_SOLD) AS Total_Discount_Given,

    -- Margin impact
    (SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) - SUM(s.AMOUNT_SOLD)) * 100.0 /
        SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) AS Discount_Impact_Pct
FROM SALES s
INNER JOIN LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
INNER JOIN LL_PROMOTION pr ON s.PROMO_ID = pr.PROMO_ID
GROUP BY
    p.PROD_ID,
    p.PROD_NAME,
    p.PROD_CATEGORY,
    p.PROD_LIST_PRICE,
    pr.PROMO_NAME,
    pr.PROMO_CATEGORY
HAVING
    COUNT(s.SALE_ID) >= 5  -- Only products with meaningful transaction volume
ORDER BY
    Total_Discount_Given DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
