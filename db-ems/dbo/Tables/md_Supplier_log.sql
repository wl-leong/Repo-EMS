CREATE TABLE [dbo].[md_Supplier_log] (
    [supplierLogId]                    INT           IDENTITY (1, 1) NOT NULL,
    [supplierorgId]                    BIGINT        NULL,
    [companyId]                        INT           NOT NULL,
    [internal_branchId]                INT           CONSTRAINT [DF_md_Supplier_log_internal_branchId] DEFAULT ((0)) NOT NULL,
    [supplierCompanyName]              VARCHAR (255) NOT NULL,
    [supplierCompanyRegno]             VARCHAR (20)  CONSTRAINT [DF_md_Supplier_log_supplierCompanyRegno] DEFAULT ('') NOT NULL,
    [supplierAddressName]              VARCHAR (255) CONSTRAINT [DF_md_Supplier_log_supplierAddressName] DEFAULT ('') NOT NULL,
    [supplierAddress]                  VARCHAR (200) CONSTRAINT [DF_md_Supplier_log_supplierAddress] DEFAULT ('') NOT NULL,
    [supplierAddressLine2]             VARCHAR (200) CONSTRAINT [DF_md_Supplier_log_supplierAddressLine2] DEFAULT ('') NOT NULL,
    [supplierCity]                     VARCHAR (50)  NOT NULL,
    [supplierStates]                   VARCHAR (20)  CONSTRAINT [DF_md_Supplier_log_supplierStates] DEFAULT ('') NOT NULL,
    [supplierPostcode]                 VARCHAR (10)  CONSTRAINT [DF_md_Supplier_log_supplierPostcode] DEFAULT ('') NOT NULL,
    [supplierCountry]                  INT           CONSTRAINT [DF_md_Supplier_log_supplierCountry] DEFAULT ((0)) NOT NULL,
    [supplierContactNumber]            VARCHAR (20)  CONSTRAINT [DF_md_Supplier_log_supplierContactNumber] DEFAULT ('') NOT NULL,
    [supplierFaxNumber]                VARCHAR (20)  CONSTRAINT [DF_md_Supplier_log_supplierFaxNumber] DEFAULT ('') NOT NULL,
    [supplierEmail]                    VARCHAR (100) CONSTRAINT [DF_md_Supplier_log_supplierEmail] DEFAULT ('') NOT NULL,
    [supplierContactPerson]            VARCHAR (100) CONSTRAINT [DF_md_Supplier_log_supplierContactPerson] DEFAULT ('') NOT NULL,
    [supplierContactPersonPhoneNumber] VARCHAR (20)  CONSTRAINT [DF_md_Supplier_log_supplierContactPersonPhoneNumber] DEFAULT ('') NOT NULL,
    [supplierContactPersonEmail]       VARCHAR (100) CONSTRAINT [DF_md_Supplier_log_supplierContactPersonEmail] DEFAULT ('') NOT NULL,
    [paymentTerm]                      INT           CONSTRAINT [DF_md_Supplier_log_paymentTerm] DEFAULT ((0)) NOT NULL,
    [status]                           INT           CONSTRAINT [DF_md_Supplier_log_status] DEFAULT ('1') NOT NULL,
    [supplierCreateDateTime]           DATETIME      CONSTRAINT [DF__md_Supplier_log_createDateTime] DEFAULT (getdate()) NOT NULL,
    [actiontype]                       VARCHAR (10)  NULL,
    [logDate]                          DATETIME      CONSTRAINT [DF__md_Suppli__logDa__062DE679] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_md_supplier_log] PRIMARY KEY CLUSTERED ([supplierLogId] ASC)
);


GO

