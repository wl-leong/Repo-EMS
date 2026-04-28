CREATE TABLE [dbo].[poReceivedLineItem] (
    [poRcvLineItemId]     BIGINT         IDENTITY (1, 1) NOT NULL,
    [poRcvHeaderId]       BIGINT         NOT NULL,
    [poRcvName]           VARCHAR (50)   NOT NULL,
    [poDetailsId]         BIGINT         NOT NULL,
    [invId]               INT            CONSTRAINT [DF_poReceivedLineItem_invId] DEFAULT ((0)) NOT NULL,
    [supplierSkuId]       INT            CONSTRAINT [DF_poReceivedLineItem_supplierSkuId] DEFAULT ((0)) NOT NULL,
    [supplierSku]         VARCHAR (50)   NOT NULL,
    [rcvQty]              INT            NOT NULL,
    [notes]               VARCHAR (2000) NOT NULL,
    [poRcvLineItemStatus] INT            CONSTRAINT [DF_poReceivedLineItem_poRcvLineItemStatus] DEFAULT ((3159)) NOT NULL,
    [enterDate]           DATETIME       CONSTRAINT [DF_poReceivedLineItem_enterDate] DEFAULT (getdate()) NOT NULL,
    [enterBy]             INT            NOT NULL,
    [updateDate]          DATETIME       NULL,
    [updateBy]            INT            NULL,
    CONSTRAINT [PK_poReceivedLineItem] PRIMARY KEY CLUSTERED ([poRcvLineItemId] ASC),
    CONSTRAINT [FK_poReceivedLineItem_poLineItem] FOREIGN KEY ([poDetailsId]) REFERENCES [dbo].[poLineItem] ([podetailsId]),
    CONSTRAINT [FK_poReceivedLineItem_poReceivedHeader] FOREIGN KEY ([poRcvHeaderId]) REFERENCES [dbo].[poReceivedHeader] ([poRcvHeaderId])
);


GO

