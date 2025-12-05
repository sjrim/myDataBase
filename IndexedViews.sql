-- ============================================================================
-- Indexed Views (Materialized Views) for Performance Optimization
-- Week 3: Access Structures Determination
-- ============================================================================

USE [2025DBFall_Group_5_DB];
GO

-- ============================================================================
-- Indexed View 1: Monthly Sales Summary by Product Category
-- Purpose: Optimize BQ01 (Monthly Sales Performance)
-- Benefit: Pre-aggregates sales data by category and month for fast reporting
-- ============================================================================

CREATE OR ALTER VIEW vw_MonthlySalesByCategory
WITH SCHEMABINDING
AS
SELECT
    p.PROD_CATEGORY,
    YEAR(s.SALE_DATE) AS Sale_Year,
    MONTH(s.SALE_DATE) AS Sale_Month,
    COUNT_BIG(*) AS Transaction_Count,  -- Required for indexed view
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,
    SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) AS Potential_Revenue,
    SUM((p.PROD_LIST_PRICE * s.QUANTITY_SOLD) - s.AMOUNT_SOLD) AS Total_Discount_Given
FROM dbo.SALES s
INNER JOIN dbo.LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
GROUP BY
    p.PROD_CATEGORY,
    YEAR(s.SALE_DATE),
    MONTH(s.SALE_DATE);
GO

-- Create unique clustered index to materialize the view
CREATE UNIQUE CLUSTERED INDEX IX_vw_MonthlySalesByCategory
    ON vw_MonthlySalesByCategory(PROD_CATEGORY, Sale_Year, Sale_Month);
GO

-- Create additional non-clustered index for date-based queries
CREATE NONCLUSTERED INDEX IX_vw_MonthlySalesByCategory_Date
    ON vw_MonthlySalesByCategory(Sale_Year, Sale_Month)
    INCLUDE (PROD_CATEGORY, Total_Revenue, Total_Quantity);
GO

-- ============================================================================
-- Indexed View 2: Customer Purchase Summary
-- Purpose: Optimize BQ02 (Customer Purchase Analysis)
-- Benefit: Pre-aggregates customer metrics for fast top-N queries
-- ============================================================================

CREATE OR ALTER VIEW vw_CustomerPurchaseSummary
WITH SCHEMABINDING
AS
SELECT
    c.CUST_ID,
    COUNT_BIG(*) AS Total_Transactions,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,
    SUM(CASE WHEN s.SHIPPING_DATE IS NOT NULL
        THEN DATEDIFF(DAY, s.SALE_DATE, s.SHIPPING_DATE) ELSE 0 END) AS Total_Days_To_Ship,
    SUM(CASE WHEN s.PAYMENT_DATE IS NOT NULL
        THEN DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) ELSE 0 END) AS Total_Days_To_Pay,
    SUM(CASE WHEN s.SHIPPING_DATE IS NOT NULL THEN 1 ELSE 0 END) AS Shipped_Count,
    SUM(CASE WHEN s.PAYMENT_DATE IS NOT NULL THEN 1 ELSE 0 END) AS Paid_Count,
    SUM(CASE WHEN s.PAYMENT_DATE IS NOT NULL
             AND DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) <= 30
        THEN 1 ELSE 0 END) AS OnTime_Payment_Count
FROM dbo.CUSTOMER c
INNER JOIN dbo.SALES s ON c.CUST_ID = s.CUST_ID
GROUP BY c.CUST_ID;
GO

-- Create unique clustered index
CREATE UNIQUE CLUSTERED INDEX IX_vw_CustomerPurchaseSummary
    ON vw_CustomerPurchaseSummary(CUST_ID);
GO

-- Create non-clustered index for revenue-based sorting
CREATE NONCLUSTERED INDEX IX_vw_CustomerPurchaseSummary_Revenue
    ON vw_CustomerPurchaseSummary(Total_Revenue DESC)
    INCLUDE (CUST_ID, Total_Transactions, Total_Days_To_Pay, Paid_Count);
GO

-- ============================================================================
-- Indexed View 3: Channel Performance Summary
-- Purpose: Optimize BQ03 (Channel Performance with Discount Analysis)
-- Benefit: Pre-aggregates channel metrics
-- ============================================================================

CREATE OR ALTER VIEW vw_ChannelPerformanceSummary
WITH SCHEMABINDING
AS
SELECT
    ch.CHANNEL_ID,
    COUNT_BIG(*) AS Transaction_Count,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,
    SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) AS Potential_Revenue,
    COUNT(DISTINCT s.CUST_ID) AS Unique_Customer_Count
FROM dbo.LL_CHANNELS ch
INNER JOIN dbo.SALES s ON ch.CHANNEL_ID = s.CHANNEL_ID
INNER JOIN dbo.LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
GROUP BY ch.CHANNEL_ID;
GO

-- Create unique clustered index
CREATE UNIQUE CLUSTERED INDEX IX_vw_ChannelPerformanceSummary
    ON vw_ChannelPerformanceSummary(CHANNEL_ID);
GO

-- ============================================================================
-- Indexed View 4: Product Discount Analysis
-- Purpose: Optimize BQ07 (Discount and Margin Analysis)
-- Benefit: Pre-aggregates discount metrics by product and promotion
-- ============================================================================

