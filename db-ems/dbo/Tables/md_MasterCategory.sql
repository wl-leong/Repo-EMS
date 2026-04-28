CREATE TABLE [dbo].[md_MasterCategory] (
    [categoryId]       INT           IDENTITY (1, 1) NOT NULL,
    [categoryName]     VARCHAR (255) CONSTRAINT [DF__md_Master__categ__52593CB8] DEFAULT (NULL) NULL,
    [categoryParentID] INT           CONSTRAINT [DF__md_Master__categ__534D60F1] DEFAULT ('0') NULL,
    [categoryRemarks]  VARCHAR (255) NOT NULL,
    [status]           INT           CONSTRAINT [DF__md_Master__statu__5441852A] DEFAULT ('1') NOT NULL,
    CONSTRAINT [PK_md_MasterCategory] PRIMARY KEY CLUSTERED ([categoryId] ASC)
);


GO

