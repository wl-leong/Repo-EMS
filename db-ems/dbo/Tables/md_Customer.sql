CREATE TABLE [dbo].[md_Customer] (
    [customerId]             INT            IDENTITY (1, 1) NOT NULL,
    [companyId]              INT            NOT NULL,
    [internal_branchId]      INT            CONSTRAINT [DF_md_Customer_internal_branchId] DEFAULT ((0)) NOT NULL,
    [parent_customerId]      INT            CONSTRAINT [DEFAULT_md_Customer_parent_customerId] DEFAULT ((0)) NULL,
    [customerName]           VARCHAR (100)  NOT NULL,
    [customerShortCode]      VARCHAR (3)    NOT NULL,
    [customerAddressName]    VARCHAR (200)  NOT NULL,
    [customerAddress]        VARCHAR (200)  CONSTRAINT [DF_md_Customer_customerAddress] DEFAULT ('') NOT NULL,
    [customerAddressLine2]   VARCHAR (200)  CONSTRAINT [DF_md_Customer_customerAddressLine2] DEFAULT ('') NOT NULL,
    [customerCity]           VARCHAR (50)   NOT NULL,
    [customerStates]         VARCHAR (50)   NOT NULL,
    [customerPostcode]       VARCHAR (10)   NOT NULL,
    [customerCountry]        INT            NOT NULL,
    [customerContactNumber]  VARCHAR (20)   CONSTRAINT [DF_md_Customer_customerContactNumber] DEFAULT ('') NOT NULL,
    [customerMobileNumber]   VARCHAR (20)   CONSTRAINT [DF_md_Customer_customerMobileNumber] DEFAULT ('') NOT NULL,
    [customerFaxNumber]      VARCHAR (20)   CONSTRAINT [DF_md_Customer_customerFaxNumber] DEFAULT ('') NOT NULL,
    [customerEmail]          VARCHAR (100)  CONSTRAINT [DF_md_Customer_customerEmail] DEFAULT ('') NOT NULL,
    [paymentTerm]            INT            CONSTRAINT [DF_md_Customer_paymentTerm] DEFAULT ((0)) NOT NULL,
    [status]                 INT            CONSTRAINT [DF__md_Custom__statu__3D5E1FD2] DEFAULT ('1') NOT NULL,
    [customerCreateDateTime] DATETIME       CONSTRAINT [DF__md_Custom__custo__3E52440B] DEFAULT (getdate()) NOT NULL,
    [transportMetaJson]      NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_md_Customer] PRIMARY KEY CLUSTERED ([customerId] ASC),
    CONSTRAINT [FK_md_Customer_md_Company] FOREIGN KEY ([companyId]) REFERENCES [dbo].[md_Company] ([companyId])
);


GO

