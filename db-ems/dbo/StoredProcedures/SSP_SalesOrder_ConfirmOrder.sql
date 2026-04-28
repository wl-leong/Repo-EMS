-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Confirm SO

-- Description : Once the SO is draft / reopened, can multi select to confirm

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-29   11.0        ZY Wong     Add validation for approved SO
-- 2025-03-21	10.0        WL Leong	port of destination is blank cannot confirm
-- 2024-11-26   6.0         WL Leong	for factory to confirm SO# tagDivision = "Others" SO# status is not allowed
-- 2024-10-24   5.0         WL Leong    Factory SO no need to have supplier
-- 2024-07-11   4.0         ZY Wong     Add validation for empty supplier, standardize @ErrMessage & returnMessage
-- 2024-06-10	3.0			WL Leong	If line item count is 0 cannot confirm so
-- 2024-01-22	2.0			ZY Wong		Add XACT_ABORT
-- 2023-12-12	1.1			ZY Wong		Check soStatus and return error message
-- 2023-06-08	1.0			WL Leong	Initial
-- ==========================================================================================
-- EXEC SSP_SalesOrder_ConfirmOrder
-- N'{"soList":[{"soHeaderId":"30932"}]}', 1
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_ConfirmOrder]
@orderJson VARCHAR(MAX),
@updateBy INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @orderJson VARCHAR(MAX)
		--DECLARE @createdBy INT = 1
		--SET @orderJson = N'{"soList":[{"soHeaderId":"10006"}, {"soHeaderId":"10007"}]}'
		-- Read json content

        DECLARE @ErrMessage VARCHAR(MAX);

		DROP TABLE IF EXISTS #order;

		SELECT * 
		INTO #order
		FROM  OPENJSON(@orderJson, '$.soList') 
   			WITH (
				soHeaderId BIGINT			N'$.soHeaderId'
			)

		DROP TABLE IF EXISTS #orderList;

		SELECT so.soHeaderId, soName, soStatus, companyId, supplierId, so.portOfDestination
		INTO #orderList
		FROM soHeader so  
			INNER JOIN #order odr
				ON so.soHeaderId = odr.soHeaderId

		DECLARE @companyId INT, @isMarketing INT;

		SET @companyId = (SELECT TOP 1 companyId FROM #orderList)
		SET @isMarketing = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId)
		 
 
        IF (SELECT COUNT(1) FROM #orderList WHERE portOfDestination = 0 or portOfDestination = '') > 0 
		BEGIN
			SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' has no port configured.' 
                                    FROM (SELECT DISTINCT  soName
                                            FROM #orderList  
                                             WHERE portOfDestination = 0 or portOfDestination = '')g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END
 
        IF (SELECT COUNT(1) FROM #orderList WHERE supplierId = 0) > 0 AND @isMarketing = 1
		BEGIN
			SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' have no supplier choosen.' 
                                    FROM (SELECT DISTINCT  soName
                                            FROM #orderList  
                                            WHERE supplierId = 0)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 1106) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already confirmed.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 1106)g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

        IF (SELECT COUNT(1) FROM #orderList WHERE soStatus = 6237) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' already approved.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus = 6237)g
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

		IF (SELECT COUNT(1) FROM #orderList WHERE soStatus NOT IN (2144, 1105)) > 0
		BEGIN
            SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' not able to confirm.' 
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus NOT IN (2144, 1105))g
                                  );                                 
            THROW 60000, @ErrMessage, 1;
		END

		IF (SELECT COUNT(1) FROM solineItem s INNER JOIN #orderList so ON s.soHeaderId = so.soheaderId 
            WHERE soLineItemStatus IN (1105, 1106, 2144, 2125) ) = 0
		BEGIN
            SET @ErrMessage = 'SO# does not have line item to confirm.';                                 
            THROW 60000, @ErrMessage, 1;		
        END
 
        IF @isMarketing = 0
        BEGIN
            DROP TABLE IF EXISTS #tagDivision;

            SELECT DISTINCT soName 
            INTO #tagDivision
            FROM soLineitem li
                INNER JOIN #orderList s
                    ON s.soHeaderId = li.soHeaderId
            WHERE tagDivision = 3234

            IF (SELECT COUNT(1) FROM #tagDivision) > 0
            BEGIN
                SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(MAX), soName), ',') + ' not able to confirm, Please marked all line item(s) with correct division tag.' 
                                        FROM (SELECT DISTINCT soName
                                                FROM #tagDivision)g
                                      );                                 
                THROW 60000, @ErrMessage, 1;

            END 
        END
--1105	Draft
--1106	Confirmed
--1107	Cancel
--1108	Close
--2125	In Production
--2144	ReOpen
 
		BEGIN TRANSACTION

			UPDATE soHeader SET
				soName = REPLACE(soHeader.soName, 'tempSO_', ''),
				soStatus = 1106,
				apiStatus = '_NEW_',
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #orderList odr
			WHERE odr.soHeaderId = soHeader.soHeaderId
				AND soHeader.soStatus IN (2144, 1105)

			UPDATE soLineItem SET
				soLineItemStatus = 1106,
				updateBy = @updateBy,
				updateDate = getdate()
			FROM #orderList odr
			WHERE odr.soHeaderId = soLineItem.soHeaderId
				AND soLineItemStatus IN (2144, 1105)			
 
		COMMIT TRANSACTION

        SET @ErrMessage = (SELECT 'SO# ' + STRING_AGG(CONVERT(VARCHAR(max), soName), ',') + ' success confirmed.'
                                    FROM (SELECT DISTINCT soName
                                            FROM #orderList  
                                            WHERE soStatus IN (2144, 1105) )g
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

