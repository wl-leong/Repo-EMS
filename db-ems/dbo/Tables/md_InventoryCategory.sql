CREATE TABLE [dbo].[md_InventoryCategory] (
    [prodCategoryId]       INT           IDENTITY (1, 1) NOT NULL,
    [companyId]            INT           NULL,
    [prodCategoryName]     VARCHAR (255) NULL,
    [prodCategoryCode]     VARCHAR (10)  NULL,
    [prodCategoryParentID] INT           NULL,
    [prodCategoryRemarks]  VARCHAR (255) NULL,
    [status]               INT           NULL,
    [isBom]                BIT           CONSTRAINT [DF_md_InventoryCategory_isBom] DEFAULT ((0)) NOT NULL,
    [isBuffer]             INT           CONSTRAINT [DF_md_InventoryCategory_isBuffer] DEFAULT ((0)) NOT NULL,
    [createDate]           DATETIME      CONSTRAINT [DF_md_InventoryCategory_createDate] DEFAULT (getdate()) NOT NULL,
    [enterBy]              INT           NULL,
    [updateDate]           DATETIME      NULL,
    [updateBy]             INT           NULL,
    CONSTRAINT [PK_md_InventoryCategory_1] PRIMARY KEY CLUSTERED ([prodCategoryId] ASC)
);


GO

