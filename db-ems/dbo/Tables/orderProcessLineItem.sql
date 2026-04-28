CREATE TABLE [dbo].[orderProcessLineItem] (
    [opLineItemId]     BIGINT       IDENTITY (1, 1) NOT NULL,
    [opId]             BIGINT       NOT NULL,
    [lrName]           VARCHAR (50) NOT NULL,
    [soHeaderId]       BIGINT       NOT NULL,
    [soLineItemId]     BIGINT       NOT NULL,
    [containerTypeId]  INT          NOT NULL,
    [containerSeq]     INT          NOT NULL,
    [shipToId]         INT          NOT NULL,
    [earlyShipDate]    DATE         NOT NULL,
    [endShipDate]      DATE         NOT NULL,
    [invId]            BIGINT       NOT NULL,
    [customerSku]      VARCHAR (50) NOT NULL,
    [loadingQty]       INT          NOT NULL,
    [shipQty]          INT          CONSTRAINT [DF_orderProcessLineItem_shipQty] DEFAULT ((0)) NOT NULL,
    [opLineItemStatus] INT          CONSTRAINT [DF_orderProcessLineItem_opLineItemStatus] DEFAULT ((2142)) NOT NULL,
    [ref_lrLineItemId] BIGINT       NOT NULL,
    [enterBy]          VARCHAR (20) NOT NULL,
    [enterDate]        DATETIME     NOT NULL,
    [updateBy]         VARCHAR (20) NULL,
    [updateDate]       DATETIME     NULL,
    CONSTRAINT [PK_orderProcessLineItem] PRIMARY KEY CLUSTERED ([opLineItemId] ASC)
);


GO

