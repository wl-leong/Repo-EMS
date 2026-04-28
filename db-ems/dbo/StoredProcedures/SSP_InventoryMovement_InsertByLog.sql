-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-03-07
-- Used By:	    EMS -> Production Module -> Inventory Movement -> Import 

-- Description : Inventory Movement for factory, so they can adjust stock

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-03-07	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC [SSP_Production_CreateNewInventoryMovementByLog] '',1
CREATE PROCEDURE [dbo].[SSP_InventoryMovement_InsertByLog]
@fileUploaded varchar(150),
@createdBy INT
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
	BEGIN TRY
		 
		DECLARE @ErrMessage VARCHAR(MAX);
		--DECLARE @fileUploaded varchar(150) = '.csv', @createdBy INT = 1

		IF (SELECT COUNT(*) FROM temp_inventoryMovementLog WHERE fileLoaded = @fileUploaded) > 0
		BEGIN

			DROP TABLE IF EXISTS #tempInvMv;

			SELECT companyId, warehouseLabel, action, shipId, orderNo, inventorySku, qty, reason, enterBy, enterDate
			INTO #tempInvMv
			FROM temp_inventoryMovementLog 
			WHERE fileLoaded = @fileUploaded
				AND companyId IS NOT NULL

			ALTER TABLE #tempInvMv ADD warehouseId INT;
            ALTER TABLE #tempInvMv ADD actionId BIGINT;
			ALTER TABLE #tempInvMv ADD invId BIGINT;

/* Start: Data Validation */
			IF (SELECT COUNT(1) FROM #tempInvMv WHERE ISNULL(warehouseLabel, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Warehouse Label is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE ISNULL(action, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Action is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE ISNULL(inventorySku, '') = '') > 0
			BEGIN
				SET @ErrMessage = 'Inventory Sku is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE ISNULL(qty, 0) = 0) > 0
			BEGIN
				SET @ErrMessage = 'Qty is compulsory';
				THROW 60000, @ErrMessage, 1;
			END

            UPDATE t SET
                warehouseId = wh.warehouseId
            FROM #tempInvMv t
                INNER JOIN md_Warehouse wh
                    ON t.warehouseLabel = wh.[label]
                    AND t.companyId = wh.companyId
                    AND wh.[status] = 1

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE warehouseId IS NULL) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Warehouse Label ' + STRING_AGG(CONVERT(NVARCHAR(max), warehouseLabel), ',') + ' has not setup in system' 
                                    FROM (SELECT DISTINCT warehouseLabel 
                                            FROM #tempInvMv 
                                            WHERE warehouseId IS NULL)g
                                    );
				THROW 60000, @ErrMessage, 1;
            END

            UPDATE t SET
                actionId = ac.categoryId
            FROM #tempInvMv t
                INNER JOIN md_MasterCategory ac
					ON t.[action] = ac.categoryName
					AND ac.categoryParentID = 2151 --inventory movement action
                    AND ac.[status] = 1

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE actionId IS NULL) > 0
			BEGIN
				SET @ErrMessage = (SELECT 'Action ' + STRING_AGG(CONVERT(NVARCHAR(max), [action]), ',') + ' has not setup in system' 
                                    FROM (SELECT DISTINCT [action] 
                                            FROM #tempInvMv 
                                            WHERE actionId IS NULL)g
                                   );
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE (ISNULL(shipId, '') = '' OR ISNULL(orderNo, '') = '') AND actionId IN (2152,2153,2155)) > 0
			BEGIN
				SET @ErrMessage = (SELECT 'Ship Id/ Order # is compulsory for action ' + STRING_AGG(CONVERT(NVARCHAR(max), [action]), ',')  
                                    FROM (SELECT DISTINCT [action] 
                                            FROM #tempInvMv 
                                            WHERE (ISNULL(shipId, '') = '' OR ISNULL(orderNo, '') = '') 
                                                AND actionId IN (2152,2153,2155))g
                                    );
				THROW 60000, @ErrMessage, 1;
			END

			IF (SELECT COUNT(1) FROM #tempInvMv WHERE ISNULL(reason, '') = '' AND actionId IN (2154)) > 0
			BEGIN
				SET @ErrMessage = (SELECT TOP 1 'Reason is compulsory for action ' + action  
                                    FROM #tempInvMv 
                                    WHERE ISNULL(reason, '') = '' 
                                        AND actionId IN (2154)
                                    );
				THROW 60000, @ErrMessage, 1;
			END

            UPDATE t SET
				invId = inv.invId
			FROM #tempInvMv t
				INNER JOIN md_Inventory inv
					ON t.inventorySku = inv.inventorySKU
					AND t.companyId = inv.companyId


			IF (SELECT COUNT(*) FROM #tempInvMv WHERE invId IS NULL) > 0
			BEGIN
				SET @ErrMessage = (SELECT 'Inventory Sku ' + STRING_AGG(CONVERT(NVARCHAR(max), inventorySku), ',') + ' has not setup in system' 
                                    FROM (SELECT DISTINCT inventorySku 
                                        FROM #tempInvMv 
                                        WHERE invId IS NULL)g
                                   );
				THROW 60000, @ErrMessage, 1;
			END

/* End: Data validation */ 
				
			DECLARE @companyId INT, @supplierId INT, @shipWay INT, @VeselBooking VARCHAR(20), @POL VARCHAR(20)

			SET @companyId = (SELECT TOP 1 companyId FROM #tempInvMv)

            BEGIN TRANSACTION

			    INSERT INTO inventoryMovement (warehouseID, companyId, action, shipId, orderNo, invId, qty, reason, enterBy, enterDate)
			    SELECT warehouseID, companyId, action, shipId, orderNo, invId, qty, reason, enterBy, enterDate
			    FROM #tempInvMv            

			    -- update shipment line item
			    UPDATE shipmentLineItem SET
				    shipQty = shipQty + qtyAdj,
				    updateBy = @createdBy,
				    updateDate = getdate()
			    FROM (	SELECT shipId, orderNo, invId, CASE WHEN action = 'SHIP' THEN -qty ELSE qty END as qtyAdj 
					    FROM #tempInvMv
					    WHERE ISNULL(shipId, '') <> '' 
					    ) invmv
				    INNER JOIN shipmentHeader sh
					    ON invmv.shipId = sh.shipId
					    AND invmv.orderNo = sh.soName
			    WHERE shipmentLineItem.invId = invmv.invId
				    AND shipmentLineItem.shipmentId = sh.shipmentId
				    AND sh.companyId = @companyId

			    -- update inventoryBalanceWH
			    UPDATE inventoryBalanceWH SET
				    balanceQty = balanceQty + qtyAdj,
				    updateBy = @createdBy,
				    updateDate = getdate()
			    FROM (	SELECT warehouseID, invId, 
						    CASE WHEN action = 'SHIP' THEN -qty ELSE qty END as qtyAdj 
					    FROM #tempInvMv
					    ) invmv
			    WHERE inventoryBalanceWH.invId = invmv.invId
				    AND inventoryBalanceWH.warehouseId = invmv.warehouseID
				    AND inventoryBalanceWH.companyId = @companyId

            COMMIT TRANSACTION

		END
		ELSE
		BEGIN
			SET @ErrMessage = 'No rows being processed ' + @fileUploaded;
			THROW 60000, @ErrMessage, 1;
		END

		DELETE FROM temp_inventoryMovementLog WHERE fileLoaded = @fileUploaded

		SELECT '_SUCCESS_' as status, 'Inventory Movement loaded successfully' as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  

		DELETE FROM temp_inventoryMovementLog WHERE fileLoaded = @fileUploaded
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

