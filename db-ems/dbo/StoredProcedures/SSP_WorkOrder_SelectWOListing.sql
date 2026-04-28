-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-03-05
-- Used By:	    EMS -> SO Module -> WO Listing

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-24   5.1         ZY Wong     Update sorting seqence
-- 2025-09-02   5.0         ZY Wong     Add revision column
-- 2025-08-18   4.0         ZY Wong     Use confirmQty to calculate totalQty
-- 2025-08-12   3.1         WL Leong	Remove the blank space in searchInput
-- 2025-08-01   3.0         ZY Wong     Add column targetCompleteDate
-- 2025-05-05	2.0			WL Leong	Sorting issue
-- 2025-03-05	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC SSP_WorkOrder_SelectWOListing 4, 0, 5230, 1, 150 , 2 , 'desc', NULL, 1
 
 --select * from workOrder
CREATE PROCEDURE [dbo].[SSP_WorkOrder_SelectWOListing]
@companyId INT,
@warehouseId INT,  
@workOrderStatus INT,
@rowStart INT,
@pageRow INT,
@sortBy INT,
@sortDirection VARCHAR(4) = 'DESC',
@searchInput VARCHAR(50) = NULL,
@userId INT
AS
BEGIN
    /** sortBy follow UI column
        1 = order by workOrderName  
		3 = order by workOrderDate
        5 = order by warehouse
        6 = order by targetCompleteDate
        7 = order by shipDate 
        10 = order by status
    **/
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY        

