-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-27
-- Used By:	    EMS -> Shipment Module -> Shipment Document -> Update shipment freight

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-27	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
select * from shipmentLIneItem order by 1 desc

		DECLARE @Json VARCHAR(MAX) = 
			N'{"shipmentItemList":[{
			       "shipmentLineItemId":10029,
                   "shipQty":"1360",	   
			       "lineItemNotes":"Happy"
			}]}'
 

EXEC SSP_Shipping_UpdateShipmentLineItem @json, 1
*/
 
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateShipmentLineItem]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"shipmentItemList":[{
		--	       "shipmentLineItemId":10029,
  --                 "shipQty":"1360",	   
		--	       "lineItemNotes":"Happy"
		--	}]}'
		--	, @userId INT = 1;

		DECLARE @returnMessage VARCHAR(1000);
 
        DROP TABLE IF EXISTS #shipmentItem;

        SELECT shipmentLineItemId, shipQty, lineItemNotes
        INTO #shipmentItem 
        FROM OPENJSON(@Json, '$.shipmentItemList') 
   				WITH (
					shipmentLineItemId BIGINT				    N'$.shipmentLineItemId',
                    shipQty INT                                 N'$.shipQty',
                    lineItemNotes VARCHAR(500)                  N'$.lineItemNotes'
                )
    
		DROP TABLE IF EXISTS #adjusted;

		SELECT newli.shipmentLineitemId,  newli.shipQty, li.shipQty as oldShipQty, li.shipQty - newli.shipQty as adjustQty, newli.lineItemNotes, li.lineItemStatus,
			li.shipId, li.invId, 0 as companyId, 0 as warehouseId, CAST('' as VARCHAR(50)) as soName, li.soLineItemId, 0 as soHeaderId, lrDetailsId, 0 as lrHeaderId, 0 as lrContainerId
		INTO #adjusted 
		FROM #shipmentItem newli
			INNER JOIN shipmentLineItem li
				ON newli.shipmentLineItemId = li.shipmentLineItemId
 
		UPDATE #adjusted SET
			companyId = s.companyId,
			warehouseId = s.pickUpAddrId
		FROM shipmentHeader s
		WHERE #adjusted.shipId= s.shipId
		 
		UPDATE #adjusted SET
			soName = so.soName,
			soHeaderId = so.soHeaderId
		FROM #adjusted adj
			INNER JOIN soLineItem li
				ON adj.soLineItemId = li.soLineItemId
			INNER JOIN soHeader so
				ON li.soHeaderId= so.soHeaderId

		UPDATE #adjusted SET
			lrHeaderId = li.lrHeaderId,
			lrContainerId = li.lrContainerId
		FROM #adjusted adj
			INNER JOIN lrLineItem li
				ON adj.lrDetailsId = li.lrDetailsId

        IF (SELECT COUNT(1) FROM #adjusted WHERE shipQty > oldShipQty) > 0
        BEGIN
            SET @returnMessage = 'Reverse shipment can only reduce checkout qty.';
            THROW 60000, @returnMessage,1;
        END

        IF (SELECT COUNT(1) FROM #adjusted WHERE lineItemStatus <> 2149) > 0
        BEGIN
            SET @returnMessage = 'No close item can be edit.';
            THROW 60000, @returnMessage,1;
        END
        
		BEGIN TRANSACTION

			UPDATE s SET
				shipQty = adj.shipQty,
				lineItemNotes = adj.lineItemNotes,
				updateBy = @userId,
				updateDate = getdate()
			FROM shipmentLineItem s 
				INNER JOIN #adjusted adj
					ON adj.shipmentLineItemId = s.shipmentLineItemId
       
            INSERT INTO inventoryMovement(warehouseId, companyId, action, actionKey, invId, qty, reason, enterBy, enterDate)
            SELECT warehouseId, companyId, 'REVSHIP', shipId, invId, -adjustQty, 
				lineItemNotes + '|Reverse shipQty From ' + LTRIM(RTRIM(CAST(oldShipQty as VARCHAR))) + ' to ' + LTRIM(RTRIM(CAST(shipQty as VARCHAR))), @userId, getdate()
            FROM #adjusted

			UPDATE li SET
				shpQty = li.shpQty - ttlAdjustQty,
				updateDate = getdate(),
				updateBy = @userId
			FROM soLineItem li
				INNER JOIN (SELECT soLineItemId, SUM(adjustQty) as ttlAdjustQty
							  FROM #adjusted
							  GROUP BY soLineItemId) g
					ON li.soLineItemId = g.soLineitemId
					 

			UPDATE li SET
				processQty = li.processQty - ttlAdjustQty,
				itemStatus = 2135,
				updateDate = getdate(),
				updateBy = @userId
			FROM lrLineItem li
				INNER JOIN (SELECT lrDetailsId, SUM(adjustQty) as ttlAdjustQty
							  FROM #adjusted
							  GROUP BY lrDetailsId) g
				ON li.lrDetailsId = g.lrDetailsId

			UPDATE lrContainer SET
				containerstatus = 2135,
				updateDate = getdate(),
				updateBy = @userId
			FROM #adjusted adj
			WHERE lrContainer.lrContainerId = adj.lrContainerId

			UPDATE lrHeader SET
				lrStatus = 2135,
				updateDate = getdate(),
				updateBy = @userId
			FROM #adjusted adj
			WHERE lrHeader.lrHeaderId = adj.lrHeaderId

            UPDATE inventoryBalanceWH SET
                balanceQty = balanceQty + ttlAdjustQty,
                updateBy = @userId,
                updateDate = getdate()
            FROM (	SELECT invId, warehouseId, companyId, SUM(adjustQty) as ttlAdjustQty
                    FROM #adjusted
                    GROUP BY invId, warehouseId, companyId) chkout
            WHERE inventoryBalanceWH.invId = chkout.invId
                AND inventoryBalanceWH.warehouseId = chkout.warehouseId
                AND inventoryBalanceWH.companyId = chkout.companyId
 
		COMMIT TRANSACTION
        
        SELECT '_SUCCESS_' as status, 'Shipment Line Item successfully reverse.' as returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

