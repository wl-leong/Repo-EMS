CREATE TABLE [dbo].[packingHeader] (
    [packingHeaderId] BIGINT        IDENTITY (1, 1) NOT NULL,
    [companyId]       INT           NOT NULL,
    [customerId]      INT           NOT NULL,
    [packingName]     VARCHAR (50)  NULL,
    [lrName]          VARCHAR (50)  NOT NULL,
    [requestDate]     DATE          NOT NULL,
    [soHeaderId]      BIGINT        NULL,
    [soName]          VARCHAR (50)  NULL,
    [reference1]      VARCHAR (200) NULL,
    [reference2]      VARCHAR (200) NULL,
    [reference3]      VARCHAR (200) NULL,
    [lrContainerType] INT           NULL,
    [lrNote]          VARCHAR (500) NULL,
    [packingStatus]   INT           NOT NULL,
    [enterBy]         INT           NOT NULL,
    [enterDate]       DATETIME      NOT NULL,
    [updateBy]        INT           NULL,
    [updateDate]      DATETIME      NULL,
    CONSTRAINT [PK_packingHeader] PRIMARY KEY CLUSTERED ([packingHeaderId] ASC)
);


GO

