-- =============================================
-- Author:		WL Leong
-- Create date: 2024-05-05
-- Used By:	    EMS -> SO Module -> SO Listing -> SO PDF/ PI PDF
--
-- Description : Show list of sales order item based on soHeaderId
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-09-08	9.0			ZY Wong		Get packaging from md_CustomerSkuPackagingMaterial
-- 2025-09-24   8.0         ZY Wong     Add @userId & @companyId & @menu2Id to control cost permission
-- 2024-05-06   7.0         ZY Wong     Use itemReference2 as EAN
-- 2024-11-18   6.0         ZY Wong     Change get color from inventory_attributes where categoryId in (19, 3194)
-- 2024-08-28   5.0         WL Leong	Cancel item also shows
-- 2024-07-01   4.0         ZY Wong     Add EAN from md_customerSku - used by factory ver pdf
-- 2024-06-26   3.0         WL Leong	Remove odrQty = 0
-- 2024-06-13   2.0         ZY Wong     Filter out cancel item
-- 2024-05-05	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_SalesOrder_SSRS_SelectLineItem] 20817, 'SO', 1, 11, 3059
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectLineItem]
@soHeaderId BIGINT,
@module VARCHAR(2),
@userId INT,
@companyId INT,
@menu2Id INT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

/* Start: set permission */
        DECLARE @permission TABLE(functionAdd BIT, functionEdit BIT, functionDelete BIT);
		DECLARE @pricePremission BIT = 0;

		INSERT INTO @permission(functionAdd, functionEdit, functionDelete)
		SELECT functionAdd, functionEdit, functionDelete
		FROM dbo.userPermission(@userId , @companyId, @menu2Id)

        SET @pricePremission = (SELECT TOP 1 functionAdd FROM @permission);
/* End: set permission */

        DROP TABLE IF EXISTS #soLineItem;

        SELECT soLineItemId, invId, customerSkuId, customerSku, merchantSku, currencyCode, 
            CASE WHEN @pricePremission = 1 THEN csCost ELSE 0 END as csCost, 
            odrQty, soItemDesc, itemReference2 as EAN
        INTO #soLineItem
        FROM soLineItem s
        WHERE soHeaderId = @soHeaderId
            --AND soLineItemStatus <> 1107  -- cancel
            --AND odrQty > 0
    
        ALTER TABLE #soLineItem ADD color VARCHAR(50);
		ALTER TABLE #soLineItem ADD packagingMaterialInvId BIGINT;
        ALTER TABLE #soLineItem ADD packagingType VARCHAR(50);
        ALTER TABLE #soLineItem ADD modelNo VARCHAR(50);
        ALTER TABLE #soLineItem ADD itemCode VARCHAR(50);
        ALTER TABLE #soLineItem ADD HTSCode VARCHAR(20);
        ALTER TABLE #soLineItem ADD prodCategoryId INT;
        ALTER TABLE #soLineItem ADD prodSubCategoryId INT;
        ALTER TABLE #soLineItem ADD prodCategory VARCHAR(50);
        ALTER TABLE #soLineItem ADD soNotes VARCHAR(100);

        UPDATE #soLineItem SET
            soNotes = s.soNote
        FROM soHeader s
        WHERE s.soHeaderId = @soHeaderId
 
        UPDATE #soLineItem SET
            modelNo = inv.inventorySku,
            itemCode = inv.itemCode,
            prodCategoryId = inv.productCategory,
            prodSubCategoryId = inv.productSubCategory
        FROM md_inventory inv
        WHERE #soLineItem.invId = inv.invId
 
        UPDATE #soLineItem SET 
            color = cl.value
        FROM inventory_attributes cl
        WHERE #soLineItem.invId = cl.invId
                AND cl.categoryId = 3194 -- color
         
        UPDATE #soLineItem SET 
            packagingMaterialInvId = pm.packagingMaterialInvId
        FROM md_CustomerSkuPackagingMaterial pm
        WHERE #soLineItem.customerSkuId = pm.customerSkuId

		UPDATE #soLineItem SET 
            packagingType = inv.productName
        FROM md_Inventory inv
        WHERE #soLineItem.packagingMaterialInvId = inv.invId
 
        UPDATE #soLineItem SET
            HTSCode = c.HTSCode
        FROM md_inventoryHTSCode c
        WHERE  #soLineItem.prodCategoryId = c.HTSCode_prodCategoryId
 
        UPDATE #soLineItem SET
            prodCategory = pro.prodCategoryName
        FROM  md_inventoryCategory pro
        WHERE #soLineItem.prodCategoryId = pro.prodCategoryId

        SELECT soLineItemId, invId, customerSkuId, customerSku, EAN, merchantSku, currencyCode, csCost, odrQty, soItemDesc, ROUND(csCost * odrQty, 2) as amount,
            color, packagingType, modelNo, itemCode, HTSCode, soNotes, prodCategory as prodSubCategory, ROW_NUMBER() OVER  (ORDER BY soLineItemId) as rowNo
        FROM #soLineItem
 
END

GO