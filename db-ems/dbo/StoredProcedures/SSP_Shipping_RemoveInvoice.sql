-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-31
-- Used By:	    EMS -> Shipping Module -> Shipment Document -> Create New Invoice

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-31	1.0			ZY Wong 	Initial
---- ==========================================================================================
-- [SSP_Shipping_RemoveInvoice] 1, 1
 
CREATE PROCEDURE [dbo].[SSP_Shipping_RemoveInvoice]
@shipmentId BIGINT,
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
 
		DECLARE @returnMessage VARCHAR(1000);

		--DECLARE @userId INT = 1, @shipmentId BIGINT = 1

        DROP TABLE IF EXISTS #invoice;
 
		SELECT shipmentId, shipId, shipmentStatus, companyId, invoiceId
		INTO #invoice		
        FROM shipmentHeader 
		WHERE shipmentID = @shipmentId

		IF (SELECT COUNT(1) FROM #invoice WHERE invoiceId IS NULL) > 0
		BEGIN
			SET @returnMessage = 'INVOICE # is empty';
			THROW 60000, @returnMessage, 1;
		END
		
		BEGIN TRANSACTION

			IF (SELECT COUNT(1) FROM #invoice) > 0 
			BEGIN
				DECLARE @invoiceId VARCHAR(50);

				SET @invoiceId = (SELECT TOP 1 invoiceId FROM #invoice);

				UPDATE shipmentHeader SET
					invoiceId = null,
                    invoiceDate = null,
					updateBy = @userId,
					updateDate = getdate()
				WHERE shipmentID = @shipmentId
 						 
			END
			ELSE
			BEGIN
				SET @returnMessage = 'No record for action';
				
				THROW 60000, @returnMessage, 1
			END

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'INVOICE # ' + @invoiceId + ' successfully removed' AS returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END
 
 
 
 --select * from soHeader

GO

