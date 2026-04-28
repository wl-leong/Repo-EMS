-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-07-05
-- Description:	Add/Update/Delete inventory sub category
-- Used By:		Inventory Module -> Inventory Sub Category

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-10-16   3.0         WL Leong    
-- 2024-08-29   2.0         ZY Wong     Update md_Inventory isBuffer
-- 2024-07-05	1.0			ZY Wong		Initial version
-- =============================================
/**
EXEC SSP_Inventory_UpsertInventorySubCategory
			N'{"subCategoryList":[{
                "prodCategoryId":29,
				"companyId":"4",
                "prodCategoryParentId":"4",
				"code":"",
				"item":"BINS",
                "remarks":"NON-WOVEN BINS",		
                "isBuffer":0,
				"action":"Update"
				}]}',1;

SELECT * FROM md_inventoryCategory 
**/
CREATE PROCEDURE [dbo].[SSP_Inventory_UpsertInventorySubCategory]
@Json VARCHAR(MAX),
@userId INT 
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON
    BEGIN TRY

   --     DECLARE @Json VARCHAR(MAX) = 
			--N'{"subCategoryList":[{
   --             "prodCategoryId":null,
			--	"companyId":"4",
   --             "prodCategoryParentId":"3",
			--	"code":"123",
			--	"item":"Test",
   --             "remarks":null,		
   --             "isBuffer":0,
			--	"action":"Add"
			--	}]}',
			--@userId INT = 1;

		DECLARE @ReturnMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #subCategoryList;

		SELECT prodCategoryId, companyId, prodCategoryParentId, categoryCode, UPPER(categoryName) as categoryName, remarks, isBuffer, actionType
		INTO #subCategoryList
		FROM  OPENJSON(@Json, '$.subCategoryList') 
   			WITH (
				prodCategoryId INT              N'$.prodCategoryId',
                companyId INT					N'$.companyId',
                prodCategoryParentId INT        N'$.prodCategoryParentId',
                categoryCode VARCHAR(255)		N'$.code',
                categoryName VARCHAR(255)		N'$.item',
                remarks VARCHAR(255)			N'$.remarks',
                isBuffer INT                    N'$.isBuffer',
				actionType VARCHAR(50)			N'$.action'
			)

		DECLARE @actionType VARCHAR(50), @companyId INT, @prodCategoryParentId INT, @prodCategoryId BIGINT, @categoryName VARCHAR(50), @categoryCode VARCHAR(3), 
            @remarks VARCHAR(255), @isBuffer INT;;

		SELECT @actionType = actionType, @companyId = companyId, @prodCategoryParentId = prodCategoryParentId, @prodCategoryId = prodCategoryId, @categoryCode = categoryCode, 
            @categoryName = categoryName, @remarks = remarks, @isBuffer = isBuffer
		FROM #subCategoryList

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @ReturnMessage = '[System Error] Action is required.';
            THROW 60000, @ReturnMessage, 1;
        END

        IF ISNULL(@companyId,0) = 0 
        BEGIN
            SET @ReturnMessage = '[System Error] Company Id is required.';
            THROW 60000, @ReturnMessage, 1;
        END

        IF ISNULL(@userId,0) = 0 
        BEGIN
            SET @ReturnMessage = '[System Error] User Id is required.';
            THROW 60000, @ReturnMessage, 1;
        END        

        DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId);
        
        IF @actionType IN ('Add','Update') 
        BEGIN
            IF ISNULL(@categoryName, '') = ''
            BEGIN
                SET @ReturnMessage = 'Item is compulsory.';
                THROW 60000, @ReturnMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_inventoryCategory 
                    WHERE prodCategoryName = @categoryName 
                    AND companyId = @companyId 
                    AND prodCategoryId  <> @prodCategoryId 
                    AND prodCategoryParentId = @prodCategoryParentId
                ) > 0
            BEGIN
                SET @ReturnMessage = (SELECT 'Item ' + @categoryName  + ' already exists in the system.' );
                THROW 60000, @ReturnMessage, 1;
            END
        END

        IF @actionType IN ('Add') 
        BEGIN
            IF (SELECT COUNT(1) FROM md_inventoryCategory WHERE prodCategoryName = @categoryName AND companyId = @companyId AND prodCategoryParentId = @prodCategoryParentId) > 0
            BEGIN
                SET @ReturnMessage = (SELECT 'Item ' + @categoryName  + ' already exists in the system.');
                THROW 60000, @ReturnMessage, 1;
            END
        END

        IF @actionType IN ('Update','Delete','Reactivate') 
        BEGIN
            IF ISNULL(@prodCategoryId, 0) = 0
            BEGIN
                SET @ReturnMessage = '[System Error] ProdCategoryId is required.';
                THROW 60000, @ReturnMessage, 1;
            END

            IF (SELECT COUNT(1) FROM md_inventoryCategory WHERE prodCategoryId = @prodCategoryId) = 0
            BEGIN
                SET @ReturnMessage = '[System Error] ProdCategoryId is not exists in the system.';
                THROW 60000, @ReturnMessage, 1;
            END
        END

	    BEGIN TRANSACTION

            IF @actionType = 'Add'
            BEGIN
                IF ISNULL(@prodCategoryParentId,0) = 0 
                BEGIN
                    SET @ReturnMessage = '[System Error] ProdCategoryParentId is required.';
                    THROW 60000, @ReturnMessage, 1;
                END

                DECLARE @newSubCategory TABLE (prodCategoryId INT);
                DECLARE @newProdCategoryId INT;

                INSERT INTO md_InventoryCategory (companyId, prodCategoryName, prodCategoryCode, prodCategoryParentID, prodCategoryRemarks, status, isBom, isBuffer, createDate, enterBy)
                OUTPUT INSERTED.prodCategoryId
                INTO @newSubCategory
                SELECT @companyId, @categoryName, ISNULL(@categoryCode, 0), @prodCategoryParentID, @remarks, 1 as status, 0 as isBom, @isBuffer, getdate(), @userId            

                SET @newProdCategoryId = (SELECT prodCategoryId FROM @newSubCategory);

                IF @newProdCategoryId IS NULL
                BEGIN
                    SET @ReturnMessage = '[System Error] ProdCategoryId encounter creation problem.';
                    THROW 60000, @ReturnMessage, 1;
                END
 
                SET @ReturnMessage = 'created.';

                SET @prodCategoryId = @newProdCategoryId;
            END
 
            IF @actionType = 'Update'
            BEGIN
                UPDATE md_InventoryCategory SET
                    prodCategoryName = @categoryName,
                    prodCategoryRemarks = @remarks,
                    isBuffer = @isBuffer,
                    updateBy = @userId,
                    updateDate = getdate()
                WHERE prodCategoryId = @prodCategoryId

                DECLARE @oriCategoryCode VARCHAR(10);
                SET @oriCategoryCode = (SELECT prodCategoryCode FROM md_InventoryCategory WHERE prodCategoryId = @prodCategoryId);

                IF (@isMarketing = 1) OR (@isMarketing = 0 AND ISNULL(@oriCategoryCode, '') = '')
                BEGIN
                    UPDATE md_InventoryCategory SET
                        prodCategoryCode = @categoryCode,
                        updateBy = @userId,
                        updateDate = getdate()
                    WHERE prodCategoryId = @prodCategoryId
                END

                UPDATE md_Inventory SET
                    isBuffer = @isBuffer
                WHERE productSubCategory = @prodCategoryId

                SET @ReturnMessage = 'updated.';
            END

            IF @actionType = 'Delete'
            BEGIN
                UPDATE md_InventoryCategory SET
                    status = 0,
                    updateBy = @userId,
                    updateDate = getdate()
                WHERE prodCategoryId = @prodCategoryId

                SET @ReturnMessage = 'deleted.';
            END

            IF @actionType = 'Reactivate'
            BEGIN
                UPDATE md_InventoryCategory SET
                    status = 1,
                    updateBy = @userId,
                    updateDate = getdate()
                WHERE prodCategoryId = @prodCategoryId

                SET @ReturnMessage = 're-activated.';
            END

            IF @actionType IN ('Add', 'Update') AND  @isMarketing = 0 AND ISNULL(@categoryCode, '') = ''
            BEGIN
                DECLARE @prodCategoryCode VARCHAR(10);
            
                EXEC [dbo].[SSP_Inventory_GetItemCode] 'PRODSUBCATEGORY', @companyId, @prodCategoryParentID, @prodCategoryId,  @prodCategoryCode OUTPUT

                IF @prodCategoryCode IS NULL
                BEGIN
                    SET @ReturnMessage = '[System Error] Product sub category code encounter creation problem.';
                    THROW 60000, @ReturnMessage, 1;
                END

                UPDATE md_InventoryCategory SET
                    prodCategoryCode = @prodCategoryCode
                WHERE prodCategoryId =  @prodCategoryId

                UPDATE md_itemCode SET
                    nextNum = nextNum + 1
                WHERE condition = 'PRODSUBCATEGORY'
                    AND companyId = @companyId
                    AND prodCategoryId = @prodCategoryParentID 
                    AND prodSubCategoryId = @prodCategoryId
            END

            SET @ReturnMessage = 'Inventory Sub Category successfully ' + @ReturnMessage;
        
		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, @ReturnMessage AS returnMessage

        RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END  
 
        IF @ReturnMessage IS NULL 
            SET @ReturnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE()

		SELECT '_FAILURE_' as status, @ReturnMessage as returnMessage

		RETURN -1
	END CATCH
END

GO

