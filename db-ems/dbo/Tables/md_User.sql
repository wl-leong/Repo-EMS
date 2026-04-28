CREATE TABLE [dbo].[md_User] (
    [userId]            INT           IDENTITY (1, 1) NOT NULL,
    [useLoginId]        VARCHAR (255) CONSTRAINT [DF__md_user__useLogi__72C60C4A] DEFAULT (NULL) NULL,
    [userPassword]      VARCHAR (255) CONSTRAINT [DF__md_user__userPas__73BA3083] DEFAULT (NULL) NULL,
    [userName]          VARCHAR (255) CONSTRAINT [DF__md_user__userNam__74AE54BC] DEFAULT (NULL) NULL,
    [contactNumber]     VARCHAR (50)  CONSTRAINT [DF__md_user__contact__75A278F5] DEFAULT (NULL) NULL,
    [userGender]        VARCHAR (5)   CONSTRAINT [DF__md_user__userGen__76969D2E] DEFAULT (NULL) NULL,
    [userBirthday]      DATE          CONSTRAINT [DF__md_user__userBir__778AC167] DEFAULT (NULL) NULL,
    [loginCount]        INT           CONSTRAINT [DF__md_user__loginCo__787EE5A0] DEFAULT ('0') NOT NULL,
    [lastLoginDateTime] DATETIME      CONSTRAINT [DF__md_user__lastLog__797309D9] DEFAULT (NULL) NULL,
    [userStatus]        INT           CONSTRAINT [DF__md_user__userSta__7A672E12] DEFAULT ('1') NOT NULL,
    [createdDateTime]   DATETIME      CONSTRAINT [DF__md_user__created__7B5B524B] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_user] PRIMARY KEY CLUSTERED ([userId] ASC)
);


GO

