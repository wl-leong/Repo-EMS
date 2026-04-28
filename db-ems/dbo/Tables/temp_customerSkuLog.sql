CREATE TABLE [dbo].[temp_customerSkuLog] (
    [customerSkuLog] BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]      INT           NOT NULL,
    [customerName]   VARCHAR (100) NOT NULL,
    [inventorySku]   VARCHAR (50)  NOT NULL,
    [customerSku]    VARCHAR (30)  NOT NULL,
    [merchantSku]    VARCHAR (30)  NOT NULL,
    [EAN]            VARCHAR (50)  NULL,
    [itemDesc]       VARCHAR (250) NULL,
    [currencyCode]   VARCHAR (3)   NOT NULL,
    [customerCost]   VARCHAR (10)  NOT NULL,
    [fileLoaded]     VARCHAR (150) NULL,
    [enterBy]        VARCHAR (20)  DEFAULT ('') NULL,
    [enterDate]      DATETIME      DEFAULT (getdate()) NULL,
    PRIMARY KEY CLUSTERED ([customerSkuLog] ASC)
);


GO

