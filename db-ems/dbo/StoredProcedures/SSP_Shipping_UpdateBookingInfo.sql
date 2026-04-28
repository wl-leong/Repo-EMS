-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> Loading Request -> Released LR -> Update booking info

-- Description : Edit info of Shipment Document

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025.05.07   3.0         ZY Wong     Update lrHeader.apiStatus = '_READYLOAD_' if bookingNo passed in
-- 2025-01-03	2.0			WL Leong	Update also ref_lrContainer
-- 2024-05-16	1.0			WL Leong	Initial
-- ==========================================================================================
/*
	EXEC [SSP_Shipping_UpdateBookingInfo] N'{"bookingList":[{
			       "lrHeaderId":10026,
                   "ContainerSeq":1,	   
                   "forwarderId":3163,	 
			       "forwarderBookingId":"EMCAA00001",
			       "forwarderBookingDate":"2024-05-18",
			       "forwarderReplyDate":"2024-05-31",
			       "forwarderSICutOffDate":"2024-05-31",
			       "forwarderBookingNo":"ABCDE",
			       "ETD":"2024-05-20",
			       "ETA":"2024-05-31",
			       "MAAP":"2024-06-31",
			       "pouch":"CCDDEE"
			}]}', 1
	select * from md_masterCategory  
*/
 
CREATE PROCEDURE [dbo].[SSP_Shipping_UpdateBookingInfo]
@Json VARCHAR(MAX),
@userId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		--DECLARE @Json VARCHAR(MAX) = 
		--	N'{"bookingList":[{
		--	       "lrHeaderId":3,
  --               "ContainerSeq":1,	   
		--	       "forwardBookingId":"EMCAA00001",
		--	       "forwardBookingDate":"2024-05-18",
		--	       "forwardReplyDate":"2024-05-31",
		--	       "forwardSICutOffDate":"2024-05-31",
		--	       "forwardBookingNo":"ABCDE",
		--	       "ETD":"2024-05-20",
		--	       "ETA":"2024-05-31",
		--	       "MAAP":"2024-06-31",
		--	       "pouch":"CCDDEE"
		--	}]}'
		--	, @userId INT = 1
 
		DECLARE @returnMessage VARCHAR(1000);
 
        DROP TABLE IF EXISTS #booking;

        SELECT lrHeaderId, ContainerSeq, forwarderId, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate,
            forwarderBookingNo, ETD, ETA, MAAP, pouch, portId
        INTO #booking 
        FROM OPENJSON(@Json, '$.bookingList') 
   				WITH (
					lrHeaderId BIGINT				    N'$.lrHeaderId',
                    ContainerSeq INT                    N'$.ContainerSeq',
                    forwarderId INT                     N'$.forwarderId',
                    forwarderBookingId VARCHAR(30)      N'$.forwarderBookingId',
                    forwarderBookingDate DATE           N'$.forwarderBookingDate',
                    forwarderReplyDate DATE             N'$.forwarderReplyDate',
                    forwarderSICutOffDate DATE          N'$.forwarderSICutOffDate',
                    forwarderBookingNo VARCHAR(30)      N'$.forwarderBookingNo',
					portId INT							N'$.portId',
                    ETD DATE                            N'$.ETD',
                    ETA DATE                            N'$.ETA',
                    MAAP VARCHAR(30)                    N'$.MAAP',
                    pouch VARCHAR(30)                   N'$.pouch'
                )
        
        DROP TABLE IF EXISTS #lrInfo;

        SELECT b.lrHeaderId, b.ContainerSeq, b.forwarderId, b.forwarderBookingId, b.forwarderBookingDate, b.forwarderReplyDate, b.forwarderSICutOffDate,
            b.forwarderBookingNo, b.ETD, b.ETA, b.MAAP, b.pouch, lr.lrContainerId, lr.lrName, lr.earlyShipDate, b.portId
        INTO #lrInfo
        FROM #booking b
            INNER JOIN lrContainer lr
                ON b.lrHeaderId = lr.lrHeaderId
               -- AND b.containerSeq = lr.containerSeq
			   
        DROP TABLE IF EXISTS #validate;

        SELECT lr.lrName, lr.earlyShipDate, portId
        INTO #validate
        FROM #lrInfo lr

        IF (SELECT COUNT(DISTINCT earlyShipDate) FROM #validate) > 1
        BEGIN
            SET @returnMessage = 'Diff. shipdate cannot merge into same booking info';
            THROW 60000, @returnMessage, 1;
        END

        IF (SELECT COUNT(DISTINCT portId) FROM #validate) > 1
        BEGIN
            SET @returnMessage = 'Diff. POD cannot merge into same booking info';
            THROW 60000, @returnMessage, 1;
        END

        DECLARE @lrHeader TABLE (lrHeaderId BIGINT);
        DELETE FROM @lrHeader

		BEGIN TRANSACTION
         
         -- update marketing company LR
		    UPDATE lrContainer SET
                cargoReadyDate = DATEADD(DAY, -8, l.earlyShipDate),
                forwarderId = l.forwarderId,
            	forwarderBookingId = l.forwarderBookingId,
                forwarderBookingNo = l.forwarderBookingNo,
			    forwarderBookingDate = l.forwarderBookingDate,
			    forwarderReplyDate = l.forwarderReplyDate,
			    forwarderSICutOffDate = l.forwarderSICutOffDate,	
			    ETD = CONVERT(date, l.ETD),	
			    ETA = CONVERT(date, l.ETA),	 
                maap = l.maap,
			    pouch = l.pouch,
				portId = l.portId,
			    updateBy = @userId,
			    updateDate = getdate()
            OUTPUT INSERTED.lrHeaderId
            INTO @lrHeader
		    FROM #lrInfo l
		    WHERE l.lrContainerId = lrContainer.lrContainerId

        -- update F&P LR
		    UPDATE lrContainer SET
                cargoReadyDate = DATEADD(DAY, -8, l.earlyShipDate),
                forwarderId = l.forwarderId,
            	forwarderBookingId = l.forwarderBookingId,
                forwarderBookingNo = l.forwarderBookingNo,
			    forwarderBookingDate = l.forwarderBookingDate,
			    forwarderReplyDate = l.forwarderReplyDate,
			    forwarderSICutOffDate = l.forwarderSICutOffDate,	
			    ETD = CONVERT(date, l.ETD),	
			    ETA = CONVERT(date, l.ETA),	 
                maap = l.maap,
			    pouch = l.pouch,
				portId = l.portId,
			    updateBy = @userId,
			    updateDate = getdate()
            OUTPUT INSERTED.lrHeaderId
            INTO @lrHeader
		    FROM #lrInfo l
		    WHERE l.lrContainerId = lrContainer.ref_lrContainerId
 
            IF (SELECT COUNT(1) FROM #lrInfo WHERE ISNULL(forwarderBookingNo,'') <> '') > 0
            BEGIN
                UPDATE lrHeader SET
                    apiStatus = '_READYLOAD_'
                WHERE lrHeaderId IN (SELECT lrHeaderId FROM @lrHeader)
                    
            END
 
		COMMIT TRANSACTION
        
        SELECT '_SUCCESS_' as status, 'Booking info success update.' as returnMessage

		RETURN 0
	END TRY

	BEGIN CATCH
		IF (@@TRANCOUNT > 0 OR XACT_STATE() = 1)
		BEGIN
			ROLLBACK TRANSACTION 
		END 
 
		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO

