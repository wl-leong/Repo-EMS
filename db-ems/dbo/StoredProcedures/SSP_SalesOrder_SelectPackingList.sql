-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> Packing List

-- Description : All Sales Order still remain open and allow customer to process to shipment if inventory is ready

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-15	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_SelectPackingList 4, 0, '2023-12-23', '2025-06-20', null, 1, 10, 1, 'DESC', null
--select * from soheader order by 1 desc
  
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectPackingList]
@companyId INT,
@customerId INT = 0,
@startShipDate DATE,
@endShipDate DATE,
@pod VARCHAR(50),
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'ASC',
@searchInput VARCHAR(50) 
AS
BEGIN
    /** sortBy
        1 = order by soName  
        2 = order by lrName
        3 = order by customer 
        4 = order by shipTo 
        5 = order by shipDate 
    **/
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

        --DECLARE @companyId INT = 4, @customerId INT = 0,  
        --    @startShipDate DATE = '2024-06-10', @endShipDate DATE = '2025-09-08', @pod VARCHAR(50) = '', 
        --    @rowStart INT = 1, @pageRow INT = 10, @sortBy INT = 0, @searchInput VARCHAR(50), @sortDirection VARCHAR(4) = 'ASC'
        DECLARE @sortOrder VARCHAR(2);

		IF @customerId = 0 
            SET @customerId = NULL

        IF @pod = '0'  
            SET @pod = NULL

        IF @searchInput = ''
            SET @searchInput = NULL

        IF @sortDirection = 'ASC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END

        DROP TABLE IF EXISTS #pod;

        SELECT DISTINCT st.shipToId, st.pod
        INTO #pod
        FROM md_shipToDestination st
        WHERE st.companyId =  @companyId
            AND (st.pod = @pod or @pod IS NULL)

        DROP TABLE IF EXISTS #soSearch;

        CREATE TABLE #soSearch(soHeaderId BIGINT)
        
        IF @searchInput IS NOT NULL
        BEGIN
            INSERT INTO #soSearch(soHeaderId)
            SELECT soHeaderId
            FROM soHeader
            WHERE soName LIKE '%' + @searchInput + '%'

            INSERT INTO #soSearch(soHeaderId)
            SELECT DISTINCT soHeaderId
            FROM soHeader
            WHERE customerPO LIKE '%' + @searchInput + '%'
 

            INSERT INTO #soSearch(soHeaderId)
            SELECT DISTINCT li.soHeaderId
            FROM soLineItem li
                INNER JOIN lrReceiveLineItem lr
                    ON li.soLineItemId = lr.soLineItemId
            WHERE lr.lrName  LIKE '%' + @searchInput + '%'
        END
		ELSE
		BEGIN
			INSERT INTO #soSearch(soHeaderId)
			SELECT li.soHeaderId
			FROM soHeader li
				INNER JOIN #pod pd 
					ON li.shipToId = pd.shipToId
			WHERE li.companyId = @companyId
				AND (customerId = @customerId OR @customerId IS NULL)
				AND earlyShipDate BETWEEN @startShipDate AND @endShipDate
		END
        
        DROP TABLE IF EXISTS #soInfo;

        SELECT soHeaderId, customerId, soName, customerPO, soDate, earlyShipDate, lateShipDate, shipToId
        INTO #soInfo
        FROM soHeader  
		WHERE soStatus NOT IN (1108, 1107) -- not closed and cancel
			AND companyId = @companyId
			AND (customerId = @customerId OR @customerId IS NULL)
 
		DROP TABLE IF EXISTS #soLineItem;

		SELECT s.soHeaderId, s.customerId, s.soName, s.customerPO, s.soDate, s.earlyShipDate, s.lateShipDate, s.shipToId, 
			li.soLineitemId, li.invId, CAST('' as VARCHAR(50)) as inventorySku, li.odrQty-shpQty as openQty, 0 as warehouseQty
		INTO #soLineItem
		FROM #soInfo s
			INNER JOIN soLineItem li
				ON s.soHeaderId = li.soHeaderid
				AND li.soLineItemStatus NOT IN (1108,1107)
		WHERE li.odrQty-shpQty > 0
 
		UPDATE #soLineItem SET
			inventorySku = inv.inventorySku
		FROM md_inventory inv
		WHERE #soLineItem.invId = inv.invId

		DROP TABLE IF EXISTS #warehouseBalance;

		SELECT invId, SUM(balanceQty) as warehouseQty
		INTO #warehouseBalance
		FROM inventoryBalanceWH
		WHERE companyId = @companyId
		GROUP BY invId

 
		UPDATE #soLineItem SET
			warehouseQty = wh.warehouseQty
		FROM #warehouseBalance wh
		WHERE #soLineItem.invId = wh.invId

		DROP TABLE IF EXISTS #packingList;

		SELECT li.*, lr.lrName, lr.lrQty - lr.shipQty as loadingQty 
		INTO #packingList
		FROM #soLineItem li
			LEFT JOIN lrReceiveLineItem lr
				ON li.soLineitemId = lr.soLineItemId

 
        DROP TABLE IF EXISTS #sortingListing;

        SELECT soLineitemId, cs.customerName, soName, customerPO, lrName, soDate, earlyShipDate, lateShipDate, st.shipToLabel,  
			inventorySku, loadingQty, warehouseQty,  
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN soName END DESC,
                CASE @sortOrder WHEN'1A' THEN soName END ASC,
                CASE @sortOrder WHEN '2D' THEN lrName END DESC,
                CASE @sortOrder WHEN'2A' THEN lrName END ASC,
                CASE @sortOrder WHEN '3D' THEN cs.customerName END DESC,
                CASE @sortOrder WHEN'3A' THEN cs.customerName END ASC,            
                CASE @sortOrder WHEN '4D' THEN st.shipToLabel END DESC,
                CASE @sortOrder WHEN'4A' THEN st.shipToLabel END ASC,    
                CASE @sortOrder WHEN '5D' THEN earlyShipDate END DESC,
                CASE @sortOrder WHEN'5A' THEN earlyShipDate END ASC     
                 ) as rowNo 
        INTO #sortingListing
        FROM  #packingList s
            INNER JOIN md_customer cs
                ON s.customerId = cs.customerId
            INNER JOIN md_shipToDestination st 
                ON s.shipToid = st.shipToId

        SELECT soLineitemId, customerName, soName, lrName, customerPO, soDate, earlyShipDate, lateShipDate, shipToLabel,  inventorySku, loadingQty, warehouseQty,  rowNo 
        FROM #sortingListing
        WHERE rowNo >= @rowStart AND rowNo <= @rowStart + @pageRow
 
	END TRY

	BEGIN CATCH
 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO

