CREATE TABLE [dbo].[loadingPlanning] (
    [loadingPlanningId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [lpName]            VARCHAR (50)   NOT NULL,
    [containerTypeId]   INT            NULL,
    [containerSeq]      INT            NOT NULL,
    [earlyShipDate]     DATE           NULL,
    [lateShipDate]      DATE           NULL,
    [shipToId]          INT            NOT NULL,
    [merchantSku]       VARCHAR (30)   NOT NULL,
    [invID]             BIGINT         NOT NULL,
    [qty]               INT            NOT NULL,
    [itemNote]          VARCHAR (5000) NULL,
    [itemStatus]        INT            NOT NULL,
    [enterBy]           INT            NOT NULL,
    [enterDate]         DATETIME       NOT NULL,
    [updateBy]          INT            NULL,
    [updateDate]        DATETIME       NULL
);


GO

