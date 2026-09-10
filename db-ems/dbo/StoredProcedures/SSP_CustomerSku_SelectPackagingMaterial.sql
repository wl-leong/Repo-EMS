-- =============================================
-- Author:		ZY Wong
-- Create date: 2026-09-10
-- Description:	Select list of packaging material based on customer sku
-- Used By:		EMS -> Customer Module -> Edit Customer Sku -> Packaging Material Listing

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-09-10	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_CustomerSku_SelectPackagingMaterial] 6, 712
CREATE PROCEDURE [dbo].[SSP_CustomerSku_SelectPackagingMaterial]
@companyId INT,
@customerSkuId INT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

		--DECLARE @companyId INT = 6, @customerSkuId INT = 712;

		DROP TABLE IF EXISTS #packaging;

		SELECT customerSkuPackagingMaterialId, customerSkuId, packagingMaterialInvId, unitsPerpackagingMaterial
		INTO #packaging
		FROM md_CustomerSkuPackagingMaterial
		WHERE customerSkuId = @customerSkuId
			AND statusFlag = 1

		ALTER TABLE #packaging ADD packagingMaterial VARCHAR(255);

		UPDATE pm SET
			packagingMaterial = inv.productName
		FROM #packaging pm
			INNER JOIN md_Inventory inv
				ON pm.packagingMaterialInvId = inv.invId
		WHERE inv.companyId = @companyId
			AND inv.status = 1

		SELECT customerSkuPackagingMaterialId, customerSkuId, packagingMaterialInvId, packagingMaterial, unitsPerpackagingMaterial
		FROM #packaging
		ORDER BY packagingMaterial

END

GO