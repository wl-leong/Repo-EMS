
-- =============================================
-- Author:		WL Leong
-- Create date: 2024-02-01
-- Used By:	    EMS -> Order Process -> LR Receive

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-08	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_OrderProcess_DetailsListing 1
CREATE PROCEDURE [dbo].[SSP_OrderProcess_DetailsListing]   
@opId BIGINT 
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

		DECLARE @companyId INT;

		DROP TABLE IF EXISTS #orderProcess;
 
		SELECT @companyId = companyId
		FROM orderProcess 
		WHERE opId = @opId

		DROP TABLE IF EXISTS #invBalance;

		SELECT bal.invId, inv.inventorySku, SUM(balanceQty) as whbalanceQty, grossWeight, cbm
		INTO #invBalance
		FROM inventoryBalanceWH bal
			INNER JOIN md_inventory inv
				ON bal.invId = inv.invId
		WHERE bal.companyId = @companyId
		GROUP BY bal.invId, inv.inventorySku, grossWeight, cbm

		SELECT li.opLineItemId,  bal.inventorySku, li.customerSku, li.merchantSku, li.itemReference1, li.loadingQty as requestLoadingQty, li.confirmQty,
			SUM(li.loadingQty * grossWeight) as ttlGrossWeight, SUM(li.loadingQty * cbm) as ttlCbm, bal.whBalanceQty
		FROM orderProcessLineItem li
			INNER JOIN soLineItem so
				ON li.soLineItemId = so.soLineItemId
			LEFT JOIN #invBalance bal
				ON so.invId = bal.invId
		WHERE li.opId = @opId
		GROUP BY li.opLineItemId,  bal.inventorySku, li.customerSku, li.merchantSku, li.itemReference1, li.loadingQty, li.confirmQty, bal.whBalanceQty
END

GO

