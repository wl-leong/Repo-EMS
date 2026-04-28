-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-04-22
-- Used By:	    EMS -> Customer Module -> Import Customer Sku

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-26   2.0         ZY Wong     Remove validation of customerCost, convert to 0 if pass in empty/null
-- 2024-04-22	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_CustomerSku_InsertByFileLog] 11, '20240619095009_CustomerSkuUpload_Template (1).xlsx', 1
CREATE PROCEDURE [dbo].[SSP_CustomerSku_InsertByFileLog]
@companyId INT,
@fileLoaded VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
				
            --DECLARE @companyId INT = 4, @fileLoaded VARCHAR(150) = '20241010142751_CustomerSkuUpload_20241010_test.xlsx', @userId INT = '1';

            DECLARE @ErrMessage VARCHAR(MAX);

            IF ISNULL(@companyId,0) = 0 
            BEGIN
                SET @ErrMessage = '[System Error] Company Id is required.';
                THROW 60000, @ErrMessage, 1;
            END

            IF ISNULL(@userId,0) = 0 
            BEGIN
                SET @ErrMessage = '[System Error] User Id is required.';
                THROW 60000, @ErrMessage, 1;
            END

            DROP TABLE IF EXISTS #tempCsSku;

            SELECT companyId, customerName, inventorySku, customerSku, merchantSku, ISNULL(EAN,'') as EAN, ISNULL(itemDesc,'') as itemDesc, currencyCode, CONVERT(FLOAT, customerCost) as customerCost
            INTO #tempCsSku
            FROM temp_customerSkuLog
            WHERE fileLoaded = @fileLoaded
                AND companyId = @companyId
                AND (ISNULL(customerName,'') <> '' AND ISNULL(inventorySku,'') <> '') -- ignore empty row

            ALTER TABLE #tempCsSku ADD customerId INT;
            ALTER TABLE #tempCsSku ADD invId BIGINT;
            ALTER TABLE #tempCsSku ADD customerSkuId BIGINT;
            ALTER TABLE #tempCsSku ADD currency INT;

