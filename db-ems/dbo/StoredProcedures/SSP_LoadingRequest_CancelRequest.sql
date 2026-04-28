-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-12-11
-- Used By:	    EMS -> LR Module -> LR Listing -> Delete LR
--
-- Description : Change LR status to cancel
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-07   4.0         ZY Wong     Allow to cancel for released lr (marketing: cancel lrHeader & lrContainer & lrLineItem, reduce poLineItem.lrQty, factory: cancel lrHeader & lrContainer & lrLineItem)
-- 2024-05-16   3.0         ZY Wong     Change to reduce lrQty from poLineItem
-- 2024-01-22	2.0			WL Leong	Cancel will 0 lrQty and reduce the soLineItem lrQty
-- 2023-12-11	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_CancelRequest N'{"lrList":[{"lrHeaderId":"46"}]}',1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_CancelRequest]
@json NVARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	

		--DECLARE @Json VARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @Json = N'{"lrList":[{"lrHeaderId":"1"}]}'

        DECLARE @returnMessage VARCHAR(MAX);
        DECLARE @ErrMessage VARCHAR(MAX);

		-- Read json content
		DROP TABLE IF EXISTS #lr;

		SELECT * 
		INTO #lr
		FROM  OPENJSON(@Json, '$.lrList') 
   			WITH (
				lrHeaderId BIGINT		N'$.lrHeaderId'
			)

		DROP TABLE IF EXISTS #lrInfo;

		SELECT lrd.lrHeaderId, lrd.lrName, lrd.lrStatus
		INTO #lrInfo
		FROM lrHeader lrd
			INNER JOIN #lr l
				ON lrd.lrHeaderId = l.lrHeaderId
		 		 

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2130) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' already canceled.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus = 2130)g);
			THROW 60000, @ErrMessage, 1;
		END


		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2131) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' already closed.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus = 2131)g);
			THROW 60000, @ErrMessage, 1;
		END

-- 2132 Draft
-- 2134 Reject
-- 2145 Reopen
-- 2135 Released

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus NOT IN (2132, 2134, 2145, 2135)) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' not able to cancel.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus NOT IN (2132, 2134, 2145, 2135))g);
			THROW 60000, @ErrMessage, 1;
		END

		BEGIN TRANSACTION

            DECLARE @updatedLr TABLE (lrHeaderId BIGINT, lrName VARCHAR(50));
			DECLARE @updatedLrLineItem TABLE(lrDetailsId BIGINT, poDetailsId BIGINT, lrQty INT);
            DECLARE @updatedLrContainer TABLE(lrContainerId BIGINT);
            DELETE FROM @updatedLr
            DELETE FROM @updatedLrLineItem
            DELETE FROM @updatedLrContainer

            -- cancel marketing lr
			UPDATE lrHeader SET
				lrStatus = 2130,	
				lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
            OUTPUT DELETED.lrHeaderId, DELETED.lrName
            INTO @updatedLr
			FROM lrHeader lr
                INNER JOIN #lr l
			        ON lr.lrHeaderId = l.lrHeaderId
            WHERE lr.lrStatus IN (2132, 2134, 2145, 2135)

            -- cancel marketing lr container
            UPDATE lrContainer SET
                containerStatus = 2130,
                lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
            OUTPUT DELETED.lrContainerId
            INTO @updatedLrContainer
            FROM lrContainer lr
                INNER JOIN #lr l
			        ON lr.lrHeaderId = l.lrHeaderId
		    WHERE lr.containerStatus IN (2132, 2134, 2145, 2135)

            -- cancel marketing lr item
			UPDATE lrLineItem SET
				itemStatus = 2130,
				confirmQty = 0,
				lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
			OUTPUT DELETED.lrDetailsId, DELETED.poDetailsId, DELETED.qty
			INTO @updatedLrLineItem
			FROM lrLineItem lr
                INNER JOIN #lr l
			        ON lr.lrHeaderId = l.lrHeaderId 
            WHERE lr.itemStatus IN (2132, 2134, 2145, 2135)
            
            -- reduce lrQty from poLineItem
            UPDATE poLineItem SET
                lrQty = pl.lrQty - lr.cancelQty,
                updateBy = @userId,
				updateDate = getdate()
			FROM poLineItem pl
				INNER JOIN (SELECT poDetailsId, SUM(lrQty) as cancelQty 
                            FROM @updatedLrLineItem 
                            GROUP BY poDetailsId) lr
					ON pl.poDetailsId = lr.poDetailsId

            -- cancel factory lr
            UPDATE lrHeader SET
				lrStatus = 2130,	
				lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
			FROM lrHeader lr
                INNER JOIN @updatedLr l
			        ON lr.ref_customerLrHeaderId = l.lrHeaderId
            WHERE lr.lrStatus = 2135

            -- cancel factory lr container
            UPDATE lrContainer SET
                containerStatus = 2130,
                lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
            FROM lrContainer lr
                INNER JOIN @updatedLrContainer l
			        ON lr.ref_lrContainerId = l.lrContainerId
		    WHERE lr.containerStatus IN (2132, 2134, 2145, 2135)

            -- cancel factory lr item
            UPDATE lrLineItem SET
				itemStatus = 2130,
				lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
			FROM lrLineItem lr
                INNER JOIN @updatedLrLineItem l
			        ON lr.ref_lrLineItemId = l.lrDetailsId 
            WHERE lr.itemStatus IN (2132, 2134, 2145, 2135)
 
		COMMIT TRANSACTION

		SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ') + ' success canceled.'
                                FROM (SELECT DISTINCT lrName
                                        FROM @updatedLr)g); 

        SELECT '_SUCCESS_' as status, @returnMessage AS returnMessage 

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
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as errorMessage

		RETURN -1
	END CATCH
END

GO

