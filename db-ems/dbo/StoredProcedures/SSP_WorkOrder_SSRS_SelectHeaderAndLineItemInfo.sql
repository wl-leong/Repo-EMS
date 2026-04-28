-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-04-07
-- Used By:	    EMS -> WO Module -> WO Listing -> WO Pdf
-- Description : Select header and line item info of WO report

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-02   7.0         ZY Wong     Remove ver 6.0, add Revision column
-- 2025-08-15   6.0         ZY Wong     Add history for qty and target complete date
-- 2025-08-01   5.0         ZY Wong     Restructure columns
-- 2025-05-19   4.0         ZY Wong     Fix poNotes container type
-- 2025-05-07   3.0         ZY Wong     Header add thirdParty & remove soList, Line item add merchantSku & POD, restructure sp
-- 2025-04-18   2.0         ZY Wong     Remove looping
-- 2025-04-07	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*
EXEC [SSP_WorkOrder_SSRS_SelectHeaderAndLineItemInfo] '33'
*/
CREATE PROCEDURE [dbo].[SSP_WorkOrder_SSRS_SelectHeaderAndLineItemInfo]
@workOrderHeaderId VARCHAR(MAX)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        --DECLARE @workOrderHeaderId VARCHAR(MAX) = '24';

        DECLARE @sourceModule VARCHAR(10) = 'WorkOrder';

        -- get workOrderHeaderId from string
        DROP TABLE IF EXISTS #order;

        SELECT CAST([value] as INT) as workOrderHeaderId
        INTO #order
        FROM STRING_SPLIT(@workOrderHeaderId, ',')

        DROP TABLE IF EXISTS #summary;
        CREATE TABLE #summary (
            recordType VARCHAR(2), totalContainer VARCHAR(50), revision int,
            workOrderHeaderId BIGINT, companyName VARCHAR(100), companyAddress VARCHAR(200), companyPhone VARCHAR(200), workOrderName VARCHAR(50),
            warehouse VARCHAR(100), headerCustomerName VARCHAR(100), headerThirdParty VARCHAR(50), workOrderDate DATE,  earlyShipDate DATE, targetCompleteDate DATE, shipDate DATE,             
            rowNo INT, modelNo VARCHAR(50), EAN VARCHAR(50), merchantSku VARCHAR(50), customerModelNo VARCHAR(50), itemDesc VARCHAR(500), color VARCHAR(100), 
            soName VARCHAR(50), customerPo VARCHAR(50), POD VARCHAR(50), thirdPartyPo VARCHAR(500), totalQty INT, sumQty INT            
        )
        
        DROP TABLE IF EXISTS #woHeader;

        SELECT odr.workOrderHeaderId, companyId, workOrderName, workOrderDate, warehouseId, CAST('' as VARCHAR(100)) as warehouse, DATEADD(DAY, -8, shipDate) as earlyShipDate, 
            targetCompleteDate, shipDate, thirdParty, revision
        INTO #woHeader
        FROM workOrderHeader wo
            INNER JOIN #order odr
                ON wo.workOrderHeaderId = odr.workOrderHeaderId

        DECLARE @companyId INT = (SELECT TOP 1 companyId FROM #woHeader);

/** Start: prepare header info **/

        UPDATE #woHeader SET
            warehouse = CASE WHEN ISNULL(wh.locNo,'') = '' THEN wh.[label] ELSE wh.locNo END
        FROM md_Warehouse wh
        WHERE #woHeader.warehouseId = wh.warehouseId

        DROP TABLE IF EXISTS #woSoInfo;

        SELECT DISTINCT soHeaderId, soName, wo.workOrderHeaderId, CAST(0 as INT) as customerId, CAST('' as VARCHAR(100)) as customerName
        INTO #woSoInfo
        FROM workOrderLineItem li
            INNER JOIN #woHeader wo
                ON li.workOrderHeaderId = wo.workOrderHeaderId
        ORDER BY soName

        UPDATE #woSoInfo SET
            customerId = so.customerId,
            customerName = cs.customerName
        FROM soHeader so
            INNER JOIN md_Customer cs
                ON so.customerId = cs.customerId
        WHERE #woSoInfo.soHeaderId = so.soHeaderId

        -- prepare company address
        DECLARE @companyAddr TABLE(companyId INT, companyName VARCHAR(100), companyAddress VARCHAR(MAX), contactNumber VARCHAR(50), faxNumber VARCHAR(50),
            addrName VARCHAR(200), email VARCHAR(100), line2 VARCHAR(MAX));  --not using
        DECLARE @companyPhone VARCHAR(200);

        INSERT INTO @companyAddr (companyId, companyName, addrName, companyAddress, line2, contactNumber, faxNumber, email)
        EXEC [SSP_GetReportAddressInfo] 'Company', @companyId, 1       
        
        SET @companyPhone = ( SELECT CASE WHEN LEN(contactNumber) > 0 THEN 'TEL : ' + contactNumber + '  ' ELSE '' END + 
                                CASE WHEN LEN(faxNumber) > 0 THEN 'FAX : ' + faxNumber ELSE '' END
                                FROM @companyAddr);

        -- insert summary
        INSERT INTO #summary (recordType, workOrderHeaderId, companyName, companyAddress, companyPhone, workOrderName, 
            warehouse, headerCustomerName, headerThirdParty, workOrderDate, earlyShipDate, targetCompleteDate, shipDate, revision)
        SELECT DISTINCT 'OH' as recordType, wo.workOrderHeaderId, c.companyName, c.companyAddress, @companyPhone, workOrderName, 
            warehouse, ws.customerName, thirdParty, workOrderDate, earlyShipDate, targetCompleteDate, shipDate, revision
        FROM @companyAddr c
            INNER JOIN #woHeader wo
                ON c.companyId = wo.companyid
            INNER JOIN #woSoInfo ws
                ON wo.workOrderHeaderId = ws.workOrderHeaderId

