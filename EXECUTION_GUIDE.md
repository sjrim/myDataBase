# How to Run the Week 3 Code - Step by Step Guide

## Prerequisites

You need:
- ✅ SQL Server (any version 2016+)
- ✅ SQL Server Management Studio (SSMS)
- ✅ Database: `2025DBFall_Group_5_DB` (should already exist)
- ✅ Source data tables: `LIY26.dbo.LI_CUSTOMERS_INTX`, `LI_CUSTOMERS_EXT`, `LI_CHANNELS` (should already exist from previous weeks)

---

## Execution Order (IMPORTANT!)

**Run files in this exact order:**

### Step 1: Create Dimension Tables
```
1. COUNTRY.sql         (if not already done)
2. CUSTOMER.sql        (if not already done)
3. LL_CHANNELS.sql     (if not already done)
4. PRODUCT.sql         ← NEW
5. PROMOTION.sql       ← NEW
```

### Step 2: Create Fact Table with Indexes
```
6. SALES.sql           ← NEW (includes 5 indexes)
```

### Step 3: Create Indexed Views
```
7. IndexedViews.sql    ← NEW (4 materialized views)
```

### Step 4: Create Stored Procedures
```
8. StoredProcedures.sql ← NEW (2 procedures)
```

### Step 5: Test Business Queries
```
9. BusinessQueries.sql  ← NEW (all 8 queries)
```

---

## Detailed Instructions

### Method 1: Using SQL Server Management Studio (SSMS) - RECOMMENDED

#### Step-by-Step:

1. **Open SSMS**
   - Connect to your SQL Server instance

2. **Verify Database Exists**
   ```sql
   USE master;
   GO

   -- Check if database exists
   SELECT name FROM sys.databases WHERE name = '2025DBFall_Group_5_DB';
   GO
   ```

3. **Open First File**
   - File → Open → File
   - Navigate to: `PRODUCT.sql`
   - The file opens in a new query window

4. **Run the File**
   - Press **F5** or click **Execute** button
   - Watch the Messages tab for results
   - Look for: "Command(s) completed successfully"

5. **Repeat for Each File in Order**
   ```
   PRODUCT.sql          → Execute (F5)
   PROMOTION.sql        → Execute (F5)
   SALES.sql            → Execute (F5) - takes longer (creating indexes)
   IndexedViews.sql     → Execute (F5) - takes longer (creating views)
   StoredProcedures.sql → Execute (F5)
   BusinessQueries.sql  → Execute (F5) - shows query results
   ```

---

### Method 2: Using Command Line (sqlcmd)

If you prefer command line:

```bash
# Navigate to the directory
cd /path/to/myDataBase

# Run each file in order
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i PRODUCT.sql
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i PROMOTION.sql
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i SALES.sql
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i IndexedViews.sql
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i StoredProcedures.sql
sqlcmd -S localhost -d 2025DBFall_Group_5_DB -i BusinessQueries.sql
```

---

## IMPORTANT: Sample Data Required!

**Note:** The tables will be EMPTY after creation. You need to populate them with data.

### Option A: You Have Source Data

If your professor provided source data, load it:

```sql
-- Example: Load products from source
INSERT INTO PRODUCT (PROD_ID, PROD_NAME, PROD_CATEGORY, PROD_LIST_PRICE, ...)
SELECT PROD_ID, PROD_NAME, PROD_CATEGORY, PROD_LIST_PRICE, ...
FROM [SourceDatabase].[dbo].[SourceProductTable];
GO

-- Repeat for PROMOTION and SALES
```

### Option B: Create Sample Data for Testing

I can create a sample data script if needed. Let me know!

---

## Verification Steps

After running all files, verify everything worked:

### 1. Check Tables Exist
```sql
USE [2025DBFall_Group_5_DB];
GO

SELECT
    TABLE_NAME,
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('CUSTOMER', 'PRODUCT', 'PROMOTION', 'SALES', 'LL_CHANNELS', 'COUNTRY')
ORDER BY TABLE_NAME;
GO
```

**Expected Result:** 6 tables listed

### 2. Check Indexes Exist
```sql
SELECT
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE t.name IN ('SALES', 'PRODUCT', 'PROMOTION')
  AND i.name IS NOT NULL
ORDER BY t.name, i.name;
GO
```

**Expected Result:** Should see indexes like:
- IX_SALES_SALEDATE
- IX_SALES_CUSTOMER
- IX_SALES_CHANNEL
- IX_PRODUCT_CATEGORY
- etc.

### 3. Check Indexed Views Exist
```sql
SELECT
    name AS ViewName,
    create_date
FROM sys.views
WHERE name LIKE 'vw_%'
ORDER BY name;
GO
```

**Expected Result:** 4 views:
- vw_MonthlySalesByCategory
- vw_CustomerPurchaseSummary
- vw_ChannelPerformanceSummary
- vw_ProductDiscountAnalysis

### 4. Check Stored Procedures Exist
```sql
SELECT
    name AS ProcedureName,
    create_date
FROM sys.procedures
WHERE name LIKE 'sp_%'
ORDER BY name;
GO
```

