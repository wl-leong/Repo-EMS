CREATE TABLE [dbo].[md_Company] (
    [companyId]                INT           IDENTITY (1, 1) NOT NULL,
    [typeId]                   INT           CONSTRAINT [DF__md_Compan__typeI__2F10007B] DEFAULT (NULL) NOT NULL,
    [companyName]              VARCHAR (100) CONSTRAINT [DF__md_Compan__compa__300424B4] DEFAULT ('') NOT NULL,
    [companyShortCode]         VARCHAR (3)   CONSTRAINT [DF_md_Company_companyShortCode] DEFAULT ('') NOT NULL,
    [registerNo]               VARCHAR (50)  CONSTRAINT [DF__md_Compan__regis__30F848ED] DEFAULT ('') NOT NULL,
    [address]                  VARCHAR (200) NOT NULL,
    [addressLine2]             VARCHAR (200) CONSTRAINT [DF_md_Company_addressLine2] DEFAULT ('') NOT NULL,
    [city]                     VARCHAR (50)  CONSTRAINT [DF__md_Company__city__32E0915F] DEFAULT ('') NOT NULL,
    [state]                    VARCHAR (50)  CONSTRAINT [DF__md_Compan__state__33D4B598] DEFAULT (NULL) NOT NULL,
    [postcode]                 VARCHAR (20)  CONSTRAINT [DF__md_Compan__postc__31EC6D26] DEFAULT (NULL) NOT NULL,
    [country]                  INT           CONSTRAINT [DF__md_Compan__count__34C8D9D1] DEFAULT (NULL) NOT NULL,
    [telephoneNumber]          VARCHAR (50)  CONSTRAINT [DF__md_Compan__telep__35BCFE0A] DEFAULT ('') NOT NULL,
    [faxNumber]                VARCHAR (50)  CONSTRAINT [DF__md_Compan__faxNu__36B12243] DEFAULT ('') NOT NULL,
    [websiteUrl]               VARCHAR (255) CONSTRAINT [DF__md_Compan__websi__37A5467C] DEFAULT ('') NOT NULL,
    [emailAddress]             VARCHAR (100) CONSTRAINT [DF__md_Compan__email__38996AB5] DEFAULT ('') NOT NULL,
    [contactPersonName]        VARCHAR (100) CONSTRAINT [DF__md_Compan__conta__398D8EEE] DEFAULT ('') NOT NULL,
    [contactPersonPhoneNumber] VARCHAR (50)  CONSTRAINT [DF_md_Company_contactPersonPhoneNumber] DEFAULT ('') NOT NULL,
    [contactPersonEmail]       VARCHAR (100) CONSTRAINT [DF_md_Company_contactPersonEmail] DEFAULT ('') NOT NULL,
    [companyBankId]            INT           NULL,
    [status]                   TINYINT       CONSTRAINT [DF__md_Compan__statu__3A81B327] DEFAULT ('1') NOT NULL,
    [createdDateTime]          DATETIME      CONSTRAINT [DF__md_Compan__creat__3B75D760] DEFAULT (getdate()) NOT NULL,
    [isMarketing]              BIT           CONSTRAINT [DF__md_Compan__isMar__6ADAD1BF] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_md_Company_1] PRIMARY KEY CLUSTERED ([companyId] ASC)
);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'1 active, 0 inactive', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'md_Company', @level2type = N'COLUMN', @level2name = N'status';


GO

