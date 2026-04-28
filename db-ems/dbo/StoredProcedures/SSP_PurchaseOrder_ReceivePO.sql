-- =============================================
-- Author:		WL Leong
-- Create date: 2024-05-25
-- Used By:	    EMS -> PO Module -> PO Listing -> Received PO
--
-- Description : Change PO status to approved
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-12-02	2.0			WL Leong		DO# is compulsory
-- 2024-05-25	1.0			WL Leong		Initial
-- ==========================================================================================
-- EXEC [dbo].[SSP_PurchaseOrder_ReceivePO] N'{"POID":[{"poId":474,"DO":"FNP-SHP-25-00004.csv","warehouseId":1,"poList":{"poDetailsId":1447,"rcvQty":1364}}]}', 1
 
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_ReceivePO]
@porJson NVARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
 
		--DECLARE @porJson NVARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @porJson = N'{"poId":474,"DO":"FNP-SHP-25-00004.csv","warehouseId":1,"poList":{"poDetailsId":1447,"rcvQty":1364}}'

        DECLARE @ErrMessage VARCHAR(500)
		-- Read json content
		DROP TABLE IF EXISTS #por;

		SELECT DISTINCT poId, warehouseId, DO, notes, poList, poDetailsId, rcvQty, itemNotes 
		INTO #por
		FROM  OPENJSON(@porJson) 
   			WITH (
				poId BIGINT			    N'$.poId',
                warehouseId INT		    N'$.warehouseId',
                DO VARCHAR(100)		    N'$.DO',
                notes VARCHAR(500)		N'$.notes',
                poList NVARCHAR(MAX)	N'$.poList' AS JSON
			) CROSS APPLY OPENJSON(poList)
                WITH (
                    poDetailsId BIGINT      N'$.poDetailsId',
                    rcvQty INT              N'$.rcvQty',
                    itemNotes VARCHAR(500)  N'$.itemNotes'
                    )
 
        DECLARE @poRcvName VARCHAR(50), @warehouseId INT, @poId VARCHAR(100), @doNo VARCHAR(50)

        SET @warehouseId = (SELECT TOP 1 warehouseId FROM #por)
        SET @poId = (SELECT TOP 1 poId FROM #por)

        IF @warehouseId IS NULL
        BEGIN
			SET @ErrMessage = 'Warehouse is not select';

            THROW 60000, @ErrMessage, 1;
        END

        IF @poId IS NULL
        BEGIN
			SET @ErrMessage = 'PO# is invalid, unable to proceed';

            THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #por) = 0
        BEGIN
			SET @ErrMessage = 'No po received information being process';

            THROW 60000, @ErrMessage, 1;
        END

        DECLARE @supplierId INT, @companyId INT, @rcvNote VARCHAR(500), @poName VARCHAR(50)
        
        SELECT TOP 1 @supplierId = supplierId , @companyId = companyId, @rcvNote = p.notes, @doNo = p.do, @poName = poName
        FROM poHeader po 
            INNER JOIN #por p 
                ON po.poID = p.poId

        IF ISNULL(@doNo,'') = ''
        BEGIN
			SET @ErrMessage = 'DO# cannot be empty';

            THROW 60000, @ErrMessage, 1;
        END

        DROP TABLE IF EXISTS #lineItem;

        SELECT  p.poDetailsId, p.rcvQty, p.itemNotes, pd.supplierSkuId, pd.supplierSku, pd.invId, pd.qty-pd.rcvQty as toBeRcv, pd.itemStatus
        INTO #lineItem
        FROM #por p
            INNER JOIN poLineItem pd
                ON p.poDetailsId = pd.poDetailsId
        WHERE p.rcvQty > 0

        IF (SELECT COUNT(1) FROM #lineItem WHERE rcvQty > toBeRcv) > 0
        BEGIN
			SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '. ')
                                FROM (SELECT 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' to be received qty is more than po qty' as errorMsg 
                                    FROM #lineItem
                                    WHERE rcvQty > toBeRcv
                                    )g
                                );

            THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #lineItem WHERE itemStatus <> 1077) > 0
        BEGIN
			SET @ErrMessage = 'Only released PO can received item';

            THROW 60000, @ErrMessage, 1;
        END

        BEGIN TRANSACTION

            EXEC [dbo].[SSP_GetRunningNo] 'GRN', @companyId, @poRcvName OUTPUT

            IF @poRcvName IS NOT NULL
		    BEGIN
                DROP TABLE IF EXISTS #poReceivedList;

                DECLARE @poReceived TABLE (poRcvHeaderId BIGINT, poRcvName VARCHAR(50), supplierDo VARCHAR(50))
                DECLARE @poRcvLineItem TABLE (poRcvLineItemId BIGINT, poDetailsId BIGINT, invId INT, rcvQty INT)
                DECLARE @poRcvHeaderId BIGINT

                INSERT INTO poReceivedHeader (companyId, supplierId, poRcvDate, poRcvName, supplierDo, warehouseId, poRcvStatus, notes, enterBy, enterDate, updateBy, updateDate)
                OUTPUT INSERTED.poRcvHeaderId, INSERTED.poRcvName, INSERTED.supplierDo
                INTO @poReceived
                SELECT @companyId,  @supplierId, getdate(), @poRcvName, @doNo, @warehouseId, 3159 as poRcvStatus, ISNULL(@rcvNote, ''), @userId as enterBy, getdate() as enterDate, @userId as updateBy, getdate() as updateDate

                SET @poRcvHeaderId = (SELECT poRcvHeaderId FROM @poReceived)
 

                IF @poRcvHeaderId IS NULL
                BEGIN
                    SET @ErrMessage = 'Insert PO Received failed';
                    THROW 60000, @ErrMessage, 1;
                END 
 
                INSERT INTO poReceivedLineItem (poRcvHeaderId, poRcvName, poDetailsId, invId, supplierSkuId, supplierSku, rcvQty, notes, poRcvLineItemStatus, enterBy, enterDate, updateBy, updateDate)
                OUTPUT INSERTED.poRcvLineItemId, INSERTED.poDetailsId, INSERTED.invId, INSERTED.rcvQty
                INTO @poRcvLineItem                
                SELECT @poRcvHeaderId, @poRcvName, poDetailsId, invId, supplierSkuId, supplierSku, rcvQty, ISNULL(itemNotes, ''), 3159 as poRcvLineItemStatus, @userId as enterBy, getdate() as enterDate, @userId as updateBy, getdate() as updateDate
                FROM #lineItem
				WHERE rcvQty > 0

        /* Update inventoryMovement, inventoryBalanceWH, poLineItem.rcvQty */
                IF (SELECT COUNT(1) FROM @poRcvLineItem) > 0
                BEGIN
                    INSERT INTO inventoryMovement (warehouseId, companyId, action, actionKey, invId, qty, reason, enterBy, enterDate)
                    SELECT @warehouseId, @companyId, 'DO' as action, @poRcvName, invId, rcvQty, @poName, @userId as enterBy, getdate() as enterDate
                    FROM @poRcvLineItem

                    -- upsert warehouse balance
                    DROP TABLE IF EXISTS #warehouseBalance;

                    SELECT bal.invBalanceId, @warehouseId as warehouseId, @companyId as companyId, pr.invId, pr.rcvQty
                    INTO #warehouseBalance
                    FROM @poRcvLineItem pr
                        LEFT JOIN inventorybalancewh bal
                            ON pr.invId = bal.invId
                            AND bal.companyId = @companyId
                            AND bal.warehouseId = @warehouseId

                    INSERT INTO inventoryBalanceWh(warehouseId, companyId, invId, balanceQty, lockQty, createDate, createBy)
                    SELECT warehouseId, companyId, invId, rcvQty, 0 as lockQty, getdate(), @userId
                    FROM #warehouseBalance
                    WHERE invBalanceId IS NULL

                    UPDATE bal SET
                        balanceQty = bal.balanceQty + chk.rcvQty,
                        updateBy = @userId,
                        updateDate = getdate()
                    FROM inventoryBalanceWH bal
                        INNER JOIN #warehouseBalance chk
                            ON bal.invBalanceId = chk.invBalanceId
                    WHERE chk.invBalanceId IS NOT NULL
                    
                    UPDATE pl SET
                        rcvQty = pl.rcvQty + pr.rcvQty,
                        updateBy = @userId,
                        updateDate = getdate()
                    FROM poLineItem pl
                        INNER JOIN @poRcvLineItem pr
                            ON pl.poDetailsId = pr.poDetailsId

                    UPDATE pl SET
                        itemStatus = 1087
                    FROM poLineItem pl
                    WHERE pl.poId = @poId
                        AND pl.qty - pl.rcvQty = 0
 
                    IF (SELECT COUNT(1) FROM poLineItem WHERE poId = @poId AND itemStatus NOT IN (1087, 1086)) = 0
                    BEGIN
                        UPDATE poHeader SET
                            poStatus = 1087,
                            updateDate = getdate(),
                            updateBy = @userId
                        WHERE poId = @poId
                    END
                END  
            END
            ELSE
		    BEGIN
			    SET @ErrMessage = 'GRN prefix is not configured'; 
			    THROW 60000, @ErrMessage, 1;
		    END

        SELECT '_SUCCESS_' as status, 'PO Receive has been successful create' as returnMessage
    
        COMMIT TRANSACTION
		

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
 
		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

