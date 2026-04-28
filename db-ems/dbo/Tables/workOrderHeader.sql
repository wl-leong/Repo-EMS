CREATE TABLE [dbo].[workOrderHeader] (
    [workOrderHeaderId]  BIGINT         IDENTITY (1, 1) NOT NULL,
    [companyId]          INT            NOT NULL,
    [workOrderName]      VARCHAR (50)   NOT NULL,
    [workOrderDate]      DATE           NOT NULL,
    [warehouseId]        INT            NOT NULL,
    [shipDate]           DATE           NOT NULL,
    [workOrderNote]      VARCHAR (1000) CONSTRAINT [DF_workOrderHeader_workOrderNote] DEFAULT ('') NOT NULL,
    [workOrderStatus]    INT            NOT NULL,
    [createBy]           INT            NOT NULL,
    [createDate]         DATETIME       NOT NULL,
    [updateBy]           INT            NULL,
    [updateDate]         DATETIME       NULL,
    [apiStatus]          VARCHAR (10)   CONSTRAINT [DF_workOrderHeader_apiStatus] DEFAULT ('_NEW_') NULL,
    [customerId]         INT            CONSTRAINT [DF_workOrder_customerId] DEFAULT ((0)) NOT NULL,
    [thirdParty]         VARCHAR (20)   CONSTRAINT [DF_workOrder_thirdParty] DEFAULT ('') NOT NULL,
    [targetCompleteDate] DATE           NULL,
    [Revision]           INT            CONSTRAINT [DF_workOrderHeader_Revision] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_workOrderHeader] PRIMARY KEY CLUSTERED ([workOrderHeaderId] ASC)
);


GO

CREATE   TRIGGER [dbo].[trg_WO_TargetDateChanged]
ON [dbo].[workOrderHeader]
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;

  -- Only act on relevant updates
	IF NOT (UPDATE(targetCompleteDate)) 
		RETURN;

  -- Simplified: only one Notification per work order update
	DECLARE @newNotifID BIGINT, @corporateId BIGINT, @updatedUserId INT

	DECLARE @OutputCapture TABLE (
		notificationID BIGINT,
		corporateId BIGINT,
		sourceModule VARCHAR(50)
	);

	SELECT @updatedUserId = i.updateBy
	FROM inserted i

	DECLARE @notification TABLE (companyId INT, workOrderHeaderId BIGINT, soHeaderId BIGINT, eventType VARCHAR(100), payload NVARCHAR(MAX), comment VARCHAR(2000));

	INSERT INTO @notification(companyId,  workOrderHeaderId, soHeaderId, eventType, payLoad, comment)
	SELECT DISTINCT i.companyId, d.workOrderHeaderId, li.soHeaderId,
			'TargetDateChanged',
			(
			  CONCAT(
				'{"oldDate":', QUOTENAME(ISNULL(d.TargetCompleteDate, ''), '"'),
				',"newDate":', QUOTENAME(i.TargetCompleteDate, '"'),
				'}'
			  )
			),
		CONCAT('WO # ', d.workOrderName, ' target complete date changed from ', ISNULL(d.TargetCompleteDate, ''), ' to ', i.TargetCompleteDate)
	FROM inserted i
		  INNER JOIN deleted d 
			ON i.workOrderHeaderId = d.workOrderHeaderId
		  INNER JOIN workOrderLineItem li 
			ON d.workOrderHeaderId = li.workOrderheaderId
	WHERE i.TargetCompleteDate <> d.TargetCompleteDate
 
	INSERT INTO actionNotification (corporateId, relatedCorporateId, sourceModule, sourceRecordId, eventType, payload, comment)
	OUTPUT INSERTED.actionNotificationID, INSERTED.corporateId, INSERTED.sourceModule
	INTO @OutputCapture(notificationID, corporateID, sourceModule)
	SELECT DISTINCT companyId, NULL, 'WorkOrder', workOrderHeaderId, eventType, payload, comment
	FROM @notification
	WHERE workOrderHeaderId IS NOT NULL
	UNION
	SELECT DISTINCT companyId, NULL, 'SalesOrder', soHeaderId, eventType, payload, comment
	FROM @notification
	WHERE soHeaderId IS NOT NULL

	SELECT TOP 1 
		@newNotifID = notificationID,
		@corporateId = corporateId
	FROM @OutputCapture;

	IF @newNotifID IS NULL
		RETURN;

	DECLARE @Recepient AS TABLE (userId INT, roleName VARCHAR(50), roleId INT);

	INSERT INTO @Recepient(userId, roleName, roleId)
	SELECT usr.userId, r.roleName, r.roleId
	FROM md_user usr
		INNER JOIN userRole usrRole
			ON usr.userId = usrRole.userId
		INNER JOIN companyRole cRole
			ON usrRole.userRoleCompanyRoleId = cRole.companyRoleId
		INNER JOIN md_role r
			ON cRole.roleId = r.roleId
	WHERE usr.userStatus = 1
		AND cRole.companyId = @corporateId
		AND r.roleId IN (2050, 2049, 2024) -- planning, loading, sales
		AND usr.userId <> @updatedUserId
 
 
  -- Insert recipients: both work order team and sales order team
	INSERT INTO notificationRecipient (notificationID, notifyGroup, userId, isRead, clickedAt)
	SELECT notificationID, r.roleName, r.userId, 0, SYSUTCDATETIME()
	FROM @OutputCapture n, @Recepient r
	WHERE r.roleId IN (2050, 2049)
		AND n.sourceModule = 'WorkOrder'
	
	INSERT INTO notificationRecipient (notificationID, notifyGroup, userId, isRead, clickedAt)
	SELECT notificationID, r.roleName, r.userId, 0, SYSUTCDATETIME()
	FROM @OutputCapture n, @Recepient r
	WHERE r.roleId IN (2024)
		AND n.sourceModule = 'SalesOrder'
 
END

GO

