-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-21
-- Description:	Add default 0 warehouse balance qty for NEW inventory 
-- Used By:		Inventory Module -> import/create inventory

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-21	1.0			ZY Wong		Initial
-- =============================================
-- EXEC [SSP_Inventory_InsertWarehouseBalance] 1
CREATE PROCEDURE [dbo].[SSP_Inventory_InsertWarehouseBalance] 
@enterBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
				
		--DECLARE @updateBy INT = 1
		
		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #newInvList;

		SELECT inv.companyId, wh.warehouseId, inv.invId, 0 as balanceQty, 0 as lockQty
		INTO #newInvList
		FROM md_Inventory inv
			INNER JOIN md_Warehouse wh
				ON inv.companyId = wh.companyId
			LEFT JOIN inventoryBalanceWH bal
				ON inv.invId = bal.invId
				AND wh.warehouseId = bal.warehouseId
		WHERE bal.invBalanceId IS NULL
			AND bal.warehouseId IS NULL

		IF (SELECT COUNT(*) FROM #newInvList) > 0
		BEGIN
			INSERT INTO inventoryBalanceWH (warehouseId, companyId, invId, balanceQty, lockQty, createBy, createDate, updateBy, updateDate)
			SELECT warehouseId, companyid, invId, balanceQty, lockQty, @enterBy, getdate(), @enterBy, getdate()
			FROM #newInvList
		END

		--SELECT '_SUCCESS_' as status, 'Default warehouse balance qty 0  was created for all new inventory.' as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

