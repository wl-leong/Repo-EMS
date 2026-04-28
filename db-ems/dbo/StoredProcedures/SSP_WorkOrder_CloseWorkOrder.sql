-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> WO Module -> WO Listing -> Close WO

-- Description : Once the SO is done and approved

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-06	4.0			WL Leong	if work order have soLineItem then will lock the quantity for the SO until further release
-- 2025-05-05	3.0			WL Leong	Add in soName in reason for tracing
-- 2025-04-18	2.1			WL Leong	Add in inventory movement
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
 /**
 SSP_WorkOrder_CloseWorkOrder
 N'{"woList":[{"workOrderHeaderId":"3"}]}', 1
 **/
CREATE PROCEDURE [dbo].[SSP_WorkOrder_CloseWorkOrder]
@json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @orderJson VARCHAR(MAX)
		--DECLARE @createdBy INT = 1
		--SET @json = N'{"woList":[{"workOrderHeaderId":"1"}, {"workOrderHeaderId":"2"}]}'
		-- Read json content

        DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #confirmlist;

		SELECT workOrderHeaderId
		INTO #confirmlist
		FROM  OPENJSON(@json, '$.woList') 
   			WITH (
				workOrderHeaderId BIGINT			N'$.workOrderHeaderId'
			)

 
		DROP TABLE IF EXISTS #list;

		SELECT wo.companyID, wo.workOrderHeaderId, wo.warehouseId, wo.workOrderName, wo.workOrderStatus
		INTO #list
		FROM workOrderHeader wo  
			INNER JOIN #confirmlist li
				ON wo.workOrderHeaderId = li.workOrderHeaderId

        IF (SELECT COUNT(1) FROM #list WHERE workOrderStatus <> 5230) > 0 
		BEGIN
			SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), workOrderName), ',') + ' is not open' 
                                    FROM (SELECT DISTINCT  workOrderName
                                            FROM #list  
                                             WHERE workOrderStatus <> 5230) g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

 
--5231	Close	5229	Close
--5230	Open	5229	Open
--5229	Work Order Status	0	WO Status
 
		BEGIN TRANSACTION
            DROP TABLE IF EXISTS #itemList;
 
		    SELECT li.companyID, workOrderLineitemId, li.warehouseId, wo.workOrderName, soName, soHeaderId, soLineItemId, invId, qty
            INTO #itemList
            FROM workOrderLineItem wo
                INNER JOIN #list li
					ON wo.workOrderHeaderId = li.workOrderHeaderId  
            WHERE workOrderItemStatus = 5230 -- only open status
 
      /* Update inventoryMovement, inventoryBalanceWH, poLineItem.rcvQty */
			DECLARE @lockQty as TABLE(warehouseId INT, companyId INT,  invId INT, workOrderName VARCHAR(20), soName VARCHAR(20),qty numeric(13,4))

            INSERT INTO inventoryMovement (warehouseId, companyId, action, actionKey, invId, qty, reason, enterBy, enterDate)
			OUTPUT INSERTED.warehouseId, INSERTED.companyId, INSERTED.invId,INSERTED.actionKey, INSERTED.reason, INSERTED.qty INTO @lockQty
            SELECT warehouseId, companyId, 'PROD' as action, workOrderName, invId, qty, soName, @updateBy as enterBy, getdate() as enterDate
            FROM #itemList

      
			INSERT INTO inventoryBalanceWH_lock(companyId, warehouseId, invId, soHeaderId, soLineItemId, lockQty, enterBy, enterDate)
			SELECT lock.companyId, lock.warehouseId, lock.invId, li.soHeaderId, li.soLineItemId, lock.qty, @updateBy as enterBy, getdate() as enterDate
			FROM #itemList li
				INNER JOIN @lockQty lock
					ON li.soName = lock.soName
					AND li.invid = lock.invId
					AND li.workOrderName = lock.workOrderName
			WHERE li.soLineItemId > 0

            DROP TABLE IF EXISTS #missingWhBalance;

            SELECT bal.invBalanceId, pr.warehouseId, pr.companyId, pr.invId, qty
            INTO #missingWhBalance
            FROM #itemList pr
                LEFT JOIN inventorybalancewh bal
                    ON pr.warehouseId = bal.warehouseId
                    AND pr.companyId = bal.companyId
                    AND pr.invId = bal.invId

 
            -- create empty balance record
            IF (SELECT COUNT(1) FROM #missingWhBalance WHERE invBalanceId IS NULL) > 0
            BEGIN
                INSERT INTO inventoryBalanceWH (warehouseId, companyId, invId, balanceQty, lockQty, createBy, createDate, updateBy, updateDate)
                SELECT warehouseId, companyId, invId, 0 as balanceQty, 0 as lockQty, @updateBy, getdate(), @updateBy, getdate()
                FROM #itemList
                WHERE invBalanceId IS NULL
            END

            UPDATE bal SET
                balanceQty = bal.balanceQty + itm.qty,
				lockQty = bal.lockQty + (CASE WHEN itm.solineItemId > 0 THEN itm.qty ELSE 0 END),
                updateBy = @updateBy,
                updateDate = getdate()
            FROM inventoryBalanceWH bal
                INNER JOIN #itemList itm
                    ON bal.invId = itm.invId
                    AND bal.companyId = itm.companyId
                    AND bal.warehouseId = itm.warehouseId


			UPDATE wo SET
				workOrderStatus = 5231, -- close the WO
				updateBy = @updateBy,
				updateDate = getdate()
			FROM workOrderHeader wo
				INNER JOIN #list li
					ON wo.workOrderHeaderId = li.workOrderHeaderId  
 
			UPDATE wo SET
				workOrderItemStatus = 5231,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM workOrderLineItem wo
				INNER JOIN #itemList li
					ON wo.workOrderLineitemId = li.workOrderLineitemId  
		
        
		COMMIT TRANSACTION

        SET @ErrMessage = (SELECT 'WO# ' + STRING_AGG(CONVERT(VARCHAR(max), workOrderName), ',') + ' success close.'
                                    FROM (SELECT DISTINCT workOrderName
                                            FROM #list )g
                                  );

        SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @ErrMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

