-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-10-18
-- Description:	Creata/ Update product for product listing 
-- Used By:		Inventory Module > Product Listing > Add

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-10-18   1.0         ZY Wong     Initial version
-- =============================================
/*		
DECLARE @outputJson VARCHAR(MAX), @inventoryJson VARCHAR(MAX) = 
N'{"inventory": [{
            "companyId": "4",
            "userId": "1",
			"invId": "",
            "productCategory":"3",
            "productSubCategory":"336",
            "productType":"2679",
            "modelNo":"test123",
            "inventorySku":"test123",
			"description": "test123",
            "grossWeight":"123",
            "grossLength": "800",
            "grossWidth": "500",
            "grossHeight": "1200",
            "netWeight":"123",
			"netLength": "800",
            "netWidth": "500",
            "netHeight": "1200",
            "cbm":"12.3145",
            "measurement":"1070",
            "isVirtual": "0",
            "isBuffer":"0",
            "action":"Add"
		}]}'; 

        EXEC [SSP_Inventory_UpsertProduct] @inventoryJson, @outputJson OUTPUT

        SELECT @outputJson
*/		 
CREATE PROCEDURE [dbo].[SSP_Inventory_UpsertProduct] 
@inventoryJson VARCHAR(MAX),
@outputJson VARCHAR(MAX) OUTPUT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

	BEGIN TRY
/*		
DECLARE @inventoryJson VARCHAR(MAX) = 
N'{"inventory": [{
            "companyId": "4",
            "userId": "1",
			"invId": "",
            "productCategory":"3",
            "productSubCategory":"336",
            "productType":"2679",
            "modelNo":"test123",
            "inventorySku":"test123",
			"description": "test123",
            "grossWeight":"123",
            "grossLength": "800",
            "grossWidth": "500",
            "grossHeight": "1200",
            "netWeight":"123",
			"netLength": "800",
            "netWidth": "500",
            "netHeight": "1200",
            "cbm":"12.3145",
            "measurement":"1070",
            "isVirtual": "0",
            "isBuffer":"0",
            "action":"Add"
		}]}'; 
*/		
		DECLARE @ErrMessage VARCHAR(MAX);
        DECLARE @returnMessage VARCHAR(100);

		DROP TABLE IF EXISTS #invDump;
  
		SELECT companyId, userId, invId, productCategory, productSubCategory, productType, 
            UPPER(modelNo) as modelNo, UPPER(inventorySku) as inventorySku, UPPER(itemDesc) as itemDesc, 
			grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight,
			cbm, measurement, isVirtual, isBuffer, actionType
		INTO #invDump
		FROM OPENJSON(@inventoryJson, '$.inventory') 
   		    WITH (
                companyId INT                   N'$.companyId',
                userId INT                      N'$.userId',
                invId INT                       N'$.invId',
                productCategory INT             N'$.productCategory',
                productSubCategory INT          N'$.productSubCategory',
                productType INT                 N'$.productType',
                modelNo	VARCHAR(50)             N'$.modelNo',
                inventorySku VARCHAR(50)        N'$.inventorySku',
                itemDesc VARCHAR(5000)          N'$.description',                
                grossWeight FLOAT               N'$.grossWeight',
                grossLength FLOAT               N'$.grossLength',
                grossWidth FLOAT                N'$.grossWidth',
                grossHeight FLOAT               N'$.grossHeight',
                netWeight FLOAT                 N'$.netWeight',
                netLength FLOAT                 N'$.netLength',
                netWidth FLOAT                  N'$.netWidth',
                netHeight FLOAT                 N'$.netHeight',
                cbm FLOAT                       N'$.cbm',
                measurement INT                 N'$.measurement',
                isVirtual INT                   N'$.isVirtual',
                isBuffer INT                    N'$.isBuffer',
                actionType VARCHAR(10)          N'$.action'
            )

        DECLARE @companyId INT, @userId INT, @actionType VARCHAR(10), 
            @invId INT, @productCategory INT, @productSubCategory INT, @productType INT, @measurement INT;

        SELECT @companyId = companyId, @userId = userId, @actionType = actionType, 
            @invId = invId, @productCategory = productCategory, @productSubCategory = productSubCategory, @productType = productType, @measurement = measurement
        FROM #invDump

