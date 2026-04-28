CREATE TABLE [dbo].[md_SupplierSku] (
    [supplierskuId]  INT             IDENTITY (1, 1) NOT NULL,
    [invId]          BIGINT          NOT NULL,
    [supplierId]     INT             NOT NULL,
    [companyId]      INT             NOT NULL,
    [supplierSku]    VARCHAR (50)    NOT NULL,
    [itemDesc]       VARCHAR (500)   CONSTRAINT [DF_md_SupplierSku_itemDesc] DEFAULT ('') NULL,
    [currencyCode]   INT             CONSTRAINT [DF_md_SupplierSku_currencyCode] DEFAULT ((0)) NOT NULL,
    [supCost]        NUMERIC (18, 4) CONSTRAINT [DF_md_SupplierSku_supCost] DEFAULT ((0)) NOT NULL,
    [moq]            INT             CONSTRAINT [DF_md_SupplierSku_mou] DEFAULT ((1)) NOT NULL,
    [isDefault]      INT             NOT NULL,
    [statusflag]     INT             NOT NULL,
    [createDateTime] DATETIME        CONSTRAINT [DF__md_Suppli__creat__6D0D32F4] DEFAULT (getdate()) NOT NULL,
    [enterBy]        INT             NOT NULL,
    [updateDateTime] DATETIME        CONSTRAINT [DF__md_Suppli__updat__6E01572D] DEFAULT (getdate()) NOT NULL,
    [updateBy]       INT             NOT NULL,
    CONSTRAINT [PK_md_SupplierSku] PRIMARY KEY CLUSTERED ([supplierskuId] ASC),
    CONSTRAINT [FK_md_SupplierSku_md_Inventory] FOREIGN KEY ([invId]) REFERENCES [dbo].[md_Inventory] ([invID]),
    CONSTRAINT [FK_md_SupplierSku_md_Supplier] FOREIGN KEY ([supplierId]) REFERENCES [dbo].[md_Supplier] ([supplierId])
);


GO