/*** Start: data validation ***/
            
            IF (SELECT COUNT(1) FROM #tempCsSku WHERE ISNULL(customerName,'') = '' 
                    OR ISNULL(inventorySku,'') = ''
                    OR ISNULL(customerSku,'') = ''
                    OR ISNULL(merchantSku,'') = ''
                    OR ISNULL(currencyCode,'') = '') > 0
            BEGIN
                SET @ErrMessage = 'Customer Name/ Inventory Sku/ Customer Sku/ Merchant Sku/ Currency Code are compulsory.';
			    THROW 60000, @ErrMessage, 1;
            END

       --     IF (SELECT COUNT(1) FROM #tempCsSku WHERE ISNUMERIC(customerCost) = 0 OR customerCost <= 0 ) > 0
       --     BEGIN
       --         SET @ErrMessage = 'Invalid Customer Cost, not a positive numeric value.';
			    --THROW 60000, @ErrMessage, 1;
       --     END

            UPDATE t SET 
                customerId = cs.customerId
            FROM #tempCsSku t
                INNER JOIN md_Customer cs 
                    ON t.companyId = cs.companyId
                    AND t.customerName = cs.customerName
                    AND cs.[status] = 1

            IF (SELECT COUNT(1) FROM #tempCsSku WHERE customerId IS NULL) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Customer ' + STRING_AGG(CONVERT(VARCHAR(max), customerName), ',')  + ' not found in the system.'
                                    FROM (  SELECT DISTINCT customerName 
                                            FROM #tempCsSku 
                                            WHERE customerId IS NULL
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            UPDATE t SET 
                invId = inv.invId,
                itemDesc = CASE WHEN t.itemDesc = '' THEN ( CASE WHEN ISNULL(inv.itemDesc,'') = '' THEN inv.productName ELSE inv.itemDesc END) ELSE t.itemDesc END
            FROM #tempCsSku t
                INNER JOIN md_Inventory inv 
                    ON t.companyId = inv.companyId
                    AND t.inventorySku = inv.inventorySku
                    AND inv.[status] = 1

            IF (SELECT COUNT(1) FROM #tempCsSku WHERE invId IS NULL) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Inventory Sku ' + STRING_AGG(CONVERT(VARCHAR(max), inventorySku), ',')  + ' not found in the system.'
                                    FROM (  SELECT DISTINCT inventorySku 
                                            FROM #tempCsSku 
                                            WHERE invId IS NULL
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            -- check duplicate customerSku with same merchantSku in same file
            DROP TABLE IF EXISTS #checkSkuDuplicate;

            SELECT customerSku, merchantSku, COUNT(*) as counts
            INTO #checkSkuDuplicate
            FROM #tempCsSku
            GROUP BY customerSku, merchantSku
            HAVING COUNT(*) > 1

            IF (SELECT COUNT(1) FROM #checkSkuDuplicate) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Customer Sku ' + STRING_AGG(CONVERT(VARCHAR(max), customerSku + ' (Merchant Sku '+ merchantSku +')'), ', ')  + ' are duplicate in same file.'
                                    FROM (  SELECT DISTINCT customerSku, merchantSku 
                                            FROM #checkSkuDuplicate 
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            -- allow multiple customerSku for 1 invId
            -- check customer sku exists (companyId + customerId + customerSku + merchantSku = unique)
            DROP TABLE IF EXISTS #checkSkuCombinationExists;

            SELECT sku.customerSkuId, l.customerSku, l.merchantSku
            INTO #checkSkuCombinationExists
            FROM #tempCsSku l
                INNER JOIN md_CustomerSku sku
                    ON l.companyId = sku.companyId
                    AND l.customerId = sku.customerId
                    AND l.customerSku = sku.customerSku
                    AND l.merchantSku = sku.merchantSku
                    AND sku.statusflag = 1

            IF (SELECT COUNT(1) FROM #checkSkuCombinationExists WHERE customerSkuId IS NOT NULL) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Customer Sku ' + STRING_AGG(CONVERT(VARCHAR(max), customerSku + ' (Merchant Sku '+ merchantSku +')'), ', ')  + ' already exists in the system.' 
                                    FROM (SELECT DISTINCT customerSku, merchantSku 
                                            FROM #checkSkuCombinationExists
                                            WHERE customerSkuId IS NOT NULL)g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

            UPDATE t SET
                currency = cr.categoryId
            FROM #tempCsSku t
                INNER JOIN md_MasterCategory cr
                    ON t.currencyCode = cr.categoryName
                    AND cr.categoryParentId = 1119  --currency code

            IF (SELECT COUNT(1) FROM #tempCsSku WHERE currency IS NULL) > 0
            BEGIN
                SET @ErrMessage =   (SELECT 'Currency Code ' + STRING_AGG(CONVERT(VARCHAR(max), currencyCode), ',')  + ' not configured in the system.'
                                    FROM (  SELECT currencyCode 
                                            FROM #tempCsSku 
                                            WHERE currency IS NULL
                                        )g 
                                    );
                THROW 60000, @ErrMessage, 1;
            END

/*** End: data validation ***/

        BEGIN TRANSACTION

            INSERT INTO md_CustomerSku (invId, customerId, companyId, customerSku, merchantSku, itemDesc, currencyCode, csCost, EAN, statusFlag, feedStartDate, feedingEndDate, enterBy, createDateTime, updateBy, updateDateTime)
            SELECT invId, customerId, companyId, customerSku, merchantSku, itemDesc, currency, customerCost, EAN, 1 as statusFlag, cast(getdate() as date), cast(getdate() as date), @userId, getdate(), @userId, getdate()
            FROM #tempCsSku

		COMMIT TRANSACTION

        DELETE FROM temp_customerSkuLog WHERE fileLoaded = @fileLoaded AND companyId = @companyId

		SELECT '_SUCCESS_' as status, 'Customer Sku has been successful import.' as returnMessage
				
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        DELETE FROM temp_customerSkuLog WHERE fileLoaded = @fileLoaded AND companyId = @companyId

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

