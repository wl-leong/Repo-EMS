CREATE TABLE [dbo].[actionNotification] (
    [actionNotificationID] BIGINT         IDENTITY (1, 1) NOT NULL,
    [corporateId]          INT            NULL,
    [relatedCorporateId]   INT            NULL,
    [sourceModule]         VARCHAR (50)   NULL,
    [sourceRecordId]       BIGINT         NULL,
    [eventType]            VARCHAR (100)  NULL,
    [payload]              NVARCHAR (MAX) NULL,
    [comment]              VARCHAR (256)  NULL,
    [createDate]           DATETIME       DEFAULT (getdate()) NULL,
    PRIMARY KEY CLUSTERED ([actionNotificationID] ASC)
);


GO

