-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-11-21
-- Description:	Load inventory list from dump 
-- Used By:		Inventory Module > Import Inventory
--              Inventory Module > Inventory Listing > Add

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-14   10.0        ZY Wong     Add validation check warehouse exists
-- 2024-10-21   9.0         ZY Wong     Change use OR for ignore empty line, change 'color' to 'COLOUR NAME' attribute
-- 2024-10-09   8.0         ZY Wong     Improve on error msg of product sub category & product type validation
-- 2024-09-23   7.0         ZY Wong     Remove @isMarketing
-- 2024-07-03   6.0         ZY Wong     Add new parameter @userId, Rename grossDepth to grossLength, netDepth to netLength, Add validation for system error, Generate itemCode for non-marketing company, Simplify code
-- 2024-04-08	5.0			WL Leong	rename upc to itemCode
-- 2024-03-21	4.0			ZY Wong		Call sp [SSP_Inventory_InsertWarehouseBalance] after insert inventory ** pass in @enterBy parameter in future
-- 2024-03-19	3.0			ZY Wong		Only allow insert inventory, removed create category/type & update inventory
-- 2024-01-19	2.0			ZY Wong		Remove blank or null upc row
-- 2023-11-21	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_Inventory_InsertInventory] 11, '20241003061159_InventoryTemplate_test20241001.xlsx', 1
CREATE PROCEDURE [dbo].[SSP_Inventory_InsertInventory] 
@companyId INT,
@fileName VARCHAR(150),
@userId INT
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
	BEGIN TRY
		
		--DECLARE @fileName VARCHAR(150) = 'InventoryTemplate_20240319.xlsx', @companyId INT = 4
		
		DECLARE @ErrMessage VARCHAR(MAX);

        -- check warehouse configured
        DECLARE @warehouseId BIGINT = (SELECT TOP 1 warehouseId FROM md_Warehouse WHERE companyId = @companyId AND status = 1);

        IF @warehouseId IS NULL
        BEGIN
        	SET @ErrMessage = 'Warehouse is not configured in system.';
			THROW 60000, @ErrMessage, 1;
        END

		DROP TABLE IF EXISTS #invDump;

		SELECT logId, productCategory, productSubCategory, productType, itemCode, modelNo, inventorySKU, productName, productPrice, [description] as itemDesc, 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight,
			cbm, measurement, color, packaging, size, glCode, virtualProduct
		INTO #invDump
		FROM temp_inventoryLog
		WHERE fileName = @fileName
            AND (ISNULL(productCategory,'') <> '' OR ISNULL(productSubCategory,'') <> '' OR ISNULL(productType,'') <> '')  --ignore empty line

