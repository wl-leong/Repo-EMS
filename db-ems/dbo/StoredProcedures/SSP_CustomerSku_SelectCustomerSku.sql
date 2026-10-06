-- =============================================
-- Author:		ZY Wong
-- Create date: 2026-10-06
-- Description:	Select list of active customer sku based on customer 
-- Used By:		EMS -> Customer Module -> Customer Sku -> List Customer Sku

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-10-06	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_CustomerSku_SelectCustomerSku] 11, 26
CREATE PROCEDURE [dbo].[SSP_CustomerSku_SelectCustomerSku]
@companyId INT,
@customerId INT = NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

		--DECLARE @companyId INT = 11, @customerId INT = 26;

		DROP TABLE IF EXISTS #skuList;

		SELECT customerId, customerSkuId, invId, itemDesc, customerSku, merchantSku, csCost
		INTO #skuList
		FROM md_CustomerSku
		WHERE companyId = @companyId
			AND (ISNULL(@customerId, 0) = 0 OR customerId = @customerId)
			AND statusFlag = 1

		ALTER TABLE #skuList ADD customerName VARCHAR(100);
		ALTER TABLE #skuList ADD inventorySku VARCHAR(50);
		ALTER TABLE #skuList ADD productName VARCHAR(255);

		UPDATE #skuList SET
			customerName = cs.customerName
		FROM md_Customer cs
		WHERE #skuList.customerId = cs.customerId

		UPDATE #skuList SET
			inventorySku = inv.inventorySku,
			productName = inv.productName,
			itemDesc = CASE WHEN #skuList.itemDesc = '' THEN inv.itemDesc ELSE #skuList.itemDesc END
		FROM md_Inventory inv
		WHERE #skuList.invId = inv.invId

		DROP TABLE IF EXISTS #packaging;

		SELECT pm.customerSkuId, pm.productQty, pm.packagingMaterialInvId, pm.unitsPerpackagingMaterial
		INTO #packaging
		FROM md_CustomerSkuPackagingMaterial pm
			INNER JOIN #skuList l
				ON pm.customerSkuId = l.customerSkuId

		ALTER TABLE #packaging ADD packagingMaterial VARCHAR(255);

		UPDATE pm SET
			packagingMaterial = inv.productName
		FROM #packaging pm
			INNER JOIN md_Inventory inv
				ON pm.packagingMaterialInvId = inv.invId
		WHERE inv.companyId = @companyId
			AND inv.status = 1

		SELECT customerName, inventorySku as productSku, productName, itemDesc as itemDescription, customerSku, merchantSku, csCost, pm.packagingMaterial, pm.productQty, pm.unitsPerpackagingMaterial
		FROM #skuList l
			LEFT JOIN #packaging pm
				ON l.customerSkuId = pm.customerSkuId
		ORDER BY customerName, inventorySku, customerSku

END

GO