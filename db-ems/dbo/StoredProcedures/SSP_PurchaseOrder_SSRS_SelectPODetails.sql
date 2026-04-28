-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-05-05
-- Used By:	    EMS -> PO Module -> PO Listing -> Export PO Details pdf ssrs
--
-- Description : Export Purchase Order Details report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-05-05	1.0			ZY Wong 	Initial
-- ==========================================================================================
-- [SSP_PurchaseOrder_SSRS_SelectPODetails] 11, '2025-04-05','2025-05-05', 0, 0
CREATE PROCEDURE [dbo].[SSP_PurchaseOrder_SSRS_SelectPODetails]
@companyId INT,
@rptStartDate DATE,
@rptEndDate DATE,
@supplierId INT = 0,
@poStatus INT = 0
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        /*
        DECLARE @companyId INT = 11,
            @rptStartDate DATE = '2025-04-05',
            @rptEndDate DATE = '2025-05-05',
            @supplierId INT = 0,
            @poStatus INT = 0
        */

        -- default value
        IF @supplierId = 0
            SET @supplierId = NULL

        IF @poStatus = 0
            SET @poStatus = NULL

        DECLARE @companyName VARCHAR(200) = (SELECT companyName FROM md_Company WHERE companyId = @companyId);
        
        -- prepare header
        DROP TABLE IF EXISTS #poHeader;

        SELECT poId, supplierId, poName, poDate, CONVERT(VARCHAR(10), poEarlyShipDate) + ' - ' + CONVERT(VARCHAR(10), poLateShipDate) as shipWindow, customerCode, poReferenceId as soName, reference1 as customerPo, 
            shipToId, portOfLanding as POL, portOfDestination as portId, poStatus as poStatusId, poNote
        INTO #poHeader
        FROM poHeader
        WHERE poDate BETWEEN @rptStartDate AND @rptEndDate
            AND (@supplierId IS NULL OR supplierId = @supplierId)
            AND (@poStatus IS NULL OR poStatus = @poStatus)
            AND companyId = @companyId

        ALTER TABLE #poHeader ADD internal_branchId INT;
        ALTER TABLE #poHeader ADD supplierName VARCHAR(200);
        ALTER TABLE #poHeader ADD shipToName VARCHAR(100);
        ALTER TABLE #poHeader ADD POD VARCHAR(200);
        ALTER TABLE #poHeader ADD poStatus VARCHAR(50);

        UPDATE #poHeader SET
            internal_branchId = sup.internal_branchId,
            supplierName = sup.supplierCompanyName
        FROM md_Supplier sup
        WHERE #poHeader.supplierId = sup.supplierId

        IF (SELECT COUNT(1) FROM #poHeader WHERE internal_branchId <> 0) > 0
        BEGIN
            UPDATE #poHeader SET
                supplierName = c.companyShortCode
            FROM md_Company c
            WHERE #poHeader.internal_branchId = c.companyId
        END

        UPDATE #poHeader SET
            shipToName = st.shipToName
        FROM md_shipToDestination st
        WHERE #poHeader.shipToId = st.shipToId

        UPDATE #poHeader SET
            POD = pt.portName
        FROM md_Port pt
        WHERE #poHeader.portId = pt.portId

        UPDATE #poHeader SET
            poStatus = s.categoryName
        FROM md_masterCategory s
        WHERE #poHeader.poStatusId = s.categoryId

        -- prepare line item
        DROP TABLE IF EXISTS #poItems;

        SELECT poDetailsId, pl.poId, invId, supplierSku, itemCode, merchantSku, poItemDesc, qty, itemStatus as itemStatusId, soLineItemId,
            ROW_NUMBER() OVER(PARTITION BY pl.poId ORDER BY poDetailsId) as lineNum
        INTO #poItems
        FROM poLineItem pl
            INNER JOIN #poHeader ph
                ON pl.poId = ph.poId

        ALTER TABLE #poItems ADD itemStatus VARCHAR(50);
        ALTER TABLE #poItems ADD customerSkuId BIGINT;  -- remove in future, use poLineItem.reference2 as EAN
        ALTER TABLE #poItems ADD EAN VARCHAR(50);  -- remove in future, use poLineItem.reference2 as EAN

        UPDATE #poItems SET
            itemStatus = s.categoryName
        FROM md_masterCategory s
        WHERE #poItems.itemStatusId = s.categoryId 
        
        -- remove in future, use poLineItem.reference2 as EAN
        UPDATE #poItems SET 
            customerSkuId = sl.customerSkuId
        FROM soLineItem sl
        WHERE #poItems.soLineItemId = sl.soLineItemId
        
        -- remove in future, use poLineItem.reference2 as EAN
        UPDATE #poItems SET
            EAN = cs.EAN
        FROM md_customerSku cs
        WHERE #poItems.customerSkuId = cs.customerSkuId

        -- return output
        SELECT supplierName, poName, poDate, shipWindow, customerCode, soName, customerPo, shipToName, POL, POD, poStatus, poNote,
            lineNum, supplierSku, itemCode, merchantSku, EAN, poItemDesc, qty, itemStatus, @companyName as companyName
        FROM #poHeader ph
            INNER JOIN #poItems pl
                ON ph.poId = pl.poId
        ORDER BY poName, lineNum

END

GO

