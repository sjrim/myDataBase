-- ============================================================================
-- Stored Procedures for UPDATE and DELETE Operations
-- Week 3: Access Structures Determination
-- ============================================================================

USE [2025DBFall_Group_5_DB];
GO

-- ============================================================================
-- BQ04: Update Customer Credit Limit (UPDATE)
-- User Type: Sales Manager
-- Description: Update customer credit limits based on purchase history and payment behavior
-- Derived Attributes: Days_To_Pay = Payment_Date – Sale_Date
-- ============================================================================

CREATE OR ALTER PROCEDURE sp_UpdateCustomerCreditLimit
    @CUST_ID INT = NULL,  -- NULL = update all eligible customers
    @PaymentThreshold INT = 30,  -- Days threshold for "on-time" payment
    @IncreasePercentage DECIMAL(5,2) = 10.0,  -- Percentage increase for credit limit
    @MinimumTransactions INT = 5,  -- Minimum number of transactions to qualify
    @DryRun BIT = 0  -- If 1, show what would be updated without making changes
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UpdateCount INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Create temp table to hold customers eligible for credit increase
        CREATE TABLE #EligibleCustomers (
            CUST_ID INT,
            Current_Credit_Limit DECIMAL(18,2),
            New_Credit_Limit DECIMAL(18,2),
            Total_Transactions INT,
            Total_Revenue DECIMAL(18,2),
            Avg_Days_To_Pay DECIMAL(10,2),
            OnTime_Payment_Pct DECIMAL(5,2)
        );

        -- Identify eligible customers
        INSERT INTO #EligibleCustomers
        SELECT
            c.CUST_ID,
            c.CUST_CREDIT_LIMIT AS Current_Credit_Limit,
            -- New credit limit = current + percentage increase
            ROUND(c.CUST_CREDIT_LIMIT * (1 + @IncreasePercentage / 100.0), 2) AS New_Credit_Limit,
            COUNT(s.SALE_ID) AS Total_Transactions,
            SUM(s.AMOUNT_SOLD) AS Total_Revenue,
            AVG(CAST(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) AS DECIMAL(10,2))) AS Avg_Days_To_Pay,
            -- Percentage of payments made on time
            SUM(CASE WHEN DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) <= @PaymentThreshold THEN 1 ELSE 0 END) * 100.0
                / COUNT(s.SALE_ID) AS OnTime_Payment_Pct
        FROM CUSTOMER c
        INNER JOIN SALES s ON c.CUST_ID = s.CUST_ID
        WHERE s.PAYMENT_DATE IS NOT NULL
          AND c.CUST_CREDIT_LIMIT IS NOT NULL
          AND (@CUST_ID IS NULL OR c.CUST_ID = @CUST_ID)
        GROUP BY
            c.CUST_ID,
            c.CUST_CREDIT_LIMIT
        HAVING
            -- Criteria for credit increase:
            -- 1. Minimum transaction count
            COUNT(s.SALE_ID) >= @MinimumTransactions
            -- 2. Average payment within threshold (on-time payment)
            AND AVG(CAST(DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) AS DECIMAL(10,2))) <= @PaymentThreshold
            -- 3. At least 80% of payments on time
            AND SUM(CASE WHEN DATEDIFF(DAY, s.SALE_DATE, s.PAYMENT_DATE) <= @PaymentThreshold THEN 1 ELSE 0 END) * 100.0
                / COUNT(s.SALE_ID) >= 80;

        -- Show results
        SELECT
            CUST_ID,
            Current_Credit_Limit,
            New_Credit_Limit,
            New_Credit_Limit - Current_Credit_Limit AS Credit_Increase,
            Total_Transactions,
            Total_Revenue,
            Avg_Days_To_Pay,
            OnTime_Payment_Pct,
            CASE WHEN @DryRun = 1 THEN 'DRY RUN - No changes made' ELSE 'UPDATED' END AS Status
        FROM #EligibleCustomers
        ORDER BY Total_Revenue DESC;

        SET @UpdateCount = @@ROWCOUNT;

        -- Perform actual update if not dry run
        IF @DryRun = 0
        BEGIN
            UPDATE c
            SET c.CUST_CREDIT_LIMIT = ec.New_Credit_Limit
            FROM CUSTOMER c
            INNER JOIN #EligibleCustomers ec ON c.CUST_ID = ec.CUST_ID;

            PRINT 'Credit limits updated for ' + CAST(@UpdateCount AS VARCHAR(10)) + ' customer(s).';
        END
        ELSE
        BEGIN
            PRINT 'DRY RUN: Would update credit limits for ' + CAST(@UpdateCount AS VARCHAR(10)) + ' customer(s).';
        END

        DROP TABLE #EligibleCustomers;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Error updating customer credit limits: ' + @ErrorMessage;

        -- Re-throw the error
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- BQ08: Delete Cancelled Transaction (DELETE)
-- User Type: Accounting/Finance Staff
-- Description: Remove erroneous or cancelled sales transactions after proper authorization
-- ============================================================================

