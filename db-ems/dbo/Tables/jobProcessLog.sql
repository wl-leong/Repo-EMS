CREATE TABLE [dbo].[jobProcessLog] (
    [logId]       BIGINT        IDENTITY (1, 1) NOT NULL,
    [executionId] VARCHAR (50)  DEFAULT ('') NULL,
    [sourceId]    VARCHAR (50)  DEFAULT ('') NULL,
    [category]    VARCHAR (50)  NOT NULL,
    [startdate]   DATETIME      NULL,
    [stepName]    VARCHAR (100) NOT NULL,
    [status]      VARCHAR (20)  NOT NULL,
    [stepStartDT] DATETIME      NULL,
    [stepEndDT]   DATETIME      NULL,
    [spId]        INT           NULL,
    [kpId]        INT           NULL,
    [hostName]    VARCHAR (50)  NULL,
    [dbId]        VARCHAR (20)  NULL,
    [error_msg]   VARCHAR (MAX) NULL,
    [insertedon]  SMALLDATETIME NOT NULL,
    PRIMARY KEY CLUSTERED ([logId] ASC)
);


GO

