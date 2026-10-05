-- =============================================
-- Author:		ZY Wong
-- Create date: 2025-06-04
-- Used By:	    EMS -> Shipping Module -> Shipping Listing -> Export CI by Invoice ssrs
--
-- Description : Export Commercial Invoice report
--
-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-06-17   2.0         ZY Wong     For CIPL return rowNo order by distinct inventory type
-- 2025-06-04	1.0			ZY Wong 	Initial
-- ==========================================================================================
/*

--DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00005', @invoiceId VARCHAR(20) = 'FNP-INV-25-00007', @reportType VARCHAR(5) = 'DO'
DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00001', @invoiceId VARCHAR(20) = 'FNP-INV-25-00008', @reportType VARCHAR(5) = 'CI'
--DECLARE @lrHeaderId BIGINT = 24, @bol VARCHAR(20) = 'FNP-BOL-25-00005', @invoiceId VARCHAR(20) = 'FNP-INV-25-00007', @reportType VARCHAR(5) = 'CIPL'

EXEC [SSP_Shipping_SSRS_SelectCIPLDOLineItem] @lrHeaderId, @bol, @invoiceId, @reportType
*/
CREATE PROCEDURE [dbo].[SSP_Shipping_SSRS_SelectCIPLDOLineItem]
@lrHeaderId BIGINT,
@bol VARCHAR(20),
@invoiceId VARCHAR(20),
@reportType VARCHAR(5)
AS 
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

        DECLARE @shipHeader TABLE(shipmentId BIGINT, soName VARCHAR(50));

        IF @reportType = 'DO'
        BEGIN
            INSERT INTO @shipHeader (shipmentId, soName)
            SELECT shipmentId, soName
            FROM shipmentHeader 
            WHERE bol = @bol
        END
        ELSE IF @reportType = 'CIPL'
        BEGIN
            INSERT INTO @shipHeader (shipmentId, soName)
            SELECT shipmentId, soName
            FROM shipmentHeader 
            WHERE lrHeaderId = @lrHeaderId
        END
        ELSE IF @reportType = 'CI'
        BEGIN
            INSERT INTO @shipHeader (shipmentId, soName)
            SELECT shipmentId, soName
            FROM shipmentHeader 
            WHERE invoiceId = @invoiceId
        END

        -- all items of invoiceId
        DROP TABLE IF EXISTS #shipmentItem;

        SELECT l.shipmentId, s.shipmentLineItemId, l.soName, s.invId, s.customerSku, s.shipQty, s.soLineItemId
        INTO #shipmentItem
        FROM shipmentLineItem s
            INNER JOIN @shipHeader l
                ON s.shipmentId = l.shipmentId
        WHERE s.lineItemStatus <> 2150 -- cancel

        -- items grp by invid
        DROP TABLE IF EXISTS #itemInfo;

        SELECT shp.invId, shp.customerSku, UPPER(s.soItemDesc) as soItemDesc, SUM(shp.shipQty) as shipQty, s.csCost, 
            CONVERT(NUMERIC(13,2), 0) as discount, CONVERT(NUMERIC(13,2), 0) as tax
        INTO #itemInfo
        FROM #shipmentItem shp
            INNER JOIN soLineItem s
                ON shp.soLineItemId = s.soLineItemId  
        GROUP BY shp.invId, shp.customerSku, UPPER(s.soItemDesc), s.csCost

        ALTER TABLE #itemInfo ADD measurementId INT;
        ALTER TABLE #itemInfo ADD cbm NUMERIC(13,5);
        ALTER TABLE #itemInfo ADD inventoryTypeId INT;
        ALTER TABLE #itemInfo ADD measurement VARCHAR(10);
        ALTER TABLE #itemInfo ADD inventoryType VARCHAR(100);

        UPDATE #itemInfo SET
            measurementId = inv.measurement,
            cbm = CONVERT(NUMERIC(13,5), inv.cbm),
            inventoryTypeId = inv.productType
        FROM md_Inventory inv
        WHERE #itemInfo.invId = inv.invId

        UPDATE #itemInfo SET
            measurement = ms.categoryName
        FROM md_MasterCategory ms
        WHERE #itemInfo.measurementId = ms.categoryId

        UPDATE #itemInfo SET
            inventoryType = pt.inventoryType
        FROM md_inventoryType pt
        WHERE #itemInfo.inventoryTypeId = pt.inventoryTypeId

        -- calculate cost per invId
        DROP TABLE IF EXISTS #itemCost;

        SELECT invId, shipQty, (shipQty * csCost) as ttlCost, (shipQty * discount) as ttlDiscount, (shipQty * tax) as ttlTax, (shipQty * cbm) as ttlCbm
        INTO #itemCost
        FROM #itemInfo

        ALTER TABLE #itemCost ADD ttlAmount NUMERIC(13,2);

        UPDATE #itemCost SET
            ttlAmount = ttlCost - ttlDiscount - ttlTax

        -- calculate total cost per invoiceId
        DECLARE @ttlShipQty INT = (SELECT SUM(shipQty) FROM #itemCost);
        DECLARE @invCost NUMERIC(13,2) = (SELECT SUM(ttlCost) FROM #itemCost);
        DECLARE @invDiscount NUMERIC(13,2) = (SELECT SUM(ttlDiscount) FROM #itemCost);
        DECLARE @invTax NUMERIC(13,2)= (SELECT SUM(ttlTax) FROM #itemCost);
        DECLARE @invAmount NUMERIC(13,2) = @invCost - @invDiscount + @invTax;
        DECLARE @totalShipmentCbm NUMERIC(13,5) = (SELECT CONVERT(NUMERIC(13,5), SUM(ttlCbm)) FROM #itemCost);

        -- grp for CI / CIPL
        --DECLARE @inventoryTypeList VARCHAR(MAX) = 
        --(
        --    SELECT STRING_AGG(CONVERT(VARCHAR(MAX), inventoryType), ', ') 
        --    FROM (SELECT DISTINCT inventoryType FROM #itemInfo )g 
        --);

        DECLARE @measurement VARCHAR(10) = (SELECT TOP 1 measurement FROM #itemInfo);
       
        DECLARE @summary TABLE (rowNo INT, customerSku VARCHAR(20), soItemDesc VARCHAR(500), shipQty INT, csCost NUMERIC(13,2), discount NUMERIC(13,2), tax NUMERIC(13,2), ttlAmount NUMERIC(13,2), 
            inventoryTypeList VARCHAR(MAX), ttlShipQty INT, measurement VARCHAR(10), totalShipmentCbm NUMERIC(13,5), invCost NUMERIC(13,2), invDiscount NUMERIC(13,2), invTax NUMERIC(13,2), invAmount NUMERIC(13,2));

        -- DO / CI return result
        IF @reportType IN ('DO', 'CI')
        BEGIN
            INSERT INTO @summary (rowNo, customerSku, soItemDesc, shipQty, csCost, discount, tax, ttlAmount, ttlShipQty, measurement, totalShipmentCbm, invCost, invDiscount, invTax, invAmount)
            SELECT ROW_NUMBER() OVER (ORDER BY customerSku) as rowNo,
                customerSku, soItemDesc, li.shipQty, csCost, discount, tax, c.ttlAmount, @ttlShipQty as ttlShipQty, @measurement as measurement, @totalShipmentCbm as totalShipmentCbm,
                @invCost as invCost, @invDiscount as invDiscount, @invTax as invTax, @invAmount as invAmount
            FROM #itemInfo li
                INNER JOIN #itemCost c
                    ON li.invId = c.invId

        END
        ELSE
        -- CIPL return result
        BEGIN
            INSERT INTO @summary (rowNo, inventoryTypeList, ttlShipQty, measurement, totalShipmentCbm, invCost, invDiscount, invTax, invAmount)
            SELECT ROW_NUMBER() OVER (ORDER BY inventoryType) as rowNo,
                inventoryType as inventoryTypeList, @ttlShipQty as ttlShipQty, @measurement as measurement, @totalShipmentCbm as totalShipmentCbm,
                @invCost as invCost, @invDiscount as invDiscount, @invTax as invTax, @invAmount as invAmount
            FROM (SELECT DISTINCT inventoryType FROM #itemInfo)g
        END

        SELECT rowNo, customerSku, soItemDesc, shipQty, csCost, discount, tax, ttlAmount, inventoryTypeList, ttlShipQty, measurement, totalShipmentCbm, invCost, invDiscount, invTax, invAmount
        FROM @summary

END

GO

