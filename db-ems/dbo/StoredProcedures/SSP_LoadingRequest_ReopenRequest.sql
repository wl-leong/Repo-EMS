-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-11
-- Used By:	    EMS -> LR Module -> LR Listing -> Approve LR
--
-- Description : Change LR status to approved
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-11	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_ReopenRequest N'{"lrList":[{"lrHeaderId":"2"}]}', 1
 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_ReopenRequest]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
 
		--DECLARE @Json VARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @Json = N'{"lrList":[{"lrHeaderId":"1"}]}'

		-- Read json content
		DROP TABLE IF EXISTS #lr;

		SELECT * 
		INTO #lr
		FROM  OPENJSON(@Json, '$.lrList') 
   			WITH (
				lrHeaderId BIGINT			N'$.lrHeaderId'
			)

		DROP TABLE IF EXISTS #lrInfo;

		SELECT lrd.lrHeaderId, lrd.lrName, lrd.lrStatus
		INTO #lrInfo
		FROM lrHeader lrd
			INNER JOIN #lr l
				ON lrd.lrHeaderId = l.lrHeaderId
 
		DECLARE @returnMessage as VARCHAR(500), @poMessage as VARCHAR(500)

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2130) > 0
		BEGIN
			SELECT @returnMessage = COALESCE(@returnMessage + ', ' + lrName, lrName) 
			From #lrInfo 
			WHERE lrStatus = 2130

			SELECT '_ALERT_' as status, 'Lr# ' + @returnMessage + ' is/are already canceled, cannot reopen' AS returnMessage 

			RETURN -1
		END
		
		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2131) > 0
		BEGIN
			SELECT @returnMessage = COALESCE(@returnMessage + ', ' + soName, soName) 
			From #lrInfo 
			WHERE lrStatus = 2131

			SELECT '_ALERT_' as status, 'SO# ' + @returnMessage + ' is/are already closed, cannot reopen' AS returnMessage 

			RETURN -1
		END

		BEGIN TRANSACTION
			IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus IN (2129)) > 0
			BEGIN

				UPDATE lrHeader SET
					lrStatus = 2145,	
					lrApprovalBy = @updateBy,
					lrApprovalDate = getdate()
				FROM  #lrInfo lr
				WHERE lr.lrHeaderId = lrHeader.lrHeaderId
					AND lrHeader.lrStatus IN (2129)
	 
				UPDATE lrLineItem SET
					itemStatus = 2145,
					updateBy = @updateBy,
					updateDate = getdate()
				FROM #lrInfo lr
				WHERE lr.lrHeaderId = lrLineItem.lrHeaderId
					AND itemStatus IN (2129)

				SELECT @returnMessage = COALESCE(@returnMessage + ', ' + lrName, lrName) 
				FROM #lrInfo 
				WHERE lrStatus IN (2129)
			END

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'LR# '+ @returnMessage + ' has/have reopen' AS returnMessage 

	
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage

		RETURN -1
	END CATCH
END

GO

