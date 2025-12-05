-- 2. CUSTOMER
CREATE TABLE CUSTOMER (
    CUST_ID                 INT           NOT NULL,
    CUST_FIRST_NAME         VARCHAR(50)   NOT NULL,
    CUST_LAST_NAME          VARCHAR(50)   NOT NULL,
    CUST_GENDER             CHAR(1)       NULL,
    CUST_MAIN_PHONE_NUMBER  VARCHAR(25)   NULL,
    CUST_EMAIL              VARCHAR(100)  NULL,
    CUST_STREET_ADDRESS     VARCHAR(200)  NULL,
    CUST_POSTAL_CODE        VARCHAR(20)   NULL,
    CUST_CITY               VARCHAR(100)  NULL,
    CUST_STATE_PROVINCE     VARCHAR(100)  NULL,
    COUNTRY_ID              INT           NOT NULL,
    CUST_YEAR_OF_BIRTH      INT           NULL,
    CUST_MARITAL_STATUS     VARCHAR(20)   NULL,
    CUST_INCOME_LEVEL       VARCHAR(20)   NULL,
    CUST_CREDIT_LIMIT       DECIMAL(18,2) NULL,
    CONSTRAINT PK_CUSTOMER PRIMARY KEY (CUST_ID),
    CONSTRAINT FK_CUSTOMER_COUNTRY
        FOREIGN KEY (COUNTRY_ID)
        REFERENCES COUNTRY(COUNTRY_ID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    -- Domain constraints (low-cardinality fields)
    CONSTRAINT CK_CUSTOMER_GENDER
        CHECK (CUST_GENDER IN ('M','F','U') OR CUST_GENDER IS NULL),
    CONSTRAINT CK_CUSTOMER_MARITAL
        CHECK (CUST_MARITAL_STATUS IS NULL
               OR CUST_MARITAL_STATUS IN ('single','married','divorced','widow')),
    CONSTRAINT CK_CUSTOMER_INCOME
        CHECK (CUST_INCOME_LEVEL IS NULL
               OR CUST_INCOME_LEVEL IN ('A','B','C','D','E','F','G','H')),
    -- Business rule constraints
    CONSTRAINT CK_CUSTOMER_CREDITLIMIT
        CHECK (CUST_CREDIT_LIMIT IS NULL OR CUST_CREDIT_LIMIT >= 0),
    CONSTRAINT CK_CUSTOMER_YOB
        CHECK (CUST_YEAR_OF_BIRTH IS NULL
               OR (CUST_YEAR_OF_BIRTH BETWEEN 1900 AND YEAR(GETDATE()))),
    CONSTRAINT CK_CUSTOMER_EMAIL
        CHECK (CUST_EMAIL IS NULL OR CUST_EMAIL LIKE '%@%')
);


USE [2025DBFall_Group_5_DB]
GO


ALTER TABLE dbo.CUSTOMER
ALTER COLUMN CUST_INCOME_LEVEL VARCHAR(50) NULL; -- Enlarge the column to fit the real data
GO

ALTER TABLE dbo.CUSTOMER
DROP CONSTRAINT CK_CUSTOMER_MARITAL;   -- use the name shown in error
GO

ALTER TABLE dbo.CUSTOMER
DROP CONSTRAINT CK_CUSTOMER_INCOME;   -- exact name from the error message
GO

INSERT INTO dbo.CUSTOMER (
    CUST_ID,
    CUST_FIRST_NAME,
    CUST_LAST_NAME,
    CUST_GENDER,
    CUST_MAIN_PHONE_NUMBER,
    CUST_EMAIL,
    CUST_STREET_ADDRESS,
    CUST_POSTAL_CODE,
    CUST_CITY,
    CUST_STATE_PROVINCE,
    COUNTRY_ID,
    CUST_YEAR_OF_BIRTH,
    CUST_MARITAL_STATUS,
    CUST_INCOME_LEVEL,
    CUST_CREDIT_LIMIT
)
SELECT
    i.CUST_ID,
    i.CUST_FIRST_NAME,
    i.CUST_LAST_NAME,
    COALESCE(e.CUST_GENDER, i.CUST_GENDER),
    i.CUST_MAIN_PHONE_NUMBER,
    i.CUST_EMAIL,
    i.CUST_STREET_ADDRESS,
    i.CUST_POSTAL_CODE,
    i.CUST_CITY,
    i.CUST_STATE_PROVINCE,
    i.COUNTRY_ID,
    e.CUST_YEAR_OF_BIRTH,
    e.CUST_MARITAL_STATUS,
    e.CUST_INCOME_LEVEL,
    e.CUST_CREDIT_LIMIT
FROM LIY26.dbo.LI_CUSTOMERS_INTX i
LEFT JOIN LIY26.dbo.LI_CUSTOMERS_EXT e
       ON i.CUST_ID = e.CUST_ID;
GO



--1.CUST_INCOME_LEVEL (CUSTOMER – CK_CUSTOMER_INCOME and length)

--Initial design: CUST_INCOME_LEVEL was defined as a short code (e.g., A–H) with a CHECK constraint that only allowed a small set of values.

--Problem observed: the source column in LI_CUSTOMERS_EXT actually stores descriptive income ranges such as "K: 250,000 – 299,999", which are longer strings and outside the allowed set. This produced a string truncation error and a conflict with CK_CUSTOMER_INCOME during the load.

--Resolution: we increased the column length to VARCHAR(50) and dropped the restrictive CK_CUSTOMER_INCOME constraint so that the database can store the full set of income ranges used in the operational system.

--2.CUST_MARITAL_STATUS (CUSTOMER – CK_CUSTOMER_MARITAL)

--Initial design: we restricted marital status to a few values (e.g., single, married, divorced, widow) using CK_CUSTOMER_MARITAL.

--Problem observed: LI_CUSTOMERS_EXT.CUST_MARITAL_STATUS contains additional valid categories, so inserts failed with a check-constraint violation.

--Resolution: we removed CK_CUSTOMER_MARITAL (and could later replace it with a looser constraint based on the actual set of values) so that the database reflects the real domain of the source dat--a.