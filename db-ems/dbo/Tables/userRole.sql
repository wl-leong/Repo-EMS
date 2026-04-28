CREATE TABLE [dbo].[userRole] (
    [userRoleId]            INT IDENTITY (1, 1) NOT NULL,
    [userId]                INT CONSTRAINT [DF__userrole__userId__7E37BEF6] DEFAULT (NULL) NULL,
    [userrolecompanyroleid] INT CONSTRAINT [DF__userrole__userro__7F2BE32F] DEFAULT (NULL) NULL,
    [userdefaultId]         INT NOT NULL,
    CONSTRAINT [PK_userrole] PRIMARY KEY CLUSTERED ([userRoleId] ASC)
);


GO