/** End: prepare header info **/

/** Start: prepare line item info **/
        DROP TABLE IF EXISTS #woLineItem;

        SELECT odr.workOrderHeaderId, workOrderLineItemId, wo.soHeaderId, wo.soLineItemId, wo.invId, wo.confirmQty as qty, wo.workOrderItemStatus,
            li.customerSku, li.merchantSku, li.itemReference1 as customerModelNo, li.itemReference2 as EAN, li.soItemDesc as itemDesc,  
            CAST('' as VARCHAR(50)) as soName, CAST('' as VARCHAR(50)) as customerPo, CAST('' as VARCHAR(500)) as thirdPartyPo, CAST(0 as INT) as portId, CAST('' as VARCHAR(50)) as POD
        INTO #woLineItem
        FROM workOrderLineItem wo
            INNER JOIN #order odr
                ON wo.workOrderHeaderId = odr.workOrderHeaderId
            INNER JOIN soLineItem li
                ON wo.soLineItemId = li.soLineItemId    
                
        UPDATE #woLineItem SET
            soName = so.soName,
            customerPo = so.customerPo,
            thirdPartyPo = so.thirdPartyPo,
            portId = so.portOfDestination
        FROM soHeader so
        WHERE #woLineItem.soHeaderId = so.soHeaderId

        UPDATE #woLineItem SET
            POD = pt.portName
        FROM md_port pt
        WHERE #woLineItem.portId = pt.portId

        DROP TABLE IF EXISTS #woItems;

        SELECT workOrderHeaderId, soName, customerPo, POD, thirdPartyPo, invId, customerSku, merchantSku, customerModelNo, EAN, itemDesc, SUM(qty) as totalQty, 0 as sumQty,
            CAST('' as VARCHAR(50)) as modelNo, CAST('' as VARCHAR(50)) as color, CAST(0 as INT) as rowNo, CAST('' as VARCHAR(500)) as containers
        INTO #woItems
        FROM #woLineItem
        GROUP BY workOrderHeaderId, soName, customerPo, POD, thirdPartyPo, invId, customerSku, merchantSku, customerModelNo, EAN, itemDesc

        UPDATE #woItems SET
            sumQty = g.sumQty           
        FROM (SELECT workOrderHeaderId, invId, SUM(totalQty) as sumQty
                FROM #woItems
                GROUP BY workOrderHeaderId, invId
                )g
        WHERE #woItems.workOrderHeaderId = g.workOrderHeaderId
             AND #woItems.invId = g.invId       

        UPDATE #woItems SET
            modelNo = inv.inventorySku
        FROM md_inventory inv
        WHERE #woItems.invId = inv.invId

        UPDATE #woItems SET 
            color = cl.[value]
        FROM (
            SELECT invId, [value] 
            FROM inventory_attributes 
            WHERE categoryId IN (3194) -- colour name
            ) cl
        WHERE #woItems.invId = cl.invId

        DROP TABLE IF EXISTS #rowNo;

        SELECT workOrderHeaderId, modelNo, ROW_NUMBER() OVER (PARTITION BY workOrderHeaderId ORDER BY modelNo) as rowNo
        INTO #rowNo
        FROM (SELECT DISTINCT workOrderHeaderId, modelNo FROM #woItems)g

        UPDATE #woItems SET
            rowNo = rw.rowNo
        FROM #rowNo rw
        WHERE #woItems.workOrderHeaderId = rw.workOrderHeaderId
            AND #woItems.modelNo = rw.modelNo       

        UPDATE #woItems SET
            containers = REPLACE(po.poNote, '''','')
        FROM poHeader po
        WHERE #woItems.customerPo = po.poName
            AND ISNULL(po.poNote,'') <> ''

        DROP TABLE IF EXISTS #containerType;

        SELECT REPLACE(categoryName, ' ', '') as containerType
        INTO #containerType
        FROM md_masterCategory
        WHERE categoryParentId = 3153  -- container type

        DROP TABLE IF EXISTS #shortenPoNotes;

        SELECT workOrderHeaderId, customerPo, LEFT(containers, sPosition + ctLength - 1) as containers, containerType
        INTO #shortenPoNotes
        FROM (
            SELECT DISTINCT workOrderHeaderId, customerPo, containers, containerType, CHARINDEX(containerType, containers) as sPosition, LEN(containerType) as ctLength
            FROM #woItems, #containerType
        )g
        WHERE sPosition <> 0

        DROP TABLE IF EXISTS #containerList;

        SELECT workOrderHeaderId, customerPo, CAST(TRIM(LEFT(containers, CHARINDEX('x', containers) - 1)) as INT) as containerQty, containerType
        INTO #containerList
        FROM #shortenPoNotes

        DROP TABLE IF EXISTS #totalContainer;

        SELECT workOrderHeaderId, STRING_AGG(CAST(containerQty as VARCHAR) + ' x ' + LEFT(containerType,2) + '''' + RIGHT(containerType, LEN(containerType) - 2), ' & ') as totalContainer
        INTO #totalContainer
        FROM (
            SELECT workOrderHeaderId, containerType, SUM(CAST(containerQty as INT)) as containerQty
            FROM #containerList
            GROUP BY workOrderHeaderId, containerType
        )g
        GROUP BY workOrderHeaderId 

        UPDATE wo SET
            totalContainer = ISNULL(tc.totalContainer,'')
        FROM #summary wo           
            INNER JOIN #totalContainer tc
                ON wo.workOrderHeaderId = tc.workOrderHeaderId
        WHERE wo.recordType = 'OH'

        -- preapre sumQty & old_sumQty for OH records
        DECLARE @sumQty TABLE (workOrderHeaderId BIGINT, sumQty INT);

        INSERT INTO @sumQty (workOrderHeaderId, sumQty)
        SELECT workOrderHeaderId, SUM(totalQty) as sumQty
        FROM #woItems 
        GROUP BY workOrderHeaderId

        UPDATE wo SET
            sumQty = sq.sumQty
        FROM #summary wo
            INNER JOIN @sumQty sq
                ON wo.workOrderHeaderId = sq.workOrderHeaderId
        WHERE wo.recordType = 'OH'

        -- insert summary
        INSERT INTO #summary (recordType, workOrderHeaderId, modelNo, EAN, merchantSku, customerModelNo, itemDesc, 
            color, soName, customerPo, POD, thirdPartyPo, totalQty, sumQty, rowNo, totalContainer)
        SELECT 'OL' as recordType, wo.workOrderHeaderId, modelNo, EAN, merchantSku, customerModelNo, itemDesc, 
            color, soName, customerPo, POD, thirdPartyPo, totalQty, sumQty, rowNo, ISNULL(tc.totalContainer,'')
        FROM #woItems wo
            LEFT JOIN #totalContainer tc
                ON wo.workOrderHeaderId = tc.workOrderHeaderId
        ORDER BY rowNo

/** End: prepare line item info **/

        SELECT recordType, workOrderHeaderId, companyName, companyAddress, companyPhone, workOrderName, warehouse, 
            headerCustomerName, headerThirdParty, workOrderDate, earlyShipDate, targetCompleteDate, shipDate,             
            rowNo, modelNo, EAN, merchantSku, customerModelNo, itemDesc, color, soName, customerPo, POD, thirdPartyPo, totalQty, sumQty, totalContainer, revision
        FROM #summary
        ORDER BY workOrderHeaderId, recordType, rowNo
 
END

GO

