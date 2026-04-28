CREATE TABLE [History].[soLineItem] (
    [soLineItemId]       BIGINT          NOT NULL,
    [soheaderId]         BIGINT          NOT NULL,
    [invID]              INT             NOT NULL,
    [customerSkuId]      INT             NOT NULL,
    [customerSku]        VARCHAR (30)    NOT NULL,
    [currencyCode]       VARCHAR (3)     NULL,
    [csCost]             NUMERIC (19, 4) NULL,
    [freightCost]        NUMERIC (19, 4) NULL,
    [isItemPriceChanged] BIT             NOT NULL,
    [odrQty]             INT             NOT NULL,
    [poQty]              INT             NOT NULL,
    [processQty]         INT             CONSTRAINT [DF_soLineItem_processQty_1] DEFAULT ((0)) NOT NULL,
    [shpQty]             INT             NOT NULL,
    [itemReference1]     VARCHAR (500)   NOT NULL,
    [itemReference2]     VARCHAR (500)   NOT NULL,
    [itemNote]           VARCHAR (5000)  NOT NULL,
    [soLineItemStatus]   INT             NOT NULL,
    [createBy]           INT             NOT NULL,
    [createDate]         DATETIME        NOT NULL,
    [updateBy]           INT             NOT NULL,
    [updateDate]         DATETIME        NOT NULL,
    [ValidFrom]          DATETIME2 (7)   NOT NULL,
    [ValidTo]            DATETIME2 (7)   NOT NULL,
    [merchantSku]        VARCHAR (30)    CONSTRAINT [DF_history_soLineItem_merchantSku] DEFAULT ('') NULL,
    [ref_poLineItemId]   BIGINT          CONSTRAINT [DF_history_poLineItem_ref_poLineItemId] DEFAULT ((0)) NOT NULL,
    [soItemDesc]         VARCHAR (500)   NULL,
    [tagDivision]        INT             CONSTRAINT [DF_history_soLineItem_tagDivision] DEFAULT ((0)) NOT NULL
);


GO

CREATE CLUSTERED INDEX [ix_soLineItem]
    ON [History].[soLineItem]([ValidTo] ASC, [ValidFrom] ASC);


GO

