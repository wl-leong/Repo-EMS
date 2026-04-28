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
EXEC SSP_Shipping_SelectShipmentFreight 5
**/

CREATE PROCEDURE [dbo].[SSP_Shipping_SelectShipmentFreight]
@shipmentId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    
    --DECLARE @shipmentId BIGINT = 5

    DROP TABLE IF EXISTS #shipment;

    SELECT  shipmentId, shipId, BOL, containerSeqNo, containerNo, containerSealNo, containerMaxGross, containerTare, containerTypeId,  forwarderId, 
        sh.haulierId,  vesselId, ETD, ETA, containerPullInDate, containerPullOutDate
    INTO #shipment
    FROM shipmentHeader sh   
    WHERE shipmentId =  @shipmentId

    SELECT sh.shipmentId, shipId, BOL, containerSeqNo, containerNo, containerSealNo, containerMaxGross, containerTare, containerTypeId, ct.categoryName as containerType,
        sh.forwarderId, fwd.categoryName as forwarder, sh.haulierId, h.haulier, vs.categoryName as vessel, ETD, ETA, containerPullInDate, containerPullOutDate
    FROM #shipment sh
        INNER JOIN md_masterCategory ct
            ON sh.containerTypeId = ct.categoryId
        LEFT JOIN md_masterCategory fwd
            ON sh.forwarderId = fwd.categoryId
        LEFT JOIN md_haulier h
            ON sh.haulierId = h.haulierId
        LEFT JOIN md_masterCategory vs
            ON sh.vesselId = vs.categoryId
    
END

GO

