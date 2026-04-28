-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-20
-- Used By:	    EMS -> Inventory Module -> Inventory -> Raw Bom

-- Description : Perform 'Delete' and 'Re-active' action for raw bom listing

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-20	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Inventory_AcitvateBomListing] N'{"rawBomList":[{"invId":94,"action":"DeleteRawBom"}]}', 1
CREATE PROCEDURE [dbo].[SSP_Inventory_AcitvateBomListing]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	
	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @ErrMessage VARCHAR(MAX);

		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"rawBomList":[{
		--		"invId":94,
		--		"action":"ReactiveRawBom"
		--	}]}'

		--DECLARE @updateBy INT = 1;

		DROP TABLE IF EXISTS #rawBomList;

		SELECT * 
		INTO #rawBomList
		FROM  OPENJSON(@Json, '$.rawBomList') 
   			WITH (
				invId BIGINT				N'$.invId',
				actionType VARCHAR(50)		N'$.action'
			)

		DECLARE @invId BIGINT, @actionType VARCHAR(50);

		SELECT @invId = invId, @actionType = actionType
		FROM #rawBomList

		IF @actionType = 'DeleteRawBom'
		BEGIN
 			UPDATE rbom SET
				status = 0, 
				updateBy = @updateBy,
				updateDate = getdate()
			FROM rawBom rbom
			WHERE invId = @invId
				AND status = 1

			SET @ErrMessage = 'Raw BOM is successfully deleted.'
		END

		IF @actionType = 'ReactiveRawBom'
		BEGIN
 			UPDATE rawBom SET
				status = 1, 
				updateBy = @updateBy,
				updateDate = getdate()
			FROM rawBom rbom
			WHERE invId = @invId
				AND status = 0			
				
			SET @ErrMessage = 'Raw BOM is successfully re-actived.'
		END

		COMMIT TRANSACTION

        SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

