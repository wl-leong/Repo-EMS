CREATE TABLE [dbo].[md_EmailCategory] (
    [emailCategoryId] INT          IDENTITY (1, 1) NOT NULL,
    [emailCategory]   VARCHAR (50) NOT NULL,
    [actionName]      VARCHAR (30) NULL,
    [status]          INT          CONSTRAINT [DF_md_EmailCategory_status] DEFAULT ((1)) NOT NULL,
    [enterBy]         VARCHAR (20) CONSTRAINT [DF_md_EmailCategory_enterBy] DEFAULT ('') NOT NULL,
    [enterDate]       DATETIME     CONSTRAINT [DF_md_EmailCategory_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]        VARCHAR (20) CONSTRAINT [DF_md_EmailCategory_updateBy] DEFAULT ('') NOT NULL,
    [updateDate]      DATETIME     CONSTRAINT [DF_md_EmailCategory_updateDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_EmailCategory_emailCategoryId] PRIMARY KEY CLUSTERED ([emailCategoryId] ASC)
);


GO

