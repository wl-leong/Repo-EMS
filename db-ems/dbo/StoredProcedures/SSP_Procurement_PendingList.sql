
-- =============================================
-- Author:		WL Leong
-- Create date: 2024-02-01
-- Used By:	    EMS -> Procurement -> Pending Listing

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-08	2.0			WL Leong	Remove upc
-- 2024-02-01	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_Procurement_PendingList] 4
CREATE PROCEDURE [dbo].[SSP_Procurement_PendingList]  
@companyId INT
AS
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #procurement;
	--DECLARE @companyId INT = 4

	DROP TABLE IF EXISTS #inventory;

	SELECT invId, inventorySku
	INTO #inventory
	FROM md_Inventory
	WHERE status = 1
		AND companyId = @companyId
 
	SELECT procurementProcessId, soHeaderId, soName, invId, processQty, rawBomInvId, rawBomQty, rawBomTotalQty, poQty, lockQty
	INTO #procurement
	FROM procurementProcess 
	WHERE companyId = @companyId 
		AND status = 0

	DROP TABLE IF EXISTS #processList;

	SELECT procurementProcessId, p.soName, s.earlyShipDate, invId, processQty, rawBomInvId, rawBomQty, rawBomTotalQty, poQty, lockQty
	INTO #processList
	FROM #procurement p
		INNER JOIN soHeader s
			ON p.soHeaderId = s.soHeaderId
	 
	DROP TABLE IF EXISTS #supplierSku;

	SELECT invId, supplierSkuId, supplierId, supCost, moq, ROW_NUMBER() OVER(PARTITION BY invId ORDER BY supCost) rowNo
	INTO #supplierSku
	FROM md_SupplierSku sk
	WHERE companyId = @companyId
		AND statusFlag = 1
 
	DROP TABLE IF EXISTS #warehouseBalance;

	SELECT wh.invId, SUM(balanceQty) as balanceQty, MAX(wh.lockQty) as whlockQty
	INTO #warehouseBalance
	FROM inventoryBalanceWh wh
		INNER JOIN (SELECT DISTINCT rawBomInvId FROM #processList) pl
			ON pl.rawBomInvId = wh.invId
	GROUP BY wh.invId
 
	DROP TABLE IF EXISTS #list;

	SELECT procurementProcessId, supplierId, soName, earlyShipDate as shipDate, inv.inventorySku, processQty, 
		rawBomInvId, rawInv.inventorySku as orderedBom, rawBomQty, rawBomTotalQty, poQty, pl.lockQty, supCost, moq
	INTO #list
	FROM #processList pl
		INNER JOIN #inventory inv
			ON pl.invId = inv.invId
		INNER JOIN #inventory rawinv
			ON pl.rawBomInvId = rawinv.invId
		INNER JOIN #supplierSku sk
			ON pl.rawBomInvId = sk.invId
			AND sk.rowNo = 1
			

	SELECT li.procurementProcessId, li.supplierId, 
			li.soName, shipDate, li.inventorySku, li.processQty, li.rawBomQty, wh.balanceQty, wh.whlockQty as warehouselockqty, 
			li.rawBomInvId, orderedBom, li.rawBomTotalQty - li.poQty as  rawBomTotalQty, sp.supplierCompanyName, li.supCost, li.poQty, li.lockQty, li.moq
	FROM #list li
		INNER JOIN #warehouseBalance wh
			ON li.rawBomInvId = wh.invId
		INNER JOIN MD_Supplier sp
			ON li.supplierId = sp.supplierId

END

GO

