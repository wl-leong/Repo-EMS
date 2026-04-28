-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-11
-- Used By:	    EMS -> LR Module -> LR Listing -> Approve LR
--
-- Description : Change LR status to approved
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-04-23   3.0         ZY Wong     Standardize error message handling, update lrContainer
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-11	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_ApproveRequest N'{"lrList":[{"lrHeaderId":"1"},{"lrHeaderId":"2"}]}', 1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_ApproveRequest]
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

        DECLARE @returnMessage as VARCHAR(5000);

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

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2129) > 0 
		BEGIN
			SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' already approved.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus = 2129)g);
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2134) > 0 
		BEGIN
            SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ') + ' already rejected.' 
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus = 2134)g);
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus <> 2133) > 0 
		BEGIN
            SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' not yet confirmed.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus <> 2133)g);
			THROW 60000, @returnMessage, 1; 
		END
		
		BEGIN TRANSACTION

			UPDATE lrHeader SET
				lrStatus = 2129,	
				lrApprovalBy = @updateBy,
				lrApprovalDate = getdate()
			FROM #lr lr
			WHERE lr.lrHeaderId = lrHeader.lrHeaderId
				AND lrStatus = 2133

            UPDATE lrContainer SET
				containerStatus = 2129,	
				containerApproveDate = getdate(),
				containerApproveBy = @updateBy
			FROM #lr lr
			WHERE lr.lrHeaderId = lrContainer.lrHeaderId
				AND containerStatus = 2133
	 
			UPDATE lrLineItem SET
				itemStatus = 2129,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #lr lr
			WHERE lr.lrHeaderId = lrLineItem.lrHeaderId
				AND itemStatus = 2133

		COMMIT TRANSACTION

		SET @returnMessage = (SELECT 'LR# '+ STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' success approved.'
                                FROM (SELECT DISTINCT lrName
                                        FROM #lrInfo 
			                            WHERE lrStatus = 2133)g);

		SELECT '_SUCCESS_' as status, @returnMessage AS returnMessage 
	
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 

        IF @returnMessage IS NULL
            SET @returnMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();
 
		SELECT
			'_FAILURE_' as status, @returnMessage as returnMessage
 
		RETURN -1
	END CATCH
END

GO

