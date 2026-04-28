CREATE TABLE [dbo].[md_CustomerSku] (
    [customerskuId]  INT             IDENTITY (1, 1) NOT NULL,
    [invID]          BIGINT          NOT NULL,
    [customerId]     INT             NOT NULL,
    [companyId]      INT             NOT NULL,
    [customerSku]    VARCHAR (30)    NOT NULL,
    [merchantSKU]    VARCHAR (30)    CONSTRAINT [DF_md_CustomerSku_merchantSKU] DEFAULT ('') NOT NULL,
    [EAN]            VARCHAR (50)    CONSTRAINT [DF_md_CustomerSku_VSN] DEFAULT ('') NOT NULL,
    [itemDesc]       NVARCHAR (2500) NULL,
    [currencyCode]   INT             CONSTRAINT [DF_md_CustomerSku_currencyCode] DEFAULT ((0)) NOT NULL,
    [csCost]         NUMERIC (19, 4) CONSTRAINT [DF_md_CustomerSku_csCost] DEFAULT ((0)) NULL,
    [tagDivision]    INT             CONSTRAINT [DF_md_CustomerSku_tagDivision] DEFAULT ((3234)) NULL,
    [statusflag]     INT             CONSTRAINT [DF_md_CustomerSku_statusflag] DEFAULT ((1)) NOT NULL,
    [feedstartDate]  DATE            NULL,
    [feedingEndDate] DATE            NULL,
    [enterBy]        INT             NOT NULL,
    [createDateTime] DATETIME        CONSTRAINT [DF__md_custom__creat__403A8C7D] DEFAULT (getdate()) NOT NULL,
    [updateBy]       INT             NOT NULL,
    [updateDateTime] DATETIME        CONSTRAINT [DF_customerSku_updateDateTime] DEFAULT (getdate()) NOT NULL,
    [cartonMaterial] BIGINT          NULL,
    [qtyPerCarton]   INT             NULL,
    CONSTRAINT [PK_md_CustomerSku] PRIMARY KEY CLUSTERED ([customerskuId] ASC),
    CONSTRAINT [FK_md_CustomerSku_md_Customer] FOREIGN KEY ([customerId]) REFERENCES [dbo].[md_Customer] ([customerId]),
    CONSTRAINT [FK_md_CustomerSku_md_Inventory] FOREIGN KEY ([invID]) REFERENCES [dbo].[md_Inventory] ([invID])
);


GO

