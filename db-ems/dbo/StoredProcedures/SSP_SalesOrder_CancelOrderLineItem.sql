-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-06-06
-- Used By:	    EMS -> SO Module -> SO Listing -> Cancel item

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-06-06	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
EXEC [SSP_SalesOrder_CancelOrderLineItem] N'{"soItemList":[{"soHeaderId":"30929","soLineItemId":"21768"}]}',1
*/
CREATE PROCEDURE [dbo].[SSP_SalesOrder_CancelOrderLineItem]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @ErrMessage VARCHAR(MAX) = '';
		--DECLARE @Json VARCHAR(MAX)
		--DECLARE @createdBy INT = 1
		--SET @Json = N'{"soItemList":[{"soHeaderId":"30929","soLineItemId":"21768"}]}'
 
 
		DROP TABLE IF EXISTS #orderLineItem;

		SELECT * 
		INTO #orderLineItem
		FROM  OPENJSON(@Json, '$.soItemList') 
   			WITH (
				soHeaderId BIGINT			N'$.soHeaderId',
				soLineItemId BIGINT			N'$.soLineItemId'
			)

--1105	Open SO
--1106	Confirm SO
--1107	Cancel SO
--1108	Close SO

        DECLARE @soHeaderId BIGINT, @soLineItemId BIGINT, @currentStatus INT;

        SELECT @soHeaderId = soHeaderId, @soLineItemId = soLineItemId 
        FROM #orderLineItem 
 
	    SELECT @currentStatus = soStatus 
        FROM soHeader
        WHERE soHeaderId = @soHeaderId
 
		IF @currentStatus = 1105
		BEGIN
 
			DELETE FROM soLineItem 
			WHERE soLineItemId = @soLineItemId 
				AND soHeaderId = @soHeaderId
										
			SET @ErrMessage = 'LineItems are successfully deleted';
		END
		ELSE
		BEGIN
			UPDATE soLineItem SET 
				soLineItemStatus = 1107,
                odrQty = 0,
                updateBy = @userId,
                updateDate = getdate()
			WHERE soLineItemId = @soLineItemId 
				AND soHeaderId = @soHeaderId

			SET @ErrMessage = 'LineItems are successfully canceled';
		END

        IF @currentStatus <> 1105
        BEGIN
			UPDATE soHeader SET
				lastUpdatedDate = getdate()
			WHERE soHeaderId = @soHeaderId			
        END

		SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage 			

		COMMIT TRANSACTION
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO

