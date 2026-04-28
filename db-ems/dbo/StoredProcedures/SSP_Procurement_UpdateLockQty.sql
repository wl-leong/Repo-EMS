-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-22
-- Used By:	    EMS -> Procurement Module -> Pending List -> Lock Qty 

-- Description : Lock Qty for pending list

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-22	1.0			ZY Wong		Initial
-- ==========================================================================================
/*
	EXEC [SSP_Procurement_UpdateLockQty] N'{"lockList":[{"procurementProcessId":"2","invBalanceId":"605","lockQty":"12"}]}',1
	select * from procurementProcess where procurementProcessId = 2
	select * from inventoryBalanceWH where invBalanceId = 605
	select * from WarehouseBalanceLock 
*/
CREATE PROCEDURE [dbo].[SSP_Procurement_UpdateLockQty]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
SET XACT_ABORT ON;
SET NOCOUNT ON;

	BEGIN TRY

		BEGIN TRANSACTION

		--DECLARE @updateBy INT = 1

		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"lockList":[{
		--	   "procurementProcessId":"2",
		--	   "invBalanceId":"605",
		--	   "lockQty":"10"
		--	}]}'

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #lockList;
-- lockQty change to numeric(13,1) in future
		SELECT *
		INTO #lockList
		FROM  OPENJSON(@Json, '$.lockList') 
   				WITH (
					procurementProcessId BIGINT			N'$.procurementProcessId',
					invBalanceId INT					N'$.invBalanceId',
					lockQty NUMERIC(13,4)				N'$.lockQty'
				)

		DROP TABLE IF EXISTS #procurementList;

		SELECT pp.companyId, pp.procurementProcessId, pp.soLineItemId, lock.invBalanceId, rawBomInvId as lockInvId, 
			lock.lockQty - pp.lockQty as newLockQty, pp.status
		INTO #procurementList
		FROM procurementProcess pp
			INNER JOIN #lockList lock
				ON pp.procurementProcessId = lock.procurementProcessId

		--IF (SELECT COUNT(1) FROM #procurementList WHERE status = 0) < 1
		--BEGIN
		--	SET @ErrMessage = 'This line is already locked';
		--	THROW 60000, @ErrMessage, 1;
		--END

		DROP TABLE IF EXISTS #balanceList;

		SELECT l.procurementProcessId, l.soLineItemId, l.invBalanceId, wh.warehouseId,
			wh.label as warehouseName, l.newLockQty, CONVERT(NUMERIC(13,4), (bal.balanceQty - bal.lockQty)) as availableQty, l.status
		INTO #balanceList
		FROM inventoryBalanceWH bal 
			INNER JOIN md_Warehouse wh
				ON bal.warehouseId = wh.warehouseId
			INNER JOIN #procurementList l
				ON bal.invBalanceId = l.invBalanceId

		IF (SELECT COUNT(1) FROM #balanceList WHERE availableQty >= newLockQty) > 0
		BEGIN
			
			UPDATE bal SET
				lockQty = lockQty + l.newLockQty,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM inventoryBalanceWH bal
				INNER JOIN #balanceList l
					ON bal.invBalanceId = l.invBalanceId
					 
			UPDATE p SET
				status = CASE WHEN p.lockQty + bal.newLockQty = RawBomTotalQty THEN 1 ELSE 0 END,
				lockQty = p.lockQty + bal.newLockQty,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM procurementProcess p
				INNER JOIN #balanceList bal
					ON p.procurementProcessId = bal.procurementProcessId

			INSERT INTO inventoryBalanceWh_Lock (procurementProcessId, soLineItemId, invBalanceId, lockQty, notes, status, enterBy, enterDate, updateBy, updateDate)
			SELECT procurementProcessId, soLineItemId, invBalanceId, newLockQty, '' as notes, 0 as status, @updateBy, getdate(), @updateBy, getdate()
			FROM #balanceList
 
		END  
		ELSE
		BEGIN
			SET @ErrMessage = (SELECT 'Warehouse ' + warehouseName + ' don''t have enough inventory balance to lock' FROM #balanceList);
			THROW 60000, @ErrMessage, 1;
		END

		COMMIT TRANSACTION

		SET @ErrMessage = (SELECT 'Lock Qty ' + CAST(newlockQty as varchar) + ' are successfully locked in Warehouse ' + warehouseName FROM #balanceList);

		SELECT '_SUCCESS_' as status, @ErrMessage as returnMessage

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
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

