
-- =============================================
-- Author:		WL Leong
-- Create date: 2024-02-01
-- Used By:	    EMS -> LR Module -> Raise LR

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION'
-- 2025-06-11	12.0        WL Leong	Fix duplicate lrHeader
-- 2025-05-30   11.0        WL Leong	rename shpToId to portId
-- 2025-05-23   10.0        ZY Wong     Handle multiples lrHeaderId pass in, add cursor
-- 2025-05-07   9.0         WL Leong	Update apiStatus '_REL_' 
-- 2025-05-03   8.0         WL Leong	Update LR Raise Date
-- 2025-01-08   7.0         WL Leong	Base on new lr module and fix shipToid
-- 2024-12-31   6.0         WL Leong	Add lrReceiveLineItem
-- 2024-05-24   5.0         ZY Wong     Add check po status
-- 2024-05-10	4.0			WL Leong	Simplify raise LR
-- 2024-02-26	3.0			WL Leong	Add soReferenceId which is the internal PI#
-- 2024-02-14	2.0			WL Leong	Add soName in orderProcess 
-- 2024-02-01	1.0			WL Leong	Initial
-- ==========================================================================================

/**
EXEC [SSP_LoadingRequest_RaiseInternalLr]
  N'{"lrList":[{"lrHeaderId":"152"},{"lrHeaderId":"156"}]}', 1
**/
 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_RaiseInternalLr]
