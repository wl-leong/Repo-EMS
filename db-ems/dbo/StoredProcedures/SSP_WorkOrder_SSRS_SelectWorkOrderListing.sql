-- =============================================
-- Author:		ZY Wong
-- Create date: 2026-08-14
-- Description: Select list of work order with item details within selected work order date range for specified customer
-- Used By:		EMS -> Report Module -> Operation -> Work Order -> Work Order Listing

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-08-14	1.0			ZY Wong 	Initial version
-- ==========================================================================================
-- EXEC [SSP_WorkOrder_SSRS_SelectWorkOrderListing] 4, '2025-01-01', '2025-10-01', '29, 19, 37, 6'
CREATE PROCEDURE [dbo].[SSP_WorkOrder_SSRS_SelectWorkOrderListing]
@companyId INT,
@workOrderStartDate DATE,
@workOrderEndDate DATE,
@customerId VARCHAR(MAX)
AS 
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

		-- DECLARE @companyId INT = 4, @workOrderStartDate DATE = '2025-01-01', @workOrderEndDate DATE = '2025-10-01', @customerId VARCHAR(MAX) = '29, 19, 37, 6';

		DROP TABLE IF EXISTS #customerList;

		SELECT [value] as customerId
		INTO #customerList
		FROM STRING_SPLIT(@customerId, ',')
		
		DROP TABLE IF EXISTS #woList;

		SELECT wo.workOrderHeaderId, wo.workOrderName, wo.workOrderDate, DATEADD(DAY, -8, shipDate) as cargoReadyDate, wo.shipDate as deliveryDate, wo.targetCompleteDate, wo.workOrderStatus as workOrderStatusId, wo.customerId, wo.warehouseId
		INTO #woList
		FROM workOrderHeader wo
			INNER JOIN #customerList cs
				ON wo.customerId = cs.customerId
		WHERE companyId = @companyId
			AND workOrderDate BETWEEN @workOrderStartDate AND @workOrderEndDate

		ALTER TABLE #woList ADD customerName VARCHAR(100);
		ALTER TABLE #woList ADD workOrderStatus VARCHAR(50);
		ALTER TABLE #woList ADD warehouse VARCHAR(100);

		UPDATE #woList SET
			customerName = cs.customerName
		FROM md_Customer cs
		WHERE #woList.customerId = cs.customerId
			--AND cs.[status] = 1

		UPDATE #woList SET
			workOrderStatus = ct.categoryName
		FROM md_MasterCategory ct
		WHERE #woList.workOrderStatusId = ct.categoryId 
			--AND ct.[status] = 1

		UPDATE #woList SET
			warehouse = CASE WHEN ISNULL(wh.locNo,'') = '' THEN wh.[label] ELSE wh.locNo END
		FROM md_Warehouse wh
		WHERE #woList.warehouseId = wh.warehouseId
			--AND wh.[status] = 1

		DROP TABLE IF EXISTS #woItems;

		SELECT wo.workOrderHeaderId, woli.workOrderLineItemId, woli.soHeaderId, woli.soName, woli.soLineItemId, 
			woli.invId, woli.confirmQty, woli.workOrderItemStatus as workOrderItemStatusId,
			soli.customerSku, soli.merchantSku, soli.itemReference1 as customerModelNo, soli.itemReference2 as EAN, soli.soItemDesc as itemDesc
		INTO #woItems
		FROM workOrderLineItem woli
			INNER JOIN #woList wo
				ON woli.workOrderHeaderId = wo.workOrderHeaderId
			INNER JOIN soLineItem soli
				ON woli.soLineItemId = soli.soLineItemId	

		ALTER TABLE #woItems ADD modelNo VARCHAR(50);
		ALTER TABLE #woItems ADD customerPo VARCHAR(50);
		ALTER TABLE #woItems ADD thirdPartyPo VARCHAR(500);
		ALTER TABLE #woItems ADD portId INT;
		ALTER TABLE #woItems ADD POD VARCHAR(50);
		ALTER TABLE #woItems ADD color VARCHAR(50);
		ALTER TABLE #woItems ADD workOrderItemStatus VARCHAR(50);

		UPDATE #woItems SET
			modelNo = inv.inventorySku
		FROM md_Inventory inv
		WHERE #woItems.invId = inv.invId

		UPDATE #woItems SET
			customerPo = so.customerPo,
			thirdPartyPo = so.thirdPartyPo,
			portId = so.portOfDestination
		FROM soHeader so
		WHERE #woItems.soHeaderId = so.soHeaderId

		UPDATE #woItems SET
			POD = pt.portName
		FROM md_Port pt
		WHERE #woItems.portId = pt.portId

		UPDATE #woItems SET 
			color = cl.[value]
		FROM (
			SELECT invId, [value] 
			FROM inventory_attributes 
			WHERE categoryId IN (3194) -- colour name
			) cl
		WHERE #woItems.invId = cl.invId

		UPDATE #woItems SET
			workOrderItemStatus = ct.categoryName
		FROM md_MasterCategory ct
		WHERE #woItems.workOrderItemStatusId = ct.categoryId 
			--AND ct.[status] = 1

		SELECT wo.workOrderName, wo.workOrderDate, wo.cargoReadyDate, wo.deliveryDate, wo.targetCompleteDate, wo.customerName, wo.warehouse, wo.workOrderStatus,
			li.soName, li.customerPo, li.POD, li.thirdPartyPo, li.modelNo, li.customerSku, li.EAN, li.customerModelNo, li.merchantSku, li.itemDesc, color, confirmQty, workOrderItemStatus
		FROM #woList wo
			INNER JOIN #woItems li
				ON wo.workOrderHeaderId = li.workOrderHeaderId
		ORDER BY wo.workOrderDate, wo.workOrderName, li.soName, li.modelNo
END

GO