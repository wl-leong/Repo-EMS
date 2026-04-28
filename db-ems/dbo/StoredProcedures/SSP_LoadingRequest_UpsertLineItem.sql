-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-19
-- Used By:	    EMS -> LR Module -> LR Listing -> Edit Line Item

-- Description : Add/Update/Delete LR Line Item

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-24   3.0         ZY Wong     Json remove containerSeq and add lrContainerId, minor change on #overQty and msg return
-- 2024-11-27   2.0         ZY Wong     Add poItemQty and change balanceQty & aqjustQty in #overQty
-- 2024-04-19	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
declare @userId int = 1

declare @Json VARCHAR(MAX) = N'{"lrList":[{"action":"Add","lrHeaderId":"10346","poDetailsId":"22490","lrContainerId":"87064","qty":"20","itemNote":""}]}'
--declare @Json VARCHAR(MAX) = N'{"lrList":[{ "action":"Delete","lrDetailsId":138}]}'
--declare @Json VARCHAR(MAX) = N'{ "lrList":[{ "action":"Update","lrDetailsId":138, "qty":"60", "itemNote":""}]}'

exec [SSP_LoadingRequest_UpsertLineItem] @Json, @userId
*/

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_UpsertLineItem]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
            --declare @Json VARCHAR(MAX) = N'{ "lrList":[{ "action":"Update","lrDetailsId":1142, "qty":"6100", "itemNote":""}]}'
            DECLARE @returnMessage VARCHAR(MAX);