@Json VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

		--DECLARE @createdBy INT = 1, @Json VARCHAR(MAX) = N'{"lrList":[{"lrHeaderId":"10394"},{"lrHeaderId":"10395"}]}'

	    DECLARE @returnMessage as VARCHAR(500);
        DECLARE @result TABLE (customerLrName VARCHAR(20));
        DELETE FROM @result
 
		-- Read json content
		DROP TABLE IF EXISTS #lr;

		SELECT * 
		INTO #lr
		FROM  OPENJSON(@Json, '$.lrList') 
   			WITH (
				lrHeaderId BIGINT	N'$.lrHeaderId'
			)

		DROP TABLE IF EXISTS #lrInfo;

		SELECT DISTINCT lr.lrHeaderId, lr.supplierId, lr.companyId, lrName, lr.lrShipDate, lrStatus
		INTO #lrInfo
		FROM lrHeader lr
			INNER JOIN #lr l
				ON l.lrHeaderId = lr.lrHeaderId

		IF (SELECT COUNT(1) FROM #lrInfo WHERE ISNULL(supplierId, 0) = 0) > 0 
		BEGIN
			SET @returnMessage = ('Only internal supplier allowed to raise LR.');
            THROW 60000, @returnMessage, 1; 
		END

        IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2135) > 0 
		BEGIN
            SET @returnMessage = (SELECT 'LR#' + STRING_AGG(CONVERT(VARCHAR(MAX),lrName), ', ') + ' already raised.'
                                    FROM #lrInfo
                                    WHERE lrStatus = 2135
                                );
            THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus <> 2129) > 0 
		BEGIN
            SET @returnMessage = (SELECT 'LR#' + STRING_AGG(CONVERT(VARCHAR(MAX),lrName), ', ') + ' not yet confirmed.'
                                    FROM #lrInfo
                                    WHERE lrStatus <> 2129
                                );
            THROW 60000, @returnMessage, 1;
		END

        ALTER TABLE #lrInfo ADD internal_branchId INT;

        UPDATE #lrInfo SET
            internal_branchId = s.internal_branchId
        FROM md_supplier s
        WHERE #lrInfo.supplierId = s.supplierId

		IF (SELECT COUNT(1) FROM #lrInfo WHERE internal_branchId = 0) > 0 
		BEGIN
			SET @returnMessage = ('Only internal supplier allowed to raise LR.');
            THROW 60000, @returnMessage, 1; 
		END

        DROP TABLE IF EXISTS #lrLineItem;

        SELECT li.lrDetailsId, l.supplierId, l.internal_branchId, l.lrHeaderId, l.lrName, li.lrContainerId, soHeaderId as customerSoHeaderId, soLineItemId as customerSoLineItemId, 
			poId, poDetailsId, supplierSku, invId, qty as lrQty, 0 as poStatus, CAST('' as VARCHAR(50)) as customerSku , 0 as soHeaderId, 0 as soLineItemId , itemStatus, itemNote
        INTO #lrLineItem
        FROM #lrInfo l
            INNER JOIN lrLineItem li
                ON l.lrHeaderId = li.lrHeaderId
		WHERE itemStatus <> 2130
			AND qty - confirmQty > 0
 
		UPDATE #lrLineItem SET
			poStatus = p.poStatus
		FROM poHeader p
		WHERE p.poId = #lrLineItem.poId

        IF (SELECT COUNT(1) FROM #lrLineItem WHERE poStatus <> 1077 ) > 0
        BEGIN
            SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(VARCHAR(max), lrName), ',') + ', PO''s not yet raised to supplier.' 
                                    FROM (SELECT DISTINCT lrName 
                                            FROM #lrLineItem 
                                            WHERE poStatus <> 1077)g
                                    );
            THROW 60000, @returnMessage, 1;
        END

		UPDATE #lrLineitem SET
			soHeaderId = s.soHeaderId,
			soLineItemId = s.soLineItemId,
			customerSku  = s.customerSku  ,
			invId = s.invId
		FROM #lrLineitem lr
			INNER JOIN soLineItem s
				ON lr.poDetailsId = s.ref_poLineItemId
 
		IF (SELECT COUNT(1) FROM #lrLineItem WHERE soLineItemId IS NULL) > 1
		BEGIN
			SET @returnMessage = ('No SO# found in supplier side for the LR to be raised.');
			THROW 60000, @returnMessage, 1;
		END		 

		DECLARE @lrHeaderId INT 

        DECLARE CUR_raiseLRList CURSOR LOCAL FOR  
		SELECT DISTINCT lrHeaderId
		FROM #lrInfo 

		OPEN CUR_raiseLRList  
		FETCH NEXT FROM CUR_raiseLRList 
		INTO @lrHeaderId
 
		WHILE @@FETCH_STATUS=0
		BEGIN 
/** Start: Prepare data **/
            DECLARE @companyId INT, @lrOwner INT, @customerId INT, @lrName VARCHAR(30), @portId INT;

		    DROP TABLE IF EXISTS #convertList;
		
		    SELECT lrHeaderId as ref_customerLrHeaderId, lrName as customerLrName, internal_branchId, companyId, lrShipDate
            INTO #convertList
		    FROM #lrInfo 
            WHERE lrHeaderId = @lrHeaderId

            DROP TABLE IF EXISTS #convertItems;

            SELECT lrDetailsId, lrContainerId, soHeaderId, soLineItemId, 0 as poId, 0 as poDetailsId, customerSku, invId, lrQty, itemNote, 2135 as itemStatus
            INTO #convertItems
            FROM #lrLineitem
            WHERE lrHeaderId = @lrHeaderId

            SET @companyId = (SELECT TOP 1 internal_branchId FROM #convertList);
            SET @lrOwner = (SELECT TOP 1 companyId FROM #convertList);
            SET @customerId = (SELECT customerId FROM md_customer WHERE companyId = @companyId AND internal_branchId = @lrOwner);

		    --SET @portId = (SELECT shipToId
						--        FROM md_shipToDestination st
						--		        INNER JOIN md_warehouse wh
						--			        ON st.warehouseId = wh.warehouseId
						--			        AND st.companyId = @companyId
						--        WHERE wh.companyId = @lrOwner
      --                          );

            DROP TABLE IF EXISTS #convertContainers;

            SELECT lrHeaderId, lrName, containerTypeId, containerSeq, containerNo, earlyShipDate, lateShipDate, portId, notes, 2135 as containerStatus,
				cargoReadyDate, forwarderId, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo,
				haulierId, ETD, ETA, MAAP, Pouch, containerSealNo, containerMaxGross, containerTare, containerPullInDate, containerPullOutDate, lrContainerId
            INTO #convertContainers
			FROM lrContainer
            WHERE lrHeaderId = @lrHeaderId

/** End: Prepare data **/

            DECLARE @newOrder AS TABLE (lrHeaderId BIGINT, lrName VARCHAR(30), ref_customerLrHeaderId BIGINT, customerLrName VARCHAR(30));
            DELETE FROM @newOrder
		    DECLARE @newLrName VARCHAR(20);
	    
            BEGIN TRANSACTION

			    EXEC [dbo].[SSP_GetRunningNo] 'LR', @companyId, @newLrName OUTPUT

			    IF @newLrName IS NOT NULL
			    BEGIN
 
				    INSERT INTO lrHeader(companyId, supplierId, customerId, ref_customerLrHeaderId, customerLrName, lrDate, lrShipDate,  lrName,  enterBy, enterDate, lrStatus, apiStatus)
				    OUTPUT INSERTED.lrHeaderId, INSERTED.lrName, INSERTED.ref_customerLrHeaderId, INSERTED.customerLrName
				    INTO @newOrder
				    SELECT @companyId, 0, @customerId, ref_customerLrHeaderId, customerLrName, getdate() as requestDate, lrShipDate,  @newLrName,  1, getdate() as requestDate, 2135 as lrStatus, '_REL_' -- released when raise internal
				    FROM #convertList
 
				    IF (SELECT COUNT(1) FROM @newOrder) = 0
				    BEGIN
					    SET @returnMessage = ('Raise LR to supplier encounter creation problem.');
					    THROW 60000, @returnMessage, 1;
				    END
				    ELSE
				    BEGIN
					    DECLARE @newContainer AS TABLE (lrHeaderId BIGINT, lrName VARCHAR(30), lrContainerId BIGINT, ref_lrContainerId BIGINT);
                        DELETE FROM @newContainer
 
					    INSERT INTO lrContainer (lrHeaderId, lrName, containerTypeId, containerSeq, containerNo, earlyShipDate, lateShipDate, portId, notes, containerStatus,
						    cargoReadyDate, forwarderId, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo,
						    haulierId, ETD, ETA, MAAP, Pouch, containerSealNo, containerMaxGross, containerTare, containerPullInDate, containerPullOutDate,
						    ref_lrContainerId, enterBy)
					    OUTPUT INSERTED.lrHeaderId, INSERTED.lrName, INSERTED.lrContainerId, INSERTED.ref_lrContainerId
					    INTO @newContainer
					    SELECT o.lrHeaderId, o.lrName, containerTypeId, containerSeq, containerNo, earlyShipDate, lateShipDate, portId, notes, containerStatus,
						    cargoReadyDate, forwarderId, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo,
						    haulierId, ETD, ETA, MAAP, Pouch, containerSealNo, containerMaxGross, containerTare, containerPullInDate, containerPullOutDate, lrContainerId, 1 as enterBy
					    FROM #convertContainers lr
						    INNER JOIN @newOrder o
							    ON lr.lrHeaderId = o.ref_customerLrHeaderId
 
 					    IF (SELECT COUNT(1) FROM @newContainer) = 0
					    BEGIN
						    SET @returnMessage = ('Raise LR to supplier encounter creation problem');
						    THROW 60000, @returnMessage, 1;
					    END				 

					    INSERT INTO lrLineItem (lrHeaderId, lrName, lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, supplierSku, invId, qty, itemNote, itemStatus, enterBy, enterDate, ref_lrLineItemId)
					    SELECT c.lrHeaderId, c.lrName, c.lrContainerId, soHeaderId, soLineItemId, poId, poDetailsId, customerSku, invId, lrQty, itemNote, itemStatus, 1 as updateBy, getdate(), lr.lrDetailsId
					    FROM #convertItems lr
						    INNER JOIN @newContainer c
							    ON lr.lrContainerId = c.ref_lrContainerId
 
					    UPDATE lr SET
						    confirmQty = confirmQty + qty,
						    updateDate = getdate(),
						    updateBy = @createdBy
					    FROM lrLineItem lr
						    INNER JOIN #convertItems li
							    ON lr.lrDetailsId = li.lrDetailsId

					    UPDATE lr SET
						    itemStatus = 2135
					    FROM lrLineItem lr
						    INNER JOIN #convertItems li
							    ON lr.lrDetailsId = li.lrDetailsId
					 
					    UPDATE lr SET 
						    containerStatus = 2135,
						    updateDate = getdate(),
						    updateBy = @createdBy
					    FROM lrContainer lr
						    INNER JOIN #convertItems li
							    ON lr.lrContainerId = li.lrContainerId

					    UPDATE lr SET 
						    apiStatus = '_REL_',
						    lrStatus = 2135,
                            lrRequestDate = getdate(),
						    updateBy = @createdBy
					    FROM lrHeader lr
						    INNER JOIN @newOrder li
							    ON lr.lrHeaderId = li.ref_customerLrHeaderId

                        INSERT INTO @result (customerLrName)
			            SELECT customerLrName
                        FROM @newOrder
                        

				    END
			    END 
		        ELSE
		        BEGIN
			        SET @returnMessage = ('LR prefix is not configured.'); 
                    THROW 60000, @returnMessage, 1;
		        END 
 
            COMMIT TRANSACTION

			FETCH NEXT FROM CUR_raiseLRList 
			INTO @lrHeaderId 
		END

		CLOSE CUR_raiseLRList
		DEALLOCATE CUR_raiseLRList

		SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(VARCHAR(MAX), customerLrName), ', ') + ' success raised.'
                                FROM @result
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
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

