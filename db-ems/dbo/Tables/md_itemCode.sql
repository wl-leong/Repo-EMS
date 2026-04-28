CREATE TABLE [dbo].[md_itemCode] (
    [Id]                INT          IDENTITY (1, 1) NOT NULL,
    [companyId]         INT          NOT NULL,
    [prodCategoryId]    INT          NOT NULL,
    [prodSubCategoryId] INT          NULL,
    [condition]         VARCHAR (50) NOT NULL,
    [ItemFormat]        VARCHAR (50) NOT NULL,
    [FormatIndex]       INT          NOT NULL,
    [NextNum]           INT          NOT NULL,
    [MaxNum]            INT          NOT NULL,
    CONSTRAINT [PK_md_itemCode] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO

