-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    Use to generate all Inventory #

-- Description : ItemFormat is the format and replace the xxx with running#

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-07-08	1.0			WL Leong	Initial
-- ==========================================================================================
/**
/**
select * from md_company
select * from md_itemCOde where condition = 'SO'

 
**/

 DECLARE @StringFormat VARCHAR(50)
 EXEC [dbo].[SSP_Inventory_GetItemCode] 'ItemCode', 4, 3, 334, @StringFormat OUTPUT

SELECT @StringFormat
**/
CREATE PROCEDURE [dbo].[SSP_Inventory_GetItemCode]
@keyID VARCHAR(50),
@companyId INT,
@prodCategoryId INT,
@prodSubCategoryId INT,
@StringFormat varchar(50) OUTPUT
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

 
	DECLARE @ItemFormat VARCHAR(20), @NextNum INT, @returnstring VARCHAR(50), @FormatIndex INT, @MaxNum INT

--    DECLARE @keyID VARCHAR(50) = 'PRODCATEGORY',
--@companyId INT = 4,
--@prodCategoryId INT = 309,
--@prodSubCategoryId INT = 0
 
    IF @keyID = 'PRODCATEGORY'
    BEGIN
		SELECT @NextNum = NextNum, @FormatIndex=FormatIndex, @MaxNum=MaxNum, @ItemFormat=ItemFormat
		FROM MD_itemCode WITH (TABLOCKX)
		WHERE condition =  @keyID 
            AND companyId = @companyId

 
        IF @NextNum IS NULL
        BEGIN
            INSERT INTO md_ItemCode(companyId, condition, prodCategoryId, prodSubCategoryId, ItemFormat, FormatIndex, NextNum, MaxNum)
            SELECT @companyId, 'PRODCATEGORY', 0, 0, 'XXX', 1, 1, 99

            SET @nextNum = 1
            SET @ItemFormat = 'XXX'
        END
        ELSE
        BEGIN
            DECLARE @prodi INT = 1, @prodj INT = 1

            SET @StringFormat = REPLACE(@ItemFormat, 'xxx', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))

 
            WHILE (@prodi = @prodj)
            BEGIN
                IF (SELECT COUNT(1) FROM md_InventoryCategory WHERE prodCategoryParentId = 1 AND companyId = @companyId AND prodCategoryCode = @StringFormat) > 0
                BEGIN
                    
                    UPDATE MD_itemCode SET
                        NextNum = NextNum + 1
                    WHERE condition = @keyID
                        AND companyId = @companyId 

                    SET @NextNum = @NextNum + 1

                    SET @StringFormat = REPLACE(@ItemFormat, 'xxx', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))
                END
                ELSE
                BEGIN 
                    SET @prodj = @prodi + 999
                END
            END
        END
 
        SET @StringFormat = REPLACE(@ItemFormat, 'xxx', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))
    END
 
    IF @keyID = 'PRODSUBCATEGORY'
    BEGIN
		SELECT @NextNum = NextNum, @FormatIndex = FormatIndex, @MaxNum=MaxNum, @ItemFormat=ItemFormat
		FROM MD_itemCode WITH (TABLOCKX)
		WHERE condition =  @keyID 
            AND companyId = @companyId
            AND prodCategoryId = @prodCategoryId

        IF @nextNum IS NULL
        BEGIN
            DECLARE @prefix VARCHAR(3) = (SELECT prodCategoryCode FROM md_InventoryCategory WHERE prodCategoryId = @prodCategoryId);

            INSERT INTO md_ItemCode(companyId, condition, prodCategoryId, prodSubCategoryId, ItemFormat, FormatIndex, NextNum, MaxNum)
            SELECT @companyId, @keyID, @prodCategoryId, 0, @prefix + '.' + 'XXX', 1, 1, 999

            SET @nextNum = 1
            SET @ItemFormat =  @prefix + '.' + 'XXX'
        END
        ELSE
        BEGIN
            DECLARE @subi INT = 1, @subj INT = 1

            SET @StringFormat = REPLACE(@ItemFormat, 'xxx', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))

            WHILE (@subi = @subj)
            BEGIN
                IF (SELECT COUNT(1) FROM md_InventoryCategory WHERE prodCategoryParentId = @prodCategoryId AND companyId = @companyId AND prodCategoryCode = @StringFormat) > 0
                BEGIN
                    UPDATE MD_itemCode SET
                        NextNum = NextNum + 1
                    WHERE condition = @keyID
                        AND companyId = @companyId 
                        AND prodCategoryId = @prodCategoryId 
                        
                    SET @NextNum = @NextNum + 1

                    SET @StringFormat = REPLACE(@ItemFormat, 'XXX', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))
                END
                ELSE
                BEGIN 
                    SET @subj = @subi + 999
                END
            END
        END
 
        SET @StringFormat = REPLACE(@ItemFormat, 'XXX', RIGHT('000' + CONVERT(NVARCHAR, @nextNum), 3))

    END

    IF @keyID = 'ITEMCODE'
    BEGIN
		SELECT @NextNum = NextNum, @FormatIndex = FormatIndex, @MaxNum=MaxNum, @ItemFormat=ItemFormat
		FROM MD_itemCode WITH (TABLOCKX)
		WHERE condition =  @keyID 
            AND companyId = @companyId
            AND prodCategoryId = @prodCategoryId
            AND prodSubCategoryId = @prodSubCategoryId
 
        IF @nextNum IS NULL
        BEGIN
            DECLARE @grouprefix VARCHAR(3) = (SELECT prodCategoryCode FROM md_InventoryCategory WHERE prodCategoryId = @prodCategoryId);
            DECLARE @itemprefix VARCHAR(16) = (SELECT prodCategoryCode FROM md_InventoryCategory WHERE prodCategoryId = @prodSubCategoryId);

            INSERT INTO md_ItemCode(companyId, condition, prodCategoryId, prodSubCategoryId, ItemFormat, FormatIndex, NextNum, MaxNum)
            SELECT @companyId, @keyID, @prodCategoryId, @prodSubCategoryId, @itemprefix + '.' + 'XXXX', 1, 1, 9999

            SET @nextNum = 1
            SET @ItemFormat =  @itemprefix + '.' + 'XXXX'
        END
        ELSE
        BEGIN
            DECLARE @itemi INT = 1, @itemj INT = 1

            SET @StringFormat = REPLACE(@ItemFormat, 'XXXX', RIGHT('0000' + CONVERT(NVARCHAR, @nextNum), 4))

            WHILE (@itemi = @itemj)
            BEGIN 
                IF (SELECT COUNT(1) FROM md_inventory WHERE productCategory = @prodCategoryId AND companyId = @companyId AND productSubCategory = @prodSubCategoryId AND itemCode = @StringFormat) > 0
                BEGIN
                    UPDATE MD_itemCode SET
                        NextNum = NextNum + 1
                    WHERE condition = @keyID
                        AND companyId = @companyId 
                        AND prodCategoryId = @prodCategoryId
                        AND prodSubCategoryId = @prodSubCategoryId

                    SET @NextNum = @NextNum + 1

                    SET @StringFormat = REPLACE(@ItemFormat, 'XXXX', RIGHT('0000' + CONVERT(NVARCHAR, @nextNum), 4))
                END
                ELSE
                BEGIN 
                    SET @itemj = @itemi + 999
                END
            END
        END
 
        SET @StringFormat = REPLACE(@ItemFormat, 'XXXX', RIGHT('0000' + CONVERT(NVARCHAR, @nextNum), 4))

    END
END

GO