/*** Start: data validation ***/
/*** system generate itemcode & product name ***/

        IF @actionType IN ('ADD','UPDATE') 
        BEGIN
            IF (SELECT COUNT(1) FROM md_InventoryCategory WHERE prodCategoryId = @productCategory AND prodCategoryParentId = 1 AND companyId = @companyId AND [status] = 1) = 0
            BEGIN
                SET @ErrMessage = '[System Error] Product Category Id not found.';
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_InventoryCategory WHERE prodCategoryId = @productSubCategory AND prodCategoryParentId = @productCategory AND companyId = @companyId AND [status] = 1) = 0
            BEGIN
                SET @ErrMessage = '[System Error] Product Sub Category Id not found.';
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_InventoryType WHERE inventoryTypeId = @productType AND prodCategoryId = @productSubCategory AND [status] = 1) = 0
            BEGIN
                SET @ErrMessage = '[System Error] Product Type Id not found.';
			    THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_MasterCategory WHERE categoryId = @measurement AND categoryParentId = 1069 AND [status] = 1) = 0
            BEGIN
                SET @ErrMessage = '[System Error] Measurement Id not found.';
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

            IF (SELECT COUNT(1) FROM #invDump WHERE isVirtual NOT IN (0,1)) > 0
		    BEGIN
			    SET @ErrMessage = '[System Error] Invalid isVirtual value.';
			    THROW 60000, @ErrMessage, 1;
		    END

            IF (SELECT COUNT(1) FROM #invDump WHERE isBuffer NOT IN (0,1)) > 0
		    BEGIN
			    SET @ErrMessage = '[System Error] Invalid isBuffer value.';
			    THROW 60000, @ErrMessage, 1;
		    END

            DECLARE @productCategoryCode VARCHAR(3), @productSubCategoryCode VARCHAR(7);

            SELECT @productCategoryCode = prodCategoryCode
            FROM md_InventoryCategory 
            WHERE prodCategoryId = @productCategory

            SELECT @productSubCategoryCode = prodCategoryCode
            FROM md_InventoryCategory 
            WHERE prodCategoryId = @productSubCategory

            IF ISNULL(@productCategoryCode,'') = ''
		    BEGIN
			    SET @ErrMessage = 'Product Category not yet configure Code in system.';
			    THROW 60000, @ErrMessage, 1;
		    END

            IF ISNULL(@productSubCategoryCode,'') = ''
		    BEGIN
			    SET @ErrMessage = 'Product Sub Category not yet configure Code in system.';
			    THROW 60000, @ErrMessage, 1;
		    END

        END
    
/*** End: data validation ***/
        BEGIN TRANSACTION

        DECLARE @Inventory TABLE (invID BIGINT);

        IF @actionType = 'ADD'
        BEGIN
            /*** Start: generate itemCode ***/   
            DECLARE @productCode VARCHAR(16);
            
            EXEC [dbo].[SSP_Inventory_GetItemCode] 'ITEMCODE', @companyId, @productCategory, @productSubCategory, @productCode OUTPUT

            IF @productCode IS NULL
            BEGIN
                SET @ErrMessage = '[System Error] Item code encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END
    
            UPDATE md_itemCode SET
                nextNum = nextNum + 1
            WHERE condition = 'ITEMCODE'
                AND companyId = @companyId
                AND prodCategoryId = @productCategory 
                AND prodSubCategoryId = @productSubCategory 
            /*** End: generate itemCode ***/

		    -- insert new inventory
		    INSERT INTO md_Inventory (companyId, itemCode, productCategory, productSubCategory, productType, modelNo, inventorySKU, productName, productPrice, itemDesc, 
			    grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, measurement, isVirtual, isBuffer, status, CreateDateTime, UpdateDateTime)
		    OUTPUT INSERTED.invID
		    INTO @Inventory
		    SELECT @companyId, @productCode, @productCategory, @productSubCategory, @productType, 
                modelNo, inventorySKU, CAST('' as VARCHAR(255)) as productName, CAST('0' as FLOAT) as productPrice, itemDesc, 
			    grossWeight, grossLength, grossWidth, grossHeight, netWeight, netLength, netWidth, netHeight, cbm, @measurement, isVirtual, isBuffer, 1 as status, getdate(), getdate()
		    FROM #invDump

            IF (SELECT COUNT(1) FROM @Inventory) <> 1
            BEGIN
                SET @ErrMessage = '[System Error] Create product encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END

            -- insert warehouse balance
            DECLARE @intResult INT;

		    EXEC @intResult = [SSP_Inventory_InsertWarehouseBalance] @userId

            IF @intResult <> 0
            BEGIN
                SET @ErrMessage = '[System Error] Default warehouse balance encounter creation problem.';
			    THROW 60000, @ErrMessage, 1;
            END

            SET @invId = (SELECT invId FROM @Inventory);

            UPDATE #invDump SET invId = @invId

            SET @returnMessage = 'created.'
        END

        IF ISNULL(@invId,0) = 0
        BEGIN
            SET @ErrMessage = '[System Error] Missing invId.';
			THROW 60000, @ErrMessage, 1;
        END

        IF (SELECT COUNT(1) FROM md_Inventory WHERE invId = @invId) <> 1
        BEGIN
            SET @ErrMessage = '[System Error] InvId not found.';
			THROW 60000, @ErrMessage, 1;
        END

        IF @actionType = 'UPDATE'
        BEGIN
            UPDATE md_Inventory SET
                productCategory = i.productCategory, 
                productSubCategory = i.productSubCategory, 
                productType = i.productType,             
                modelNo = i.modelNo, 
                inventorySKU = i.inventorySKU, 
                itemDesc = i.itemDesc,
			    grossWeight = i.grossWeight, 
                grossLength = i.grossLength, 
                grossWidth = i.grossWidth, 
                grossHeight = i.grossHeight, 
                netWeight = i.netWeight, 
                netLength = i.netLength, 
                netWidth = i.netWidth, 
                netHeight = i.netHeight,
			    cbm = i.cbm, 
                measurement = i.measurement, 
                isVirtual = i.isVirtual, 
                isBuffer = i.isBuffer,
                updateDateTime = getdate()
            FROM #invDump i
            WHERE md_Inventory.invId = @invId

            SET @returnMessage = 'updated.'
        END

        DECLARE @attributesJson NVARCHAR(MAX), @productName NVARCHAR(255), @namingConvention VARCHAR(200), @productTypeName VARCHAR(255);

        IF @actionType IN ('ADD', 'UPDATE')
        BEGIN

            /*** Start: generate productName ***/
            SELECT @namingConvention = namingConvention, @productTypeName = inventoryType
            FROM md_inventoryType
            WHERE inventoryTypeId = @productType

            IF @namingConvention IS NULL
            BEGIN
                SET @ErrMessage = '[System Error] Naming convention not yet configure in system.';
                THROW 60000, @ErrMessage, 1;
            END

            SET @attributesJson = (
                    SELECT i.modelno, 
                        MAX(CASE WHEN mc.categoryName IN ('color','COLOUR') THEN ia.[value] ELSE '' END) as color,
                        MAX(CASE WHEN mc.categoryName = 'COLOUR NAME' THEN ia.[value] ELSE '' END) as colorname,
                        CAST(i.netLength as VARCHAR(50)) as netlength,
                        CAST(i.netWidth as VARCHAR(50)) as netwidth,
                        CAST(i.netHeight as VARCHAR(50)) as netheight,
                        @productTypeName as inventorytype,
                        MAX(CASE WHEN mc.categoryName = 'BOARD GRADE' THEN ia.[value] ELSE '' END) as boardgrade,
                        MAX(CASE WHEN mc.categoryName = 'GRAMMAGE' THEN ia.[value] ELSE '' END) as grammage,
                        MAX(CASE WHEN mc.categoryName = 'EDGING TYPE' THEN ia.[value] ELSE '' END) as edgingtype,
                        MAX(CASE WHEN mc.categoryName = 'SURFACE' THEN ia.[value] ELSE '' END) as surface,
                        MAX(CASE WHEN mc.categoryName = 'BACKER TYPE' THEN ia.[value] ELSE '' END) as backertype,
                        MAX(CASE WHEN mc.categoryName = 'PAPER TYPE' THEN ia.[value] ELSE '' END) as papertype,
                        MAX(CASE WHEN mc.categoryName = 'AI SIZE' THEN ia.[value] ELSE '' END) as aisize,
                        MAX(CASE WHEN mc.categoryName = 'AI TYPE' THEN ia.[value] ELSE '' END) as aitype,
                        MAX(CASE WHEN mc.categoryName = 'PAGES' THEN ia.[value] ELSE '' END) as pages,
                        MAX(CASE WHEN mc.categoryName = 'DIRECTION' THEN ia.[value] ELSE '' END) as direction
                    FROM #invDump i
                        LEFT JOIN inventory_attributes ia
                            ON i.invId = ia.invId
                        LEFT JOIN md_MasterCategory mc
                            ON ia.categoryId = mc.categoryId
                            AND mc.categoryParentID = 18  -- inventory attributes
                            AND mc.[status] = 1
                    WHERE i.invId = @invId
                    GROUP BY i.modelno, i.netlength, i.netwidth, i.netheight
					FOR JSON PATH, ROOT('inventory')
            );       

            EXEC [SSP_Inventory_GetProductName] @productType, @attributesJson, @productName OUTPUT

            /*** End: generate productName ***/

            IF ISNULL(@productName,'') = ''
            BEGIN 
                SET @ErrMessage = '[System Error] Product name encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END

            UPDATE md_Inventory SET
                productName = @productName
            WHERE invId = @invId

            SET @outputJson = (SELECT invId, itemCode, productName
                                FROM md_Inventory
                                WHERE invId = @invId
                                FOR JSON PATH, ROOT('inventory')
                            );
            
        END

        DELETE FROM @Inventory;

        COMMIT TRANSACTION

        SET @returnMessage = 'Inventory has been successful ' + @returnMessage;

		SELECT '_SUCCESS_' as status, @returnMessage as returnMessage, @outputJson as outputJson

        RETURN 0
	END TRY

	BEGIN CATCH	 

		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END

        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @ErrMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

