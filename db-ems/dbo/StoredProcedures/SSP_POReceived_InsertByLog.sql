-- =============================================
-- AuDOor:		ZY Wong
-- Create date: 2024-04-15
-- Used By:	    EMS -> PO Module -> GRN -> Import GRN

-- Description : Import GRN from dump table

-- History: * Put DOe latest change on DOe top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-23   1.1         ZY Wong     CLOSE poLineItem if ttl rcvQty = poQty, CLOSE poHeader if all line item is CLOSED/ CANCEL
-- 2024-04-15	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_POReceived_InsertByLog] 4, '20240417033035_20240417_DOUpload_Template.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_POReceived_InsertByLog]
@companyId INT,
@fileName VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
		
		--DECLARE @companyId INT = 4, @fileName VARCHAR(150) = '20240417033035_20240417_DOUpload_Template.xlsx', @userId INT = 1;

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #tempPoReceived;

		SELECT recordType, column1, column2, column3, column4, column5, column6
		INTO #tempPoReceived
		FROM temp_poReceivedLog
		WHERE [fileName] = @fileName
            AND ISNULL(recordType,'') <> ''

        DROP TABLE IF EXISTS #tempDO;

        SELECT recordType, column1 as doNo, column2 as doDate, ISNULL(column3,'') as notes
        INTO #tempDO
        FROM #tempPoReceived
        WHERE recordType = 'DO'

        DROP TABLE IF EXISTS #tempDL;

        SELECT recordType, column1 as doNo, column2 as poName, column3 as warehouseLabel, column4 as supplierSku, column5 as rcvQty, ISNULL(column6,'') as notes
        INTO #tempDL
        FROM #tempPoReceived
        WHERE recordType = 'DL'

