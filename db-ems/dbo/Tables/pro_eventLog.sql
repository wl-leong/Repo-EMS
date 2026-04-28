CREATE TABLE [dbo].[pro_eventLog] (
    [proCallId]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [transId]       VARCHAR (50)    NOT NULL,
    [procedureName] [sysname]       NOT NULL,
    [startDate]     DATETIME2 (3)   NOT NULL,
    [endDate]       DATETIME2 (3)   NULL,
    [logStatus]     VARCHAR (10)    NULL,
    [jsonParam]     NVARCHAR (MAX)  NULL,
    [returnMessage] NVARCHAR (4000) NULL,
    [userId]        INT             NULL,
    PRIMARY KEY CLUSTERED ([proCallId] ASC)
);


GO

