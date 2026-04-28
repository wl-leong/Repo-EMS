-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-08-29
-- Description:	Select inventory details
-- Used By:		Inventory > Inventory Catalog

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-08-29	1.0			ZY Wong		Initial version
-- =============================================
-- [SSP_Inventory_SelectInventoryDetails] 22642
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectInventoryDetails] 
@invId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

        --DECLARE @invId INT = 22671;

        DROP TABLE IF EXISTS #inventory;

        SELECT invId, companyId, itemCode, productCategory, productSubCategory, productType, 
            modelNo, inventorySku, productName, itemDesc, productPrice, grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, 
            cbm, measurement, glCode, 
            CASE WHEN isVirtual = 1 THEN 'YES' ELSE 'NO' END as virtualProduct,
            CASE WHEN inv.isBuffer = 1 THEN 'YES' ELSE 'NO' END as [Buffer]
        INTO #inventory
        FROM md_Inventory inv
        WHERE invId = @invId 

        ALTER TABLE #inventory ADD prodCategory VARCHAR(255);
        ALTER TABLE #inventory ADD prodSubCategory VARCHAR(255);
        ALTER TABLE #inventory ADD prodType VARCHAR(255);
        ALTER TABLE #inventory ADD measurements VARCHAR(10);

        UPDATE inv SET
            prodCategory = pc.prodCategoryName
        FROM #inventory inv
            INNER JOIN md_InventoryCategory pc
                ON inv.productCategory = pc.prodCategoryId
                AND inv.companyId = pc.companyId
                AND pc.prodCategoryParentID = 1  -- product category
                AND pc.status = 1

        UPDATE inv SET
            prodSubCategory = psc.prodCategoryName
        FROM #inventory inv
            INNER JOIN md_InventoryCategory psc
                ON inv.productSubCategory = psc.prodCategoryId
                AND inv.companyId = psc.companyId
                AND inv.productCategory = psc.prodCategoryParentID  -- product sub category
                AND psc.status = 1

        UPDATE inv SET
             prodType = pt.inventoryType
        FROM #inventory inv
            INNER JOIN md_inventoryType pt
                ON inv.productType = pt.inventoryTypeId
                AND inv.productSubCategory = pt.prodCategoryId  -- product type
                AND pt.status = 1

        UPDATE inv SET
            measurements = ms.categoryName
        FROM #inventory inv
            INNER JOIN md_MasterCategory ms
                ON inv.measurement = ms.categoryId  
                AND ms.categoryParentID = 1069  -- measurement
                AND ms.status = 1

        SELECT invId, itemCode, prodCategory, prodSubCategory, prodType, modelNo, inventorySku, productName, itemDesc, productPrice, 
            grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, 
            cbm, measurements, glCode, virtualProduct, [Buffer]
        FROM #inventory

END

GO

