-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Close SO

-- Description : Once the SO is done and approved

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
 --EXEC SSP_SalesOrder_CloseOrder N'{"soList":[{"soHeaderId":20428,"notes":26}, {"soHeaderId":20429,"notes":26}]}', 2
CREATE PROCEDURE [dbo].[SSP_SalesOrder_CloseOrder]
@orderJson VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY

--1105	Draft
--1106	Confirmed
--2125  In Production
--1107	Cancel
--1108	Close
--2144	Reopen
        --DECLARE @orderJson NVARCHAR(MAX)
        --SET @orderJson = N'{"soList":[{"soHeaderId":20428,"notes":26}, {"soHeaderId":20429,"notes":26}]}'
		DROP TABLE IF EXISTS #order;

		SELECT soHeaderId, notes
		INTO #order
		FROM  OPENJSON(@orderJson, '$.soList') 
   			WITH (
				soHeaderId BIGINT	N'$.soHeaderId',
                notes VARCHAR(1000) N'$.notes'
			)

		IF (SELECT COUNT(1) FROM #order WHERE notes = '') > 0
		BEGIN
			SELECT '_ALERT_' as status, 'reason to close the SO# is compulsory' AS returnMessage 

			RETURN -1
		END

        DROP TABLE IF EXISTS #orderList;

		SELECT s.soHeaderId, s.soName 
        INTO #orderList
        FROM #order odr
            INNER JOIN soHeader s
                ON odr.soHeaderId = s.soHeaderId

        DROP TABLE IF EXISTS #poCheck;

        SELECT odr.soHeaderId, odr.soName, p.poStatus
        INTO #poCheck
        FROM #orderList odr
            INNER JOIN poHeader p
                ON odr.soName = p.poReferenceId
 

        IF (SELECT COUNT(1) FROM #poCheck WHERE poStatus = 1086) > 1
 		BEGIN
            DECLARE @soList VARCHAR(1000)
            SET @soList = (SELECT STRING_AGG(soName,'-') FROM #poCheck  WHERE poStatus = 1086)

			SELECT '_ALERT_' as status, 'SO# '+ @soList + ' , please close the related PO# before proceed to close' AS returnMessage 

			RETURN -1
		END

		BEGIN TRANSACTION
			DECLARE  @soName as TABLE(soName varchar(50))

			UPDATE s SET
				soStatus = 1108,
				apiStatus = '_NEW_',
				updateBy = @updateBy,
				updateDate = getdate()
			OUTPUT INSERTED.soName 
            INTO @soName
			FROM #order odr
				INNER JOIN soHeader s
					ON odr.soHeaderId = s.soHeaderId
					AND s.soStatus <> 1107
	 
			UPDATE sol SET
				soLineItemStatus = 1108,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #order odr
				INNER JOIN soLineItem sol
					ON odr.soHeaderId = sol.soHeaderId
					AND sol.soLineItemStatus <> 1107

            DECLARE @returnMessage VARCHAR(2000)

			SELECT @returnMessage = COALESCE(@returnMessage + ', ' + soName, soName) 
			FROM @soName

		COMMIT TRANSACTION

		SELECT '_SUCCESS_' as status, 'SO# '+ @returnMessage + ' is/are closed' AS returnMessage 
 
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

