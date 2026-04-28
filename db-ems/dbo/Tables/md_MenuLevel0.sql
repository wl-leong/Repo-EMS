CREATE TABLE [dbo].[md_MenuLevel0] (
    [menuLevel0Id]    INT          IDENTITY (1, 1) NOT NULL,
    [menuLevel0Name]  VARCHAR (50) CONSTRAINT [DF__md_MenuLe__menuL__5629CD9C] DEFAULT (NULL) NULL,
    [menuLevel0icon]  VARCHAR (50) NOT NULL,
    [status]          INT          CONSTRAINT [DF__md_MenuLe__statu__571DF1D5] DEFAULT ('1') NOT NULL,
    [createdDateTime] DATETIME     CONSTRAINT [DF__md_MenuLe__creat__5812160E] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_MenuLevel0] PRIMARY KEY CLUSTERED ([menuLevel0Id] ASC)
);


GO

