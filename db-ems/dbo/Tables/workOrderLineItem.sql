CREATE TABLE [dbo].[workOrderLineItem] (
    [workOrderLineItemId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [workOrderHeaderId]   BIGINT         NOT NULL,
    [workOrderName]       VARCHAR (50)   NOT NULL,
    [soHeaderId]          BIGINT         NOT NULL,
    [soName]              VARCHAR (50)   NOT NULL,
    [soLineItemId]        BIGINT         NOT NULL,
    [invId]               INT            NOT NULL,
    [qty]                 INT            NOT NULL,
    [confirmQty]          INT            DEFAULT ((0)) NULL,
    [produceQty]          INT            DEFAULT ((0)) NULL,
    [workOrderItemNote]   VARCHAR (1000) CONSTRAINT [DF_workOrderLineItem_workOrderItemNote] DEFAULT ('') NOT NULL,
    [workOrderItemStatus] INT            NOT NULL,
    [createBy]            INT            NOT NULL,
    [createDate]          DATETIME       NOT NULL,
    [updateBy]            INT            NULL,
    [updateDate]          DATETIME       NULL,
    CONSTRAINT [PK_workOrderLineItem] PRIMARY KEY CLUSTERED ([workOrderLineItemId] ASC)
);


GO

CREATE   TRIGGER [dbo].[trg_WOLineItem_QtyChanged]
ON [dbo].[workOrderLineItem]
AFTER UPDATE
AS
BEGIN
	SET NOCOUNT ON;

  -- Only act on relevant updates
	IF NOT (UPDATE(qty) OR UPDATE(confirmQty))
		RETURN;

  -- Simplified: only one Notification per work order update
	DECLARE @newNotifID BIGINT, @corporateId BIGINT 

	DECLARE @OutputCapture TABLE (
		notificationID BIGINT,
		corporateId BIGINT,
		sourceModule VARCHAR(50)
	);
 
	DECLARE @notification TABLE (companyId INT, workOrderHeaderId BIGINT, soHeaderId BIGINT, eventType VARCHAR(100), payload NVARCHAR(MAX), comment VARCHAR(2000));

	IF UPDATE(confirmQty)
	BEGIN
		INSERT INTO @notification(companyId,  workOrderHeaderId, soHeaderId, eventType, payLoad, comment)
		SELECT DISTINCT h.companyId, d.workOrderHeaderId, d.soHeaderId,
				'confirmQtyChanged' as eventType,
				(
				  CONCAT(
					'{"workOrderLineItemId":', QUOTENAME(i.workOrderLineItemId, '"'),
					',"oldQty":', QUOTENAME(ISNULL(d.confirmQty, '0'), '"'),
					',"newQty":', QUOTENAME(i.confirmQty, '"'),
					'}'
				  )
				) as payLoad,
			CONCAT('WO # ', d.workOrderName, ' confirm qty changed from ', ISNULL(d.confirmQty, ''), ' to ', i.confirmQty) as comment 
		FROM inserted i
			INNER JOIN deleted d 
				ON i.workOrderLineItemId = d.workOrderLineItemId
			INNER JOIN workOrderHeader h
				ON d.workOrderHeaderId = h.workOrderheaderId
		WHERE i.confirmQty <> d.confirmQty
	END


	IF UPDATE(qty)
	BEGIN	
		INSERT INTO @notification(companyId,  workOrderHeaderId, soHeaderId, eventType, payLoad, comment)
		SELECT DISTINCT h.companyId, d.workOrderHeaderId, d.soHeaderId,
				'woQtyChanged',
				(
				  CONCAT(
					'{"workOrderLineItemId":', QUOTENAME(i.workOrderLineItemId, '"'),
					',"oldQty":', QUOTENAME(ISNULL(d.qty, '0'), '"'),
					',"newQty":', QUOTENAME(i.qty, '"'),
					'}'
				  )
				),
			CONCAT('WO # ', d.workOrderName, ' wo qty changed from ', ISNULL(d.qty, ''), ' to ', i.qty)
		FROM inserted i
			INNER JOIN deleted d 
				ON d.workOrderHeaderId = i.workOrderheaderId
			INNER JOIN workOrderHeader h
				ON d.workOrderHeaderId = h.workOrderheaderId
		WHERE i.qty <> d.qty
	END

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

