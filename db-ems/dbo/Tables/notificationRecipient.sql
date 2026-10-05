CREATE TABLE [dbo].[notificationRecipient] (
    [recipientId]    BIGINT       IDENTITY (1, 1) NOT NULL,
    [notificationID] BIGINT       NULL,
    [userID]         INT          NULL,
    [notifyGroup]    VARCHAR (50) NULL,
    [isRead]         BIT          DEFAULT ((0)) NULL,
    [clickedAt]      DATETIME     NULL,
    PRIMARY KEY CLUSTERED ([recipientId] ASC),
    FOREIGN KEY ([notificationID]) REFERENCES [dbo].[actionNotification] ([actionNotificationID])
);


GO

CREATE NONCLUSTERED INDEX [IX_notificationRecipient_userID_isRead]
    ON [dbo].[notificationRecipient]([userID] ASC, [isRead] ASC)
    INCLUDE([notificationID]);


GO

CREATE NONCLUSTERED INDEX [IX_notificationRecipient_notificationID]
    ON [dbo].[notificationRecipient]([notificationID] ASC);


GO

