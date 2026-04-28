-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> OP Module -> LR Receive -> Process Shipment

-- Description : Load Request for factory, so they can prepare packing list for container loading

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-29	5.0			WL Leong	Add inventory movement
-- 2024-01-30	4.2			WL Leong	Add lrShipToId
-- 2024-01-29	4.1			ZY Wong		Fix poName repeating in error msg
-- 2024-01-29	4.0			WL Leong	Add another validation for 0 lines conversion
-- 2024-01-22	3.0			ZY Wong		Add XACT_ABORT
-- 2024-01-22	2.0			WL Leong	Change of some column
-- 2023-12-10	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_OrderProcess_ProcessShipment
11, 4, 1
**/
--select * from ORDERpROCESS

CREATE PROCEDURE [dbo].[SSP_OrderProcess_ProcessShipment]
@opId BIGINT,
@companyId INT,
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
			DROP TABLE IF EXISTS #orderInfo;

			SELECT p.opId, p.lrName, p.soHeaderId, p.soName, p.companyId, p.customerId, p.reference1, p.reference2, p.reference3, p.lrContainerType, ct.categoryName as containerType, soReferenceId, opStatus
			INTO #orderInfo
			FROM orderProcess p
				INNER JOIN md_masterCategory ct
					ON p.lrContainerType = ct.categoryId
			WHERE p.opId = @opId

			DECLARE @returnMessage as VARCHAR(500)
