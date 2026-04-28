-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-14
-- Used By:	    EMS -> PO Module -> Export PDF 

-- Description : List of PO pdf details (for marketing)

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-15	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_PurchaseOrder_SelectPdfItemDetails] 1
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SelectPdfItemDetails]
@poId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		
		--DECLARE @poId BIGINT = 10141;
        DECLARE @supplierId INT, @poNote varchar(5000)

        SELECT @supplierId = supplierId, @poNote = poNote
        FROM poHeader 
        WHERE poId = @poId

        
        DROP TABLE IF EXISTS #poLineItem;

        SELECT poDetailsId, poId, soLineItemId, p.supplierSku, invId, currencyCode, unitPrice, qty, CONVERT(NUMERIC(18,2),(unitPrice * qty)) as amount
        INTO #poLineItem
        FROM poLineItem p
        WHERE poId = @poId
            AND itemStatus <> 1086

        DROP TABLE IF EXISTS #soLineItem;

        SELECT pl.poDetailsId, so.merchantSku as customerModelNo, so.customerSku
        INTO #soLineItem
        FROM #poLineItem pl
            INNER JOIN soLineItem so
                ON pl.soLineItemID = so.soLineitemId


        DROP TABLE IF EXISTS #itemInfo;

        SELECT pl.poDetailsId, pl.invId, CAST('' as VARCHAR(100)) as color, CAST('' as VARCHAR(100)) as packaging, 
            CASE WHEN sk.itemDesc = '' THEN inv.productName ELSE sk.itemDesc END as productName
        INTO #itemInfo
        FROM #poLineItem pl
            INNER JOIN md_supplierSku sk
                ON pl.invId = sk.invId
                AND sk.supplierId = @supplierId
                AND statusFlag = 1
            INNER JOIN md_Inventory inv
                ON pl.invId = inv.invId
               
        UPDATE i SET
            color = inv.[value]
        FROM #itemInfo i
            INNER JOIN inventory_attributes inv
                ON i.invId = inv.invId
                AND inv.categoryId = 19

        UPDATE i SET
            packaging = inv.[value]
        FROM #itemInfo i
            INNER JOIN inventory_attributes inv
                ON i.invId = inv.invId
                AND inv.categoryId = 1123

		SELECT pl.supplierSku as factoryModelNo, sl.customerModelNo, itm.productName, sl.customerSku as vendorStkNo, 
            itm.color, itm.packaging, pl.currencyCode, pl.unitPrice, pl.qty, pl.amount, @poNote as poNote
        FROM #poLineItem pl
            INNER JOIN  #itemInfo itm
                ON pl.poDetailsId = itm.poDetailsId
            LEFT JOIN #soLineItem sl
                ON pl.poDetailsId = sl.poDetailsId

 
 
 

END

GO

