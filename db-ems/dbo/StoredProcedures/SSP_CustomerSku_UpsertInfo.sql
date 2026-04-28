-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-09
-- Used By:		EMS -> Customer Module -> Add/ Update/ Delete Customer Sku

-- Description:	Add/ Update/ Delete customer sku

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-26   3.0         Zy Wong     Add carton material & qtyPerCarton
-- 2024-11-09	2.0			WL Leong	Remove validaion on duplicate check in the for update, Add tagDivision
-- 2024-05-09	1.0			ZY Wong		Initial version
-- =============================================
/*
select * from md_customersku where customerSKuId = 427
declare @Json VARCHAR(MAX), @userId INT = 1;
set @Json = N'{
	"customerSkuList": {
		"companyId": "11",
		"customerId": "26",
		"customerSkuId": "427",
		"invId": "603",
		"customerSku": "YZ5336278612003",
		"merchantSku": "669924991",
		"EAN": "9551020201461",
		"itemDesc": "YOUR ZONE TOY CHEST, WHITE",
		"currencyCode": "1121",
		"csCost": "4.2222",
		"feedStartDate": "2024-05-11",
		"feedingEndDate": "2024-05-11",
		"action": "Update",
		"division":"3232"
	}
}'

 EXEC [SSP_CustomerSku_UpsertInfo] @Json, @userId
set @Json = N'{"customerSkuList":[{"companyId":"11","customerId":"26","customerSkuId":36,"invId":"1","customerSku":"BH61100005302WH","merchantSku":"662606518","EAN":"9551020200006",
                "itemDesc":"","currencyCode":"1121","csCost":"49.2900","feedStartDate":"2024-05-09","feedingEndDate":"2024-05-09","action":"Update"}]}'


--set @Json = N'{"customerSkuList":[{"companyId":"11","customerId":"26","customerSkuId":"36","invId":null,"customerSku":null,"merchantSku":null,"EAN":null,
--                "itemDesc":null,"currencyCode":null,"csCost":null,"feedStartDate":null,"feedingEndDate":null,"action":"Delete"}]}'
EXEC [SSP_CustomerSku_UpsertInfo] @Json, @userId
select * from md_customersku where companyid = 11	and customerSku = 'BH61100005302WH' and customerid = 26
*/

