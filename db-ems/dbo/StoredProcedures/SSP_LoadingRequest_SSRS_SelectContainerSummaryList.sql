-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-05-21
-- Used By:	    EMS -> Shipping Module 
--
-- Description : 
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-21	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_LoadingRequest_SSRS_SelectContainerSummaryList]  11,'2025-05-05','2025-05-06'
CREATE PROCEDURE [dbo].[SSP_LoadingRequest_SSRS_SelectContainerSummaryList]
@companyId BIGINT,
@rptStartDate DATE,
@rptEndDate DATE
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        --DECLARE @companyId BIGINT = 4; DECLARE @rptStartDate DATE = '2025-04-05', @rptEndDate DATE = '2025-07-06'
        DECLARE @isMarketing INT = (SELECT isMarketing FROM md_company WHERE companyId = @companyId);

        DROP TABLE IF EXISTS #lrList;

        SELECT DISTINCT lr.lrHeaderId, lr.customerId
        INTO #lrList
        FROM lrHeader lr
            INNER JOIN lrContainer lc
                ON lr.lrHeaderId = lc.lrHeaderId
        WHERE lr.companyId = @companyId
            AND lc.lateShipDate BETWEEN @rptStartDate AND @rptEndDate

        DROP TABLE IF EXISTS #lrItems;

        SELECT lr.lrHeaderId, lr.customerId, lrDetailsId, lrContainerId, invId, soHeaderId
        INTO #lrItems
        FROM lrLineItem li
            INNER JOIN #lrList lr
                ON li.lrHeaderId = lr.lrHeaderId

        ALTER TABLE #lrItems ADD inventoryTypeId INT;
        ALTER TABLE #lrItems ADD inventoryType VARCHAR(150);
        ALTER TABLE #lrItems ADD soName VARCHAR(50);
        ALTER TABLE #lrItems ADD soDate DATE;  --inquiryDate
        ALTER TABLE #lrItems ADD customerPo VARCHAR(300);
        ALTER TABLE #lrItems ADD thirdPartyPo VARCHAR(300);
        ALTER TABLE #lrItems ADD shipToId INT;
        ALTER TABLE #lrItems ADD shipTo VARCHAR(50);
        ALTER TABLE #lrItems ADD customer VARCHAR(150);
        ALTER TABLE #lrItems ADD customerShortCode VARCHAR(3);

        UPDATE #lrItems SET
            inventoryTypeId = inv.productType
        FROM md_inventory inv
        WHERE #lrItems.invId = inv.invId

        UPDATE #lrItems SET
            inventoryType = pt.inventoryType
        FROM md_inventoryType pt
        WHERE #lrItems.inventoryTypeId = pt.inventoryTypeId

        UPDATE #lrItems SET
            soName = so.soName,
            soDate = so.soDate,
            customerPo = so.customerPo,
            thirdPartyPo = so.thirdPartyPo,
            shipToId = so.shipToId,
            customerId = CASE WHEN #lrItems.customerId = 0 THEN so.customerId ELSE #lrItems.customerId END
        FROM soHeader so
        WHERE #lrItems.soHeaderId = so.soHeaderId

        UPDATE #lrItems SET
            shipTo = st.shipToLabel
        FROM md_shipToDestination st
        WHERE #lrItems.shipToId = st.shipToId

        IF @isMarketing = 1
        BEGIN            
            UPDATE #lrItems SET
                thirdPartyPo = customerPo

            UPDATE #lrItems SET
                customerPo = po.poName
            FROM poHeader po
            WHERE #lrItems.soName = po.poReferenceId
        END

        UPDATE #lrItems SET
            customer = cs.customerName,
            customerShortCode = cs.customerShortCode
        FROM md_customer cs
        WHERE #lrItems.customerId = cs.customerId

        DROP TABLE IF EXISTS #lrContainer;

        SELECT DISTINCT li.lrContainerId, lateShipDate, containerTypeId, containerSeq
        INTO #lrContainer
        FROM lrContainer lc
            INNER JOIN #lrItems li
                ON lc.lrContainerId = li.lrContainerId

        ALTER TABLE #lrContainer ADD containerType VARCHAR(10);

        UPDATE #lrContainer SET
            containerType = ct.categoryName
        FROM md_masterCategory ct
        WHERE #lrContainer.containerTypeId = ct.categoryId

        DROP TABLE IF EXISTS #itemSummary;

        SELECT li.lrHeaderId, li.lrDetailsId, lc.lrContainerId, soHeaderId, li.customerId,
            customer, lateShipDate, soDate, customerPo, thirdPartyPo, inventoryType, containerType, containerSeq, shipTo
        INTO #itemSummary
        FROM #lrItems li
            INNER JOIN #lrContainer lc
                ON li.lrContainerId = lc.lrContainerId

        DROP TABLE IF EXISTS #containerQty;

        SELECT soHeaderId, COUNT(DISTINCT lrContainerId) as containerQty
        INTO #containerQty
        FROM #itemSummary
        GROUP BY soHeaderId

        DROP TABLE IF EXISTS #inventoryTypeList;

        SELECT soHeaderId, STRING_AGG(CONVERT(VARCHAR(MAX), inventoryType), ', ') as inventoryTypeList
        INTO #inventoryTypeList
        FROM (SELECT DISTINCT soHeaderId, inventoryType
                FROM #itemSummary 
            )g
        GROUP BY soHeaderId

        ALTER TABLE #itemSummary ADD containerQty INT;
        ALTER TABLE #itemSummary ADD inventoryTypeList VARCHAR(MAX);
        ALTER TABLE #itemSummary ADD rptMonth DATE;
        ALTER TABLE #itemSummary ADD rptMonthName VARCHAR(8);
        ALTER TABLE #itemSummary ADD totalMonthContainerQty INT;

        UPDATE #itemSummary SET
            containerQty = q.containerQty
        FROM #containerQty q
        WHERE #itemSummary.soHeaderId = q.soHeaderId

        UPDATE #itemSummary SET
            inventoryTypeList = it.inventoryTypeList
        FROM #inventoryTypeList it
        WHERE #itemSummary.soHeaderId = it.soHeaderId

        UPDATE #itemSummary SET
            rptMonth = DATEFROMPARTS(YEAR(lateShipDate), MONTH(lateShipDate), 1)

        UPDATE #itemSummary SET
            rptMonthName = UPPER(FORMAT(rptMonth, 'MMM')) + ' ' + CAST(YEAR(lateShipDate) as VARCHAR)

        DROP TABLE IF EXISTS #totalContainer;

        SELECT rptMonth, customerId, STRING_AGG(CONVERT(VARCHAR(MAX), ttlQty) + ' x ' + containerType,' & ') as totalContainer 
        INTO #totalContainer
        FROM (SELECT rptMonth, customerId, containerType, SUM(containerQty) as ttlQty
                FROM (SELECT DISTINCT rptMonth, customerId, soHeaderId, containerType, containerQty FROM #itemSummary)g
                GROUP BY rptMonth, customerId, containerType
              )g
        GROUP BY rptMonth, customerId

        SELECT soHeaderId, customer, soDate, lateShipDate, customerPo, thirdPartyPo, inventoryTypeList, containerType, containerQty, shipTo, s.rptMonth, rptMonthName, tc.totalContainer, @isMarketing as isMarketing
        FROM (SELECT DISTINCT soHeaderId, customerId, customer, lateShipDate, soDate, customerPo, thirdPartyPo, inventoryTypeList, containerType, containerQty, shipTo, rptMonth, rptMonthName
                FROM #itemSummary )s
            INNER JOIN #totalContainer tc
                ON s.rptMonth = tc.rptMonth
                AND s.customerId = tc.customerId
        ORDER BY customer, lateShipDate, customerPo

END

GO

