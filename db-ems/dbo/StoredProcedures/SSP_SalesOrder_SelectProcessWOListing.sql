-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO pending process to workOrder

-- Description : All Sales Order still remain unprocess

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-25   7.0         ZY Wong     LTRIM(RTRIM(@searchInput))
-- 2025-09-02   6.0         ZY Wong     Change modelNo to inventorySku
-- 2025-06-16   5.0         ZY Wong     Hardcode @pageRow = 9999 change earlyShipDate >= @earlyShipDate
-- 2025-06-15   4.0         ZY Wong     Fix sorting issue
-- 2025-05-05   3.0         WL Leong    PortId is not a filter in UI
-- 2025-04-01   2.0         WL Leong    Return totalRecord
-- 2025-03-04	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_SelectProcessWOListing 4, 0,  '2025-06-16', 0, 0, 0, 1, 10, 2, 'DESC', null

CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectProcessWOListing]
@companyId INT,
@customerId INT = 0, -- for filter of data
@earlyShipDate VARCHAR(100), -- for filter of data
@portId INT = 0,	-- for filter of data
@warehouseId INT = 0, -- for filter of data 
@readyProcess INT = 1, -- for filter of data 
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'DESC',
@searchInput VARCHAR(50) 
AS
BEGIN

    /** sortBy
    1 = order by locNo  
    2 = order by soName
    3 = order by thirdParty
    4 = order by customerPo
    5 = order by earlyShipDate
    6 = order by portName 
    **/
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
 
	BEGIN TRY

        SET @pageRow = 9999;

		IF ISNULL(@earlyShipDate, '') = ''
			SET @earlyShipDate = getdate();
		 
   --     DECLARE @companyId INT = 4, @customerId INT = null, @earlyShipDate DATE = '2025-12-31', @pod VARCHAR(50) = '', @locNo VARCHAR(20) = null, 
		 --@processToWHId INT = 0, @forceProcess INT = 0, @rowStart INT = 1, @pageRow INT = 10, @sortBy INT = 0, @searchInput VARCHAR(50) = '', @sortDirection VARCHAR(4) = 'DESC'
        DECLARE @sortOrder VARCHAR(2), @locNo VARCHAR(10);

		IF @customerId = 0 
            SET @customerId = NULL

        --IF @portId = '0'  
            SET @portId = NULL

        IF @warehouseId = '0'  
            SET @warehouseId = NULL

        IF @warehouseId = '0' 
            SET @locNo = NULL
		ELSE
			SET @locNo = (SELECT locNo FROM md_warehouse WHERE warehouseId = @warehouseId)

        IF @searchInput = ''
            SET @searchInput = NULL

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END


        DROP TABLE IF EXISTS #soSearch;

        CREATE TABLE #soSearch(soHeaderId BIGINT, locNo VARCHAR(20), soStatus INT)
        
        IF @searchInput IS NOT NULL
        BEGIN

            SET @searchInput = (SELECT LTRIM(RTRIM(@searchInput)));

            INSERT INTO #soSearch(soHeaderId, locNo, soStatus)
            SELECT soHeaderId, locNo, soStatus
            FROM soHeader
            WHERE companyId = @companyId
				AND soName LIKE '%' + @searchInput + '%'

            INSERT INTO #soSearch(soHeaderId, locNo, soStatus)
            SELECT soHeaderId, locNo, soStatus
            FROM soHeader
            WHERE companyId = @companyId
				AND customerPO LIKE '%' + @searchInput + '%'

        END
        ELSE
        BEGIN
			INSERT INTO #soSearch(soHeaderId, locNo, soStatus)
			SELECT li.soHeaderId, locNo, li.soStatus
			FROM soHeader li
			WHERE li.companyId = @companyId
				AND (customerId = @customerId OR @customerId IS NULL)
				AND (locNo = @locNo OR @locNo IS NULL)
				AND (portOfDestination  = @portId OR @portId IS NULL)
				AND earlyShipDate >= @earlyShipDate
  
			IF @readyProcess = 1
			BEGIN
				DELETE FROM #soSearch WHERE ISNULL(locNo, '') = '' OR soStatus = 1105
			END
        END 

        DROP TABLE IF EXISTS #soInfo;

        SELECT li.soHeaderId, li.customerId, li.locNo, soName, customerPO, thirdParty, thirdPartyPO, soDate, earlyShipDate, portName, li.soStatus
        INTO #soInfo
        FROM soHeader li
            INNER JOIN #soSearch so 
                ON li.soHeaderId = so.soHeaderId
            INNER JOIN md_port pd 
                ON li.portOfDestination = pd.portId
        WHERE li.companyId = @companyId
        
 
        DROP TABLE IF EXISTS #sortingListing;

        SELECT li.soLineItemId, soName, ISNULL(locNo, '') as locNo, thirdParty, customerPO, earlyShipDate as shipDate, portName, 
			li.invId, inv.inventorySku, li.odrQty, li.processQty, li.odrQty - li.processQty as pendingProcessQty, mc.categoryName as soStatus,
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN ISNULL(locNo, '') END DESC,
                CASE @sortOrder WHEN'1A' THEN ISNULL(locNo, '') END ASC,
                CASE @sortOrder WHEN '2D' THEN soName END DESC,
                CASE @sortOrder WHEN'2A' THEN soName END ASC,  
                CASE @sortOrder WHEN '3D' THEN thirdParty END DESC,
                CASE @sortOrder WHEN'3A' THEN thirdParty END ASC,  
                CASE @sortOrder WHEN '4D' THEN customerPO END DESC,
                CASE @sortOrder WHEN'4A' THEN customerPO END ASC,    
                CASE @sortOrder WHEN '5D' THEN earlyShipDate END DESC,
                CASE @sortOrder WHEN'5A' THEN earlyShipDate END ASC,
                CASE @sortOrder WHEN '6D' THEN portName END DESC,
                CASE @sortOrder WHEN'6A' THEN portName END ASC
                 ) as rowNo
        INTO #sortingListing
        FROM  #soInfo s
			INNER JOIN md_MasterCategory mc
				ON s.soStatus = mc.categoryId
            INNER JOIN soLineItem li
                ON s.soHeaderId = li.soHeaderId
			INNER JOIN md_inventory inv
				ON li.invId = inv.invId
		WHERE li.odrQty - li.processQty   > 0
			AND li.soLineItemStatus NOT IN (1107, 1108)

        DECLARE @totalRecord INT = (SELECT COUNT(1) FROM #sortingListing);

        SELECT soLineItemId, locNo, soName, customerPO, shipDate, portName, inventorySku, odrQty, processQty, pendingProcessQty, soStatus,rowNo , @totalRecord as totalRecord, thirdParty
        FROM #sortingListing
        WHERE rowNo >= @rowStart 
            AND rowNo <=  (@rowStart-1) + @pageRow
        ORDER BY rowNo
 
	END TRY

	BEGIN CATCH
 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO

