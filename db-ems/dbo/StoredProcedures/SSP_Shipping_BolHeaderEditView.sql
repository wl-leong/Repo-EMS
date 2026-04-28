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
EXEC SSP_Shipping_BolHeaderEditView 'MPH-BOL-24-00062'
**/

CREATE PROCEDURE [dbo].[SSP_Shipping_BolHeaderEditView]
@bol VARCHAR(30)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #shipment;

    SELECT shipmentId
    INTO #shipment
    FROM shipmentHeader
    WHERE bol = @bol

    DECLARE @itemQty INT

    SET @itemQty = (SELECT SUM(shipmentQty)
                    FROM #shipment s
                        INNER JOIN shipmentLineItem li
                            ON s.shipmentId = li.shipmentId)

    SELECT  DISTINCT BOL, customerId, CAST(shipmentDate as date), lrName, POL, POD, mc.categoryName as containerType, 
        containerNo, forwarderBookingNo as bookingNo, containerSealNo, countryOfOrigin, vs.categoryName as vesselName,
        ETD, ETA, @itemQty as totalPcs, bolTotalShipmentWeight, summary, note
    FROM shipmentHeader sh
        INNER JOIN md_masterCategory mc
            ON sh.containerTypeId = mc.categoryId
        LEFT JOIN md_masterCategory vs
            ON sh.vesselId = vs.categoryId
    WHERE bol = @bol
 
END

GO

