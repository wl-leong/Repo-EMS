CREATE TABLE [dbo].[md_Supplier] (
    [supplierId]                       INT           IDENTITY (1, 1) NOT NULL,
    [companyId]                        INT           NOT NULL,
    [internal_branchId]                INT           CONSTRAINT [DF_md_Supplier_internal_branchId] DEFAULT ((0)) NOT NULL,
    [supplierCompanyName]              VARCHAR (255) NOT NULL,
    [supplierCompanyRegno]             VARCHAR (20)  CONSTRAINT [DF_md_Supplier_supplierCompanyRegno] DEFAULT ('') NOT NULL,
    [supplierAddressName]              VARCHAR (255) CONSTRAINT [DF_md_Supplier_supplierAddressName] DEFAULT ('') NOT NULL,
    [supplierAddress]                  VARCHAR (200) CONSTRAINT [DF_md_Supplier_supplierAddress] DEFAULT ('') NOT NULL,
    [supplierAddressLine2]             VARCHAR (200) CONSTRAINT [DF_md_Supplier_supplierAddressLine2] DEFAULT ('') NOT NULL,
    [supplierCity]                     VARCHAR (50)  NOT NULL,
    [supplierStates]                   VARCHAR (20)  CONSTRAINT [DF_md_Supplier_supplierStates] DEFAULT ('') NOT NULL,
    [supplierPostcode]                 VARCHAR (10)  CONSTRAINT [DF_md_Supplier_supplierPostcode] DEFAULT ('') NOT NULL,
    [supplierCountry]                  INT           CONSTRAINT [DF_md_Supplier_supplierCountry] DEFAULT ((0)) NOT NULL,
    [supplierContactNumber]            VARCHAR (20)  CONSTRAINT [DF_md_Supplier_supplierContactNumber] DEFAULT ('') NOT NULL,
    [supplierFaxNumber]                VARCHAR (20)  CONSTRAINT [DF_md_Supplier_supplierFaxNumber] DEFAULT ('') NOT NULL,
    [supplierEmail]                    VARCHAR (100) CONSTRAINT [DF_md_Supplier_supplierEmail] DEFAULT ('') NOT NULL,
    [supplierContactPerson]            VARCHAR (100) CONSTRAINT [DF_md_Supplier_supplierContactPerson] DEFAULT ('') NOT NULL,
    [supplierContactPersonPhoneNumber] VARCHAR (20)  CONSTRAINT [DF_md_Supplier_supplierContactPersonPhoneNumber] DEFAULT ('') NOT NULL,
    [supplierContactPersonEmail]       VARCHAR (100) CONSTRAINT [DF_md_Supplier_supplierContactPersonEmail] DEFAULT ('') NOT NULL,
    [currencyCode]                     INT           NULL,
    [paymentTerm]                      INT           CONSTRAINT [DF_md_Supplier_paymentTerm] DEFAULT ((0)) NOT NULL,
    [status]                           INT           CONSTRAINT [DF__md_Suppli__statu__6A30C649] DEFAULT ('1') NOT NULL,
    [supplierCreateDateTime]           DATETIME      CONSTRAINT [DF__md_Suppli__suppl__6B24EA82] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_Supplier] PRIMARY KEY CLUSTERED ([supplierId] ASC)
);


GO

