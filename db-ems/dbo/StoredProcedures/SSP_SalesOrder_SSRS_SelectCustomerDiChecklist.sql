-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-12-03
-- Used By:		Shipping Module -> SSRS - CustomerDiChecklist

-- Description:	Get sales order info of particular date range for specific customer

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-03-17   2.0         ZY Wong     Use md_port for destination
-- 2025-01-20   1.1         ZY Wong     Add customerName
-- 2024-12-03	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_SalesOrder_SSRS_SelectCustomerDiChecklist] 4,'19,29','2024-08-01','2025-12-30'
-- EXEC [SSP_SalesOrder_SSRS_SelectCustomerDiChecklist] 11,'26,30','2024-08-01','2025-12-30'
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectCustomerDiChecklist]
@companyId INT,
@customerList NVARCHAR(MAX),
@reportStartDate DATE,
@reportEndDate DATE
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
    SET DATEFORMAT ymd;

        --DECLARE @companyId INT = 4,
        --@customerList NVARCHAR(MAX) = '19,20,24,29',
        --@reportStartDate DATE = '2024-08-01' ,
        --@reportEndDate DATE = '2025-01-20'

        DROP TABLE IF EXISTS #customerList;

        SELECT csl.value as customerId, cs.customerName, cs.customerShortCode as customer, cs.internal_branchId as isInternalBranch
        INTO #customerList 
        FROM string_split(@customerList,',') csl
            INNER JOIN md_Customer cs
                ON csl.value = cs.customerId
                AND cs.companyId = @companyId
        ORDER BY cs.customerName

        DECLARE @customerName VARCHAR(1000) = (SELECT STRING_AGG(customerName, ', ') FROM #customerList );

        DROP TABLE IF EXISTS #soList;

        SELECT soHeaderId, soName, so.customerId, cs.customer, customerPo, thirdPartyPo, earlyShipDate, lateShipDate, DATEADD(DAY, -2, earlyShipDate) as bookingETD, shipToId, portOfDestination,
            reference1 as customerSoName, cs.isInternalBranch
        INTO #soList
        FROM soHeader so
            INNER JOIN #customerList cs
                ON so.customerId = cs.customerId
        WHERE companyId = @companyId
            AND earlyShipDate BETWEEN @reportStartDate AND @reportEndDate

        ALTER TABLE #soList ADD destination VARCHAR(50);
            
        UPDATE #soList SET
            destination = UPPER(pt.portName)
        FROM md_Port pt
        WHERE #soList.portOfDestination = pt.portId

        DROP TABLE IF EXISTS #internalSoList;

        SELECT l.soHeaderId, so.soHeaderId as customerSoHeaderId
        INTO #internalSoList
        FROM soHeader so
            INNER JOIN #soList l
                ON so.soName = l.customerSoName
        WHERE l.isInternalBranch <> 0

        DROP TABLE IF EXISTS #soInfo;

        SELECT customer, customerPo, thirdPartyPo, earlyShipDate, lateShipDate, bookingETD, destination, soName, 
            CASE WHEN customerSoHeaderId IS NULL THEN l.soHeaderId ELSE customerSoHeaderId END as soHeaderId, customerSoName
        INTO #soInfo
        FROM #soList l
            LEFT JOIN #internalSoList il
                ON l.soHeaderId = il.soHeaderId

        DROP TABLE IF EXISTS #lrInfo;

        SELECT so.soHeaderId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo, ETD, ETA, MAAP, Pouch, count( DISTINCT containerSeq) as volume
        INTO #lrInfo
        FROM lrContainer c
            INNER JOIN lrLineItem lr
                ON c.lrHeaderId = lr.lrHeaderId
            INNER JOIN #soInfo so
                ON lr.soHeaderId = so.soHeaderId
        GROUP BY so.soHeaderId, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo, ETD, ETA, MAAP, Pouch

        SELECT customer, customerPo, thirdPartyPo, earlyShipDate, lateShipDate, bookingETD, destination, volume,
            soName, forwarderBookingDate, forwarderReplyDate, forwarderSICutOffDate, forwarderBookingNo, ETD, ETA, MAAP, pouch, customerSoName,
            @customerName as customerNameList
        FROM #soInfo so
            LEFT JOIN #lrInfo lr
                ON so.soHeaderId = lr.soHeaderId
        ORDER BY earlyShipDate, customerPo
            
END

GO