CREATE OR ALTER VIEW vw_ProductDiscountAnalysis
WITH SCHEMABINDING
AS
SELECT
    p.PROD_ID,
    pr.PROMO_ID,
    COUNT_BIG(*) AS Transaction_Count,
    SUM(s.QUANTITY_SOLD) AS Total_Quantity,
    SUM(s.AMOUNT_SOLD) AS Actual_Revenue,
    SUM(p.PROD_LIST_PRICE * s.QUANTITY_SOLD) AS Potential_Revenue,
    SUM((p.PROD_LIST_PRICE * s.QUANTITY_SOLD) - s.AMOUNT_SOLD) AS Total_Discount
FROM dbo.SALES s
INNER JOIN dbo.LL_PRODUCT p ON s.PROD_ID = p.PROD_ID
INNER JOIN dbo.LL_PROMOTION pr ON s.PROMO_ID = pr.PROMO_ID
GROUP BY p.PROD_ID, pr.PROMO_ID;
GO

-- Create unique clustered index
CREATE UNIQUE CLUSTERED INDEX IX_vw_ProductDiscountAnalysis
    ON vw_ProductDiscountAnalysis(PROD_ID, PROMO_ID);
GO

-- Create non-clustered index for discount analysis
CREATE NONCLUSTERED INDEX IX_vw_ProductDiscountAnalysis_Discount
    ON vw_ProductDiscountAnalysis(Total_Discount DESC)
    INCLUDE (PROD_ID, PROMO_ID, Actual_Revenue, Potential_Revenue);
GO

-- ============================================================================
-- Usage Examples: How to Query Indexed Views
-- ============================================================================

-- Example 1: Use indexed view for BQ01 - Monthly sales performance
SELECT
    PROD_CATEGORY,
    Sale_Year,
    Sale_Month,
    Total_Revenue,
    Total_Quantity,
    Total_Discount_Given * 100.0 / Potential_Revenue AS Avg_Discount_Rate,
    LAG(Total_Revenue) OVER (
        PARTITION BY PROD_CATEGORY
        ORDER BY Sale_Year, Sale_Month
    ) AS Previous_Month_Revenue
FROM vw_MonthlySalesByCategory
WHERE Sale_Year = 2024
ORDER BY PROD_CATEGORY, Sale_Year DESC, Sale_Month DESC;
GO

-- Example 2: Use indexed view for BQ02 - Top customers
SELECT TOP 20
    c.CUST_ID,
    c.CUST_FIRST_NAME + ' ' + c.CUST_LAST_NAME AS Customer_Name,
    v.Total_Revenue,
    v.Total_Transactions,
    CASE WHEN v.Shipped_Count > 0
        THEN v.Total_Days_To_Ship * 1.0 / v.Shipped_Count
        ELSE NULL END AS Avg_Days_To_Ship,
    CASE WHEN v.Paid_Count > 0
        THEN v.Total_Days_To_Pay * 1.0 / v.Paid_Count
        ELSE NULL END AS Avg_Days_To_Pay,
    CASE WHEN v.Paid_Count > 0
        THEN v.OnTime_Payment_Count * 100.0 / v.Paid_Count
        ELSE NULL END AS OnTime_Payment_Pct
FROM vw_CustomerPurchaseSummary v
INNER JOIN CUSTOMER c ON v.CUST_ID = c.CUST_ID
ORDER BY v.Total_Revenue DESC;
GO

-- Example 3: Use indexed view for BQ03 - Channel performance
SELECT
    ch.CHANNEL_ID,
    ch.CHANNELS_DESC,
    ch.CHANNEL_CLASS,
    v.Transaction_Count,
    v.Total_Revenue,
    v.Unique_Customer_Count,
    (v.Potential_Revenue - v.Total_Revenue) AS Total_Discount_Given,
    (v.Potential_Revenue - v.Total_Revenue) * 100.0 / v.Potential_Revenue AS Avg_Discount_Rate
FROM vw_ChannelPerformanceSummary v
INNER JOIN LL_CHANNELS ch ON v.CHANNEL_ID = ch.CHANNEL_ID
ORDER BY v.Total_Revenue DESC;
GO

-- Example 4: Use indexed view for BQ07 - Discount analysis
SELECT
    p.PROD_NAME,
    p.PROD_CATEGORY,
    pr.PROMO_NAME,
    v.Transaction_Count,
    v.Total_Quantity,
    v.Actual_Revenue,
    v.Potential_Revenue,
    v.Total_Discount,
    v.Total_Discount * 100.0 / v.Potential_Revenue AS Discount_Impact_Pct
FROM vw_ProductDiscountAnalysis v
INNER JOIN LL_PRODUCT p ON v.PROD_ID = p.PROD_ID
INNER JOIN LL_PROMOTION pr ON v.PROMO_ID = pr.PROMO_ID
WHERE v.Transaction_Count >= 5
ORDER BY v.Total_Discount DESC;
GO

-- ============================================================================
-- Maintenance: Indexed View Statistics
-- ============================================================================

-- Check indexed view statistics
SELECT
    OBJECT_NAME(i.object_id) AS View_Name,
    i.name AS Index_Name,
    i.type_desc AS Index_Type,
    ps.row_count AS Row_Count,
    ps.reserved_page_count * 8 / 1024.0 AS Reserved_MB,
    ps.used_page_count * 8 / 1024.0 AS Used_MB
FROM sys.indexes i
INNER JOIN sys.dm_db_partition_stats ps
    ON i.object_id = ps.object_id
    AND i.index_id = ps.index_id
WHERE OBJECT_NAME(i.object_id) LIKE 'vw_%'
ORDER BY View_Name, Index_Name;
GO
