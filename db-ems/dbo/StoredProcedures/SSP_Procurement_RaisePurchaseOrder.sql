
--1105	Open
--1106	Confirm
--1107	Cancel
--1108	Close

-- =============================================
-- Author:		WL Leong
-- Create date: 2023-08-28
-- Used By:	    EMS -> Procurement -> Raise PO

-- Description : Once the SO is confirmed, can multi select to convert PO 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-08   1.1         ZY Wong     Change column to itemCode
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
/**
 EXEC SSP_Procurement_RaisePurchaseOrder
 N'{"list":[{"procurementProcessId":"823", "supplierId":"13", "poQty":"263"},{"procurementProcessId":"824", "supplierId":"13", "poQty":"263"}]}'
, 1 
 
 **/
 
CREATE PROCEDURE [dbo].[SSP_Procurement_RaisePurchaseOrder]
@json VARCHAR(MAX),
@userId INT
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON;
	BEGIN TRY

			DECLARE @RaiseMessage varchar(max)
			DECLARE @result as TABLE (poRefName varchar(20), poQty int)

			-- DECLARE @json varchar(MAX) = N'{"list":[{"procurementProcessId":"505", "supplierId":"28", "poQty":"45.0000"}]}'
			-- DECLARE @userId INT = 1

			DROP TABLE IF EXISTS #list;
			
			SELECT procurementProcessId, supplierId, CONVERT(NUMERIC(13,4), poQty) as poQty
			INTO #list
			FROM  OPENJSON(@json, '$.list') 
   				WITH (
					procurementProcessId BIGINT	N'$.procurementProcessId',
					supplierId INT				N'$.supplierId',
					poQty VARCHAR(20)			N'$.poQty'
				)
			
 
			DROP TABLE IF EXISTS #procurementList;
 
			SELECT p.soHeaderId, p.soName, p.companyId, p.procurementProcessId, p.soLineItemId, ls.supplierId, ls.poQty, p.rawBomInvId
			INTO #procurementList
			FROM procurementProcess p
				INNER JOIN #list ls
					ON p.procurementProcessId = ls.procurementProcessId
					AND status = 0

 
			IF (SELECT COUNT(1) FROM #procurementList where poQty = 0) > 0
			BEGIN
				DECLARE @ZeroProcurement varchar(5000) 
				
				SELECT @ZeroProcurement = COALESCE(@ZeroProcurement + ', ' + soName, soName) 
				FROM #procurementList
				WHERE poQty = 0

				SELECT '_ALERT_' as status, @ZeroProcurement + ' does not have po qty'  as returnMessage


				RETURN -1
			END

			DROP TABLE IF EXISTS #soInfo;
 
			SELECT s.soHeaderId, s.companyId,  ls.supplierId, s.soName, s.customerPO, s.soDate, s.earlyShipDate, s.lateShipDate, s.portOfLanding, 
				s.portofDestination, s.shipWay, s.vesselBooking, s.thirdParty, s.thirdPartyPO, s.Reference1 as soReferenceId, s.soNote, ls.procurementProcessId
			INTO #soInfo
			FROM soHeader s
				INNER JOIN #procurementList ls
					ON s.soHeaderId = ls.soHeaderId

 
			DROP TABLE IF EXISTS #lineItem;

			SELECT s.soHeaderId, s.companyId, s.supplierId, s.soName, s.procurementProcessId, s.rawBomInvId, 
				inv.itemCode, sku.supplierSku, sku.supplierSkuId, cur.categoryName as currencyCode, sku.supCost, s.poQty, s.soLineItemId
			INTO #lineItem
			FROM #procurementList s
				LEFT JOIN MD_SupplierSku sku
					ON s.companyId = sku.companyId
					AND s.supplierId = sku.supplierId
					AND s.rawBomInvId = sku.invId
					AND sku.statusflag = 1
				INNER JOIN md_masterCategory cur
					ON sku.currencyCode = cur.categoryId
					AND cur.status = 1
				INNER JOIN md_Inventory inv  
					ON s.rawBomInvId = inv.invId



			IF (SELECT COUNT(1) FROM #lineItem WHERE supplierSku IS NULL) > 0
			BEGIN
				DECLARE @emptySupplierSku varchar(5000) 
				
				SELECT @emptySupplierSku = COALESCE(@emptySupplierSku + ', ' + inventorySku, inventorySku) 
				FROM #lineItem cl
					INNER JOIN MD_inventory inv
						ON cl.rawBomInvId = inv.invId
				WHERE supplierSkuId IS NULL

				SELECT '_ALERT_' as status, @emptySupplierSku + ' is not yet configured in supplier sku'  as returnMessage
				RETURN -1 
			END
 
		BEGIN TRANSACTION

			DECLARE @returnMessage VARCHAR(5000)
			DECLARE @companyId INT, @supplierId INT

			DECLARE CUR_soConvertList CURSOR LOCAL FOR  
			SELECT DISTINCT companyId, supplierId
			FROM #lineItem 

			OPEN CUR_soConvertList  
			FETCH NEXT FROM CUR_soConvertList 
			INTO @companyId, @supplierId
 
			WHILE @@FETCH_STATUS=0
			BEGIN 
				DECLARE @poId BIGINT, @poName varchar(50);
				DECLARE @poCompanyId INT
			
				DECLARE @homeCurrency VARCHAR(3), @foreignCurrency VARCHAR(3), @currencyRate NUMERIC(14, 4) = 0

				SET @foreignCurrency = (SELECT TOP 1 mc.categoryName 
										FROM md_supplierSku sku
											INNER JOIN md_MasterCategory mc
												ON sku.currencyCode = mc.categoryId
												AND sku.statusFlag = 1
										WHERE supplierId = @supplierId);

				SET @homeCurrency = (SELECT configValue FROM MD_defaultConfig WHERE configName = 'DefaultCurrency' AND companyId = @companyId);
			
				IF @homeCurrency = @foreignCurrency
				BEGIN
					SET @currencyRate = 1
				END 

				IF @foreignCurrency IS NULL OR @homeCurrency IS NULL
				BEGIN
					SELECT '_ALERT_' as status, 'default supplier/company currency code is not setup'  as returnMessage

					COMMIT TRANSACTION
					RETURN -1 
				END
				ELSE
				BEGIN
					SET @currencyRate = (SELECT foreignRate
										 FROM md_CurrencyRate
										 WHERE CONVERT(date, getdate()) BETWEEN startDate AND endDate)

					IF @currencyRate = 0
					BEGIN
						SELECT '_ALERT_' as status, 'please set up the currency rate in the system'  as returnMessage

						COMMIT TRANSACTION
						RETURN -1 
					END
				END
				

				--DECLARE @companyID INT = 5
				DECLARE @shpToId INT
				SET @shpToID = (SELECT TOP 1 shipToId FROM MD_ShipToDestination WHERE companyId = @companyId);
				
				IF @shpToID IS NULL
				BEGIN
					SELECT '_ALERT_' as status, 'warehouse is not setup'  as returnMessage

					COMMIT TRANSACTION
					RETURN -1 
				END

				--IF (SELECT COUNT(1) FROM poHeader WHERE poReferenceId = @soName) = 0
				--BEGIN

					DECLARE @tempPO varchar(100) = 'tempPO-' + CAST(@userId as VARCHAR) + '-' + FORMAT(getdate(),'yyyyMMddHHmmssffff')
					DECLARE @poTable TABLE(poId BIGINT, poName varchar(50));

					DECLARE @soName VARCHAR(MAX) = (SELECT TOP 1 soName FROM #lineItem WHERE supplierId = @supplierId);

					INSERT INTO poHeader(companyId, supplierId, poName, poReferenceId, shipToid, shipVia, vesselBooking, portOfLanding, portOfDestination, poEarlyShipDate, poLateShipDate, poStatus, poNote,
						poNetTotal, poDiscount, poTax, poGrossTotal, foreignCurrencyCode, homeCurrencyCode, foreignCurrencyRate, reference1, reference2, reference3, enterDate, enterBy)
					OUTPUT INSERTED.poID, INSERTED.poName
					INTO @poTable
					SELECT DISTINCT companyId, supplierId, @tempPO, @soName, @shpToId, '' shipWay, '' vesselBooking, '' portOfLanding, '' portOfDestination, 
						null earlyShipDate, null lateShipDate, 1079 as poStatus, '' as poNote, 
						0 as poNetTotal, 0 as poDiscount, 0 as poTax, 0 as poGrossTotal,   @foreignCurrency, @homeCurrency, @currencyRate,
						'' as reference1, '' as reference2, '' as reference3, getdate() as enterDate, @userId as enterBy
					FROM #lineItem li
					WHERE supplierId = @supplierId
 
					SELECT @poId = poId FROM @poTable;
					
					DECLARE @raisePO table(tempPO VARCHAR(50), soLineItemId BIGINT, qty INT)

 					INSERT INTO poLineItem(poId, poName, soLineItemId, supplierSKU, invId, itemCode, qty, currencyCode, unitPrice, homeCurrencyCost, itemReference1, merchantSku, itemStatus, enterDate, enterBy, updateDate, updateBy)
					OUTPUT INSERTED.poName, INSERTED.soLineItemId, INSERTED.qty 
					INTO @raisePO
					SELECT @poId, @tempPO, s.soLineItemId, s.supplierSku, s.rawBomInvId, s.itemCode, SUM(poQty) as orderQty, currencyCode, supCost, CAST(supCost * @currencyRate as NUMERIC(13,4)),
						'' as itemReference1,'' as  merchantSku, 1079 as itemStatus, getdate(), @userId, getdate(), @userId
					FROM #lineItem s
					WHERE supplierId = @supplierId
					GROUP BY s.soLineItemId, s.rawBomInvId, itemCode, s.supplierSku, supCost, currencyCode
 

 					EXEC [dbo].[SSP_GetRunningNo] 'PO', @companyId, @poName output
	
					IF @poName IS NULL
					BEGIN
						SELECT '_ALERT_' as status, 'poName is not created properly'  as returnMessage

						COMMIT TRANSACTION
						RETURN -1 
					END
 
					UPDATE p SET
						poQty = p.poQty + s.poQty 
					FROM procurementProcess p
						INNER JOIN #lineItem s
							ON p.procurementProcessId = s.procurementProcessId
							AND s.supplierId = @supplierId

					UPDATE p SET
						status =1
					FROM procurementProcess p
						INNER JOIN #lineItem s
							ON p.procurementProcessId = s.procurementProcessId
							AND s.supplierId = @supplierId
					WHERE p.poQty - rawBomTotalQty = 0

 					UPDATE soLineItem SET
						poQty = poQty + s.qty,
						updateDate = getdate()
					FROM @raisePO s
					WHERE soLineItem.soLineItemId = s.soLineItemId

					UPDATE poHeader SET
						poName = @poName
					WHERE poName = @tempPO

					UPDATE poLineItem SET
						poName = @poName
					WHERE poName = @tempPO

 
						
					INSERT INTO @result(poRefName, poQty)
					SELECT @poName, SUM(qty)
					FROM @raisePO

				--END
				--ELSE
				--BEGIN
				--	DECLARE @updatePo VARCHAR(50)
				--	DECLARE @updatePoId BIGINT

				--	SET @updatePoId = (SELECT poId FROM poHeader WHERE poReferenceId = @soName)
				--	SET @updatePo = (SELECT poName FROM poHeader WHERE poId = @updatePoId)

				--	UPDATE p SET
				--		poEarlyShipDate = s.earlyShipDate, 
				--		poLateShipDate = s.lateShipDate,
				--		reference1 = s.customerPO,
				--		reference2 = s.thirdPartyPO,
				--		poStatus = 1079,
				--		updateDate = getdate(),
				--		updateBy = @userId,
				--		lastUpdatedDate = getdate() --CASE WHEN p.poStatus = 1077  THEN getdate() ELSE p.lastUpdatedDate END
				--	FROM poHeader p
				--		INNER JOIN soHeader s
				--			ON p.poReferenceId = s.soName
				--	WHERE s.soHeaderId =  @soHeaderId
						
				--	DECLARE @updatePoLineItem table(soLineItemId BIGINT, qty INT)

 			--		UPDATE poLineItem SET
				--		qty = s.odrQty,
				--		itemStatus = 1079,
				--		updateDate = getdate(),
				--		updateBy = @userId
				--	OUTPUT INSERTED.soLineItemId, INSERTED.qty 
				--	INTO @updatePoLineItem
				--	FROM soLineItem s
				--	WHERE poLineItem.poId = @updatePoId
				--		AND poLineItem.soLineItemId = s.soLineItemId

 			--		INSERT INTO poLineItem(poId, poName, soLineItemId, supplierSKU, invId, upc, qty, currencyCode, unitPrice, itemReference1, merchantSku, itemStatus, enterDate, enterBy, updateDate, updateBy)
				--	OUTPUT INSERTED.soLineItemId, INSERTED.qty 
				--	INTO @updatePoLineItem
				--	SELECT @updatePoId, @updatePo, s.soLineItemId, s.supplierSku, s.invID, s.upc, SUM(OpenQty) as orderQty, cur.categoryName as currencyCode, supCost, s.itemReference1, s.merchantSku, 
				--		1079 as itemStatus, getdate(), @userId, getdate(), @userId
				--	FROM #customerSOList s
				--		INNER JOIN md_masterCategory cur
				--			ON s.currencyCode = cur.categoryId
				--		LEFT JOIN poLineItem po
				--			ON s.soLIneItemId = po.soLineItemId
				--	WHERE soHeaderId = @soHeaderId
				--		AND po.poDetailsId IS NULL
				--	GROUP BY soReferenceId, s.soLineItemId, s.invID, s.upc, s.supplierSku, supCost, cur.categoryName, s.itemReference1, s.merchantSku

 			--		UPDATE soLineItem SET
				--		poQty = poQty + s.qty,
				--		updateDate = getdate()
				--	FROM @updatePoLineItem s
				--	WHERE soLineItem.soLineItemId = s.soLineItemId

				--	INSERT INTO @result(poRefName, poQty)
				--	SELECT @updatePo, SUM(qty)
				--	FROM @updatePoLineItem
				--END

				--UPDATE soLineItem SET
				--	soLineItemStatus = CASE WHEN odrQty = 0 THEN 1107 ELSE 2125 END
				--WHERE odrQty - poQty = 0
				--	AND soHeaderId = @soHeaderId

				--UPDATE soHeader SET
				--	soStatus = 2125
				--FROM (SELECT s.soHeaderId
				--	  FROM soHeader s
				--		INNER JOIN soLineItem sl
				--			ON s.soHeaderId = sl.soHeaderId
				--	  WHERE s.soHeaderId = @soHeaderId
				--	  GROUP BY s.soHeaderId
				--	  HAVING SUM(odrQty - poQty) = 0) g
				--WHERE soHeader.soHeaderId = g.soHeaderId

				FETCH NEXT FROM CUR_soConvertList 
				INTO @companyId, @supplierId
			END

			CLOSE CUR_soConvertList
			DEALLOCATE CUR_soConvertList

		COMMIT TRANSACTION

		SELECT @returnMessage =   COALESCE(poRefName + ' : ' + CAST(SUM(poQty) as varchar) + ' item Qty ordered ', poRefName + ' : ' + CAST(SUM(poQty) as varchar) + ' item Qty ordered ')   
		FROM @result
		GROUP BY poRefName

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage
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
 
		SET @RaiseMessage =  ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, 'SSP_ProcurementProcess_RaisePurchaseOrder : ' + @RaiseMessage as returnMessage
	END CATCH
END

GO

