CREATE TABLE [dbo].[shipmentLineItem] (
    [shipmentLineItemId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [shipmentId]         BIGINT        NOT NULL,
    [shipId]             VARCHAR (50)  NOT NULL,
    [soLineItemId]       BIGINT        NOT NULL,
    [invId]              INT           NOT NULL,
    [customerSku]        VARCHAR (50)  NOT NULL,
    [merchantSku]        VARCHAR (50)  NOT NULL,
    [shipmentQty]        INT           CONSTRAINT [shipmentLineItem_shipQty] DEFAULT ((0)) NOT NULL,
    [shipQty]            INT           CONSTRAINT [shipmentLineItem_checkoutQty] DEFAULT ((0)) NOT NULL,
    [palletProcessQty]   INT           CONSTRAINT [shipmentLineItem_carrierShipQty] DEFAULT ((0)) NOT NULL,
    [lineItemNotes]      VARCHAR (500) CONSTRAINT [shipmentLineItem_shipNote] DEFAULT ('') NOT NULL,
    [lineItemStatus]     INT           CONSTRAINT [shipmentLineItem_shipmentLineItemStatus] DEFAULT ((2149)) NOT NULL,
    [lrDetailsId]        BIGINT        NULL,
    [createBy]           INT           NOT NULL,
    [createDate]         DATETIME      CONSTRAINT [shipmentLineItem_createDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]           INT           NOT NULL,
    [updateDate]         DATETIME      CONSTRAINT [shipmentLineItem_updateDate] DEFAULT ('1900-01-01') NOT NULL,
    CONSTRAINT [PK_shipmentLineItem] PRIMARY KEY CLUSTERED ([shipmentLineItemId] ASC),
    CONSTRAINT [FK_shipmentLineItem_shipmentHeader] FOREIGN KEY ([shipmentId]) REFERENCES [dbo].[shipmentHeader] ([shipmentId])
);


GO

