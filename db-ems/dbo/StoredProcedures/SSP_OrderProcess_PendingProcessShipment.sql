
-- =============================================
-- Author:		WL Leong
-- Create date: 2024-02-01
-- Used By:	    EMS -> Order Process -> LR Receive

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-08	3.0			WL Leong	Add new column
-- 2024-02-06	2.0			WL Leong	Change to based on orderProcess
-- 2024-02-01	1.0			WL Leong	Initial
-- ==========================================================================================

CREATE PROCEDURE [dbo].[SSP_OrderProcess_PendingProcessShipment]  
@companyId INT 
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

		--DECLARE @companyId INT = 4;

		DROP TABLE IF EXISTS #orderProcess;

		SELECT opId, cs.customerName, lrName, lrShipDate, lrContainerType
		INTO  #orderProcess
		FROM orderProcess op
			INNER JOIN md_customer cs
				ON op.customerId = cs.customerId
		WHERE opStatus = 2142

		DROP TABLE IF EXISTS #invBalance;

		SELECT inv_invId, inv.inventorySku, SUM(inv_balanceQty) as whbalanceQty, grossWeight, cbm
		INTO #invBalance
		FROM inventoryBalanceWH bal
			INNER JOIN md_inventory inv
				ON bal.inv_invId = inv.invId
		WHERE invBalance_companyId = @companyId
		GROUP BY inv_invId, inv.inventorySku, grossWeight, cbm

		SELECT li.opLineItemId, op.customerName, op.lrName, st.shipToLabel, sod.earlyShipDate, sod.lateShipDate, ISNULL(ct.categoryName,'') as lrContainerTYpe, 
			sod.soName, sod.customerPo, bal.inventorySku, li.customerSku, li.merchantSku, li.itemReference1, (so.odrQty - so.shpQty) as soPendingQty, li.loadingQty as requestLoadingQty, li.confirmQty,
			SUM(li.loadingQty * grossWeight) as ttlGrossWeight, SUM(li.loadingQty * cbm) as ttlCbm, bal.whBalanceQty
		FROM #orderProcess op
			INNER JOIN orderProcessLineItem li
				ON op.opId = li.opId
			INNER JOIN soLineItem so
				ON li.soLineItemId = so.soLineItemId
			INNER JOIN soHeader sod
				ON so.soheaderId = sod.soHeaderId
			INNER JOIN md_ShipToDestination st
				ON sod.shipToid = st.shipToId
			LEFT JOIN #invBalance bal
				ON so.invId = bal.inv_invId
			LEFT JOIN md_MasterCategory ct
				ON op.lrContainerType = ct.categoryId
		GROUP BY li.opLineItemId, op.customerName, op.lrName, st.shipToLabel, sod.earlyShipDate, sod.lateShipDate, ct.categoryName, sod.soName, sod.customerPo, bal.inventorySku, li.customerSku, li.merchantSku, li.itemReference1, 
			li.loadingQty, bal.whBalanceQty, so.odrQty, so.shpQty, li.confirmQty

END

GO

