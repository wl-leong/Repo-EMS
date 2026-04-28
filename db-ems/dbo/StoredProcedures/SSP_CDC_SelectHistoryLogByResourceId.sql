-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-08-06
-- Used By:	    

-- Description : Get list of action notification according to module and id

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-06	1.0			ZY Wong 	Initial
-- ==============================================
-- EXEC [SSP_CDC_SelectHistoryLogByResourceId] 4, 1, null, 26
--select * from md_user
--select * from actionNotification order by 1 desc
CREATE PROCEDURE [dbo].[SSP_CDC_SelectHistoryLogByResourceId]
@companyId INT,
@userId INT,
@sourceModule VARCHAR(50),
@sourceRecordId INT
AS
BEGIN
	SET NOCOUNT ON

	IF @sourceModule = ''
		SET @sourceModule = NULL;

    --DECLARE @companyId INT = 4, @userId INT = 29, @sourceModule VARCHAR(50) = 'WorkOrder', @sourceRecordId INT = 24 ; --> WO-25-00024

	--drop table if exists aaa;
	----select * from aaa

	--select @companyId a, @userId b, @sourceModule c, @sourceRecordId d INTO aaa;

    DROP TABLE IF EXISTS #idList;

    SELECT notificationID 
    INTO #idList
    FROM notificationRecipient 
    WHERE userId = @userId
        AND isRead = 0  -- unread

    SELECT ROW_NUMBER() OVER(ORDER BY createDate DESC) as rowNo, actionNotificationID, eventType, comment, FORMAT(createDate, 'yyyy-MM-dd hh:mmtt') as createDate
    FROM actionNotification ac
        INNER JOIN #idList l
            ON ac.actionNotificationID = l.notificationID
    WHERE corporateId = @companyId 
        AND sourceModule = @sourceModule
        AND sourceRecordId = @sourceRecordId

END

GO

