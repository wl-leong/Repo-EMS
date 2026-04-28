CREATE TABLE [dbo].[inventoryCategory_temp] (
    [prodCategoryId]       INT           IDENTITY (1, 1) NOT NULL,
    [companyId]            INT           NULL,
    [prodCategoryName]     VARCHAR (255) NULL,
    [prodCategoryCode]     VARCHAR (50)  NULL,
    [prodCategoryParentID] INT           NULL,
    [prodCategoryRemarks]  VARCHAR (255) NULL,
    [status]               INT           NULL,
    [isBom]                BIT           NOT NULL,
    [createDate]           DATETIME      NOT NULL,
    [isBuffer]             INT           NOT NULL
);


GO