CREATE PROCEDURE [dbo].[SSP_CustomerSku_UpsertInfo]
@Json NVARCHAR(MAX),
@userId INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
	BEGIN TRY

        DECLARE @ErrMessage VARCHAR(MAX);
        --declare @Json NVARCHAR(MAX)
        --declare @userId INT = 1
        --set @Json = N'{"customerSkuList":{"companyId":"4","customerId":"29","customerSkuId":"2661","invId":"3128","customerSku":"24461 WH","merchantSku":"24461 WH","itemDesc":"MS CORNER 6-CUBE STORAGE ORGANIZER","currencyCode":"1120","csCost":"0","feedStartDate":"2025-06-12","feedingEndDate":"2025-06-12","action":"Update","cartonMaterial":21136}}'


		DROP TABLE IF EXISTS #skuList;

		SELECT companyId, customerId, ISNULL(customerSkuId,0) as customerSkuId, invId, customerSku, merchantSku, ISNULL(EAN,'') as EAN, ISNULL(itemDesc,'') as itemDesc, 
            currencyCode, CASE WHEN ISNULL(csCost,'') = '' THEN '0.0000' ELSE CAST(csCost AS NUMERIC(18,4)) END as csCost, feedStartDate, feedingEndDate, actionType, 
            tagDivision, cartonMaterial, qtyPerCarton
		INTO #skuList
		FROM  OPENJSON(@Json, '$.customerSkuList') 
   			WITH (
				companyId INT					N'$.companyId',
				customerId INT					N'$.customerId',
                customerSkuId BIGINT            N'$.customerSkuId',
				invId BIGINT					N'$.invId',
				customerSku VARCHAR(30)			N'$.customerSku',
                merchantSku VARCHAR(30)			N'$.merchantSku',
                EAN VARCHAR(30)			        N'$.EAN',
                itemDesc VARCHAR(5000)          N'$.itemDesc',
				currencyCode VARCHAR(30)		N'$.currencyCode',
				csCost VARCHAR(20)				N'$.csCost',
				feedStartDate VARCHAR(10)		N'$.feedStartDate',
				feedingEndDate VARCHAR(10)		N'$.feedingEndDate',
                tagDivision INT		            N'$.division',
                cartonMaterial BIGINT           N'$.cartonMaterial',
                qtyPerCarton INT                N'$.qtyPerCarton',
				actionType VARCHAR(10)			N'$.action'
			)

		DECLARE @actionType VARCHAR(50);

		SELECT @actionType = actionType
		FROM #skuList

        IF @actionType IS NULL
        BEGIN
            SET @ErrMessage = 'Action Type is required.';
			THROW 60000, @ErrMessage, 1;
        END

        IF @actionType IN ('Add', 'Update')
        BEGIN
            IF (SELECT COUNT(1) FROM #skuList WHERE ISNULL(customerSku,'') = '') > 0
            BEGIN
                SET @ErrMessage = 'Customer Sku is compulsory.';
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM #skuList WHERE ISNULL(merchantSku,'') = '') > 0
            BEGIN
                SET @ErrMessage = 'Merchant Sku is compulsory.';
			    THROW 60000, @ErrMessage, 1;
            END

            -- combination (companyId + customerId + customerSku + merchantSku) = unique
            DROP TABLE IF EXISTS #checkSkuCombinationExists;

            SELECT sku.customerSkuId, l.customerSkuId as oriCustomerSkuId, l.customerSku, l.merchantSku
            INTO #checkSkuCombinationExists
            FROM #skuList l
                INNER JOIN md_CustomerSku sku
                    ON l.companyId = sku.companyId
                    AND l.customerId = sku.customerId
                    AND l.customerSku = sku.customerSku
                    AND l.merchantSku = sku.merchantSku
                    AND sku.statusflag = 1

            IF (SELECT COUNT(1) FROM #checkSkuCombinationExists WHERE customerSkuId IS NOT NULL AND customerSkuId <> oriCustomerSkuId) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Customer Sku ' + STRING_AGG(CONVERT(VARCHAR(MAX), customerSku + ' (Merchant Sku '+ merchantSku +')'), ', ')  + ' already exists in the system.' 
                                    FROM (SELECT DISTINCT customerSku, merchantSku 
                                            FROM #checkSkuCombinationExists
                                            WHERE customerSkuId IS NOT NULL
                                                AND customerSkuId <> oriCustomerSkuId)g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM #skuList WHERE ISNULL(cartonMaterial,0) <> 0 AND ISNULL(qtyPerCarton,0) <= 0) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Qty Per Carton is needed for Carton Material ' + STRING_AGG(CONVERT(VARCHAR(MAX), inventorySku), ', ') + '.'
                                    FROM (SELECT inventorySku FROM md_Inventory where invId IN 
                                            (SELECT DISTINCT cartonMaterial 
                                                FROM #skuList
                                                WHERE ISNULL(cartonMaterial,0) <> 0 
                                                    AND ISNULL(qtyPerCarton,0) <= 0)
                                          )g
                                    );
                THROW 60000, @ErrMessage, 1;
            END
        END

        UPDATE l SET 
            itemDesc = CASE WHEN l.itemDesc = '' THEN ( CASE WHEN ISNULL(inv.itemDesc,'') = '' THEN inv.productName ELSE inv.itemDesc END) ELSE l.itemDesc END
        FROM #skuList l
            INNER JOIN md_Inventory inv 
                ON l.companyId = inv.companyId
                AND l.invId = inv.invId
                AND inv.[status] = 1

        BEGIN TRANSACTION

            IF @actionType = 'Delete'
            BEGIN
                UPDATE sku SET
                    statusFlag = 0,
                    updateBy = @userId,
                    updateDateTime = getdate()
                FROM md_CustomerSku sku
                    INNER JOIN #skuList l
                        ON sku.customerskuId = l.customerSkuId

                SET @ErrMessage = 'deleted.'
            END

            IF @actionType = 'Update'
            BEGIN
                UPDATE sku SET 
                    customerSku = l.customerSku,
                    merchantSku = l.merchantSku,
                    EAN = l.EAN,
                    itemDesc = l.itemDesc,
                    csCost = l.csCost,
                    feedStartDate = l.feedStartDate,
                    feedingEndDate = l.feedingEndDate,
                    tagDivision = l.tagDivision,
                    cartonMaterial = l.cartonMaterial,
                    qtyPerCarton = l.qtyPerCarton,
                    updateBy = @userId,
                    updateDateTime = getdate()
                FROM md_CustomerSku sku
                    INNER JOIN #skuList l
                        ON sku.customerskuId = l.customerSkuId
 
                SET @ErrMessage = 'updated.'
            END

            IF @actionType = 'Add'
            BEGIN
                INSERT INTO md_CustomerSku (customerId, companyId, invId, customerSku, merchantSku, EAN, itemDesc, currencyCode, csCost, statusFlag, tagDivision, cartonMaterial, qtyPerCarton,
                    feedStartDate, feedingEndDate, enterBy, createDateTime, updateBy, updateDateTime)
                SELECT customerId, companyId, invId, customerSku, merchantSku, EAN, itemDesc, currencyCode, csCost, 1 as statusFlag, tagDivision, cartonMaterial, qtyPerCarton,
                    feedStartDate, feedingEndDate, @userId, getdate(), @userId, getdate()
                FROM #skuList

                SET @ErrMessage = 'added.'
            END

        COMMIT TRANSACTION

        SET @ErrMessage = 'Customer SKU is successfully ' + @ErrMessage;

		SELECT '_SUCCESS_' as status, @ErrMessage as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  
 
        IF @ErrMessage IS NULL 
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

