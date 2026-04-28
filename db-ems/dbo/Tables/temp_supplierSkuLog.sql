CREATE TABLE [dbo].[temp_supplierSkuLog] (
    [supplierSkuLog] BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]      INT           NOT NULL,
    [supplierName]   VARCHAR (100) NOT NULL,
    [inventorySku]   VARCHAR (50)  NOT NULL,
    [supplierSku]    VARCHAR (50)  NOT NULL,
    [itemDesc]       VARCHAR (250) NULL,
    [currencyCode]   VARCHAR (3)   NOT NULL,
    [supplierCost]   VARCHAR (10)  NOT NULL,
    [MOQ]            VARCHAR (10)  NOT NULL,
    [isDefault]      VARCHAR (3)   NOT NULL,
    [fileLoaded]     VARCHAR (150) NULL,
    [enterBy]        VARCHAR (20)  DEFAULT ('') NULL,
    [enterDate]      DATETIME      DEFAULT (getdate()) NULL,
    PRIMARY KEY CLUSTERED ([supplierSkuLog] ASC)
);


GO

