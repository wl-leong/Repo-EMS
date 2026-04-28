CREATE TABLE [dbo].[poHeader] (
    [poID]                BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]           INT             CONSTRAINT [DF_po_created_companyId] DEFAULT ((0)) NOT NULL,
    [supplierId]          INT             CONSTRAINT [DF_po_created_customerId] DEFAULT ((0)) NOT NULL,
    [poName]              VARCHAR (50)    CONSTRAINT [DF_po_created_poName] DEFAULT ('') NOT NULL,
    [poDate]              DATE            CONSTRAINT [DF_po_created_poDate] DEFAULT (getdate()) NOT NULL,
    [poReferenceId]       VARCHAR (50)    CONSTRAINT [DF_poHeader_poReferenceId] DEFAULT ('') NOT NULL,
    [shipToId]            INT             CONSTRAINT [DF_poHeader_shipToId] DEFAULT ((0)) NOT NULL,
    [shipVia]             VARCHAR (50)    CONSTRAINT [DF_poHeader_shipVia] DEFAULT ('') NOT NULL,
    [vesselBooking]       VARCHAR (100)   CONSTRAINT [DF_poHeader_vesselBook] DEFAULT ('') NOT NULL,
    [portOfLanding]       VARCHAR (50)    CONSTRAINT [DF_poHeader_POL] DEFAULT ('') NOT NULL,
    [portOfDestination]   VARCHAR (50)    CONSTRAINT [DF_poHeader_POD] DEFAULT ('') NOT NULL,
    [poEarlyShipDate]     DATE            NULL,
    [poLateShipDate]      DATE            NULL,
    [poStatus]            INT             CONSTRAINT [DF_po_created_poStatus] DEFAULT ((0)) NOT NULL,
    [poNote]              VARCHAR (5000)  CONSTRAINT [DF_po_created_poNote] DEFAULT ('') NOT NULL,
    [poNetTotal]          NUMERIC (18, 4) CONSTRAINT [DF_po_created_poNetTotal] DEFAULT ((0)) NOT NULL,
    [poDiscount]          NUMERIC (18, 4) CONSTRAINT [DF_po_created_poDiscount] DEFAULT ((0)) NOT NULL,
    [poTax]               NUMERIC (18, 4) CONSTRAINT [DF_po_created_poTax] DEFAULT ((0)) NOT NULL,
    [poGrossTotal]        NUMERIC (18, 4) CONSTRAINT [DF_po_created_poGrossTotal] DEFAULT ((0)) NOT NULL,
    [uploadFile]          VARCHAR (200)   CONSTRAINT [DF_poHeader_uploadFile] DEFAULT ('') NOT NULL,
    [reference1]          VARCHAR (200)   CONSTRAINT [DF_poHeader_reference1] DEFAULT ('') NOT NULL,
    [reference2]          VARCHAR (200)   CONSTRAINT [DF_poHeader_reference2] DEFAULT ('') NOT NULL,
    [reference3]          VARCHAR (200)   CONSTRAINT [DF_poHeader_reference3] DEFAULT ('') NOT NULL,
    [poApprovalBy]        VARCHAR (20)    CONSTRAINT [DF_poHeader_poApprovalBy] DEFAULT ('') NULL,
    [poConfirmBy]         VARCHAR (20)    NULL,
    [poCancelBy]          VARCHAR (20)    NULL,
    [poApprovalDate]      DATETIME        CONSTRAINT [DF_poHeader_poApprovalDate] DEFAULT ('1900-01-01') NULL,
    [poConfirmDate]       DATETIME        CONSTRAINT [DF_poHeader_poConfirmDate] DEFAULT ('1900-01-01') NULL,
    [poCancelDate]        DATETIME        CONSTRAINT [DF_poHeader_poCancelDate] DEFAULT ('1900-01-01') NULL,
    [enterDate]           DATETIME        CONSTRAINT [DF_po_created_entryDate] DEFAULT (getdate()) NOT NULL,
    [enterBy]             VARCHAR (20)    CONSTRAINT [DF_po_created_enterBy] DEFAULT ('') NOT NULL,
    [updateDate]          DATETIME        CONSTRAINT [DF_po_created_updatedDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]            VARCHAR (20)    CONSTRAINT [DF_po_created_updateBy] DEFAULT ('') NOT NULL,
    [ValidFrom]           DATETIME2 (7)   DEFAULT (getdate()) NOT NULL,
    [ValidTo]             DATETIME2 (7)   DEFAULT (CONVERT([datetime2],'9999-12-31 23:59:59.9999999')) NOT NULL,
    [lastUpdatedDate]     DATETIME        NULL,
    [foreignCurrencyCode] VARCHAR (3)     CONSTRAINT [DF_foreignCurrencyCode] DEFAULT ('') NULL,
    [homeCurrencyCode]    VARCHAR (3)     CONSTRAINT [DF_homeCurrencyCode] DEFAULT ('') NULL,
    [foreignCurrencyRate] NUMERIC (13, 4) CONSTRAINT [DF_foreignCurrencyRate] DEFAULT ((0)) NULL,
    [warehouseId]         INT             CONSTRAINT [DF_poHeader] DEFAULT ((0)) NOT NULL,
    [locNo]               VARCHAR (20)    NULL,
    [customerCode]        VARCHAR (20)    NULL,
    CONSTRAINT [PK_po_created] PRIMARY KEY CLUSTERED ([poID] ASC),
    CONSTRAINT [FK_poHeader_md_Supplier] FOREIGN KEY ([supplierId]) REFERENCES [dbo].[md_Supplier] ([supplierId])
);


GO

CREATE NONCLUSTERED INDEX [IX_poReferenceID]
    ON [dbo].[poHeader]([poReferenceId] ASC);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'-1 cancel PO, 0 as Open, 1 is pending approval, 2 is pending supplier confirmation, 10 is confirmed PO', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'poHeader', @level2type = N'COLUMN', @level2name = N'poStatus';


GO

