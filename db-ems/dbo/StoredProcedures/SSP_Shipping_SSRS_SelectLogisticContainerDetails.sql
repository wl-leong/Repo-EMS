-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-11-25
-- Used By:		Report Module -> Shipment -> SSRS - Logistic Container Details

-- Description:	Get shipping info summary of particular report date

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-19   2.0         ZY Wong     Change parameter @reportMonth & @reportYear into variable, Add parameter @reportDate, Add column soName 
-- 2025-02-05   1.1         ZY Wong     Change lr table to lrContainer
-- 2024-11-25	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_Shipping_SSRS_SelectLogisticContainerDetails] 4, '2025-05-01'
CREATE PROCEDURE [dbo].[SSP_Shipping_SSRS_SelectLogisticContainerDetails]
@companyId INT,
@reportDate DATE
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
    SET DATEFORMAT ymd;

        --DECLARE @companyId INT = 4, @reportDate DATE = '2025-05-01';

        DECLARE @reportMonth INT = MONTH(@reportDate);
        DECLARE @reportYear INT = YEAR(@reportDate);
        DECLARE @monthName VARCHAR(10) = LEFT(DATENAME(MONTH, @reportDate),3) + '-' + RIGHT(CAST(@reportYear as VARCHAR),2);

        DROP TABLE IF EXISTS #shipmentInfo;

        SELECT shipmentId, shipId, lrHeaderId, 
            forwarderBookingNo, containerSeqNo, pod as destination, containerNo, containerSealNo, CONVERT(DATE, shipmentDate) as shipmentDate, containerPullInDate, containerPullOutDate,
             haulierId, CAST(containerMaxGross as VARCHAR) as containerMaxGross, CAST(containerTare as VARCHAR) as containerTare, containerTypeId
        INTO #shipmentInfo
        FROM shipmentHeader
        WHERE companyId = @companyId
            AND DATEPART(month, shipmentDate) = @reportMonth
            AND DATEPART(year, shipmentDate) = @reportYear

        DROP TABLE IF EXISTS #lrDetails;

        SELECT DISTINCT shp.shipmentId, shp.lrHeaderId, lc.containerSeq, 
            CAST(FORMAT(lc.earlyShipDate, 'MM/dd') as VARCHAR) + ' - ' + CAST(FORMAT(lc.lateShipDate, 'MM/dd') as VARCHAR) as shippingWindow,
            li.soHeaderId
        INTO #lrDetails
        FROM lrContainer lc
            INNER JOIN #shipmentInfo shp
                ON lc.lrHeaderId = shp.lrHeaderId
                AND lc.containerSeq = shp.containerSeqNo
            INNER JOIN lrLineItem li
                ON lc.lrContainerId = li.lrContainerId

        ALTER TABLE #lrDetails ADD soName VARCHAR(50);

        UPDATE #lrDetails SET 
            soName = so.soName
        FROM soHeader so
        WHERE #lrDetails.soHeaderId = so.soHeaderId

        DROP TABLE IF EXISTS #lrSummary;

        SELECT lrHeaderId, containerSeq, shippingWindow, soName
        INTO #lrSummary
        FROM #lrDetails

        ALTER TABLE #shipmentInfo ADD haulier VARCHAR(50);
        ALTER TABLE #shipmentInfo ADD containerType VARCHAR(10);

        UPDATE #shipmentInfo SET
            haulier = UPPER(hl.haulier)
        FROM md_Haulier hl
        WHERE #shipmentInfo.haulierId = hl.haulierId
            AND hl.statusFlag = 1

        UPDATE #shipmentInfo SET
            containerType = ct.categoryName
        FROM md_MasterCategory ct
        WHERE #shipmentInfo.containerTypeId = ct.categoryId
            AND ct.categoryParentID = 3153  --container type
            AND ct.status = 1

        SELECT ROW_NUMBER() OVER (ORDER BY shipmentDate, lrHeaderId, containerSeqNo, soName) as rowNo, @monthName as [monthName],
            soName, forwarderBookingNo, containerSeqNo, destination, containerNo, containerSealNo, shipmentDate, shippingWindow, containerPullInDate, containerPullOutDate,
            haulier, containerMaxGross, containerTare, containerType       
        FROM (SELECT DISTINCT s.lrHeaderId, soName, forwarderBookingNo, containerSeqNo, destination, containerNo, containerSealNo, shipmentDate, shippingWindow, containerPullInDate, containerPullOutDate,
                    haulier, containerMaxGross, containerTare, containerType
                FROM #shipmentInfo s
                    INNER JOIN #lrDetails lr
                        ON s.lrHeaderId = lr.lrHeaderId
                        AND s.containerSeqNo = lr.containerSeq
            )g
        ORDER BY rowNo
                                
END

GO

