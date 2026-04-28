-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-09-21
-- Used By:	    EMS -> PO Module -> PO Listing -> Confirm PO
--
-- Description : Change PO status to pending approval
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-23   3.0         ZY Wong     Standardize error message handling
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-11	1.1			ZY Wong		Check poStatus and return error message
-- 2023-09-21	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [dbo].[SSP_PurchaseOrder_ConfirmOrder] N'{"poList":[{"poId":"6"}, {"poId":"9"}]}', 1
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_ConfirmOrder]
@orderJson VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
 
		--DECLARE @orderJson VARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @orderJson = N'{"poList":[{"poId":"6"}, {"poId":"9"}]}'

		-- Read json content
		DROP TABLE IF EXISTS #order;

		SELECT * 
		INTO #order
		FROM  OPENJSON(@orderJson, '$.poList') 
   			WITH (
				poId BIGINT			N'$.poId'
			)

		DROP TABLE IF EXISTS #orderList;

		SELECT po.poId, poName, poStatus 
		INTO #orderList
		FROM poHeader po
			INNER JOIN #order odr
				ON po.poId = odr.poId
		 
		DECLARE @returnMessage as VARCHAR(500)

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1080) > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' already confirmed.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE poStatus = 1080
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus NOT IN (1079, 1078)) > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' not able to confirm.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE poStatus NOT IN (1079, 1078)
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		BEGIN TRANSACTION

			UPDATE poHeader SET
				poStatus = 1080,	
                poConfirmBy = @updateBy,
				poConfirmDate = getdate(),
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #order odr
			WHERE odr.poId = poHeader.poId
				AND poStatus IN (1079, 1078)

			UPDATE poLineItem SET
				itemStatus = 1080,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #order odr
			WHERE odr.poId = poLineItem.poId
				AND itemStatus IN (1079, 1078)

		COMMIT TRANSACTION

		SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' success confirmed.'
			                    FROM (SELECT DISTINCT poName 
                                        FROM #orderList 
			                            WHERE poStatus IN (1079, 1078)
                                    )g
                                );

		SELECT '_SUCCESS_' as status, @returnMessage AS returnMessage  

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

