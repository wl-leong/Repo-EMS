CREATE TABLE [dbo].[md_Role] (
    [roleId]          INT           IDENTITY (1, 1) NOT NULL,
    [roleName]        VARCHAR (50)  CONSTRAINT [DF__md_Role__roleNam__66603565] DEFAULT (NULL) NULL,
    [roleRemarks]     VARCHAR (255) NOT NULL,
    [status]          INT           CONSTRAINT [DF__md_Role__status__6754599E] DEFAULT ('1') NOT NULL,
    [createdDateTime] DATETIME      CONSTRAINT [DF__md_Role__created__68487DD7] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_Role] PRIMARY KEY CLUSTERED ([roleId] ASC)
);


GO

