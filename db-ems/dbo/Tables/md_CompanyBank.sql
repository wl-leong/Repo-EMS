CREATE TABLE [dbo].[md_CompanyBank] (
    [bankId]              INT           IDENTITY (1, 1) NOT NULL,
    [companyId]           INT           NOT NULL,
    [bankName]            VARCHAR (100) NOT NULL,
    [AccountName]         VARCHAR (100) NOT NULL,
    [AccountNumber]       VARCHAR (50)  NOT NULL,
    [swiftCode]           VARCHAR (10)  NOT NULL,
    [bankAddressLine1]    VARCHAR (100) NOT NULL,
    [bankAddressLine2]    VARCHAR (100) NOT NULL,
    [bankAddressCity]     VARCHAR (50)  NOT NULL,
    [bankAddressState]    VARCHAR (50)  NOT NULL,
    [bankAddressPostCode] VARCHAR (50)  NOT NULL,
    [bankAddressCountry]  INT           NOT NULL,
    [statusFlag]          INT           CONSTRAINT [DEFAULT_md_CompanyBank_statusFlag] DEFAULT ((1)) NOT NULL,
    [enterBy]             INT           NOT NULL,
    [enterDate]           DATETIME      CONSTRAINT [DF_md_companyBank_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]            INT           NULL,
    [updateDate]          DATETIME      NULL
);


GO

