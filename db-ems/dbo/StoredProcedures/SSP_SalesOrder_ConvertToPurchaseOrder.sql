
--1105	Open
--1106	Confirm
--1107	Cancel
--1108	Close
--6237  Approved

-- =============================================
-- Author:		WL Leong
-- Create date: 2023-08-28
-- Used By:	    EMS -> SO Module -> SO Approval -> Raise PO

-- Description : Once the SO is approved, can multi select to convert PO 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-29   15.0        ZY Wong     Change condition to status approved
-- 2025-07-01   14.0        ZY Wong     Add new column EAN into poLineItem (undo pass EAN to poLineItem.itemReference2)
-- 2205-06-06   13.0        WL Leong	Marketing when received SO, itemReference1 = modelNo, merchantSku = merchantSku, when raise PO, will put itemReference1 = merchantSku
-- 2205-05-06   12.0        ZY Wong     Pass customerSku to poLineItem.merchantSku, pass EAN to poLineItem.itemReference2
-- 2025-04-23   11.0        ZY Wong     Standardize error message handling
-- 2025-03-21	10.0        WL Leong	switch the begin trans
-- 2024-05-08   9.0         ZY Wong     Get shipToId from soHeader
-- 2024-04-08	8.0			WL Leong	rename column to itemCode
-- 2024-03-21	7.0			WL Leong	changes on the currency rate
-- 2024-03-07	6.0			WL Leong	update PO LastupdatedDate once it is reopen SO for edit
-- 2024-02-26	5.0			WL Leong	Pass in soNote to poNote
-- 2024-02-20	4.0			WL Leong	Only released PO will update last update date if changes
-- 2024-02-08	3.0			WL Leong	Insert new item will also insert into the existing poLineItem
-- 2024-01-15	2.0			WL Leong	Get soLineItem merchantSku else refer to customerSku
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
/**
 EXEC SSP_SalesOrder_ConvertToPurchaseOrder
N'{"soList":[{"soHeaderId":"41389"},{"soHeaderId":"41390"},{"soHeaderId":"41391"}]}'
, 1
 **/
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ConvertToPurchaseOrder]
@soList VARCHAR(MAX),
@userId INT
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY

			DECLARE @returnMessage VARCHAR(MAX);
			DECLARE @result TABLE (poRefName VARCHAR(20), poQty INT);
            DELETE FROM @result

			--DECLARE @soList VARCHAR(MAX) = N'{"soList":[{"soHeaderId":"30832"}]}', @userId INT = 1

			DROP TABLE IF EXISTS #soList;
			
			SELECT * 
			INTO #soList
			FROM  OPENJSON(@soList, '$.soList') 
   				WITH (
					soHeaderId BIGINT	N'$.soHeaderId'
				)
			

			DROP TABLE IF EXISTS #soConvertList;
 
			SELECT s.soHeaderId, s.companyId, s.supplierId, s.soName, s.customerPO, s.soDate, s.earlyShipDate, s.lateShipDate, s.shipToId, s.portOfLanding, 
				s.portofDestination, s.shipWay, s.vesselBooking, s.thirdParty, s.thirdPartyPO, s.Reference1 as soReferenceId, s.soNote, s.soStatus, s.customerId
			INTO #soConvertList
			FROM soHeader s
				INNER JOIN #soList ls
					ON s.soHeaderId = ls.soHeaderId

            ALTER TABLE #soConvertList ADD customerCode VARCHAR(20)

            UPDATE #soConvertList SET 
                customerCode = cs.customerShortCode
            FROM md_Customer cs
            WHERE #soConvertList.customerId = cs.customerID
 
			IF (SELECT COUNT(1) FROM #soConvertList WHERE soStatus <> 6237) > 0
			BEGIN
				SET @returnMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(MAX),soName), ', ') + ' not yet approved.'
                                    FROM ( SELECT DISTINCT soName 
                                            FROM #soConvertList
                                            WHERE soStatus <> 6237
                                        )g
                                    );
				THROW 60000, @returnMessage, 1;
			END

			DROP TABLE IF EXISTS #soInfo;

			SELECT s.soHeaderId, s.companyId, s.supplierId, s.soName, s.customerPO, s.soDate, s.earlyShipDate, s.lateShipDate, s.shipToId, s.portOfLanding, 
				s.portofDestination, s.shipWay, s.vesselBooking, s.thirdParty, s.thirdPartyPO, s.soReferenceId, s.soNote, 
				li.soLineItemId, li.invID, (li.odrQty - li.poQty) as openQty, li.merchantSku as itemReference1, li.itemNote, s.customerCode,
                li.customerSkuId, li.customerSku as merchantSku, li.EAN
			INTO #soInfo
			FROM  #soConvertList s
				INNER JOIN soLineItem li
					ON s.soHeaderId = li.soHeaderId
			WHERE (li.odrQty - li.poQty) > 0
				AND li.soLineItemStatus = 6237  -- approved

            IF (SELECT COUNT(1) FROM #soInfo) = 0
			BEGIN
				SET @returnMessage = 'No open SO to be convert.';
                THROW 60000, @returnMessage, 1;
			END

            ALTER TABLE #soInfo ADD itemCode VARCHAR(50);
            ALTER TABLE #soInfo ADD inventorySku VARCHAR(50);
            ALTER TABLE #soInfo ADD itemDesc VARCHAR(500);
            ALTER TABLE #soInfo ADD supplierSkuId INT;
            ALTER TABLE #soInfo ADD supplierSku VARCHAR(50);
            ALTER TABLE #soInfo ADD currencyCode INT;
            ALTER TABLE #soInfo ADD currency VARCHAR(3);
            ALTER TABLE #soInfo ADD supCost NUMERIC(18,4);

            UPDATE #soInfo SET
                supplierSkuId = sk.supplierSkuId,
                supplierSku = sk.supplierSku,
                currencyCode = sk.currencyCode,
                supCost = sk.supCost,
                itemDesc = sk.itemDesc
            FROM md_supplierSku sk
            WHERE #soInfo.companyId = sk.companyId
                AND #soInfo.supplierId = sk.supplierId
				AND #soInfo.invId = sk.invId
				AND sk.statusflag = 1

            UPDATE #soInfo SET
                currency = cur.categoryName
            FROM md_masterCategory cur
			WHERE #soInfo.currencyCode = cur.categoryId

            UPDATE #soInfo SET
                itemCode = inv.itemCode,
                inventorySku = inv.inventorySku,
                itemDesc = CASE WHEN ISNULL(#soInfo.itemDesc,'') = '' THEN inv.itemDesc ELSE #soInfo.itemDesc END
            FROM md_Inventory inv
            WHERE #soInfo.invId = inv.invId	
            

			IF (SELECT COUNT(1) FROM #soInfo WHERE supplierSku IS NULL) > 0
			BEGIN
				SET @returnMessage = (SELECT 'Supplier SKU for ' + STRING_AGG(CONVERT(VARCHAR(MAX),inventorySku), ', ') + ' not yet configured in the system.'
                                    FROM ( SELECT DISTINCT inventorySku 
                                            FROM #soInfo
                                            WHERE supplierSku IS NULL
                                        )g
                                    );
				THROW 60000, @returnMessage, 1; 
			END

        BEGIN TRANSACTION

			DECLARE @soHeaderId BIGINT, @companyId INT, @supplierId INT, @soName VARCHAR(50);

			DECLARE CUR_soConvertList CURSOR LOCAL FOR  
			SELECT DISTINCT soHeaderId, companyId, supplierId, soName
			FROM #soInfo 

			OPEN CUR_soConvertList  
			FETCH NEXT FROM CUR_soConvertList 
			INTO @soHeaderId, @companyId, @supplierId, @soName
 
			WHILE @@FETCH_STATUS=0
			BEGIN 
				DECLARE @poId BIGINT, @poName varchar(50) = NULL;
				DECLARE @poCompanyId INT, @warehouseId INT;
                DECLARE @homeCurrency VARCHAR(3), @foreignCurrency VARCHAR(3), @currencyRate NUMERIC(14, 4) = 0;

				SET @poCompanyId= (SELECT internal_branchId FROM md_supplier WHERE supplierId = @supplierId);
                SET @warehouseId = (SELECT TOP 1 warehouseId FROM md_warehouse WHERE companyId = @companyId);						
				SET @foreignCurrency = (SELECT configValue FROM MD_defaultConfig WHERE configName = 'DefaultCurrency' AND companyId = @poCompanyId);
				SET @homeCurrency = (SELECT configValue FROM MD_defaultConfig WHERE configName = 'DefaultCurrency' AND companyId = @companyId);
			
				IF @homeCurrency = @foreignCurrency
				BEGIN
					SET @currencyRate = 1
				END 

				IF @foreignCurrency IS NULL OR @homeCurrency IS NULL
				BEGIN
					SET @returnMessage = 'Default supplier/company currency code not yet configured in the system.';
                    THROW 60000, @returnMessage, 1;
				END
				ELSE
				BEGIN
					SET @currencyRate = (SELECT foreignRate
										 FROM md_CurrencyRate
										 WHERE CONVERT(DATE, GETDATE()) BETWEEN startDate AND endDate)

					IF @currencyRate = 0
					BEGIN
						SET @returnMessage = 'Please set up the currency rate in the system.';
                        THROW 60000, @returnMessage, 1;
					END
				END				

				IF (SELECT COUNT(1) FROM poHeader WHERE poReferenceId = @soName) = 0
				BEGIN
                -- new po
					DECLARE @tempPO varchar(100) = 'tempPO-' + CAST(@userId as VARCHAR) + '-' + FORMAT(getdate(),'yyyyMMddHHmmssffff');
					DECLARE @poTable TABLE(poId BIGINT, poName varchar(50));
                    DELETE FROM @poTable

					INSERT INTO poHeader (companyId, supplierId, poName, poReferenceId, shipToid, shipVia, vesselBooking, portOfLanding, portOfDestination, 
                        poEarlyShipDate, poLateShipDate, poStatus, poNote, poNetTotal, poDiscount, poTax, poGrossTotal, foreignCurrencyCode, homeCurrencyCode, foreignCurrencyRate, 
                        reference1, reference2, reference3, warehouseId, enterDate, enterBy, customerCode)
					OUTPUT INSERTED.poID, INSERTED.poName
					INTO @poTable
					SELECT DISTINCT companyId, supplierId, @tempPO, soName, shipToId, shipWay, vesselBooking, portOfLanding, portOfDestination, 
                        earlyShipDate, lateShipDate, 1079 as poStatus, soNote as poNote, 0 as poNetTotal, 0 as poDiscount, 0 as poTax, 0 as poGrossTotal, @foreignCurrency, @homeCurrency, @currencyRate,
						customerPO as reference1, thirdPartyPO as reference2, '' as reference3, @warehouseId, getdate() as enterDate, @userId as enterBy, customerCode
					FROM #soInfo
					WHERE soHeaderId =  @soHeaderId
 
					SELECT @poId = poId FROM @poTable;
					
					DECLARE @raisePO TABLE (poDetailsId BIGINT, tempPO VARCHAR(50), soLineItemId BIGINT, qty INT, unitPrice NUMERIC(14,4));
                    DELETE FROM @raisePO

 					INSERT INTO poLineItem (poId, poName, soLineItemId, supplierSkuId, supplierSKU, invId, itemCode, qty, currencyCode, unitPrice, homeCurrencyCost, 
						itemReference1, itemReference2, merchantSku, EAN, itemStatus, poItemDesc, enterDate, enterBy, updateDate, updateBy)
					OUTPUT INSERTED.poDetailsId, INSERTED.poName, INSERTED.soLineItemId, INSERTED.qty, INSERTED.unitPrice
					INTO @raisePO
					SELECT @poId, @tempPO, soLineItemId, supplierSkuId, supplierSku, invID, itemCode, SUM(openQty) as orderQty, currency, supCost, CAST(supCost * @currencyRate as NUMERIC(13,4)),
						itemReference1, '' as itemReference2, merchantSku, EAN, 1079 as itemStatus, itemDesc, getdate(), @userId, getdate(), @userId
					FROM #soInfo 
					WHERE soHeaderId = @soHeaderId
					GROUP BY soReferenceId, soLineItemId, invID, itemCode, supplierSkuId, supplierSku, supCost, itemReference1, 
						merchantSku, EAN, currency, CAST(supCost * @currencyRate as NUMERIC(13,4)), itemDesc
 
 					EXEC [dbo].[SSP_GetRunningNo] 'PO', @companyId, @poName output
	
					IF @poName IS NULL
					BEGIN
						SET @returnMessage = 'PO number encounter creation problem.';
                        THROW 60000, @returnMessage, 1; 
					END

 					UPDATE soLineItem SET
						poQty = poQty + s.qty,
						updateDate = GETDATE()
					FROM @raisePO s
					WHERE soLineItem.soLineItemId = s.soLineItemId

					DECLARE @netTotal as NUMERIC(14,4) = (SELECT SUM(qty * unitPrice) FROM @raisePO);

					UPDATE poHeader SET
						poName = @poName,
						poNetTotal = @netTotal
					WHERE poName = @tempPO
 
					UPDATE poLineItem SET
						poName = @poName
					WHERE poName = @tempPO

					UPDATE lrLineItem SET
						poDetailsId = s.poDetailsId
					FROM @raisePO s
					WHERE lrLineItem.soLineItemId = s.soLineItemId

					INSERT INTO @result (poRefName, poQty)
					SELECT @poName, SUM(qty)
					FROM @raisePO

				END
				ELSE
				BEGIN
                -- po exists, reopen so -> confirm & reconvert
					DECLARE @updatePo VARCHAR(50), @updatePoId BIGINT;

					SET @updatePoId = (SELECT poId FROM poHeader WHERE poReferenceId = @soName);
					SET @updatePo = (SELECT poName FROM poHeader WHERE poId = @updatePoId);

					UPDATE p SET
						poEarlyShipDate = s.earlyShipDate, 
						poLateShipDate = s.lateShipDate,
						reference1 = s.customerPO,
						reference2 = s.thirdPartyPO,
						shipToId = s.shipToId,
                        portOfLanding = s.portOfLanding,
						portOfDestination = s.portOfDestination,
						poStatus = 1079,
						poNote = s.soNote,
						updateDate = getdate(),
						updateBy = @userId,
						lastUpdatedDate = getdate() --CASE WHEN p.poStatus = 1077  THEN getdate() ELSE p.lastUpdatedDate END
					FROM poHeader p
						INNER JOIN soHeader s
							ON p.poReferenceId = s.soName
					WHERE s.soHeaderId =  @soHeaderId
						
					DECLARE @updatePoLineItem TABLE (soLineItemId BIGINT, qty INT);
                    DELETE FROM @updatePoLineItem

 					UPDATE poLineItem SET
						qty = s.odrQty,
						itemStatus = 1079,  --draft
						updateDate = getdate(),
						updateBy = @userId
					OUTPUT INSERTED.soLineItemId, INSERTED.qty 
					INTO @updatePoLineItem
					FROM soLineItem s
					WHERE poLineItem.poId = @updatePoId
						AND poLineItem.soLineItemId = s.soLineItemId

                    -- new item added when reopen so
 					INSERT INTO poLineItem (poId, poName, soLineItemId, supplierSkuId, supplierSKU, invId, itemCode, qty, currencyCode, unitPrice, homeCurrencyCost, 
						itemReference1, itemReference2, merchantSku, EAN, itemStatus, poItemDesc, enterDate, enterBy, updateDate, updateBy)
					OUTPUT INSERTED.soLineItemId, INSERTED.qty 
					INTO @updatePoLineItem
					SELECT @updatePoId, @updatePo, s.soLineItemId, s.supplierSkuId, s.supplierSku, s.invID, s.itemCode, SUM(s.openQty) as orderQty, s.currency, s.supCost, CAST(s.supCost * @currencyRate as NUMERIC(13,4)),
						s.itemReference1, '' as itemReference2, s.merchantSku, s.EAN, 1079 as itemStatus, s.itemDesc, getdate(), @userId, getdate(), @userId
					FROM #soInfo s
						LEFT JOIN poLineItem po
							ON s.soLineItemId = po.soLineItemId
					WHERE soHeaderId = @soHeaderId
						AND po.poDetailsId IS NULL
					GROUP BY soReferenceId, s.soLineItemId, s.supplierSkuId, s.invID, s.itemCode, s.supplierSku, s.supCost, s.currency,  s.itemReference1, 
						s.merchantSku, s.EAN, CAST(s.supCost * @currencyRate as NUMERIC(13,4)), s.itemDesc

 					UPDATE soLineItem SET
						poQty = poQty + s.qty,
						updateDate = getdate()
					FROM @updatePoLineItem s
					WHERE soLineItem.soLineItemId = s.soLineItemId

					INSERT INTO @result (poRefName, poQty)
					SELECT @updatePo, SUM(qty)
					FROM @updatePoLineItem
				END

				UPDATE soLineItem SET
					soLineItemStatus = CASE WHEN odrQty = 0 THEN 1107 ELSE 2125 END
				WHERE odrQty - poQty = 0
					AND soHeaderId = @soHeaderId

				UPDATE soHeader SET
					soStatus = 2125
				FROM (SELECT s.soHeaderId
					  FROM soHeader s
						INNER JOIN soLineItem sl
							ON s.soHeaderId = sl.soHeaderId
					  WHERE s.soHeaderId = @soHeaderId
					  GROUP BY s.soHeaderId
					  HAVING SUM(odrQty - poQty) = 0
                      ) g
				WHERE soHeader.soHeaderId = g.soHeaderId

				FETCH NEXT FROM CUR_soConvertList 
				INTO @soHeaderId, @companyId, @supplierId, @soName
			END

			CLOSE CUR_soConvertList
			DEALLOCATE CUR_soConvertList

		COMMIT TRANSACTION

		SET @returnMessage = (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), poRefName) + ' : ' + CAST(poQty as VARCHAR) + ' item Qty ordered', ', ')
                                FROM @result
                            );

		SELECT '_SUCCESS_' as execStatus, @returnMessage as execMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as execStatus, @returnMessage as execMessage

        RETURN -1
	END CATCH
END

GO

