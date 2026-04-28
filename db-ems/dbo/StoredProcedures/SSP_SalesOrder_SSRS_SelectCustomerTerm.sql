-- =============================================
-- Author:		WL Leong
-- Create date: 2024-05-05
-- Used By:	    EMS -> SO Module -> SO Listing -> Export SO/PI ssrs
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-25	2.0			WL Leong	Default to company default if no customer is specify
-- 2024-05-05	1.0			WL Leong	Initial
--select * from soheader where soName = 'MPH-SO-25-00255'
-- ==========================================================================================
-- EXEC SSP_SalesOrder_SSRS_SelectCustomerTerm 21692, 'SO'
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectCustomerTerm]
@soHeaderId BIGINT,
@module VARCHAR(3)
AS 

BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #soInfo;

    SELECT companyId, customerId
    INTO #soInfo
    FROM soHeader s
    WHERE soHeaderId = @soHeaderId
 
    CREATE TABLE #customerTerm(termRow INT, termText NVARCHAR(MAX))

    INSERT INTO #customerTerm(termRow, termText)
    SELECT ct.termRow, ct.termText
    FROM #soInfo s
        INNER JOIN md_TermNCondition ct
            ON s.companyId = ct.companyId
            AND s.customerId = ct.customerId
            AND ct.module = @module
    WHERE ct.statusFlag = 1


    IF (SELECT COUNT(1) FROM #customerTerm) = 0
    BEGIN
        INSERT INTO #customerTerm(termRow, termText)
        SELECT ct.termRow, ct.termText
        FROM #soInfo s
            INNER JOIN md_TermNCondition ct
                ON s.companyId = ct.companyId
                AND ct.module = @module
				AND ct.customerId = 0
        WHERE ct.statusFlag = 1
    END

    SELECT termRow, termText
    FROM #customerTerm
END

GO

