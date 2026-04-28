CREATE TABLE [dbo].[soLineItem] (
    [soLineItemId]       BIGINT          IDENTITY (1, 1) NOT NULL,
    [soheaderId]         BIGINT          NOT NULL,
    [invID]              INT             NOT NULL,
    [customerSkuId]      INT             NOT NULL,
    [customerSku]        VARCHAR (30)    NOT NULL,
    [currencyCode]       VARCHAR (3)     NULL,
    [csCost]             NUMERIC (19, 4) CONSTRAINT [DF_soLineItem_csCost] DEFAULT ((0)) NULL,
    [freightCost]        NUMERIC (19, 4) CONSTRAINT [DF_soLineItem_freightCost] DEFAULT ((0)) NULL,
    [isItemPriceChanged] BIT             CONSTRAINT [DF_soLineItem_isItemPriceChanged] DEFAULT ((0)) NOT NULL,
    [odrQty]             INT             CONSTRAINT [DF_soLineItem_odrQty] DEFAULT ((0)) NOT NULL,
    [poQty]              INT             CONSTRAINT [DF_soLineItem_poQty] DEFAULT ((0)) NOT NULL,
    [processQty]         INT             CONSTRAINT [DF_soLineItem_processQty] DEFAULT ((0)) NOT NULL,
    [shpQty]             INT             CONSTRAINT [DF_soLineItem_shpQty] DEFAULT ((0)) NOT NULL,
    [itemReference1]     VARCHAR (500)   CONSTRAINT [DF_soLineItem_itemReference1] DEFAULT ('') NOT NULL,
    [itemReference2]     VARCHAR (500)   CONSTRAINT [DF_soLineItem_itemReference2] DEFAULT ('') NOT NULL,
    [itemNote]           VARCHAR (5000)  CONSTRAINT [DF_soLineItem_itemNote] DEFAULT ('') NOT NULL,
    [soLineItemStatus]   INT             NOT NULL,
    [createBy]           INT             CONSTRAINT [DF_soLineItem_createBy] DEFAULT ('') NOT NULL,
    [createDate]         DATETIME        CONSTRAINT [DF_soLineItem_createDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]           INT             CONSTRAINT [DF_soLineItem_updateBy] DEFAULT ('') NOT NULL,
    [updateDate]         DATETIME        CONSTRAINT [DF_soLineItem_updateDate] DEFAULT (getdate()) NOT NULL,
    [merchantSku]        VARCHAR (30)    CONSTRAINT [DF_soLineItem_merchantSku] DEFAULT ('') NULL,
    [EAN]                VARCHAR (50)    NULL,
    [ref_poLineItemId]   BIGINT          CONSTRAINT [DF_soLineItem_ref_poLineItemId] DEFAULT ((0)) NOT NULL,
    [soItemDesc]         NVARCHAR (500)  NULL,
    [tagDivision]        INT             CONSTRAINT [DF_soLineItem_tagDivision] DEFAULT ((0)) NOT NULL,
    [ValidFrom]          DATETIME2 (7)   CONSTRAINT [DF_ValidFrom] DEFAULT (sysutcdatetime()) NOT NULL,
    [ValidTo]            DATETIME2 (7)   CONSTRAINT [DF_ValidTo] DEFAULT (CONVERT([datetime2],'9999-12-31 23:59:59.9999999')) NOT NULL,
    CONSTRAINT [PK__soLineItem_soLineItemId] PRIMARY KEY CLUSTERED ([soLineItemId] ASC),
    CONSTRAINT [FK_soLineItem_md_CustomerSku] FOREIGN KEY ([customerSkuId]) REFERENCES [dbo].[md_CustomerSku] ([customerskuId]),
    CONSTRAINT [FK_soLineItem_soHeader] FOREIGN KEY ([soheaderId]) REFERENCES [dbo].[soHeader] ([soheaderId])
);


GO

