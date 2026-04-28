-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-06-19
-- Description:	Check any existing customerSku/supplierSku before delete inventory 
-- Used By:		Inventory Module > Inventory Listing > Delete
--              Inventory Module > Product Listing > Delete

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-19   1.0         ZY Wong     Initial version
-- =============================================
-- EXEC [SSP_Inventory_DeleteInventory] 1022
CREATE PROCEDURE [dbo].[SSP_Inventory_DeleteInventory] 
@invId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

	BEGIN TRY

        --DECLARE @invId INT = 1022;

        DECLARE @returnMessage VARCHAR(MAX);

        DROP TABLE IF EXISTS #inventory;
        
        SELECT invId, inventorySku, status
        INTO #inventory
        FROM md_Inventory
        WHERE invId = @invId

        IF (SELECT COUNT(1) FROM #inventory WHERE status = 0) > 0
        BEGIN
            SET @returnMessage = (SELECT 'Inventory ' + inventorySku + ' already inactivated.' FROM #inventory);
            THROW 60000, @returnMessage, 1;
        END

        DROP TABLE IF EXISTS #checkCustomerSku;

        SELECT customerSkuId, customerId, customerSku, merchantSku, CAST('' as VARCHAR) as customerShortCode
        INTO #checkCustomerSku
        FROM md_customerSku 
        WHERE invId  = @invId
            AND statusFlag = 1

        UPDATE #checkCustomerSku SET
            customerShortCode = cs.customerShortCode
        FROM md_Customer cs
        WHERE #checkCustomerSku.customerId = cs.customerId

        IF (SELECT COUNT(1) FROM #checkCustomerSku) > 0
        BEGIN
            SET @returnMessage = (SELECT 'Customer SKU ' + customerSku + ' for ' + customerShortCode + ' is active. Please DELETE the customer SKU to proceed.'
                                    FROM (SELECT TOP 1 * FROM #checkCustomerSku)g
                                );
            THROW 60000, @returnMessage, 1;
        END

        DROP TABLE IF EXISTS #checkSupplierSku;

        SELECT supplierSkuId, supplierId, supplierSku, CAST('' as VARCHAR) as supplierName
        INTO #checkSupplierSku
        FROM md_supplierSku 
        WHERE invId  = @invId
            AND statusFlag = 1

        UPDATE #checkSupplierSku SET
            supplierName = sp.supplierCompanyName
        FROM md_Supplier sp
        WHERE #checkSupplierSku.supplierId = sp.supplierId

        IF (SELECT COUNT(1) FROM #checkSupplierSku) > 0
        BEGIN
            SET @returnMessage = (SELECT 'Supplier SKU ' + supplierSku + ' for ' + supplierName + ' is active. Please DELETE the Supplier SKU to proceed.'
                                    FROM (SELECT TOP 1 * FROM #checkSupplierSku)g
                                );
            THROW 60000, @returnMessage, 1;
        END

        BEGIN TRANSACTION

            UPDATE md_Inventory SET
                status = 0,
                UpdateDateTime = GETDATE()
            WHERE invId = @invId

        COMMIT TRANSACTION

        SET @returnMessage = 'Inventory successful deleted.';

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH	 

		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END

        IF @returnMessage IS NULL
            SET @returnMessage = ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @returnMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

