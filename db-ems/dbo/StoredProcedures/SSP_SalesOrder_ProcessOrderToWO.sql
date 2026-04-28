-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO pending process

-- Description : All Sales Order still remain unprocess

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-12	5.0			WL Leong	Process WO# will default target complete date T-7, confirmQty = woQty
-- 2025-06-10	4.0			WL Leong	Split customerId, ship date, portId then third party SO#
-- 2025-05-05	3.1			WL Leong	Split customerId, ship date then third party SO#
-- 2025-05-03	3.0			WL Leong	Split ship date then third party SO#
-- 2025-03-21	2.0			WL Leong	At least 1 warehouse need to have for company to process WO
-- 2025-03-04	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_ProcessOrderToWO 4, N'{"soList":[{"soLineItemId":"33425"}, {"soLineItemId":"33426"}]}',  0, 3, 1, 1
 -- EXEC SSP_SalesOrder_ProcessOrderToWO 4, '',  1, 0, 0, 1
 --EXEC SSP_SalesOrder_ProcessOrderToWO 4, N'{"soList":[{"soLineItemId":"25963"}, {"soLineItemId":"25964"}, {"soLineItemId":"25965"}, {"soLineItemId":"25966"}]}',  0, 3, 1, 1
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ProcessOrderToWO]
@companyId INT,
@processList NVARCHAR(MAX) = '', 
@autoProcess INT = 1,
@processToWarehouseId INT = 0,
@forcedProcess BIT = 0,
@createBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		DECLARE @ErrMessage VARCHAR(1000)

		--DECLARE @processList VARCHAR(MAX) = ''
		--DECLARE @createBy INT = 1, @companyId INT = 4, @autoProcess INT = 1, @forcedProcess BIT = 0, @processToWarehouseId INT = 0 

		--SET @processList = N'{"soList":[{"soLineItemId":"33425"}, {"soLineItemId":"33426"}]}'
 
        DROP TABLE IF EXISTS #workOrder;
        DROP TABLE IF EXISTS #processList;

        CREATE TABLE #workOrder (workOrder VARCHAR(20));

        CREATE TABLE #processList(soHeaderId BIGINT, customerId INT, soName VARCHAR(50), customerPO VARCHAR(50), thirdParty VARCHAR(20),
                                    thirdPartyPO VARCHAR(200), earlyShipDate DATE, locNo  VARCHAR(20), portId INT,
                                    soLineItemId BIGINT, invId INT, woQty INT, warehouseId INT, invCustomerAttribute VARCHAR(20));
 
 
        IF @autoProcess = 0
        BEGIN
            IF ISNULL(@processList, '') = ''
            BEGIN
                SET @ErrMessage = 'Missing selected row for process';
                THROW 60000, @ErrMessage, 1;
            END

		    DROP TABLE IF EXISTS #list;

		    SELECT soLineItemId
		    INTO #list
		    FROM  OPENJSON(@processList, '$.soList') 
   			    WITH (
				    soLineItemId BIGINT			N'$.soLineItemId'
			    )
            
			DROP TABLE IF EXISTS #itemList;
            
            SELECT li.soHeaderId, li.soLineItemId, li.invId, li.odrQty - li.processQty as woQty
            INTO #itemList
            FROM soLineItem li
				INNER JOIN #list s
					ON li.soLineItemId = s.soLineItemId
		    WHERE li.odrQty - li.processQty > 0
			    AND li.soLineItemStatus NOT IN (1107, 1108, 1105)

            INSERT INTO #processList(soHeaderId, customerId, soName, customerPO, thirdParty, thirdPartyPO, earlyShipDate, locNo, portId, soLineItemId, invId, woQty, warehouseId)
		    SELECT s.soHeaderId, customerId, soName, customerPO, thirdParty, thirdPartyPO, earlyShipDate, locNo, s.portOfDestination,
			    soLineItemId, invId, woQty, CAST(0 as INT) as warehouseId
		    FROM  #itemList li
			    INNER JOIN soHeader s
				    ON li.soHeaderId = s.soHeaderId
                     
		    IF @forcedProcess = 1 
            BEGIN
                IF ISNULL(@processToWarehouseId, 0) = 0
		        BEGIN
                    SET @ErrMessage = 'Missing process to value';
                    THROW 60000, @ErrMessage, 1;
                END

			    UPDATE #processList SET
				    locNo = (SELECT TOP 1 locNo FROM md_warehouse WHERE warehouseId = @processToWarehouseId)
			    WHERE ISNULL(locNo, '') = ''
		    END
        END
        ELSE
        BEGIN
		    DROP TABLE IF EXISTS #soHeader;

		    SELECT soHeaderId, customerId, soName, customerPO, thirdParty, thirdPartyPO, earlyShipDate, locNo, portOfDestination
		    INTO #soHeader
		    FROM soHeader 
		    WHERE companyId =  @companyId 
			    AND soStatus NOT IN (1107, 1108, 1105)


            INSERT INTO #processList(soHeaderId, customerId, soName, customerPO, thirdParty, thirdPartyPO, earlyShipDate, locNo, portId, soLineItemId, invId, woQty, warehouseId)
		    SELECT s.soHeaderId, customerId, soName, customerPO, thirdParty, thirdPartyPO, earlyShipDate, locNo, s.portOfDestination,
			    soLineItemId, invId, odrQty - processQty as woQty, CAST(0 as INT) as warehouseId
		    FROM  soLineItem li
			    INNER JOIN #soHeader s
				    ON li.soHeaderId = s.soHeaderId
		    WHERE li.odrQty - li.processQty > 0
			    AND li.soLineItemStatus NOT IN (1107, 1108, 1105)

			UPDATE #processList SET
				locNo = (SELECT TOP 1 locNo FROM md_warehouse WHERE companyId = 4)
			WHERE ISNULL(locNo, '') = ''
        END


		UPDATE #processList SET
			warehouseId = wh.warehouseId
		FROM md_warehouse wh
		WHERE #processList.locNo = wh.locNo

		UPDATE #processList SET
			invCustomerAttribute = inv.[value]
		FROM inventory_attributes inv
		WHERE #processList.invId = inv.invId    
            AND inv.categoryId = 3186

        IF (SELECT COUNT(1) FROM #processList WHERE warehouseId = 0) > 0
		BEGIN
            SET @ErrMessage = 'Please configure at least 1 warehouse to proceed';
            THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM #processList) = 0
		BEGIN
            SET @ErrMessage = 'No row pending process';
            THROW 60000, @ErrMessage, 1;
        END

		BEGIN TRANSACTION
			DECLARE @shipDate DATE, @thirdParty VARCHAR(20), @customerId INT, @portId INT

			DECLARE CUR_customer CURSOR LOCAL FOR  
			SELECT DISTINCT customerId
			FROM #processList 

			OPEN CUR_customer  
			FETCH NEXT FROM CUR_customer 
			INTO @customerId
 
			WHILE @@FETCH_STATUS=0
			BEGIN 
				DROP TABLE IF EXISTS #customerList;

				SELECT *
				INTO #customerList
				FROM #processList
				WHERE customerId = @customerId

				DECLARE CUR_dateRange CURSOR LOCAL FOR  
				SELECT DISTINCT earlyShipDate, portId
				FROM #customerList 

				OPEN CUR_dateRange  
				FETCH NEXT FROM CUR_dateRange 
				INTO @shipDate, @portId
 
				WHILE @@FETCH_STATUS=0
				BEGIN 
					DROP TABLE IF EXISTS #ShipDateList;

					SELECT *
					INTO #ShipDateList
					FROM #processList
					WHERE earlyShipDate = @shipDate
						AND portId = @portId

					DECLARE CUR_thirdPartyCustomer CURSOR LOCAL FOR  
					SELECT DISTINCT thirdParty
					FROM #ShipDateList 

					OPEN CUR_thirdPartyCustomer  
					FETCH NEXT FROM CUR_thirdPartyCustomer 
					INTO @thirdParty
 
					WHILE @@FETCH_STATUS=0
					BEGIN

						DECLARE @woName VARCHAR(20)
 
						EXEC [dbo].[SSP_GetRunningNo] 'WorkOrder', @CompanyId, @woName OUTPUT

						IF @woName IS NOT NULL
						BEGIN
							INSERT INTO #workOrder(workOrder)
							SELECT @woName

							DECLARE @insertedWO AS TABLE(workOrderHeaderId BIGINT, workOrderName VARCHAR(20))

							DROP TABLE IF EXISTS #processWO

							SELECT *
							INTO #processWO
							FROM #ShipDateList
							WHERE thirdParty = @thirdParty

							DECLARE @workOrderHeaderId BIGINT
 
							INSERT INTO workOrderheader(companyId, workOrderName, workOrderDate, warehouseId, shipDate, targetCompleteDate, workOrderStatus, createBy, createDate, customerId, thirdParty)
							OUTPUT INSERTED.workOrderHeaderId, INSERTED.workOrderName INTO @insertedWO
							SELECT DISTINCT @companyId, @woName,getdate(),  warehouseId, earlyShipDate, DATEADD(DAY, -7, earlyShipDate) as targetCompleteDate, 5230, @createBy, getdate(), customerId, thirdParty
							FROM #processWO

							SET @workOrderHeaderId = (SELECT workOrderHeaderId FROM @insertedWO)

							IF @workOrderHeaderId IS NULL
							BEGIN
								SET @ErrMessage = 'WorkOrder number encounter creation problem';
								THROW 60000, @ErrMessage, 1;
							END
							ELSE  
							BEGIN
								DECLARE @insertedJob AS TABLE(soLineItemId BIGINT, woQty INT)

								INSERT INTO workOrderLineItem(workOrderHeaderId, workOrderName, soHeaderId, soName, soLineItemId, invId, qty, confirmQty, workOrderItemStatus, createBy, createDate)
								OUTPUT INSERTED.soLineItemId, INSERTED.qty INTO @insertedJob
								SELECT @workOrderHeaderId, @woName, soHeaderId, soName, soLineItemId, invId, woQty, woQty, 5230, @createBy, getdate()
								FROM #processWO

								UPDATE soLineItem SET
									processQty = processQty + woQty 
								FROM (SELECT soLineItemId, SUM(woQty) as woQty FROM @insertedJob GROUP BY soLineItemId) wh
								WHERE soLineItem.soLineItemId = wh.soLineItemId
							END
						END

						DELETE FROM @insertedWO
						DELETE FROM @insertedJob

						FETCH NEXT FROM CUR_thirdPartyCustomer 
						INTO @thirdParty
					END

					CLOSE CUR_thirdPartyCustomer
					DEALLOCATE CUR_thirdPartyCustomer


					FETCH NEXT FROM CUR_dateRange 
					INTO @shipDate, @portId
				END

				CLOSE CUR_dateRange
				DEALLOCATE CUR_dateRange

			FETCH NEXT FROM CUR_customer 
			INTO @customerId
		END

		CLOSE CUR_customer
		DEALLOCATE CUR_customer

	    COMMIT TRANSACTION

        SET @ErrMessage = (SELECT 'WO# ' + STRING_AGG(CONVERT(VARCHAR(max), workOrder), ',') + ' success created.'
                                    FROM (SELECT DISTINCT workOrder
                                            FROM #workOrder )g
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
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()
		    
        SELECT '_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

