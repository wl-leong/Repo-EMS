CREATE TABLE [dbo].[md_Customer_Log] (
    [customerLogId]          INT           IDENTITY (1, 1) NOT NULL,
    [customerOrgId]          INT           NOT NULL,
    [companyId]              INT           NOT NULL,
    [internal_branchId]      INT           CONSTRAINT [DF_md_Customer_log_internal_branchId] DEFAULT ((0)) NULL,
    [customerName]           VARCHAR (100) NULL,
    [customerShortCode]      VARCHAR (3)   NULL,
    [customerAddressName]    VARCHAR (200) NULL,
    [customerAddress]        VARCHAR (200) CONSTRAINT [DF_md_Customer_log_customerAddress] DEFAULT ('') NULL,
    [customerAddressLine2]   VARCHAR (200) CONSTRAINT [DF_md_Customer_log_customerAddressLine2] DEFAULT ('') NULL,
    [customerCity]           VARCHAR (50)  NULL,
    [customerStates]         VARCHAR (50)  NULL,
    [customerPostcode]       VARCHAR (10)  NULL,
    [customerCountry]        INT           NULL,
    [customerContactNumber]  VARCHAR (20)  CONSTRAINT [DF_md_Customer_log_customerContactNumber] DEFAULT ('') NULL,
    [customerMobileNumber]   VARCHAR (20)  CONSTRAINT [DF_md_Customer_log_customerMobileNumber] DEFAULT ('') NULL,
    [customerFaxNumber]      VARCHAR (20)  CONSTRAINT [DF_md_Customer_log_customerFaxNumber] DEFAULT ('') NULL,
    [customerEmail]          VARCHAR (100) CONSTRAINT [DF_md_Customer_log_customerEmail] DEFAULT ('') NULL,
    [paymentTerm]            INT           CONSTRAINT [DF_md_Customer_log_paymentTerm] DEFAULT ((0)) NULL,
    [status]                 INT           CONSTRAINT [DF_md_Customer_log_status] DEFAULT ('1') NULL,
    [customerCreateDateTime] DATETIME      CONSTRAINT [DF_md_Customer_log_createDateTime] DEFAULT (getdate()) NULL,
    [actiontype]             VARCHAR (10)  NULL,
    [logDate]                DATETIME      CONSTRAINT [DF__md_Custom__logDa__7ABC33CD] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_md_Customer_log] PRIMARY KEY CLUSTERED ([customerLogId] ASC)
);


GO

