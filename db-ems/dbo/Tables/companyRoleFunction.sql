CREATE TABLE [dbo].[companyRoleFunction] (
    [companyRoleFunctionId] INT      IDENTITY (1, 1) NOT NULL,
    [companyRoleId]         INT      CONSTRAINT [DF__companyRo__compa__286302EC] DEFAULT (NULL) NULL,
    [menuLevel2Id]          INT      CONSTRAINT [DF__companyRo__menuL__29572725] DEFAULT (NULL) NULL,
    [functionAdd]           INT      CONSTRAINT [DF__companyRo__funct__2A4B4B5E] DEFAULT ('0') NOT NULL,
    [functionEdit]          INT      CONSTRAINT [DF__companyRo__funct__2B3F6F97] DEFAULT ('0') NOT NULL,
    [functionDelete]        INT      CONSTRAINT [DF__companyRo__funct__2C3393D0] DEFAULT ('0') NOT NULL,
    [createdDateTime]       DATETIME CONSTRAINT [DF__companyRo__creat__2D27B809] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_companyRoleFunction] PRIMARY KEY CLUSTERED ([companyRoleFunctionId] ASC)
);


GO

