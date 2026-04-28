CREATE TABLE [dbo].[md_Warehouse] (
    [warehouseId]     INT           IDENTITY (1, 1) NOT NULL,
    [companyId]       INT           NOT NULL,
    [locNo]           VARCHAR (20)  CONSTRAINT [DF_md_Warehouse_locNo] DEFAULT ('') NOT NULL,
    [label]           VARCHAR (20)  NOT NULL,
    [address]         VARCHAR (255) NULL,
    [addressLine2]    VARCHAR (255) NULL,
    [city]            VARCHAR (50)  NULL,
    [state]           VARCHAR (50)  NULL,
    [postcode]        VARCHAR (10)  NULL,
    [countryId]       INT           NULL,
    [phone]           VARCHAR (20)  NULL,
    [fax]             VARCHAR (20)  NULL,
    [emailAddress]    VARCHAR (100) NULL,
    [status]          BIT           CONSTRAINT [DF_md_Warehouse_status] DEFAULT ((1)) NOT NULL,
    [createdDateTime] DATETIME      CONSTRAINT [DF_md_Warehouse_createdDateTime] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_md_Warehouse] PRIMARY KEY CLUSTERED ([warehouseId] ASC),
    CONSTRAINT [FK_md_Warehouse_md_Company] FOREIGN KEY ([companyId]) REFERENCES [dbo].[md_Company] ([companyId])
);


GO

