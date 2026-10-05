CREATE TABLE [dbo].[md_MasterCategoryAttribute] (
    [attributeId]      INT          IDENTITY (1, 1) NOT NULL,
    [masterCategoryId] INT          NOT NULL,
    [attributeName]    VARCHAR (20) NOT NULL,
    [attributeValue]   VARCHAR (50) NOT NULL,
    [statusFlag]       INT          CONSTRAINT [DF_md_MasterCategoryAttribute_statusFlag] DEFAULT ((1)) NOT NULL,
    [enterBy]          INT          NOT NULL,
    [enterDate]        DATETIME     CONSTRAINT [DF_ContainerAttribute_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]         INT          NULL,
    [updateDate]       DATETIME     NULL,
    CONSTRAINT [PK_md_MasterCategoryAttribute] PRIMARY KEY CLUSTERED ([attributeId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_md_MasterCategoryAttribute_masterCategoryId]
    ON [dbo].[md_MasterCategoryAttribute]([masterCategoryId] ASC);


GO

