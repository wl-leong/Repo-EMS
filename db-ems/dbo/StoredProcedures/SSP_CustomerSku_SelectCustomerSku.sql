-- =============================================
-- Author:		ZY Wong
-- Create date: 2026-10-06
-- Description:	Select list of active customer sku based on customer 
-- Used By:		EMS -> Customer Module -> Customer Sku -> List Customer Sku

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2026-10-06	1.0			ZY Wong		Initial version
-- =============================================
-- EXEC [SSP_CustomerSku_SelectCustomerSkuListing] 11, 26, 1, 50, 1, 'DESC', 'MS 6'
CREATE PROCEDURE [dbo].[SSP_CustomerSku_SelectCustomerSkuListing]
@companyId INT,
@customerId INT = 0,
@rowStart INT,      --compulsory
@pageRow INT,       --compulsory
@sortBy INT = 1,    
@sortDirection VARCHAR(4) = 'DESC',
@searchInput VARCHAR(50) = NULL
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

    /** sortBy
        2 = order by productSku
        3 = order by productName 
        4 = order by itemDescription 
        5 = order by customerSku 
        6 = order by merchantSku 
		7 = order by csCost
    **/

	BEGIN TRY

		--DECLARE @companyId INT = 11, @customerId INT = 26, @rowStart INT = 1, @pageRow INT = 10, @sortBy INT = 0, @sortDirection VARCHAR(4) = 'DESC', @searchInput VARCHAR(50) = NULL;

		DECLARE @sortOrder VARCHAR(2);

		IF @customerId = 0
		BEGIN
            SET @customerId = NULL
		END

		IF @searchInput = ''
        BEGIN
            SET @searchInput = NULL
        END

        IF @sortDirection = 'DESC'
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'D';
        END
        ELSE
        BEGIN
            SET @sortOrder = CAST(@sortBy as VARCHAR) + 'A';
        END

		DROP TABLE IF EXISTS #skuList;

		SELECT customerId, customerSkuId, invId, itemDesc, customerSku, merchantSku, csCost
		INTO #skuList
		FROM md_CustomerSku
		WHERE companyId = @companyId
			AND (ISNULL(@customerId, 0) = 0 OR customerId = @customerId)
			AND statusFlag = 1

		ALTER TABLE #skuList ADD customerName VARCHAR(100);
		ALTER TABLE #skuList ADD inventorySku VARCHAR(50);
		ALTER TABLE #skuList ADD productName VARCHAR(255);

		UPDATE #skuList SET
			customerName = cs.customerName
		FROM md_Customer cs
		WHERE #skuList.customerId = cs.customerId

		UPDATE #skuList SET
			inventorySku = inv.inventorySku,
			productName = inv.productName,
			itemDesc = CASE WHEN #skuList.itemDesc = '' THEN inv.itemDesc ELSE #skuList.itemDesc END
		FROM md_Inventory inv
		WHERE #skuList.invId = inv.invId

		DECLARE @result TABLE(customerSkuId BIGINT, customerName VARCHAR(100), productSku VARCHAR(50), productName VARCHAR(255), itemDescription VARCHAR(255), customerSku VARCHAR(50), merchantSku VARCHAR(50), csCost NUMERIC(18,4), totalRecord INT);

		IF @searchInput IS NOT NULL
        BEGIN
			SET @searchInput = (SELECT LTRIM(RTRIM(@searchInput)));

			INSERT INTO @result (customerSkuId, customerName, productSku, productName, itemDescription, customerSku, merchantSku, csCost)
			SELECT customerSkuId, customerName, inventorySku, productName, itemDesc, customerSku, merchantSku, csCost
			FROM #skuList 
			WHERE customerName LIKE '%' + @searchInput + '%'
				OR inventorySku LIKE '%' + @searchInput + '%'
				OR productName LIKE '%' + @searchInput + '%'
				OR itemDesc LIKE '%' + @searchInput + '%'
				OR customerSku LIKE '%' + @searchInput + '%'
				OR merchantSku LIKE '%' + @searchInput + '%'
				OR CONVERT(VARCHAR(20), csCost) LIKE '%' + @searchInput + '%'
		END
		ELSE
		BEGIN
			INSERT INTO @result (customerSkuId, customerName, productSku, productName, itemDescription, customerSku, merchantSku, csCost)
			SELECT customerSkuId, customerName, inventorySku, productName, itemDesc, customerSku, merchantSku, csCost
			FROM #skuList 
		END

		UPDATE @result SET
            totalRecord = totalrow
        FROM (SELECT COUNT(DISTINCT customerSkuId) as totalrow FROM @result) g

		DROP TABLE IF EXISTS #sortingListing;

        SELECT customerSkuId, customerName, productSku, productName, itemDescription, customerSku, merchantSku, csCost, 
            ROW_NUMBER() OVER(ORDER BY 
                CASE @sortOrder WHEN '1D' THEN customerName END DESC,
                CASE @sortOrder WHEN'1A' THEN customerName END ASC,
                CASE @sortOrder WHEN '2D' THEN productSku END DESC,
                CASE @sortOrder WHEN'2A' THEN productSku END ASC,
                CASE @sortOrder WHEN '3D' THEN productName END DESC,
                CASE @sortOrder WHEN'3A' THEN productName END ASC,
                CASE @sortOrder WHEN '4D' THEN itemDescription END DESC,
                CASE @sortOrder WHEN'4A' THEN itemDescription END ASC,            
                CASE @sortOrder WHEN '5D' THEN customerSku END DESC,
                CASE @sortOrder WHEN'5A' THEN customerSku END ASC,    
                CASE @sortOrder WHEN '6D' THEN merchantSku END DESC,
                CASE @sortOrder WHEN'6A' THEN merchantSku END ASC,   
                CASE @sortOrder WHEN '7D' THEN csCost END DESC,
                CASE @sortOrder WHEN'7A' THEN csCost END ASC        
                 ) as rowNo, totalRecord
        INTO #sortingListing
        FROM @result

		SELECT customerSkuId, customerName, productSku, productName, itemDescription, customerSku, merchantSku, csCost, rowNo, totalRecord
		FROM #sortingListing
		WHERE rowNo >= @rowStart AND rowNo <= (@rowStart - 1) + @pageRow
		ORDER BY rowNo

	END TRY

	BEGIN CATCH

		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as returnMessage

		RETURN -1
	END CATCH
END

GO