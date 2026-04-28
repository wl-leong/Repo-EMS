-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-07
-- Used By:	    EMS -> Shiping Module -> Shipment Monitoring -> Update Confirm Pickup Date 

-- Description :  Update Confirm Pickup Date 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-07	1.0			ZY Wong		Initial
-- ==========================================================================================
--SSP_Shipping_UpdateConfirmPickupDate 'FNP-BOL-25-00004', 1
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateConfirmPickupDate]
@BOL VARCHAR(80),
@updateBy INT
AS
BEGIN
SET DATEFORMAT ymd
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION

		DECLARE @returnMessage VARCHAR(1000);

		IF ISNULL(@BOL, '') = ''
		BEGIN
			SET @returnMessage = 'BOL # is empty';
			THROW 60000, @returnMessage, 1
		END

		DECLARE @companyId INT, @DO VARCHAR(20) 
 
		UPDATE shipmentHeader SET
			containerPullOutDate = getdate(),
			updateBy = @updateBy,
			updateDate = getdate()
		WHERE bol = @BOL


		DROP TABLE IF EXISTS #shipment;

		SELECT sh.shipId, soLineItemId, shipQty
		INTO #shipment
		FROM shipmentLineItem li
			INNER JOIN shipmentHeader sh
				ON li.shipId = sh.shipId
		WHERE sh.BOL = @BOL

		DECLARE @warehouseId INT
		SELECT @warehouseId = (SELECT DISTINCT st.warehouseId
						   FROM md_shipToDestination st
								INNER JOIN shipmentHeader sh
									ON st.shipToId = sh.shipToId
						   WHERE BOL = @BOL)
		
		DECLARE @GRN NVARCHAR(MAX)
		DECLARE @GRNresult INT = 0;

		SET @GRN = (SELECT poId as [poId], 
						s.shipId + '.csv' as DO,
						@warehouseId as warehouseId,
						pl.podetailsId as [poList.poDetailsId],
						s.shipQty as [poList.rcvQty]
					FROM #shipment s
						INNER JOIN soLineItem so
							ON s.soLineItemId = so.soLineItemId
						INNER JOIN poLineItem pl
							ON so.ref_polineItemId = pl.poDetailsId
					 FOR JSON PATH);

					-- select @GRN

		EXEC @GRNresult = [dbo].[SSP_PurchaseOrder_ReceivePO] @GRN, 1

		IF @GRNresult = 0
		BEGIN
			SELECT '_SUCCESS_' as status, 'BOL# ' + @BOL + ' success Confirm Pickup ' as returnMessage
		END
		ELSE
		BEGIN
			SELECT '_FAILURE_' as status, 'BOL# ' + @BOL + ' is/are not notify customer on GRN, Manual GRN need to be done at customer side' as returnMessage
		END

		DECLARE @result INT = 0;
		
		EXEC @result = [dbo].[SSP_Notification_SendShipmentASN] @BOL, @updateBy

		COMMIT TRANSACTION

		IF @result = 0
		BEGIN
			SELECT '_SUCCESS_' as status, 'BOL# ' + @BOL + ' success Confirm Pickup and send shipment ASN email ' as returnMessage
		END
		ELSE
		BEGIN
			SELECT '_FAILURE_' as status, 'BOL# ' + @BOL + ' is/are not able to Confirm Pickup' as returnMessage
		END


		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

		IF (XACT_STATE()) = 1  
		BEGIN  
			COMMIT TRANSACTION ;     
		END;  
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

