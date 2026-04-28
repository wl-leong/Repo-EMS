CREATE TABLE [dbo].[md_inventoryType] (
    [inventoryTypeId]  INT           IDENTITY (1, 1) NOT NULL,
    [inventoryType]    VARCHAR (255) NOT NULL,
    [inventoryCode]    VARCHAR (3)   NULL,
    [status]           BIT           NULL,
    [prodCategoryId]   INT           NULL,
    [namingConvention] VARCHAR (200) NULL,
    CONSTRAINT [PK_md_inventoryType] PRIMARY KEY CLUSTERED ([inventoryTypeId] ASC),
    CONSTRAINT [FK_md_inventoryType_md_InventoryCategory] FOREIGN KEY ([prodCategoryId]) REFERENCES [dbo].[md_InventoryCategory] ([prodCategoryId])
);


GO

-- =============================================
-- Author:		WL Leong
-- Create date: 2025-12-16
-- Description:	Update to default naming if the inventoryType belongs to factory finished good
-- Used By:		inserted new rows in inventoryType

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-12-16	1.0			WL Leong	Initial 
-- =============================================
CREATE TRIGGER tgr_insert_inventoryType_factory
   ON md_inventoryType
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;

    UPDATE t
    SET namingConvention = '[modelno]+[space]+[color]+[space]+[inventorytype]+[,][space]+[colorname]'
    FROM md_inventoryType AS t
		INNER JOIN inserted AS i
			ON t.inventoryTypeId = i.inventoryTypeId
    WHERE t.prodCategoryId IN (
        SELECT prodCategoryid 
        FROM md_inventoryCategory 
        WHERE companyId = 4 
          AND prodCategoryParentId = 3
    );
END

GO