CREATE OR ALTER PROCEDURE sp_DeleteCancelledTransaction
    @SALE_ID BIGINT = NULL,  -- Specific transaction to delete
    @CUST_ID INT = NULL,  -- Delete all cancelled transactions for a customer
    @StartDate DATE = NULL,  -- Delete cancelled transactions in date range
    @EndDate DATE = NULL,
    @AuthorizationCode VARCHAR(50) = NULL,  -- Required authorization code
    @Reason VARCHAR(500) = NULL,  -- Required reason for deletion
    @DryRun BIT = 1  -- Default to dry run for safety
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DeleteCount INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @AuditLog TABLE (
        SALE_ID BIGINT,
        CUST_ID INT,
        SALE_DATE DATE,
        AMOUNT_SOLD DECIMAL(18,2),
        Deleted_DateTime DATETIME,
        Deleted_By VARCHAR(100),
        Authorization_Code VARCHAR(50),
        Reason VARCHAR(500)
    );

    BEGIN TRY
        -- Validation: Must provide authorization code and reason
        IF @AuthorizationCode IS NULL OR @Reason IS NULL
        BEGIN
            RAISERROR('Authorization code and reason are required for transaction deletion.', 16, 1);
            RETURN;
        END

        -- Validation: Must specify at least one filter criteria
        IF @SALE_ID IS NULL AND @CUST_ID IS NULL AND (@StartDate IS NULL OR @EndDate IS NULL)
        BEGIN
            RAISERROR('Must specify SALE_ID, CUST_ID, or date range for deletion.', 16, 1);
            RETURN;
        END

        BEGIN TRANSACTION;

        -- Log transactions to be deleted (audit trail)
        INSERT INTO @AuditLog (
            SALE_ID,
            CUST_ID,
            SALE_DATE,
            AMOUNT_SOLD,
            Deleted_DateTime,
            Deleted_By,
            Authorization_Code,
            Reason
        )
        SELECT
            s.SALE_ID,
            s.CUST_ID,
            s.SALE_DATE,
            s.AMOUNT_SOLD,
            GETDATE(),
            SYSTEM_USER,
            @AuthorizationCode,
            @Reason
        FROM SALES s
        WHERE
            (@SALE_ID IS NOT NULL AND s.SALE_ID = @SALE_ID)
            OR (@CUST_ID IS NOT NULL AND s.CUST_ID = @CUST_ID)
            OR (@StartDate IS NOT NULL AND @EndDate IS NOT NULL
                AND s.SALE_DATE BETWEEN @StartDate AND @EndDate);

        SET @DeleteCount = @@ROWCOUNT;

        -- Show what will be deleted
        SELECT
            SALE_ID,
            CUST_ID,
            SALE_DATE,
            AMOUNT_SOLD,
            Deleted_DateTime,
            Deleted_By,
            Authorization_Code,
            Reason,
            CASE WHEN @DryRun = 1 THEN 'DRY RUN - No deletion performed' ELSE 'DELETED' END AS Status
        FROM @AuditLog
        ORDER BY SALE_DATE DESC;

        -- Perform actual deletion if not dry run
        IF @DryRun = 0
        BEGIN
            -- In production, consider moving to archive table instead of hard delete
            -- For now, perform the delete
            DELETE s
            FROM SALES s
            INNER JOIN @AuditLog a ON s.SALE_ID = a.SALE_ID;

            PRINT 'Deleted ' + CAST(@DeleteCount AS VARCHAR(10)) + ' transaction(s).';
            PRINT 'Authorization Code: ' + @AuthorizationCode;
            PRINT 'Reason: ' + @Reason;

            -- TODO: In production, insert audit log into permanent audit table
            -- INSERT INTO SALES_DELETION_AUDIT SELECT * FROM @AuditLog;
        END
        ELSE
        BEGIN
            PRINT 'DRY RUN: Would delete ' + CAST(@DeleteCount AS VARCHAR(10)) + ' transaction(s).';
            PRINT 'Use @DryRun = 0 to perform actual deletion.';
        END

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();
        PRINT 'Error deleting transactions: ' + @ErrorMessage;

        -- Re-throw the error
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- Usage Examples for Stored Procedures
-- ============================================================================

-- Example 1: BQ04 - Dry run to see which customers qualify for credit increase
EXEC sp_UpdateCustomerCreditLimit
    @PaymentThreshold = 30,
    @IncreasePercentage = 10.0,
    @MinimumTransactions = 5,
    @DryRun = 1;
GO

-- Example 2: BQ04 - Update specific customer's credit limit
EXEC sp_UpdateCustomerCreditLimit
    @CUST_ID = 12345,
    @PaymentThreshold = 30,
    @IncreasePercentage = 15.0,
    @MinimumTransactions = 3,
    @DryRun = 0;
GO

-- Example 3: BQ08 - Dry run to see what would be deleted
EXEC sp_DeleteCancelledTransaction
    @SALE_ID = 999999,
    @AuthorizationCode = 'AUTH-2024-001',
    @Reason = 'Customer requested cancellation within 24 hours',
    @DryRun = 1;
GO

-- Example 4: BQ08 - Delete specific transaction (requires authorization)
EXEC sp_DeleteCancelledTransaction
    @SALE_ID = 999999,
    @AuthorizationCode = 'AUTH-2024-001',
    @Reason = 'Duplicate transaction - system error',
    @DryRun = 0;
GO

-- Example 5: BQ08 - Delete all cancelled transactions for a customer in date range
EXEC sp_DeleteCancelledTransaction
    @CUST_ID = 12345,
    @StartDate = '2024-01-01',
    @EndDate = '2024-01-31',
    @AuthorizationCode = 'AUTH-2024-002',
    @Reason = 'Fraudulent transactions identified and verified',
    @DryRun = 1;
GO
