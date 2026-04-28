CREATE TABLE [dbo].[temp_lrLog] (
    [lrLogId]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [companyId]      INT             NOT NULL,
    [poName]         NVARCHAR (100)  NULL,
    [customerPo]     NVARCHAR (400)  NULL,
    [pod]            NVARCHAR (50)   NULL,
    [productName]    NVARCHAR (500)  NULL,
    [supplierSku]    NVARCHAR (100)  NULL,
    [merchantSku]    NVARCHAR (100)  NULL,
    [lrQty]          NVARCHAR (20)   NULL,
    [shipDate]       NVARCHAR (20)   NULL,
    [containerType]  NVARCHAR (50)   NULL,
    [containerSeq]   NVARCHAR (50)   NULL,
    [notes]          NVARCHAR (2500) NULL,
    [fileLoaded]     NVARCHAR (300)  NULL,
    [enterBy]        VARCHAR (20)    CONSTRAINT [DF__tmp_ms_xx__enter__6EAC2DFA] DEFAULT ('') NOT NULL,
    [enterDate]      DATETIME        CONSTRAINT [DF__tmp_ms_xx__enter__6FA05233] DEFAULT (getdate()) NOT NULL,
    [cartonMaterial] NVARCHAR (50)   NULL,
    [cartonQty]      NVARCHAR (20)   NULL,
    [qtyPerCarton]   NVARCHAR (20)   NULL,
    [poDetailsId]    NVARCHAR (10)   NULL,
    CONSTRAINT [PK__tmp_ms_x__EBFD634598F7CDCE] PRIMARY KEY CLUSTERED ([lrLogId] ASC)
);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'refre to poName - 20240513', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'temp_lrLog', @level2type = N'COLUMN', @level2name = N'poName';


GO

