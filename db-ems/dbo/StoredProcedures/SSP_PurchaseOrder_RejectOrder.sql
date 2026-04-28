-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-09-21
-- Used By:	    EMS -> PO Module -> PO Listing -> Reject PO
--
-- Description : Change PO status to reject
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-15   3.0         ZY Wong     Add reason for reject PO
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-11	1.1			ZY Wong		Check poStatus and return error message
-- 2023-09-21	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [dbo].[SSP_PurchaseOrder_RejectOrder] N'{"poList":[{"poId":"6"}, {"poId":"9"},{"poId":"3"}, {"poId":"5"}, {"poId":"8"}, {"poId":"4"}, {"poId":"7"}]}', 1
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_RejectOrder]
@orderJson VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
 
		--DECLARE @orderJson VARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @orderJson = N'{"poList":[{"poId":"6"}, {"poId":"9"},{"poId":"3"}, {"poId":"5"}, {"poId":"8"}]}'

		-- Read json content
		DROP TABLE IF EXISTS #order;

		SELECT * 
		INTO #order
		FROM  OPENJSON(@orderJson, '$.poList') 
   			WITH (
				poId BIGINT			N'$.poId',
                notes VARCHAR(500)	N'$.notes'
			)

		DROP TABLE IF EXISTS #orderList;

		SELECT po.poId, poName, poStatus, odr.notes
		INTO #orderList
		FROM poHeader po
			INNER JOIN #order odr
				ON po.poId = odr.poId
		 
		DECLARE @returnMessage as VARCHAR(500);

        IF (SELECT COUNT(1) FROM #orderList WHERE ISNULL(notes, '') = '') > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ', reason is compulsory for reject'
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
                                            WHERE ISNULL(notes, '') = '')g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1085) > 0
		BEGIN
            SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' already approved'
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
                                            WHERE poStatus = 1085)g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1078) > 0
		BEGIN
            SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' already rejected.'
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
                                            WHERE poStatus = 1078)g
                                    );
			THROW 60000, @returnMessage, 1;
		END
		
		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1086) > 0
		BEGIN
            SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' already closed.'
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
                                            WHERE poStatus = 1086)g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus <> 1080) > 0
		BEGIN
            SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' not yet confirmed.'
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
                                            WHERE poStatus <> 1080)g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		BEGIN TRANSACTION
 
			UPDATE poHeader SET
				poStatus = 1078, --reject	
                poNote = (CASE WHEN LEN(poNote) > 0 THEN poNote + '|' ELSE '' END) + notes,
                updateBy = @updateBy,
				updateDate = getdate()
			FROM #order odr
			WHERE odr.poId = poHeader.poId
				AND poStatus = 1080  --in review

			UPDATE poLineItem SET
				itemStatus = 1078, --reject
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #order odr
			WHERE odr.poId = poLineItem.poId
				AND itemStatus = 1080  --in review
 
		COMMIT TRANSACTION

        SELECT @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), poName), ',') + ' success rejected.' 
			                        FROM (SELECT DISTINCT poName
                                            FROM #orderList 
			                                WHERE poStatus = 1080)g
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
			'_FAILURE_' as status, @returnMessage as errorMessage

		RETURN -1
	END CATCH
END

GO

