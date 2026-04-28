CREATE TABLE [dbo].[md_MenuLevel1] (
    [menuLevel1Id]    INT          IDENTITY (1, 1) NOT NULL,
    [menuLevel0Id]    INT          CONSTRAINT [DF__md_MenuLe__menuL__59FA5E80] DEFAULT (NULL) NULL,
    [menuLevel1Name]  VARCHAR (50) CONSTRAINT [DF__md_MenuLe__menuL__5AEE82B9] DEFAULT (NULL) NULL,
    [status]          INT          CONSTRAINT [DF__md_MenuLe__statu__5BE2A6F2] DEFAULT ('1') NOT NULL,
    [createdDateTime] DATETIME     CONSTRAINT [DF__md_MenuLe__creat__5CD6CB2B] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_MenuLevel1] PRIMARY KEY CLUSTERED ([menuLevel1Id] ASC)
);


GO

