CREATE TABLE [dbo].[temp_loadingPlanningLog] (
    [lrLogId]       BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]     INT            NOT NULL,
    [containerType] VARCHAR (20)   NOT NULL,
    [containerSeq]  VARCHAR (10)   NOT NULL,
    [customerName]  VARCHAR (30)   NULL,
    [merchantSku]   VARCHAR (30)   NOT NULL,
    [lrQty]         VARCHAR (10)   NOT NULL,
    [shipDate]      VARCHAR (8)    NULL,
    [shipToLabel]   VARCHAR (20)   NULL,
    [notes]         VARCHAR (2500) NULL,
    [fileLoaded]    VARCHAR (150)  NULL,
    [enterBy]       VARCHAR (20)   NOT NULL,
    [enterDate]     DATETIME       NOT NULL
);


GO

