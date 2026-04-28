-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-25
-- Used By:	    EMS -> Shipping Module -> Shipping Listing

-- Description : Show all

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-25	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC [SSP_Shipping_SelectShipmentLineItem] 1
**/

CREATE PROCEDURE [dbo].[SSP_Shipping_SelectShipmentLineItem]
@shipmentId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #shipment;

    SELECT shipmentId, shipId, BOL
    INTO #shipment
    FROM shipmentHeader sh   
    WHERE shipmentId =  @shipmentId

    SELECT sh.shipmentId, sh.shipId, sh.BOL, customerSku, inv.inventorySku, merchantSku, shipmentQty, shipQty, lineItemNotes, lineItemStatus, ct.categoryName as itemStatus, li.shipmentLineItemId
    FROM #shipment sh
        INNER JOIN shipmentLineItem li
            ON sh.shipmentId = li.shipmentId
        INNER JOIN md_inventory inv
            ON li.invId = inv.invId
        INNER JOIN md_masterCategory ct
            ON li.lineItemStatus = ct.categoryId
 
END

GO

