-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> SO Module -> SO Listing View -> Process Shipment button

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2023-12-10	1.0			WL Leong	Initial
-- ==========================================================================================
/**
SSP_SalesOrder_SalectLineItemForShipment
30896
**/
--select * from soHeader
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectLineItemForShipment]
@soHeaderId BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

		SELECT soName, customerPO, earlyShipDate, st.shipToLabel, soLineItemId, customerSku, merchantSku, odrQty, poQty, poQty as shpQty
		FROM soLineItem li
            INNER JOIN soHeader s
                ON li.soHeaderId = s.soHeaderId
            INNER JOIN md_shipToDestination st
                ON s.shipToId = st.shipToId
        WHERE li.soHeaderId = @soHeaderId
                AND soLineItemStatus = 2125

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

