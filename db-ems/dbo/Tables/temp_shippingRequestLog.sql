CREATE TABLE [dbo].[temp_shippingRequestLog] (
    [logId]               BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]           INT           NULL,
    [lrName]              VARCHAR (50)  NOT NULL,
    [poName]              VARCHAR (50)  NULL,
    [soName]              VARCHAR (50)  NOT NULL,
    [supplierCompanyName] VARCHAR (255) NOT NULL,
    [customerName]        VARCHAR (100) NOT NULL,
    [lrShipDate]          DATE          NULL,
    [lrReference1]        VARCHAR (500) NULL,
    [lrReference2]        VARCHAR (500) NULL,
    [lrReference3]        VARCHAR (500) NULL,
    [supplierSku]         VARCHAR (30)  NOT NULL,
    [merchantSku]         VARCHAR (50)  NOT NULL,
    [itemReference1]      VARCHAR (500) NULL,
    [qty]                 INT           NOT NULL,
    [confirmQty]          INT           NOT NULL,
    [loadingQty]          INT           NULL,
    [size]                VARCHAR (96)  NULL,
    [cbm]                 FLOAT (53)    NOT NULL,
    [totalCbm]            FLOAT (53)    NOT NULL,
    [grossWeight]         FLOAT (53)    NOT NULL,
    [totalWeight]         FLOAT (53)    NOT NULL,
    [netWeight]           FLOAT (53)    NOT NULL,
    [totalNetWeight]      FLOAT (53)    NOT NULL,
    [containerType]       VARCHAR (255) NOT NULL,
    [fileName]            VARCHAR (150) NULL,
    [enterBy]             VARCHAR (20)  CONSTRAINT [DF_temp_shippingRequestLog_enterBy] DEFAULT ('') NOT NULL,
    [enterDate]           DATETIME      CONSTRAINT [DF_temp_shippingRequestLog_enterDate] DEFAULT (getdate()) NOT NULL,
    [updateBy]            VARCHAR (20)  CONSTRAINT [DF_temp_shippingRequestLog_updateBy] DEFAULT ('') NOT NULL,
    [updateDate]          DATETIME      CONSTRAINT [DF_temp_shippingRequestLog_updateDate] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK__temp_shi__7839F64D582D93FD] PRIMARY KEY CLUSTERED ([logId] ASC)
);


GO

