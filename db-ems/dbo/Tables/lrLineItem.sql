CREATE TABLE [dbo].[lrLineItem] (
    [lrDetailsId]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [lrHeaderId]           BIGINT         NOT NULL,
    [lrName]               VARCHAR (50)   NOT NULL,
    [lrContainerId]        BIGINT         NOT NULL,
    [soHeaderId]           BIGINT         NOT NULL,
    [soLineItemId]         BIGINT         NOT NULL,
    [poId]                 BIGINT         NULL,
    [poDetailsId]          BIGINT         NULL,
    [supplierSku]          VARCHAR (30)   NOT NULL,
    [invID]                BIGINT         NOT NULL,
    [qty]                  INT            CONSTRAINT [DF_lrDetails_qty] DEFAULT ((0)) NOT NULL,
    [confirmQty]           INT            CONSTRAINT [DF_lrLineItem_confirmQty] DEFAULT ((0)) NOT NULL,
    [processQty]           INT            CONSTRAINT [DF_lrLineItem_processQty] DEFAULT ((0)) NOT NULL,
    [itemNote]             VARCHAR (5000) CONSTRAINT [DF_lrLineItem_itemNote] DEFAULT ('') NULL,
    [itemStatus]           INT            NOT NULL,
    [lrCancelDate]         DATETIME       NULL,
    [lrCancelBy]           INT            NULL,
    [enterBy]              INT            NOT NULL,
    [enterDate]            DATETIME       CONSTRAINT [DF_lrDetails_createDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]             INT            NULL,
    [updateDate]           DATETIME       NULL,
    [ref_lrLineItemId]     BIGINT         CONSTRAINT [DF_lrLineItem_ref_lrLineItemId] DEFAULT ((0)) NULL,
    [cartonMaterial_invId] BIGINT         NULL,
    [cartonMaterial]       VARCHAR (50)   NULL,
    [cartonQty]            INT            NULL,
    [qtyPerCarton]         INT            NULL,
    CONSTRAINT [PK_lrDetails] PRIMARY KEY CLUSTERED ([lrDetailsId] ASC),
    CONSTRAINT [FK_lrLineItem_lrHeader] FOREIGN KEY ([lrHeaderId]) REFERENCES [dbo].[lrHeader] ([lrHeaderId])
);


GO

