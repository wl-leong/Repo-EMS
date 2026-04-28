-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-09-23
-- Description:	Load inventory list from dump 
-- Used By:		Inventory Module > Import Product
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-05   4.0         ZY Wong     Add validation check generated product name exists in system
-- 2025-01-14   3.0         ZY Wong     Add validation check warehouse exists
-- 2024-10-21   2.0         ZY Wong     For insert md_inventory empty description use productName
-- 2024-10-14   1.1         ZY Wong     Add generate itemCode, prepare attributes, generate productName
-- 2024-09-23   1.0         ZY Wong     Initial version
-- =============================================
-- EXEC [SSP_Inventory_InsertProduct] 4, '20241016064524_ProductTemplate_FNP_FinishedGood_fromProd.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_Inventory_InsertProduct] 
@companyId INT,
@fileName VARCHAR(150),
@userId INT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

	BEGIN TRY
		
		--DECLARE @fileName VARCHAR(150) = '20250505150436_ProductTemplate.xlsx', @companyId INT = 4, @userId INT = 1
		
		DECLARE @ErrMessage VARCHAR(MAX);

        -- check warehouse configured
        DECLARE @warehouseId BIGINT = (SELECT TOP 1 warehouseId FROM md_Warehouse WHERE companyId = @companyId AND status = 1);

        IF @warehouseId IS NULL
        BEGIN
        	SET @ErrMessage = 'Warehouse is not configured in system.';
			THROW 60000, @ErrMessage, 1;
        END

		DROP TABLE IF EXISTS #invDump;
  
		SELECT logId, UPPER(productCategory) as productCategory, UPPER(productSubCategory) as productSubCategory, UPPER(productType) as productType, 
            CASE WHEN ISNULL(itemCode, '') = '' THEN '0' ELSE itemCode END as itemCode, 
            UPPER(modelNo) as modelNo, UPPER(inventorySKU) as inventorySKU, CAST('' as NVARCHAR(255)) as productName, productPrice, UPPER([description]) as [description], 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight,
			cbm, measurement, UPPER(glCode) as glCode, virtualProduct,
            UPPER(attributeName_1) as attributeName_1, UPPER(attributeValue_1) as attributeValue_1, 
            UPPER(attributeName_2) as attributeName_2, UPPER(attributeValue_2) as attributeValue_2, 
            UPPER(attributeName_3) as attributeName_3, UPPER(attributeValue_3) as attributeValue_3, 
            UPPER(attributeName_4) as attributeName_4, UPPER(attributeValue_4) as attributeValue_4, 
            UPPER(attributeName_5) as attributeName_5, UPPER(attributeValue_5) as attributeValue_5, 
            UPPER(attributeName_6) as attributeName_6, UPPER(attributeValue_6) as attributeValue_6, 
            UPPER(attributeName_7) as attributeName_7, UPPER(attributeValue_7) as attributeValue_7, 
            UPPER(attributeName_8) as attributeName_8, UPPER(attributeValue_8) as attributeValue_8, 
            UPPER(attributeName_9) as attributeName_9, UPPER(attributeValue_9) as attributeValue_9, 
            UPPER(attributeName_10) as attributeName_10, UPPER(attributeValue_10) as attributeValue_10
		INTO #invDump
		FROM temp_inventoryLog
		WHERE fileName =  @fileName
            AND (ISNULL(productCategory,'') <> '' OR ISNULL(productSubCategory,'') <> '' OR ISNULL(productType,'') <> '')  --ignore empty line

