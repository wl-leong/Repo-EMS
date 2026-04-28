-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-09-21
-- Used By:	    EMS -> PO Module -> PO Listing -> Cancel PO
--
-- Description : Change PO status to approved
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-25   5.0         ZY Wong     Note is compusory
-- 2024-04-23   4.0         ZY Wong     Standardize error message handling
-- 2025-01-13	3.0			WL Leong	Fix poNote | only added when poNote has value
-- 2024-02-26	2.0			WL Leong	Change message handling
-- 2024-02-23	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [dbo].[SSP_PurchaseOrder_CancelOrder] N'{"poList":[{"poId":"48", "notes":"customer dwant to shift date"}]}', 1

CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_CancelOrder]
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

		SELECT po.poId, poName, poStatus , odr.notes, po.poReferenceId
		INTO #orderList
		FROM poHeader po
			INNER JOIN #order odr
				ON po.poId = odr.poId
		 
		DECLARE @returnMessage as VARCHAR(500);

		IF (SELECT COUNT(1) FROM #orderList WHERE ISNULL(notes, '') = '') > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' reason is compulsory for cancel.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE ISNULL(notes, '') = ''
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1085) > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' already approved.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE poStatus = 1085
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END
		
		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1086) > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' already canceled.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE poStatus = 1086
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE poStatus = 1087) > 0
		BEGIN
			SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' already closed.'
			                        FROM (SELECT DISTINCT poName 
                                            FROM #orderList 
			                                WHERE poStatus = 1087
                                        )g
                                    );
			THROW 60000, @returnMessage, 1;
		END

		BEGIN TRANSACTION

			DECLARE @cancelHeader TABLE (poName VARCHAR(50));
			DECLARE @cancelLineItem TABLE (poDetailsId BIGINT, soLineItemId BIGINT);
 
			UPDATE poHeader SET
				poStatus = 1086,	
                poNote = (CASE WHEN LEN(poNote) > 0 THEN poNote + '|' ELSE '' END) + notes,
				poCancelBy = @updateBy,
				poCancelDate = getdate()
			OUTPUT INSERTED.poName
			INTO @cancelHeader
			FROM #orderList odr
			WHERE odr.poId = poHeader.poId

			UPDATE poLineItem SET
				itemStatus = 1086,
				updateDate = getdate()
			OUTPUT INSERTED.poDetailsId, INSERTED.soLineItemId
			INTO @cancelLineItem
			FROM #orderList odr
			WHERE odr.poId = poLineItem.poId
 
			IF (SELECT COUNT(1) FROM @cancelLineItem) > 0
			BEGIN
				UPDATE soLineItem SET
					poQty = 0,
					soLineItemStatus = 1106
				FROM @cancelLineItem cancel
				WHERE soLineItem.soLineItemId = cancel.soLineItemId

				UPDATE soHeader SET
					soStatus = 1106
				FROM #orderList odr
				WHERE odr.poReferenceId = soHeader.soName
			END
 
		COMMIT TRANSACTION

		SET @returnMessage = (SELECT 'PO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),poName), ', ') + ' success canceled.'
			                    FROM (SELECT DISTINCT poName 
                                        FROM @cancelHeader 
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
            SET @returnMessage = ERROR_MESSAGE();
            --SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

