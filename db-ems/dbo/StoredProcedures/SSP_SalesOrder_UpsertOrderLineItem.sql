-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-07-01   7.0         ZY Wong     Add new column EAN into soLineItem
-- 2025-03-11   6.0         ZY Wong     (factory) if all line item updated division <> 'others', auto update order status from draft to confirm
-- 2024-05-21   5.0         WL Leong    Only allowed delete if it is draft, if reactive the cancel item, the item will be in draft status
-- 2024-04-16   4.1         ZY Wong     Add soItemDesc into soLineItem table
-- 2024-03-20	4.0			WL Leong	When delete for lineItem, delete it completely
-- 2024-01-22	3.0			ZY Wong		Add XACT_ABORT
-- 2024-01-15	2.0			WL Leong	Add merchantSku
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_UpsertOrderLineItem
--N'{"soItemList":[{"soHeaderId":8,"soLineItemId":2,"customerSku":"5497412WCOM","odrQty":10,"freightCost":0,"itemCost":0,"itemNote":""},{"soHeaderId":8,"soHeaderId":0,"customerSku":"5497412WCOM","odrQty":20,"freightCost":0,"itemCost":0,"itemNote":""}]}'
--, 1

CREATE PROCEDURE [dbo].[SSP_SalesOrder_UpsertOrderLineItem]
@orderJson VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @ErrMessage VARCHAR(MAX) = ''
		--DECLARE @orderJson VARCHAR(MAX)
		--DECLARE @createdBy INT = 1
		--SET @orderJson = N'{"soItemList":[{"soHeaderId":"10053","soLineItemId":"10025","customerSkuId":"1068","customerSku":"LLY-11013EX","odrQty":"40","freightCost":"0.00","itemCost":"20.00","itemNote":""},{"soHeaderId":"10053","soLineItemId":"10026","customerSkuId":"1069","customerSku":"LLY-11068EX\/DBR","odrQty":"20","freightCost":"0.00","itemCost":"25.00","itemNote":""}]}'
 
 
		DROP TABLE IF EXISTS #orderLineItem;

		SELECT * 
		INTO #orderLineItem
		FROM  OPENJSON(@orderJson, '$.soItemList') 
   			WITH (
				soHeaderId BIGINT			N'$.soHeaderId',
				soLineItemId BIGINT			N'$.soLineItemId',
				customerSkuId BIGINT		N'$.customerSkuId',
				customerSku VARCHAR(50)		N'$.customerSku',
				orderQty INT				N'$.odrQty',
				itemCost NUMERIC(13,4)		N'$.itemCost',
				freightCost NUMERIC(13,4)	N'$.freightCost',
				itemNote VARCHAR(200)		N'$.itemNote',
                tagDivision INT             N'$.tagDivision'
			)

        DECLARE @soHeaderId BIGINT = (SELECT TOP 1 soHeaderId FROM #orderLineItem);
        DECLARE @companyId INT = (SELECT companyId FROM soHeader WHERE soHeaderId = @soHeaderId);
        DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId);
 