/*** Start: data validation ***/
/*** insert product sp, if itemcode passed in then validate, if no pass in then use system generate itemcode ***/
/*** product name ALL use system generate ***/

        DROP TABLE IF EXISTS #checkDupItemCode;

        SELECT itemCode, COUNT(itemCode) as itemCodeCount 
        INTO #checkDupItemCode
        FROM #invDump 
        WHERE itemCode <> '0'  --except null
        GROUP BY itemCode

		IF (SELECT COUNT(1) FROM #checkDupItemCode  WHERE itemCodeCount > 1) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Item Code ' + STRING_AGG(CONVERT(VARCHAR(max), itemCode), ', ') + ' are duplicate in file.' 
                                FROM (SELECT itemCode 
                                        FROM #checkDupItemCode  
                                        WHERE itemCodeCount > 1)g
                                );
			THROW 60000, @ErrMessage, 1;
		END

        DROP TABLE IF EXISTS #checkExistsItemCode;

		SELECT invId, i.itemCode
		INTO #checkExistsItemCode
		FROM md_Inventory inv
			INNER JOIN #invDump i
				ON inv.itemCode = i.itemCode

		IF (SELECT COUNT(1) FROM #checkExistsItemCode) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Item Code ' + STRING_AGG(CONVERT(VARCHAR(max), itemCode), ', ') + ' already exists in system.' 
                                FROM #checkExistsItemCode
                                );
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productCategory,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Product Category is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productSubCategory,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Product Sub Category is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productType,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Product Type is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(modelNo,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Model No is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(inventorySKU,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Inventory Sku is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END	

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(grossWeight,'') = '' OR ISNULL(grossLength,'') = '' OR ISNULL(grossWidth,'') = '' OR ISNULL(grossWeight,'') = '') > 0			
		BEGIN
			SET @ErrMessage = 'Gross Weight/ Length/ Width/ Height are compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNUMERIC(grossWeight) = 0 OR ISNUMERIC(grossLength) = 0 OR ISNUMERIC(grossWidth) = 0 OR ISNUMERIC(grossWeight) = 0) > 0			
		BEGIN
			SET @ErrMessage = 'Invalid Gross Weight/ Length/ Width/ Height, not a numeric value.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(netWeight,'') = '' OR ISNULL(netLength,'') = '' OR ISNULL(netWidth,'') = '' OR ISNULL(netWeight,'') = '') > 0			
		BEGIN
			SET @ErrMessage = 'Net Weight/ Length/ Width/ Height are compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNUMERIC(netWeight) = 0 OR ISNUMERIC(netLength) = 0 OR ISNUMERIC(netWidth) = 0 OR ISNUMERIC(netWeight) = 0) > 0			
		BEGIN
			SET @ErrMessage = 'Invalid Net Weight/ Length/ Width/ Height, not a numeric value.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(cbm,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'CBM is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNUMERIC(cbm) = 0) > 0
		BEGIN
			SET @ErrMessage = 'Invalid CBM, not a numeric value.';
			THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(measurement,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Measurement is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END		

        ALTER TABLE #invDump ADD productCategoryId INT;
        ALTER TABLE #invDump ADD productCategoryCode VARCHAR(3);
        ALTER TABLE #invDump ADD productSubCategoryId INT;
        ALTER TABLE #invDump ADD productSubCategoryCode VARCHAR(7);
        ALTER TABLE #invDump ADD isBuffer INT;
        ALTER TABLE #invDump ADD productTypeId INT;
        ALTER TABLE #invDump ADD measurementId INT;        

        -- get product category id & code
        UPDATE #invDump SET
            productCategoryId = pcat.prodCategoryId,
            productCategoryCode = pcat.prodCategoryCode
        FROM #invDump d
            INNER JOIN md_InventoryCategory pcat
				ON d.productCategory = pcat.prodCategoryName
				AND pcat.prodCategoryParentID = 1 --product category
				AND pcat.companyId = @companyId
				AND pcat.status = 1

        IF (SELECT COUNT(1) FROM #invDump WHERE productCategoryId IS NULL) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Category ' + STRING_AGG(CONVERT(VARCHAR(max), productCategory), ', ') + ' not yet created in system.' 
                                FROM (SELECT DISTINCT productCategory 
                                        FROM #invDump 
                                        WHERE productCategoryId IS NULL)g
                               );
			THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productCategoryCode,'') = '') > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Category ' + STRING_AGG(CONVERT(VARCHAR(max), productCategory), ', ') + ' not yet configure Code in system.' 
                                FROM (SELECT DISTINCT productCategory 
                                        FROM #invDump 
                                        WHERE ISNULL(productCategoryCode,'') = '')g
                                );
			THROW 60000, @ErrMessage, 1;
		END

        -- get product sub category id & code & isbuffer
        UPDATE #invDump SET
            productSubCategoryId = subcat.prodCategoryId,
            productSubCategoryCode = subcat.prodCategoryCode,
            isBuffer = subcat.isBuffer
        FROM #invDump d
            INNER JOIN md_InventoryCategory subcat
				ON d.productSubCategory = subcat.prodCategoryName
				AND d.productCategoryId = subcat.prodCategoryParentID --product sub category
				AND subcat.companyId = @companyId
				AND subcat.status = 1

        IF (SELECT COUNT(1) FROM #invDump WHERE productSubCategoryId IS NULL) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Sub Category ' + STRING_AGG(CONVERT(VARCHAR(max), productSubCategory + ' (' + productCategory + ')'), ', ') + ' not yet created in system.' 
                                FROM (SELECT DISTINCT productCategory, productSubCategory 
                                        FROM #invDump 
                                        WHERE productSubCategoryId IS NULL)g
                               );
			THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productSubCategoryCode,'') = '') > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Sub Category ' + STRING_AGG(CONVERT(VARCHAR(max), productSubCategory), ', ') + ' not yet configure Code in system.' 
                                FROM (SELECT DISTINCT productSubCategory 
                                        FROM #invDump 
                                        WHERE ISNULL(productSubCategoryCode,'') = '')g
                                );
			THROW 60000, @ErrMessage, 1;
		END

        ---- check file itemCode vs configured code
        --IF (SELECT COUNT(1) FROM #invDump WHERE LEFT(itemCode,7) <> productSubCategoryCode ) > 0
        --BEGIN
	       -- SET @ErrMessage = (SELECT 'Item Code ' + STRING_AGG(CONVERT(VARCHAR(max), itemCode), ', ') + ' have different prefix compare to Code configured in system.' 
        --                        FROM (SELECT DISTINCT itemCode 
        --                                FROM #invDump 
        --                                WHERE LEFT(itemCode,7) <> productSubCategoryCode)g
        --                        );
	       -- THROW 60000, @ErrMessage, 1;
        --END

        -- get product type id
        UPDATE #invDump SET
            productTypeId = ptype.inventoryTypeId
        FROM #invDump d
            INNER JOIN md_InventoryType ptype
		        ON d.productType = ptype.inventoryType --product type
		        AND d.productSubCategoryId = ptype.prodCategoryId
		        AND ptype.status = 1
 
        IF (SELECT COUNT(1) FROM #invDump WHERE productTypeId IS NULL) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Type ' + STRING_AGG(CONVERT(VARCHAR(max), productType + ' (' + productSubCategory + ')'), ', ') + ' not yet created in system.' 
                                FROM (SELECT DISTINCT productSubCategory, productType 
                                        FROM #invDump 
                                        WHERE productTypeId IS NULL)g
                               );
			THROW 60000, @ErrMessage, 1;
		END
		
        -- get measurement id
		UPDATE #invDump SET
            measurementId = meas.categoryId
        FROM #invDump d
            INNER JOIN md_MasterCategory meas
				ON d.measurement = meas.categoryName
				AND meas.categoryParentID = 1069 --measurement
				AND meas.status = 1

		IF (SELECT COUNT(1) FROM #invDump WHERE measurementId IS NULL) > 0
		BEGIN
			SET @ErrMessage = 'Invalid Measurement. [Unit/ Meter/ Set]';
			THROW 60000, @ErrMessage, 1;
		END	
        
/*** End: data validation ***/

/*** Start: generate itemCode ***/
        DECLARE @icLogId INT, @icProdCategoryId INT, @icProdSubCategoryId INT
            
        DECLARE db_genItemCode CURSOR FOR 
        SELECT logId, productCategoryId, productSubCategoryId
        FROM #invDump
        WHERE itemCode = '0'

        OPEN db_genItemCode  
        FETCH NEXT FROM db_genItemCode INTO @icLogId, @icProdCategoryId, @icProdSubCategoryId

        WHILE @@FETCH_STATUS = 0  
        BEGIN  
            DECLARE @productCode VARCHAR(16);
            
            EXEC [dbo].[SSP_Inventory_GetItemCode] 'ITEMCODE', @companyId, @icProdCategoryId, @icProdSubCategoryId, @productCode OUTPUT

            IF @productCode IS NULL
            BEGIN
                SET @ErrMessage = '[System Error] Item code encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END
    
            UPDATE #invDump SET
                itemCode = @productCode
            WHERE logId = @icLogId

            UPDATE md_itemCode SET
                nextNum = nextNum + 1
            WHERE condition = 'ITEMCODE'
                AND companyId = @companyId
                AND prodCategoryId = @icProdCategoryId 
                AND prodSubCategoryId = @icProdSubCategoryId 

            FETCH NEXT FROM db_genItemCode INTO @icLogId, @icProdCategoryId, @icProdSubCategoryId
        END 

        CLOSE db_genItemCode  
        DEALLOCATE db_genItemCode

/*** End: generate itemCode ***/

/*** Start : prepare attributes ***/
        DROP TABLE IF EXISTS #attributes;

        SELECT itemCode, attributeName_1 as attributeName, attributeValue_1 as attributeValue 
        INTO #attributes
        FROM #invDump 
        WHERE ISNULL(attributeName_1,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_2, attributeValue_2 FROM #invDump WHERE ISNULL(attributeName_2,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_3, attributeValue_3 FROM #invDump WHERE ISNULL(attributeName_3,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_4, attributeValue_4 FROM #invDump WHERE ISNULL(attributeName_4,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_5, attributeValue_5 FROM #invDump WHERE ISNULL(attributeName_5,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_6, attributeValue_6 FROM #invDump WHERE ISNULL(attributeName_6,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_7, attributeValue_7 FROM #invDump WHERE ISNULL(attributeName_7,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_8, attributeValue_8 FROM #invDump WHERE ISNULL(attributeName_8,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_9, attributeValue_9 FROM #invDump WHERE ISNULL(attributeName_9,'') <> ''
        UNION ALL 
        SELECT itemCode, attributeName_10, attributeValue_10 FROM #invDump WHERE ISNULL(attributeName_10,'') <> ''
        ORDER BY itemCode

        ALTER TABLE #attributes ADD categoryId INT;

        UPDATE att SET
            categoryId = mc.categoryId
        FROM #attributes att
            INNER JOIN md_MasterCategory mc
                ON att.attributeName = mc.categoryName
                AND mc.categoryParentID = 18  --product attributes
                AND mc.[status] = 1

        IF (SELECT COUNT(1) FROM #attributes WHERE categoryId IS NULL) > 0
        BEGIN
            SET @ErrMessage = (SELECT 'Attribute ' + STRING_AGG(CONVERT(VARCHAR(MAX), attributeName),', ') + ' not yet created in system.'
                                FROM (SELECT DISTINCT attributeName 
                                        FROM #attributes 
                                        WHERE categoryId IS NULL)g
                               );
            THROW 60000, @ErrMessage, 1;
        END

/*** End : prepare attributes ***/

/*** Start: generate productName ***/

        DROP TABLE IF EXISTS #getProductName;

        DECLARE @itemCode VARCHAR(50);

        DECLARE db_genItemCode CURSOR FOR 
        SELECT itemCode
        FROM #invDump

        OPEN db_genItemCode  
        FETCH NEXT FROM db_genItemCode INTO @itemCode

        WHILE @@FETCH_STATUS = 0  
        BEGIN  

            DECLARE @inventoryTypeId INT, @attributesJson NVARCHAR(MAX), @productName NVARCHAR(255);
            DECLARE @namingConvention VARCHAR(200);

            SELECT @inventoryTypeId = productTypeId
            FROM #invDump
            WHERE itemCode = @itemCode

            SELECT @namingConvention = namingConvention 
            FROM md_inventoryType
            WHERE inventoryTypeId = @inventoryTypeId

            IF @namingConvention IS NULL
            BEGIN
                SET @ErrMessage = '[System Error] Naming convention not yet configure in system.';
                THROW 60000, @ErrMessage, 1;
            END

            SET @attributesJson = (
                    SELECT i.modelno, 
                        MAX(CASE WHEN attributeName IN ('color','COLOUR') THEN attributeValue ELSE '' END) as color,
                        MAX(CASE WHEN attributeName = 'COLOUR NAME' THEN attributeValue ELSE '' END) as colorname,
                        CAST(i.netLength as VARCHAR(50)) as netlength,
                        CAST(i.netWidth as VARCHAR(50)) as netwidth,
                        CAST(i.netHeight as VARCHAR(50)) as netheight,
                        i.productType as inventorytype,
                        MAX(CASE WHEN attributeName = 'BOARD GRADE' THEN attributeValue ELSE '' END) as boardgrade,
                        MAX(CASE WHEN attributeName = 'GRAMMAGE' THEN attributeValue ELSE '' END) as grammage,
                        MAX(CASE WHEN attributeName = 'EDGING TYPE' THEN attributeValue ELSE '' END) as edgingtype,
                        MAX(CASE WHEN attributeName = 'SURFACE' THEN attributeValue ELSE '' END) as surface,
                        MAX(CASE WHEN attributeName = 'BACKER TYPE' THEN attributeValue ELSE '' END) as backertype,
                        MAX(CASE WHEN attributeName = 'PAPER TYPE' THEN attributeValue ELSE '' END) as papertype,
                        MAX(CASE WHEN attributeName = 'AI SIZE' THEN attributeValue ELSE '' END) as aisize,
                        MAX(CASE WHEN attributeName = 'AI TYPE' THEN attributeValue ELSE '' END) as aitype,
                        MAX(CASE WHEN attributeName = 'PAGES' THEN attributeValue ELSE '' END) as pages,
                        MAX(CASE WHEN attributeName = 'DIRECTION' THEN attributeValue ELSE '' END) as direction
                    FROM #invDump i
                        INNER JOIN #attributes a
                            ON i.itemCode = a.itemCode 
                    WHERE i.itemcode = @itemCode
                    GROUP BY i.modelno, i.productType, i.netlength, i.netwidth, i.netheight
					FOR JSON PATH, ROOT('inventory')
            );       

            SELECT @productName = dbo.FN_Inventory_GetProductName (@inventoryTypeId, @attributesJson) 

            UPDATE #invDump SET
                productName = @productName
            WHERE itemCode = @itemCode

            -- check generated productName exists in system
            DROP TABLE IF EXISTS #checkProductNameExists;

            SELECT invId, itemCode
            INTO #checkProductNameExists
            FROM md_Inventory
            WHERE productName = @productName
                AND companyId = @companyId
                AND status = 1

            IF (SELECT COUNT(1) FROM #checkProductNameExists) > 0
            BEGIN
                SET @ErrMessage = ( SELECT 'Product Name [' + @productName + '] already exists in the system with Item Code [' + itemCode + '].'
                                    FROM (SELECT TOP 1 itemCode
                                            FROM #checkProductNameExists
                                        )g

                                    );
                THROW 60000, @ErrMessage, 1;
            END


            FETCH NEXT FROM db_genItemCode INTO @itemCode
        END 

        CLOSE db_genItemCode  
        DEALLOCATE db_genItemCode

/*** End: generate productName ***/

        BEGIN TRANSACTION

		-- insert inventory, itemCode default 0
		DECLARE @Inventory table (invID BIGINT, itemCode VARCHAR(50));

		INSERT INTO md_Inventory (companyId, itemCode, productCategory, productSubCategory, productType, modelNo, inventorySKU, productName, productPrice, itemDesc, 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, measurement, glCode, isVirtual, isBuffer, 
            status, CreateDateTime, UpdateDateTime)
		OUTPUT INSERTED.invID, INSERTED.itemCode
		INTO @Inventory
		SELECT @companyId, itemCode, productCategoryId, productSubCategoryId, productTypeId, modelNo, inventorySKU, productName, productPrice, 
            CASE WHEN ISNULL([description],'') = '' THEN productName ELSE [description] END as [description], --empty description use productName
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, measurementId, glCode, 			
            CASE WHEN virtualProduct = 'Y' THEN 1 ELSE 0 END as isVirtual, isBuffer,  1 as status, getdate(), getdate()
		FROM #invDump

		-- insert product attribute 
		INSERT INTO inventory_attributes (invId, categoryId, value)
		SELECT inv.invID, att.categoryId, att.attributeValue
		FROM #invDump l
			INNER JOIN @Inventory inv
				ON l.itemCode = inv.itemCode
            INNER JOIN #attributes att
                ON l.itemCode = att.itemCode	

        -- insert warehouse balance
        DECLARE @intResult INT;

		EXEC @intResult = [SSP_Inventory_InsertWarehouseBalance] @userId

        IF @intResult <> 0
        BEGIN
            SET @ErrMessage = '[System Error] Default warehouse balance encounter creation problem.';
			THROW 60000, @ErrMessage, 1;
        END
		
		DELETE FROM @Inventory;

        COMMIT TRANSACTION

		DELETE FROM temp_inventoryLog WHERE fileName = @fileName

        SET @ErrMessage = 'Inventory has been successful created.';

		SELECT '_SUCCESS_' as status, @ErrMessage as returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH	 

		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END

		DELETE FROM temp_inventoryLog WHERE fileName = @fileName

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @ErrMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

