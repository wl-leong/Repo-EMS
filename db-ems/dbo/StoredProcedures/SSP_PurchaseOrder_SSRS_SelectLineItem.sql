-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-07
-- Used By:	    EMS -> PO Module -> PO Listing -> Export PO pdf ssrs
--
-- Description : Export Purchase Order report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-27   6.0         ZY Wong     (Exchange) Use itemReference1 as customerSku, use merchantsSku as merchantSku
-- 2025-05-21   5.0         ZY Wong     Use merchantsSku as customerSku, use itemReference1 as merchantSku
-- 2024-11-18   4.0         ZY Wong     Remove #itemInfo temp table & simplify code from #itemInfo
-- 2024-08-28   3.0         WL Leong	Cancel item also shows
-- 2024-06-20   2.0         ZY Wong     Change currencyCode get from md_supplier
-- 2024-05-07	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_PurchaseOrder_SSRS_SelectLineItem] 16
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SSRS_SelectLineItem]
@poId BIGINT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    --DECLARE @poId BIGINT = 16

    DROP TABLE IF EXISTS #poItem;

    SELECT poDetailsId, soLineItemId, invId, supplierSku, itemReference1 as merchantSku, itemReference1 as customerSKu, poItemDesc, qty, CONVERT(NUMERIC(13,5), unitPrice) as unitPrice, supplierId, p.poNote
    INTO #poItem
    FROM poLineItem pl
        INNER JOIN poHeader p
            ON pl.poId = p.poId
    WHERE pl.poId = @poId

    ALTER TABLE #poItem ADD currencyCode INT;
    ALTER TABLE #poItem ADD currency VARCHAR(3);
    ALTER TABLE #poItem ADD color VARCHAR(50);
    ALTER TABLE #poItem ADD packaging VARCHAR(50);

    UPDATE #poItem SET
        currencyCode = s.currencyCode
    FROM md_Supplier s
    WHERE #poItem.supplierId = s.supplierId

    UPDATE #poItem SET
        currency = cr.categoryName
    FROM md_MasterCategory cr
    WHERE #poItem.currencyCode = cr.categoryId

    UPDATE #poItem SET 
        color = cl.value
    FROM (SELECT invId, value FROM inventory_attributes WHERE categoryId IN (3194)) cl
    WHERE #poItem.invId = cl.invId
         
    UPDATE #poItem SET 
        packaging = cl.value
    FROM inventory_attributes cl
    WHERE #poItem.invId = cl.invId
            AND cl.categoryId = 1123 -- packagingType

    SELECT ROW_NUMBER() OVER(ORDER BY soLineItemId) as itemNo, supplierSku, merchantSku, poItemDesc, customerSku, color, packaging, 
        qty, unitPrice, currency, poNote
    FROM #poItem p
    
END

GO

