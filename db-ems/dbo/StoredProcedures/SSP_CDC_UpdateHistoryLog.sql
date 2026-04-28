-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-08-06
-- Used By:	    

-- Description : Update isRead = 1 after user read history log 

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-08-12	1.1			WL Leong	Add in companyId, only update the recipient based on user
-- 2025-08-06	1.0			ZY Wong 	Initial
-- ==============================================
-- [dbo].[SSP_CDC_UpdateHistoryLog] 4, 27, 'WorkOrder', 30
CREATE PROCEDURE [dbo].[SSP_CDC_UpdateHistoryLog]
@companyId INT,
@userId INT,
@sourceModule VARCHAR(50),
@sourceRecordId INT
AS
BEGIN
  	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY   
        --DECLARE @userId INT = 29, @sourceModule VARCHAR(50) = 'WorkOrder', @sourceRecordId INT = 24 ; --> WO-25-00024
 
        DROP TABLE IF EXISTS #historyLog;

        CREATE TABLE #historyLog (rowNo INT, actionNotificationId BIGINT, eventType VARCHAR(100), comment VARCHAR(256), createDate DATETIME)

        INSERT INTO #historyLog (rowNo, actionNotificationId, eventType, comment, createDate)
        EXEC [dbo].[SSP_CDC_SelectHistoryLogByResourceId] @companyId, @userId, @sourceModule, @sourceRecordId

        UPDATE nr SET
            isRead = 1
        FROM notificationRecipient nr
            INNER JOIN #historyLog l
                ON nr.notificationID = l.actionNotificationId
		WHERE nr.userId = @userId

		SELECT '_SUCCESS_' as status, '' as returnMessage
				
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

		IF (XACT_STATE()) = 1  
		BEGIN  
			COMMIT TRANSACTION ;     
		END;  
 

		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

