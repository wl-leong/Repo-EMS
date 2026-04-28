-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-26
-- Description:	Listing of warehouse info for specific rawBomInvId(factory)/ invId(marketing)
-- Used By:		Procurement Module -> Pending List -> click on lock qty -> select warehouse dropdown

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-26	1.0			ZY Wong		Initial
-- =============================================
-- EXEC [SSP_Procurement_SelectRawBomWarehouse] 602
CREATE PROCEDURE [dbo].[SSP_Procurement_SelectInventoryWarehouseBalance] 
@invId BIGINT,
@warehouseId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
				
		--DECLARE @invId INT = 602
		
		SELECT bal.invBalanceId, (bal.balanceQty - bal.lockQty) as availableQty
		FROM inventoryBalanceWH bal
			INNER JOIN md_Warehouse wh
				ON bal.warehouseId = wh.warehouseId
		WHERE bal.invId = @invId
			AND bal.warehouseId = @warehouseId

END

GO

