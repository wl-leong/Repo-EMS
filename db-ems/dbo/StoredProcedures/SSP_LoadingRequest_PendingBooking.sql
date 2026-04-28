-- =============================================
-- Author:		WL Leong
-- Create date: 2023-12-10
-- Used By:	    EMS -> LR Module -> Pending Booking

-- Description : LR that is released but not yet make booking with forwarder

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-05-05	2.0			WL Leong	simplify and unique lr and container
-- 2024-04-18	1.0			WL Leong	Initial
-- ==========================================================================================
/**
EXEC SSP_LoadingRequest_PendingBooking
11, 2135, '2024-07-16', '2025-08-30',  1, 10
**/
--select * from lrHeader 
--select * from lrContainer where lrHeaderId = 10016
 
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_PendingBooking]
@companyId INT,
@lrStatus INT,
@startDate DATE,
@endDate DATE,
@rowStart INT,
@pageRow INT 
--@sortBy INT = 1,
--@sortDirection VARCHAR(4) = 'ASC'
AS
BEGIN
    BEGIN TRY
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DROP TABLE IF EXISTS #header;

    SELECT l.lrHeaderId, supplierId, l.lrName, l.lrNote, l.lrStatus
    INTO #header
    FROM lrHeader l 
    WHERE l.companyId = 11 --@companyId
		AND l.lrStatus NOT IN (2130, 2131) -- not closed/cancel

    DROP TABLE IF EXISTS #lineItem;

    SELECT l.lrHeaderId, l.lrName, l.supplierId,
        lr.lrContainerId, lr.earlyShipDate, lr.lateShipDate, lr.containerTypeId, containerSeq, l.lrStatus,  
        lr.forwarderBookingId, lr.forwarderBookingNo, lr.forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate,
        ETD, ETA, MAAP, Pouch, CAST('' as VARCHAR(20)) containerType, CAST('' as VARCHAR(20)) as [status], CAST('' as VARCHAR(20)) as customerName
    INTO #lineItem
    FROM #header l
        INNER JOIN lrContainer lr 
            ON l.lrHeaderId = lr.lrHeaderId
    WHERE lr.containerStatus NOT IN (2130, 2131)
 
	
	UPDATE li SET
		containerType = ctype.categoryName
	FROM #lineItem li
		INNER JOIN md_masterCategory ctype
            ON li.containerTypeId = ctype.categoryId

	UPDATE li SET
		[status] = st.categoryName
	FROM #lineItem li
		INNER JOIN md_masterCategory st
            ON li.lrStatus = st.categoryId
 
	ALTER TABLE #lineItem ADD poId BIGINT;
	ALTER TABLE #lineItem ADD soHeaderId BIGINT;

	UPDATE #lineItem SET
		poId = l.poId,
		soHeaderId = l.soHeaderId
	FROM #lineItem li
		INNER JOIN lrLineItem l
			ON li.lrContainerId = l.lrContainerId
  
 
    UPDATE li SET
        customerName = p.customerCode
    FROM #lineItem li
        INNER JOIN poHeader p
            ON li.poId = p.poId
 

    DROP TABLE IF EXISTS #soName;

    SELECT lrHeaderId, STRING_AGG(s.soName, ',') as soName
    INTO #soName
    FROM (
        SELECT DISTINCT lrHeaderId, s.soName 
        FROM #lineItem li
            INNER JOIN soHeader s
                ON li.soHeaderId = s.soHeaderId
        ) s
    GROUP BY lrHeaderId



    SELECT lrHeaderId, lrName, customerName, earlyShipDate, containerType, containerSeq,
        forwarderBookingId, forwarderBookingNo, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, ETD, ETA, MAAP, Pouch,
         [status]
    FROM (
        SELECT l.lrHeaderId, l.lrName, l.customerName, l.earlyShipDate, l.containerType, l.containerSeq, 
            forwarderBookingId, forwarderBookingNo, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, ETD, ETA, MAAP, Pouch,
            [status], ROW_NUMBER() OVER(ORDER BY l.earlyShipDate) as RowNo
        FROM (SELECT lrHeaderId, lrName, customerName, earlyShipDate, containerType, COUNT(containerSeq) as containerSeq,
                    forwarderBookingId, forwarderBookingNo, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, ETD, ETA, MAAP, Pouch,
                    [status]
              FROM #lineItem l
			  GROUP BY lrHeaderId, lrName, customerName, earlyShipDate, containerType,
                    forwarderBookingId, forwarderBookingNo, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, ETD, ETA, MAAP, Pouch,
                    [status]
              ) l
    ) g 
    WHERE rowNo BETWEEN @rowStart AND @rowStart + @pageRow
    ORDER BY earlyShipDate
 
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

