-- =============================================
-- Author:		ZY Wong
-- Create date: 2024-08-29
-- Description:	Filter inventory info with @searchFilter
-- Used By:		Inventory > Inventory Catalog

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2024-09-25   2.0         ZY Wong     Add @customerId
-- 2024-09-03   1.1         ZY Wong     Add @rowStart, @pageRow, @sortBy, @sortDirection
-- 2024-08-29	1.0			ZY Wong		Initial version
-- =============================================
-- [SSP_Inventory_SelectInventoryCatalog] 4, '24', 1, 10, 5, 'DESC', 0;
CREATE PROCEDURE [dbo].[SSP_Inventory_SelectInventoryCatalog] 
@companyId INT,
@searchFilter VARCHAR(200),
@rowStart INT,
@pageRow INT,
@sortBy INT = 1,
@sortDirection VARCHAR(4) = 'DESC',
@customerId INT = 0
AS
BEGIN
    /** sortBy
        1 = order by itemCode  
        2 = order by prodCategory
        3 = order by prodSubCategory 
        4 = order by prodType 
        5 = order by modelNo 
        6 = order by inventorySku  
        7 = order by productName
        8 = order by itemDesc
        9 = order by status
    **/
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

        --DECLARE @companyId INT = 11, @searchFilter VARCHAR(200) = 'w', @rowStart INT = 1, @pageRow INT = 10, @sortBy INT = 1, @sortDirection VARCHAR(4) = 'DESC';

        DECLARE @sortOrder VARCHAR(2);

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D'
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A'
        END

        DECLARE @prodCategory TABLE (prodCategoryId INT);
        DECLARE @prodType TABLE (inventoryTypeId INT);
        DECLARE @inventory TABLE (invId INT);
        DECLARE @summary TABLE (thumbnailImage VARCHAR(255), invId INT, itemCode VARCHAR(50), productCategory INT, prodCategory VARCHAR(255), productSubCategory INT, prodSubCategory VARCHAR(255), 
            productType INT, prodType VARCHAR(255), modelNo VARCHAR(50), inventorySku VARCHAR(50), productName VARCHAR(255), itemDesc VARCHAR(500), [status] VARCHAR(10));

        -- search product category/ product sub category
        INSERT INTO @prodCategory
        SELECT prodCategoryId
        FROM md_InventoryCategory
        WHERE prodCategoryName like '%' + @searchFilter + '%'
            AND companyId = @companyId
            AND status = 1

        -- search product type
        INSERT INTO @prodType
        SELECT inventoryTypeId
        FROM md_inventoryType
        WHERE inventoryType like '%' + @searchFilter + '%'
            AND status = 1

        -- search itemCode/ modelNo/ inventorySku/ productName/ itemDesc
        INSERT INTO @inventory(invId)
        SELECT invId
        FROM md_inventory
        WHERE companyId = @companyId 
            AND (itemCode like '%' + @searchFilter + '%'
                OR modelNo like '%' + @searchFilter + '%'
                OR inventorySku like '%' + @searchFilter + '%'
                OR productName like '%' + @searchFilter + '%'
                OR itemDesc like '%' + @searchFilter + '%')

		INSERT INTO @inventory(invId)
		SELECT invId
		FROM md_inventory inv
            INNER JOIN @prodType pt
                ON inv.productType = pt.inventoryTypeId
		WHERE companyId = @companyId


		INSERT INTO @inventory(invId)
		SELECT invId
		FROM md_inventory inv
            INNER JOIN @prodCategory pc
                ON inv.productCategory = pc.prodCategoryId  -- product category
                OR inv.productSubCategory = pc.prodCategoryId  -- product sub category
		WHERE companyId = @companyId

        INSERT INTO @summary (thumbnailImage, invId, itemCode, productCategory, productSubCategory, productType, modelNo, inventorySku, productName, itemDesc, [status])
        SELECT DISTINCT inv.thumbnailImage, inv.invId, itemCode, productCategory, productSubCategory, productType, modelNo, inventorySku, productName, inv.itemDesc, 
            CASE WHEN [status] = 1 THEN 'ACTIVE' ELSE 'INACTIVE' END as [status]
        FROM md_Inventory inv
            INNER JOIN @inventory filterInv
                ON inv.invId = filterInv.invId  -- product category
            LEFT JOIN md_CustomerSku cssku
                ON inv.invId = cssku.invId
                AND inv.companyId = cssku.companyId
                AND cssku.statusflag = 1
        WHERE (ISNULL(@customerId,0) = 0 OR (@customerId <> 0 AND cssku.customerId = @customerId))
   

        UPDATE @summary SET 
            prodCategory = pc.prodCategoryName 
        FROM @summary inv
            INNER JOIN md_InventoryCategory pc
                ON inv.productCategory = pc.prodCategoryId
                AND pc.companyId = @companyId
                AND pc.prodCategoryParentID = 1  -- product category
                AND pc.status = 1
            
        UPDATE @summary SET 
            prodSubCategory = psc.prodCategoryName 
        FROM @summary inv
            INNER JOIN md_InventoryCategory psc
                ON inv.productSubCategory = psc.prodCategoryId
                AND psc.companyId = @companyId
                AND inv.productCategory = psc.prodCategoryParentID  -- product sub category
                AND psc.status = 1

        UPDATE @summary SET 
            prodType = pt.inventoryType
        FROM @summary inv
            INNER JOIN md_inventoryType pt
                ON inv.productType = pt.inventoryTypeId
                AND inv.productSubCategory = pt.prodCategoryId  -- product type
                AND pt.status = 1

        DROP TABLE IF EXISTS #sortingListing;

        SELECT DISTINCT thumbnailImage, invId, itemCode, prodCategory, prodSubCategory, prodType, modelNo, inventorySku, productName, itemDesc, [status], 
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN itemCode END DESC,
                CASE @sortOrder WHEN '1A' THEN itemCode END ASC,
                CASE @sortOrder WHEN '2D' THEN prodCategory END DESC,
                CASE @sortOrder WHEN '2A' THEN prodCategory END ASC,
                CASE @sortOrder WHEN '3D' THEN prodSubCategory END DESC,
                CASE @sortOrder WHEN '3A' THEN prodSubCategory END ASC,
                CASE @sortOrder WHEN '4D' THEN prodType END DESC,
                CASE @sortOrder WHEN '4A' THEN prodType END ASC,            
                CASE @sortOrder WHEN '5D' THEN modelNo END DESC,
                CASE @sortOrder WHEN '5A' THEN modelNo END ASC,    
                CASE @sortOrder WHEN '6D' THEN inventorySku END DESC,
                CASE @sortOrder WHEN '6A' THEN inventorySku END ASC,   
                CASE @sortOrder WHEN '7D' THEN productName END DESC,
                CASE @sortOrder WHEN '7A' THEN productName END ASC,
                CASE @sortOrder WHEN '8D' THEN itemDesc END DESC,
                CASE @sortOrder WHEN '8A' THEN itemDesc END ASC,
                CASE @sortOrder WHEN '9D' THEN [status] END DESC,
                CASE @sortOrder WHEN '9A' THEN [status] END ASC
                 ) as rowNo, 0 as totalRecord
        INTO #sortingListing
        FROM (SELECT DISTINCT thumbnailImage, invId, itemCode, prodCategory, prodSubCategory, prodType, modelNo, inventorySku, productName, itemDesc, [status]
            FROM @summary )g

        UPDATE #sortingListing SET
            totalRecord = totalrow
        FROM (SELECT COUNT(DISTINCT invId) as totalrow FROM #sortingListing) g

        SELECT invId, itemCode, prodCategory, prodSubCategory, prodType, modelNo, inventorySku, productName, itemDesc, [status], totalRecord, thumbnailImage
        FROM #sortingListing
        WHERE rowNo >= @rowStart AND rowNo <=  (@rowStart-1) + @pageRow
        ORDER BY rowNo

END

GO

