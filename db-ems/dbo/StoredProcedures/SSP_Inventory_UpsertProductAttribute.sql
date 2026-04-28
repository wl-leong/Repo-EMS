-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-10-08
-- Description:	Add product attribute 
-- Used By:		Inventory Module > Product Listing > Add Product > [Attributes]

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-10-20   1.1         ZY Wong     Update productName after success upsert, return productName 
-- 2024-10-08	1.0			ZY Wong		Initial version
-- =============================================
/*
select * from inventory_attributes where invid = 1427

    DECLARE @Json VARCHAR(MAX)= N'
            {"attributeList":[{
                    "attributesId": "2008",
                    "invId":"",
                    "attributeType":"",
                    "attributeValue":"",
                    "action":"Delete"
            }]}'
    EXEC [SSP_Inventory_UpsertProductAttribute] @Json
*/
CREATE PROCEDURE [dbo].[SSP_Inventory_UpsertProductAttribute] 
@Json VARCHAR(MAX)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;
	BEGIN TRY

        DECLARE @returnMessage VARCHAR(MAX);

        --DECLARE @Json VARCHAR(MAX)= N'
        --    {"attributeList":[{
        --            "attributesId": "5484",
        --            "invId":"31917",
        --            "attributeType":"19",
        --            "attributeValue":"BLACK",
        --            "action":"ADD"
        --    }]}'

        DROP TABLE IF EXISTS #attributeList;

        SELECT attributesId, invId, attributeType, attributeValue, actionType
        INTO #attributeList
        FROM OPENJSON(@Json, '$.attributeList') 
   				WITH (
                    attributesId BIGINT                         N'$.attributesId',
                    invId BIGINT                                N'$.invId',
					attributeType BIGINT				        N'$.attributeType',
                    attributeValue VARCHAR(100)                 N'$.attributeValue',
                    actionType VARCHAR(50)			            N'$.action'
                )

        DECLARE @actionType VARCHAR(50), @attributesId BIGINT, @invId BIGINT, @attributeType BIGINT, @attributeValue VARCHAR(100);

        SELECT @actionType = actionType, @attributesId = attributesId, @invId = invId, @attributeType = attributeType, @attributeValue = UPPER(attributeValue)
        FROM #attributeList

        IF ISNULL(@actionType,'') = '' 
        BEGIN
            SET @returnMessage = '[System Error] Action is required.';
            THROW 60000, @returnMessage, 1;
        END

        IF @actionType IN ('Add', 'Update') 
        BEGIN
            IF ISNULL(@attributeValue, '') = ''
            BEGIN
                SET @returnMessage = 'Attributes value is compulsory.';
                THROW 60000, @returnMessage, 1;
            END

        END

        IF @actionType IN ('Update', 'Delete') 
        BEGIN
            -- check attribute id passed in
            IF ISNULL(@attributesId, '') = '' 
            BEGIN
                SET @returnMessage = '[System Error] Attributes Id is compulsory.';
                THROW 60000, @returnMessage, 1;
            END
        END

        IF @invID IS NULL OR @invId = ''
        BEGIN
            SELECT @invId = invId
            FROM inventory_attributes
            WHERE attributesId = @attributesId
        END

        IF @attributeValue IS NULL OR @attributeValue = ''
        BEGIN
            SELECT @attributeValue = [value]
            FROM inventory_attributes
            WHERE attributesId = @attributesId
        END

        BEGIN TRANSACTION

        IF @actionType = 'Add'
        BEGIN
            -- check attribute exists
            IF (SELECT COUNT(1) FROM inventory_attributes WHERE invId = @invId AND categoryId = @attributeType) > 0
            BEGIN
            
                DECLARE @attributeName VARCHAR(100)

                SET @attributeName = (SELECT categoryName FROM md_MasterCategory WHERE categoryId = @attributeType AND categoryParentID = 18  AND [status] = 1);

                SET @returnMessage = 'Attributes ' + @attributeName + ' already created.';
                THROW 60000, @returnMessage,1;
            END

            -- insert new attributes
            INSERT INTO inventory_attributes (invID, categoryId, [value])
            SELECT @invId, @attributeType, @attributeValue

            SET @returnMessage = 'added.'
        END

        IF @actionType = 'Update'
        BEGIN
            -- update attribute
            UPDATE inventory_attributes SET
                [value] = @attributeValue
            WHERE attributesId = @attributesId

            SET @returnMessage = 'updated.'
        END

        IF @actionType = 'Delete'
        BEGIN
            -- delete attribute
            DELETE FROM inventory_attributes WHERE attributesId = @attributesId

            SET @returnMessage = 'deleted.'
        END

         
       DECLARE @attributesJson NVARCHAR(MAX), @productName NVARCHAR(255) 

       DECLARE @inventoryTypeId INT  = (SELECT productType FROM md_inventory inv WHERE invId = @invId)
   
        /*** Start: generate productName ***/
        SET @attributesJson = (
                SELECT i.modelno, 
                    MAX(CASE WHEN mc.categoryName IN ('color','COLOUR') THEN ia.[value] ELSE '' END) as color,
                    MAX(CASE WHEN mc.categoryName = 'COLOUR NAME' THEN ia.[value] ELSE '' END) as colorname,
                    CAST(i.netLength as VARCHAR(50)) as netlength,
                    CAST(i.netWidth as VARCHAR(50)) as netwidth,
                    CAST(i.netHeight as VARCHAR(50)) as netheight,
                    inv.inventoryType  as inventorytype,
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
                FROM md_Inventory i
                    INNER JOIN md_inventoryType inv
                        ON i.productType = inv.inventoryTypeId
                    LEFT JOIN inventory_attributes ia
                        ON i.invId = ia.invId
                    LEFT JOIN md_MasterCategory mc
                        ON ia.categoryId = mc.categoryId
                        AND mc.categoryParentID = 18  -- inventory attributes
                        AND mc.[status] = 1
                WHERE i.invId = @invId
                GROUP BY i.modelno, i.netlength, i.netwidth, i.netheight, inv.inventoryType 
				FOR JSON PATH, ROOT('inventory')
        );       

  
        EXEC [SSP_Inventory_GetProductName] @inventoryTypeId, @attributesJson, @productName OUTPUT

        /*** End: generate productName ***/

        IF ISNULL(@productName,'') = ''
        BEGIN 
            SET @returnMessage = '[System Error] Product name encounter creation problem.';
            THROW 60000, @returnMessage, 1;
        END

        UPDATE md_Inventory SET
            productName = @productName
        WHERE invId = @invId

        SET @returnMessage = 'Product attributes successful ' + @returnMessage;

        COMMIT TRANSACTION

    	SELECT '_SUCCESS_' as status, @returnMessage as returnMessage, @productName as productName

        RETURN 0
	END TRY

	BEGIN CATCH	 

		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END

        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @returnMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

