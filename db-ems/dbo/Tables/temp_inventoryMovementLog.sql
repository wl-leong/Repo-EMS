CREATE TABLE [dbo].[temp_inventoryMovementLog] (
    [invMovementLog_Id] BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]         INT           NOT NULL,
    [warehouseLabel]    VARCHAR (20)  NOT NULL,
    [action]            VARCHAR (20)  NOT NULL,
    [shipId]            VARCHAR (50)  NULL,
    [orderNo]           VARCHAR (50)  NULL,
    [inventorySku]      VARCHAR (50)  NOT NULL,
    [qty]               INT           NOT NULL,
    [reason]            VARCHAR (200) NULL,
    [fileLoaded]        VARCHAR (150) NOT NULL,
    [enterBy]           INT           NOT NULL,
    [enterDate]         DATETIME      NOT NULL,
    PRIMARY KEY CLUSTERED ([invMovementLog_Id] ASC)
);


GO

