CREATE TABLE [dbo].[md_MenuLevel2] (
    [menuLevel2Id]         INT           IDENTITY (1, 1) NOT NULL,
    [menuLevel1Id]         INT           CONSTRAINT [DF__md_MenuLe__menuL__5EBF139D] DEFAULT (NULL) NULL,
    [menuLevel2Name]       VARCHAR (50)  CONSTRAINT [DF__md_MenuLe__menuL__5FB337D6] DEFAULT (NULL) NULL,
    [menuLevel2PageFolder] VARCHAR (150) CONSTRAINT [DF__md_MenuLe__menuL__60A75C0F] DEFAULT (NULL) NULL,
    [status]               INT           CONSTRAINT [DF__md_MenuLe__statu__619B8048] DEFAULT ('1') NOT NULL,
    [createdDateTime]      DATETIME      CONSTRAINT [DF__md_MenuLe__creat__628FA481] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_MenuLevel2] PRIMARY KEY CLUSTERED ([menuLevel2Id] ASC)
);


GO

