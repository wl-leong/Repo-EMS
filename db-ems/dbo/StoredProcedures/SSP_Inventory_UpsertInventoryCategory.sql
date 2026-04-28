-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-07-03
-- Description:	Add/Update/Delete/Reactivate inventory category
-- Used By:		Inventory Module -> Inventory Category

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-07-03	1.0			ZY Wong		Initial version
-- =============================================
--EXEC  [dbo].[SSP_Inventory_UpsertInventoryCategory]
--	 		N'{"categoryList":[{
--                "prodCategoryId":null,
--	 			"companyId":"4",
--	 			"code":"",
--	 			"item":"TESTING CODE 1",
--                "remarks":null,		
--                "isBom":0,
--	 			"action":"ADD"
--	 			}]}',   1

CREATE PROCEDURE [dbo].[SSP_Inventory_UpsertInventoryCategory]
@Json VARCHAR(MAX),
@userId INT 
AS
BEGIN
SET NOCOUNT ON
SET XACT_ABORT ON
    BEGIN TRY

    --    DECLARE @Json VARCHAR(MAX) = 
	-- 		N'{"categoryList":[{
    --            "prodCategoryId":null,
	-- 			"companyId":"4",
	-- 			"code":"123",
	-- 			"item":"Test",
    --            "remarks":null,		
    --            "isBom":0,
	-- 			"action":"ADD"
	-- 			}]}',
	-- 		@userId INT = 1;

		DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #categoryList;

		SELECT prodCategoryId, companyId, categoryCode, UPPER(categoryName) as categoryName, remarks, isBom, actionType
		INTO #categoryList
		FROM  OPENJSON(@Json, '$.categoryList') 
   			WITH (
				prodCategoryId INT              N'$.prodCategoryId',
                companyId INT					N'$.companyId',
                categoryCode VARCHAR(3)		    N'$.code',
                categoryName VARCHAR(255)		N'$.item',
                remarks VARCHAR(255)			N'$.remarks',
                isBom INT                       N'$.isBom',
				actionType VARCHAR(50)			N'$.action'
			)

 
		DECLARE @actionType VARCHAR(50), @companyId INT, @prodCategoryId BIGINT, @categoryName VARCHAR(50), @categoryCode VARCHAR(3), @remarks VARCHAR(255), @isBom INT;

		SELECT @actionType = actionType, @companyId = companyId, @prodCategoryId = prodCategoryId, @categoryCode = categoryCode, @categoryName = categoryName, @remarks = remarks, 
            @isBom = isBom
		FROM #categoryList

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @ErrMessage = '[System Error] Action is required.';
            THROW 60000, @ErrMessage, 1;
        END

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
        
        DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId);
        
        IF @actionType IN ('Add', 'Update') 
        BEGIN
            IF ISNULL(@categoryName, '') = ''
            BEGIN
                SET @ErrMessage = 'Item is compulsory.';
                THROW 60000, @ErrMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_inventoryCategory 
                    WHERE prodCategoryName = @categoryName 
                    AND companyId = @companyId 
                    AND prodCategoryId <> @prodCategoryId 
                    AND prodCategoryParentId = 1 -- prod category 
                ) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Item ' + @categoryName  + ' already exists in the system.'  );
                THROW 60000, @ErrMessage, 1;
            END

        END

        IF @actionType = 'Add'
        BEGIN
            IF (SELECT COUNT(1) FROM md_inventoryCategory WHERE prodCategoryName = @categoryName AND companyId = @companyId AND prodCategoryParentId = 1) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'Item ' + @categoryName  + ' already exists in the system.'  );
                THROW 60000, @ErrMessage, 1;
            END
        END

        IF @actionType IN ('Update','Delete','Reactivate') 
        BEGIN
            IF ISNULL(@prodCategoryId, 0) = 0
            BEGIN
                SET @ErrMessage = '[System Error] ProdCategoryId is required.';
                THROW 60000, @ErrMessage, 1;
            END
        END

        BEGIN TRANSACTION

        IF @actionType = 'Add'
        BEGIN
            DECLARE @newCategory TABLE (prodCategoryId INT);
            DECLARE @insertedCategoryId BIGINT;

            INSERT INTO md_InventoryCategory (companyId, prodCategoryName, prodCategoryCode, prodCategoryParentID, prodCategoryRemarks, status, isBom, isBuffer, createDate, enterBy)
            OUTPUT INSERTED.prodCategoryId
            INTO @newCategory
            SELECT @companyId, @categoryName, ISNULL(@categoryCode, 0), 1 as prodCategoryParentID, @remarks, 1 as status, @isBom, 0 as isBuffer, getdate(), @userId            

            SET @insertedCategoryId = (SELECT prodCategoryId FROM @newCategory);

            IF @insertedCategoryId IS NULL
            BEGIN
                SET @ErrMessage = '[System Error] ProdCategoryId encounter creation problem.';
                THROW 60000, @ErrMessage, 1;
            END

            IF @isMarketing = 0
            BEGIN
                DECLARE @prodCategoryCode VARCHAR(3);
            
                EXEC [dbo].[SSP_Inventory_GetItemCode] 'PRODCATEGORY', @companyId, @insertedCategoryId, 0,  @prodCategoryCode OUTPUT

                IF @prodCategoryCode IS NULL
                BEGIN
                    SET @ErrMessage = '[System Error] Product category code encounter creation problem.';
                    THROW 60000, @ErrMessage, 1;
                END

                UPDATE md_InventoryCategory SET
                    prodCategoryCode = @prodCategoryCode
                WHERE prodCategoryId =  @insertedCategoryId

                UPDATE md_itemCode SET
                    nextNum = nextNum + 1
                WHERE condition = 'PRODCATEGORY'
                    AND companyId = @companyId
                    AND prodCategoryId = @insertedCategoryId 
            END




            SET @ErrMessage = 'created.';

        END

        IF @actionType = 'Update'
        BEGIN

            UPDATE md_InventoryCategory SET
                prodCategoryName = @categoryName,
                prodCategoryRemarks =  @remarks,
                isBom = @isBom,
                updateBy = @userId,
                updateDate = getdate()
            WHERE prodCategoryId = @prodCategoryId
  
            IF @isMarketing = 1
            BEGIN
                UPDATE md_InventoryCategory SET
                    prodCategoryCode = @categoryCode,
                    updateBy = @userId,
                    updateDate = getdate()
                WHERE prodCategoryId = @prodCategoryId
            END

            SET @ErrMessage = 'updated.';

        END

        IF @actionType = 'Delete'
        BEGIN
            UPDATE md_InventoryCategory SET
                status = 0,
                updateBy = @userId,
                updateDate = getdate()
            WHERE prodCategoryId = @prodCategoryId

            DECLARE @productSubCategory TABLE (prodCategoryId BIGINT);

            -- deactivate sub category belongs to the product category
            UPDATE md_InventoryCategory SET
                status = 0,
                updateBy = @userId,
                updateDate = getdate()
            OUTPUT INSERTED.prodCategoryId
            INTO @productSubCategory
            WHERE prodCategoryParentId = @prodCategoryId

            -- deactivate product type belongs to the deactivated sub category
            UPDATE tp SET
                status = 0
            FROM md_InventoryType tp
                INNER JOIN  @productSubCategory p
                    ON tp.prodCategoryId = p.prodCategoryId

            SET @ErrMessage = 'deleted.';
        END
     
        IF @actionType = 'Reactivate'
        BEGIN
            UPDATE md_InventoryCategory SET
                status = 1,
                updateBy = @userId,
                updateDate = getdate()
            WHERE prodCategoryId = @prodCategoryId

            SET @ErrMessage = 're-activated.';
        END

        SET @ErrMessage = 'Inventory Category successfully ' + @ErrMessage;
        
		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage

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

