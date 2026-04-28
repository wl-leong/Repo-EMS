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
EXEC SSP_Shipping_SelectShipmentHeader 1
**/ 

CREATE PROCEDURE [dbo].[SSP_Shipping_SelectShipmentHeader]
@shipmentId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #shipment;

    SELECT shipmentId, shipId, BOL, customerName, shipmentDate, st.categoryName as shipStatus,  
        containerPullOutDate as checkoutDate, lrName, soName, customerPO,
        invoiceId, customerInvoiceNo, invoiceAmount, 
        pickUpAddrId, shipToId, pol, pod, paymentTermId, pt.categoryName as paymentTerm,
        note, apiStatus, asnDate, NULL as invoiceDate 
    INTO #shipment
    FROM shipmentHeader sh   
        INNER JOIN md_customer cs
            ON sh.customerId = cs.customerId
        INNER JOIN md_masterCategory pt
            ON sh.paymentTermId = pt.categoryId
        INNER JOIN md_masterCategory st
            ON sh.shipmentStatus = st.categoryId
    WHERE shipmentId =  @shipmentId


    SELECT shipmentId, shipId, BOL, customerName, shipmentDate,  shipStatus,  
        checkoutDate, lrName, soName, customerPO, invoiceId, customerInvoiceNo, invoiceAmount, 
        pickUpAddrId, s.shipToId, s.pol, s.pod, paymentTermId, paymentTerm,
        note, apiStatus, asnDate,  invoiceDate, wh.label as shipFrom, st.shipToLabel  
    FROM #shipment s
        INNER JOIN md_warehouse wh
            ON s.pickUpAddrId  = wh.warehouseId
        INNER JOIN md_shipToDestination st
            ON s.shipToId = st.shipTOId
END

GO

