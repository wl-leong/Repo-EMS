-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-05-057
-- Used By:	    EMS -> SO Module -> SO Listing -> Export SO/PI ssrs 
--
-- Description : Select additional remakrs used by SO pdf
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-07	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_SalesOrder_SSRS_SelectAdditionalRemarks] 22079, 'SO'
-- [SSP_SalesOrder_SSRS_SelectAdditionalRemarks] 21476, 'PI'
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectAdditionalRemarks]
@soHeaderId BIGINT,
@module VARCHAR(3)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        --DECLARE @soHeaderId BIGINT = 21476, @module VARCHAR(3) = 'SO';

        DECLARE @companyId INT, @customerId INT;
        
        SELECT @companyId = companyId, @customerId = customerId 
        FROM soHeader 
        WHERE soHeaderId = @soHeaderId

        DROP TABLE IF EXISTS #itemHts;

        SELECT invId 
        INTO #itemHts
        FROM soLineItem
        WHERE soHeaderId = @soHeaderId

        ALTER TABLE #itemHts ADD prodCategoryId INT;
        ALTER TABLE #itemHts ADD prodCategory VARCHAR(50);
        ALTER TABLE #itemHts ADD htsCode VARCHAR(50);

        UPDATE #itemHts SET
            prodCategoryId = inv.productCategory
        FROM md_inventory inv
        WHERE #itemHts.invId = inv.invId

        UPDATE #itemHts SET
            prodCategory = pro.prodCategoryName
        FROM  md_inventoryCategory pro
        WHERE #itemHts.prodCategoryId = pro.prodCategoryId

        UPDATE #itemHts SET
            htsCode = c.HTSCode
        FROM md_inventoryHTSCode c
        WHERE #itemHts.prodCategoryId = c.HTSCode_prodCategoryId

        --DROP TABLE IF EXISTS #htsGroup;

        --SELECT ROW_NUMBER() OVER(ORDER BY htsCode) as htsRowNum, 
        --    '[' + CONVERT(VARCHAR(1), CHAR(ROW_NUMBER() OVER(ORDER BY htsCode) + 64)) + ']' as htsRowDisplay,
        --    htsCode, STRING_AGG(CONVERT(VARCHAR(MAX), prodCategory), ', ') as prodCategoryList
        --INTO #htsGroup
        --FROM (SELECT DISTINCT htsCode, prodCategory
        --        FROM #itemHts
        --        WHERE htsCode IS NOT NULL
        --     )g
        --GROUP BY htsCode

        -- only select top 1 record
        DROP TABLE IF EXISTS #htsGroup;

        SELECT ROW_NUMBER() OVER(ORDER BY htsCode) as htsRowNum, 
            '[' + CONVERT(VARCHAR(1), CHAR(ROW_NUMBER() OVER(ORDER BY htsCode) + 64)) + ']' as htsRowDisplay,
            htsCode, prodCategory as prodCategoryList
        INTO #htsGroup
        FROM (SELECT TOP 1 htsCode, prodCategory
                FROM #itemHts
                WHERE htsCode IS NOT NULL
                ORDER BY htsCode, prodCategory
             )g

        DROP TABLE IF EXISTS #getRemarks;

        CREATE TABLE #getRemarks (
            lineNum INT,
            remarksName VARCHAR(100),
            remarks VARCHAR(5000)
        )

        INSERT INTO #getRemarks (lineNum, remarksName, remarks)
        SELECT lineNum, remarksName, remarks
        FROM md_reportAdditionalRemarks 
        WHERE companyId = @companyId
            AND customerId = @customerId
            AND module = @module
            AND statusFlag = 1

        -- if record not found, use default 
        IF (SELECT COUNT(1) FROM #getRemarks) = 0
        BEGIN
            INSERT INTO #getRemarks (lineNum, remarksName, remarks)
            SELECT lineNum, remarksName, remarks
            FROM md_reportAdditionalRemarks 
            WHERE companyId = @companyId
                AND customerId = 0  -- use default
                AND module = @module
                AND statusFlag = 1
        END

        SELECT 1 as displaySeq, htsRowNum as lineNum, htsRowDisplay + ' ' + htsCode as remarksName, prodCategoryList as remarks
        FROM #htsGroup
        UNION ALL 
        SELECT 2 as displaySeq, lineNum, remarksName, remarks
        FROM #getRemarks

END

GO