--1105	Open SO
--1106	Confirm SO
--1107	Cancel SO
--1108	Close SO	
		DROP TABLE IF EXISTS #lineItem;

		SELECT so.soName, odr.soHeaderId, odr.soLineItemId, sku.invId, odr.itemCost, currency.categoryName as currency, odr.customerSkuId, odr.customerSku, sku.itemDesc, 
			CASE WHEN odr.itemCost <> sku.csCost THEN 1 ELSE 0 END as isItemPriceChanged, odr.freightCost, 
			odr.orderQty, 0 as poQty, 0 as shpQty, odr.itemNote, 1105 as lineItemStatus, sku.merchantSku, sku.EAN, odr.tagDivision
		INTO #lineItem
		FROM #orderLineItem odr
			INNER JOIN soHeader so
				ON odr.soHeaderId = so.soHeaderId
			INNER JOIN md_customerSku sku
				ON sku.companyId = so.companyId
				AND sku.customerId = so.customerId
				AND odr.customerSkuId = sku.customerSkuId
				AND statusFlag = 1
			INNER JOIN md_masterCategory currency
				ON sku.currencyCode = currency.categoryId

        -- check item exists for Add
        DROP TABLE IF EXISTS #chkItemExists;

        SELECT so.soLineItemId 
        INTO #chkItemExists
        FROM #lineItem li
            INNER JOIN soLineItem so
                ON li.customerSkuId = so.customerSkuId
                AND li.soHeaderId = so.soHeaderId
        WHERE ISNULL(li.soLineItemId,0) = 0

        IF (SELECT COUNT(1) FROM #chkItemExists) > 0
        BEGIN
            SET @ErrMessage = 'This product already add, please choose another product';
			THROW 60000, @ErrMessage,1;
        END

		IF (SELECT COUNT(DISTINCT currency) FROM #lineItem) > 1
		BEGIN
			SET @ErrMessage = 'Items have different currency code';
			THROW 60000, @ErrMessage,1;
		END

		IF (SELECT COUNT(*) FROM #lineItem) > 0
		BEGIN
 			DECLARE @soName as varchar(100)

			SELECT TOP 1 @soName = soName
			FROM #lineItem

 			UPDATE lineitem SET
				csCost = odr.itemCost, 
				isItemPriceChanged = odr.isItemPriceChanged,
				odrQty  = odr.orderQty, 
				freightCost  = odr.freightCost,
				merchantSku = odr.merchantSku,
                EAN = odr.EAN,
				itemNote  = odr.itemNote, 
                soLineItemStatus = 1105,
                tagDivision = odr.tagDivision,
				updateBy = @createdBy,
				updateDate = getdate()
			FROM soLineItem lineitem
				INNER JOIN #lineItem odr
					ON lineItem.soLineItemId = odr.soLineItemId
			WHERE soLineItemStatus IN (2144, 1105) -- reopen & draft
 
 			DROP TABLE IF EXISTS #removeLineItem;

			SELECT so.soHeaderId, so.soLineItemId
			INTO #removeLineItem
			FROM soLineItem so
				LEFT JOIN #lineItem odr
					ON so.soLineItemId = odr.soLineItemId
			WHERE  odr.soLineItemId IS NULL
				AND so.soHeaderId =  @soHeaderId
 
            DECLARE @currentStatus INT  
            
            SET @currentStatus = (SELECT TOP 1 soStatus FROM #lineItem li INNER JOIN soHeader s ON li.soHeaderId = s.soHeaderId)

 
			IF (SELECT COUNT(1) FROM #removeLineItem) > 0
			BEGIN
				IF @currentStatus = 1105
				BEGIN
 
					DELETE FROM soLineItem 
					WHERE soLineItemId IN (SELECT soLineItemId FROM #removeLineItem) 
						AND soHeaderId = @soHeaderId
					
					
					SET @ErrMessage = ' & deleted';
				END
				ELSE
				BEGIN
					UPDATE soLineItem SET 
						soLineItemStatus = 1107,
                        odrQty = 0
					FROM #removeLineItem removeId
					WHERE soLineItem.soLineItemId = removeId.soLineItemId
						AND soLineItem.soHeaderId = @soHeaderId

					SET @ErrMessage = ' & canceled';
				END
			END

			INSERT INTO soLineItem (soHeaderId, invId, customerSkuId, customerSku, soItemDesc, merchantSku, EAN, csCost, currencyCode, isItemPriceChanged, 
				odrQty, poQty, shpQty, itemNote, soLineItemStatus, tagDivision, createBy, createDate)
			SELECT odr.soHeaderId, odr.invId, odr.customerSkuId, odr.customerSku, odr.itemDesc, odr.merchantSku, odr.EAN, odr.itemCost, odr.currency, odr.isItemPriceChanged,
				orderQty, odr.poQty, odr.shpQty, odr.itemNote, odr.lineItemStatus, odr.tagDivision, @createdBy, getdate()
			FROM #lineItem odr
			WHERE soLineItemId = 0

			IF (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId = 0) > 0 AND (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId <> 0) = 0
			BEGIN
				SET @ErrMessage = 'LineItems are successfully created' + @ErrMessage;
			END 
			ELSE IF (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId = 0) = 0 AND (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId <> 0) > 0
			BEGIN
				SET @ErrMessage = 'LineItems are successfully updated' + @ErrMessage;
			END 
			ELSE IF (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId = 0) > 0 AND (SELECT COUNT(1) FROM #lineItem WHERE soLineItemId <> 0) > 0
			BEGIN
				SET @ErrMessage = 'LineItems are successfully created & updated' + @ErrMessage;
			END
			ELSE
			BEGIN
				SET @ErrMessage = 'LineItems are successfully' + REPLACE(@ErrMessage, ' &','');
			END

            -- for factory, if all items tagDivision <> 'others', auto confirm order status
            IF @isMarketing = 0
            BEGIN
                IF (SELECT COUNT(1) FROM soLineItem WHERE soHeaderId = @soHeaderId AND soLineitemStatus <> 1107 AND tagDivision = 3234) = 0
                BEGIN
                    UPDATE soHeader SET
                        soName = REPLACE(soHeader.soName, 'tempSO_', ''),
				        soStatus = 1106, -- confirm
                        apiStatus = '_NEW_',
				        updateBy = @createdBy,
				        updateDate = getdate()
			        WHERE soHeaderId = @soHeaderId

                    UPDATE soLineItem SET
				        soLineItemStatus = 1106, -- confirm
				        updateBy = @createdBy,
				        updateDate = getdate()
			        WHERE soHeaderId = @soHeaderId
                         AND soLineitemStatus <> 1107
                END
            END
 
            IF @currentStatus <> 1105
            BEGIN
			    UPDATE soHeader SET
				    lastUpdatedDate = getdate()
			    WHERE soHeaderId = @soHeaderId			
            END

			SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage 	
		END
		ELSE
		BEGIN
			SET @ErrMessage = 'No rows being inserted/updated.';

			SELECT '_ALERT_' as status, @ErrMessage AS returnMessage 
		END

		COMMIT TRANSACTION
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

GO

