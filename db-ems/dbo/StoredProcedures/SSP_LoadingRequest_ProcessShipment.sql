-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> OP Module -> LR Receive -> Process Shipment

-- Description : Load Request for factory, so they can prepare packing list for container loading

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-06	7.0			WL Leong	Fix POD, release lockQty
-- 2024-11-29   6.0         ZY Wong     Add containerNo, containerSealNo, containerMaxGross, containerTare, haulierId, containerPullInDate, containerPullOutDate into #lrListing
-- 2024-02-29	5.0			WL Leong	Add inventory movement
-- 2024-01-30	4.2			WL Leong	Add lrShipToId
-- 2024-01-29	4.1			ZY Wong		Fix poName repeating in error msg
-- 2024-01-29	4.0			WL Leong	Add another validation for 0 lines conversion
-- 2024-01-22	3.0			ZY Wong		Add XACT_ABORT
-- 2024-01-22	2.0			WL Leong	Change of some column
-- 2023-12-10	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_LoadingRequest_ProcessShipment
10371, 4, 3,1
update lrHeader set lrstatus = 2135
update lrLineItem set itemStatus = 2135, confirmQty = 0
select * from shipmentHeader
select * from shipmentLineItem
 truncate table shipmentHeader
select * from lrHeader
select * from lrLineItem
**/
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_ProcessShipment]
@lrHeaderId BIGINT,
@companyId INT,
@warehouseId INT,
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @lrHeaderId BIGINT =10371, @warehouseId BIGINT = 1, @companyId INT = 4, @createdBy INT = 1
 		DECLARE @returnMessage as VARCHAR(500)

		DROP TABLE IF EXISTS #lrHeader;

		SELECT lrHeaderId, companyId, customerId, lrName, lrDate, ref_customerLrHeaderId, lrStatus
		INTO #lrHeader
		FROM lrHeader
		WHERE lrHeaderId = @lrHeaderId

		IF (SELECT COUNT(1) FROM #lrHeader) = 0
		BEGIN
			SET @returnMessage = ( 'LR Header ' + @returnMessage + ' selected is not valid'); 
            THROW 60000, @returnMessage, 1;
		END

		DROP TABLE IF EXISTS #lrListing;

		SELECT l.companyId, l.lrHeaderId, l.lrName, li.notes, lrStatus, 
            li.lrContainerId, li.containerTypeId, li.containerSeq, li.containerNo, li.portId, li.cargoReadyDate,
            li.forwarderId, li.forwarderBookingNo, li.ETD, li.ETA,
            li.containerSealNo, li.containerMaxGross, li.containerTare, li.haulierId, li.containerPullInDate, li.containerPullOutDate
        INTO #lrListing
		FROM #lrHeader l
            INNER JOIN lrContainer li
                ON l.lrHeaderId = li.lrHeaderId
		WHERE containerStatus = 2135

		DROP TABLE IF EXISTS #lrLineItem;

		SELECT lr.companyId, lr.lrHeaderId, lr.lrName, lr.notes, lr.containerNo, lr.portId, lr.cargoReadyDate,
            lr.lrContainerId, lr.containerTypeId, lr.containerSeq, lr.forwarderId, lr.forwarderBookingNo, lr.ETD, lr.ETA,
            lr.containerSealNo, lr.containerMaxGross, lr.containerTare, lr.haulierId, lr.containerPullInDate, lr.containerPullOutDate,
			li.soheaderId, li.soLineItemId, li.invId, li.supplierSku, li.qty - processQty as shipQty, li.itemNote, CAST('' as VARCHAR(30)) as soName
		INTO #lrLineItem 
		FROM #lrListing lr
			INNER JOIN lrLineItem li
				ON lr.lrContainerId = li.lrContainerId
		WHERE li.qty - li.processQty > 0
			AND itemStatus = 2135
				 
		UPDATE #lrLineItem SET
			soName = s.soName
		FROM soHeader s
		WHERE s.soHeaderId = s.soHeaderId
 

        ALTER TABLE #lrLineItem ADD warehouseBalance INT 

		DROP TABLE IF EXISTS #warehouseBal;

 		SELECT bal.invId, SUM(balanceQty) as balanceQty
		INTO #warehouseBal
		FROM #lrLineItem lr
            INNER JOIN inventoryBalanceWh bal
                ON lr.companyId = bal.companyId
                AND lr.invId = bal.invId
		WHERE bal.warehouseId = @warehouseId
		GROUP BY bal.invId
		 
        UPDATE #lrLineItem SET
            warehouseBalance = balanceQty
        FROM #warehouseBal bal
        WHERE #lrLineItem.invId = bal.invId
 
 
		IF (SELECT COUNT(1) FROM #lrLineItem WHERE ISNULL(warehouseBalance, 0) < shipQty) > 0
		BEGIN
			SET @returnMessage = (SELECT 'LR item ' + supplierSku + ' has no enough stock to process.'
                                    FROM ( SELECT TOP 1 supplierSku
			                                FROM #lrLineItem 
			                                WHERE ISNULL(warehouseBalance, 0) < shipQty
                                          )g
                                    );
 
            THROW 60000, @returnMessage, 1;
		END

        DECLARE @lrContainerId BIGINT, @soHeaderId BIGINT, @bol VARCHAR(30), @bolShipmentWeight NUMERIC(13,4) = 0
 
        BEGIN TRANSACTION

            DECLARE cur_container CURSOR FOR 
            SELECT DISTINCT lrContainerId
            FROM #lrLineItem

            OPEN cur_container  
            FETCH NEXT FROM cur_container INTO @lrContainerId
            WHILE @@FETCH_STATUS = 0  
            BEGIN             
                EXEC [dbo].[SSP_GetRunningNo] 'BOL', @companyId, @bol  output

                IF (@bol IS NULL) 
			    BEGIN
				    SET @returnMessage = 'Container bol Id encounter creation problem.';
                    THROW 60000, @returnMessage, 1;
			    END
                
                DECLARE cur_shipment CURSOR FOR 
                SELECT DISTINCT soHeaderId
                FROM #lrLineItem
                WHERE lrContainerId = @lrContainerId

                OPEN cur_shipment  
                FETCH NEXT FROM cur_shipment INTO @soHeaderId
                
                WHILE @@FETCH_STATUS = 0  
                BEGIN  
                    DECLARE @shipment VARCHAR(30);

				    EXEC [dbo].[SSP_GetRunningNo] 'SHP', @companyId, @shipment OUTPUT
 
                    IF (@shipment IS NULL) 
			        BEGIN
				        SET @returnMessage = 'Shipment Id encounter creation problem.';
                        THROW 60000, @returnMessage, 1;
			        END

                    DROP TABLE IF EXISTS #containerInfo;

				    SELECT lr.companyId, lr.lrHeaderId, lr.lrName, lr.notes, lr.portId, lr.cargoReadyDate,
						lr.lrContainerId, lr.containerTypeId, lr.containerSeq, lr.forwarderId, lr.forwarderBookingNo, lr.ETD, lr.ETA,
						lr.containerNo, lr.containerSealNo, lr.containerMaxGross, lr.containerTare, lr.haulierId, lr.containerPullInDate, lr.containerPullOutDate,
						lr.soheaderId, lr.soLineItemId, lr.invId, lr.supplierSku, lr.shipQty, lr.soName, lr.itemNote
				    INTO #containerInfo
				    FROM #lrLineItem lr
				    WHERE lrContainerId = @lrContainerId
						AND lr.soHeaderId = @soHeaderId                    
 
                    DECLARE @shipmentWeight NUMERIC(13,5), @pol VARCHAR(50), @paymentTermId INT, @customerPO VARCHAR(50), @pod VARCHAR(50), @portId INT;
                    DECLARE @countryOfOrigin VARCHAR(50), @shipToId INT, @soName VARCHAR(30), @customerId INT;

                    SET @countryOfOrigin = (SELECT TOP 1 mc.categoryName FROM md_company c INNER JOIN md_masterCategory mc ON c.country = mc.categoryId WHERE c.companyId = @companyId);

 
                    DROP TABLE IF EXISTS #lineItemWeight;

                    SELECT info.shipQty * inv.grossWeight as lineItemGrossWeight
                    INTO #lineItemWeight
                    FROM #containerInfo info
                        INNER JOIN md_Inventory inv
                            ON info.invId = inv.invId
                     
                    SET @shipmentWeight = ( SELECT SUM(lineItemGrossWeight) FROM #lineItemWeight)

                    SET @bolShipmentWeight = @bolShipmentWeight + @shipmentWeight;

                    SET @shipToId = (SELECT shipToId FROM soHeader WHERE soHeaderId = @soHeaderId);
                    SET @portId = (SELECT portId FROM #containerInfo);
                    SET @pod = (SELECT portName FROM md_port WHERE portId = @portId);                   
              		 
                    SET @pol = (SELECT DISTINCT portOfLanding
                                FROM soHeader
								WHERE soHeaderId = @soHeaderId)

                    SELECT @paymentTermId = cs.paymentTerm, @customerPO = customerPO, @soName = s.soName, @customerId = s.customerId 
                    FROM soHeader s
                            INNER JOIN md_customer cs
                                ON s.customerId = cs.customerId
                    WHERE soHeaderId = @soHeaderId


                    DROP TABLE IF EXISTS #newShipment;

 				    CREATE TABLE #newShipment (shipmentId BIGINT, shipId VARCHAR(50), soHeaderId BIGINT, soName VARCHAR(50))
	
                    INSERT INTO shipmentHeader(companyId, customerId, shipId, bol, shipmentDate, shipmentStatus,  lrHeaderId, lrName, soHeaderId, soName, customerPO,
                                pickupAddrId, shipToId, pol, pod, paymentTermId,  
						        containerTypeId, containerSeqNo, forwarderId, forwarderBookingNo, ETD, ETA, 
                                containerNo, containerSealNo, containerMaxGross, containerTare, haulierId, containerPullInDate, containerPullOutDate,
                                countryOfOrigin, shipmentWeight, createBy, createDate)
                    OUTPUT INSERTED.shipmentId, INSERTED.shipId, INSERTED.soheaderId, INSERTED.soName
                    INTO #newShipment
                    SELECT DISTINCT @companyId, @customerId, @shipment, @bol, getdate() as shipmentDate,  2149 as shipmentStatus, l.lrHeaderId, l.lrName, l.soHeaderId, @soName, @customerPO,  
                            @warehouseId, @shipToId, @pol, @pod, @paymentTermId, 
						    l.containerTypeId, l.containerSeq, forwarderId, forwarderBookingNo, ETD, ETA, 
                            containerNo, containerSealNo, containerMaxGross, containerTare, haulierId, containerPullInDate, containerPullOutDate,
                            @countryOfOrigin, @shipmentWeight, @createdBy, getdate()
                    FROM #containerInfo l
  
                    DECLARE @shipmentId BIGINT, @shipId VARCHAR(50) ;
 
                    SELECT @shipmentId = shipmentId, @shipId = shipId 
                    FROM #newShipment

                    IF @shipmentId IS NULL
			        BEGIN
				        SET @returnMessage = ( 'Insert into shipment header encountered issue' ) ;
                        THROW 60000, @returnMessage, 1;
			        END

                    DROP TABLE IF EXISTS #newShipmentlineItem;

                    CREATE TABLE #newShipmentlineItem (soLineItemId BIGINT, invId INT, shipmentQty INT)

                    INSERT INTO shipmentLineItem(shipmentId, shipId, soLineItemId, invId, customerSku, merchantSku, shipmentQty, shipQty, lineItemNotes, lineItemStatus, createBy, createDate, updateBy, updateDate)
                    OUTPUT INSERTED.soLineItemId, INSERTED.invId, INSERTED.shipmentQty
                    INTO #newShipmentlineItem
                    SELECT @shipmentId, @shipId, info.soLineItemId, info.invId, so.customerSku, so.merchantSku, info.shipQty, info.shipQty, info.itemNote, 2149 as lineItemStatus, @createdBy, getdate(), @createdBy, getdate()
                    FROM #containerInfo info
                        INNER JOIN soLineItem so
                            ON info.soLineItemId = so.soLineItemid                         
 
                    INSERT INTO shipmentAddress(shipmentId, shipId, locNo, shipToName, shipToLabel, shipToEmail, shipToContactNumber, shipToFaxNumber, 
                        shipToAddressLine1, shipToAddressLine2, shipToCity, shipToState, shipToPostCode, country, createDate, createBy, updateBy, updateDate)
                    SELECT @shipmentId, @shipId, locNo, shipToName, shipToLabel, shipToEmail, shipToContactNumber, shipToFaxNumber, 
                            shipToAddressLine1, shipToAddressLine2, shipToCity, shipToState, shipToPostCode, country, getdate(), @createdBy, @createdBy, getdate()
                    FROM md_shipToDestination
                    WHERE shipToId = @shipToId
 
                    INSERT INTO inventoryMovement(warehouseId, companyId, action, actionKey, invId, qty, reason, enterBy, enterDate)
                    SELECT @warehouseId, @companyId, 'SHIP', @shipId, invId, -shipmentQty, @soName, @createdBy, getdate()
                    FROM #newShipmentlineItem

					UPDATE inventoryBalanceWH_Lock SET
						releaseQty = releaseQty + shipmentQty
					FROM inventoryBalanceWH_Lock bal
						INNER JOIN #newShipmentlineItem li
							ON bal.invId = li.invId 
							ANd bal.soLineItemId = li.soLineItemId
					WHERE companyId = @companyId
						AND warehouseId = @warehouseId
						AND soHeaderId = @soHeaderId


                    UPDATE inventoryBalanceWH SET
                        balanceQty = balanceQty - checkoutQty,
						lockQty = lockQty - checkoutQty,
                        updateBy = @createdBy,
                        updateDate = getdate()
                    FROM (	SELECT invId, SUM(shipmentQty) as checkoutQty
                            FROM #newShipmentlineItem
                            GROUP BY invId) chkout
                    WHERE inventoryBalanceWH.invId = chkout.invId
                        AND inventoryBalanceWH.warehouseId = @warehouseId
                        AND inventoryBalanceWH.companyId = @companyId
							 

                    UPDATE li SET
					    processQty = processQty + cl.shipmentQty,
					    updateBy = @createdBy,
					    updateDate = getdate()
				    FROM lrlineItem li
                        INNER JOIN #newShipmentlineItem cl
                            ON li.soLineItemId = cl.soLineItemId
				    WHERE lrContainerId = @lrContainerId
						AND li.soHeaderId = @soHeaderId

                    UPDATE lrLineItem SET
                        itemStatus = 2131
                    WHERE (CASE WHEN confirmQty = 0 THEN qty ELSE confirmQty END) - processQty = 0
                        AND lrHeaderId = @lrHeaderId
                           
                    --IF (SELECT COUNT(1) FROM lrLineItem WHERE itemStatus NOT IN (2131, 2130)) = 0
                    IF (SELECT COUNT(1) FROM lrLineItem WHERE itemStatus NOT IN (2131, 2130) AND lrHeaderId = @lrHeaderId) = 0
                    BEGIN
                        UPDATE lrHeader SET
                            lrStatus = 2131
                        WHERE lrHeaderId = @lrHeaderId
                    END
          
				    UPDATE so SET
					    shpQty = so.shpQty + cl.shpQty,
					    updateBy = @createdBy,
					    updateDate = getdate()
                    FROM soLineItem so
					    INNER JOIN (SELECT soLineItemId, SUM(shipmentQty) as shpQty
                                    FROM #newShipmentlineItem 
                                    GROUP BY soLineItemId) cl
						    ON so.soLineItemId = cl.soLineItemId

                    UPDATE soli SET
                        soLineItemStatus = 1108,
                        updateBy = @createdBy,
                        updateDate = getdate()
                    FROM soLineItem soli
                        INNER JOIN #newShipment ship
                            ON soli.soHeaderId = ship.soHeaderId
                        AND odrQty - shpQty = 0

                    IF (SELECT COUNT(1) FROM soLineItem WHERE soLineItemStatus NOT IN (1107, 1108)) = 0
                    BEGIN
                        UPDATE soHeader SET
                            soStatus = 1108,
                            updateBy = @createdBy,
                            updateDate = getdate()
                        FROM #newShipment ship
                        WHERE soHeader.soHeaderId = ship.soHeaderId
                    END
 
                    FETCH NEXT FROM cur_shipment INTO @soHeaderId 
                END 

                UPDATE shipmentHeader SET 
                    bolTotalShipmentWeight = @bolShipmentWeight
                WHERE bol = @bol

                CLOSE cur_shipment  
                DEALLOCATE cur_shipment

                FETCH NEXT FROM cur_container INTO @lrContainerId
            END 


        CLOSE cur_container  
        DEALLOCATE cur_container

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status,  'Shipment document successfully created.' AS returnMessage  
				
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