/*** Start: data validation ***/
/*** insert inventory sp, check ALL itemcode passed in, product name NOT allow null ***/
           
		IF (SELECT COUNT(1) FROM #invDump WHERE itemCode IS NULL) > 0
		BEGIN
			SET @ErrMessage = 'Item Code is missing in file.';
			THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(itemCode,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Item Code is compulsory, please fill in.';
			THROW 60000, @ErrMessage, 1;
		END

        DROP TABLE IF EXISTS #checkDupItemCode;

        SELECT itemCode, COUNT(itemCode) as itemCodeCount 
        INTO #checkDupItemCode
        FROM #invDump 
        GROUP BY itemCode

		IF (SELECT COUNT(1) FROM #checkDupItemCode  WHERE itemCodeCount > 1) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Item Code ' + STRING_AGG(CONVERT(VARCHAR(max), itemCode), ',') + ' are duplicate in file.' 
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
			SET @ErrMessage = (SELECT 'Item Code ' + STRING_AGG(CONVERT(VARCHAR(max), itemCode), ',') + ' already exists in system.' 
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

		IF (SELECT COUNT(1) FROM #invDump WHERE ISNULL(productName,'') = '') > 0
		BEGIN
			SET @ErrMessage = 'Product Name is compulsory, please fill in.';
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
        ALTER TABLE #invDump ADD productSubCategoryId INT;
        ALTER TABLE #invDump ADD isBuffer INT;
        ALTER TABLE #invDump ADD productTypeId INT;
        ALTER TABLE #invDump ADD measurementId INT;        

        -- get product category id
        UPDATE #invDump SET
            productCategoryId = pcat.prodCategoryId
        FROM #invDump d
            INNER JOIN md_InventoryCategory pcat
				ON d.productCategory = pcat.prodCategoryName
				AND pcat.prodCategoryParentID = 1 --product category
				AND pcat.companyId = @companyId
				AND pcat.status = 1

        IF (SELECT COUNT(1) FROM #invDump WHERE productCategoryId IS NULL) > 0
		BEGIN
			SET @ErrMessage = (SELECT 'Product Category ' + STRING_AGG(CONVERT(VARCHAR(max), productCategory), ',') + ' not yet created in system.' 
                                FROM (SELECT DISTINCT productCategory 
                                        FROM #invDump 
                                        WHERE productCategoryId IS NULL)g
                               );
			THROW 60000, @ErrMessage, 1;
		END

        -- get product sub category id & isbuffer
        UPDATE #invDump SET
            productSubCategoryId = subcat.prodCategoryId,
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

        -- update empty itemDesc 
        UPDATE #invDump SET
            itemDesc = productName
        WHERE ISNULL(itemDesc,'') = '' 
            AND productName IS NOT NULL


/*** End: data validation ***/

        BEGIN TRANSACTION

		-- insert inventory
		DECLARE @Inventory table (invID BIGINT, itemCode VARCHAR(50), prodCategoryId INT, prodSubCategory INT);

		INSERT INTO md_Inventory (companyId, itemCode, productCategory, productSubCategory, productType, modelNo, inventorySKU, productName, productPrice, itemDesc, 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, measurement, glCode, isVirtual, isBuffer, 
            status, CreateDateTime, UpdateDateTime)
		OUTPUT INSERTED.invID, INSERTED.itemCode, INSERTED.productCategory, INSERTED.productSubCategory
		INTO @Inventory
		SELECT @companyId, itemCode, productCategoryId, productSubCategoryId, productTypeId, modelNo, inventorySKU, productName, productPrice, itemDesc, 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, measurementId, glCode, 			
            CASE WHEN virtualProduct = 'Y' THEN 1 ELSE 0 END as isVirtual, isBuffer,  1 as status, getdate(), getdate()
		FROM #invDump

		-- insert product attribute (color, packaging, size)
		DECLARE @colorId INT = (SELECT categoryId FROM md_MasterCategory WHERE categoryName = 'COLOUR NAME' AND categoryParentID = 18)
		DECLARE @packagingId INT = (SELECT categoryId FROM md_MasterCategory WHERE categoryName = 'Packaging' AND categoryParentID = 18)
		DECLARE @sizeId INT = (SELECT categoryId FROM md_MasterCategory WHERE categoryName = 'Size' AND categoryParentID = 18)

		INSERT INTO inventory_attributes (invId, categoryId, value)
		SELECT inv.invID, @colorId, l.color
		FROM #invDump l
			INNER JOIN @Inventory inv
				ON l.itemCode = inv.itemCode
		WHERE ISNULL(l.color,'') <> '' 
		UNION ALL 
		SELECT inv.invID, @packagingId, l.packaging
		FROM #invDump l
			INNER JOIN @Inventory inv
				ON l.itemCode = inv.itemCode
		WHERE ISNULL(l.packaging,'') <> '' 
		UNION ALL 
		SELECT inv.invID, @sizeId, l.size
		FROM #invDump l
			INNER JOIN @Inventory inv
				ON l.itemCode = inv.itemCode
		WHERE ISNULL(l.size,'') <> ''

        DECLARE @intResult INT;

		EXEC @intResult = [SSP_Inventory_InsertWarehouseBalance] @userId

        IF @intResult <> 0
        BEGIN
            SET @ErrMessage = 'Default warehouse balance encounter creation problem.';
			THROW 60000, @ErrMessage, 1;
        END
		
		DELETE FROM @Inventory;

        COMMIT TRANSACTION

		DELETE FROM temp_inventoryLog WHERE fileName = @fileName

		SELECT '_SUCCESS_' as status, 'Inventory has been successful created.' as returnMessage
        
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

