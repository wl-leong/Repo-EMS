-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order inventory dropdown

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-14	1.0			WL Leong	CustomerSku dropdown
-- ==========================================================================================
/**
EXEC SSP_SalesOrder_AddOrderLineItem
N'{
	"soItemList": [
		{
			"soHeaderId": 21263,
			"soLineItemId": 0,
			"customerSkuId": "597",
			"customerSku": "BH5336278612105",
			"odrQty": 60,
			"freightCost": 0,
			"itemCost": "39.6071",
			"itemNote": "",
            "tagDivision": "3231"
		}
	]
}'
, 1

select* from md_customersku where companyId = 11
**/
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectCustomerSkuDropdown]
@inventoryCategory INT,
@inventorySubCategory INT,
@inventoryType INT,
@customerId INT,
@companyId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
 
		SELECT customerSkuId, productCategory, productSubCategory, productType, 
			customerSku + ' ( ' + inventorySku + ' )' as inventory, currencyCode, csCost, merchantSku
		FROM (
			SELECT customerSkuId, customerSku, merchantSku, csCost,  mc.categoryName as currencyCode,
				ISNULL(sk.itemDesc, inv.productName) as itemDesc, inv.inventorySku, productCategory, productSubCategory, productType
			FROM md_customerSku sk
				INNER JOIN md_inventory inv
					ON sk.invId = inv.invId
					AND inv.status = 1
				INNER JOIN md_masterCategory mc
					ON sk.currencyCode = mc.categoryId
			WHERE sk.companyId = @companyId
				AND sk.customerId = @customerId
				AND sk.statusflag = 1
				AND inv.productCategory = @inventoryCategory
				AND inv.productSubCategory = @inventorySubCategory
				AND inv.productType = @inventoryType
		) g
 
 
		RETURN 0
	END TRY

	BEGIN CATCH
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

