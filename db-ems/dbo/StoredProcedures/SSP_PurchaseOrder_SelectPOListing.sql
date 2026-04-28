-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-20
-- Used By:	    EMS -> PO Module -> PO Listing 

-- Description : List of PO Item details

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-19   4.0         ZY Wong     Add search for poName, poReferenceId, customerPo
-- 2025-05-04   3.0         WL Leong    Add customerCode and sorting
-- 2025-04-01   2.0         WL Leong    Return totalRecord
-- 2024-04-20	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_PurchaseOrder_SelectPOListing] 0, '2025-01-01', '2025-05-31', NULL, '593', 1, 400, 1, 'ASC', 11

CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SelectPOListing]
@supplierId INT,
@startDate DATE,
@endDate DATE,
@poStatus INT = NULL,
@search VARCHAR(100),
@rowStart INT,
@pageRow INT,
@sortBy INT,
@sortDirection VARCHAR(4) = 'DESC',
@companyId INT
AS
BEGIN		
    /** sortBy
        1 = order by poReferenceId  
        2 = order by customerCode 
        3 = order by poName
        4 = order by supplierCompanyName
        5 = order by poDate
        6 = order by totalQty
        7 = order by totalReceived
        8 = order by poGrossTotal
        9 = order by shipDate
        10 = order by poStatusName
    **/
    
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

        DECLARE @sortOrder VARCHAR(3);

        IF ISNULL(@sortBy,0) = 0
        BEGIN
            SET @sortBy = 1
        END

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

		IF @poStatus = '' or @poStatus = 0
		BEGIN
			SET @poStatus = NULL
		END

		IF @supplierId = 0
		BEGIN
			SET @supplierId = NULL
		END

        IF @search = ''
        BEGIN
            SET @search = NULL
        END

        DROP TABLE IF EXISTS #search;
        CREATE TABLE #search (poId BIGINT);

        DROP TABLE IF EXISTS #soName;
        CREATE TABLE #soName (soName VARCHAR(50));

        DROP TABLE IF EXISTS #poHeader;
        CREATE TABLE #poHeader (poId BIGINT, poReferenceId VARCHAR(50), poName VARCHAR(50), poDate DATE, supplierId INT, poEarlyShipDate DATE, poGrossTotal NUMERIC(18,4), poStatus INT, 
            customerCode VARCHAR(20), totalRecord INT DEFAULT 0, poStatusName VARCHAR(50), supplierCompanyName VARCHAR(20) DEFAULT (''), internal_branchId INT);

        IF @search IS NOT NULL
        BEGIN

            INSERT INTO #search (poId)
            SELECT DISTINCT poId 
            FROM poHeader 
            WHERE companyId = @companyId
                AND poName LIKE '%' + @search + '%'

            INSERT INTO #search (poId)
            SELECT DISTINCT poId 
            FROM poHeader
            WHERE companyId = @companyId
                AND poReferenceId LIKE '%' + @search + '%'

            INSERT INTO #soName (soName)
            SELECT DISTINCT soName
            FROM soHeader
            WHERE companyId = @companyId
                AND customerPo LIKE '%' + @search + '%'

            IF (SELECT COUNT(1) FROM #soName) > 0
            BEGIN
                INSERT INTO #search (poId)
                SELECT DISTINCT poId 
                FROM poHeader po
                    INNER JOIN #soName so
                        ON po.poReferenceId = so.soName
            END

            INSERT INTO #poHeader (poId, poReferenceId, poName, poDate, supplierId, poEarlyShipDate, poGrossTotal, poStatus, customerCode)
            SELECT DISTINCT l.poId, poReferenceId, poName, poDate, supplierId, poEarlyShipDate, poGrossTotal, poStatus, customerCode
            FROM poHeader po
                INNER JOIN #search l
                    ON po.poId = l.poId

        END
        ELSE
        BEGIN
            INSERT INTO #poHeader (poId, poReferenceId, poName, poDate, supplierId, poEarlyShipDate, poGrossTotal, poStatus, customerCode)
            SELECT poId, poReferenceId, poName, poDate, supplierId, poEarlyShipDate, poGrossTotal, poStatus, customerCode
            FROM poHeader
            WHERE companyId = @companyId
			    AND (supplierId = @supplierId OR @supplierId IS NULL)
                AND poEarlyShipDate BETWEEN @startDate AND @endDate
                AND (poStatus = @poStatus OR @poStatus IS NULL)
        END

        UPDATE #poHeader SET
            totalRecord = totalrow
        FROM (SELECT COUNT(DISTINCT poId) as totalrow FROM #poHeader) g

        UPDATE #poHeader SET
            poStatusName = mc.categoryName
        FROM md_masterCategory mc 
        WHERE #poHeader.poStatus = mc.categoryId

        UPDATE p SET
            supplierCompanyName = ISNULL(c.companyShortCode, s.supplierCompanyName),
			internal_branchId = s.internal_branchId
        FROM #poHeader p
            INNER JOIN md_Supplier s
                ON p.supplierId = s.supplierId
            LEFT JOIN md_company c
                ON s.internal_branchid = c.companyId

        DROP TABLE IF EXISTS #lineItem;

        SELECT ph.poId, SUM(pl.qty) as totalQty, SUM(pl.rcvQty) as totalReceived
        INTO #lineItem
        FROM #poHeader ph
            INNER JOIN poLineItem pl 
                ON ph.poId = pl.poId
        WHERE pl.itemStatus <> 1086 -- not include cancel
        GROUP BY ph.poId

        DROP TABLE IF EXISTS #poListing;

        SELECT p.poId, p.poReferenceId, p.poName, p.supplierCompanyName, p.customerCode, p.poDate, p.poEarlyShipDate as shipDate, p.internal_branchId,
            pl.totalQty, pl.totalReceived, poGrossTotal, p.poStatus, p.poStatusName, p.totalRecord
        INTO #poListing
        FROM #poHeader p
            LEFT JOIN #lineItem pl 
                ON p.poId = pl.poId
 
        DROP TABLE IF EXISTS #sortingListing;

        SELECT poId, poReferenceId, poName, supplierCompanyName, customerCode, poDate, shipDate, internal_branchId,
            totalQty, totalReceived, poGrossTotal, poStatus, poStatusName, totalRecord, 
            ROW_NUMBER() OVER(ORDER BY
                CASE @sortOrder WHEN '1D' THEN poReferenceId END DESC,
                CASE @sortOrder WHEN '1A' THEN poReferenceId END ASC,
                CASE @sortOrder WHEN '2D' THEN customerCode END DESC,
                CASE @sortOrder WHEN '2A' THEN customerCode END ASC,      
                CASE @sortOrder WHEN '3D' THEN poName END DESC,
                CASE @sortOrder WHEN '3A' THEN poName END ASC,  
                CASE @sortOrder WHEN '4D' THEN supplierCompanyName END DESC,
                CASE @sortOrder WHEN '4A' THEN supplierCompanyName END ASC, 
                CASE @sortOrder WHEN '5D' THEN poDate END DESC,
                CASE @sortOrder WHEN '5A' THEN poDate END ASC,   
                CASE @sortOrder WHEN '6D' THEN totalQty END DESC,
                CASE @sortOrder WHEN '6A' THEN totalQty END ASC,
                CASE @sortOrder WHEN '7D' THEN totalReceived END DESC,
                CASE @sortOrder WHEN '7A' THEN totalReceived END ASC,
                CASE @sortOrder WHEN '8D' THEN poGrossTotal END DESC,
                CASE @sortOrder WHEN '8A' THEN poGrossTotal END ASC,
                CASE @sortOrder WHEN '9D' THEN shipDate END DESC,
                CASE @sortOrder WHEN '9A' THEN shipDate END ASC,
                CASE @sortOrder WHEN '10D' THEN poStatusName END DESC,
                CASE @sortOrder WHEN '10A' THEN poStatusName END ASC
                 ) as rowNo             
        INTO #sortingListing
        FROM #poListing

        SELECT poID, poReferenceId, poName, internal_branchId, supplierCompanyName, customerCode,  poDate, shipDate, 
            totalQty, totalReceived, poGrossTotal, poStatus, poStatusName, rowNo, totalRecord
        FROM #sortingListing 
        WHERE rowNo >= @rowStart 
            AND rowNo <=  (@rowStart-1) + @pageRow
        ORDER BY rowNo

END

GO

