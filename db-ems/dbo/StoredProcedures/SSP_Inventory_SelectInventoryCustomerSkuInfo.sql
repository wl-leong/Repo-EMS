-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-08-29
-- Description:	Select inventory customer list & info
-- Used By:		Inventory > Inventory Catalog

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-08-29	1.0			ZY Wong		Initial version
-- =============================================
-- [SSP_Inventory_SelectInventoryCustomerSkuInfo] 505
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectInventoryCustomerSkuInfo] 
@invId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

        --DECLARE @invId INT = 505;

        DROP TABLE IF EXISTS #customerSkuInfo; 

        SELECT customerskuId, invId, customerId, customerSku, merchantSku, EAN, itemDesc, currencyCode as currencyCodeId, csCost,
            CASE WHEN statusflag = 1 THEN 'ACTIVE' ELSE 'INACTIVE' END as [status]
        INTO #customerSkuInfo
        FROM md_CustomerSku 
        WHERE invId = @invId 

        ALTER TABLE #customerSkuInfo ADD customerName VARCHAR(100);
        ALTER TABLE #customerSkuInfo ADD currencyCode VARCHAR(3);

        UPDATE sku SET
            customerName = cs.customerName
        FROM #customerSkuInfo sku
            INNER JOIN md_Customer cs
                ON sku.customerId = cs.customerId
                --AND cs.status = 1

        UPDATE sku SET
            currencyCode = cr.categoryName
        FROM #customerSkuInfo sku 
            INNER JOIN md_MasterCategory cr
                ON sku.currencyCodeId = cr.categoryId
                AND cr.categoryParentID = 1119  -- currency
                AND cr.status = 1

        SELECT customerskuId, invId, customerName, customerSku, merchantSku, EAN, itemDesc, currencyCode, csCost, [status]
        FROM #customerSkuInfo

END

GO

