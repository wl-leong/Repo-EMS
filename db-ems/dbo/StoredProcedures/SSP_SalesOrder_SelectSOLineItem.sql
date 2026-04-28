-- =============================================
-- Author:		WL Leong
-- Create date: 2023-06-08
-- Used By:	    EMS -> SO Module -> SO Listing -> Create New Order

-- Description : Sales Order for factory, Performa Invoice for Marketing Department

-- History: * Put the latest change on the top
-- DATE			VERSION #	NAME		DESCRIPTION
-- 2025-09-01	4.0			WL Leong	Add parameter UserId, return processQty
-- 2024-11-31	3.0			WL Leong	Using left join for tagDivision
-- 2024-11-13	2.0			WL Leong	Add tagDivision
-- 2024-04-28	1.0			WL Leong	Initial
-- ==========================================================================================
--EXEC SSP_SalesOrder_SelectSOLineItem 20428
 
CREATE PROCEDURE [dbo].[SSP_SalesOrder_SelectSOLineItem]
@soHeaderId BIGINT,
@userId INT,
@companyId INT,
@menu2Id INT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		
		DECLARE @permission AS TABLE(functionAdd BIT, functionEdit BIT, functionDelete BIT)
		DECLARE @pricePremission BIT = 0

		INSERT INTO @permission(functionAdd, functionEdit, functionDelete)
		SELECT functionAdd, functionEdit, functionDelete
		FROM dbo.userPermission(18 , 4, 1018)

		SET @pricePremission = (SELECT TOP 1 functionAdd FROM @permission);

        SELECT soLineItemId, customerSkuId, customerSku, merchantSku, inv.invId, inv.modelNo, currencyCode, 
			CASE WHEN @pricePremission = 1 THEN csCost ELSE 0 END as csCost, 
			CASE WHEN @pricePremission = 1 THEN freightCost ELSE 0 END as freightCost, 
			odrQty, poQty, shpQty, processQty,
            itemNote, soLineItemStatus, mc.categoryName as itemStatus, ISNULL(dv.categoryName, '') as tagDivision
        FROM soLineItem li
            INNER JOIN md_Inventory inv
                ON li.invId = inv.invId
            INNER JOIN md_MasterCategory mc
                ON li.soLineItemStatus = mc.categoryId
            LEFT JOIN md_MasterCategory dv
                ON li.tagDivision = dv.categoryId
        WHERE li.soHeaderId =   @soHeaderId
 
	END TRY

	BEGIN CATCH

		SELECT
			'_FAILURE_' as status, 'Line ' + CAST(ERROR_LINE() AS VARCHAR) + ':' + ERROR_MESSAGE() as errorMessage


	END CATCH
END

GO

