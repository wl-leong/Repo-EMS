-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-07-01   3.0         ZY Wong     Add new column EAN into soLineItem
-- 2025-05-23   2.0         ZY Wong     Remove customerSku in json, get using customerSkuId
-- 2024-04-28	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_SalesOrder_AddOrderLineItem
N'{
	"soItemList": [
		{
			"soHeaderId": 21263,
			"soLineItemId": 0,
			"customerSkuId": "597",
			"customerSku": "BH5336278612105",
			"odrQty": 60,
			"freightCost": 0,
			"itemCost": "39.6071",
			"itemNote": "",
            "tagDivision": "3231"
		}
	]
}'
, 1

select* from md_customersku where companyId = 11
**/

-- select * from md_customersku where customerid = 33 and companyid = 11
-- select * from soLineItem where soheaderid = 20428
CREATE PROCEDURE [dbo].[SSP_SalesOrder_AddOrderLineItem]
@orderJson VARCHAR(MAX),
@createdBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION
 
		DECLARE @ErrMessage VARCHAR(MAX) = ''
--		DECLARE @orderJson VARCHAR(MAX)
--		DECLARE @createdBy INT = 1
--		SET @orderJson = N'{
--	"soItemList": [
--		{
--			"soHeaderId": 20428,
--			"soLineItemId": 0,
--			"customerSkuId": "292",
--			"customerSku": "BH61100005302WH",
--			"odrQty": 10,
--			"freightCost": 0,
--			"itemCost": "48.5",
--			"itemNote": "",
--            "tagDivision": "3231"
--		}
--	]
--}'

		DROP TABLE IF EXISTS #orderLineItem;

		SELECT * 
		INTO #orderLineItem
		FROM  OPENJSON(@orderJson, '$.soItemList') 
   			WITH (
				soHeaderId BIGINT			N'$.soHeaderId',
				soLineItemId BIGINT			N'$.soLineItemId',
				customerSkuId BIGINT		N'$.customerSkuId',
				--customerSku VARCHAR(50)		N'$.customerSku',
				orderQty INT				N'$.odrQty',
				itemCost NUMERIC(13,4)		N'$.itemCost',
				freightCost NUMERIC(13,4)	N'$.freightCost',
				itemNote VARCHAR(200)		N'$.itemNote',
                tagDivision INT             N'$.tagDivision'
			)
 
--1105	Open SO
--1106	Confirm SO
--1107	Cancel SO
--1108	Close SO	


		DROP TABLE IF EXISTS #lineItem;

		SELECT so.soName, odr.soHeaderId, odr.soLineItemId as soLineItemId, sku.invId, odr.itemCost, currency.categoryName as currency, odr.customerSkuId, sku.customerSku, sku.itemDesc, 
			CASE WHEN odr.itemCost <> sku.csCost THEN 1 ELSE 0 END as isItemPriceChanged, odr.freightCost, 
			odr.orderQty, 0 as poQty, 0 as shpQty, odr.itemNote, 1105 as lineItemStatus, sku.merchantSku, sku.EAN, odr.tagDivision
		INTO #lineItem
		FROM #orderLineItem odr
			INNER JOIN soHeader so
				ON odr.soHeaderId = so.soHeaderId
			INNER JOIN md_customerSku sku
				ON sku.customerSkuId = odr.customerSkuId
                AND sku.companyId = so.companyId
                AND sku.customerId = so.customerId
                AND sku.statusFlag = 1
			INNER JOIN md_masterCategory currency
				ON sku.currencyCode = currency.categoryId
        WHERE ISNULL(odr.soLineItemId, 0) = 0

        IF (SELECT COUNT(1) FROM #lineItem) = 0
        BEGIN
            SET @ErrMessage = 'No line item information found';
			THROW 60000, @ErrMessage,1;
        END
 
        -- check item exists for Add
        DROP TABLE IF EXISTS #chkItemExists;

        SELECT so.soLineItemId, li.customerSkuId, so.soLineItemStatus
        INTO #chkItemExists
        FROM #lineItem li
            INNER JOIN soLineItem so
                ON li.customerSkuId = so.customerSkuId
                AND li.soHeaderId = so.soHeaderId
        WHERE ISNULL(li.soLineItemId,0) = 0

        IF (SELECT COUNT(1) FROM #chkItemExists WHERE soLineItemStatus <> 1107) > 0
        BEGIN
            SET @ErrMessage = 'This product already add, please choose another product';
			THROW 60000, @ErrMessage,1;
        END
        ELSE 
        BEGIN
            UPDATE #lineItem SET
                soLineItemId = chk.soLineItemId
            FROM #chkItemExists chk
            WHERE chk.customerSkuId = #lineItem.customerSkuId
        END

		IF (SELECT COUNT(DISTINCT currency) FROM #lineItem) > 1
		BEGIN
			SET @ErrMessage = 'Items have different currency code';
			THROW 60000, @ErrMessage,1;
		END

		IF (SELECT COUNT(*) FROM #lineItem) > 0
		BEGIN

            IF (SELECT COUNT(1) FROM #lineItem WHERE ISNULL(soLineItemId,0) <> 0) = 0
            BEGIN
			    INSERT INTO soLineItem(soHeaderId, invId, customerSkuId, customerSku, soItemDesc, merchantSku, EAN, csCost, currencyCode, isItemPriceChanged, 
				    odrQty, poQty, shpQty, itemNote, soLineItemStatus, tagDivision, createBy, createDate)
			    SELECT odr.soHeaderId, odr.invId, odr.customerSkuId, odr.customerSku, odr.itemDesc, odr.merchantSku, odr.EAN, odr.itemCost, odr.currency, odr.isItemPriceChanged,
				    orderQty, odr.poQty, odr.shpQty, odr.itemNote, odr.lineItemStatus, odr.tagDivision, @createdBy, getdate()
			    FROM #lineItem odr
			    WHERE ISNULL(soLineItemId, 0) = 0
               
                SET @ErrMessage = ' created';
            END 
            ELSE
            BEGIN
                UPDATE li SET
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
			    FROM soLineItem li
				    INNER JOIN #lineItem odr
					    ON li.soLineItemId = odr.soLineItemId

                SET @ErrMessage = ' updated';
            END

            DECLARE @soHeaderid BIGINT = (SELECT TOP 1 soHeaderId FROM #lineItem);
            DECLARE @soStatus INT = (SELECT soStatus FROM soHeader WHERE soHeaderId = @soHeaderId);


			SET @ErrMessage = 'LineItems are successfully ' + @ErrMessage;

            IF @soStatus <> 1105
            BEGIN
			    UPDATE soHeader SET
				    lastUpdatedDate = getdate()
			    WHERE soHeaderId = @soHeaderId
            END

			SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage 	
		END
		ELSE
		BEGIN
			SET @ErrMessage = 'No rows being inserted.';

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
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

