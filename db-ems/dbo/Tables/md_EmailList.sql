CREATE TABLE [dbo].[md_EmailList] (
    [emailListId]     INT           IDENTITY (1, 1) NOT NULL,
    [companyId]       INT           NOT NULL,
    [emailCategoryId] INT           NOT NULL,
    [emailAddress]    VARCHAR (100) NOT NULL,
    [status]          INT           CONSTRAINT [DF_md_EmailList_status] DEFAULT ((1)) NOT NULL,
    [enterBy]         VARCHAR (20)  CONSTRAINT [DF__md_EmailL__enter__67D447E2] DEFAULT ('') NOT NULL,
    [enterDate]       DATETIME      CONSTRAINT [DF__md_EmailL__enter__68C86C1B] DEFAULT (getdate()) NOT NULL,
    [updateBy]        VARCHAR (20)  CONSTRAINT [DF__md_EmailL__updat__69BC9054] DEFAULT ('') NOT NULL,
    [updateDate]      DATETIME      CONSTRAINT [DF__md_EmailL__updat__6AB0B48D] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_EmailList_emailListId] PRIMARY KEY CLUSTERED ([emailListId] ASC)
);


GO

