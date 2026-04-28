-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-31
-- Used By:	    EMS -> Shipping Module -> Shipment Document -> Create New Invoice

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-09   3.0         ZY Wong     Rename column shipDate to shipmentDate
-- 2024-07-11   2.0         ZY Wong     Remove distinct bol checking, add distinct shipdate checking
-- 2024-05-31	1.0			ZY Wong 	Initial
---- ==========================================================================================
-- EXEC [SSP_Shipping_CreateInvoice] N'{"shipList":[{"shipmentId":"1"}]}', 1
CREATE PROCEDURE [dbo].[SSP_Shipping_CreateInvoice]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
 
		DECLARE @returnMessage VARCHAR(1000);

		--DECLARE @userId INT = 1, @Json VARCHAR(MAX)
		--SET @Json = N'{"shipList":[{"shipmentId":"1"}]}'

		DROP TABLE IF EXISTS #shipHeader;
		
		SELECT shipmentId
		INTO #shipHeader 
		FROM  OPENJSON(@Json, '$.shipList') 
  			WITH (
				shipmentId BIGINT			N'$.shipmentId'
			) 

		DROP TABLE IF EXISTS #invoice;

		SELECT s.shipmentId, shipId, shipmentStatus, companyId, invoiceId, bol, CONVERT(DATE, shipmentDate) as shipmentDate
		INTO #invoice
		FROM shipmentHeader s
			INNER JOIN #shipHeader sh
				ON s.shipmentId = sh.shipmentId

   --     IF (SELECT COUNT(DISTINCT bol) FROM #invoice) > 1
   --     BEGIN
			--SET @returnMessage = (SELECT 'SHIP # ' + STRING_AGG(CONVERT(NVARCHAR(MAX), shipId), ', ') + ' have different PL, no INVOICE # creation is allowed.'
			--                        FROM #invoice
			--                      );
			--THROW 60000, @returnMessage, 1;
   --     END

        IF (SELECT COUNT(DISTINCT shipmentDate) FROM #invoice) > 1
		BEGIN
			SET @returnMessage = (SELECT 'BOL # ' + STRING_AGG(CONVERT(NVARCHAR(MAX), bol), ', ') + ' have different Shipment Date, no INVOICE # creation is allowed.'
			                        FROM #invoice
                                  );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invoice WHERE shipmentStatus = 2150 ) > 0
		BEGIN
			SET @returnMessage = (SELECT 'BOL # ' + STRING_AGG(CONVERT(NVARCHAR(MAX), bol), ', ') + ' is in CANCEL state, no INVOICE # creation is allowed.'
			                        FROM #invoice
			                        WHERE shipmentStatus = 2150);
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invoice WHERE invoiceId IS NOT NULL) > 0
		BEGIN
			SET @returnMessage = (SELECT 'BOL # ' + STRING_AGG(CONVERT(NVARCHAR(MAX), bol), ', ') + ' already has INVOICE #.'
			                        FROM #invoice 
			                        WHERE invoiceId IS NOT NULL);
			THROW 60000, @returnMessage, 1;
		END
		
		BEGIN TRANSACTION
			DECLARE @companyId INT;
			DECLARE @invoiceId VARCHAR(50);

			SET @companyId = (SELECT TOP 1 companyId FROM #invoice);

			EXEC [dbo].[SSP_GetRunningNo] 'INV', @companyId, @invoiceId output

			IF @invoiceId IS NOT NULL 
			BEGIN
				UPDATE s SET
					invoiceId = @invoiceId,		
                    invoiceDate = getdate(),
					updateBy = @userId,
					updateDate = getdate()
				FROM #invoice i
					INNER JOIN shipmentHeader s
						ON i.shipmentId = s.shipmentId				
						 
			END
			ELSE
			BEGIN
				SET @returnMessage = 'INVOICE # encounter creation problem';				
				THROW 60000, @returnMessage, 1
			END

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'INVOICE # ' + @invoiceId + ' successfully assigned.' AS returnMessage 

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

GO

