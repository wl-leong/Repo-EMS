CREATE TABLE [dbo].[poLineItem] (
    [podetailsId]       BIGINT                                             IDENTITY (1, 1) NOT NULL,
    [poId]              BIGINT                                             NOT NULL,
    [poName]            VARCHAR (50)                                       NOT NULL,
    [supplierSkuId]     INT                                                CONSTRAINT [DF_poLineItem_supplierSkuId] DEFAULT ((0)) NOT NULL,
    [supplierSku]       VARCHAR (50)                                       NOT NULL,
    [invID]             BIGINT                                             NOT NULL,
    [itemCode]          VARCHAR (50)                                       NOT NULL,
    [poItemDesc]        NVARCHAR (500)                                     NULL,
    [currencyCode]      VARCHAR (3)                                        NULL,
    [unitPrice]         DECIMAL (18, 4)                                    NOT NULL,
    [qty]               INT                                                NOT NULL,
    [rcvQty]            INT                                                CONSTRAINT [DF_poLineItem_rcvQty] DEFAULT ((0)) NOT NULL,
    [itemReference1]    VARCHAR (200)                                      NULL,
    [itemReference2]    VARCHAR (200)                                      CONSTRAINT [DF_poLineItem_itemReference2] DEFAULT ((0)) NULL,
    [itemStatus]        INT                                                NOT NULL,
    [itemNote]          VARCHAR (MAX)                                      CONSTRAINT [DF_poLineItem_itemNote] DEFAULT ('') NULL,
    [updateDate]        DATETIME                                           NULL,
    [updateBy]          VARCHAR (20)                                       NULL,
    [enterDate]         DATETIME                                           CONSTRAINT [DF_poLineItem_enterDate] DEFAULT (getdate()) NOT NULL,
    [enterBy]           VARCHAR (20)                                       NOT NULL,
    [merchantSku]       VARCHAR (30)                                       NULL,
    [EAN]               VARCHAR (50)                                       NULL,
    [soLineItemId]      BIGINT                                             CONSTRAINT [DF_poLineItem_soLineItemId] DEFAULT ((0)) NOT NULL,
    [homeCurrencyCost]  NUMERIC (13, 4)                                    CONSTRAINT [DF_poLineItem_homeCurrencyCost] DEFAULT ((0)) NULL,
    [isDefaultSupplier] INT                                                CONSTRAINT [DF_poLineItem_isDefaultSupplier] DEFAULT ((1)) NULL,
    [lrQty]             INT                                                CONSTRAINT [DF_poLineItem_lrQty] DEFAULT ((0)) NOT NULL,
    [ValidFrom]         DATETIME2 (7) GENERATED ALWAYS AS ROW START HIDDEN CONSTRAINT [DF_poLineItem_ValidFrom] DEFAULT (sysutcdatetime()) NOT NULL,
    [ValidTo]           DATETIME2 (7) GENERATED ALWAYS AS ROW END HIDDEN   CONSTRAINT [DF_poLineItem_ValidTo] DEFAULT (CONVERT([datetime2](7),'9999-12-31 23:59:59.9999999')) NOT NULL,
    CONSTRAINT [PK_po_details] PRIMARY KEY CLUSTERED ([podetailsId] ASC),
    CONSTRAINT [FK_poLineItem_poHeader] FOREIGN KEY ([poId]) REFERENCES [dbo].[poHeader] ([poID]),
    PERIOD FOR SYSTEM_TIME ([ValidFrom], [ValidTo])
);


GO