-- 1091 Confirm
-- 1090 Closed

			IF (SELECT COUNT(1) FROM #orderInfo WHERE opStatus = 1090) > 0
			BEGIN
				SELECT @returnMessage = COALESCE(@returnMessage + ', ' + lrName, lrName) 
				FROM #orderInfo 
				WHERE opStatus = 1090

				SELECT '_ALERT_' as status, 'LR# ' + @returnMessage + ' is/are already prcoess shipment' AS returnMessage 

				RETURN -1
			END

			IF (SELECT COUNT(1) FROM #orderInfo WHERE opStatus NOT IN (1091)) > 0
			BEGIN
				SELECT @returnMessage = COALESCE(@returnMessage + ', ' + lrName, lrName) 
				FROM #orderInfo 
				WHERE opStatus NOT IN (1091)

				SELECT '_ALERT_' as status, 'LR# ' + @returnMessage + ' is/are not able to process shipment' AS returnMessage

				RETURN -1
			END
			
			DROP TABLE IF EXISTS #orderDetailsList;

 			SELECT od.companyId, li.soLineItemId, li.invId, customerSku, merchantSku, confirmQty, itemReference1, itemReference2, itemNote, grossWeight
			INTO #orderDetailsList
			FROM orderProcessLineItem li
				INNER JOIN #orderInfo od
					ON li.opId = od.opId
				INNER JOIN md_inventory inv
					ON li.invId = inv.invId
			WHERE opLineItemStatus = 1091
				AND li.opId  = @opId

			DROP TABLE IF EXISTS #invBalance;
 
			SELECT li.invId, customerSku, confirmQty, ISNULL(bal.balanceQty - bal.lockQty, 0) as balanceQty
			INTO #invBalance
			FROM #orderDetailsList li	
				LEFT JOIN inventoryBalanceWH bal
					ON li.invId = bal.invId
					AND li.companyId = bal.companyId
					 
			IF (SELECT COUNT(1) from #invBalance WHERE confirmQty < balanceQty) > 0
			BEGIN
				SELECT @returnMessage = COALESCE(@returnMessage + ', ' + customerSku, customerSku) 
				FROM #invBalance 
				WHERE confirmQty < balanceQty

				SELECT '_ALERT_' as status, 'Customre Sku # ' + @returnMessage + ' balance quantity is/are not enough to process' AS returnMessage

				RETURN -1
			END

 
			IF (SELECT COUNT(1) FROM #orderInfo WHERE opStatus = 1091) > 0
			BEGIN
				DECLARE @warehouseId INT, @shipmentWeight NUMERIC(13, 4), @shipToId INT

				SET @warehouseId = (SELECT TOP 1 warehouseId FROM md_warehouse WHERE companyId = @companyId);

				DECLARE @shipment VARCHAR(50)
				EXEC [dbo].[SSP_GetRunningNo] 'SHP', @companyId, @shipment  output

 				IF @shipment IS NOT NULL
				BEGIN
					DECLARE @newShipment TABLE(shipmentId BIGINT, shipId VARCHAR(50), soName VARCHAR(50))

					DROP TABLE IF EXISTS #orderDetails;

					SET @shipToId = (SELECT shipToId FROM #orderInfo odr INNER JOIN soHeader s ON odr.soHeaderId = s.soHeaderId)

					SELECT li.soLineItemId, li.invId, customerSku, merchantSku, confirmQty, itemReference1, itemReference2, itemNote, grossWeight
					INTO #orderDetails
					FROM orderProcessLineItem li
						INNER JOIN md_inventory inv
							ON li.invId = inv.invId
					WHERE opLineItemStatus = 1091
						AND li.opId  = @opId

			 
					SET @shipmentWeight = (SELECT SUM(confirmQty * grossWeight) FROM #orderDetails)
 
					INSERT INTO shipmentHeader(shipId, shipmentDate, shipmentStatus, companyId, soheaderId, soName, soReferenceId, pickupAddrId, pymtDueDate,  
						containerType, reference1, reference2, reference3, shipmentWeight, createBy, createDate)
					OUTPUT INSERTED.shipmentId, INSERTED.shipId, INSERTED.soName
					INTO @newShipment
					SELECT @shipment, getdate(),  2149, companyId, soHeaderId, soName, soReferenceId, @warehouseId, DATEADD(month, 3, getdate()), 
						lrContainerType, reference1, reference2, reference3, @shipmentWeight, @createdBy, getdate()
					FROM #orderInfo


					DECLARE @shipmentId BIGINT, @shipId VARCHAR(50), @soName VARCHAR(50)

					IF (SELECT COUNT(1) FROM @newShipment) > 0
					BEGIN
						DECLARE @newShipmentlineItem table(soLineItemId BIGINT, invId INT, shipmentQty INT)

						SELECT @shipmentId = shipmentId, @shipId = shipId, @soName = soName
						FROM @newShipment
				
						INSERT INTO shipmentLineItem(shipmentId, shipId, soLineItemId, invId, customerSku, merchantSku, shipmentQty, shipQty, lineItemNotes, lineItemStatus, createBy, createDate)
						OUTPUT INSERTED.soLineItemId, INSERTED.invId, INSERTED.shipmentQty
						INTO @newShipmentlineItem
						SELECT @shipmentId, @shipId, soLineItemId, invId, customerSku, merchantSku, confirmQty, confirmQty, itemNote, 2149 as lineItemStatus, @createdBy, getdate()
						FROM #orderDetails
 

						INSERT INTO shipmentAddress(shipmentId, shipId, locNo, shipToName, shipToLabel, shipToEmail, shipToContactNumber, shipToFaxNumber, 
							shipToAddressLine1, shipToAddressLine2, shipToCity, shipToState, shipToPostCode, country, createDate, createBy)
						SELECT @shipmentId, @shipId, locNo, shipToName, shipToLabel, shipToEmail, shipToContactNumber, shipToFaxNumber, 
							shipToAddressLine1, shipToAddressLine2, shipToCity, shipToState, shipToPostCode, country, getdate(), @createdBy
						FROM md_shipToDestination
						WHERE shipToId = @shipToId
	
/**	checkout from inv balance	**/

						INSERT INTO inventoryMovement(warehouseId, companyId, action, shipId, orderNo, invId, qty, reason, enterBy, enterDate)
						SELECT @warehouseId, @companyId, 'SHIP', @shipId, @soName as orderNo, invId, shipmentQty, '', @createdBy, getdate()
						FROM @newShipmentlineItem
					 
						UPDATE inventoryBalanceWH SET
							balanceQty = balanceQty - checkoutQty,
							updateBy = @createdBy,
							updateDate = getdate()
						FROM (	SELECT invId, SUM(shipmentQty) as checkoutQty
								FROM @newShipmentlineItem
								GROUP BY invId) chkout
						WHERE inventoryBalanceWH.invId = chkout.invId
							AND inventoryBalanceWH.warehouseId = @warehouseId
							AND inventoryBalanceWH.companyId = @companyId
							 
/**	checkout from inv balance	**/
 
						UPDATE li SET
							shipQty = cl.shipmentQty,
							opLineItemStatus = 1090,
							updateBy = @createdBy,
							updateDate = getdate()
						FROM orderProcessLineItem li
							INNER JOIN @newShipmentlineItem cl
								ON li.soLineItemId = cl.soLineItemId
								AND li.opId = @opId

						UPDATE orderProcess SET
							opStatus = 1090,
							updateBy = @createdBy,
							updateDate = getdate()
						WHERE opId = @opId

		 
					END
				END
				ELSE
				BEGIN
					ROLLBACK TRANSACTION
					SELECT '_FAILURE_' as status, 'Ship Id number encounter creation problem' AS returnMessage 
				
					RETURN -1
				END
			END


		COMMIT TRANSACTION
		SELECT '_SUCCESS_' as status,  @shipId + ' successfully created' AS returnMessage , @shipId as shipId
				
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

