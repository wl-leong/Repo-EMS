-- =============================================
-- Author:		WL Leong
-- Create date: 2024-03-10
-- Used By:	    EMS -> PO Module -> PO Listing -> Upsert PO LIneItem

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-04-22   4.0         ZY Wong     Json change itemCode to supplierSku, remove merchantSku ** AddPoItem should remove in future
-- 2024-04-08   3.0         ZY Wong     Change column to itemCode
-- 2024-03-20	2.0			WL Leong	Initial
-- 2024-03-10	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_PurchaseOrder_UpsertOrderLineItem
N'{"poItemList":[{"poId":5,"poDetailsId":10,"supplierSku":"MPH23207 SB","unitPrice":"42.2300","qty":"80","itemNote":"","action":"UpdatePoItem"}]}'
--N'{"poItemList":[{"poId":5,"poDetailsId":11,"supplierSku":"MPH23392 TWH","unitPrice":"44.2300","qty":"89","itemNote":"","action":"DeletePoItem"}]}'
--N'{"poItemList":[{"poId":5,"poDetailsId":0,"supplierSku":"MPH23392 TWH","unitPrice":"44.2300","qty":"89","itemNote":"","action":"AddPoItem"}]}'
, 1
select * from poLIneItem where poId = 5
select * from poHeader
  **/ 
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_UpsertOrderLineItem_tobe]
@orderJson VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @createdBy INT = 1, @orderJson VARCHAR(MAX) = N'{"poItemList":[{"poId":5,"poDetailsId":0,"supplierSku":"MPH23392 TWH","unitPrice":"44.2300","qty":"89","itemNote":"","action":"AddPoItem"}]}';

		DECLARE @returnMessage VARCHAR(MAX) = '';
		DECLARE @ErrMessage VARCHAR(500);
 
		DROP TABLE IF EXISTS #orderLineItem;

		SELECT actionType, poId, poDetailsId, supplierSku, CONVERT(NUMERIC(13,4), unitPrice) as unitPrice, qty, itemNote
		INTO #orderLineItem
		FROM  OPENJSON(@orderJson, '$.poItemList') 
   			WITH (
				actionType VARCHAR(50)		N'$.action',
				poId BIGINT					N'$.poId',
				poDetailsId BIGINT			N'$.poDetailsId',
				supplierSku VARCHAR(50)		N'$.supplierSku',
				unitPrice VARCHAR(20)		N'$.unitPrice',
				qty INT						N'$.qty',
				itemNote VARCHAR(200)		N'$.itemNote'
			)

        DECLARE @actionType VARCHAR(50) = (SELECT TOP 1 actionType FROM #orderLineItem);
 
		--DROP TABLE IF EXISTS #polineItem;

		--SELECT o.poId, o.poDetailsId, o.supplierSku, sku.invId, o.unitPrice, o.qty, o.itemNote
		--INTO #polineItem
		--FROM #orderLineItem o
		--	INNER JOIN md_SupplierSku sku
		--		ON o.supplierSku = sku.supplierSku
  --              AND sku.supplierId = @supplierId
  --              AND sku.companyId = @companyId

		IF @actionType = 'UpdatePoItem'
		BEGIN
			DROP TABLE IF EXISTS #validateQty;

			SELECT p.poDetailsId, po.soLineItemId, p.qty, so.odrQty
			INTO #validateQty
			FROM #orderLineItem p
				INNER JOIN poLineItem po
					ON p.poDetailsId = po.poDetailsId
				LEFT JOIN soLineItem so
					ON po.soLineItemId = so.soLineItemId

			IF (SELECT COUNT(1) FROM #validateQty WHERE qty > odrQty) > 0
			BEGIN
				SET @returnMessage = 'PO qty cannot more than SO order qty';				
				THROW 60000, @returnMessage, 1
			END
		END

		DROP TABLE IF EXISTS #lineItem;
 
		SELECT odr.poId, odr.poDetailsId, p.poName, sku.invId, sku.supplierSkuId, odr.supplierSku, pli.itemCode, so.merchantSku, odr.unitPrice, 
            p.foreignCurrencyCode as currency, p.foreignCurrencyRate, p.foreignCurrencyRate * odr.unitPrice as homeCurrencyCost, odr.qty, odr.itemNote, 1079 as itemStatus
		INTO #lineItem
		FROM #orderLineItem odr
			INNER JOIN poHeader p
				ON odr.poId = p.poId
            INNER JOIN poLineItem pli
                ON odr.poDetailsId = pli.poDetailsId
			INNER JOIN md_supplierSku sku
				ON sku.companyId = p.companyId
				AND sku.supplierId = p.supplierId
                AND sku.supplierSku = odr.supplierSku
				AND sku.statusFlag = 1
            INNER JOIN soLineItem so
				ON pli.soLineItemId = so.soLineItemId

  
		IF (SELECT COUNT(*) FROM #lineItem) > 0
		BEGIN
			BEGIN TRANSACTION

				DECLARE @poName as varchar(100), @poId BIGINT, @poDetailsId BIGINT

				SELECT TOP 1 @poName = poName, @poId = poId, @poDetailsId = poDetailsId
				FROM #lineItem

				IF @actionType = 'UpdatePoItem'
				BEGIN
					DECLARE @updateLineItem table(soLineItemId BIGINT, qty INT, oldQty INT)

					UPDATE lineitem SET
						unitPrice = odr.unitPrice, 
						qty  = odr.qty, 
						itemNote  = odr.itemNote, 
						homeCurrencyCost = odr.homeCurrencyCost,
						updateBy = @createdBy,
						updateDate = getdate()
					OUTPUT inserted.soLineItemId, inserted.qty, deleted.qty
					INTO @updateLineItem
					FROM poLineItem lineitem
						INNER JOIN #lineItem odr
							ON lineItem.poDetailsId = odr.poDetailsId

					DROP TABLE IF EXISTS #updateQty;

					SELECT soLineItemId, qty as newQty
					INTO #updateQty
					FROM @updateLineItem
					WHERE qty <> oldQty
					
					IF (SELECT COUNT(1) FROM #updateQty) > 0
					BEGIN
						UPDATE soLineItem SET	
							poQty = p.newQty
						FROM #updateQty p
						WHERE soLineItem.soLineItemId = p.soLineItemId
					END

                    SET @ErrMessage = ' updated';
				END

				IF @actionType = 'DeletePoItem'
				BEGIN

					DELETE FROM poLineItem 
					WHERE poDetailsId = @poDetailsId
					
					SET @ErrMessage = ' deleted';
				END

				IF @actionType = 'AddPoItem'
				BEGIN
					INSERT INTO poLineItem(poId, poName, supplierSkuId, supplierSkuId, supplierSku, invId, itemCode, currencyCode, unitPrice, qty, rcvQty, itemStatus, merchantSku
						, enterBy, enterDate, soLineItemId, homeCurrencyCost)
					SELECT odr.poId, odr.poName, odr.supplierSkuId, supplierSkuId, odr.supplierSku, odr.invId, odr.itemCode, odr.currency, odr.unitPrice, qty, 0, itemStatus, merchantSku
						, @createdBy, getdate(), 0, homeCurrencyCost
					FROM #lineItem odr
					WHERE poDetailsId = 0

                    SET @ErrMessage = ' created';
				END

				DECLARE @netTotal NUMERIC(18,4)

				SELECT @netTotal = SUM(unitPrice) 
				FROM poLineItem
				WHERE itemStatus <> 1086
					AND poId = @poId

				SET @ErrMessage = 'LineItems are successfully' + @ErrMessage;
	
				UPDATE poHeader SET
					poNetTotal = ISNULL(@netTotal, 0),
					poGrossTotal = ISNULL(@netTotal, 0) + ISNULL(poTax, 0) - ISNULL(poDiscount, 0),
					lastUpdatedDate = getdate(),
					updateBy = @createdBy
				WHERE poId = @poId				

			COMMIT TRANSACTION

			SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage 	
		END
		ELSE
		BEGIN
			SET @ErrMessage = 'No rows being inserted/updated.';

			SELECT '_ALERT_' as status, @ErrMessage AS returnMessage 
		END

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