**Expected Result:** 2 procedures:
- sp_UpdateCustomerCreditLimit
- sp_DeleteCancelledTransaction

---

## Testing the Business Queries

### BQ01: Monthly Sales Performance
```sql
-- This will run but return empty if no data loaded
SELECT
    p.PROD_CATEGORY,
    YEAR(s.SALE_DATE) AS Sale_Year,
    MONTH(s.SALE_DATE) AS Sale_Month,
    SUM(s.AMOUNT_SOLD) AS Total_Revenue
FROM SALES s
INNER JOIN PRODUCT p ON s.PROD_ID = p.PROD_ID
GROUP BY p.PROD_CATEGORY, YEAR(s.SALE_DATE), MONTH(s.SALE_DATE);
GO
```

### Test Stored Procedure (Dry Run - Safe)
```sql
-- This will run without errors even with empty tables
EXEC sp_UpdateCustomerCreditLimit
    @PaymentThreshold = 30,
    @IncreasePercentage = 10.0,
    @DryRun = 1;
GO
```

---

## Viewing Execution Plans (for Professor)

To show execution plans to your professor:

1. **Turn on Execution Plan**
   ```sql
   -- In SSMS: Query → Include Actual Execution Plan (Ctrl+M)
   -- OR add this to your query:
   SET STATISTICS IO ON;
   SET STATISTICS TIME ON;
   GO
   ```

2. **Run a Query**
   ```sql
   -- Example: BQ02
   SELECT TOP 20
       c.CUST_ID,
       c.CUST_FIRST_NAME + ' ' + c.CUST_LAST_NAME AS Customer_Name,
       SUM(s.AMOUNT_SOLD) AS Total_Revenue
   FROM CUSTOMER c
   INNER JOIN SALES s ON c.CUST_ID = s.CUST_ID
   GROUP BY c.CUST_ID, c.CUST_FIRST_NAME, c.CUST_LAST_NAME
   ORDER BY Total_Revenue DESC;
   GO
   ```

3. **View Results**
   - Click **Execution Plan** tab in SSMS
   - Shows graphical execution plan
   - Right-click → Save Execution Plan As... (to save as .sqlplan file)

---

## Common Issues and Solutions

### Issue 1: "Database does not exist"
**Solution:**
```sql
CREATE DATABASE [2025DBFall_Group_5_DB];
GO
USE [2025DBFall_Group_5_DB];
GO
```

### Issue 2: "Object already exists"
**Solution:** Tables/views/procedures already created. Either:
- Drop and recreate: `DROP TABLE PRODUCT; GO`
- Or skip that file

### Issue 3: "Foreign key constraint failed"
**Solution:** Must create tables in order:
1. COUNTRY (no dependencies)
2. CUSTOMER (depends on COUNTRY)
3. LL_CHANNELS (no dependencies)
4. PRODUCT (no dependencies)
5. PROMOTION (no dependencies)
6. SALES (depends on all above)

### Issue 4: "Cannot create index on view"
**Solution:** Must use WITH SCHEMABINDING and follow indexed view rules.
The provided IndexedViews.sql already follows all rules.

### Issue 5: No data in tables
**Solution:** Need to load data. Ask me to create a sample data script!

---

## For Your Professor - What to Show

### Deliverables Checklist:

✅ **Schema (Tables)**
   - Show table definitions: `sp_help SALES`
   - Show all tables: Query above

✅ **Indexes**
   - Show index list: Query above
   - Show index details: `sp_helpindex SALES`

✅ **Indexed Views**
   - Show view list: Query above
   - Show view definition: `sp_helptext vw_MonthlySalesByCategory`

✅ **Stored Procedures**
   - Show procedure list: Query above
   - Show procedure code: `sp_helptext sp_UpdateCustomerCreditLimit`

✅ **Business Queries**
   - Run each query from BusinessQueries.sql
   - Show execution plans

✅ **Documentation**
   - Week3_Summary.md (2 pages)
   - Week3_ExecutionPlan_Analysis.md (detailed)

---

## Quick Demo Script

Run this to show everything works:

```sql
USE [2025DBFall_Group_5_DB];
GO

-- 1. Show all tables
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;
GO

-- 2. Show all indexes on SALES table
EXEC sp_helpindex 'SALES';
GO

-- 3. Show all indexed views
SELECT name FROM sys.views WHERE name LIKE 'vw_%';
GO

-- 4. Show all stored procedures
SELECT name FROM sys.procedures WHERE name LIKE 'sp_%';
GO

-- 5. Test a stored procedure (dry run - safe)
EXEC sp_UpdateCustomerCreditLimit @DryRun = 1;
GO

-- 6. Show execution plan for a query
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- Run a sample query (will be empty if no data)
SELECT COUNT(*) AS Total_Sales FROM SALES;
GO
```

---

## Need Help?

**If you need:**
- Sample data to populate tables → Let me know!
- Help with specific errors → Share the error message
- Different execution method → I can help
- Execution plan screenshots → I can guide you

**Files Location on GitHub:**
Branch: `claude/sales-performance-query-01Xx5WYBvZRsBnQ5NDXy56gg`

All files are ready to run in order!
