-- =============================================
-- Author:		WL Leong
-- Create date: 2025-09-01
-- Used By:	    EMS -> SO Module -> SO Approval -> Approve SO

-- Description : Once the SO is confirmed, can multi select to approve

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-29   1.1         ZY Wong     Restructure sp
-- 2025-09-01	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC [SSP_SalesOrder_ApproveOrder] N'{"soList":[{"soHeaderId":"30932"}]}', 1

CREATE PROCEDURE [dbo].[SSP_SalesOrder_ApproveOrder]
@orderJson VARCHAR(MAX),
@approveBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
 
	BEGIN TRY

		DECLARE @transId VARCHAR(50) = NEWID();

		INSERT INTO pro_eventLog(procedureName, transId,  userId, startDate, endDate, logStatus, jsonParam, returnMessage)		
		SELECT 'SSP_SalesOrder_ApproveOrder', @transId, @approveBy,  getdate(), NULL, '_START_', @orderJson, NULL
		
        DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #order;

		SELECT soHeaderId
		INTO #order
		FROM  OPENJSON(@orderJson, '$.soList') 
   			WITH (
				soHeaderId BIGINT	N'$.soHeaderId'
			)

		DROP TABLE IF EXISTS #orderList;

		SELECT s.soName, s.soHeaderId, s.soStatus
		INTO #orderList
		FROM soHeader s
			INNER JOIN #order odr
				ON s.soHeaderId = odr.soHeaderId

        IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 6237) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already approved.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 6237)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 2125) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already in production.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 2125)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 1107) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already canceled.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 1107)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 1108) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already closed.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 1108)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #orderList WHERE soStatus NOT IN (1106)) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' not able to approve.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus NOT IN (1106))g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END
	 
		BEGIN TRANSACTION

			UPDATE soHeader SET
				soStatus = 6237,
				apiStatus = '_APPR_',
				approveBy = @approveBy,
				approveDate = getdate()
			FROM #orderList odr
			WHERE odr.soHeaderId = soHeader.soHeaderId
				AND soHeader.soStatus = 1106

            UPDATE soLineItem SET
				soLineItemStatus = 6237
			FROM #orderList odr
			WHERE odr.soHeaderId = soLineItem.soHeaderId
				AND soLineItemStatus = 1106	
	 
		COMMIT TRANSACTION

        SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' success approved.'
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 1106 )g
                                  );

        SELECT '_SUCCESS_' as status, @ErrMessage AS returnMessage
 
		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
        IF @ErrMessage IS NULL
            SET @ErrMessage = 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE();

		SELECT '_FAILURE_' as status, @ErrMessage as returnMessage

        RETURN -1
	END CATCH
END

GO

