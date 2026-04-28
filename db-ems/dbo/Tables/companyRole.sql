CREATE TABLE [dbo].[companyRole] (
    [companyRoleId]   INT      IDENTITY (1, 1) NOT NULL,
    [companyId]       INT      CONSTRAINT [DF__companyRo__compa__29221CFB] DEFAULT (NULL) NULL,
    [roleId]          INT      CONSTRAINT [DF__companyRo__roleI__2A164134] DEFAULT (NULL) NULL,
    [createdDateTime] DATETIME CONSTRAINT [DF__companyRo__creat__2B0A656D] DEFAULT (getdate()) NOT NULL,
    [status]          INT      CONSTRAINT [DF__companyRo__statu__2BFE89A6] DEFAULT ('1') NOT NULL,
    CONSTRAINT [PK__companyR__3F28C341F89F751B] PRIMARY KEY CLUSTERED ([companyRoleId] ASC)
);


GO

