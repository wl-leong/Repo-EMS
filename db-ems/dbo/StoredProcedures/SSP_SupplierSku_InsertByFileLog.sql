-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-06-20
-- Used By:	    EMS -> Supplier Module -> Import Supplier Sku

-- Description : 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-26   2.0         ZY Wong     Remove validation of supplierCost, convert to 0 if pass in empty/null
-- 2024-06-20	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- EXEC [SSP_SupplierSku_InsertByFileLog] 11, '20240621024238_SupplierSkuUpload_Template.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_SupplierSku_InsertByFileLog]
@companyId INT,
@fileLoaded VARCHAR(150),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
        
        --DECLARE @companyId INT = 11, @fileLoaded VARCHAR(150) = '20240621024238_SupplierSkuUpload_Template.xlsx', @userId INT = '1';

        DECLARE @ErrMessage VARCHAR(MAX);

        DROP TABLE IF EXISTS #tempSupSku;

        SELECT companyId, supplierName, inventorySku, supplierSku, ISNULL(itemDesc,'') as itemDesc, currencyCode, CONVERT(FLOAT, supplierCost) as supplierCost, MOQ, isDefault
        INTO #tempSupSku
        FROM temp_supplierSkuLog
        WHERE fileLoaded = @fileLoaded
            AND companyId = @companyId
            AND (ISNULL(supplierName,'') <> '' AND ISNULL(inventorySku,'') <> '') -- ignore empty row

        ALTER TABLE #tempSupSku ADD supplierId INT;
        ALTER TABLE #tempSupSku ADD supCurrency VARCHAR(3);
        ALTER TABLE #tempSupSku ADD invId BIGINT;
        ALTER TABLE #tempSupSku ADD supplierSkuId BIGINT;
        ALTER TABLE #tempSupSku ADD currency INT;