--		DECLARE @companyId INT = 4,
--@warehouseId INT = 0,  
--@workOrderStatus INT = 5230,
--@rowStart INT = 1,
--@pageRow INT = 100,
--@sortBy INT,
--@sortDirection VARCHAR(4) = 'DESC',
--@searchInput VARCHAR(50) = NULL,
--@userId INT
        DECLARE @sortOrder VARCHAR(3), @CDCModule VARCHAR(50) = 'WorkOrder'
 
        IF @workOrderStatus = 0
            SET @workOrderStatus = NULL

        IF ISNULL(@warehouseId, 0) = 0
            SET @warehouseId = NULL

        IF ISNULL(@searchInput, '') = ''
            SET @searchInput = NULL

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

        DROP TABLE IF EXISTS #warehouse;

        SELECT warehouseId, CASE WHEN locNo = [label] THEN locNo ELSE locNo + ' - ' + [label] END as warehouse
        INTO #warehouse
        FROM md_Warehouse
        WHERE companyId =  @companyId
            AND (warehouseId = @warehouseId OR @warehouseId IS NULL)

        DROP TABLE IF EXISTS #woSearch;     

        CREATE TABLE #woSearch(workOrderHeaderId BIGINT);
        
        IF @searchInput IS NOT NULL
        BEGIN
			SET @searchInput = LTRIM(RTRIM(@searchInput));

            -- search using workOrderName
            INSERT INTO #woSearch(workOrderHeaderId)
            SELECT workOrderHeaderId
            FROM workOrderHeader
            WHERE workOrderName LIKE '%' + @searchInput + '%'
                AND companyId = @companyId

            -- search using modelNo
            DROP TABLE IF EXISTS #inventory;

            SELECT invId 
            INTO #inventory
            FROM md_inventory 
            WHERE companyId = @companyId AND modelNo LIKE '%' + @searchInput + '%'

            INSERT INTO #woSearch(workOrderHeaderId)
            SELECT workOrderHeaderId
            FROM workOrderLineItem wli
                INNER JOIN #inventory li
                    ON wli.invId = li.invId
 
            INSERT INTO #woSearch(workOrderHeaderId)
            SELECT workOrderHeaderId
            FROM workOrderLineItem wli
            WHERE soName LIKE '%' + @searchInput + '%'
       
        END
        ELSE
        BEGIN
            INSERT INTO #woSearch(workOrderHeaderId)
            SELECT workOrderHeaderId
            FROM workOrderHeader wo
            WHERE wo.companyId = @companyId
                AND (wo.workOrderStatus = @workOrderStatus OR @workOrderStatus IS NULL) 
                AND (wo.warehouseId = @warehouseId OR @warehouseId IS NULL) 

        END 


        DROP TABLE IF EXISTS #woInfo;

        SELECT DISTINCT wo.workOrderHeaderId, customerId, CAST('' as VARCHAR(200)) as customerName, workOrderName, revision, workOrderDate, thirdParty, wo.warehouseId, CAST('' as VARCHAR(100)) warehouse, targetCompleteDate,
            shipDate, workOrderNote, workOrderStatus as workOrderStatusId, CAST('' as VARCHAR(50)) as workOrderStatus, 0 as uniqueSkuCount, 0 as totalQty, CAST('' as VARCHAR(MAX)) as soName
        INTO #woInfo
        FROM workOrderHeader wo
            INNER JOIN #woSearch ws 
                ON wo.workOrderHeaderId = ws.workOrderHeaderId

		UPDATE #woInfo SET 
			warehouse = wh.label
		FROM md_warehouse wh
		WHERE #woInfo.warehouseId = wh.warehouseId

		UPDATE #woInfo SET 
			workOrderStatus = mc.categoryName
		FROM md_MasterCategory mc
		WHERE #woInfo.workOrderStatusId = mc.categoryId

		UPDATE #woInfo SET 
			customerName = cs.customerShortCode + (CASE WHEN ISNULL(thirdParty, '') <> '' THEN ' /' + thirdParty ELSE '' END)
		FROM md_customer cs
		WHERE #woInfo.customerId = cs.customerId

        DROP TABLE IF EXISTS #woItem;

        SELECT wo.workOrderHeaderId, workOrderLineItemId, li.soName, invId, confirmQty
        INTO #woItem
        FROM workOrderLineItem li
            INNER JOIN #woInfo wo
                ON li.workOrderHeaderId = wo.workOrderHeaderId

        DROP TABLE IF EXISTS #woDetails;

		UPDATE #woInfo SET
			uniqueSkuCount = g.uniqueSkuCount,
			totalQty = g.totalQty
		FROM (
			SELECT workOrderHeaderId, COUNT(DISTINCT invId) as uniqueSkuCount, SUM(confirmQty) as totalQty
			FROM #woItem
			GROUP BY workOrderHeaderId
		) g
		WHERE #woInfo.workOrderHeaderId = g.workOrderHeaderId

		UPDATE #woInfo SET
			soName = g.soName
		FROM (
			SELECT workOrderHeaderId, STRING_AGG(soName, ';' + CHAR(13) + CHAR(10) ) AS soName
			FROM (SELECT DISTINCT workOrderHeaderId, soName
				  FROM #woItem) g
			GROUP BY workOrderHeaderId
		) g
		WHERE #woInfo.workOrderHeaderId = g.workOrderHeaderId

        DROP TABLE IF EXISTS #listing;

        SELECT wo.workOrderHeaderId, workOrderName, revision, customerName, workOrderDate, warehouse, targetCompleteDate, shipDate, soName, uniqueSkuCount, totalQty, workOrderStatus,              
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN workOrderName END DESC,
                CASE @sortOrder WHEN'1A' THEN workOrderName END ASC,
                CASE @sortOrder WHEN '3D' THEN workOrderDate END DESC,
                CASE @sortOrder WHEN'3A' THEN workOrderDate END ASC,
                CASE @sortOrder WHEN '5D' THEN warehouse END DESC,
                CASE @sortOrder WHEN'5A' THEN warehouse END ASC,
                CASE @sortOrder WHEN '6D' THEN targetCompleteDate END DESC,
                CASE @sortOrder WHEN'6A' THEN targetCompleteDate END ASC,
                CASE @sortOrder WHEN '7D' THEN shipDate END DESC,
                CASE @sortOrder WHEN'7A' THEN shipDate END ASC,            
                CASE @sortOrder WHEN '10D' THEN workOrderStatus END DESC,
                CASE @sortOrder WHEN'10A' THEN workOrderStatus END ASC 
                 ) as rowNo, 0 as totalRecord
        INTO #listing
        FROM #woInfo wo


        DROP TABLE IF EXISTS #isBell;

        SELECT DISTINCT sourceRecordId
		INTO #isBell
        FROM actionNotification ac
            INNER JOIN notificationRecipient n
                ON ac.actionNotificationID = n.notificationID
        WHERE corporateId = @companyId 
            AND sourceModule = @CDCModule
			AND n.userId = @userId
			AND isRead = 0

		UPDATE #listing SET
			totalRecord = g.ttlRecord
		FROM (SELECT COUNT(1) as ttlRecord FROM #listing) g

        SELECT workOrderHeaderId, workOrderName, customerName, revision, workOrderDate, warehouse, targetCompleteDate, shipDate, soName, uniqueSkuCount, totalQty, workOrderStatus, rowNo, totalRecord
			, CASE WHEN lb.sourceRecordId IS NULL THEN 0 ELSE 1 END as isBellAlert
        FROM #listing ls
			LEFT JOIN #isBell lb
				ON ls.workOrderHeaderId = lb.sourceRecordId
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

