-- =============================================
-- Author:		WL Leong
-- Create date: 2024-04-18
-- Used By:	    EMS -> LR Module -> LR LIsting -> View LR Line Item

-- Description : View Lr LIne Item

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-13	3.0			WL Leong	Get the poName 
-- 2024-04-24	2.0			WL Leong	Change to only list the container info in the packing list
-- 2024-04-18	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_LoadingRequest_SelectBookingInfo
37, 1

**/
--select * from lrReceive
--select * from lrContainer where lrname = 'MPH-LR-25-00013'
--select * from lrHeader

CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SelectBookingInfo]
@lrHeaderId BIGINT,
@containerSeq INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
        
        --DECLARE @lrHeaderId BIGINT = 5, @containerSeq INT = 1

		DECLARE @errorMessage As VARCHAR(200)
 
        DROP TABLE IF EXISTS #list;
 
        SELECT  lrContainerId, containerTypeId, containerSeq, containerNo, containerSealNo,
            forwarderId, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo,
            ETD, ETA, MAAP, Pouch, haulierId , portId, CAST('' as VARCHAR(20)) as portName
        INTO #list
        FROM lrContainer
        WHERE lrHeaderId =  @lrHeaderId
            AND containerSeq = @containerSeq
 
		UPDATE #list SET
			portName = p.portName
		FROM md_port p
		WHERE #list.portId = p.portId

        DROP TABLE IF EXISTS #lrLineItem;

        SELECT DISTINCT mc.categoryName as containerType, containerSeq, 
            ISNULL(containerNo, '') as containerNo, ISNULL(containerSealNo, '') as containerSealNo, lr.forwarderId,
            fd.categoryName as forwarder, forwarderBookingId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo,
            ETD, ETA, MAAP, Pouch, ISNULL(lr.haulierId, 0) as haulierId, ISNULL(h.haulier, '') as haulier, portId, portName
        FROM #list lr 
            INNER JOIN md_masterCategory mc
                ON lr.containerTypeId = mc.categoryId
            LEFT JOIN md_masterCategory fd
                ON lr.forwarderId = fd.categoryId
            LEFT JOIN md_haulier h
                ON lr.haulierId = h.haulierId

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

