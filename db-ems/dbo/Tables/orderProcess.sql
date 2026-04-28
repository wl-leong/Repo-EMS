CREATE TABLE [dbo].[orderProcess] (
    [opId]            BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]       INT           NOT NULL,
    [customerId]      INT           NOT NULL,
    [opRequestDate]   DATE          NULL,
    [lrName]          VARCHAR (50)  NOT NULL,
    [lrDate]          DATE          NOT NULL,
    [lrShipDate]      DATE          NOT NULL,
    [lrContainerType] INT           NOT NULL,
    [lrNote]          VARCHAR (500) NULL,
    [opStatus]        INT           NOT NULL,
    [enterBy]         INT           NOT NULL,
    [enterDate]       DATETIME      NOT NULL,
    [updateBy]        INT           NULL,
    [updateDate]      DATETIME      NULL,
    CONSTRAINT [PK_orderProcess] PRIMARY KEY CLUSTERED ([opId] ASC)
);


GO