--2132 Draft
--2134 Reject
--2145 Reopen
--2129 Approved
--2133 In Review
--2135 Released
--2130 Cancel
--2131 Closed
            DROP TABLE IF EXISTS #lrList;

		    SELECT actionType, lrHeaderId, lrDetailsId, lrContainerId, poDetailsId, CONVERT(INT, ISNULL(qty,0)) as qty, ISNULL(itemNote,'') as itemNote
		    INTO #lrList
		    FROM OPENJSON(@Json, '$.lrList') 
   			    WITH (
				    actionType VARCHAR(50)  N'$.action',
                    lrHeaderId BIGINT       N'$.lrHeaderId',
                    lrDetailsId BIGINT      N'$.lrDetailsId',
                    lrContainerId BIGINT    N'$.lrContainerId',
				    poDetailsId BIGINT      N'$.poDetailsId',
				    qty VARCHAR(10)         N'$.qty',
				    itemNote VARCHAR(200)   N'$.itemNote'
			    )

            DECLARE @actionType VARCHAR(50) = (SELECT actionType FROM #lrList);

            DECLARE @lrHeaderId BIGINT = (SELECT lrHeaderId FROM #lrList); 
            DECLARE @lrDetailsId BIGINT = (SELECT lrDetailsId FROM #lrList);    
            DECLARE @lrContainerId BIGINT = (SELECT lrContainerId FROM #lrList);
            DECLARE @poDetailsId BIGINT = (SELECT poDetailsId FROM #lrList);

            DECLARE @itemStatus INT = (SELECT itemStatus FROM lrLineItem WHERE lrDetailsId = @lrDetailsId);
            DECLARE @updateQty INT = 0;
            DECLARE @currentLrQty INT = 0;
            DECLARE @totalLrQty INT = 0;           

            -- check item stats
            IF @itemStatus IS NOT NULL 
                AND @itemStatus NOT IN (2132, 2134, 2145) 
		    BEGIN
			    SET @returnMessage = 'Only draft or rejected LR can add/edit/delete items.';
                THROW 60000, @returnMessage, 1;                
		    END

            --check new po item exists in current lr, if yes, update status to update 
            IF @actionType = 'Add'
            BEGIN                  
                DROP TABLE IF EXISTS #chkPoItemExists;

                SELECT lrDetailsId, qty as oriQty, itemNote as oriNote
                INTO #chkPoItemExists
                FROM lrLineItem 
                WHERE lrHeaderId = @lrHeaderId
                    AND lrContainerId = @lrContainerId
                    AND poDetailsId = @poDetailsId

                IF (SELECT COUNT(1) FROM #chkPoItemExists WHERE lrDetailsId IS NOT NULL) > 0
                BEGIN
                    UPDATE #lrList SET
                        lrDetailsId = chk.lrDetailsId,                        
                        itemNote = CASE WHEN itemNote = '' THEN oriNote ELSE (CASE WHEN ISNULL(oriNote,'') = '' THEN itemNote ELSE oriNote + ', ' + itemNote END) END,
                        actionType = 'Update'
                    FROM #chkPoItemExists chk

                    SET @updateQty = (SELECT oriQty FROM #chkPoItemExists);
                    SET @actionType = (SELECT actionType FROM #lrList);
                    
                END
                
            END

            IF @actionType = 'Update'
            BEGIN

                -- get poDetailsId using lrDetailsId and update back for later use
                SET @poDetailsId = (SELECT poDetailsId FROM lrLineItem WHERE lrDetailsId = @lrDetailsId);
                UPDATE #lrList SET poDetailsId = @poDetailsId

                -- sum of all lrLineItem.qty, except passed in lrDetailsId
                SELECT @totalLrQty = ISNULL(SUM(qty),0)
                FROM lrLineItem 
                WHERE poDetailsId = @poDetailsId
                    AND (@lrDetailsId IS NULL 
                        OR lrDetailsId <> @lrDetailsId)
                SET @lrDetailsId = (SELECT lrDetailsId FROM #lrList);

                -- lrLineItem.qty of passed in/updated lrDetailsId
                SELECT @currentLrQty = qty
                FROM lrLineItem
                WHERE lrDetailsId = @lrDetailsId

            END

            -- check lr qty exceed available lr qty
            IF @actionType IN ('Add', 'Update')
			BEGIN
                
                DROP TABLE IF EXISTS #overQty;

                SELECT pl.poDetailsId, pl.qty as poItemQty, pl.lrQty as existingLrQty, (pl.qty - pl.lrQty + @currentLrQty) as balanceQty, lr.qty as editQty, 
                    CASE WHEN @actionType = 'Update' THEN (lr.qty + @totalLrQty) 
                        WHEN @actionType = 'Add' THEN lr.qty
                        ELSE 0 END as adjustQty
                INTO #overQty
                FROM poLineItem pl
                    INNER JOIN #lrList lr
                        ON pl.poDetailsId = lr.poDetailsId

                IF (SELECT COUNT(1) FROM #overQty WHERE poItemQty < adjustQty) > 0
                BEGIN
                    DECLARE @balanceQty INT, @existingLrQty INT;

                    SELECT @balanceQty = balanceQty, @existingLrQty = existingLrQty
                    FROM #overQty

                    IF @actionType = 'Update'
                    BEGIN
                        SET @returnMessage = 'Item already have ' + CAST(@existingLrQty as VARCHAR) + ' quantity added to LR, left ' + CAST(@balanceQty - @existingLrQty as VARCHAR) + ' quantity to be planned for LR';
                    END
                    ELSE
                    BEGIN
                        SET @returnMessage = 'Item only have ' + CAST(@balanceQty as VARCHAR) + ' to be planned for LR';
                    END

                    ;THROW 60000, @returnMessage, 1;                
                END

            END

            BEGIN TRANSACTION

            IF @actionType = 'Delete'
			BEGIN
                DECLARE @lrQty INT;
                DECLARE @deleteLineItem TABLE (poDetailsId BIGINT);
                
                SELECT @lrQty = qty 
                FROM lrLineItem
                WHERE lrDetailsId = @lrDetailsId

				DELETE FROM lrLineItem                 
                OUTPUT DELETED.poDetailsId      
                INTO @deleteLineItem
				WHERE lrDetailsId = @lrDetailsId

                UPDATE pl SET
                    lrQty = lrQty - @lrQty,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM poLineItem pl
                    INNER JOIN @deleteLineItem l
                        ON pl.poDetailsId = l.poDetailsId
				
				SET @returnMessage = 'deleted.';
			END
       
            IF @actionType IN ('Update')
            BEGIN
                DECLARE @updateLineItem TABLE (poDetailsId BIGINT, qty INT, oldQty INT);

                UPDATE lrLineItem SET
                    qty = l.qty + @updateQty,
                    itemNote = l.itemNote,
                    updateBy = @userId,
                    updateDate = getdate()
                OUTPUT INSERTED.poDetailsId, INSERTED.qty, DELETED.qty
				INTO @updateLineItem
                FROM #lrList l
                WHERE lrLineItem.lrDetailsId = @lrDetailsId

                DROP TABLE IF EXISTS #updateQty;

				SELECT poDetailsId, qty - oldQty as diffQty
				INTO #updateQty
				FROM @updateLineItem
					
				IF (SELECT COUNT(1) FROM #updateQty) > 0
				BEGIN
					UPDATE poLineItem SET	
						lrQty = lrQty + diffQty
					FROM #updateQty p
					WHERE poLineItem.poDetailsId = p.poDetailsId
				END

                SET @returnMessage = 'updated.';
			END

            IF @actionType = 'Add'
            BEGIN
                
                ALTER TABLE #lrList ADD lrName VARCHAR(30);
                ALTER TABLE #lrList ADD poId BIGINT;
                ALTER TABLE #lrList ADD soLineItemId BIGINT;
                ALTER TABLE #lrList ADD supplierSku VARCHAR(30);
                ALTER TABLE #lrList ADD invId BIGINT;
                ALTER TABLE #lrList ADD soHeaderId BIGINT;
                

                UPDATE lr SET
                    lrName = l.lrName
                FROM #lrList lr
                    INNER JOIN lrHeader l
                        ON lr.lrHeaderId = l.lrHeaderId

                UPDATE lr SET
                    poId = p.poId,
                    soLineItemId = p.soLineItemId,
                    supplierSku = p.supplierSku,
                    invId = p.invId
                FROM #lrList lr
                    INNER JOIN poLineItem p
                        ON lr.poDetailsId = p.poDetailsId

                UPDATE lr SET
                    soHeaderId = s.soHeaderId
                FROM #lrList lr
                    INNER JOIN soLineItem s
                        ON lr.soLineitemId = s.soLineItemId
  
                DECLARE @newLrLineItem table(poDetailsId BIGINT, qty INT);

                INSERT INTO lrLineItem (lrHeaderId, lrName, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invID, qty, confirmQty, processQty, itemNote, itemStatus, enterBy, enterDate)
                OUTPUT INSERTED.poDetailsId, INSERTED.qty
                INTO @newLrLineItem
                SELECT lrHeaderId, lrName, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invID, qty, 0 as confirmQty, 0 as processQty, itemNote, 2132 as itemStatus, @userId, getdate() as enterDate
                FROM #lrList 

                -- update poLineitem
                UPDATE pl SET
                    lrQty = pl.lrQty + l.qty,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM poLineItem pl
                    INNER JOIN @newLrLineItem l
                        ON pl.poDetailsId = l.poDetailsId

                SET @returnMessage = 'created.';
            END
 
		COMMIT TRANSACTION

        SET @returnMessage = 'Line Item is successfully ' + @returnMessage;

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage
				
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

        IF @returnMessage IS NULL
        BEGIN
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
        END
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

