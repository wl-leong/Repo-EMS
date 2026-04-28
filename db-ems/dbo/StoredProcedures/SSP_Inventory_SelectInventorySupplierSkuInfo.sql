-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-08-29
-- Description:	Select inventory supplier list & info
-- Used By:		Inventory > Inventory Catalog

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-08-29	1.0			ZY Wong		Initial version
-- =============================================
-- [SSP_Inventory_SelectInventorySupplierSkuInfo] 505
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectInventorySupplierSkuInfo] 
@invId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

        --DECLARE @invId INT = 505;

        DROP TABLE IF EXISTS #supplierSkuInfo;

        SELECT supplierskuId, invId, supplierId, supplierSku, itemDesc, currencyCode as currencyCodeId, supCost, MOQ, 
            CASE WHEN isDefault = 1 THEN 'YES' ELSE 'NO' END as isDefault,
            CASE WHEN statusflag = 1 THEN 'ACTIVE' ELSE 'INACTIVE' END as [status]
        INTO #supplierSkuInfo
        FROM md_SupplierSku 
        WHERE invId = @invId 

        ALTER TABLE #supplierSkuInfo ADD supplierName VARCHAR(255);
        ALTER TABLE #supplierSkuInfo ADD currencyCode VARCHAR(3);

        UPDATE sku SET
            supplierName = sup.supplierCompanyName
        FROM #supplierSkuInfo sku
            INNER JOIN md_Supplier sup
                ON sku.supplierId = sup.supplierId
                --AND sup.status = 1

        UPDATE sku SET
            currencyCode = cr.categoryName
        FROM #supplierSkuInfo sku 
            INNER JOIN md_MasterCategory cr
                ON sku.currencyCodeId = cr.categoryId
                AND cr.categoryParentID = 1119  -- currency
                AND cr.status = 1

        SELECT supplierskuId, invId, supplierName, supplierSku, itemDesc, currencyCode, supCost, MOQ, isDefault, [status]
        FROM #supplierSkuInfo

END

GO

