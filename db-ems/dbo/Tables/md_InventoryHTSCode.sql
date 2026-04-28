CREATE TABLE [dbo].[md_InventoryHTSCode] (
    [HTSCodeId]              BIGINT       IDENTITY (1, 1) NOT NULL,
    [companyId]              INT          NOT NULL,
    [HTSCode_prodCategoryId] BIGINT       NOT NULL,
    [HTSCode_CountryCode]    VARCHAR (10) NOT NULL,
    [HTSCode]                VARCHAR (50) NULL,
    [createDate]             DATETIME     CONSTRAINT [DF_md_InventoryHTSCode_createDate] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_md_InventoryHTSCode] PRIMARY KEY CLUSTERED ([HTSCodeId] ASC)
);


GO

