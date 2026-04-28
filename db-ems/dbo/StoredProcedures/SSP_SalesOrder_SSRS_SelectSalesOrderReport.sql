-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-01-21
-- Used By:		Report Module -> SSRS - Sales Order Report

-- Description:	

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-01-21	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_SalesOrder_SSRS_SelectSalesOrderReport] 4
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SSRS_SelectSalesOrderReport]
@companyId INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
    SET DATEFORMAT ymd;

    --DECLARE @companyId INT = 11

    DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company WHERE companyId = @companyId);

    DROP TABLE IF EXISTS #soList;

    SELECT soHeaderId, customerId, soName, customerPO, soDate, earlyShipDate, lateShipDate, shipToId
    INTO #soList
    FROM soHeader
    WHERE companyId = @companyId
        AND soStatus NOT IN (1107)  -- cancel

    ALTER TABLE #soList ADD customer VARCHAR(200);
    ALTER TABLE #soList ADD pod VARCHAR(100);

    UPDATE #soList SET
        customer = customerName
    FROM md_Customer cs
    WHERE #soList.customerId = cs.customerId

    UPDATE #soList SET
        pod = UPPER(st.pod)
    FROM md_ShipToDestination st
    WHERE #soList.shipToId = st.shipToId

    DROP TABLE IF EXISTS #soItem;

    SELECT so.soHeaderId, soLineItemId, invId, customerSku, odrQty, tagDivision
    INTO #soItem
    FROM soLineItem li
        INNER JOIN #soList so
            ON li.soHeaderId = so.soHeaderId
    WHERE soLineItemStatus NOT IN (1107)  -- cancel

    ALTER TABLE #soItem ADD division VARCHAR(50);
    ALTER TABLE #soItem ADD inventorySku VARCHAR(100);

    UPDATE #soItem SET
        inventorySku = inv.inventorySku
    FROM md_Inventory inv
    WHERE #soItem.invId = inv.invId

    UPDATE #soItem SET
        division = UPPER(dv.categoryName)
    FROM md_MasterCategory dv
    WHERE #soItem.tagDivision = dv.categoryId
     AND tagDivision > 0

    SELECT customer, soName, customerPo, soDate, earlyShipDate, lateShipDate, inventorySku, customerSku, odrQty, pod,
        CASE WHEN (@isMarketing = 0 AND tagDivision > 0) THEN division ELSE NULL END as division
    FROM #soList so
        INNER JOIN #soItem li
            ON so.soHeaderId = li.soHeaderId
    ORDER BY soDate, soName, odrQty DESC

END

GO

