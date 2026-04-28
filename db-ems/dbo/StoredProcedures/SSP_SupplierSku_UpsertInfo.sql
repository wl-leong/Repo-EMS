-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-11-03
-- Description:	Keep supplierSku info related table to be updated
-- Used By:		

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-06-12   4.0         WL Leong    Add in supplierSKuId in json and simplify update/delete 
-- 2024-06-10   3.0         ZY Wong     Add validation for different currency with supplier
-- 2024-02-07	2.0			ZY Wong		Update lrLineItem ** removed
-- 2023-11-03	1.0			ZY Wong		Initial version
-- =============================================
/*
 EXEC  [SSP_SupplierSku_UpsertInfo] 
	--N'{"supplierSkuList":[{"companyId":"4","supplierId":"29","invId":"608","supplierSku":"MDF.C2.2.30","currencyCode":"1120","supCost":"27.12","moq":"1","isDefault":"0","action":"DeleteSupplierSku"}]}'
	N'{"supplierSkuList":[{"companyId":"4","supplierId":"4","invId":"605","supplierSku":"qwtyuio","currencyCode":"1120","supCost":"12.00","moq":"555555","isDefault":"1","action":"UpdateSupplierSku"}]}'

	, 1
*/
CREATE PROCEDURE [dbo].[SSP_SupplierSku_UpsertInfo]
@Json VARCHAR(MAX),
@updateBy INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
BEGIN TRY
	BEGIN TRANSACTION
		
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"supplierSkuList":[{
		--		"companyId":"4",
		--		"supplierId":"29",
		--		"invId":"608",
		--		"supplierSku":"MDF.C2.2.30",
  --            "itemDesc":"testing",
		--		"currencyCode":"1120",
		--		"supCost":"27.12",
		--		"moq":"1",
		--		"isDefault":"0",
		--		"action":"DeleteSupplierSku"
		--		}]}',
		--	@updateBy INT = 1;

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #skuList;

		SELECT supplierSkuId, companyId, supplierId, invid, supplierSku, currencyCode, supCost, moq, isDefault, itemDesc, actionType
		INTO #skuList
		FROM  OPENJSON(@Json, '$.supplierSkuList') 
   			WITH (
                supplierSkuId BIGINT			N'$.supplierSkuId',
				companyId INT					N'$.companyId',
				supplierId INT					N'$.supplierId',
				invId BIGINT					N'$.invId',
				supplierSku VARCHAR(30)			N'$.supplierSku',
				currencyCode INT        		N'$.currencyCode',
				supCost NUMERIC(14,4)			N'$.supCost',
				moq INT							N'$.moq',
				isDefault INT					N'$.isDefault',
                itemDesc VARCHAR(5000)          N'$.itemDesc',
				actionType VARCHAR(50)			N'$.action'
			)

		DECLARE @actionType VARCHAR(50), @supplierId INT, @currencyCode INT, @skuCurrency VARCHAR(3), @supplierCurrency VARCHAR(3);

		SELECT @actionType = actionType, @supplierId = supplierId, @currencyCode = currencyCode
		FROM #skuList

        SET @skuCurrency = (SELECT categoryName FROM md_MasterCategory WHERE categoryId = @currencyCode AND [status] = 1);
        SET @supplierCurrency = (SELECT cr.categoryName 
                                    FROM md_MasterCategory cr
                                        INNER JOIN md_Supplier s
                                            ON cr.categoryId = s.currencyCode
                                            AND cr.[status] = 1
                                    WHERE s.supplierId = @supplierId);

        -- check supplier currency setup
        IF @supplierCurrency IS NULL
        BEGIN
            SET @ErrMessage = 'Supplier''s currency is not yet setup in the system.';
			THROW 60000, @ErrMessage, 1;
        END

        -- check currency different
        IF (@skuCurrency <> @supplierCurrency) 
        BEGIN
            SET @ErrMessage = 'Currency is different with supplier''s currency (' + @supplierCurrency + ').';
			THROW 60000, @ErrMessage, 1;
        END


		IF @actionType = 'AddSupplierSku'
		BEGIN
			-- same company & same supplier not allow duplicate
			DROP TABLE IF EXISTS #checkSkuDuplicate;

			SELECT sk.supplierSku, sk.statusFlag
			INTO #checkSkuDuplicate
			FROM md_SupplierSku sk
				INNER JOIN #skuList l
					ON sk.supplierSku = l.supplierSku
					AND sk.supplierId = l.supplierId
					AND sk.invId = l.invId
					AND sk.companyId = l.companyId
            WHERE sk.statusFlag = 1

			IF (SELECT COUNT(1) FROM #checkSkuDuplicate) > 0
			BEGIN 
 
				SET @ErrMessage = (SELECT TOP 1 'Supplier Sku ' + supplierSku + ' already exists in system.'
                                   FROM #checkSkuDuplicate);
				THROW 60000, @ErrMessage, 1;
			END
            ELSE
			BEGIN
				INSERT INTO md_SupplierSku (companyId, supplierId, invId, supplierSku, itemDesc, currencyCode, supCost, moq, isDefault, statusFlag, enterBy, createDateTime, updateBy, updateDateTime)
				SELECT companyId, supplierId, invId, supplierSku, itemDesc, currencyCode, supCost, moq, isDefault, 1 as statusFlag, @updateBy, getdate(), @updateBy, getdate()
				FROM #skuList
 						
				SET @ErrMessage = 'Supplier Sku is successfully added.'
			END
		END
        
        IF @actionType = 'UpdateSupplierSku'
		BEGIN	
			UPDATE sku SET
				supplierSku = chk.supplierSku,
                itemDesc = chk.itemDesc,
				supCost = chk.supCost,
				moq = chk.moq,
				isDefault = chk.isDefault,
				updateBy = @updateBy,
				updateDateTime = getdate()
			FROM md_SupplierSku sku
				INNER JOIN #skuList chk
					ON sku.supplierSkuId = chk.supplierSkuId
 						
			SET @ErrMessage = 'Supplier Sku is successfully updated.';
			
		END

		IF @actionType = 'DeleteSupplierSku'
		BEGIN
 			UPDATE sku SET
				statusFlag = 0,
				updateBy = @updateBy,
				updateDateTime = getdate()
			FROM md_SupplierSku sku
				INNER JOIN #skuList chk
                    ON sku.supplierSkuId = chk.supplierSkuId
		
			SET @ErrMessage = 'Supplier Sku is successfully deleted.'
		END

		SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH	
	
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @ErrMessage as returnMessage

	END CATCH
END

GO

