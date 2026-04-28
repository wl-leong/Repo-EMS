-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-12-11
-- Used By:	    EMS -> LR Module -> LR Listing -> Action -> Delete Container
--
-- Description : Change LR Container & Line Item status to cancel
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-01-09   2.0         ZY Wong     Cancel lrContainer, restructure sp 
-- 2024-04-24	1.0			WL LEONG    Cancel from line item
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_CancelContainerRequest 2,2,1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_CancelContainerRequest]
@lrHeaderId BIGINT,
@containerSeq INT,
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	

        DECLARE @returnMessage VARCHAR(MAX);
        DECLARE @ErrMessage VARCHAR(MAX);
        DECLARE @lrName VARCHAR(30);

        DROP TABLE IF EXISTS #lrContainer;

        SELECT lrContainerId, lrHeaderId, lrName, containerStatus
        INTO #lrContainer
        FROM lrContainer 
        WHERE lrHeaderId = @lrHeaderId
            AND containerSeq = @containerSeq

        SET @lrName = (SELECT lrName FROM #lrContainer);

        IF (SELECT COUNT(1) FROM #lrContainer) = 0
        BEGIN
            SET @ErrMessage = 'LR# ' + @lrName + '(Container Seq ' + CAST(@containerSeq as VARCHAR) + ') not found.';
			THROW 60000, @ErrMessage, 1;
        END

		IF (SELECT COUNT(1) FROM #lrContainer WHERE containerStatus = 2130) > 0
        BEGIN
            SET @ErrMessage = 'LR# ' + @lrName + '(Container Seq ' + CAST(@containerSeq as VARCHAR) + ') already cancel.';
			THROW 60000, @ErrMessage, 1;
        END

		IF (SELECT COUNT(1) FROM #lrContainer WHERE containerStatus = 2131) > 0
        BEGIN
            SET @ErrMessage =  'LR# ' + @lrName + '(Container Seq ' + CAST(@containerSeq as VARCHAR) + ') already closed.';
			THROW 60000, @ErrMessage, 1;
        END
 
-- 2132 draft
-- 2134 Reject
-- 2145 Reopen

		IF (SELECT COUNT(1) FROM #lrContainer WHERE containerStatus NOT IN (2132, 2134, 2145)) > 0
        BEGIN
            SET @ErrMessage =  'LR# ' + @lrName + '(Container Seq ' + CAST(@containerSeq as VARCHAR) + ') not able to cancel.';
			THROW 60000, @ErrMessage, 1;
        END

		BEGIN TRANSACTION

			DECLARE @updatedLrLineItem TABLE(lrDetailsId BIGINT, poDetailsId BIGINT, lrQty INT);
            DECLARE @updatedLrContainer TABLE(lrContainerId BIGINT, lrName VARCHAR(50), containerSeq INT);
            DELETE FROM @updatedLrLineItem
            DELETE FROM @updatedLrContainer
 
            -- cancel marketing lr container
            UPDATE lrContainer SET
                containerStatus = 2130,
                lrCancelBy = @userId, 
				lrCancelDate = getdate(),
				updateBy = @userId,
				updateDate = getdate()
            OUTPUT DELETED.lrContainerId, DELETED.lrName, DELETED.containerSeq
            INTO @updatedLrContainer
            FROM lrContainer lr
                INNER JOIN #lrContainer l
			        ON lr.lrContainerId = l.lrContainerId
		    WHERE lr.containerStatus IN (2132, 2134, 2145)

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
                INNER JOIN #lrContainer l
			        ON lr.lrContainerId = l.lrContainerId 
            WHERE lr.itemStatus IN (2132, 2134, 2145)
            
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
		    WHERE lr.containerStatus IN (2132, 2134, 2145)

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
            WHERE lr.itemStatus IN (2132, 2134, 2145)

        COMMIT TRANSACTION

        SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName + '(Container Seq ' + CAST(containerSeq as VARCHAR) + ')' ), ', ') + ' success canceled.'
                                FROM (SELECT DISTINCT lrName, containerSeq
                                        FROM @updatedLrContainer)g); 

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
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

