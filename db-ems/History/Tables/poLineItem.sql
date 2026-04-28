CREATE TABLE [History].[poLineItem] (
    [podetailsId]       BIGINT          NOT NULL,
    [poId]              BIGINT          NOT NULL,
    [poName]            VARCHAR (50)    NOT NULL,
    [supplierSkuId]     INT             NOT NULL,
    [supplierSku]       VARCHAR (50)    NOT NULL,
    [invID]             BIGINT          NOT NULL,
    [itemCode]          VARCHAR (50)    NOT NULL,
    [poItemDesc]        NVARCHAR (500)  NULL,
    [currencyCode]      VARCHAR (3)     NULL,
    [unitPrice]         DECIMAL (18, 4) NOT NULL,
    [qty]               INT             NOT NULL,
    [rcvQty]            INT             NOT NULL,
    [itemReference1]    VARCHAR (200)   NULL,
    [itemReference2]    VARCHAR (200)   NULL,
    [itemStatus]        INT             NOT NULL,
    [itemNote]          VARCHAR (MAX)   NULL,
    [updateDate]        DATETIME        NULL,
    [updateBy]          VARCHAR (20)    NULL,
    [enterDate]         DATETIME        NOT NULL,
    [enterBy]           VARCHAR (20)    NOT NULL,
    [ValidFrom]         DATETIME2 (7)   NOT NULL,
    [ValidTo]           DATETIME2 (7)   NOT NULL,
    [merchantSku]       VARCHAR (100)   NULL,
    [soLineItemId]      BIGINT          CONSTRAINT [DF_history_poLineItem_soLineItemId] DEFAULT ((0)) NOT NULL,
    [homeCurrencyCost]  NUMERIC (13, 4) NULL,
    [isDefaultSupplier] INT             CONSTRAINT [DF_history_poLineItem] DEFAULT ((1)) NULL,
    [lrQty]             INT             CONSTRAINT [DF_history_poLineItem_lrQty] DEFAULT ((0)) NOT NULL,
    [EAN]               VARCHAR (50)    NULL
);


GO

CREATE CLUSTERED INDEX [ix_poLineItem]
    ON [History].[poLineItem]([ValidTo] ASC, [ValidFrom] ASC);


GO

