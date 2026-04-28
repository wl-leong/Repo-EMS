-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-15
-- Used By:	    EMS -> PO Module -> PO Listing -> View PO Item Details

-- Description : List of PO Item details

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-15	1.0			ZY Wong	    Initial
-- ==========================================================================================
-- EXEC [SSP_PurchaseOrder_SelectPoItemDetails] 5
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SelectPoItemDetails]
@poId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
		
        --DECLARE @poId BIGINT = 10143

        SELECT poDetailsId, poItemDesc as productName, p.supplierSku, invId, currencyCode, unitPrice, qty, rcvQty, itemNote, itemStatus, homeCurrencyCost, 
            CONVERT(NUMERIC(18,2), (unitPrice * qty)) as totalPrice, qty-rcvQty as tobeRcvQty
        FROM poLineItem p
        WHERE poId = @poId
 

END

GO

