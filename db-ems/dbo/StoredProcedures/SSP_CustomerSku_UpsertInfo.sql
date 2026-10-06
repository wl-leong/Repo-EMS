-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-05-09
-- Used By:		EMS -> Customer Module -> Add/ Update/ Delete Customer Sku

-- Description:	Add/ Update/ Delete customer sku

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-09-04	4.0			ZY Wong		Remove carton material & qtyPerCarton & feedStartDate & feedEndDate, improve validation
-- 2025-08-26   3.0         Zy Wong     Add carton material & qtyPerCarton
-- 2024-11-09	2.0			WL Leong	Remove validaion on duplicate check in the for update, Add tagDivision
-- 2024-05-09	1.0			ZY Wong		Initial version
-- =============================================
/*
select * from md_customersku where customerSKuId in (427,595)
declare @Json VARCHAR(MAX), @userId INT = 1;
set @Json = N'{
	"customerSkuList": {
		"companyId": "11",
		"customerId": "26",
		"customerSkuId": "595",
		"invId": "603",
		"customerSku": "YZ5336278612003",
		"merchantSku": "669924991",
		"EAN": "9551020201461",
		"itemDesc": "YOUR ZONE TOY CHEST, WHITE",
		"currencyCode": "1121",
		"csCost": "4.2222",
		"action": "Update",
		"division":"3232"
	}}'

EXEC [SSP_CustomerSku_UpsertInfo] @Json, @userId
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

		SELECT companyId, customerId, customerSkuId, invId, customerSku, merchantSku, ISNULL(EAN,'') as EAN, ISNULL(itemDesc,'') as itemDesc, 
            currencyCode, CASE WHEN ISNULL(csCost,'') = '' THEN '0.0000' ELSE CAST(csCost AS NUMERIC(18,4)) END as csCost, tagDivision, actionType            
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
				tagDivision INT		            N'$.division',
				actionType VARCHAR(10)			N'$.action'
			)

		DECLARE @companyId INT, @customerId INT, @customerSkuId BIGINT, @invId BIGINT, @customerSku VARCHAR(30), @merchantSku VARCHAR(30), @EAN VARCHAR(30), @itemDesc VARCHAR(5000),
			@currencyCode VARCHAR(30), @csCost VARCHAR(20), @tagDivision INT, @actionType VARCHAR(50);

		SELECT @companyId = companyId, @customerId = customerId, @customerSkuId = customerSkuId, @invId = invId, @customerSku = customerSku, @merchantSku = merchantSku, @EAN = EAN, @itemDesc = itemDesc,
			@currencyCode = currencyCode, @csCost = csCost, @tagDivision = tagDivision, @actionType = actionType
		FROM #skuList

		-- check missing actionType
        IF @actionType IS NULL
        BEGIN
            SET @ErrMessage = '[System Error] Action Type is required.';
			THROW 60000, @ErrMessage, 1;
        END

		-- check missing companyId
		IF @companyId IS NULL
		BEGIN
			SET @ErrMessage = '[System Error] Company ID is required.';
			THROW 60000, @ErrMessage, 1;
		END

		-- check missing customerId
		IF @customerId IS NULL
		BEGIN
			SET @ErrMessage = '[System Error] Customer ID is required.';
			THROW 60000, @ErrMessage, 1;
		END

		-- check missing customerSku
        IF @customerSku IS NULL
        BEGIN
            SET @ErrMessage = 'Customer Sku is compulsory. Please enter Customer Sku.';
			THROW 60000, @ErrMessage, 1;
        END

		-- check missing merchantSku
        IF @merchantSku IS NULL
        BEGIN
            SET @ErrMessage = 'Merchant Sku is compulsory. Please enter Merchant Sku.';
			THROW 60000, @ErrMessage, 1;
        END

		IF @actionType = 'Add'
		BEGIN
			-- combination (companyId + customerId + customerSku + merchantSku) = unique
			-- check unqiue combination duplicates
            IF EXISTS (
				SELECT 1 FROM md_CustomerSku
				WHERE companyId = @companyId
					AND customerId = @customerId
					AND customerSku = @customerSku
					AND merchantSku = @merchantSku
					AND statusflag = 1
			)
            BEGIN
                SET @ErrMessage = 'Customer Sku ' + @customerSku + ' (Merchant Sku '+ @merchantSku +') already exists in the system. Please enter a valid Customer Sku/ Merchant Sku.';
                THROW 60000, @ErrMessage, 1;
            END
		END

        IF @actionType IN ('Add', 'Update')
        BEGIN
			-- check missing invId
			IF @invId IS NULL
			BEGIN
				SET @ErrMessage = '[System Error] Inv ID is required.';
				THROW 60000, @ErrMessage, 1;
			END

			-- update empty itemDesc
			IF ISNULL(@itemDesc,'') = ''
			BEGIN
				SET @itemDesc = (SELECT CASE WHEN ISNULL(itemDesc,'') = '' THEN productName ELSE itemDesc END
									FROM md_Inventory 
									WHERE companyId = @companyId
										AND invId = @invId
										AND [status] = 1);
			END

			-- check missing currency
			IF @currencyCode IS NULL
            BEGIN
                SET @ErrMessage = 'Currency Code is compulsory. Please enter Currency Code.';
			    THROW 60000, @ErrMessage, 1;
            END

			-- check missing tagDivision
			IF @tagDivision IS NULL
            BEGIN
                SET @ErrMessage = 'Tag Division is compulsory. Please enter Tag Division.';
			    THROW 60000, @ErrMessage, 1;
            END
        END

		IF @actionType IN ('Update', 'Delete')
		BEGIN
			-- check missing customerSkuId
			IF @customerSkuId IS NULL
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku ID is required.';
				THROW 60000, @ErrMessage, 1;
			END

			-- check invalid customerSkuId
			IF NOT EXISTS (
				SELECT 1 FROM md_CustomerSku
				WHERE customerSkuId = @customerSkuId
			)
			BEGIN
				SET @ErrMessage = '[System Error] Customer Sku ID ' + CAST(@customerSkuId as VARCHAR) + ' not found in the system.';
				THROW 60000, @ErrMessage, 1;
			END 

			-- check customerSku status
			IF (SELECT statusFlag FROM md_CustomerSku WHERE customerSkuId = @customerSkuId) = 0
			BEGIN
				SET @ErrMessage = 'No active Customer Sku records found in the system.';
				THROW 60000, @ErrMessage, 1;				
			END
		END

		IF @actionType = 'Update'
		BEGIN
			-- check unqiue combination duplicates to update
			-- exclude existing customerSkuId
			IF EXISTS (
				SELECT 1 FROM md_CustomerSku
				WHERE companyId = @companyId
					AND customerId = @customerId
					AND customerSku = @customerSku
					AND merchantSku = @merchantSku
					AND statusflag = 1
					AND customerSkuId <> @customerSkuId
			)
            BEGIN
                SET @ErrMessage = 'Customer Sku ' + @customerSku + ' (Merchant Sku '+ @merchantSku +') already exists in the system. Please enter a valid Customer Sku/ Merchant Sku.';
                THROW 60000, @ErrMessage, 1;
            END
		END

        BEGIN TRANSACTION

            IF @actionType = 'Delete'
            BEGIN
                UPDATE md_CustomerSku SET
                    statusFlag = 0,
                    updateBy = @userId,
                    updateDateTime = GETDATE()
                WHERE customerSkuId = @customerSkuId

                SET @ErrMessage = 'deleted.'
            END

            IF @actionType = 'Update'
            BEGIN
                UPDATE md_CustomerSku SET 
                    customerSku = @customerSku,
                    merchantSku = @merchantSku,
                    EAN = @EAN,
                    itemDesc = @itemDesc,
                    csCost = @csCost,
                    tagDivision = @tagDivision,
                    updateBy = @userId,
                    updateDateTime = GETDATE()
                WHERE customerSkuId = @customerSkuId
 
                SET @ErrMessage = 'updated.'
            END

            IF @actionType = 'Add'
            BEGIN
                INSERT INTO md_CustomerSku (customerId, companyId, invId, customerSku, merchantSku, EAN, itemDesc, currencyCode, csCost, statusFlag, tagDivision, 
                    feedStartDate, feedingEndDate, enterBy, createDateTime, updateBy, updateDateTime)
                SELECT @customerId, @companyId, @invId, @customerSku, @merchantSku, @EAN, @itemDesc, @currencyCode, @csCost, 1 as statusFlag, @tagDivision, 
                    GETDATE(), GETDATE(), @userId, GETDATE(), @userId, GETDATE()

                SET @ErrMessage = 'added.'
            END

        COMMIT TRANSACTION

        SET @ErrMessage = 'Customer Sku is successfully ' + @ErrMessage;

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