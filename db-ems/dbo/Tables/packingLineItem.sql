CREATE TABLE [dbo].[packingLineItem] (
    [packingDetailsId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [packingHeaderId]  BIGINT        NOT NULL,
    [packingName]      VARCHAR (50)  NOT NULL,
    [customerSku]      VARCHAR (30)  NOT NULL,
    [invID]            BIGINT        NULL,
    [qty]              INT           NOT NULL,
    [shipQty]          INT           NOT NULL,
    [itemNote]         VARCHAR (500) NULL,
    [itemStatus]       INT           NOT NULL,
    [soName]           VARCHAR (50)  NULL,
    [enterBy]          INT           NOT NULL,
    [enterDate]        DATETIME      NOT NULL,
    [updateBy]         INT           NULL,
    [updateDate]       DATETIME      NULL,
    CONSTRAINT [PK_packingLineItem] PRIMARY KEY CLUSTERED ([packingDetailsId] ASC)
);


GO

