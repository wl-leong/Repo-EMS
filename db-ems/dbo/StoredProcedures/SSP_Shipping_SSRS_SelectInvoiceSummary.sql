-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-12-05
-- Used By:		Shipping Module -> SSRS - Invoice Summary

-- Description:	

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-12-05	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_Shipping_SSRS_SelectInvoiceSummary] 11,'26,30',1,2025
CREATE PROCEDURE [dbo].[SSP_Shipping_SSRS_SelectInvoiceSummary]
@companyId INT,
@customerList NVARCHAR(MAX),
@reportMonth INT,
@reportYear INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
    SET DATEFORMAT ymd;

    --DECLARE @companyId INT = 11,
    --@customerList NVARCHAR(MAX) = '19,20,24,29',
    --@reportMonth INT = 1,
    --@reportYear INT = 2025;

        DROP TABLE IF EXISTS #customerList;

        SELECT csl.value as customerId, cs.customerName
        INTO #customerList 
        FROM string_split(@customerList,',') csl
            INNER JOIN md_Customer cs
                ON csl.value = cs.customerId
                AND cs.companyId = @companyId
        ORDER BY cs.customerName

        DECLARE @customerName VARCHAR(1000) = (SELECT STRING_AGG(customerName, ', ') FROM #customerList );
        DECLARE @isMarketing INT = (SELECT isMarketing FROM md_Company where companyId = @companyId);

        -- get shipment info
        DROP TABLE IF EXISTS #csShipmentInfo;

        SELECT shipmentId, shp.customerId, cs.customerName, shipId, 
            invoiceId, invoiceDate, customerPo + ISNULL(customerInvoiceNo,'') as csInvNPoNo, ISNULL(customerInvoiceNo,'') as customerInvoiceNo, customerPo,
            pol, pod, etd, eta, 'FOB' as tradeTerm, containerSeqNo, containerTypeId, invoiceAmount, soHeaderId, soName,
            lrHeaderId
        INTO #csShipmentInfo
        FROM shipmentHeader shp
            LEFT JOIN #customerList cs
                ON shp.customerId = cs.customerId
        WHERE companyId = @companyId
            AND DATEPART(month, invoiceDate) = @reportMonth
            AND DATEPART(year, invoiceDate) = @reportYear

        

        -- use lr to find internal supplier shipment
        DROP TABLE IF EXISTS #supplierLrInfo;

        SELECT lr.lrHeaderId, lr.companyId, lr.ref_customerLrheaderId, 'FNP-' + CAST(invoiceId as VARCHAR) as supplierInvoiceId
        INTO #supplierLrInfo
        FROM lrHeader lr
            LEFT JOIN #csShipmentInfo shp
                ON lr.ref_customerLrheaderId = shp.lrHeaderId
        WHERE @isMarketing = 1
            

        ALTER TABLE #csShipmentInfo ADD containerType VARCHAR(10);
        ALTER TABLE #csShipmentInfo ADD supplierId BIGINT;
        ALTER TABLE #csShipmentInfo ADD poName VARCHAR(50);
        ALTER TABLE #csShipmentInfo ADD currency VARCHAR(3);
        ALTER TABLE #csShipmentInfo ADD supplierName VARCHAR(200);
        ALTER TABLE #csShipmentInfo ADD supplierCurrency VARCHAR(3);

        UPDATE #csShipmentInfo SET
            containerType = ct.categoryName
        FROM md_MasterCategory ct
        WHERE #csShipmentInfo.containerTypeId = ct.categoryId
            AND ct.categoryParentID = 3153  --container type
            AND ct.status = 1

        UPDATE #csShipmentInfo SET 
            supplierId = po.supplierId,
            poName = po.poName,
            currency = po.homeCurrencyCode,
            supplierCurrency = po.foreignCurrencyCode
        FROM poHeader po
        WHERE #csShipmentInfo.soName = po.poReferenceId     
        
        UPDATE shp SET 
            supplierName = cpy.companyShortCode
        FROM md_Company cpy
            INNER JOIN md_Supplier sup
                ON cpy.companyId = sup.internal_branchId 
            INNER JOIN #csShipmentInfo shp
                ON sup.supplierId = shp.supplierId

        DROP TABLE IF EXISTS #csShipmentItem;

        SELECT shp.shipmentId, SUM(shipQty) as totalShipQty
        INTO #csShipmentItem
        FROM shipmentLineItem li
            INNER JOIN #csShipmentInfo shp
                ON li.shipmentId = shp.shipmentId
        GROUP BY shp.shipmentId


        SELECT customerName, shipId, invoiceId, csInvNPoNo, customerInvoiceno, invoiceDate, customerPo, poName, pol, pod, eta, etd, tradeTerm, containerSeqNo, containerType, totalShipQty, 
            'PCS' as UOM, currency, invoiceAmount,
            supplierName, supplierInvoiceId, 
            CASE WHEN supplierInvoiceId IS NULL THEN NULL ELSE invoiceDate END as supplierInvoiceDate, 
            CASE WHEN supplierInvoiceId IS NULL THEN NULL ELSE totalShipQty END as supplierTotalShipQty, 
            CASE WHEN supplierInvoiceId IS NULL THEN NULL ELSE 'PCS' END as supplierUOM, 
            CASE WHEN supplierInvoiceId IS NULL THEN NULL ELSE supplierCurrency END as supplierCurrency, 
            CASE WHEN supplierInvoiceId IS NULL THEN NULL ELSE invoiceAmount END as supplierInvoiceAmount,
            @customerName as customerNameList
        FROM #csShipmentInfo shp
            INNER JOIN #csShipmentItem li
                ON shp.shipmentId = li.shipmentId
            LEFT JOIN #supplierLrInfo lr
                ON shp.lrHeaderId = lr.ref_customerLrheaderId



END

GO