/*** Start: data validation ***/
            
        IF (SELECT COUNT(1) FROM #tempSupSku WHERE ISNULL(supplierName,'') = '' 
                OR ISNULL(inventorySku,'') = ''
                OR ISNULL(supplierSku,'') = ''
                OR ISNULL(currencyCode,'') = ''                
                OR ISNULL(MOQ,'') = ''
                OR ISNULL(isDefault,'') = '') > 0
        BEGIN
            SET @ErrMessage = 'Supplier Name/ Inventory Sku/ Supplier Sku/ Currency Code/ MOQ/ Is Default are compulsory.';
			THROW 60000, @ErrMessage, 1;
        END

   --     IF (SELECT COUNT(1) FROM #tempSupSku WHERE ISNUMERIC(supplierCost) = 0 OR supplierCost <= 0 
   --         OR ISNUMERIC(MOQ) = 0 OR MOQ <= 0) > 0
   --     BEGIN
   --         SET @ErrMessage = 'Invalid Customer Cost, not a positive numeric value.';
			--THROW 60000, @ErrMessage, 1;
   --     END

        IF (SELECT COUNT(1) FROM #tempSupSku WHERE isDefault NOT IN ('YES','NO')) > 0
        BEGIN
            SET @ErrMessage = 'Invalid Is Default. [YES, NO]';
			THROW 60000, @ErrMessage, 1;
        END

        UPDATE #tempSupSku SET
            isDefault = CASE WHEN isDefault = 'YES' THEN 1 
                             WHEN isDefault = 'NO' THEN 0 END

        UPDATE t SET 
            supplierId = sup.supplierId,
            supCurrency = cr.categoryName
        FROM #tempSupSku t
            INNER JOIN md_Supplier sup 
                ON t.companyId = sup.companyId
                AND t.supplierName = sup.supplierCompanyName
                AND sup.[status] = 1
            INNER JOIN md_MasterCategory cr
                ON sup.currencyCode = cr.categoryId
                AND cr.categoryParentId = 1119

        IF (SELECT COUNT(1) FROM #tempSupSku WHERE supplierId IS NULL) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Supplier ' + STRING_AGG(CONVERT(VARCHAR(max), supplierName), ',')  + ' not found in the system.'
                                FROM (  SELECT DISTINCT supplierName 
                                        FROM #tempSupSku 
                                        WHERE supplierId IS NULL
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        UPDATE t SET 
            invId = inv.invId,
            itemDesc = CASE WHEN t.itemDesc = '' THEN ( CASE WHEN ISNULL(inv.itemDesc,'') = '' THEN inv.productName ELSE inv.itemDesc END) ELSE t.itemDesc END
        FROM #tempSupSku t
            INNER JOIN md_Inventory inv 
                ON t.companyId = inv.companyId
                AND t.inventorySku = inv.inventorySku
                AND inv.[status] = 1

        IF (SELECT COUNT(1) FROM #tempSupSku WHERE invId IS NULL) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Inventory Sku ' + STRING_AGG(CONVERT(VARCHAR(max), inventorySku), ',')  + ' not found in the system.'
                                FROM (  SELECT DISTINCT inventorySku 
                                        FROM #tempSupSku 
                                        WHERE invId IS NULL
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        DROP TABLE IF EXISTS #checkSkuAssigned;

        SELECT t.inventorySku
        INTO #checkSkuAssigned
        FROM #tempSupSku t
            INNER JOIN md_SupplierSku sku
                ON t.companyId = sku.companyId
                AND t.supplierId = sku.supplierId
                AND t.invId = sku.invId
                AND sku.statusflag = 1

        IF (SELECT COUNT(1) FROM #checkSkuAssigned) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Inventory Sku ' + STRING_AGG(CONVERT(VARCHAR(max), inventorySku), ',')  + ' already have Supplier Sku assigned.'
                                FROM (  SELECT DISTINCT inventorySku 
                                        FROM #checkSkuAssigned 
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        DROP TABLE IF EXISTS #checkSkuCombinationExists;

        SELECT t.supplierSku
        INTO #checkSkuCombinationExists
        FROM #tempSupSku t
            INNER JOIN md_SupplierSku sku
                ON t.companyId = sku.companyId
                AND t.supplierId = sku.supplierId
                AND t.supplierSku = sku.supplierSku
                AND sku.statusflag = 1

        IF (SELECT COUNT(1) FROM #checkSkuCombinationExists) > 0
        BEGIN
            SET @ErrMessage = (SELECT 'Supplier Sku ' + STRING_AGG(CONVERT(VARCHAR(max), supplierSku), ',')  + ' already exists in the system.' 
                                FROM (SELECT DISTINCT supplierSku 
                                        FROM #checkSkuCombinationExists)g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        UPDATE t SET
            currency = cr.categoryId
        FROM #tempSupSku t
            INNER JOIN md_MasterCategory cr
                ON t.currencyCode = cr.categoryName
                AND cr.categoryParentId = 1119  --currency code

        IF (SELECT COUNT(1) FROM #tempSupSku WHERE currency IS NULL) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Currency Code ' + STRING_AGG(CONVERT(VARCHAR(max), currencyCode), ',')  + ' not configured in the system.'
                                FROM (  SELECT currencyCode 
                                        FROM #tempSupSku 
                                        WHERE currency IS NULL
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END

        -- check currency different
        IF (SELECT COUNT(1) FROM #tempSupSku WHERE supCurrency <> currencyCode) > 0
        BEGIN
            SET @ErrMessage =   (SELECT 'Currency Code ' + currencyCode  + ' is different with supplier''s currency (' + supCurrency + ').'
                                FROM (  SELECT TOP 1 supCurrency, currencyCode 
                                        FROM #tempSupSku 
                                        WHERE supCurrency <> currencyCode
                                    )g 
                                );
            THROW 60000, @ErrMessage, 1;
        END
            
/*** End: data validation ***/

        BEGIN TRANSACTION

            INSERT INTO md_SupplierSku (invId, supplierId, companyId, supplierSku, itemDesc, currencyCode, supCost, moq, isDefault, statusFlag, createDateTime, enterBy, updateDateTime, updateBy)
            SELECT invId, supplierId, companyId, supplierSku, itemDesc, currency, supplierCost, MOQ, isDefault, 1 as statusFlag, cast(getdate() as date), @userId, getdate(), @userId
            FROM #tempSupSku

		COMMIT TRANSACTION

        DELETE FROM temp_supplierSkuLog WHERE fileLoaded = @fileLoaded AND companyId = @companyId

		SELECT '_SUCCESS_' as status, 'Supplier Sku has been successful import.' as returnMessage
				
		RETURN 0
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
 
        DELETE FROM temp_supplierSkuLog WHERE fileLoaded = @fileLoaded AND companyId = @companyId

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