/*** Start: data validation ***/

        IF (SELECT COUNT(recordType) FROM #tempPoReceived WHERE recordType NOT IN ('DO','DL')) > 0
        BEGIN
            SET @ErrMessage = 'Invalid record type. [DO/DL]';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDO) = 0 OR (SELECT COUNT(1) FROM #tempDL) = 0
        BEGIN
            SET @ErrMessage = 'Record type [DO/DL] is missing.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDO WHERE ISNULL(doNo,'') = '') > 0 OR (SELECT COUNT(1) FROM #tempDL WHERE ISNULL(doNo,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'DO # is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDO WHERE ISNULL(doDate,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'DO Date is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE ISNULL(warehouseLabel,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'Warehouse Label is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE ISNULL(poName,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'PO # is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE ISNULL(supplierSku,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'Supplier Sku is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE ISNULL(rcvQty,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'Rcv Qty is compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDO WHERE ISDATE(doDate) = 0) > 0
        BEGIN
            SET @ErrMessage = 'Invalid DO Date, date format [yyyymmdd].';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE ISNUMERIC(rcvQty) = 0) > 0
        BEGIN
            SET @ErrMessage = 'Invalid Rcv Qty, not an integer value.';
			THROW 60000, @ErrMessage, 1;
        END

        DROP TABLE IF EXISTS #chkDoNo;

        SELECT DISTINCT doNo, SUM(countDo) as countDo, SUM(countDl) as countDl
        INTO #chkDoNo
        FROM (
            SELECT doNo, COUNT(DISTINCT doNo) as countDo, 0 as countDl 
            FROM #tempDO 
            GROUP BY doNo
            UNION ALL
            SELECT doNo, 0 as countDo, COUNT(DISTINCT doNo) as countDl 
            FROM #tempDL
            GROUP BY doNo
        )g
        GROUP BY doNo

        IF (SELECT COUNT(1) FROM #chkDoNo WHERE countDo <> countDl) > 0
        BEGIN
            SET @ErrMessage = (SELECT 'DO # ' + STRING_AGG(CONVERT(NVARCHAR(max), doNo), ',') + ' is/are missing Record type [DO/DL].' FROM #chkDoNo WHERE countDo <> countDl);
			THROW 60000, @ErrMessage, 1;
        END

        ALTER TABLE #tempDL ADD companyId INT;
        ALTER TABLE #tempDL ADD warehouseId INT;
        ALTER TABLE #tempDL ADD poId BIGINT;
        ALTER TABLE #tempDL ADD poDetailsId BIGINT;
        ALTER TABLE #tempDL ADD invId INT;
        ALTER TABLE #tempDL ADD poQty INT;
        ALTER TABLE #tempDL ADD poRcvQty INT;

        UPDATE dl SET
            warehouseId = wh.warehouseId
        FROM  #tempDL dl
            INNER JOIN md_Warehouse wh
                ON dl.warehouseLabel = wh.label
                AND wh.status = 1
        WHERE wh.companyId = @companyId

        UPDATE dl SET
            poId = ph.poId,
            companyId = ph.companyId
        FROM #tempDL dl
            INNER JOIN poHeader ph
                ON dl.poName = ph.poName
        WHERE ph.companyId = @companyId

        IF (SELECT COUNT(1) FROM #tempDL WHERE warehouseId IS NULL) > 0
        BEGIN
            SET @ErrMessage = (SELECT 'Warehouse Label ' + STRING_AGG(CONVERT(NVARCHAR(max), warehouseLabel), ',') + ' is/are not found in the system.' 
                                FROM #tempDL 
                                WHERE warehouseId IS NULL);
            THROW 60000, @ErrMessage, 1;
        END

   --     DROP TABLE IF EXISTS #checkWhLabelDuplicate;

   --     SELECT doNo, warehouseLabel, COUNT(warehouseLabel) as countWhLabel
   --     INTO #checkWhLabelDuplicate
   --     FROM #tempDL
   --     GROUP BY doNo, warehouseLabel

   --     IF (SELECT COUNT(1) FROM #checkWhLabelDuplicate WHERE countWhLabel > 1) > 0
   --     BEGIN
   --         --SET @ErrMessage = (SELECT TOP 1 '2 Warehouse Label ' + warehouseLabel + ' is duplicate in DO # ' + doNo FROM #checkWhLabelDuplicate WHERE countWhLabel > 1);
   --         SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '. ')
   --                             FROM (SELECT doNo, 'Warehouse Label ' + STRING_AGG(CONVERT(NVARCHAR(max), warehouseLabel), ',') + ' is duplicate in DO # ' + doNo as errorMsg 
   --                                 FROM #checkWhLabelDuplicate 
   --                                 WHERE countWhLabel > 1
   --                                 GROUP BY doNo
   --                                 )g
   --                             );
			--THROW 60000, @ErrMessage, 1;
   --     END 

        DROP TABLE IF EXISTS #checkWhLabelDistinct;

        SELECT doNo, COUNT(DISTINCT warehouseLabel) as countWhLabel
        INTO #checkWhLabelDistinct
        FROM #tempDL
        GROUP BY doNo

        IF (SELECT COUNT(1) FROM #checkWhLabelDistinct WHERE countWhLabel > 1) > 0
        BEGIN
            SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '. ')
                                FROM (SELECT chk.doNo, 'DO # ' + chk.doNo + ' have multiple Warehouse Label ' + STRING_AGG(CONVERT(NVARCHAR(max), dl.warehouseLabel), ',') as errorMsg 
                                    FROM (SELECT DISTINCT doNo, warehouseLabel FROM #tempDL) dl
                                        INNER JOIN #checkWhLabelDistinct chk
                                            ON dl.doNo = chk.doNo
                                    WHERE chk.countWhLabel > 1
                                    GROUP BY chk.doNo
                                    )g
                                );
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE poId IS NULL) > 0
        BEGIN
			SET @ErrMessage = (SELECT 'PO # ' + STRING_AGG(CONVERT(NVARCHAR(max), poName), ',') + ' is/are not found in the system.' 
                                FROM #tempDL 
                                WHERE poId IS NULL);
            THROW 60000, @ErrMessage, 1;
        END

        UPDATE dl SET
            poDetailsId = pl.poDetailsId,
            invId = pl.invId,
            poQty = pl.qty,
            poRcvQty = pl.rcvQty
        FROM #tempDL dl
            INNER JOIN poLineItem pl
                ON dl.poId = pl.poId
                AND dl.supplierSku = pl.supplierSku

        IF (SELECT COUNT(1) FROM #tempDL WHERE poDetailsId IS NULL) > 0
        BEGIN
            SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '. ')
                                FROM (SELECT poName, 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' is/are not found in PO # ' + poName as errorMsg 
                                    FROM #tempDL
                                    WHERE poDetailsId IS NULL
                                    GROUP BY poName
                                    )g
                                );
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #tempDL WHERE poRcvQty + rcvQty > poQty) > 0
        BEGIN
			SET @ErrMessage = (SELECT STRING_AGG(CONVERT(NVARCHAR(max), errorMsg), '. ')
                                FROM (SELECT poName, 'Supplier Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), supplierSku), ',') + ' (PO # ' + poName + ') have Rcv Qty more than PO Qty in system' as errorMsg 
                                    FROM #tempDL
                                    WHERE poRcvQty + rcvQty > poQty
                                    GROUP BY poName
                                    )g
                                );
            THROW 60000, @ErrMessage, 1;
        END

        DROP TABLE IF EXISTS #checkDoNoExistsForSameSup;

        SELECT DISTINCT prh.poRcvHeaderId, dl.doNo, ph.supplierId
        INTO #checkDoNoExistsForSameSup
        FROM #tempDL dl
            INNER JOIN poHeader ph
                ON dl.poId = ph.poID
            LEFT JOIN poReceivedHeader prh
                ON dl.doNo = prh.supplierDO
                AND ph.supplierId = prh.supplierId
                AND dl.companyId = prh.companyId

        IF (SELECT COUNT(1) FROM #checkDoNoExistsForSameSup WHERE poRcvHeaderId IS NOT NULL) > 0
        BEGIN
            SET @ErrMessage = (SELECT 'DO # ' + STRING_AGG(CONVERT(NVARCHAR(max), doNo), ',') + ' already exists in the system.' FROM #checkDoNoExistsForSameSup WHERE poRcvHeaderId IS NOT NULL);
			THROW 60000, @ErrMessage, 1;
        END
            

/*** End: data validation ***/

        DECLARE @doNo VARCHAR(50);

        DECLARE CUR_do CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT DISTINCT doNo
		FROM #tempDO
 
		OPEN CUR_do
		FETCH NEXT FROM CUR_do INTO @doNo
 
		WHILE @@FETCH_STATUS = 0
		BEGIN

            DECLARE @poRcvName VARCHAR(50) = '';

			EXEC [dbo].[SSP_GetRunningNo] 'GRN', @companyId, @poRcvName OUTPUT

            IF @poRcvName IS NOT NULL
			BEGIN
        
                DROP TABLE IF EXISTS #poReceivedList;

                DECLARE @supplierId INT = (SELECT TOP 1 supplierId FROM poHeader po INNER JOIN #tempDL dl ON po.poID = dl.poId WHERE dl.doNo = @doNo)

                DECLARE @poReceived TABLE (poRcvHeaderId BIGINT, poRcvName VARCHAR(50), supplierDo VARCHAR(50))
                DECLARE @poRcvHeaderId BIGINT

                INSERT INTO poReceivedHeader (companyId, supplierId, poRcvDate, poRcvName, supplierDo, poRcvStatus, notes, enterBy, enterDate, updateBy, updateDate)
                OUTPUT INSERTED.poRcvHeaderId, INSERTED.poRcvName, INSERTED.supplierDo
                INTO @poReceived
                SELECT @companyId,  @supplierId, doDate, @poRcvName, @doNo, 3159 as poRcvStatus, notes, @userId as enterBy, getdate() as enterDate, @userId as updateBy, getdate() as updateDate
                FROM #tempDO
                WHERE doNo = @doNo

                SET @poRcvHeaderId = (SELECT poRcvHeaderId FROM @poReceived)

                IF @poRcvHeaderId IS NULL
                BEGIN
                    SET @ErrMessage = 'Insert PO Received failed';
                    THROW 60000, @ErrMessage, 1;
                END 

                INSERT INTO poReceivedLineItem (poRcvHeaderId, poRcvName, poDetailsId, warehouseId, supplierSku, rcvQty, notes, poRcvLineItemStatus, enterBy, enterDate, updateBy, updateDate)
                SELECT @poRcvHeaderId, @poRcvName, poDetailsId, warehouseId, supplierSku, rcvQty, notes, 3159 as poRcvLineItemStatus, @userId as enterBy, getdate() as enterDate, @userId as updateBy, getdate() as updateDate
                FROM #tempDL
                WHERE doNo = @doNo

        /* Update inventoryMovement, inventoryBalanceWH, poLineItem.rcvQty */

                INSERT INTO inventoryMovement (warehouseId, companyId, action, poName, invId, qty, reason, enterBy, enterDate)
                SELECT warehouseId, companyId, 'DO' as action, poName, invId, rcvQty, '', @userId as enterBy, getdate() as enterDate
                FROM #tempDL

                DROP TABLE IF EXISTS #checkWHBalanceExists;

                SELECT bal.invBalanceId, pr.warehouseId, pr.companyId, pr.invId, rcvQty
                INTO #checkWHBalanceExists
                FROM #tempDL pr
                    LEFT JOIN inventorybalancewh bal
                        ON pr.warehouseId = bal.warehouseId
                        AND pr.companyId = bal.companyId
                        AND pr.invId = bal.invId

                DECLARE @inventoryBalanceWH TABLE (invBalanceId INT, warehouseId INT, companyId INT, invId BIGINT)

                -- create empty balance record
                IF (SELECT COUNT(1) FROM #checkWHBalanceExists WHERE invBalanceId IS NULL) > 0
                BEGIN
                    INSERT INTO inventoryBalanceWH (warehouseId, companyId, invId, balanceQty, lockQty, createBy, createDate, updateBy, updateDate)
                    SELECT warehouseId, companyId, invId, rcvQty as balanceQty, 0 as lockQty, @userId, getdate(), @userId, getdate()
                    FROM #checkWHBalanceExists
                    WHERE invBalanceId IS NULL
                END

                UPDATE bal SET
                    balanceQty = bal.balanceQty + chk.rcvQty,
                    updateBy = @userId,
                    updateDate = getdate()
                FROM inventoryBalanceWH bal
                    INNER JOIN #checkWHBalanceExists chk
                        ON bal.invBalanceId = chk.invBalanceId
                WHERE chk.invBalanceId IS NOT NULL
                    
                DECLARE @closePoLine TABLE (poDetailsId BIGINT, poQty INT, rcvQty INT);
                DECLARE @closePo TABLE (poId BIGINT);

                UPDATE pl SET
                    rcvQty = pl.rcvQty + pr.rcvQty,
                    itemNote = CASE WHEN ISNULL(itemNote,'') = '' THEN notes ELSE itemNote + ', ' + notes END,
                    updateBy = @userId,
                    updateDate = getdate()
                OUTPUT INSERTED.poDetailsId, INSERTED.qty, INSERTED.rcvQty
                INTO @closePoLine
                FROM poLineItem pl
                    INNER JOIN #tempDL pr
                        ON pl.poDetailsId = pr.poDetailsId

                -- CLOSE poLineItem if ttl rcvQty = poQty
                IF (SELECT COUNT(1) FROM @closePoLine WHERE poQty = rcvQty) > 0
                BEGIN
                    UPDATE pl SET
                        itemStatus = 1087, --close
                        updateBy = @userId,
                        updateDate = getdate()
                    OUTPUT INSERTED.poId
                    INTO @closePo
                    FROM poLineItem pl
                        INNER JOIN @closePoLine l
                            ON pl.poDetailsId = l.poDetailsId
                    WHERE l.poQty = l.rcvQty

                END

                -- CLOSE poHeader if all line item is CLOSED/ CANCEL
                DROP TABLE IF EXISTS #chkpoStatus;

                SELECT po.poId, poDetailsId, itemStatus
                INTO #chkpoStatus
                FROM poLineItem pl
                    INNER JOIN @closePo po
                        ON pl.poId = po.poId

                DROP TABLE IF EXISTS #countPoLine;

                SELECT p.poId, p.ttlPoLine, g.ttlCloseLine
                INTO #countPoLine
                FROM (SELECT poId, COUNT(poDetailsId) as ttlPoLine FROM #chkpoStatus GROUP BY poId)p, 
                    (SELECT poId, COUNT(poDetailsId) as ttlCloseLine FROM #chkpoStatus WHERE itemStatus IN (1086,1087) GROUP BY poId)g
                WHERE p.poId = g.poId

                IF (SELECT COUNT(1) FROM #countPoLine WHERE ttlPoLine = ttlCloseLine) > 0
                BEGIN
                    UPDATE po SET
                        poStatus = 1087, --close
                        updateBy = @userId,
                        updateDate = getdate()
                    FROM poHeader po
                        INNER JOIN #countPoLine l
                            ON po.poId = l.poId 
                    WHERE l.ttlPoLine = l.ttlCloseLine
                END

            END
            ELSE
			BEGIN
				SET @ErrMessage = 'GRN prefix is not configured'; 
				THROW 60000, @ErrMessage, 1;
			END
			
            DELETE FROM @poReceived;
            DELETE FROM @inventoryBalanceWH;
            DELETE FROM @closePoLine;
            DELETE FROM @closePo;

            FETCH NEXT FROM CUR_do INTO @doNo
		END
		CLOSE CUR_do
		DEALLOCATE CUR_do

		COMMIT TRANSACTION

		DELETE FROM temp_poReceivedLog WHERE fileName = @fileName

		SELECT '_SUCCESS_' as status, 'PO Receive has been successful create' as returnMessage
				
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
 
		DELETE FROM temp_poReceivedLog WHERE fileName = @fileName

		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

