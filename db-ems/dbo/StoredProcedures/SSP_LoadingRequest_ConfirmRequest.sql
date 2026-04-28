-- =============================================
-- Author:		ZY Wong
-- Create date: 2023-12-11
-- Used By:	    EMS -> LR Module -> LR Listing -> Confirm LR
--
-- Description : Change LR status to pending approval
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-04-23   4.0         ZY Wong     Standardize error message handling
-- 2025-01-02	3.0			WL Leong	Check container using lrContainer
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-18	1.1			ZY Wong		Add REPLACE(lrName, 'tempLR_', '') for lrName
-- 2023-12-11	1.0			ZY Wong		Initial
-- ==========================================================================================
-- EXEC SSP_LoadingRequest_ConfirmRequest N'{"lrList":[{"lrHeaderId":"1"},{"lrHeaderId":"2"}]}', 1
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_ConfirmRequest]
@Json VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY	
		--DECLARE @Json VARCHAR(MAX)
		--DECLARE @updateBy INT = 1
		--SET @Json = N'{"lrList":[ {"lrHeaderId":"10"},{"lrHeaderId":"7"}]}'

        DECLARE @returnMessage as VARCHAR(500);

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

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus = 2133) > 0
		BEGIN
			SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ')  + ' already confirmed.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo 
			                                WHERE lrStatus = 2133)g);
			THROW 60000, @returnMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #lrInfo WHERE lrStatus NOT IN (2132, 2134, 2145)) > 0
		BEGIN
			SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ') + ' not able to confirm.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #lrInfo
			                                WHERE lrStatus NOT IN (2132, 2134, 2135))g); 
			THROW 60000, @returnMessage, 1;
		END

        DROP TABLE IF EXISTS #containertype;

        SELECT l.lrHeaderId, l.lrName
        INTO #containertype
        FROM #lrInfo l
			LEFT JOIN lrContainer lc
				ON l.lrHeaderId = lc.lrHeaderId
        WHERE ISNULL(lc.containerTypeId, 0) = 0

		IF (SELECT COUNT(1) FROM #containertype) > 0
		BEGIN
			SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ') + ' have empty container type.'
                                    FROM (SELECT DISTINCT lrName
                                            FROM #containertype)g);
            THROW 60000, @returnMessage, 1;
		END

		BEGIN TRANSACTION

			UPDATE lrHeader SET
				lrName = REPLACE(lrName, 'tempLR_', ''),
				lrStatus = 2133,	
				lrConfirmDate = getdate(),
				updateBy = @updateBy
			FROM #lr lr
			WHERE lr.lrHeaderId = lrHeader.lrHeaderId
				AND lrStatus IN (2132, 2134, 2145)

			UPDATE lrContainer SET
				lrName = REPLACE(lrName, 'tempLR_', ''),
				containerStatus = 2133,	
				containerConfirmDate = getdate(),
				containerConfirmBy = @updateBy
			FROM #lr lr
			WHERE lr.lrHeaderId = lrContainer.lrHeaderId
				AND containerStatus IN (2132, 2134, 2145)
 
			UPDATE lrLineItem SET
				lrName = REPLACE(lrName, 'tempLR_', ''),
				itemStatus = 2133,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #lr lr
			WHERE lr.lrHeaderId = lrLineItem.lrHeaderId
				AND itemStatus IN (2132, 2134, 2145)

		COMMIT TRANSACTION

		SET @returnMessage = (SELECT 'LR# ' + STRING_AGG(CONVERT(NVARCHAR(MAX), lrName), ', ') + ' success confirmed.'
                                FROM (SELECT DISTINCT lrName
                                        FROM #lrInfo 
			                            WHERE lrStatus IN (2132, 2134, 2135))g); 

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

