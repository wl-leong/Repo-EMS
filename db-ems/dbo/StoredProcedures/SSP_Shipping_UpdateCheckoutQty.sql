-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> Shipping Module -> Shipping Monitoring -> Update shipQty

-- Description : Update checkout qty and boostup inventory

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-02-29	1.0			WL Leong	Initial
---- ==========================================================================================
 
  --[dbo].[SSP_Shipping_UpdateCheckoutQty] N'{"itemList":[{"shipmentLineItemId":"4", "shipQty":"0", "lineItemNotes":"pallet left at factory"}]}', 1
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateCheckoutQty]
@shipJson VARCHAR(MAX),
@updatedBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
 
		DECLARE @errorMessage As VARCHAR(200)
		DECLARE @returnMessage VARCHAR(1000);
		--DECLARE @updatedBy INT = 2
		--DECLARE @shipJson VARCHAR(MAX)
		--SET @shipJson = N'{"itemList":[{"shipmentLineItemId":"4", "shipQty":"0", "lineItemNotes":"pallet left at factory"}]}'
		-- Read json content

		DROP TABLE IF EXISTS #lineItem;

		SELECT shipmentLineItemId, shipQty, lineItemNotes
		INTO #lineItem
		FROM  OPENJSON(@shipJson, '$.itemList') 
   			WITH (
				shipmentLineItemId BIGINT	N'$.shipmentLineItemId',
				shipQty INT					N'$.shipQty',
				lineItemNotes VARCHAR(500)	N'$.lineItemNotes'
			)
		
			DECLARE @bol VARCHAR(20), @shipmentId BIGINT, @shipmentWeight NUMERIC(14,4), @shipId VARCHAR(20)
			DECLARE @soHeaderId BIGINT, @soName VARCHAR(20), @warehouseId INT, @companyId INT

			DROP TABLE IF EXISTS #updateLineItem;

			SELECT sl.shipmentLineItemId, shipmentId, soLineItemId, li.invId, 
				sl.shipQty as newShipQty, li.shipQty as existingShipQty, li.shipQty - sl.shipQty as adjustedQty
			INTO #updateLineItem
			FROM #lineItem sl
					INNER JOIN shipmentLineItem li
						ON sl.shipmentLIneItemId = li.shipmentLineItemId
						 
			SET @shipmentId = (SELECT TOP 1 shipmentId FROM #updateLineItem);

			IF @shipmentId IS NULL
			BEGIN
				SET @returnMessage = 'No shipment ID found';
				
				THROW 60000, @returnMessage, 1
			END

			SELECT TOP 1 @bol = BOL, @shipId = s.shipId, @warehouseId = pickupAddrId, @companyId = companyId, @soName = soName
			FROM shipmentHeader s
					INNER JOIN shipmentLineItem li
						ON s.shipmentId = li.shipmentId
					INNER JOIN #lineItem sl
						ON li.shipmentLineItemId = sl.shipmentLineItemId

			SET @shipmentWeight = (SELECT SUM(grossWeight)
									FROM shipmentLineItem li
										INNER JOIN md_inventory inv
											ON li.invId = inv.invId
									WHERE li.shipmentId = @shipmentId) 
				
			BEGIN TRANSACTION
				DECLARE @updateInv AS TABLE (shipmentLineItemId BIGINT);

				UPDATE s SET
					shipQty = b.shipQty,
					lineItemNotes = b.lineItemNotes,
					updateBy = @updatedBy,
					updateDate = getdate()
				OUTPUT INSERTED.shipmentLineItemId
				INTO @updateInv
				FROM #lineItem b
					INNER JOIN shipmentLineItem s
						ON b.shipmentLineItemId = s.shipmentLineItemId
 
				UPDATE shipmentHeader SET
					shipmentWeight = @shipmentWeight,
					updateBy = @updatedBy,
					updateDate = getdate()
				WHERE shipmentId = @shipmentId
	 
/**	Adjustment from inv balance	**/

				INSERT INTO inventoryMovement(warehouseId, companyId, action, shipId, orderNo, invId, qty, reason, enterBy, enterDate)
				SELECT @warehouseId, @companyId, 'SHIPADJ', @shipId, @soName as orderNo, sl.invId, adjustedQty, '', @updatedBy, getdate()
				FROM @updateInv inv
					INNER JOIN #updateLineItem sl
						ON inv.shipmentLineItemId = sl.shipmentLineItemId
					 
				UPDATE inventoryBalanceWH SET
					balanceQty = balanceQty + adjustedQty,
					updateBy = @updatedBy,
					updateDate = getdate()
				FROM (	SELECT invId, SUM(adjustedQty) as adjustedQty
						FROM @updateInv inv
							INNER JOIN #updateLineItem sl
								ON inv.shipmentLineItemId = sl.shipmentLineItemId
						GROUP BY invId) chkout
				WHERE inventoryBalanceWH.invId = chkout.invId
					AND inventoryBalanceWH.warehouseId = @warehouseId
					AND inventoryBalanceWH.companyId = @companyId
							 
/**	checkout from inv balance	**/				
				DECLARE @updateSO AS TABLE (soHeaderId BIGINT, soLineItemId BIGINT);
	 
				UPDATE soLineItem SET
					shpQty = li.newShipQty,
					soLineItemStatus = 2125,
					updateBy = @updatedBy,
					updateDate = getdate()
				OUTPUT INSERTED.soHeaderId, INSERTED.soLineItemId
				INTO @updateSO
				FROM #updateLineItem li
				WHERE soLineItem.soLineItemId = li.soLineItemId

				SET @soHeaderId = (SELECT TOP 1 soHeaderId FROM @updateSO);

				UPDATE soHeader SET
					soStatus = 2125,
					updateBy = @updatedBy,
					updateDate = getdate()
				WHERE soHeaderId = @soHeaderId

				IF ISNULL(@bol, '') <> ''
				BEGIN
					UPDATE shipmentHeader SET
						BolTotalShipmentWeight = g.SumShipmentWeight,
						updateBy = @updatedBy,
						updateDate = getdate()
					FROM (SELECT SUM(ShipmentWeight) as SumShipmentWeight FROM shipmentHeader WHERE BOL = @BOL) g
					WHERE BOL = @BOL
				END 


			COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'Shipment# ' + @shipId + ' successfully update' AS returnMessage 

		RETURN 0
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
 
 
 
 --select * from soHeader

GO

