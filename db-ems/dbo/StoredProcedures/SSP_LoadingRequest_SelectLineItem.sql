-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-18
-- Used By:	    EMS -> LR Module -> LR LIsting -> View LR Line Item

-- Description : View Lr LIne Item

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-24   4.0         ZY Wong     Return lrContainerId
-- 2024-05-13	3.0			WL Leong	Get the poName 
-- 2024-04-24	2.0			WL Leong	Change to only list the container info in the packing list
-- 2024-04-18	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_SelectLineItem 10346, 1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SelectLineItem]
@lrHeaderId BIGINT,
@containerSeq INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
        
        --DECLARE @lrHeaderId BIGINT = 10346, @containerSeq INT = 1

		DECLARE @errorMessage VARCHAR(200);
		DECLARE @companyId INT = (SELECT companyId FROM lrHeader where lrHeaderId = @lrHeaderId);

		DROP TABLE IF EXISTS #containerInfo;

		SELECT lrContainerId, containerSeq
		INTO #containerInfo
		FROM lrContainer
		WHERE lrHeaderId = @lrHeaderId
			AND containerSeq = @containerSeq


        DROP TABLE IF EXISTS #list;
 
        SELECT  lrDetailsId, lr.lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invId, qty, confirmQty, itemNote, itemStatus, lr.containerSeq
        INTO #list
        FROM lrLineItem li
			INNER JOIN #containerInfo lr
				on li.lrContainerId = lr.lrContainerId
 
 
        DROP TABLE IF EXISTS #lrLineItem;

        SELECT lrDetailsId, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invId, qty, confirmQty, itemNote, mcStatus.categoryName as itemStatus, containerSeq 
        INTO #lrLineItem
        FROM #list lr 
            INNER JOIN md_masterCategory mcStatus
                ON lr.itemStatus = mcStatus.categoryId
                AND mcStatus.categoryParentId = 2128

        ALTER TABLE #lrLineItem ADD merchantSku VARCHAR(50);
        ALTER TABLE #lrLineItem ADD customerSku VARCHAR(50);
        ALTER TABLE #lrLineItem ADD soName VARCHAR(50);
        ALTER TABLE #lrLineItem ADD customerId INT;
        ALTER TABLE #lrLineItem ADD customerPO VARCHAR(200);
        ALTER TABLE #lrLineItem ADD poName VARCHAR(50);

		DROP TABLE IF EXISTS #warehouseBalance;

		SELECT invId, SUM(balanceQty) as invBalance
		INTO #warehouseBalance
		FROM inventoryBalanceWH 
		WHERE companyId = @companyId
		GROUP BY invId

		ALTER TABLE #lrLineItem ADD invBalance INT;

		UPDATE #lrLineItem SET
			invBalance = inv.invBalance
		FROM #warehouseBalance inv
		WHERE #lrLineItem.invId = inv.invId

        UPDATE lr SET
            poName = p.poName
        FROM #lrLineItem lr
            INNER JOIN poHeader p
                ON lr.poId = p.poId

        UPDATE lr SET
            soName = s.soName,
            customerPO = s.customerPO,
            customerId = s.customerId
        FROM #lrLineItem lr
            INNER JOIN soHeader s
                ON lr.soHeaderId = s.soHeaderId

        UPDATE lr SET
            merchantSku = s.merchantSku,
            customerSku = s.customerSku
        FROM #lrLineItem lr
            INNER JOIN soLineItem s
                ON lr.soLineItemId = s.soLineItemId


        SELECT lrDetailsId, lrContainerId, poDetailsId, containerSeq, poName, soName, customerPO, supplierSku, merchantSku, qty as lrQty, confirmQty, ISNULL(invBalance, 0) as invBalance,
            itemNote, itemStatus, customerId
        FROM #lrLineItem  
        ORDER BY containerSeq, supplierSku
 
 
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO

