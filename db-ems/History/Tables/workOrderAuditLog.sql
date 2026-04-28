CREATE TABLE [History].[workOrderAuditLog] (
    [historyId]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [workOrderHeaderId] BIGINT         NOT NULL,
    [revision]          INT            NOT NULL,
    [actionLog]         NVARCHAR (MAX) NOT NULL,
    [userId]            INT            NULL,
    [changeDateTime]    DATETIME       DEFAULT (getdate()) NOT NULL,
    PRIMARY KEY CLUSTERED ([historyId] ASC)
);


GO

